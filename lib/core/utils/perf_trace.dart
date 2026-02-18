import 'package:flutter/foundation.dart';

/// Lightweight step timer for profile/debug performance tracing.
///
/// Disabled in release builds.
class PerfTrace {
  PerfTrace(this.tag) : _enabled = kDebugMode || kProfileMode {
    if (_enabled) {
      _stopwatch.start();
      _log('start', deltaMs: 0, totalMs: 0);
    }
  }

  final String tag;
  final bool _enabled;
  final Stopwatch _stopwatch = Stopwatch();
  int _lastElapsedMs = 0;

  bool get isEnabled => _enabled;

  void step(String name, {Map<String, Object?> details = const {}}) {
    if (!_enabled) return;
    final totalMs = _stopwatch.elapsedMilliseconds;
    final deltaMs = totalMs - _lastElapsedMs;
    _lastElapsedMs = totalMs;
    _log(name, deltaMs: deltaMs, totalMs: totalMs, details: details);
  }

  void end(String name, {Map<String, Object?> details = const {}}) {
    if (!_enabled) return;
    step(name, details: details);
    _stopwatch.stop();
  }

  static void log(
    String tag,
    String name, {
    Map<String, Object?> details = const {},
  }) {
    if (!(kDebugMode || kProfileMode)) return;
    final suffix = details.isEmpty ? '' : ' ${_format(details)}';
    debugPrint('[Perf][$tag] $name$suffix');
  }

  void _log(
    String name, {
    required int deltaMs,
    required int totalMs,
    Map<String, Object?> details = const {},
  }) {
    final payload = <String, Object?>{
      'deltaMs': deltaMs,
      'totalMs': totalMs,
      ...details,
    };
    final suffix = payload.isEmpty ? '' : ' ${_format(payload)}';
    debugPrint('[Perf][$tag] $name$suffix');
  }

  static String _format(Map<String, Object?> details) {
    if (details.isEmpty) return '';
    final parts = <String>[];
    for (final entry in details.entries) {
      parts.add('${entry.key}=${entry.value}');
    }
    return parts.join(' ');
  }
}
