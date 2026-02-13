import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../data/models/habit.dart';
import '../../data/models/habit_statistics.dart';

/// View mode for the chart
enum ChartViewMode { weekly, monthly }

/// Interactive Progress Chart with Weekly/Monthly modes,
/// Fullscreen support, and Zoom capabilities
class InteractiveProgressChart extends StatefulWidget {
  final HabitStatistics statistics;
  final Habit habit;
  final bool isDark;

  const InteractiveProgressChart({
    super.key,
    required this.statistics,
    required this.habit,
    required this.isDark,
  });

  @override
  State<InteractiveProgressChart> createState() =>
      _InteractiveProgressChartState();
}

class _InteractiveProgressChartState extends State<InteractiveProgressChart>
    with SingleTickerProviderStateMixin {
  ChartViewMode _viewMode = ChartViewMode.weekly;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleViewMode() {
    setState(() {
      _viewMode = _viewMode == ChartViewMode.weekly
          ? ChartViewMode.monthly
          : ChartViewMode.weekly;
    });
    _animationController.reset();
    _animationController.forward();
  }

  void _openFullScreen() {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FullScreenChartModal(
            statistics: widget.statistics,
            habit: widget.habit,
            isDark: widget.isDark,
            initialMode: _viewMode,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.9, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _ChartCard(
      isDark: widget.isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with mode toggle and fullscreen button
          _buildHeader(),
          const SizedBox(height: 16),
          // Summary stats
          _buildSummaryRow(),
          const SizedBox(height: 20),
          // Chart - use AnimatedSwitcher for smooth transitions
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.05, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: _viewMode == ChartViewMode.weekly
                ? _WeeklyBarChart(
                    key: const ValueKey('weekly'),
                    statistics: widget.statistics,
                    habit: widget.habit,
                    isDark: widget.isDark,
                    animation: _animation,
                  )
                : _MonthlyLineChart(
                    key: const ValueKey('monthly'),
                    statistics: widget.statistics,
                    habit: widget.habit,
                    isDark: widget.isDark,
                    animation: _animation,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        // Icon
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                widget.habit.color.withOpacity(0.2),
                widget.habit.color.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _viewMode == ChartViewMode.weekly
                ? Icons.calendar_view_week_rounded
                : Icons.calendar_month_rounded,
            color: widget.habit.color,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        // Title
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _viewMode == ChartViewMode.weekly
                    ? 'Weekly Progress'
                    : 'Monthly Progress',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: widget.isDark ? Colors.white : Colors.black87,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                _viewMode == ChartViewMode.weekly
                    ? 'Last 7 days'
                    : 'Last 30 days',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: widget.isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
        ),
        // Toggle button
        _ModeToggleButton(
          isWeekly: _viewMode == ChartViewMode.weekly,
          habitColor: widget.habit.color,
          isDark: widget.isDark,
          onToggle: _toggleViewMode,
        ),
        const SizedBox(width: 8),
        // Fullscreen button
        _IconActionButton(
          icon: Icons.fullscreen_rounded,
          habitColor: widget.habit.color,
          isDark: widget.isDark,
          onTap: _openFullScreen,
          tooltip: 'Full screen',
        ),
      ],
    );
  }

  Widget _buildSummaryRow() {
    final now = DateTime.now();
    int totalCompletions = 0;
    int activeDays = 0;

    if (_viewMode == ChartViewMode.weekly) {
      for (int i = 0; i < 7; i++) {
        final date = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: i));
        final key = DateFormat('yyyy-MM-dd').format(date);
        final count = widget.statistics.dailyCompletions[key] ?? 0;
        totalCompletions += count;
        if (count > 0) activeDays++;
      }
    } else {
      for (int i = 0; i < 30; i++) {
        final date = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: i));
        final key = DateFormat('yyyy-MM-dd').format(date);
        final count = widget.statistics.dailyCompletions[key] ?? 0;
        totalCompletions += count;
        if (count > 0) activeDays++;
      }
    }

    final totalDays = _viewMode == ChartViewMode.weekly ? 7 : 30;
    final consistencyPercent = (activeDays / totalDays * 100).round();
    
    // Build type-specific summary chips
    final chips = <Widget>[];
    
    // For Quit habits, show special metrics
    if (widget.habit.isQuitHabit) {
      chips.addAll([
        Expanded(
          child: _SummaryChip(
            icon: Icons.shield_rounded,
            value: '${widget.statistics.currentStreak}',
            label: 'clean days',
            color: const Color(0xFF4CAF50),
            isDark: widget.isDark,
          ),
        ),
        const SizedBox(width: 8),
        if (widget.habit.costTrackingEnabled == true &&
            widget.statistics.moneySaved != null &&
            widget.statistics.moneySaved! > 0)
          Expanded(
            child: _SummaryChip(
              icon: Icons.savings_rounded,
              value: widget.habit.formatCurrency(widget.statistics.moneySaved!),
              label: 'saved',
              color: const Color(0xFF66BB6A),
              isDark: widget.isDark,
            ),
          )
        else
          Expanded(
            child: _SummaryChip(
              icon: Icons.block_rounded,
              value: '${widget.statistics.slipsCount ?? 0}',
              label: 'slips',
              color: const Color(0xFFFF6B6B),
              isDark: widget.isDark,
            ),
          ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryChip(
            icon: Icons.psychology_rounded,
            value: '${widget.statistics.resistanceCount ?? 0}',
            label: 'resisted',
            color: widget.habit.color,
            isDark: widget.isDark,
          ),
        ),
      ]);
    }
    // For Timer habits, show duration metrics
    else if (widget.habit.completionType == 'timer') {
      final minutes = _viewMode == ChartViewMode.weekly 
          ? widget.statistics.minutesThisWeek ?? 0
          : widget.statistics.minutesThisMonth ?? 0;
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      final durationStr = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';
      
      chips.addAll([
        Expanded(
          child: _SummaryChip(
            icon: Icons.timer_rounded,
            value: durationStr,
            label: 'total time',
            color: const Color(0xFF4CAF50),
            isDark: widget.isDark,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryChip(
            icon: Icons.local_fire_department_rounded,
            value: '${widget.statistics.currentStreak}',
            label: 'streak',
            color: const Color(0xFFFF6B6B),
            isDark: widget.isDark,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryChip(
            icon: Icons.percent_rounded,
            value: '$consistencyPercent%',
            label: 'active',
            color: widget.habit.color,
            isDark: widget.isDark,
          ),
        ),
      ]);
    }
    // For Numeric habits, show value metrics
    else if (widget.habit.completionType == 'numeric') {
      final value = _viewMode == ChartViewMode.weekly 
          ? widget.statistics.totalValueThisWeek ?? 0
          : widget.statistics.totalValueThisMonth ?? 0;
      final unit = widget.habit.customUnitName ?? widget.habit.unit ?? '';
      
      chips.addAll([
        Expanded(
          child: _SummaryChip(
            icon: Icons.analytics_rounded,
            value: value % 1 == 0 ? '${value.toInt()}' : value.toStringAsFixed(1),
            label: unit.isNotEmpty ? unit : 'total',
            color: const Color(0xFF4CAF50),
            isDark: widget.isDark,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryChip(
            icon: Icons.local_fire_department_rounded,
            value: '${widget.statistics.currentStreak}',
            label: 'streak',
            color: const Color(0xFFFF6B6B),
            isDark: widget.isDark,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryChip(
            icon: Icons.percent_rounded,
            value: '$consistencyPercent%',
            label: 'active',
            color: widget.habit.color,
            isDark: widget.isDark,
          ),
        ),
      ]);
    }
    // Default for Yes/No and Checklist habits
    else {
      chips.addAll([
        Expanded(
          child: _SummaryChip(
            icon: Icons.check_circle_rounded,
            value: '$totalCompletions',
            label: 'completions',
            color: const Color(0xFF4CAF50),
            isDark: widget.isDark,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryChip(
            icon: Icons.local_fire_department_rounded,
            value: '${widget.statistics.currentStreak}',
            label: 'streak',
            color: const Color(0xFFFF6B6B),
            isDark: widget.isDark,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryChip(
            icon: Icons.percent_rounded,
            value: '$consistencyPercent%',
            label: 'active',
            color: widget.habit.color,
            isDark: widget.isDark,
          ),
        ),
      ]);
    }

    return Row(children: chips);
  }
}

enum _ProgressMetric { count, minutes, value }

_ProgressMetric _metricForHabit(Habit habit) {
  switch (habit.completionType) {
    case 'timer':
      return _ProgressMetric.minutes;
    case 'numeric':
      return _ProgressMetric.value;
    default:
      return _ProgressMetric.count;
  }
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

List<({DateTime date, double value})> _buildDailySeries({
  required HabitStatistics statistics,
  required Habit habit,
  required int days,
}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final metric = _metricForHabit(habit);
  final completions = statistics.recentCompletions;

  final result = <({DateTime date, double value})>[];
  for (int i = days - 1; i >= 0; i--) {
    final date = today.subtract(Duration(days: i));
    final key = DateFormat('yyyy-MM-dd').format(date);

    double value = 0.0;
    switch (metric) {
      case _ProgressMetric.minutes:
        value = completions
            .where((c) =>
                !c.isSkipped &&
                !c.isPostponed &&
                _isSameDay(c.completedDate, date) &&
                c.actualDurationMinutes != null)
            .fold<double>(0, (sum, c) => sum + c.actualDurationMinutes!.toDouble());
        break;
      case _ProgressMetric.value:
        value = completions
            .where((c) =>
                !c.isSkipped &&
                !c.isPostponed &&
                _isSameDay(c.completedDate, date) &&
                c.actualValue != null)
            .fold<double>(0, (sum, c) => sum + c.actualValue!);
        break;
      case _ProgressMetric.count:
        // Prefer real counts (supports targetCount > 1). Fall back to
        // dailyCompletions (success markers) for edge cases.
        value = completions
            .where((c) =>
                !c.isSkipped &&
                !c.isPostponed &&
                _isSameDay(c.completedDate, date))
            .fold<double>(0, (sum, c) => sum + c.count.toDouble());
        final fallback = (statistics.dailyCompletions[key] ?? 0).toDouble();
        if (fallback > value) value = fallback;
        break;
    }

    result.add((date: date, value: value));
  }

  return result;
}

double _paddedMaxY(double rawMax) {
  if (rawMax <= 0) return 1.0;
  final padded = rawMax * 1.15;
  if ((padded - rawMax) < 1.0) return rawMax + 1.0;
  return padded;
}

double _niceInterval(double maxY) {
  if (maxY <= 0) return 1.0;
  // Keep it simple (charts are small); avoid 0 interval.
  return (maxY / 3).clamp(0.5, double.infinity);
}

String _formatTooltipValue(_ProgressMetric metric, double value, Habit habit) {
  switch (metric) {
    case _ProgressMetric.minutes:
      return _formatMinutes(value.round());
    case _ProgressMetric.value:
      final unit = habit.customUnitName ?? habit.unit ?? '';
      final numText =
          value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
      return unit.isNotEmpty ? '$numText $unit' : numText;
    case _ProgressMetric.count:
      final count = value.toInt();
      if (habit.isQuitHabit) {
        return count == 1 ? '1 clean day' : '$count clean days';
      }
      return count == 1 ? '1 completion' : '$count completions';
  }
}

String _formatMetricValue(_ProgressMetric metric, double value, Habit habit) {
  switch (metric) {
    case _ProgressMetric.minutes:
      return _formatMinutes(value.round());
    case _ProgressMetric.value:
      final unit = habit.customUnitName ?? habit.unit ?? '';
      final numText =
          value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
      return unit.isNotEmpty ? '$numText $unit' : numText;
    case _ProgressMetric.count:
      return value.toInt().toString();
  }
}

String _formatAxisTick(_ProgressMetric metric, double value, Habit habit) {
  switch (metric) {
    case _ProgressMetric.minutes:
      final minutes = value.round();
      if (minutes >= 60) {
        final hours = minutes / 60.0;
        return hours % 1 == 0 ? '${hours.toInt()}h' : '${hours.toStringAsFixed(1)}h';
      }
      return '${minutes}m';
    case _ProgressMetric.value:
      return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
    case _ProgressMetric.count:
      return value.toInt().toString();
  }
}

String _formatMinutes(int minutes) {
  if (minutes <= 0) return '0m';
  final hours = minutes ~/ 60;
  final mins = minutes % 60;
  if (hours == 0) return '${mins}m';
  if (mins == 0) return '${hours}h';
  return '${hours}h ${mins}m';
}

/// Weekly Bar Chart Widget
class _WeeklyBarChart extends StatelessWidget {
  final HabitStatistics statistics;
  final Habit habit;
  final bool isDark;
  final Animation<double> animation;

  const _WeeklyBarChart({
    super.key,
    required this.statistics,
    required this.habit,
    required this.isDark,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final metric = _metricForHabit(habit);
    final series =
        _buildDailySeries(statistics: statistics, habit: habit, days: 7);

    final rawMax =
        series.fold<double>(0, (max, p) => math.max(max, p.value));
    final maxY = _paddedMaxY(rawMax);
    final interval =
        metric == _ProgressMetric.count ? 1.0 : _niceInterval(maxY);

    return SizedBox(
      height: 160,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          return BarChart(
            BarChartData(
              minY: 0,
              maxY: maxY,
              alignment: BarChartAlignment.spaceAround,
              barTouchData: BarTouchData(
                enabled: true,
                handleBuiltInTouches: true,
                touchTooltipData: BarTouchTooltipData(
                  tooltipBgColor:
                      isDark ? const Color(0xFF2C3138) : Colors.white,
                  tooltipRoundedRadius: 12,
                  tooltipPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final index = group.x.toInt().clamp(0, series.length - 1);
                    final date = series[index].date;
                    final value = series[index].value;
                    return BarTooltipItem(
                      '${DateFormat('EEE, MMM d').format(date)}\n',
                      TextStyle(
                        color: isDark ? Colors.white54 : Colors.black54,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      children: [
                        TextSpan(
                          text: _formatTooltipValue(metric, value, habit),
                          style: TextStyle(
                            color: habit.color,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 34,
                    interval: interval,
                    getTitlesWidget: (value, meta) {
                      // Reduce clutter: show only 0, mid, max-ish
                      if (value == 0 || (maxY - value).abs() < interval * 0.6) {
                        return Text(
                          _formatAxisTick(metric, value, habit),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        );
                      }
                      if ((value - maxY / 2).abs() < interval * 0.6) {
                        return Text(
                          _formatAxisTick(metric, value, habit),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white24 : Colors.black26,
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt().clamp(0, series.length - 1);
                      final date = series[index].date;
                      final isToday = _isSameDay(date, DateTime.now());

                      final label = DateFormat('E').format(date).substring(0, 2);
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight:
                                isToday ? FontWeight.w900 : FontWeight.w700,
                            color: isToday
                                ? habit.color
                                : (isDark ? Colors.white38 : Colors.black38),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: interval,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.05),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(series.length, (index) {
                final date = series[index].date;
                final value = series[index].value;
                final isToday = _isSameDay(date, DateTime.now());
                final hasValue = value > 0;

                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: (value * animation.value).clamp(0.0, maxY),
                      width: 14,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(8),
                      ),
                      gradient: hasValue
                          ? LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: isToday
                                  ? [
                                      habit.color.withOpacity(0.85),
                                      habit.color,
                                    ]
                                  : [
                                      habit.color.withOpacity(0.65),
                                      habit.color.withOpacity(0.95),
                                    ],
                            )
                          : null,
                      color: hasValue
                          ? null
                          : (isDark
                              ? Colors.white.withOpacity(0.08)
                              : Colors.black.withOpacity(0.06)),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: maxY,
                        color: isDark
                            ? Colors.white.withOpacity(0.03)
                            : Colors.black.withOpacity(0.03),
                      ),
                    ),
                  ],
                );
              }),
            ),
            swapAnimationDuration: Duration.zero,
          );
        },
      ),
    );
  }
}

/// Monthly Line Chart Widget
class _MonthlyLineChart extends StatelessWidget {
  final HabitStatistics statistics;
  final Habit habit;
  final bool isDark;
  final Animation<double> animation;

  const _MonthlyLineChart({
    super.key,
    required this.statistics,
    required this.habit,
    required this.isDark,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final metric = _metricForHabit(habit);
    final series =
        _buildDailySeries(statistics: statistics, habit: habit, days: 30);

    final spots = series.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.value);
    }).toList();

    final rawMax = spots.fold<double>(0, (max, s) => math.max(max, s.y));
    final effectiveMaxY = _paddedMaxY(rawMax);
    final gridInterval =
        metric == _ProgressMetric.count ? 1.0 : effectiveMaxY / 4;
    final leftInterval =
        metric == _ProgressMetric.count ? 1.0 : effectiveMaxY / 2;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return SizedBox(
          height: 160,
          child: LineChart(
            LineChartData(
              maxY: effectiveMaxY,
              minY: 0,
              clipData: const FlClipData.all(),
              lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  tooltipBgColor: isDark ? const Color(0xFF2C3138) : Colors.white,
                  tooltipRoundedRadius: 12,
                  tooltipPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final index = spot.x.toInt().clamp(0, series.length - 1);
                      final date = series[index].date;
                      final value = series[index].value;
                      return LineTooltipItem(
                        '${DateFormat('MMM d').format(date)}\n',
                        TextStyle(
                          color: isDark ? Colors.white54 : Colors.black54,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        children: [
                          TextSpan(
                            text: _formatTooltipValue(metric, value, habit),
                            style: TextStyle(
                              color: habit.color,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
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
                horizontalInterval: gridInterval,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.05),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: leftInterval,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        _formatAxisTick(metric, value, habit),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    interval: 7,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= series.length) {
                        return const SizedBox();
                      }
                      final date = series[index].date;
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          DateFormat('d').format(date),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots
                      .map((s) => FlSpot(s.x, s.y * animation.value))
                      .toList(),
                  isCurved: true,
                  curveSmoothness: 0.25,
                  color: habit.color,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
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
                        color: habit.color,
                        strokeWidth: 2,
                        strokeColor: isDark
                            ? const Color(0xFF24282F)
                            : Colors.white,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        habit.color.withOpacity(0.25 * animation.value),
                        habit.color.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Full Screen Chart Modal with Zoom capabilities
class FullScreenChartModal extends StatefulWidget {
  final HabitStatistics statistics;
  final Habit habit;
  final bool isDark;
  final ChartViewMode initialMode;

  const FullScreenChartModal({
    super.key,
    required this.statistics,
    required this.habit,
    required this.isDark,
    required this.initialMode,
  });

  @override
  State<FullScreenChartModal> createState() => _FullScreenChartModalState();
}

class _FullScreenChartModalState extends State<FullScreenChartModal>
    with SingleTickerProviderStateMixin {
  late ChartViewMode _viewMode;
  final TransformationController _transformationController =
      TransformationController();
  double _currentScale = 1.0;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _viewMode = widget.initialMode;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();

    // Allow landscape for better viewing
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _animationController.dispose();
    // Reset to portrait only
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _toggleViewMode() {
    setState(() {
      _viewMode = _viewMode == ChartViewMode.weekly
          ? ChartViewMode.monthly
          : ChartViewMode.weekly;
    });
    _animationController.reset();
    _animationController.forward();
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
    setState(() {
      _currentScale = 1.0;
    });
  }

  void _zoomIn() {
    final currentMatrix = _transformationController.value.clone();
    final newScale = (_currentScale * 1.3).clamp(1.0, 4.0);
    currentMatrix.setEntry(0, 0, newScale);
    currentMatrix.setEntry(1, 1, newScale);
    _transformationController.value = currentMatrix;
    setState(() {
      _currentScale = newScale;
    });
  }

  void _zoomOut() {
    final currentMatrix = _transformationController.value.clone();
    final newScale = (_currentScale / 1.3).clamp(1.0, 4.0);
    currentMatrix.setEntry(0, 0, newScale);
    currentMatrix.setEntry(1, 1, newScale);
    _transformationController.value = currentMatrix;
    setState(() {
      _currentScale = newScale;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final bgColor = widget.isDark ? const Color(0xFF0D0F12) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isLandscape),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isLandscape ? 32 : 20,
                  vertical: 16,
                ),
                child: Column(
                  children: [
                    // Summary stats
                    _buildSummaryRow(),
                    const SizedBox(height: 20),
                    // Zoomable chart
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          decoration: BoxDecoration(
                            color: widget.isDark
                                ? const Color(0xFF1A1D22)
                                : const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: widget.isDark
                                  ? Colors.white.withOpacity(0.08)
                                  : Colors.black.withOpacity(0.05),
                            ),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: InteractiveViewer(
                            transformationController: _transformationController,
                            minScale: 1.0,
                            maxScale: 4.0,
                            // Allow panning only when zoomed in, so chart gestures
                            // (tooltips/drag) remain usable at 100%.
                            panEnabled: _currentScale > 1.0,
                            scaleEnabled: true,
                            onInteractionUpdate: (_) {
                              final nextScale = _transformationController.value
                                  .getMaxScaleOnAxis()
                                  .clamp(1.0, 4.0);
                              if ((nextScale - _currentScale).abs() > 0.01) {
                                setState(() => _currentScale = nextScale);
                              }
                            },
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 400),
                              child: _viewMode == ChartViewMode.weekly
                                  ? _FullScreenWeeklyChart(
                                      key: const ValueKey('fs_weekly'),
                                      statistics: widget.statistics,
                                      habit: widget.habit,
                                      isDark: widget.isDark,
                                      animation: _animation,
                                    )
                                  : _FullScreenMonthlyChart(
                                      key: const ValueKey('fs_monthly'),
                                      statistics: widget.statistics,
                                      habit: widget.habit,
                                      isDark: widget.isDark,
                                      animation: _animation,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Zoom controls
                    _buildZoomControls(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isLandscape) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isLandscape ? 32 : 20,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF0D0F12) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: widget.isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.05),
          ),
        ),
      ),
      child: Row(
        children: [
          // Back button
          _IconActionButton(
            icon: Icons.close_rounded,
            habitColor: widget.habit.color,
            isDark: widget.isDark,
            onTap: () => Navigator.of(context).pop(),
            tooltip: 'Close',
          ),
          const SizedBox(width: 16),
          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.habit.title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: widget.isDark ? Colors.white : Colors.black87,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _viewMode == ChartViewMode.weekly
                      ? 'Weekly Progress View'
                      : 'Monthly Progress View',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: widget.isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ],
            ),
          ),
          // Mode toggle
          _ModeToggleButton(
            isWeekly: _viewMode == ChartViewMode.weekly,
            habitColor: widget.habit.color,
            isDark: widget.isDark,
            onToggle: _toggleViewMode,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow() {
    final now = DateTime.now();
    int totalCompletions = 0;
    int activeDays = 0;
    int bestDay = 0;

    final days = _viewMode == ChartViewMode.weekly ? 7 : 30;
    for (int i = 0; i < days; i++) {
      final date =
          DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final key = DateFormat('yyyy-MM-dd').format(date);
      final count = widget.statistics.dailyCompletions[key] ?? 0;
      totalCompletions += count;
      if (count > 0) activeDays++;
      if (count > bestDay) bestDay = count;
    }

    final consistencyPercent = (activeDays / days * 100).round();
    final avgPerActiveDay =
        activeDays > 0 ? (totalCompletions / activeDays).toStringAsFixed(1) : '0';

    // Build type-specific summary chips for fullscreen
    final chips = <Widget>[];
    
    // For Quit habits
    if (widget.habit.isQuitHabit) {
      chips.addAll([
        _SummaryChip(
          icon: Icons.shield_rounded,
          value: '${widget.statistics.currentStreak}',
          label: 'clean days',
          color: const Color(0xFF4CAF50),
          isDark: widget.isDark,
        ),
        const SizedBox(width: 10),
        _SummaryChip(
          icon: Icons.emoji_events_rounded,
          value: '${widget.statistics.bestStreak}',
          label: 'best streak',
          color: const Color(0xFFFFB347),
          isDark: widget.isDark,
        ),
        const SizedBox(width: 10),
        if (widget.habit.costTrackingEnabled == true &&
            widget.statistics.moneySaved != null &&
            widget.statistics.moneySaved! > 0)
          _SummaryChip(
            icon: Icons.savings_rounded,
            value: widget.habit.formatCurrency(widget.statistics.moneySaved!),
            label: 'saved',
            color: const Color(0xFF66BB6A),
            isDark: widget.isDark,
          )
        else
          _SummaryChip(
            icon: Icons.block_rounded,
            value: '${widget.statistics.slipsCount ?? 0}',
            label: 'slips',
            color: const Color(0xFFFF6B6B),
            isDark: widget.isDark,
          ),
        const SizedBox(width: 10),
        _SummaryChip(
          icon: Icons.psychology_rounded,
          value: '${widget.statistics.resistanceCount ?? 0}',
          label: 'resisted',
          color: widget.habit.color,
          isDark: widget.isDark,
        ),
        const SizedBox(width: 10),
        if (widget.statistics.unitsAvoided != null)
          _SummaryChip(
            icon: Icons.do_not_disturb_rounded,
            value: '${widget.statistics.unitsAvoided}',
            label: 'avoided',
            color: const Color(0xFF64B5F6),
            isDark: widget.isDark,
          ),
      ]);
    }
    // For Timer habits
    else if (widget.habit.completionType == 'timer') {
      final minutes = _viewMode == ChartViewMode.weekly 
          ? widget.statistics.minutesThisWeek ?? 0
          : widget.statistics.minutesThisMonth ?? 0;
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      final durationStr = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';
      
      final avgMinutes = widget.statistics.averageMinutesPerCompletion ?? 0;
      final avgH = avgMinutes ~/ 60;
      final avgM = (avgMinutes % 60).toInt();
      final avgStr = avgH > 0 ? '${avgH}h ${avgM}m' : '${avgM}m';
      
      chips.addAll([
        _SummaryChip(
          icon: Icons.timer_rounded,
          value: durationStr,
          label: 'total time',
          color: const Color(0xFF4CAF50),
          isDark: widget.isDark,
        ),
        const SizedBox(width: 10),
        _SummaryChip(
          icon: Icons.local_fire_department_rounded,
          value: '${widget.statistics.currentStreak}',
          label: 'streak',
          color: const Color(0xFFFF6B6B),
          isDark: widget.isDark,
        ),
        const SizedBox(width: 10),
        _SummaryChip(
          icon: Icons.emoji_events_rounded,
          value: '${widget.statistics.bestStreak}',
          label: 'best streak',
          color: const Color(0xFFFFB347),
          isDark: widget.isDark,
        ),
        const SizedBox(width: 10),
        _SummaryChip(
          icon: Icons.speed_rounded,
          value: avgStr,
          label: 'avg session',
          color: const Color(0xFF64B5F6),
          isDark: widget.isDark,
        ),
        const SizedBox(width: 10),
        _SummaryChip(
          icon: Icons.percent_rounded,
          value: '$consistencyPercent%',
          label: 'active',
          color: widget.habit.color,
          isDark: widget.isDark,
        ),
      ]);
    }
    // For Numeric habits
    else if (widget.habit.completionType == 'numeric') {
      final value = _viewMode == ChartViewMode.weekly 
          ? widget.statistics.totalValueThisWeek ?? 0
          : widget.statistics.totalValueThisMonth ?? 0;
      final unit = widget.habit.customUnitName ?? widget.habit.unit ?? '';
      final avg = widget.statistics.averageValuePerCompletion ?? 0;
      
      chips.addAll([
        _SummaryChip(
          icon: Icons.analytics_rounded,
          value: value % 1 == 0 ? '${value.toInt()}' : value.toStringAsFixed(1),
          label: unit.isNotEmpty ? unit : 'total',
          color: const Color(0xFF4CAF50),
          isDark: widget.isDark,
        ),
        const SizedBox(width: 10),
        _SummaryChip(
          icon: Icons.local_fire_department_rounded,
          value: '${widget.statistics.currentStreak}',
          label: 'streak',
          color: const Color(0xFFFF6B6B),
          isDark: widget.isDark,
        ),
        const SizedBox(width: 10),
        _SummaryChip(
          icon: Icons.emoji_events_rounded,
          value: '${widget.statistics.bestStreak}',
          label: 'best streak',
          color: const Color(0xFFFFB347),
          isDark: widget.isDark,
        ),
        const SizedBox(width: 10),
        _SummaryChip(
          icon: Icons.speed_rounded,
          value: avg % 1 == 0 ? '${avg.toInt()}' : avg.toStringAsFixed(1),
          label: 'avg/$unit',
          color: const Color(0xFF64B5F6),
          isDark: widget.isDark,
        ),
        const SizedBox(width: 10),
        _SummaryChip(
          icon: Icons.percent_rounded,
          value: '$consistencyPercent%',
          label: 'active',
          color: widget.habit.color,
          isDark: widget.isDark,
        ),
      ]);
    }
    // Default for Yes/No and Checklist
    else {
      chips.addAll([
        _SummaryChip(
          icon: Icons.check_circle_rounded,
          value: '$totalCompletions',
          label: 'completions',
          color: const Color(0xFF4CAF50),
          isDark: widget.isDark,
        ),
        const SizedBox(width: 10),
        _SummaryChip(
          icon: Icons.local_fire_department_rounded,
          value: '${widget.statistics.currentStreak}',
          label: 'streak',
          color: const Color(0xFFFF6B6B),
          isDark: widget.isDark,
        ),
        const SizedBox(width: 10),
        _SummaryChip(
          icon: Icons.emoji_events_rounded,
          value: '${widget.statistics.bestStreak}',
          label: 'best streak',
          color: const Color(0xFFFFB347),
          isDark: widget.isDark,
        ),
        const SizedBox(width: 10),
        _SummaryChip(
          icon: Icons.star_rounded,
          value: '$bestDay',
          label: 'best day',
          color: widget.habit.color,
          isDark: widget.isDark,
        ),
        const SizedBox(width: 10),
        _SummaryChip(
          icon: Icons.speed_rounded,
          value: avgPerActiveDay,
          label: 'avg/day',
          color: const Color(0xFF64B5F6),
          isDark: widget.isDark,
        ),
      ]);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: chips),
    );
  }

  Widget _buildZoomControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Zoom out
          _ZoomButton(
            icon: Icons.remove_rounded,
            onTap: _currentScale > 1.0 ? _zoomOut : null,
            habitColor: widget.habit.color,
            isDark: widget.isDark,
          ),
          const SizedBox(width: 12),
          // Zoom indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: widget.isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${(_currentScale * 100).round()}%',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: widget.isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Zoom in
          _ZoomButton(
            icon: Icons.add_rounded,
            onTap: _currentScale < 4.0 ? _zoomIn : null,
            habitColor: widget.habit.color,
            isDark: widget.isDark,
          ),
          const SizedBox(width: 16),
          // Reset zoom
          _ZoomButton(
            icon: Icons.fit_screen_rounded,
            onTap: _currentScale != 1.0 ? _resetZoom : null,
            habitColor: widget.habit.color,
            isDark: widget.isDark,
          ),
        ],
      ),
    );
  }
}

/// Full screen weekly chart (larger bars)
class _FullScreenWeeklyChart extends StatelessWidget {
  final HabitStatistics statistics;
  final Habit habit;
  final bool isDark;
  final Animation<double> animation;

  const _FullScreenWeeklyChart({
    super.key,
    required this.statistics,
    required this.habit,
    required this.isDark,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final metric = _metricForHabit(habit);
    final series =
        _buildDailySeries(statistics: statistics, habit: habit, days: 7);

    final rawMax =
        series.fold<double>(0, (max, p) => math.max(max, p.value));
    final maxY = _paddedMaxY(rawMax);
    final interval =
        metric == _ProgressMetric.count ? 1.0 : _niceInterval(maxY);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return BarChart(
          BarChartData(
            minY: 0,
            maxY: maxY,
            alignment: BarChartAlignment.spaceAround,
            barTouchData: BarTouchData(
              enabled: true,
              handleBuiltInTouches: true,
              touchTooltipData: BarTouchTooltipData(
                tooltipBgColor:
                    isDark ? const Color(0xFF2C3138) : Colors.white,
                tooltipRoundedRadius: 14,
                tooltipPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final index = group.x.toInt().clamp(0, series.length - 1);
                  final date = series[index].date;
                  final value = series[index].value;
                  return BarTooltipItem(
                    '${DateFormat('EEEE, MMM d').format(date)}\n',
                    TextStyle(
                      color: isDark ? Colors.white54 : Colors.black54,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    children: [
                      TextSpan(
                        text: _formatTooltipValue(metric, value, habit),
                        style: TextStyle(
                          color: habit.color,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 46,
                  interval: interval,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      _formatAxisTick(metric, value, habit),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt().clamp(0, series.length - 1);
                    final date = series[index].date;
                    final isToday = _isSameDay(date, DateTime.now());

                    return Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        DateFormat('EEE').format(date),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isToday ? FontWeight.w900 : FontWeight.w700,
                          color: isToday
                              ? habit.color
                              : (isDark ? Colors.white54 : Colors.black54),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: interval,
              getDrawingHorizontalLine: (value) => FlLine(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.08),
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            barGroups: List.generate(series.length, (index) {
              final date = series[index].date;
              final value = series[index].value;
              final isToday = _isSameDay(date, DateTime.now());
              final hasValue = value > 0;

              return BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: (value * animation.value).clamp(0.0, maxY),
                    width: 26,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    gradient: hasValue
                        ? LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: isToday
                                ? [
                                    habit.color.withOpacity(0.85),
                                    habit.color,
                                    habit.color.withOpacity(0.95),
                                  ]
                                : [
                                    habit.color.withOpacity(0.55),
                                    habit.color.withOpacity(0.95),
                                  ],
                          )
                        : null,
                    color: hasValue
                        ? null
                        : (isDark
                            ? Colors.white.withOpacity(0.10)
                            : Colors.black.withOpacity(0.08)),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: maxY,
                      color: isDark
                          ? Colors.white.withOpacity(0.04)
                          : Colors.black.withOpacity(0.04),
                    ),
                  ),
                ],
              );
            }),
          ),
          swapAnimationDuration: Duration.zero,
        );
      },
    );
  }
}

/// Full screen monthly chart (larger, more detailed)
class _FullScreenMonthlyChart extends StatelessWidget {
  final HabitStatistics statistics;
  final Habit habit;
  final bool isDark;
  final Animation<double> animation;

  const _FullScreenMonthlyChart({
    super.key,
    required this.statistics,
    required this.habit,
    required this.isDark,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final metric = _metricForHabit(habit);
    final series =
        _buildDailySeries(statistics: statistics, habit: habit, days: 30);

    final spots = series.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.value);
    }).toList();

    final rawMax = spots.fold<double>(0, (max, s) => math.max(max, s.y));
    final maxY = _paddedMaxY(rawMax);
    final interval =
        metric == _ProgressMetric.count ? 1.0 : _niceInterval(maxY);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return LineChart(
          LineChartData(
            maxY: maxY,
            minY: 0,
            clipData: const FlClipData.all(),
            lineTouchData: LineTouchData(
              enabled: true,
              touchTooltipData: LineTouchTooltipData(
                tooltipBgColor: isDark ? const Color(0xFF2C3138) : Colors.white,
                tooltipRoundedRadius: 14,
                tooltipPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    final index = spot.x.toInt().clamp(0, series.length - 1);
                    final date = series[index].date;
                    final value = series[index].value;
                    return LineTooltipItem(
                      '${DateFormat('EEEE, MMM d').format(date)}\n',
                      TextStyle(
                        color: isDark ? Colors.white54 : Colors.black54,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      children: [
                        TextSpan(
                          text: _formatTooltipValue(metric, value, habit),
                          style: TextStyle(
                            color: habit.color,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
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
              drawVerticalLine: true,
              horizontalInterval: interval,
              verticalInterval: 7,
              getDrawingHorizontalLine: (value) => FlLine(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.08),
                strokeWidth: 1,
              ),
              getDrawingVerticalLine: (value) => FlLine(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.05),
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 35,
                  interval: interval,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      _formatAxisTick(metric, value, habit),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: 5,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= series.length) {
                      return const SizedBox();
                    }
                    final date = series[index].date;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        DateFormat('d').format(date),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots
                    .map((s) => FlSpot(s.x, s.y * animation.value))
                    .toList(),
                isCurved: true,
                curveSmoothness: 0.2,
                color: habit.color,
                barWidth: 4,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) {
                    if (spot.y == 0) {
                      return FlDotCirclePainter(
                        radius: 0,
                        color: Colors.transparent,
                        strokeWidth: 0,
                        strokeColor: Colors.transparent,
                      );
                    }
                    return FlDotCirclePainter(
                      radius: 5,
                      color: habit.color,
                      strokeWidth: 3,
                      strokeColor:
                          isDark ? const Color(0xFF1A1D22) : Colors.white,
                    );
                  },
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      habit.color.withOpacity(0.35 * animation.value),
                      habit.color.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============ Helper Widgets ============

class _ChartCard extends StatelessWidget {
  final Widget child;
  final bool isDark;

  const _ChartCard({
    required this.child,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF24282F) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.05),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color:
                isDark ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ModeToggleButton extends StatelessWidget {
  final bool isWeekly;
  final Color habitColor;
  final bool isDark;
  final VoidCallback onToggle;

  const _ModeToggleButton({
    required this.isWeekly,
    required this.habitColor,
    required this.isDark,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ToggleOption(
              label: '7D',
              isSelected: isWeekly,
              habitColor: habitColor,
              isDark: isDark,
            ),
            _ToggleOption(
              label: '30D',
              isSelected: !isWeekly,
              habitColor: habitColor,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color habitColor;
  final bool isDark;

  const _ToggleOption({
    required this.label,
    required this.isSelected,
    required this.habitColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected ? habitColor : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: isSelected
              ? Colors.white
              : (isDark ? Colors.white54 : Colors.black54),
        ),
      ),
    );
  }
}

class _IconActionButton extends StatelessWidget {
  final IconData icon;
  final Color habitColor;
  final bool isDark;
  final VoidCallback onTap;
  final String tooltip;

  const _IconActionButton({
    required this.icon,
    required this.habitColor,
    required this.isDark,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.black.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final bool isDark;

  const _SummaryChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color.withOpacity(0.7),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color habitColor;
  final bool isDark;

  const _ZoomButton({
    required this.icon,
    required this.onTap,
    required this.habitColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isEnabled
              ? habitColor.withOpacity(0.15)
              : (isDark
                  ? Colors.white.withOpacity(0.03)
                  : Colors.black.withOpacity(0.03)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isEnabled
                ? habitColor.withOpacity(0.3)
                : Colors.transparent,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isEnabled
              ? habitColor
              : (isDark ? Colors.white24 : Colors.black26),
        ),
      ),
    );
  }
}
