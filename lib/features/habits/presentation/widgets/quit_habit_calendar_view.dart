import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/habit.dart';
import '../../data/models/habit_completion.dart';
import '../../data/models/habit_statistics.dart';
import '../../data/models/temptation_log.dart';
import '../providers/temptation_log_providers.dart';
import '../providers/habit_providers.dart';

/// Status for a day in quit habit calendar
/// QUIT HABIT SPECIFIC - Uses WIN/SLIP terminology!
/// Both win and almost are SUCCESS - user didn't do the bad habit
/// Only slip is a failure
enum QuitDayStatus {
  win,           // SUCCESS: Won the day! Didn't do bad habit (easy day)
  almost,        // SUCCESS: Almost slipped, but still WON! (hard-fought victory)
  slip,          // FAILURE: Did the bad habit
  noData,        // No data for this day (but habit existed)
  future,        // Future date
  beforeCreated, // Date is before the habit was created
}

/// Data for a single day in the quit habit calendar
class QuitDayData {
  final DateTime date;
  final QuitDayStatus status;
  final List<HabitCompletion> completions;
  final List<TemptationLog> temptations;
  final int maxTemptationIntensity;
  final bool didResist;
  final String? slipReason;

  QuitDayData({
    required this.date,
    required this.status,
    this.completions = const [],
    this.temptations = const [],
    this.maxTemptationIntensity = 0,
    this.didResist = true,
    this.slipReason,
  });
}

/// Provider for monthly quit habit data
final quitHabitMonthlyDataProvider = FutureProvider.family<
    Map<DateTime, QuitDayData>,
    ({String habitId, int year, int month})>((ref, params) async {
  final repository = ref.watch(habitRepositoryProvider);
  final temptationRepo = ref.watch(temptationLogRepositoryProvider);

  // Get the habit to check startDate (user-defined start date)
  final habit = await repository.getHabitById(params.habitId);
  if (habit == null) return {};
  
  // Use startDate - the user-defined "when this habit officially begins"
  final habitStartDate = DateTime(habit.startDate.year, habit.startDate.month, habit.startDate.day);
  final lastDay = DateTime(params.year, params.month + 1, 0);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  final Map<DateTime, QuitDayData> result = {};

  for (int day = 1; day <= lastDay.day; day++) {
    final date = DateTime(params.year, params.month, day);
    final dateKey = DateTime(date.year, date.month, date.day);

    // Skip dates BEFORE the habit's start date - habit didn't begin yet!
    if (dateKey.isBefore(habitStartDate)) {
      result[dateKey] = QuitDayData(
        date: date,
        status: QuitDayStatus.beforeCreated,
      );
      continue;
    }

    // Skip future dates
    if (dateKey.isAfter(today)) {
      result[dateKey] = QuitDayData(
        date: date,
        status: QuitDayStatus.future,
      );
      continue;
    }

    // Get completions for this date
    final completions = await repository.getCompletionsForDate(params.habitId, date);
    
    // Get temptation logs for this date
    final temptations = await temptationRepo.getLogsForHabitOnDate(params.habitId, date);

    // Determine status
    QuitDayStatus status;
    String? slipReason;
    int maxIntensity = 0;
    bool didResist = true;

    // Check for slips in completions
    // For quit habits, a completion with isSkipped=true means they slipped (did the bad thing)
    final hasSlip = completions.any((c) => c.isSkipped);
    
    // Also check temptation logs for slips (didResist = false)
    final hasTemptationSlip = temptations.any((t) => !t.didResist);

    // Is this date TODAY?
    final isToday = dateKey.isAtSameMomentAs(today);

    if (hasSlip || hasTemptationSlip) {
      status = QuitDayStatus.slip;
      didResist = false;
      // Get slip reason
      final slipCompletion = completions.where((c) => c.isSkipped).firstOrNull;
      final slipTemptation = temptations.where((t) => !t.didResist).firstOrNull;
      slipReason = slipCompletion?.skipReason ?? slipTemptation?.reasonText;
    } else if (temptations.isNotEmpty) {
      // Had temptations but resisted
      maxIntensity = temptations
          .map((t) => t.intensityIndex)
          .reduce((a, b) => a > b ? a : b);

      // If intensity is strong (2) or extreme (3), mark as "almost" - still a WIN!
      if (maxIntensity >= 2) {
        status = QuitDayStatus.almost;
      } else {
        // Mild or moderate temptation, clean "not done" day
        status = QuitDayStatus.win;
      }
    } else if (completions.any((c) => !c.isSkipped && c.count > 0)) {
      // Has a successful completion (resisted/not done day marked, or auto-backfilled)
      status = QuitDayStatus.win;
    } else if (isToday) {
      // TODAY with no data = still in progress, NOT a win yet!
      // Day hasn't ended, user hasn't logged anything
      // Will be auto-backfilled as a win tomorrow if no slip is logged
      status = QuitDayStatus.noData;
    } else {
      // PAST DAY with NO DATA - this shouldn't normally happen after auto-backfill runs
      // But if it does (e.g., habit just created with backdated start), treat as no data
      // The auto-backfill will fix this on next app load
      status = QuitDayStatus.noData;
    }

    result[dateKey] = QuitDayData(
      date: date,
      status: status,
      completions: completions,
      temptations: temptations,
      maxTemptationIntensity: maxIntensity,
      didResist: didResist,
      slipReason: slipReason,
    );
  }

  return result;
});

/// Enhanced Calendar View specifically for Quit Habits
/// Shows color-coded days based on slip/clean/temptation status
class QuitHabitCalendarView extends ConsumerStatefulWidget {
  final Habit habit;
  final HabitStatistics statistics;
  final bool isDark;

  const QuitHabitCalendarView({
    super.key,
    required this.habit,
    required this.statistics,
    required this.isDark,
  });

  @override
  ConsumerState<QuitHabitCalendarView> createState() => _QuitHabitCalendarViewState();
}

class _QuitHabitCalendarViewState extends ConsumerState<QuitHabitCalendarView> {
  late DateTime _focusedMonth;
  late DateTime _focusedWeekStart; // Start of the focused week (Sunday)
  DateTime? _selectedDate;
  bool _isWeeklyView = false; // Toggle between monthly and weekly view

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = now;
    // Set to start of current week (Sunday)
    _focusedWeekStart = _getWeekStart(now);
  }

  /// Get the start of the week (Sunday) for a given date
  DateTime _getWeekStart(DateTime date) {
    final weekday = date.weekday % 7; // 0=Sunday
    return DateTime(date.year, date.month, date.day - weekday);
  }

  /// Get all 7 days of the week starting from weekStart
  List<DateTime> _getWeekDays(DateTime weekStart) {
    return List.generate(7, (i) => weekStart.add(Duration(days: i)));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // View mode toggle
        _buildViewModeToggle(),
        const SizedBox(height: 8),

        // Header with navigation
        _buildHeader(),
        const SizedBox(height: 8),

        // Legend
        _buildLegend(),
        const SizedBox(height: 16),

        // Weekday headers
        _buildWeekdayHeaders(),
        const SizedBox(height: 8),

        // Calendar content (weekly or monthly)
        Expanded(
          child: _isWeeklyView ? _buildWeeklyView() : _buildMonthlyView(),
        ),

        // Stats summary (weekly or monthly)
        _isWeeklyView ? _buildWeeklyStatsSummary() : _buildStatsSummary(),
      ],
    );
  }

  Widget _buildViewModeToggle() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: widget.isDark 
            ? Colors.white.withOpacity(0.05) 
            : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isWeeklyView = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !_isWeeklyView
                      ? widget.habit.color.withOpacity(0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: !_isWeeklyView
                      ? Border.all(color: widget.habit.color, width: 1.5)
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_month_rounded,
                      size: 16,
                      color: !_isWeeklyView
                          ? widget.habit.color
                          : (widget.isDark ? Colors.white54 : Colors.black45),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Monthly',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: !_isWeeklyView ? FontWeight.w700 : FontWeight.w500,
                        color: !_isWeeklyView
                            ? widget.habit.color
                            : (widget.isDark ? Colors.white54 : Colors.black45),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isWeeklyView = true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _isWeeklyView
                      ? widget.habit.color.withOpacity(0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: _isWeeklyView
                      ? Border.all(color: widget.habit.color, width: 1.5)
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.view_week_rounded,
                      size: 16,
                      color: _isWeeklyView
                          ? widget.habit.color
                          : (widget.isDark ? Colors.white54 : Colors.black45),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Weekly',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _isWeeklyView ? FontWeight.w700 : FontWeight.w500,
                        color: _isWeeklyView
                            ? widget.habit.color
                            : (widget.isDark ? Colors.white54 : Colors.black45),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyView() {
    final firstDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final lastDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    final startWeekday = firstDayOfMonth.weekday % 7; // 0=Sun

    final monthlyDataAsync = ref.watch(quitHabitMonthlyDataProvider((
      habitId: widget.habit.id,
      year: _focusedMonth.year,
      month: _focusedMonth.month,
    )));

    return monthlyDataAsync.when(
      data: (monthlyData) => _buildCalendarGrid(
        daysInMonth,
        startWeekday,
        monthlyData,
      ),
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
      ),
      error: (e, _) => Center(
        child: Text('Error loading data: $e'),
      ),
    );
  }

  Widget _buildWeeklyView() {
    final weekDays = _getWeekDays(_focusedWeekStart);
    
    // We need to fetch data for the month(s) that this week spans
    // A week can span two months (e.g., Jan 28 - Feb 3)
    final monthlyDataAsync = ref.watch(quitHabitMonthlyDataProvider((
      habitId: widget.habit.id,
      year: _focusedWeekStart.year,
      month: _focusedWeekStart.month,
    )));

    // If week spans two months, also fetch the next month
    final weekEnd = weekDays.last;
    final needsNextMonth = weekEnd.month != _focusedWeekStart.month;
    final nextMonthDataAsync = needsNextMonth
        ? ref.watch(quitHabitMonthlyDataProvider((
            habitId: widget.habit.id,
            year: weekEnd.year,
            month: weekEnd.month,
          )))
        : null;

    return monthlyDataAsync.when(
      data: (monthlyData) {
        // Merge with next month data if needed
        Map<DateTime, QuitDayData> combinedData = Map.from(monthlyData);
        if (needsNextMonth && nextMonthDataAsync != null) {
          nextMonthDataAsync.whenData((nextData) {
            combinedData.addAll(nextData);
          });
        }
        return _buildWeeklyCalendarGrid(weekDays, combinedData);
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
      ),
      error: (e, _) => Center(
        child: Text('Error loading data: $e'),
      ),
    );
  }

  Widget _buildWeeklyCalendarGrid(List<DateTime> weekDays, Map<DateTime, QuitDayData> data) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: weekDays.map((date) {
          final dateKey = DateTime(date.year, date.month, date.day);
          final dayData = data[dateKey];
          final isToday = dateKey == today;
          final isSelected = _selectedDate != null &&
              dateKey == DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day);

          return Expanded(
            child: _buildWeeklyDayCell(date, dayData, isToday, isSelected),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildWeeklyDayCell(
    DateTime date,
    QuitDayData? dayData,
    bool isToday,
    bool isSelected,
  ) {
    final status = dayData?.status ?? QuitDayStatus.future;
    
    Color bgColor;
    Color borderColor;
    Color accentColor;
    Color textColor;
    double borderWidth = 1.0;
    IconData? statusIcon;

    switch (status) {
      case QuitDayStatus.win:
        accentColor = const Color(0xFF4CAF50);
        bgColor = accentColor.withOpacity(widget.isDark ? 0.12 : 0.08);
        borderColor = accentColor.withOpacity(0.8);
        textColor = widget.isDark ? Colors.white : Colors.green[800]!;
        statusIcon = Icons.check_circle_rounded;
        break;
      case QuitDayStatus.almost:
        accentColor = const Color(0xFFFFB347);
        bgColor = accentColor.withOpacity(widget.isDark ? 0.12 : 0.08);
        borderColor = accentColor.withOpacity(0.8);
        textColor = widget.isDark ? Colors.white : Colors.orange[800]!;
        statusIcon = Icons.shield_rounded;
        break;
      case QuitDayStatus.slip:
        accentColor = const Color(0xFFEF5350);
        bgColor = accentColor.withOpacity(widget.isDark ? 0.12 : 0.08);
        borderColor = accentColor.withOpacity(0.8);
        textColor = widget.isDark ? Colors.white : Colors.red[800]!;
        statusIcon = Icons.cancel_rounded;
        break;
      case QuitDayStatus.beforeCreated:
      case QuitDayStatus.future:
      case QuitDayStatus.noData:
      default:
        accentColor = widget.isDark ? Colors.white24 : Colors.black26;
        bgColor = widget.isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02);
        borderColor = widget.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05);
        textColor = widget.isDark ? Colors.white24 : Colors.black26;
        break;
    }

    if (isToday || isSelected) {
      borderWidth = 2.0;
      borderColor = isToday ? widget.habit.color : accentColor;
      if (status == QuitDayStatus.future || status == QuitDayStatus.noData) {
        textColor = isToday ? widget.habit.color : textColor;
      }
    }

    return GestureDetector(
      onTap: dayData != null ? () {
        setState(() => _selectedDate = date);
        _showDayDetails(context, date, dayData);
      } : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: isToday ? [
            BoxShadow(
              color: widget.habit.color.withOpacity(0.15),
              blurRadius: 10,
              spreadRadius: 1,
            )
          ] : null,
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat('EEE').format(date).toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: textColor.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${date.day}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: isToday ? FontWeight.w900 : FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 10),
                if (statusIcon != null)
                  Icon(statusIcon, size: 16, color: accentColor)
                else
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: textColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklyStatsSummary() {
    final weekDays = _getWeekDays(_focusedWeekStart);
    
    // Fetch data for this week
    final monthlyDataAsync = ref.watch(quitHabitMonthlyDataProvider((
      habitId: widget.habit.id,
      year: _focusedWeekStart.year,
      month: _focusedWeekStart.month,
    )));

    // If week spans two months, also fetch the next month
    final weekEnd = weekDays.last;
    final needsNextMonth = weekEnd.month != _focusedWeekStart.month;
    final nextMonthDataAsync = needsNextMonth
        ? ref.watch(quitHabitMonthlyDataProvider((
            habitId: widget.habit.id,
            year: weekEnd.year,
            month: weekEnd.month,
          )))
        : null;

    return monthlyDataAsync.when(
      data: (monthlyData) {
        // Merge with next month data if needed
        Map<DateTime, QuitDayData> combinedData = Map.from(monthlyData);
        if (needsNextMonth && nextMonthDataAsync != null) {
          nextMonthDataAsync.whenData((nextData) {
            combinedData.addAll(nextData);
          });
        }

        // Calculate stats for this week only
        int winDays = 0;
        int slipDays = 0;
        int closeCallsResisted = 0;

        for (final date in weekDays) {
          final dateKey = DateTime(date.year, date.month, date.day);
          final dayData = combinedData[dateKey];
          if (dayData == null) continue;

          if (dayData.status == QuitDayStatus.win || 
              dayData.status == QuitDayStatus.almost) {
            winDays++;
          } else if (dayData.status == QuitDayStatus.slip) {
            slipDays++;
          }

          // Count strong temptations resisted
          closeCallsResisted += dayData.temptations
              .where((t) => t.intensityIndex >= 2 && t.didResist)
              .length;
        }

        final totalTracked = winDays + slipDays;
        final successRate = totalTracked > 0
            ? (winDays / totalTracked * 100).toStringAsFixed(0)
            : '0';

        return Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.03),
                widget.isDark
                    ? Colors.white.withOpacity(0.02)
                    : Colors.black.withOpacity(0.01),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.05),
            ),
          ),
          child: Column(
            children: [
              // Week label
              Text(
                'WEEK SUMMARY',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: widget.isDark ? Colors.white38 : Colors.black38,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('$winDays', 'Wins', const Color(0xFF4CAF50)),
                  _buildStatDivider(),
                  _buildStatItem('$closeCallsResisted', 'Resisted', const Color(0xFFFFB347)),
                  _buildStatDivider(),
                  _buildStatItem('$slipDays', 'Slips', const Color(0xFFEF5350)),
                  _buildStatDivider(),
                  _buildStatItem('$successRate%', 'Success', 
                    int.parse(successRate) >= 80
                        ? const Color(0xFF4CAF50)
                        : int.parse(successRate) >= 50
                            ? const Color(0xFFFFB347)
                            : const Color(0xFFEF5350)),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(height: 100),
      error: (e, _) => const SizedBox(height: 100),
    );
  }

  Widget _buildHeader() {
    if (_isWeeklyView) {
      return _buildWeeklyHeader();
    }
    return _buildMonthlyHeader();
  }

  Widget _buildWeeklyHeader() {
    final weekDays = _getWeekDays(_focusedWeekStart);
    final weekEnd = weekDays.last;
    final isSameMonth = _focusedWeekStart.month == weekEnd.month;

    String dateRangeText;
    if (isSameMonth) {
      dateRangeText = '${DateFormat('MMM d').format(_focusedWeekStart)} - ${weekEnd.day}';
    } else {
      dateRangeText = '${DateFormat('MMM d').format(_focusedWeekStart)} - ${DateFormat('MMM d').format(weekEnd)}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildNavButton(
            Icons.chevron_left_rounded,
            () => setState(() {
              _focusedWeekStart = _focusedWeekStart.subtract(const Duration(days: 7));
            }),
          ),
          Column(
            children: [
              Text(
                dateRangeText.toUpperCase(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: widget.isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _focusedWeekStart.year.toString(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: widget.isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
          _buildNavButton(
            Icons.chevron_right_rounded,
            () => setState(() {
              _focusedWeekStart = _focusedWeekStart.add(const Duration(days: 7));
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildNavButton(
            Icons.chevron_left_rounded,
            () => setState(() {
              _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
            }),
          ),
          Column(
            children: [
              Text(
                DateFormat('MMMM').format(_focusedMonth).toUpperCase(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: widget.isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                DateFormat('yyyy').format(_focusedMonth),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: widget.isDark ? Colors.white54 : Colors.black54,
                ),
              ),
            ],
          ),
          _buildNavButton(
            Icons.chevron_right_rounded,
            () => setState(() {
              _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton(IconData icon, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: Icon(icon, size: 20),
        onPressed: onPressed,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLegendItem(const Color(0xFF4CAF50), 'Win'),
          const SizedBox(width: 20),
          _buildLegendItem(const Color(0xFFFFB347), 'Almost'),
          const SizedBox(width: 20),
          _buildLegendItem(const Color(0xFFEF5350), 'Slip'),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withOpacity(0.8), width: 2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: widget.isDark ? Colors.white70 : Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildWeekdayHeaders() {
    const weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: weekdays
            .map((day) => SizedBox(
                  width: 36,
                  child: Text(
                    day,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      color: widget.isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildCalendarGrid(
    int daysInMonth,
    int startWeekday,
    Map<DateTime, QuitDayData> monthlyData,
  ) {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemCount: 42, // 6 weeks
      itemBuilder: (context, index) {
        final dayOffset = index - startWeekday;
        if (dayOffset < 0 || dayOffset >= daysInMonth) {
          return const SizedBox.shrink();
        }

        final date = DateTime(_focusedMonth.year, _focusedMonth.month, dayOffset + 1);
        final dateKey = DateTime(date.year, date.month, date.day);
        final dayData = monthlyData[dateKey];
        final now = DateTime.now();
        final isToday = date.day == now.day &&
            date.month == now.month &&
            date.year == now.year;
        final isSelected = _selectedDate != null &&
            date.day == _selectedDate!.day &&
            date.month == _selectedDate!.month &&
            date.year == _selectedDate!.year;

        return _buildDayCell(date, dayData, isToday, isSelected);
      },
    );
  }

  Widget _buildDayCell(
    DateTime date,
    QuitDayData? dayData,
    bool isToday,
    bool isSelected,
  ) {
    final status = dayData?.status ?? QuitDayStatus.noData;

    Color bgColor;
    Color borderColor;
    Color textColor;
    IconData? statusIcon;
    double borderWidth = 2.0;

    switch (status) {
      case QuitDayStatus.win:
        bgColor = const Color(0xFF4CAF50).withOpacity(widget.isDark ? 0.15 : 0.12);
        borderColor = const Color(0xFF4CAF50).withOpacity(0.8);
        textColor = widget.isDark ? Colors.white : Colors.green[800]!;
        statusIcon = Icons.check_rounded;
        break;
      case QuitDayStatus.slip:
        bgColor = const Color(0xFFEF5350).withOpacity(widget.isDark ? 0.15 : 0.12);
        borderColor = const Color(0xFFEF5350).withOpacity(0.8);
        textColor = widget.isDark ? Colors.white : Colors.red[800]!;
        statusIcon = Icons.close_rounded;
        break;
      case QuitDayStatus.almost:
        bgColor = const Color(0xFFFFB347).withOpacity(widget.isDark ? 0.15 : 0.12);
        borderColor = const Color(0xFFFFB347).withOpacity(0.8);
        textColor = widget.isDark ? Colors.white : Colors.orange[800]!;
        statusIcon = Icons.shield_rounded; // Shield = defended against temptation!
        break;
      case QuitDayStatus.future:
        bgColor = widget.isDark
            ? Colors.white.withOpacity(0.02)
            : Colors.black.withOpacity(0.02);
        borderColor = Colors.transparent;
        textColor = widget.isDark ? Colors.white24 : Colors.black26;
        borderWidth = 0;
        break;
      case QuitDayStatus.beforeCreated:
        // Habit didn't exist yet - show as disabled/grayed out
        bgColor = Colors.transparent;
        borderColor = Colors.transparent;
        textColor = widget.isDark ? Colors.white12 : Colors.black12;
        borderWidth = 0;
        break;
      case QuitDayStatus.noData:
        bgColor = widget.isDark
            ? Colors.white.withOpacity(0.03)
            : Colors.black.withOpacity(0.03);
        borderColor = widget.isDark
            ? Colors.white.withOpacity(0.08)
            : Colors.black.withOpacity(0.05);
        textColor = widget.isDark ? Colors.white54 : Colors.black54;
        borderWidth = 1;
        break;
    }

    // Override for today
    if (isToday) {
      borderWidth = 3;
      if (status == QuitDayStatus.noData || status == QuitDayStatus.future) {
        borderColor = widget.habit.color;
      }
    }

    // Override for selected
    if (isSelected) {
      borderWidth = 3;
      borderColor = const Color(0xFFCDAF56);
    }

    return GestureDetector(
      onTap: status != QuitDayStatus.future && 
             status != QuitDayStatus.noData && 
             status != QuitDayStatus.beforeCreated
          ? () {
              setState(() => _selectedDate = date);
              _showDayDetails(context, date, dayData!);
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFCDAF56).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: textColor,
              ),
            ),
            if (statusIcon != null && status != QuitDayStatus.noData)
              Positioned(
                bottom: 2,
                right: 2,
                child: Icon(
                  statusIcon,
                  size: 10,
                  color: borderColor,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSummary() {
    final monthlyDataAsync = ref.watch(quitHabitMonthlyDataProvider((
      habitId: widget.habit.id,
      year: _focusedMonth.year,
      month: _focusedMonth.month,
    )));

    return monthlyDataAsync.when(
      data: (monthlyData) {
        // QUIT HABIT SPECIFIC COUNTING
        // "Win" = days you WON (didn't do bad habit)
        // "Close Calls" = Strong/Extreme temptations you RESISTED (even on slip days!)
        // "Slip" = days you did the bad habit (failure)
        
        // Count win days (includes both easy wins and almost-but-won days)
        final winDays = monthlyData.values
            .where((d) => d.status == QuitDayStatus.win || d.status == QuitDayStatus.almost)
            .length;
        
        // Count slip days
        final slipDays = monthlyData.values
            .where((d) => d.status == QuitDayStatus.slip)
            .length;
        
        // Count "Close Calls" = Strong (2) or Extreme (3) temptations that were RESISTED
        // This counts across ALL days (even slip days) because you still deserve credit!
        int closeCallsResisted = 0;
        for (final dayData in monthlyData.values) {
          closeCallsResisted += dayData.temptations
              .where((t) => t.intensityIndex >= 2 && t.didResist)
              .length;
        }
        
        // Success rate is based on days
        final totalTracked = winDays + slipDays;
        final successRate = totalTracked > 0
            ? (winDays / totalTracked * 100).toStringAsFixed(0)
            : '0';

        return Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF4CAF50).withOpacity(0.1),
                const Color(0xFFCDAF56).withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF4CAF50).withOpacity(0.2),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Win days (successfully avoided bad habit)
              _buildStatItem('$winDays', 'Wins', const Color(0xFF4CAF50)),
              _buildStatDivider(),
              // Close Calls = Strong/Extreme temptations RESISTED (you deserve credit!)
              _buildStatItem('$closeCallsResisted', 'Resisted', const Color(0xFFFFB347)),
              _buildStatDivider(),
              _buildStatItem('$slipDays', 'Slips', const Color(0xFFEF5350)),
              _buildStatDivider(),
              _buildStatItem('$successRate%', 'Success', widget.habit.color),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildStatItem(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: widget.isDark ? Colors.white54 : Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 40,
      color: widget.isDark ? Colors.white12 : Colors.black12,
    );
  }

  void _showDayDetails(BuildContext context, DateTime date, QuitDayData dayData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DayDetailsModal(
        date: date,
        dayData: dayData,
        habit: widget.habit,
        isDark: widget.isDark,
      ),
    );
  }
}

/// Modal showing details for a specific day
class _DayDetailsModal extends StatelessWidget {
  final DateTime date;
  final QuitDayData dayData;
  final Habit habit;
  final bool isDark;

  const _DayDetailsModal({
    required this.date,
    required this.dayData,
    required this.habit,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(dayData.status);
    final statusText = _getStatusText(dayData.status);
    final statusIcon = _getStatusIcon(dayData.status);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D24) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle & Date Header (Fixed)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    DateFormat('EEEE, MMMM d, yyyy').format(date).toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: isDark ? Colors.white54 : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(statusIcon, color: statusColor, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  statusText,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: statusColor,
                                  ),
                                ),
                                Text(
                                  _getStatusSubtext(dayData.status),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? Colors.white54 : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Slip reason if any
                    if (dayData.status == QuitDayStatus.slip && dayData.slipReason != null) ...[
                      _buildDetailCard(
                        icon: Icons.report_problem_rounded,
                        title: 'Slip Reason',
                        content: dayData.slipReason!,
                        color: const Color(0xFFEF5350),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Temptation details if any
                    if (dayData.temptations.isNotEmpty) ...[
                      _buildSectionHeader('Temptations Logged', dayData.temptations.length),
                      const SizedBox(height: 12),
                      ...dayData.temptations.take(5).map((t) => _buildTemptationItem(t)),
                    ],

                    // Completion details
                    if (dayData.completions.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildSectionHeader('Activity Log', dayData.completions.length),
                      const SizedBox(height: 12),
                      ...dayData.completions.take(5).map((c) => _buildCompletionItem(c)),
                    ],

                    // Empty state
                    if (dayData.temptations.isEmpty && dayData.completions.isEmpty) ...[
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Icon(
                                Icons.check_circle_outline_rounded,
                                size: 48,
                                color: const Color(0xFF4CAF50).withOpacity(0.5),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Win! 🎉',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white70 : Colors.grey[700],
                                ),
                              ),
                              Text(
                                'No temptations or slips recorded',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.white38 : Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard({
    required IconData icon,
    required String title,
    required String content,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Row(
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
            color: isDark ? Colors.white54 : Colors.grey[600],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: habit.color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: habit.color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTemptationItem(TemptationLog temptation) {
    final intensityLabels = ['Mild', 'Moderate', 'Strong', 'Extreme'];
    final intensityColors = [
      const Color(0xFF4CAF50),
      const Color(0xFFFFB347),
      const Color(0xFFFF6B6B),
      const Color(0xFFE53935),
    ];
    final intensity = temptation.intensityIndex.clamp(0, 3);
    final color = intensityColors[intensity];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              temptation.didResist
                  ? Icons.shield_rounded
                  : Icons.warning_rounded,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        intensityLabels[intensity],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      temptation.didResist ? 'Resisted!' : 'Slipped',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: temptation.didResist
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFFEF5350),
                      ),
                    ),
                  ],
                ),
                if (temptation.reasonText != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    temptation.reasonText!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : Colors.grey[700],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (temptation.customNote != null &&
                    temptation.customNote!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    temptation.customNote!,
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: isDark ? Colors.white38 : Colors.grey[500],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Text(
            DateFormat('h:mm a').format(temptation.occurredAt),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white38 : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionItem(HabitCompletion completion) {
    final isSlip = completion.isSkipped;
    final color = isSlip ? const Color(0xFFEF5350) : const Color(0xFF4CAF50);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isSlip ? Icons.close_rounded : Icons.check_rounded,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSlip ? 'Slipped' : 'Win',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                if (completion.skipReason != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    completion.skipReason!,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.grey[600],
                    ),
                  ),
                ],
                if (completion.note != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    completion.note!,
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: isDark ? Colors.white38 : Colors.grey[500],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            DateFormat('h:mm a').format(completion.completedAt),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white38 : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(QuitDayStatus status) {
    switch (status) {
      case QuitDayStatus.win:
        return const Color(0xFF4CAF50); // Green = Success
      case QuitDayStatus.almost:
        return const Color(0xFFFFB347); // Amber = Still success, but hard-fought!
      case QuitDayStatus.slip:
        return const Color(0xFFEF5350); // Red = Failure
      case QuitDayStatus.noData:
      case QuitDayStatus.future:
      case QuitDayStatus.beforeCreated:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(QuitDayStatus status) {
    switch (status) {
      case QuitDayStatus.win:
        return Icons.celebration_rounded;
      case QuitDayStatus.almost:
        return Icons.shield_rounded; // Shield = defended against temptation!
      case QuitDayStatus.slip:
        return Icons.sentiment_dissatisfied_rounded;
      case QuitDayStatus.noData:
      case QuitDayStatus.future:
        return Icons.help_outline_rounded;
      case QuitDayStatus.beforeCreated:
        return Icons.block_rounded;
    }
  }

  String _getStatusText(QuitDayStatus status) {
    switch (status) {
      case QuitDayStatus.win:
        return 'Win! 🎉';
      case QuitDayStatus.almost:
        return 'Almost, But Won! 💪';
      case QuitDayStatus.slip:
        return 'Slipped';
      case QuitDayStatus.noData:
        return 'No Data';
      case QuitDayStatus.future:
        return 'Future';
      case QuitDayStatus.beforeCreated:
        return 'Not Created Yet';
    }
  }

  String _getStatusSubtext(QuitDayStatus status) {
    switch (status) {
      case QuitDayStatus.win:
        return 'You won the day! 🏆';
      case QuitDayStatus.almost:
        return 'Strong temptation, but you won! Full credit! 🏆';
      case QuitDayStatus.slip:
        return 'Don\'t give up, tomorrow is a new day';
      case QuitDayStatus.noData:
        return 'No activity recorded';
      case QuitDayStatus.future:
        return 'This day hasn\'t come yet';
      case QuitDayStatus.beforeCreated:
        return 'This habit didn\'t exist on this day';
    }
  }
}
