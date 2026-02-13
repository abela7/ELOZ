import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/widgets/duration_entry_sheet.dart';
import '../../data/models/habit.dart';

/// Timer UI for Timer-type habits.
///
/// Returns the logged duration in **minutes** (int) when saved, or null if cancelled.
class HabitTimerModal {
  static Future<int?> show(
    BuildContext context, {
    required Habit habit,
  }) async {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (context) => _HabitTimerSheet(habit: habit),
    );
  }
}

class _HabitTimerSheet extends StatefulWidget {
  final Habit habit;

  const _HabitTimerSheet({
    required this.habit,
  });

  @override
  State<_HabitTimerSheet> createState() => _HabitTimerSheetState();
}

class _HabitTimerSheetState extends State<_HabitTimerSheet> {
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted && _stopwatch.isRunning) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _toggle() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_stopwatch.isRunning) {
        _stopwatch.stop();
      } else {
        _stopwatch.start();
      }
    });
  }

  void _reset() {
    HapticFeedback.lightImpact();
    setState(() {
      _stopwatch.reset();
    });
  }

  Future<void> _manualEntry() async {
    HapticFeedback.selectionClick();
    final habit = widget.habit;
    final minutes = await DurationEntrySheet.show(
      context,
      title: 'Log duration',
      subtitle: habit.title,
      targetMinutes: habit.targetDurationMinutes,
      initialUnit: habit.effectiveTimeUnit,
      accentColor: habit.color,
      pointsForMinutes: (m) => habit.calculateTimerPoints(m).round(),
    );
    if (!mounted || minutes == null) return;
    if (_stopwatch.isRunning) _stopwatch.stop();
    Navigator.pop(context, minutes);
  }

  int get _elapsedMinutesCeil {
    final seconds = _stopwatch.elapsed.inSeconds;
    if (seconds <= 0) return 0;
    return (seconds / 60).ceil();
  }

  String _formatElapsed() {
    final d = _stopwatch.elapsed;
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    final seconds = d.inSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final habit = widget.habit;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E2228) : Colors.white;
    final text = isDark ? Colors.white : const Color(0xFF1A1C1E);
    final sub = isDark ? Colors.white70 : const Color(0xFF44474E);
    final targetMinutes = habit.targetDurationMinutes;
    final elapsedMinutes = _elapsedMinutesCeil;
    final progress = (targetMinutes == null || targetMinutes <= 0)
        ? null
        : (elapsedMinutes / targetMinutes).clamp(0.0, 2.0);

    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Timer • ${habit.title}',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: text,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              if (targetMinutes != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Target: ${habit.formatDuration(targetMinutes, compact: true)}',
                                  style: TextStyle(
                                    color: sub,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton.filledTonal(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded, size: 20),
                          style: IconButton.styleFrom(
                            backgroundColor: isDark ? Colors.white10 : Colors.black12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Timer Display Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF252A31) : const Color(0xFFF7F7F8),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.black12,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _formatElapsed(),
                            style: TextStyle(
                              color: text,
                              fontSize: 56,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -2.0,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (progress != null) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(99),
                              child: LinearProgressIndicator(
                                value: progress.toDouble().clamp(0.0, 1.0),
                                minHeight: 10,
                                backgroundColor: isDark ? Colors.white10 : Colors.black12,
                                color: habit.color,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Logged: ${habit.formatDuration(elapsedMinutes, compact: true)}'
                              '${elapsedMinutes > (targetMinutes ?? 0) ? ' (overtime)' : ''}',
                              style: TextStyle(
                                color: sub,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ] else ...[
                            Text(
                              elapsedMinutes == 0
                                  ? 'Tap Start to begin'
                                  : 'Logged: ${habit.formatDuration(elapsedMinutes, compact: true)}',
                              style: TextStyle(
                                color: sub,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Controls
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: elapsedMinutes == 0 ? null : _reset,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.refresh_rounded, size: 18),
                                const SizedBox(width: 8),
                                Text('Reset', style: TextStyle(color: text, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _manualEntry,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.edit_rounded, size: 18),
                                const SizedBox(width: 8),
                                Text('Manual', style: TextStyle(color: text, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _toggle,
                        icon: Icon(
                          _stopwatch.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          size: 24,
                        ),
                        label: Text(
                          _stopwatch.isRunning ? 'Stop Timer' : 'Start Timer',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: habit.color,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Bottom Actions
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(color: sub, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: elapsedMinutes <= 0
                                ? null
                                : () {
                                    if (_stopwatch.isRunning) _stopwatch.stop();
                                    Navigator.pop(context, elapsedMinutes);
                                  },
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Save Progress',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

