import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/dark_gradient.dart';
import '../../data/models/sleep_record.dart';
import '../../data/models/day_sleep_summary.dart';
import '../providers/sleep_providers.dart';
import 'sleep_history_screen.dart';

/// Sleep Calendar Screen - Full-screen interactive calendar for sleep history
/// Mirrors Habit Calendar architecture with quality heatmap and record list.
class SleepCalendarScreen extends ConsumerStatefulWidget {
  const SleepCalendarScreen({super.key});

  @override
  ConsumerState<SleepCalendarScreen> createState() =>
      _SleepCalendarScreenState();
}

class _SleepCalendarScreenState extends ConsumerState<SleepCalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();
  bool _showHeatmap = true;

  static const Color _gold = Color(0xFFCDAF56);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final recordsAsync = ref.watch(sleepRecordsProvider);

    return Scaffold(
      body: isDark
          ? DarkGradient.wrap(
              child: _buildContent(context, isDark, recordsAsync),
            )
          : _buildContent(context, isDark, recordsAsync),
    );
  }

  Widget _buildContent(
    BuildContext context,
    bool isDark,
    AsyncValue<List<SleepRecord>> recordsAsync,
  ) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Sleep Calendar'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _showHeatmap ? Icons.gradient_rounded : Icons.grid_view_rounded,
              color: _showHeatmap ? _gold : null,
            ),
            onPressed: () {
              setState(() => _showHeatmap = !_showHeatmap);
              HapticFeedback.lightImpact();
            },
            tooltip: _showHeatmap ? 'Hide Quality Heatmap' : 'Show Quality Heatmap',
          ),
          IconButton(
            icon: const Icon(Icons.today_rounded),
            onPressed: () {
              setState(() {
                _focusedDay = DateTime.now();
                _selectedDay = DateTime.now();
              });
              HapticFeedback.mediumImpact();
            },
            tooltip: 'Go to Today',
          ),
        ],
      ),
      body: recordsAsync.when(
        data: (records) {
          final selectedRawDay = _selectedDay ?? DateTime.now();
          final selectedDay = DateTime(
            selectedRawDay.year,
            selectedRawDay.month,
            selectedRawDay.day,
          );
          final dayRecordsAsync = ref.watch(
            sleepRecordsByDateProvider(selectedDay),
          );
          final monthlySummaryAsync = ref.watch(
            monthlySleepCalendarProvider((
              year: _focusedDay.year,
              month: _focusedDay.month,
            )),
          );
          final monthlySummary = monthlySummaryAsync.maybeWhen(
            data: (s) => s,
            orElse: () => <DateTime, DaySleepSummary>{},
          );

          return CustomScrollView(
            physics: const ClampingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _buildCalendarCard(isDark, monthlySummary),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverToBoxAdapter(
                child: _buildDayHeader(isDark, selectedDay),
              ),
              SliverToBoxAdapter(
                child: _buildDaySummaryCard(
                  isDark,
                  selectedDay,
                  monthlySummary,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Records',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white54 : Colors.black54,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
              dayRecordsAsync.when(
                data: (dayRecords) {
                  if (dayRecords.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyDayState(isDark),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildRecordTile(
                          context,
                          isDark,
                          dayRecords[index],
                        ),
                        childCount: dayRecords.length,
                      ),
                    ),
                  );
                },
                loading: () => const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, _) => SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text('Error: $err')),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildCalendarCard(
    bool isDark,
    Map<DateTime, DaySleepSummary> monthlySummary,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D3139).withOpacity(0.5) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TableCalendar<DaySleepSummary>(
            firstDay: DateTime.now().subtract(const Duration(days: 365 * 2)),
            lastDay: DateTime.now().add(const Duration(days: 365)),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            rowHeight: 60,
            daysOfWeekHeight: 40,
            startingDayOfWeek: StartingDayOfWeek.monday,
            onDaySelected: (selectedDay, focusedDay) {
              if (!isSameDay(_selectedDay, selectedDay)) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
                HapticFeedback.lightImpact();
              }
            },
            onFormatChanged: (format) {
              if (_calendarFormat != format) {
                setState(() => _calendarFormat = format);
              }
            },
            onPageChanged: (focusedDay) {
              setState(() => _focusedDay = focusedDay);
            },
            headerStyle: HeaderStyle(
              titleCentered: true,
              formatButtonVisible: false,
              leftChevronIcon: const Icon(Icons.chevron_left_rounded, color: _gold),
              rightChevronIcon: const Icon(Icons.chevron_right_rounded, color: _gold),
              titleTextFormatter: (date, locale) => '',
              headerPadding: const EdgeInsets.symmetric(vertical: 4),
            ),
            calendarBuilders: CalendarBuilders(
              headerTitleBuilder: (context, date) {
                return Column(
                  children: [
                    Text(
                      DateFormat('MMMM').format(date),
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      DateFormat('yyyy').format(date),
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black54,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );
              },
              dowBuilder: (context, day) {
                final text = DateFormat.E().format(day);
                final isWeekend =
                    day.weekday == DateTime.saturday ||
                    day.weekday == DateTime.sunday;
                return Center(
                  child: Text(
                    text,
                    style: TextStyle(
                      color: isWeekend
                          ? _gold
                          : (isDark ? Colors.white38 : Colors.black38),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                );
              },
              defaultBuilder: (context, day, focusedDay) => _buildDayCell(
                day,
                isDark,
                monthlySummary: monthlySummary,
              ),
              todayBuilder: (context, day, focusedDay) => _buildDayCell(
                day,
                isDark,
                isToday: true,
                monthlySummary: monthlySummary,
              ),
              selectedBuilder: (context, day, focusedDay) => _buildDayCell(
                day,
                isDark,
                isSelected: true,
                monthlySummary: monthlySummary,
              ),
              outsideBuilder: (context, day, focusedDay) =>
                  _buildDayCell(day, isDark, isOutside: true),
            ),
          ),
          if (_showHeatmap) _buildHeatmapLegend(isDark),
        ],
      ),
    );
  }

  Widget _buildDayCell(
    DateTime date,
    bool isDark, {
    bool isSelected = false,
    bool isToday = false,
    bool isOutside = false,
    Map<DateTime, DaySleepSummary>? monthlySummary,
  }) {
    final dateKey = DateTime(date.year, date.month, date.day);
    final summary = monthlySummary?[dateKey];
    final isFuture = date.isAfter(DateTime.now());

    Color? progressColor;
    if (_showHeatmap &&
        summary != null &&
        summary.hasData &&
        !isFuture &&
        !isOutside) {
      progressColor = summary.qualityColor;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D24) : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: progressColor != null
            ? Border.all(color: progressColor, width: 2)
            : (isSelected ? Border.all(color: _gold, width: 2) : null),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                color: isOutside
                    ? (isDark ? Colors.white10 : Colors.black12)
                    : (isFuture
                        ? (isDark ? Colors.white24 : Colors.black26)
                        : (isDark ? Colors.white : Colors.black87)),
                fontWeight: isSelected || isToday ? FontWeight.w900 : FontWeight.w600,
                fontSize: 16,
              ),
            ),
            if (summary != null && summary.hasData && !isOutside && !isFuture)
              Text(
                summary.grade,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: summary.qualityColor,
                ),
              ),
            if (summary != null && summary.hasNap && !isOutside && !isFuture)
              Icon(
                Icons.bolt_rounded,
                size: 10,
                color: _gold.withOpacity(0.8),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeatmapLegend(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.03)
            : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildLegendItem('Poor', Colors.red, isDark),
          _buildLegendItem('Fair', Colors.orange, isDark),
          _buildLegendItem('Good', Colors.green, isDark),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color.withOpacity(0.6),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildDayHeader(bool isDark, DateTime selectedDay) {
    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);
    final canGoNext = selectedDay.isBefore(todayOnly);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              final prevDay = selectedDay.subtract(const Duration(days: 1));
              setState(() {
                _selectedDay = prevDay;
                _focusedDay = prevDay;
              });
              HapticFeedback.lightImpact();
            },
            icon: Icon(
              Icons.chevron_left_rounded,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  DateFormat('EEEE').format(selectedDay),
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black54,
                    fontSize: 12,
                  ),
                ),
                Text(
                  DateFormat('MMMM d, yyyy').format(selectedDay),
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: canGoNext
                ? () {
                    final nextDay = selectedDay.add(const Duration(days: 1));
                    setState(() {
                      _selectedDay = nextDay;
                      _focusedDay = nextDay;
                    });
                    HapticFeedback.lightImpact();
                  }
                : null,
            icon: Icon(
              Icons.chevron_right_rounded,
              color: canGoNext
                  ? (isDark ? Colors.white54 : Colors.black54)
                  : (isDark ? Colors.white12 : Colors.black12),
            ),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildDaySummaryCard(
    bool isDark,
    DateTime selectedDay,
    Map<DateTime, DaySleepSummary> monthlySummary,
  ) {
    final dateKey = DateTime(
      selectedDay.year,
      selectedDay.month,
      selectedDay.day,
    );
    final summary = monthlySummary[dateKey];
    final isFuture = selectedDay.isAfter(DateTime.now());

    if (isFuture) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _buildSummaryPlaceholder(isDark, 'Future', Icons.schedule_rounded),
      );
    }
    if (summary == null || !summary.hasData) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _buildSummaryPlaceholder(
          isDark,
          'No Data',
          Icons.history_toggle_off_rounded,
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D3139).withOpacity(0.6) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: summary.qualityColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: summary.qualityColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                summary.grade,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: summary.qualityColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${summary.totalHours.toStringAsFixed(1)}h sleep',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Score ${summary.avgScore.round()}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: summary.qualityColor,
                      ),
                    ),
                    if (summary.goalMet) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.check_circle_rounded,
                        size: 14,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Goal met',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                    if (summary.hasNap) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.bolt_rounded, size: 12, color: _gold),
                      const SizedBox(width: 4),
                      Text(
                        'Nap',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _gold,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryPlaceholder(bool isDark, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: isDark ? Colors.white54 : Colors.black54),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.black54,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyDayState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bedtime_rounded,
            size: 48,
            color: isDark ? Colors.white12 : Colors.black12,
          ),
          const SizedBox(height: 16),
          Text(
            'No sleep records for this day',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => SleepHistoryScreen(
                    openNewLogOnMount: true,
                    initialDateForNewLog: _selectedDay,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.add_rounded, size: 18, color: _gold),
            label: const Text(
              'Log Sleep',
              style: TextStyle(
                color: _gold,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordTile(
    BuildContext context,
    bool isDark,
    SleepRecord record,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D3139) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.grey.withOpacity(0.1),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => SleepHistoryScreen(
                  recordIdToEditOnMount: record.id,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: record.qualityColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      record.scoreGradeDisplay,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: record.qualityColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            record.isNap
                                ? Icons.bolt_rounded
                                : Icons.bedtime_rounded,
                            size: 14,
                            color: _gold,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            record.formattedDuration,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${DateFormat.jm().format(record.bedTime)} – ${DateFormat.jm().format(record.wakeTime)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
