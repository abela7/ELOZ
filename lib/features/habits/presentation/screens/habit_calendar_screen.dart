import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/dark_gradient.dart';
import '../../data/models/habit.dart';
import '../../data/services/quit_habit_report_security_service.dart';
import '../providers/habit_providers.dart';
import '../providers/habit_statistics_providers.dart';
import '../services/quit_habit_report_access_guard.dart';
import '../widgets/skip_reason_dialog.dart';
import '../widgets/habit_detail_modal.dart';

/// Habit Calendar Screen - A full-screen interactive calendar for habit tracking history
class HabitCalendarScreen extends ConsumerStatefulWidget {
  const HabitCalendarScreen({super.key});

  @override
  ConsumerState<HabitCalendarScreen> createState() =>
      _HabitCalendarScreenState();
}

class _HabitCalendarScreenState extends ConsumerState<HabitCalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();
  bool _showHeatmap = true; // Toggle for progress heatmap
  final QuitHabitReportSecurityService _quitSecurityService =
      QuitHabitReportSecurityService();
  final QuitHabitReportAccessGuard _quitAccessGuard =
      QuitHabitReportAccessGuard();
  bool _requiresQuitUnlock = false;
  bool _quitPolicyLoaded = false;
  bool _isUnlockingQuitHabits = false;

  bool get _quitHabitsLocked =>
      !_quitPolicyLoaded ||
      (_requiresQuitUnlock && !_quitAccessGuard.isSettingsSessionUnlocked);

  @override
  void initState() {
    super.initState();
    _refreshQuitProtectionPolicy();
  }

  Future<void> _refreshQuitProtectionPolicy() async {
    final settings = await _quitSecurityService.getSettings();
    final hasPasscode = await _quitSecurityService.hasPasscode();
    if (!mounted) return;
    setState(() {
      _requiresQuitUnlock = settings.enabled && hasPasscode;
      _quitPolicyLoaded = true;
    });
  }

  Future<void> _unlockQuitHabits() async {
    if (_isUnlockingQuitHabits) return;
    setState(() => _isUnlockingQuitHabits = true);
    try {
      final unlocked = await _quitAccessGuard.ensureQuitHabitsAccess(
        context,
        onSecurityEmergencyReset: () async {
          await ref.read(habitNotifierProvider.notifier).loadHabits();
          await _refreshQuitProtectionPolicy();
        },
      );
      if (!mounted) return;
      if (unlocked) {
        // Unlock changes visibility/session state only.
        setState(() {
          _quitPolicyLoaded = true;
        });
        HapticFeedback.mediumImpact();
      }
    } finally {
      if (mounted) {
        setState(() => _isUnlockingQuitHabits = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final habitsAsync = ref.watch(habitNotifierProvider);

    return Scaffold(
      body: isDark
          ? DarkGradient.wrap(
              child: _buildContent(context, isDark, habitsAsync),
            )
          : _buildContent(context, isDark, habitsAsync),
    );
  }

  Widget _buildContent(
    BuildContext context,
    bool isDark,
    AsyncValue<List<Habit>> habitsAsync,
  ) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Habit Calendar'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _showHeatmap ? Icons.gradient_rounded : Icons.grid_view_rounded,
              color: _showHeatmap ? const Color(0xFFCDAF56) : null,
            ),
            onPressed: () {
              setState(() => _showHeatmap = !_showHeatmap);
              HapticFeedback.lightImpact();
            },
            tooltip: _showHeatmap
                ? 'Hide Progress Heatmap'
                : 'Show Progress Heatmap',
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
      body: habitsAsync.when(
        data: (habits) {
          final lockQuitHabits = _quitHabitsLocked;
          final lockedQuitCount = habits
              .where(
                (h) => !h.isArchived && h.isQuitHabit && !h.shouldHideQuitHabit,
              )
              .length;
          // Match dashboard/view-all behavior:
          // if user enables "hide quit habits", don't show them in calendar either.
          final visibleHabits = habits.where((h) {
            if (h.isArchived) return false;
            if (h.shouldHideQuitHabit) return false;
            if (lockQuitHabits && h.isQuitHabit) return false;
            return true;
          }).toList();
          final selectedRawDay = _selectedDay ?? DateTime.now();
          final selectedDay = DateTime(
            selectedRawDay.year,
            selectedRawDay.month,
            selectedRawDay.day,
          );
          final dayStatusesAsync = ref.watch(
            habitStatusesOnDateProvider(selectedDay),
          );
          final dayStatuses = dayStatusesAsync.maybeWhen(
            data: (statuses) => statuses,
            orElse: () => const <String, HabitDayStatus>{},
          );

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _buildCalendarCard(
                  isDark,
                  visibleHabits,
                  hideProtectedStats: lockQuitHabits && lockedQuitCount > 0,
                ),
              ),
              if (lockQuitHabits && lockedQuitCount > 0)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _buildQuitLockedBanner(isDark, lockedQuitCount),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverToBoxAdapter(
                child: _buildHabitListHeader(
                  isDark,
                  hideProtectedStats: lockQuitHabits && lockedQuitCount > 0,
                ),
              ),
              if (visibleHabits.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyHabitsState(isDark),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      return _buildCalendarHabitTile(
                        isDark,
                        visibleHabits[index],
                        dayStatuses,
                        dayStatusesAsync.isLoading,
                      );
                    }, childCount: visibleHabits.length),
                  ),
                ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 80),
              ), // Bottom padding
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildHabitListHeader(bool isDark, {bool hideProtectedStats = false}) {
    if (_selectedDay == null) return const SizedBox.shrink();

    final monthlyStatsAsync = hideProtectedStats
        ? const AsyncValue<Map<DateTime, double>>.data(<DateTime, double>{})
        : ref.watch(
            monthlyHabitStatsProvider((
              year: _selectedDay!.year,
              month: _selectedDay!.month,
            )),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              IconButton(
                onPressed: () {
                  final prevDay = _selectedDay!.subtract(
                    const Duration(days: 1),
                  );
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
                      DateFormat('EEEE').format(_selectedDay!),
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      DateFormat('MMMM d, yyyy').format(_selectedDay!),
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
                onPressed:
                    _selectedDay!.isAfter(
                      DateTime.now().subtract(const Duration(days: 1)),
                    )
                    ? null
                    : () {
                        final nextDay = _selectedDay!.add(
                          const Duration(days: 1),
                        );
                        setState(() {
                          _selectedDay = nextDay;
                          _focusedDay = nextDay;
                        });
                        HapticFeedback.lightImpact();
                      },
                icon: Icon(
                  Icons.chevron_right_rounded,
                  color:
                      _selectedDay!.isAfter(
                        DateTime.now().subtract(const Duration(days: 1)),
                      )
                      ? (isDark ? Colors.white12 : Colors.black12)
                      : (isDark ? Colors.white54 : Colors.black54),
                ),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 8),
              if (hideProtectedStats)
                _buildProtectedStatsBadge(isDark)
              else
                monthlyStatsAsync.when(
                  data: (stats) {
                    final dateKey = DateTime(
                      _selectedDay!.year,
                      _selectedDay!.month,
                      _selectedDay!.day,
                    );
                    final rate = stats[dateKey];
                    if (rate == null || _selectedDay!.isAfter(DateTime.now())) {
                      return _buildFutureOrNoDataBadge(isDark);
                    }
                    final percent = (rate * 100).round();
                    final color = rate >= 0.9
                        ? Colors.green
                        : (rate >= 0.55 ? Colors.orange : Colors.red);
                    return _buildScoreBadge(
                      percent,
                      color,
                      rate >= 0.9
                          ? 'Perfect'
                          : (rate >= 0.55 ? 'Medium' : 'Low'),
                    );
                  },
                  loading: () => const SizedBox(
                    width: 40,
                    height: 40,
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  error: (_, __) => const Icon(
                    Icons.error_outline,
                    size: 20,
                    color: Colors.red,
                  ),
                ),
            ],
          ),
        ),
        if (!hideProtectedStats) _buildQuickStatsRow(isDark, []),
      ],
    );
  }

  Widget _buildCalendarCard(
    bool isDark,
    List<Habit> habits, {
    bool hideProtectedStats = false,
  }) {
    final monthlyStats = hideProtectedStats
        ? const <DateTime, double>{}
        : ref
              .watch(
                monthlyHabitStatsProvider((
                  year: _focusedDay.year,
                  month: _focusedDay.month,
                )),
              )
              .maybeWhen(
                data: (stats) => stats,
                orElse: () => <DateTime, double>{},
              );

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
          TableCalendar<Habit>(
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
              leftChevronIcon: const Icon(
                Icons.chevron_left_rounded,
                color: Color(0xFFCDAF56),
              ),
              rightChevronIcon: const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFCDAF56),
              ),
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
                          ? const Color(0xFFCDAF56)
                          : (isDark ? Colors.white38 : Colors.black38),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                );
              },
              defaultBuilder: (context, day, focusedDay) => _buildDayCell(
                day,
                habits,
                isDark,
                monthlyStats: monthlyStats,
              ),
              todayBuilder: (context, day, focusedDay) => _buildDayCell(
                day,
                habits,
                isDark,
                isToday: true,
                monthlyStats: monthlyStats,
              ),
              selectedBuilder: (context, day, focusedDay) => _buildDayCell(
                day,
                habits,
                isDark,
                isSelected: true,
                monthlyStats: monthlyStats,
              ),
              outsideBuilder: (context, day, focusedDay) =>
                  _buildDayCell(day, habits, isDark, isOutside: true),
            ),
          ),
          if (_showHeatmap && !hideProtectedStats) _buildHeatmapLegend(isDark),
        ],
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
          _buildLegendItem('Low', Colors.red, isDark),
          _buildLegendItem('Medium', Colors.orange, isDark),
          _buildLegendItem('Perfect', Colors.green, isDark),
        ],
      ),
    );
  }

  Widget _buildQuitLockedBanner(bool isDark, int count) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF2D3139).withValues(alpha: 0.6)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFCDAF56).withValues(alpha: 0.45),
          width: 1.1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFCDAF56).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              color: Color(0xFFCDAF56),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quit habits are protected',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$count quit habit${count == 1 ? '' : 's'} hidden until unlocked.',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _isUnlockingQuitHabits ? null : _unlockQuitHabits,
            child: _isUnlockingQuitHabits
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Unlock'),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withOpacity(0.6),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget? _buildCalendarMarkers(DateTime date, List<Habit> habits) {
    if (date.isAfter(DateTime.now())) return null;
    return null;
  }

  Widget _buildDayCell(
    DateTime date,
    List<Habit> habits,
    bool isDark, {
    bool isSelected = false,
    bool isToday = false,
    bool isOutside = false,
    Map<DateTime, double>? monthlyStats,
  }) {
    final dateKey = DateTime(date.year, date.month, date.day);
    final completionRate = monthlyStats?[dateKey];
    final isFuture = date.isAfter(DateTime.now());

    Color? progressColor;
    if (_showHeatmap && completionRate != null && !isFuture && !isOutside) {
      if (completionRate >= 0.9) {
        progressColor = Colors.green;
      } else if (completionRate >= 0.55) {
        progressColor = Colors.orange;
      } else {
        progressColor = Colors.red;
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D24) : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: progressColor != null
            ? Border.all(color: progressColor, width: 2)
            : (isSelected
                  ? Border.all(color: const Color(0xFFCDAF56), width: 2)
                  : null),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: const Color(0xFFCDAF56).withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Center(
        child: Text(
          '${date.day}',
          style: TextStyle(
            color: isOutside
                ? (isDark ? Colors.white10 : Colors.black12)
                : (isFuture
                      ? (isDark ? Colors.white24 : Colors.black26)
                      : (isDark ? Colors.white : Colors.black87)),
            fontWeight: isSelected || isToday
                ? FontWeight.w900
                : FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildFutureOrNoDataBadge(bool isDark) {
    final isFuture = _selectedDay!.isAfter(DateTime.now());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isFuture
                ? Icons.schedule_rounded
                : Icons.history_toggle_off_rounded,
            size: 16,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
          const SizedBox(width: 6),
          Text(
            isFuture ? 'Future' : 'No Data',
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.black54,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProtectedStatsBadge(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 16,
            color: isDark ? const Color(0xFFCDAF56) : const Color(0xFF8A6B16),
          ),
          const SizedBox(width: 6),
          Text(
            'Locked',
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.black54,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreBadge(int percent, Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$percent%',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Score',
                style: TextStyle(color: color.withOpacity(0.7), fontSize: 8),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsRow(bool isDark, List<Habit> habits) {
    final dailyStatsAsync = ref.watch(dailyHabitStatsProvider(_selectedDay!));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: dailyStatsAsync.when(
        data: (stats) => Row(
          children: [
            Expanded(
              child: _buildStatChip(
                'Due',
                stats.total,
                const Color(0xFFCDAF56),
                isDark,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatChip(
                'Done',
                stats.completed,
                Colors.green,
                isDark,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatChip(
                'Streak',
                stats.streaks,
                Colors.redAccent,
                isDark,
              ),
            ),
          ],
        ),
        loading: () => Row(
          children: [
            Expanded(child: _buildLoadingStatChip(isDark)),
            const SizedBox(width: 8),
            Expanded(child: _buildLoadingStatChip(isDark)),
            const SizedBox(width: 8),
            Expanded(child: _buildLoadingStatChip(isDark)),
          ],
        ),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildLoadingStatChip(bool isDark) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _buildStatChip(String label, int count, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.black54,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyHabitsState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            size: 48,
            color: isDark ? Colors.white10 : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No habits yet',
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.black54,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create habits to start tracking',
            style: TextStyle(
              color: isDark ? Colors.white38 : Colors.black38,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarHabitTile(
    bool isDark,
    Habit habit,
    Map<String, HabitDayStatus> dayStatuses,
    bool isStatusLoading,
  ) {
    final status = dayStatuses[habit.id];
    if (status == null && isStatusLoading) {
      return _buildLoadingTile(isDark);
    }

    final dayStatus = status ?? HabitDayStatus.empty;
    final isCompleted = dayStatus.isCompleted;
    final isSkipped = dayStatus.isSkipped;
    final isPostponed = dayStatus.isPostponed;
    final isDeferred = dayStatus.isDeferred;
    final isActioned = dayStatus.isActioned;
    final isFuture = _selectedDay!.isAfter(DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D3139).withOpacity(0.5) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCompleted
              ? Colors.green.withOpacity(0.4)
              : (isDeferred
                    ? Colors.orange.withOpacity(0.4)
                    : (isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.05))),
          width: isActioned ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HabitDetailModal.show(
              context,
              habit: habit,
              selectedDate: _selectedDay,
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? Colors.green.withOpacity(0.15)
                        : (isDeferred
                              ? Colors.orange.withOpacity(0.15)
                              : habit.color.withOpacity(0.15)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isCompleted
                        ? Icons.check_circle_rounded
                        : (isPostponed
                              ? Icons.schedule_rounded
                              : (isSkipped
                                    ? Icons.skip_next_rounded
                                    : (habit.icon ??
                                          Icons.auto_awesome_rounded))),
                    color: isCompleted
                        ? Colors.green
                        : (isDeferred ? Colors.orange : habit.color),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        habit.title,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: isDark
                              ? Colors.white38
                              : Colors.black38,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isCompleted
                                  ? Colors.green.withOpacity(0.1)
                                  : (isDeferred
                                        ? Colors.orange.withOpacity(0.1)
                                        : Colors.grey.withOpacity(0.1)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isCompleted
                                  ? 'Done'
                                  : (isPostponed
                                        ? 'Postponed'
                                        : (isSkipped ? 'Skipped' : 'Pending')),
                              style: TextStyle(
                                color: isCompleted
                                    ? Colors.green
                                    : (isDeferred
                                          ? Colors.orange
                                          : (isDark
                                                ? Colors.white54
                                                : Colors.black54)),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (habit.currentStreak > 0) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.local_fire_department_rounded,
                              size: 12,
                              color: Colors.red[400],
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${habit.currentStreak}',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.red[400],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (!isFuture) ...[
                  if (!isActioned) ...[
                    _buildQuickActionButton(
                      icon: Icons.check_rounded,
                      color: Colors.green,
                      isDark: isDark,
                      onTap: () async {
                        if (habit.isNumeric || habit.isTimer) {
                          HabitDetailModal.show(
                            context,
                            habit: habit,
                            selectedDate: _selectedDay,
                          );
                          return;
                        }
                        await ref
                            .read(habitNotifierProvider.notifier)
                            .completeHabitForDate(habit.id, _selectedDay!);
                        HapticFeedback.mediumImpact();
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildQuickActionButton(
                      icon: Icons.skip_next_rounded,
                      color: Colors.orange,
                      isDark: isDark,
                      onTap: () async {
                        final String? reason = await showDialog<String>(
                          context: context,
                          builder: (context) => SkipReasonDialog(
                            isDark: isDark,
                            habitName: habit.title,
                          ),
                        );

                        if (reason != null) {
                          await ref
                              .read(habitNotifierProvider.notifier)
                              .skipHabitForDate(
                                habit.id,
                                _selectedDay!,
                                reason: reason,
                              );
                          HapticFeedback.lightImpact();
                        }
                      },
                    ),
                  ] else ...[
                    _buildQuickActionButton(
                      icon: Icons.undo_rounded,
                      color: const Color(0xFFCDAF56),
                      isDark: isDark,
                      onTap: () async {
                        await ref
                            .read(habitNotifierProvider.notifier)
                            .uncompleteHabitForDate(habit.id, _selectedDay!);
                        HapticFeedback.lightImpact();
                      },
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }

  Widget _buildLoadingTile(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 80,
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF2D3139).withOpacity(0.5)
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
