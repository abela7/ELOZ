import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Profiles the full theme-toggle pipeline in debug/profile mode.
///
/// Flow:
/// tap -> provider write -> provider observed -> app build -> theme refs -> first frame
class ThemeToggleProfiler {
  ThemeToggleProfiler._();

  static bool get _enabled => kDebugMode || kProfileMode;

  static int _nextToggleId = 0;
  static int? _activeToggleId;
  static int? _awaitingFirstFrameToggleId;
  static final Map<int, Stopwatch> _stopwatches = <int, Stopwatch>{};
  static final Map<int, _ToggleFrameWindow> _frameWindows =
      <int, _ToggleFrameWindow>{};
  static final Set<int> _postFrameScheduled = <int>{};
  static final Queue<_RapidFrameSample> _rapidSamples =
      Queue<_RapidFrameSample>();
  static const int _rapidSampleCap = 180;

  static int startToggle({required ThemeMode from, required ThemeMode to}) {
    if (!_enabled) return -1;
    final id = ++_nextToggleId;
    _activeToggleId = id;
    _awaitingFirstFrameToggleId = id;
    _stopwatches[id] = Stopwatch()..start();
    _frameWindows[id] = _ToggleFrameWindow();
    _log(id, 'tap', details: {'from': from.name, 'to': to.name});
    return id;
  }

  static void markProviderWrite(int toggleId) {
    if (!_enabled || toggleId <= 0) return;
    _log(toggleId, 'provider_write');
  }

  static void markProviderObserved({
    required ThemeMode? previous,
    required ThemeMode next,
  }) {
    if (!_enabled) return;
    final id = _activeToggleId;
    if (id == null) return;
    _log(id, 'provider_observed', details: {'next': next.name});
  }

  static int markAppBuildStart(ThemeMode mode) {
    if (!_enabled) return -1;
    final id = _activeToggleId ?? -1;
    if (id > 0) {
      _log(id, 'materialapp_build_start', details: {'mode': mode.name});
    }
    return id;
  }

  static void markThemeRefsResolved(
    int toggleId, {
    required Duration lightThemeResolve,
    required Duration darkThemeResolve,
  }) {
    if (!_enabled || toggleId <= 0) return;
    _log(
      toggleId,
      'theme_refs_resolved',
      details: {
        'lightResolveUs': lightThemeResolve.inMicroseconds,
        'darkResolveUs': darkThemeResolve.inMicroseconds,
      },
    );
  }

  static void markAppBuildDone(
    int toggleId, {
    required ThemeMode mode,
    required Duration themeAnimationDuration,
  }) {
    if (!_enabled || toggleId <= 0) return;
    _log(
      toggleId,
      'materialapp_build_done',
      details: {
        'mode': mode.name,
        'themeAnimMs': themeAnimationDuration.inMilliseconds,
      },
    );
    _markFirstRenderedFrame(toggleId);
  }

  static void onFrameTimings(List<FrameTiming> timings) {
    if (!_enabled || timings.isEmpty) return;

    for (final timing in timings) {
      final totalMs = timing.totalSpan.inMicroseconds / 1000.0;
      final buildMs = timing.buildDuration.inMicroseconds / 1000.0;
      final rasterMs = timing.rasterDuration.inMicroseconds / 1000.0;
      _rapidSamples.add(
        _RapidFrameSample(
          totalMs: totalMs,
          buildMs: buildMs,
          rasterMs: rasterMs,
        ),
      );
      while (_rapidSamples.length > _rapidSampleCap) {
        _rapidSamples.removeFirst();
      }

      if (_awaitingFirstFrameToggleId != null) {
        final id = _awaitingFirstFrameToggleId!;
        _log(
          id,
          'first_frame',
          details: {
            'frameTotalMs': totalMs.toStringAsFixed(2),
            'frameBuildMs': buildMs.toStringAsFixed(2),
            'frameRasterMs': rasterMs.toStringAsFixed(2),
          },
        );
        _awaitingFirstFrameToggleId = null;
      }

      final completed = <int>[];
      for (final entry in _frameWindows.entries) {
        final summary = entry.value;
        summary.record(totalMs);
        if (summary.isComplete) {
          _log(
            entry.key,
            'frame_window',
            details: {
              'frames': summary.samples.length,
              'avgMs': summary.avgMs.toStringAsFixed(2),
              'maxMs': summary.maxMs.toStringAsFixed(2),
              'jank16Ms': summary.jank16Ms,
            },
          );
          completed.add(entry.key);
        }
      }
      for (final id in completed) {
        _frameWindows.remove(id);
        _finishIfDone(id);
      }
    }
  }

  static void dumpRapidToggleSummary() {
    if (!_enabled) return;
    if (_rapidSamples.isEmpty) return;
    var maxMs = 0.0;
    var totalMs = 0.0;
    var jank16 = 0;
    for (final sample in _rapidSamples) {
      totalMs += sample.totalMs;
      if (sample.totalMs > maxMs) {
        maxMs = sample.totalMs;
      }
      if (sample.totalMs > 16.0) {
        jank16++;
      }
    }
    final avgMs = totalMs / _rapidSamples.length;
    debugPrint(
      '[Perf][ThemeToggleRapid] '
      'frames=${_rapidSamples.length} '
      'avgMs=${avgMs.toStringAsFixed(2)} '
      'maxMs=${maxMs.toStringAsFixed(2)} '
      'jank16Ms=$jank16',
    );
  }

  static void _finishIfDone(int toggleId) {
    final sw = _stopwatches[toggleId];
    if (sw == null) return;
    sw.stop();
    _log(toggleId, 'flow_done', details: {'totalMs': sw.elapsedMilliseconds});
    _stopwatches.remove(toggleId);
    if (_activeToggleId == toggleId) {
      _activeToggleId = null;
    }
  }

  static void _markFirstRenderedFrame(int toggleId) {
    if (!_enabled || toggleId <= 0) return;
    if (_postFrameScheduled.contains(toggleId)) return;
    _postFrameScheduled.add(toggleId);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _postFrameScheduled.remove(toggleId);
      _log(toggleId, 'first_rendered_frame');
    });
  }

  static void _log(
    int toggleId,
    String event, {
    Map<String, Object?> details = const {},
  }) {
    final sw = _stopwatches[toggleId];
    final elapsedUs = sw?.elapsedMicroseconds ?? 0;
    final payload = <String, Object?>{'elapsedUs': elapsedUs, ...details};
    final suffix = payload.entries.map((e) => '${e.key}=${e.value}').join(' ');
    debugPrint('[Perf][ThemeToggle#$toggleId] $event $suffix');
  }
}

class _ToggleFrameWindow {
  static const int _sampleBudget = 24;
  final List<double> samples = <double>[];

  bool get isComplete => samples.length >= _sampleBudget;

  void record(double frameTotalMs) {
    if (!isComplete) {
      samples.add(frameTotalMs);
    }
  }

  double get avgMs {
    if (samples.isEmpty) return 0;
    return samples.reduce((a, b) => a + b) / samples.length;
  }

  double get maxMs {
    if (samples.isEmpty) return 0;
    return samples.reduce((a, b) => a > b ? a : b);
  }

  int get jank16Ms => samples.where((v) => v > 16.0).length;
}

class _RapidFrameSample {
  _RapidFrameSample({
    required this.totalMs,
    required this.buildMs,
    required this.rasterMs,
  });

  final double totalMs;
  final double buildMs;
  final double rasterMs;
}
