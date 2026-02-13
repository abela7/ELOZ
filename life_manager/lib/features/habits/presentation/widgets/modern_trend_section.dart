import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/models/habit.dart';
import '../../data/models/habit_completion.dart';
import '../../data/models/habit_statistics.dart';

// ─── Enums ────────────────────────────────────────────────────────────────

enum _TrendRange { week, month }

enum _DayStatus { done, partial, skipped, missed, open, inactive }

// ─── Data classes ─────────────────────────────────────────────────────────

class _TrendDay {
  final DateTime date;
  final double value;
  final _DayStatus status;
  final double target;
  const _TrendDay({
    required this.date,
    required this.value,
    required this.status,
    required this.target,
  });
}

class _TrendSummary {
  final int done;
  final int partial;
  final int skipped;
  final int missed;
  final int open;
  final int inactive;
  final int goalCount;
  final double activityScore;
  final double totalValue;
  final double avgPerDay;
  final double avgPerSession;
  final int sessionCount;
  const _TrendSummary({
    required this.done,
    required this.partial,
    required this.skipped,
    required this.missed,
    required this.open,
    required this.inactive,
    required this.goalCount,
    required this.activityScore,
    required this.totalValue,
    required this.avgPerDay,
    required this.avgPerSession,
    required this.sessionCount,
  });
}

class _TrendData {
  final List<_TrendDay> days;
  final _TrendSummary summary;
  final double maxY;
  final double targetValue;
  const _TrendData({
    required this.days,
    required this.summary,
    required this.maxY,
    required this.targetValue,
  });
}

// ─── Main widget ──────────────────────────────────────────────────────────

class ModernTrendSection extends StatefulWidget {
  final HabitStatistics statistics;
  final Habit habit;
  final bool isDark;
  final bool showFullScreenButton;
  final bool startMonthly;

  const ModernTrendSection({
    super.key,
    required this.statistics,
    required this.habit,
    required this.isDark,
    this.showFullScreenButton = true,
    this.startMonthly = false,
  });

  @override
  State<ModernTrendSection> createState() => _ModernTrendSectionState();
}

class _ModernTrendSectionState extends State<ModernTrendSection>
    with SingleTickerProviderStateMixin {
  late _TrendRange _range;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  /// Offset from current period. 0 = current week/month, -1 = previous, etc.
  int _periodOffset = 0;

  @override
  void initState() {
    super.initState();
    _range = widget.startMonthly ? _TrendRange.month : _TrendRange.week;
    _animCtrl = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _toggleRange(_TrendRange range) {
    if (_range == range) return;
    _animCtrl.reset();
    setState(() {
      _range = range;
      _periodOffset = 0; // reset to current when switching mode
    });
    _animCtrl.forward();
  }

  void _goBack() {
    _animCtrl.reset();
    setState(() => _periodOffset--);
    _animCtrl.forward();
  }

  void _goForward() {
    if (_periodOffset >= 0) return;
    _animCtrl.reset();
    setState(() => _periodOffset++);
    _animCtrl.forward();
  }

  void _goToNow() {
    if (_periodOffset == 0) return;
    _animCtrl.reset();
    setState(() => _periodOffset = 0);
    _animCtrl.forward();
  }

  /// Compute the start/end dates for the current period + offset
  _DateRange _currentDateRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_range == _TrendRange.week) {
      // Current week ends today, starts 6 days ago
      final end = today.add(Duration(days: _periodOffset * 7));
      final start = end.subtract(const Duration(days: 6));
      return _DateRange(start, end);
    } else {
      // Month mode: calendar month
      final targetMonth =
          DateTime(today.year, today.month + _periodOffset, 1);
      final start = DateTime(targetMonth.year, targetMonth.month, 1);
      final end = DateTime(targetMonth.year, targetMonth.month + 1, 0);
      // Don't go past today
      final cappedEnd = end.isAfter(today) ? today : end;
      return _DateRange(start, cappedEnd);
    }
  }

  void _openFullScreen() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bg = widget.isDark ? const Color(0xFF0D0F12) : Colors.white;
        return DraggableScrollableSheet(
          initialChildSize: 0.88,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (ctx, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: bg,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color:
                            widget.isDark ? Colors.white12 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  ModernTrendSection(
                    statistics: widget.statistics,
                    habit: widget.habit,
                    isDark: widget.isDark,
                    showFullScreenButton: false,
                    startMonthly: _range == _TrendRange.month,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateRange = _currentDateRange();
    final data = _buildTrendDataForRange(
      statistics: widget.statistics,
      habit: widget.habit,
      start: dateRange.start,
      end: dateRange.end,
    );

    return _Card(
      isDark: widget.isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header row ──
          _buildHeader(),
          const SizedBox(height: 12),

          // ── Period navigator ──
          _buildPeriodNavigator(dateRange),
          const SizedBox(height: 14),

          // ── Score ring ──
          _buildScoreRing(data.summary),
          const SizedBox(height: 16),

          // ── Chart ──
          FadeTransition(
            opacity: _fadeAnim,
            child: SizedBox(
              height: 180,
              child: _range == _TrendRange.week
                  ? _WeeklyBarChart(
                      key: ValueKey('w$_periodOffset'),
                      habit: widget.habit,
                      isDark: widget.isDark,
                      days: data.days,
                      maxY: data.maxY,
                      target: data.targetValue,
                    )
                  : _MonthlyAreaChart(
                      key: ValueKey('m$_periodOffset'),
                      habit: widget.habit,
                      isDark: widget.isDark,
                      days: data.days,
                      maxY: data.maxY,
                      target: data.targetValue,
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Heatmap ──
          FadeTransition(
            opacity: _fadeAnim,
            child: _buildHeatmap(data.days),
          ),
          const SizedBox(height: 14),

          // ── Type-specific insight row ──
          _buildTypeInsights(data.summary, data.targetValue),
          const SizedBox(height: 10),

          // ── Legend ──
          _buildLegend(),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                widget.habit.color.withOpacity(widget.isDark ? 0.25 : 0.15),
                widget.habit.color.withOpacity(widget.isDark ? 0.10 : 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.insights_rounded,
              color: widget.habit.color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Progress Overview',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: widget.isDark ? Colors.white : const Color(0xFF1E1E1E),
            ),
          ),
        ),
        _RangeToggle(
          isDark: widget.isDark,
          color: widget.habit.color,
          range: _range,
          onChanged: _toggleRange,
        ),
        if (widget.showFullScreenButton) ...[
          const SizedBox(width: 6),
          _buildIconBtn(Icons.fullscreen_rounded, _openFullScreen),
        ],
      ],
    );
  }

  // ── Period navigator with arrows ──────────────────────────────────────

  Widget _buildPeriodNavigator(_DateRange range) {
    final isCurrent = _periodOffset == 0;
    String label;
    if (_range == _TrendRange.week) {
      if (isCurrent) {
        label = 'This Week';
      } else if (_periodOffset == -1) {
        label = 'Last Week';
      } else {
        label =
            '${DateFormat('MMM d').format(range.start)} – ${DateFormat('MMM d').format(range.end)}';
      }
    } else {
      if (isCurrent) {
        label = DateFormat('MMMM yyyy').format(range.start);
      } else {
        label = DateFormat('MMMM yyyy').format(range.start);
      }
    }

    return Row(
      children: [
        // Back arrow
        _navArrow(Icons.chevron_left_rounded, _goBack, true),
        const Spacer(),
        // Period label + today button
        GestureDetector(
          onTap: isCurrent ? null : _goToNow,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isCurrent
                  ? widget.habit.color.withOpacity(widget.isDark ? 0.15 : 0.08)
                  : (widget.isDark
                      ? Colors.white.withOpacity(0.06)
                      : Colors.black.withOpacity(0.04)),
              borderRadius: BorderRadius.circular(20),
              border: isCurrent
                  ? Border.all(
                      color: widget.habit.color
                          .withOpacity(widget.isDark ? 0.3 : 0.15))
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isCurrent) ...[
                  Icon(Icons.history_rounded,
                      size: 13,
                      color: widget.isDark ? Colors.white38 : Colors.black38),
                  const SizedBox(width: 4),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isCurrent
                        ? widget.habit.color
                        : (widget.isDark ? Colors.white60 : Colors.black54),
                  ),
                ),
                if (!isCurrent) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: widget.habit.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Now',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: widget.habit.color,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const Spacer(),
        // Forward arrow (disabled at current)
        _navArrow(Icons.chevron_right_rounded, _goForward, !isCurrent),
      ],
    );
  }

  Widget _navArrow(IconData icon, VoidCallback onTap, bool enabled) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: enabled
              ? (widget.isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.05))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled
              ? (widget.isDark ? Colors.white54 : Colors.black45)
              : (widget.isDark ? Colors.white10 : Colors.black12),
        ),
      ),
    );
  }

  Widget _buildIconBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: widget.isDark
              ? Colors.white10
              : Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: widget.habit.color, size: 16),
      ),
    );
  }

  // ── Score ring ────────────────────────────────────────────────────────

  Widget _buildScoreRing(_TrendSummary s) {
    final score = s.activityScore.clamp(0.0, 100.0).toDouble();
    final color = _scoreColor(score);
    final label = _scoreLabel(score);

    return Row(
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: (score / 100).clamp(0.0, 1.0),
                  strokeWidth: 5,
                  strokeCap: StrokeCap.round,
                  backgroundColor: widget.isDark
                      ? Colors.white10
                      : Colors.black.withOpacity(0.06),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              Text(
                '${score.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: widget.isDark ? Colors.white : const Color(0xFF1E1E1E),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${score.toStringAsFixed(0)}% activity',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: widget.isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _buildMiniStatusRow(s),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStatusRow(_TrendSummary s) {
    final items = <_MiniStat>[];
    items.add(_MiniStat(s.done, 'Done', _statusColor(_DayStatus.done)));
    if (_hasPartial(widget.habit) && s.partial > 0) {
      items.add(
          _MiniStat(s.partial, 'Partial', _statusColor(_DayStatus.partial)));
    }
    if (s.skipped > 0) {
      items.add(
          _MiniStat(s.skipped, 'Skip', _statusColor(_DayStatus.skipped)));
    }
    if (s.missed > 0) {
      items
          .add(_MiniStat(s.missed, 'Miss', _statusColor(_DayStatus.missed)));
    }
    if (_isFlexibleFrequency(widget.habit) && s.open > 0) {
      items.add(_MiniStat(s.open, 'Open', _statusColor(_DayStatus.open)));
    }

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: items.map((item) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: item.color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 3),
            Text(
              '${item.count}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: item.color,
              ),
            ),
            const SizedBox(width: 2),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: widget.isDark ? Colors.white30 : Colors.black26,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  // ── Professional heatmap ──────────────────────────────────────────────

  Widget _buildHeatmap(List<_TrendDay> days) {
    if (_range == _TrendRange.week) {
      return _buildWeekHeatmap(days);
    }
    return _buildMonthGrid(days);
  }

  Widget _buildWeekHeatmap(List<_TrendDay> days) {
    return Row(
      children: days.map((d) {
        final isToday = _isToday(d.date);
        final dayLabel = DateFormat('E').format(d.date).substring(0, 2);

        return Expanded(
          child: Tooltip(
            message: _tooltipText(d),
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 36,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: _cellBg(d),
                    borderRadius: BorderRadius.circular(10),
                    border: isToday
                        ? Border.all(
                            color: widget.habit.color, width: 2)
                        : Border.all(
                            color: widget.isDark
                                ? Colors.white.withOpacity(0.04)
                                : Colors.black.withOpacity(0.04),
                            width: 1),
                  ),
                  child: Center(child: _cellIcon(d)),
                ),
                const SizedBox(height: 5),
                Text(
                  dayLabel,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
                    color: isToday
                        ? widget.habit.color
                        : (widget.isDark ? Colors.white30 : Colors.black26),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMonthGrid(List<_TrendDay> days) {
    if (days.isEmpty) return const SizedBox.shrink();

    // Align to weekday grid (0=Sun)
    final firstWeekday = days.first.date.weekday % 7;
    final cells = <_TrendDay?>[
      ...List<_TrendDay?>.filled(firstWeekday, null),
      ...days,
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    final weeks = <List<_TrendDay?>>[];
    for (int i = 0; i < cells.length; i += 7) {
      weeks.add(cells.sublist(i, math.min(i + 7, cells.length)));
    }

    return Column(
      children: [
        // Day-of-week header
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                .map((l) => Expanded(
                      child: Center(
                        child: Text(
                          l,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: widget.isDark
                                ? Colors.white24
                                : Colors.black26,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
        // Rows
        ...weeks.map((row) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                children: row.map((d) {
                  if (d == null) {
                    return const Expanded(child: SizedBox(height: 28));
                  }
                  final isToday = _isToday(d.date);
                  return Expanded(
                    child: Tooltip(
                      message: _tooltipText(d),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 28,
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        decoration: BoxDecoration(
                          color: _cellBg(d),
                          borderRadius: BorderRadius.circular(6),
                          border: isToday
                              ? Border.all(
                                  color: widget.habit.color, width: 1.5)
                              : null,
                        ),
                        child: Center(
                          child: d.status == _DayStatus.inactive
                              ? null
                              : _cellIconSmall(d),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            )),
      ],
    );
  }

  /// Background color for a heatmap cell — professional, muted, status-aware
  Color _cellBg(_TrendDay d) {
    final dark = widget.isDark;
    switch (d.status) {
      case _DayStatus.done:
        return dark
            ? const Color(0xFF4CAF50).withOpacity(0.25)
            : const Color(0xFF4CAF50).withOpacity(0.18);
      case _DayStatus.partial:
        final pct = d.target > 0 ? (d.value / d.target).clamp(0.0, 1.0) : 0.5;
        return dark
            ? const Color(0xFFFFB347).withOpacity(0.12 + pct * 0.18)
            : const Color(0xFFFFB347).withOpacity(0.10 + pct * 0.15);
      case _DayStatus.skipped:
        return dark
            ? const Color(0xFF64B5F6).withOpacity(0.12)
            : const Color(0xFF64B5F6).withOpacity(0.10);
      case _DayStatus.missed:
        return dark
            ? const Color(0xFFEF5350).withOpacity(0.14)
            : const Color(0xFFEF5350).withOpacity(0.10);
      case _DayStatus.open:
        return dark
            ? Colors.white.withOpacity(0.04)
            : Colors.black.withOpacity(0.03);
      case _DayStatus.inactive:
        return dark
            ? Colors.white.withOpacity(0.02)
            : Colors.black.withOpacity(0.02);
    }
  }

  /// Icon inside weekly heatmap cell
  Widget? _cellIcon(_TrendDay d) {
    const size = 16.0;
    switch (d.status) {
      case _DayStatus.done:
        return Icon(Icons.check_rounded,
            size: size, color: _statusColor(_DayStatus.done));
      case _DayStatus.partial:
        return Icon(Icons.timelapse_rounded,
            size: size - 2, color: _statusColor(_DayStatus.partial));
      case _DayStatus.skipped:
        return Icon(Icons.redo_rounded,
            size: size - 2, color: _statusColor(_DayStatus.skipped));
      case _DayStatus.missed:
        return Icon(Icons.close_rounded,
            size: size - 2, color: _statusColor(_DayStatus.missed));
      case _DayStatus.open:
        return Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: widget.isDark ? Colors.white12 : Colors.black12,
            shape: BoxShape.circle,
          ),
        );
      case _DayStatus.inactive:
        return null;
    }
  }

  /// Small icon for 30-day grid cells
  Widget? _cellIconSmall(_TrendDay d) {
    const size = 12.0;
    switch (d.status) {
      case _DayStatus.done:
        return Icon(Icons.check_rounded,
            size: size, color: _statusColor(_DayStatus.done));
      case _DayStatus.partial:
        return Icon(Icons.circle,
            size: 5, color: _statusColor(_DayStatus.partial));
      case _DayStatus.skipped:
        return Icon(Icons.remove_rounded,
            size: size - 2, color: _statusColor(_DayStatus.skipped));
      case _DayStatus.missed:
        return Icon(Icons.close_rounded,
            size: size - 2, color: _statusColor(_DayStatus.missed));
      case _DayStatus.open:
        return null;
      case _DayStatus.inactive:
        return null;
    }
  }

  String _tooltipText(_TrendDay d) {
    final dateFmt = DateFormat('EEE, MMM d').format(d.date);
    final habit = widget.habit;
    String statusLabel;
    switch (d.status) {
      case _DayStatus.done:
        statusLabel = 'Completed';
        break;
      case _DayStatus.partial:
        statusLabel = 'Partial';
        break;
      case _DayStatus.skipped:
        statusLabel = 'Skipped';
        break;
      case _DayStatus.missed:
        statusLabel = habit.isQuitHabit ? 'Slip' : 'Missed';
        break;
      case _DayStatus.open:
        statusLabel = 'Open';
        break;
      case _DayStatus.inactive:
        statusLabel = 'Inactive';
        break;
    }
    final valStr = d.value > 0 ? ' · ${_fmtValue(habit, d.value)}' : '';
    return '$dateFmt\n$statusLabel$valStr';
  }

  // ── Type-specific insights ─────────────────────────────────────────────

  Widget _buildTypeInsights(_TrendSummary s, double target) {
    final habit = widget.habit;
    final unit = _unitLabel(habit);
    final items = <Widget>[];

    if (habit.isTimer) {
      items.addAll([
        _insightPill(Icons.timer_rounded,
            _formatMinutes(s.totalValue.round()), 'Total time', habit.color),
        if (s.sessionCount > 0)
          _insightPill(Icons.speed_rounded,
              _formatMinutes(s.avgPerSession.round()), 'Avg session', habit.color),
        if (target > 0)
          _insightPill(Icons.flag_rounded, _formatMinutes(target.round()),
              'Daily goal', habit.color.withOpacity(0.7)),
      ]);
    } else if (habit.isNumeric) {
      items.addAll([
        _insightPill(Icons.functions_rounded, _fmtNum(s.totalValue, unit),
            'Total', habit.color),
        if (s.sessionCount > 0)
          _insightPill(Icons.show_chart_rounded, _fmtNum(s.avgPerDay, unit),
              'Avg / day', habit.color),
        if (target > 0)
          _insightPill(Icons.flag_rounded, _fmtNum(target, unit), 'Goal',
              habit.color.withOpacity(0.7)),
      ]);
    } else if (habit.isQuitHabit) {
      items.addAll([
        _insightPill(Icons.shield_rounded,
            '${widget.statistics.currentStreak}', 'Clean days', const Color(0xFF4CAF50)),
        _insightPill(Icons.emoji_events_rounded,
            '${widget.statistics.bestStreak}', 'Best streak', const Color(0xFFFFB347)),
        if (s.missed > 0)
          _insightPill(Icons.warning_amber_rounded, '${s.missed}', 'Slips',
              _statusColor(_DayStatus.missed)),
      ]);
    } else {
      items.addAll([
        _insightPill(Icons.local_fire_department_rounded,
            '${widget.statistics.currentStreak}', 'Streak', const Color(0xFFFF6B6B)),
        _insightPill(Icons.emoji_events_rounded,
            '${widget.statistics.bestStreak}', 'Best', const Color(0xFFFFB347)),
        _insightPill(Icons.check_circle_rounded, '${s.done}', 'Done',
            _statusColor(_DayStatus.done)),
      ]);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: items
            .map((w) =>
                Padding(padding: const EdgeInsets.only(right: 8), child: w))
            .toList(),
      ),
    );
  }

  Widget _insightPill(
      IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(widget.isDark ? 0.18 : 0.10),
            color.withOpacity(widget.isDark ? 0.08 : 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(widget.isDark ? 0.25 : 0.15),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color:
                      widget.isDark ? Colors.white : const Color(0xFF1E1E1E),
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: widget.isDark ? Colors.white30 : Colors.black26,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Legend ──────────────────────────────────────────────────────────────

  Widget _buildLegend() {
    final items = <_LegendItem>[
      _LegendItem('Done', _statusColor(_DayStatus.done)),
      if (_hasPartial(widget.habit))
        _LegendItem('Partial', _statusColor(_DayStatus.partial)),
      if (_isFlexibleFrequency(widget.habit))
        _LegendItem('Open', _statusColor(_DayStatus.open)),
      _LegendItem('Skip', _statusColor(_DayStatus.skipped)),
      _LegendItem(
          widget.habit.isQuitHabit ? 'Slip' : 'Miss',
          _statusColor(_DayStatus.missed)),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: item.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 3),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: widget.isDark ? Colors.white24 : Colors.black26,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─── Date range helper ────────────────────────────────────────────────────

class _DateRange {
  final DateTime start;
  final DateTime end;
  const _DateRange(this.start, this.end);
}

// ─── Card container ───────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  final bool isDark;
  const _Card({required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D3139) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─── Range toggle ─────────────────────────────────────────────────────────

class _RangeToggle extends StatelessWidget {
  final bool isDark;
  final Color color;
  final _TrendRange range;
  final ValueChanged<_TrendRange> onChanged;

  const _RangeToggle({
    required this.isDark,
    required this.color,
    required this.range,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.06)
            : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Chip(
            label: '7D',
            selected: range == _TrendRange.week,
            color: color,
            onTap: () => onChanged(_TrendRange.week),
          ),
          const SizedBox(width: 3),
          _Chip(
            label: '30D',
            selected: range == _TrendRange.month,
            color: color,
            onTap: () => onChanged(_TrendRange.month),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _Chip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : color,
          ),
        ),
      ),
    );
  }
}

// ─── Small helper classes ─────────────────────────────────────────────────

class _MiniStat {
  final int count;
  final String label;
  final Color color;
  const _MiniStat(this.count, this.label, this.color);
}

class _LegendItem {
  final String label;
  final Color color;
  const _LegendItem(this.label, this.color);
}

// ─── Weekly bar chart ─────────────────────────────────────────────────────

class _WeeklyBarChart extends StatelessWidget {
  final Habit habit;
  final bool isDark;
  final List<_TrendDay> days;
  final double maxY;
  final double target;

  const _WeeklyBarChart({
    super.key,
    required this.habit,
    required this.isDark,
    required this.days,
    required this.maxY,
    required this.target,
  });

  @override
  Widget build(BuildContext context) {
    return BarChart(
      BarChartData(
        minY: 0,
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: _niceInterval(maxY),
          getDrawingHorizontalLine: (v) => FlLine(
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.black.withOpacity(0.04),
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: _niceInterval(maxY),
              getTitlesWidget: (v, _) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  _fmtAxis(habit, v),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white24 : Colors.black26,
                  ),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt().clamp(0, days.length - 1);
                final isToday = _isToday(days[i].date);
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    DateFormat('E').format(days[i].date).substring(0, 2),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight:
                          isToday ? FontWeight.w900 : FontWeight.w600,
                      color: isToday
                          ? habit.color
                          : (isDark ? Colors.white24 : Colors.black26),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        extraLinesData: target > 0
            ? ExtraLinesData(horizontalLines: [
                HorizontalLine(
                  y: target,
                  color: habit.color.withOpacity(0.4),
                  strokeWidth: 1.5,
                  dashArray: [6, 4],
                ),
              ])
            : const ExtraLinesData(),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor:
                isDark ? const Color(0xFF1A1D24) : Colors.white,
            tooltipRoundedRadius: 12,
            tooltipPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            getTooltipItem: (group, gi, rod, ri) {
              final i = group.x.toInt().clamp(0, days.length - 1);
              final d = days[i];
              return BarTooltipItem(
                '${DateFormat('EEE, MMM d').format(d.date)}\n',
                TextStyle(
                  color: isDark ? Colors.white54 : Colors.black45,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                children: [
                  TextSpan(
                    text: _fmtValue(habit, d.value),
                    style: TextStyle(
                      color: _statusColor(d.status),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        barGroups: List.generate(days.length, (i) {
          final d = days[i];
          final barColor = _statusColor(d.status);
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: d.value,
                width: 20,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(8)),
                gradient: d.value > 0
                    ? LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          barColor.withOpacity(0.5),
                          barColor,
                        ],
                      )
                    : null,
                color: d.value > 0
                    ? null
                    : (isDark
                        ? Colors.white.withOpacity(0.04)
                        : Colors.black.withOpacity(0.03)),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxY,
                  color: isDark
                      ? Colors.white.withOpacity(0.03)
                      : Colors.black.withOpacity(0.02),
                ),
              ),
            ],
          );
        }),
      ),
      swapAnimationDuration: const Duration(milliseconds: 400),
      swapAnimationCurve: Curves.easeOutCubic,
    );
  }
}

// ─── Monthly area chart ──────────────────────────────────────────────────

class _MonthlyAreaChart extends StatelessWidget {
  final Habit habit;
  final bool isDark;
  final List<_TrendDay> days;
  final double maxY;
  final double target;

  const _MonthlyAreaChart({
    super.key,
    required this.habit,
    required this.isDark,
    required this.days,
    required this.maxY,
    required this.target,
  });

  @override
  Widget build(BuildContext context) {
    final spots = days
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.value))
        .toList();

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        clipData: const FlClipData.all(),
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor:
                isDark ? const Color(0xFF1A1D24) : Colors.white,
            tooltipRoundedRadius: 12,
            tooltipPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            getTooltipItems: (spots) {
              return spots.map((spot) {
                final i = spot.x.toInt().clamp(0, days.length - 1);
                final d = days[i];
                return LineTooltipItem(
                  '${DateFormat('MMM d').format(d.date)}\n',
                  TextStyle(
                    color: isDark ? Colors.white54 : Colors.black45,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                  children: [
                    TextSpan(
                      text: _fmtValue(habit, d.value),
                      style: TextStyle(
                        color: _statusColor(d.status),
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ],
                );
              }).toList();
            },
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: _niceInterval(maxY),
          getDrawingHorizontalLine: (v) => FlLine(
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.black.withOpacity(0.04),
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: _niceInterval(maxY),
              getTitlesWidget: (v, _) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  _fmtAxis(habit, v),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white24 : Colors.black26,
                  ),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: math.max(1, (days.length / 5).roundToDouble()),
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= days.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    DateFormat('d').format(days[i].date),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white24 : Colors.black26,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        extraLinesData: target > 0
            ? ExtraLinesData(horizontalLines: [
                HorizontalLine(
                  y: target,
                  color: habit.color.withOpacity(0.4),
                  strokeWidth: 1.5,
                  dashArray: [6, 4],
                ),
              ])
            : const ExtraLinesData(),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.22,
            preventCurveOverShooting: true,
            color: habit.color,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, __, index) {
                final d = days[index];
                if (spot.y == 0) {
                  return FlDotCirclePainter(
                    radius: 0,
                    color: Colors.transparent,
                    strokeWidth: 0,
                    strokeColor: Colors.transparent,
                  );
                }
                return FlDotCirclePainter(
                  radius: 3,
                  color: _statusColor(d.status),
                  strokeWidth: 2,
                  strokeColor:
                      isDark ? const Color(0xFF2D3139) : Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  habit.color.withOpacity(0.25),
                  habit.color.withOpacity(0.08),
                  habit.color.withOpacity(0.0),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }
}

// ─── Data building (range-based) ──────────────────────────────────────────

_TrendData _buildTrendDataForRange({
  required HabitStatistics statistics,
  required Habit habit,
  required DateTime start,
  required DateTime end,
}) {
  final byDate = <String, List<HabitCompletion>>{};
  for (final c in statistics.recentCompletions) {
    final key = _dk(c.completedDate);
    byDate.putIfAbsent(key, () => []).add(c);
  }

  final totalDays = end.difference(start).inDays + 1;
  final entries = <_TrendDay>[];
  for (int i = 0; i < totalDays; i++) {
    final date = start.add(Duration(days: i));
    entries.add(_dayEntry(
      habit: habit,
      date: date,
      completions: byDate[_dk(date)] ?? const [],
    ));
  }

  final summary = _summarize(
    habit: habit,
    start: start,
    end: end,
    days: entries,
    completions: statistics.recentCompletions,
  );

  final rawMax = entries.fold<double>(0, (m, d) => math.max(m, d.value));
  final tv = _dailyTarget(habit);
  final maxY = _padMax(math.max(rawMax, tv));

  return _TrendData(
      days: entries, summary: summary, maxY: maxY, targetValue: tv);
}

_TrendSummary _summarize({
  required Habit habit,
  required DateTime start,
  required DateTime end,
  required List<_TrendDay> days,
  required List<HabitCompletion> completions,
}) {
  int done = 0,
      partial = 0,
      skipped = 0,
      missed = 0,
      open = 0,
      inactive = 0;
  double totalValue = 0;
  int sessionCount = 0;
  double sessionTotal = 0;

  for (final d in days) {
    totalValue += d.value;
    switch (d.status) {
      case _DayStatus.done:
        done++;
        break;
      case _DayStatus.partial:
        partial++;
        break;
      case _DayStatus.skipped:
        skipped++;
        break;
      case _DayStatus.missed:
        missed++;
        break;
      case _DayStatus.open:
        open++;
        break;
      case _DayStatus.inactive:
        inactive++;
        break;
    }
  }

  for (final c in completions) {
    final date = DateTime(
        c.completedDate.year, c.completedDate.month, c.completedDate.day);
    if (date.isBefore(start) || date.isAfter(end)) continue;
    if (c.isSkipped || c.isPostponed) continue;
    if (habit.isTimer && c.actualDurationMinutes != null) {
      sessionCount++;
      sessionTotal += c.actualDurationMinutes!.toDouble();
    } else if (habit.isNumeric && c.actualValue != null) {
      sessionCount++;
      sessionTotal += c.actualValue!;
    } else if (!habit.isTimer && !habit.isNumeric && c.count > 0) {
      sessionCount++;
      sessionTotal += c.count.toDouble();
    }
  }

  final active = days.length - inactive;
  final avgPerDay = active <= 0 ? 0.0 : totalValue / active;
  final avgPerSession =
      sessionCount == 0 ? 0.0 : sessionTotal / sessionCount;
  final goal = _expectedInRange(habit, start, end);
  final effectiveGoal =
      goal > 0 ? goal : math.max(1, done + partial + skipped);
  final weighted = done + partial * 0.6 + skipped * 0.3;
  final score =
      (weighted / effectiveGoal * 100).clamp(0.0, 100.0).toDouble();

  return _TrendSummary(
    done: done,
    partial: partial,
    skipped: skipped,
    missed: missed,
    open: open,
    inactive: inactive,
    goalCount: goal,
    activityScore: score,
    totalValue: totalValue,
    avgPerDay: avgPerDay,
    avgPerSession: avgPerSession,
    sessionCount: sessionCount,
  );
}

_TrendDay _dayEntry({
  required Habit habit,
  required DateTime date,
  required List<HabitCompletion> completions,
}) {
  final target = _dailyTarget(habit);
  if (!habit.isActiveOn(date) || !habit.isDueOn(date)) {
    return _TrendDay(
        date: date, value: 0, status: _DayStatus.inactive, target: target);
  }

  final hasSkip = completions.any((c) => c.isSkipped || c.isPostponed);
  final isSuccess = completions.any((c) => _isSuccess(c, habit));

  double value = 0;
  if (habit.isTimer) {
    value = completions
        .where((c) => c.actualDurationMinutes != null)
        .fold<double>(0, (s, c) => s + c.actualDurationMinutes!.toDouble());
  } else if (habit.isNumeric) {
    value = completions
        .where((c) => c.actualValue != null)
        .fold<double>(0, (s, c) => s + c.actualValue!);
  } else if (habit.completionType == 'checklist') {
    value = completions.fold<double>(0, (s, c) => s + c.count.toDouble());
  } else {
    value = isSuccess ? 1 : 0;
  }

  if (isSuccess) {
    return _TrendDay(
        date: date, value: value, status: _DayStatus.done, target: target);
  }
  if (hasSkip) {
    return _TrendDay(
        date: date, value: value, status: _DayStatus.skipped, target: target);
  }
  if (_isPartial(habit, value)) {
    return _TrendDay(
        date: date, value: value, status: _DayStatus.partial, target: target);
  }
  if (completions.isNotEmpty) {
    return _TrendDay(
        date: date, value: value, status: _DayStatus.missed, target: target);
  }
  if (_isFlexibleFrequency(habit)) {
    return _TrendDay(
        date: date, value: 0, status: _DayStatus.open, target: target);
  }
  return _TrendDay(
      date: date, value: 0, status: _DayStatus.missed, target: target);
}

// ─── Logic helpers ────────────────────────────────────────────────────────

bool _isSuccess(HabitCompletion c, Habit habit) {
  if (c.isSkipped || c.isPostponed) return false;
  switch (habit.completionType) {
    case 'yesNo':
    case 'yes_no':
      return c.answer == true || c.count > 0;
    case 'numeric':
      if (c.actualValue == null) return c.count > 0 || c.answer == true;
      return c.actualValue! >= (habit.targetValue ?? 1);
    case 'timer':
      if (c.actualDurationMinutes == null) {
        return c.count > 0 || c.answer == true;
      }
      return c.actualDurationMinutes! >= (habit.targetDurationMinutes ?? 1);
    case 'checklist':
      return c.count >= (habit.checklist?.length ?? 1);
    case 'quit':
      return c.answer == true;
    default:
      return c.count > 0 || c.answer == true;
  }
}

bool _isPartial(Habit habit, double value) {
  if (habit.isNumeric) {
    final t = habit.targetValue ?? 0;
    return value > 0 && t > 0 && value < t;
  }
  if (habit.isTimer) {
    final t = habit.targetDurationMinutes ?? 0;
    return value > 0 && t > 0 && value < t;
  }
  if (habit.completionType == 'checklist') {
    final t = habit.checklist?.length ?? 0;
    return value > 0 && t > 0 && value < t;
  }
  return false;
}

bool _hasPartial(Habit habit) =>
    habit.isNumeric || habit.isTimer || habit.completionType == 'checklist';

bool _isFlexibleFrequency(Habit habit) =>
    habit.frequencyType == 'xTimesPerWeek' ||
    habit.frequencyType == 'xTimesPerMonth';

double _dailyTarget(Habit habit) {
  if (habit.isNumeric) return habit.targetValue ?? 0;
  if (habit.isTimer) return (habit.targetDurationMinutes ?? 0).toDouble();
  if (habit.completionType == 'checklist') {
    return (habit.checklist?.length ?? 0).toDouble();
  }
  return 1;
}

int _expectedInRange(Habit habit, DateTime start, DateTime end) {
  final totalDays = end.difference(start).inDays + 1;
  int dueDays = 0;
  int activeDays = 0;
  for (int i = 0; i < totalDays; i++) {
    final date = start.add(Duration(days: i));
    if (!habit.isActiveOn(date)) continue;
    activeDays++;
    if (habit.isDueOn(date)) dueDays++;
  }
  if (!_isFlexibleFrequency(habit)) return dueDays;
  final e = math.max(1, activeDays);
  switch (habit.frequencyType) {
    case 'xTimesPerWeek':
      return (e / 7 * habit.targetCount).ceil();
    case 'xTimesPerMonth':
      return (e / 30 * habit.targetCount).ceil();
    default:
      return e;
  }
}

bool _isToday(DateTime date) {
  final now = DateTime.now();
  return date.year == now.year &&
      date.month == now.month &&
      date.day == now.day;
}

// ─── Formatting helpers ───────────────────────────────────────────────────

String _formatMinutes(int m) {
  if (m <= 0) return '0m';
  final h = m ~/ 60;
  final min = m % 60;
  if (h == 0) return '${min}m';
  if (min == 0) return '${h}h';
  return '${h}h ${min}m';
}

String _fmtNum(double v, String unit) {
  final t = v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);
  return unit.isNotEmpty ? '$t $unit' : t;
}

String _fmtValue(Habit h, double v) {
  if (h.isTimer) return _formatMinutes(v.round());
  if (h.isNumeric) return _fmtNum(v, _unitLabel(h));
  return v.toInt().toString();
}

String _fmtAxis(Habit h, double v) {
  if (h.isTimer) {
    final m = v.round();
    if (m >= 60) {
      final hr = m / 60;
      return hr % 1 == 0 ? '${hr.toInt()}h' : '${hr.toStringAsFixed(1)}h';
    }
    return '${m}m';
  }
  return v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);
}

String _unitLabel(Habit h) => h.customUnitName ?? h.unit ?? '';

double _niceInterval(double maxY) =>
    maxY <= 0 ? 1.0 : (maxY / 3).clamp(0.5, double.infinity);

double _padMax(double raw) {
  if (raw <= 0) return 1.0;
  final p = raw * 1.15;
  return (p - raw) < 1.0 ? raw + 1.0 : p;
}

Color _statusColor(_DayStatus s) {
  switch (s) {
    case _DayStatus.done:
      return const Color(0xFF4CAF50);
    case _DayStatus.partial:
      return const Color(0xFFFFB347);
    case _DayStatus.skipped:
      return const Color(0xFF64B5F6);
    case _DayStatus.missed:
      return const Color(0xFFEF5350);
    case _DayStatus.open:
      return const Color(0xFF90A4AE);
    case _DayStatus.inactive:
      return const Color(0xFFBDBDBD);
  }
}

String _scoreLabel(double s) {
  if (s >= 85) return 'Excellent';
  if (s >= 70) return 'Great';
  if (s >= 55) return 'Good';
  if (s >= 40) return 'Fair';
  return 'Needs focus';
}

Color _scoreColor(double s) {
  if (s >= 85) return const Color(0xFF4CAF50);
  if (s >= 70) return const Color(0xFF66BB6A);
  if (s >= 55) return const Color(0xFFFFB347);
  if (s >= 40) return const Color(0xFFFF8A65);
  return const Color(0xFFEF5350);
}

String _dk(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
