import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/habit.dart';
import '../../data/models/temptation_log.dart';
import '../providers/temptation_log_providers.dart';
import 'log_temptation_modal.dart';

class TemptationAnalyticsTab extends ConsumerStatefulWidget {
  final Habit habit;
  final bool isDark;

  const TemptationAnalyticsTab({
    super.key,
    required this.habit,
    required this.isDark,
  });

  @override
  ConsumerState<TemptationAnalyticsTab> createState() =>
      _TemptationAnalyticsTabState();
}

class _TemptationAnalyticsTabState
    extends ConsumerState<TemptationAnalyticsTab> {
  late DateTime _weekStart;
  late DateTime _monthStart;

  Habit get habit => widget.habit;
  bool get isDark => widget.isDark;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _weekStart = _startOfWeek(now);
    _monthStart = DateTime(now.year, now.month, 1);
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(habitTemptationLogsProvider(habit.id));

    return logsAsync.when(
      data: (logs) => _buildContent(context, logs),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
    );
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  DateTime _startOfWeek(DateTime date) {
    final normalized = _dateOnly(date);
    return normalized.subtract(Duration(days: normalized.weekday - 1));
  }

  DateTime _addMonths(DateTime date, int delta) {
    final totalMonths = (date.year * 12) + (date.month - 1) + delta;
    final targetYear = totalMonths ~/ 12;
    final targetMonth = totalMonths % 12 + 1;
    return DateTime(targetYear, targetMonth, 1);
  }

  Future<void> _pickWeek(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _weekStart,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(DateTime.now().year + 5, 12, 31),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _weekStart = _startOfWeek(picked);
    });
  }

  Future<void> _pickMonth(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _monthStart,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(DateTime.now().year + 5, 12, 31),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _monthStart = DateTime(picked.year, picked.month, 1);
    });
  }

  void _moveWeek(int delta) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: delta * 7));
    });
  }

  void _moveMonth(int delta) {
    setState(() {
      _monthStart = _addMonths(_monthStart, delta);
    });
  }

  void _goToCurrentWeek() {
    setState(() {
      _weekStart = _startOfWeek(DateTime.now());
    });
  }

  void _goToCurrentMonth() {
    final now = DateTime.now();
    setState(() {
      _monthStart = DateTime(now.year, now.month, 1);
    });
  }

  Widget _buildContent(BuildContext context, List<TemptationLog> logs) {
    if (logs.isEmpty) {
      return _buildEmptyState(context);
    }

    final dailyCounts = _buildDailyCounts(logs);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final totalCount = logs.fold<int>(0, (sum, log) => sum + log.count);
    final todayCount = _sumCountsForRange(dailyCounts, today, today);

    final reasonCounts = _buildReasonCounts(logs);
    final sortedReasons = reasonCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topReasons = sortedReasons.take(5).toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildModernOverview(todayCount, totalCount),
          const SizedBox(height: 24),
          _buildSectionTitle('ACTIVITY TRENDS'),
          const SizedBox(height: 12),
          TemptationWeeklyBarChart(
            habit: habit,
            isDark: isDark,
            dailyCounts: dailyCounts,
            weekStart: _weekStart,
            onPreviousWeek: () => _moveWeek(-1),
            onNextWeek: () => _moveWeek(1),
            onCurrentWeek: _goToCurrentWeek,
            onPickWeek: () => _pickWeek(context),
          ),
          const SizedBox(height: 24),
          TemptationMonthlyTrendChart(
            habit: habit,
            isDark: isDark,
            dailyCounts: dailyCounts,
            monthStart: _monthStart,
            onPreviousMonth: () => _moveMonth(-1),
            onNextMonth: () => _moveMonth(1),
            onCurrentMonth: _goToCurrentMonth,
            onPickMonth: () => _pickMonth(context),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('TRIGGER ANALYSIS'),
          const SizedBox(height: 12),
          _buildTriggerBreakdownCard(topReasons, totalCount),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sentiment_satisfied_alt_rounded,
              size: 52,
              color: habit.color.withOpacity(0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'No temptations logged yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1E1E1E),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Log temptations to see daily and monthly trends.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white54 : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: () {
                LogTemptationModal.show(
                  context,
                  habit: habit,
                  habitId: habit.id,
                  habitTitle: habit.title,
                  onLogged: () =>
                      ref.invalidate(habitTemptationLogsProvider(habit.id)),
                );
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Log a temptation'),
              style: TextButton.styleFrom(foregroundColor: habit.color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernOverview(int todayCount, int totalCount) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            habit.color.withOpacity(0.15),
            habit.color.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: habit.color.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildModernStatItem('TODAY', '$todayCount', habit.color),
              Container(
                height: 40,
                width: 1.5,
                color: habit.color.withOpacity(0.2),
              ),
              _buildModernStatItem('ALL TIME', '$totalCount', habit.color),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : Colors.white54,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 16, color: habit.color.withOpacity(0.8)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Fewer temptations keep the trend line steady.',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : Colors.black,
            letterSpacing: -1,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
          color: isDark ? Colors.white38 : Colors.black38,
        ),
      ),
    );
  }

  Widget _buildTriggerBreakdownCard(
    List<MapEntry<String, int>> topReasons,
    int totalCount,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF24282F) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_rounded, color: habit.color, size: 20),
              const SizedBox(width: 10),
              Text(
                'TOP TRIGGERS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (topReasons.isEmpty)
            Text(
              'No trigger data yet.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white54 : Colors.grey[600],
              ),
            )
          else
            ...topReasons.map((entry) {
              final percent = totalCount > 0 ? entry.value / totalCount : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.key,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${entry.value}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: habit.color,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(percent * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white38 : Colors.black38,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Stack(
                      children: [
                        Container(
                          height: 8,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.05)
                                : Colors.black.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: percent,
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  habit.color.withOpacity(0.7),
                                  habit.color,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: habit.color.withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Map<String, int> _buildDailyCounts(List<TemptationLog> logs) {
    final counts = <String, int>{};
    for (final log in logs) {
      final key = DateFormat('yyyy-MM-dd').format(log.occurredAt);
      counts[key] = (counts[key] ?? 0) + log.count;
    }
    return counts;
  }

  int _sumCountsForRange(
    Map<String, int> dailyCounts,
    DateTime start,
    DateTime end,
  ) {
    final startDate = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);
    var total = 0;
    var cursor = startDate;
    while (!cursor.isAfter(endDate)) {
      final key = DateFormat('yyyy-MM-dd').format(cursor);
      total += dailyCounts[key] ?? 0;
      cursor = cursor.add(const Duration(days: 1));
    }
    return total;
  }

  Map<String, int> _buildReasonCounts(List<TemptationLog> logs) {
    final reasons = <String, int>{};
    for (final log in logs) {
      final raw = (log.reasonText ?? 'Unknown').trim();
      final reason = raw.isEmpty ? 'Unknown' : raw;
      reasons[reason] = (reasons[reason] ?? 0) + log.count;
    }
    return reasons;
  }
}

class TemptationWeeklyBarChart extends StatelessWidget {
  final Habit habit;
  final bool isDark;
  final Map<String, int> dailyCounts;
  final DateTime weekStart;
  final VoidCallback onPreviousWeek;
  final VoidCallback onNextWeek;
  final VoidCallback onCurrentWeek;
  final VoidCallback onPickWeek;

  const TemptationWeeklyBarChart({
    super.key,
    required this.habit,
    required this.isDark,
    required this.dailyCounts,
    required this.weekStart,
    required this.onPreviousWeek,
    required this.onNextWeek,
    required this.onCurrentWeek,
    required this.onPickWeek,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final currentWeekStart = today.subtract(Duration(days: today.weekday - 1));
    final normalizedWeekStart = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day,
    );
    final weekDays = List<DateTime>.generate(
      7,
      (index) => normalizedWeekStart.add(Duration(days: index)),
    );
    final isCurrentWeek = normalizedWeekStart == currentWeekStart;
    final rangeLabel =
        '${DateFormat('MMM d').format(weekDays.first)} - ${DateFormat('MMM d, yyyy').format(weekDays.last)}';

    final dayData = weekDays.map((date) {
      final key = DateFormat('yyyy-MM-dd').format(date);
      final count = dailyCounts[key] ?? 0;
      return (date: date, count: count);
    }).toList();

    final maxCount = dayData.map((d) => d.count).fold(0, (a, b) => a > b ? a : b);
    final effectiveMax = maxCount < 1 ? 1 : maxCount;
    final totalWeek = dayData.fold<int>(0, (sum, d) => sum + d.count);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF24282F) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: habit.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.calendar_view_week_rounded,
                        color: habit.color, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'WEEKLY',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  _PeriodNavIconButton(
                    icon: Icons.chevron_left_rounded,
                    onTap: onPreviousWeek,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 4),
                  _PeriodNavIconButton(
                    icon: Icons.chevron_right_rounded,
                    onTap: onNextWeek,
                    isDark: isDark,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: onPickWeek,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    children: [
                      Text(
                        rangeLabel,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (!isCurrentWeek)
                        Text(
                          'Tap to return to current week',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: habit.color,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSummaryChip(
                icon: Icons.psychology_rounded,
                value: '$totalWeek',
                label: 'total',
                color: habit.color,
                isDark: isDark,
              ),
              _buildSummaryChip(
                icon: Icons.show_chart_rounded,
                value: (totalWeek / 7).toStringAsFixed(1),
                label: 'avg/day',
                color: isDark ? Colors.white70 : Colors.black54,
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 140,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = (constraints.maxWidth / 7)
                    .clamp(30.0, 46.0)
                    .toDouble();
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: dayData.map((data) {
                    final isToday = data.date.day == now.day &&
                        data.date.month == now.month &&
                        data.date.year == now.year;
                    final hasValue = data.count > 0;
                    final maxBarHeight = constraints.maxHeight - 50;
                    final barHeight = hasValue
                        ? ((data.count / effectiveMax) * (maxBarHeight - 10))
                            .clamp(12.0, maxBarHeight - 10)
                        : 6.0;

                    return SizedBox(
                      width: itemWidth,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOutCubic,
                            width: 24,
                            height: barHeight,
                            decoration: BoxDecoration(
                              gradient: hasValue
                                  ? LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        habit.color.withOpacity(0.7),
                                        habit.color,
                                      ],
                                    )
                                  : null,
                              color: hasValue
                                  ? null
                                  : (isDark
                                      ? Colors.white.withOpacity(0.08)
                                      : Colors.black.withOpacity(0.06)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: isToday
                                ? BoxDecoration(
                                    color: habit.color.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  )
                                : null,
                            child: Text(
                              DateFormat('E').format(data.date).substring(0, 2),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: isToday ? FontWeight.w900 : FontWeight.w700,
                                color: isToday
                                    ? habit.color
                                    : (isDark ? Colors.white54 : Colors.black54),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryChip({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
        ],
      ),
    );
  }
}

class TemptationMonthlyTrendChart extends StatelessWidget {
  final Habit habit;
  final bool isDark;
  final Map<String, int> dailyCounts;
  final DateTime monthStart;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onCurrentMonth;
  final VoidCallback onPickMonth;

  const TemptationMonthlyTrendChart({
    super.key,
    required this.habit,
    required this.isDark,
    required this.dailyCounts,
    required this.monthStart,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onCurrentMonth,
    required this.onPickMonth,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final normalizedMonthStart = DateTime(monthStart.year, monthStart.month, 1);
    final isCurrentMonth =
        normalizedMonthStart.year == now.year &&
        normalizedMonthStart.month == now.month;
    final daysInMonth = DateTime(
      normalizedMonthStart.year,
      normalizedMonthStart.month + 1,
      0,
    ).day;
    final monthLabel = DateFormat('MMMM yyyy').format(normalizedMonthStart);
    final monthDays = List<DateTime>.generate(
      daysInMonth,
      (index) => DateTime(
        normalizedMonthStart.year,
        normalizedMonthStart.month,
        index + 1,
      ),
    );

    final spots = monthDays.asMap().entries.map((entry) {
      final key = DateFormat('yyyy-MM-dd').format(entry.value);
      final count = dailyCounts[key] ?? 0;
      return MapEntry(entry.key.toDouble(), count.toDouble());
    }).toList();

    final maxCount = spots.map((s) => s.value).fold(0.0, (a, b) => a > b ? a : b);
    final effectiveMaxY = maxCount < 5 ? 5.0 : maxCount + 2;

    // Invert the spots for the visual "down" effect
    final invertedSpots = spots.map((s) {
      return FlSpot(s.key, effectiveMaxY - s.value);
    }).toList();

    final totalMonth = spots.fold<double>(0, (sum, s) => sum + s.value).toInt();
    final activeDays = spots.where((s) => s.value > 0).length;
    final bottomInterval = daysInMonth <= 15 ? 2.0 : (daysInMonth <= 22 ? 3.0 : 5.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF24282F) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: habit.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.trending_down_rounded,
                        color: habit.color, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'MONTHLY TREND',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  _PeriodNavIconButton(
                    icon: Icons.chevron_left_rounded,
                    onTap: onPreviousMonth,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 4),
                  _PeriodNavIconButton(
                    icon: Icons.chevron_right_rounded,
                    onTap: onNextMonth,
                    isDark: isDark,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: onPickMonth,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    children: [
                      Text(
                        monthLabel,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (!isCurrentMonth)
                        Text(
                          'Tap to return to current month',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: habit.color,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatBadge('$totalMonth', 'total', habit.color, isDark),
              _buildStatBadge(
                '$activeDays',
                'active days',
                isDark ? Colors.white70 : Colors.black54,
                isDark,
              ),
              _buildStatBadge(
                (totalMonth / daysInMonth).toStringAsFixed(1),
                'avg/day',
                isDark ? Colors.white70 : Colors.black54,
                isDark,
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
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
                    tooltipRoundedRadius: 10,
                    tooltipPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final date = monthDays[spot.x.toInt()];
                        final actualValue = effectiveMaxY - spot.y;
                        return LineTooltipItem(
                          '${DateFormat('MMM d').format(date)}\n',
                          TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          children: [
                            TextSpan(
                              text: '${actualValue.toInt()} temptations',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: habit.color,
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
                  horizontalInterval: 2,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: isDark ? Colors.white10 : Colors.black12,
                      strokeWidth: 1,
                      dashArray: [5, 5],
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: effectiveMaxY > 4 ? (effectiveMaxY / 4).ceilToDouble() : 1,
                      getTitlesWidget: (value, meta) {
                        final actualValue = effectiveMaxY - value;
                        if (actualValue < 0) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(
                            actualValue.toInt().toString(),
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? Colors.white38 : Colors.black45,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: bottomInterval,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= monthDays.length) {
                          return const SizedBox.shrink();
                        }
                        final date = monthDays[index];
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '${date.day}',
                            style: TextStyle(
                              fontSize: 9,
                              color: isDark ? Colors.white38 : Colors.black45,
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
                    spots: invertedSpots,
                    isCurved: true,
                    color: habit.color,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        final actualValue = effectiveMaxY - spot.y;
                        return FlDotCirclePainter(
                          radius: actualValue > 0 ? 3 : 0,
                          color: habit.color,
                          strokeWidth: 1.5,
                          strokeColor: isDark ? const Color(0xFF24282F) : Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          habit.color.withOpacity(0.3),
                          habit.color.withOpacity(0.05),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(String value, String label, Color color, bool isDark) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
        ),
      ],
    );
  }
}

class _PeriodNavIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;

  const _PeriodNavIconButton({
    required this.icon,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isDark ? Colors.white70 : Colors.black54,
        ),
      ),
    );
  }
}
