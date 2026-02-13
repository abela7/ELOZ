import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/habit.dart';
import '../../data/models/habit_completion.dart';
import '../../data/repositories/habit_repository.dart';
import '../../data/repositories/temptation_log_repository.dart';
import '../providers/habit_providers.dart';
import '../services/quit_habit_report_access_guard.dart';
import '../widgets/habit_detail_modal.dart';

part 'habit_report_screen_sections.dart';

enum HabitReportPeriod { day, week, month }

class HabitReportScreen extends ConsumerStatefulWidget {
  final DateTime? initialDate;
  final bool onlyQuitHabits;
  final String? titleOverride;
  final String? subtitleOverride;

  const HabitReportScreen({
    super.key,
    this.initialDate,
    this.onlyQuitHabits = false,
    this.titleOverride,
    this.subtitleOverride,
  });

  @override
  ConsumerState<HabitReportScreen> createState() => _HabitReportScreenState();
}

class _HabitReportScreenState extends ConsumerState<HabitReportScreen> {
  static const _accentColor = Color(0xFFCDAF56); // Gold accent
  static const _successColor = Color(0xFF4CAF50); // Standard success green
  static const _dangerColor = Color(0xFFF44336); // Standard error red
  static const _warningColor = Color(0xFFFFA726); // Standard warning orange
  static const _infoColor = Color(0xFF2196F3); // Standard info blue
  static const _surfaceDark = Color(0xFF2D3139); // App standard dark surface
  static const _bgLight = Color(0xFFFAFAFA); // App standard light background
  static const _bgDark = Color(0xFF0A0E27); // App standard dark background

  late DateTime _selectedDate;
  HabitReportPeriod _selectedPeriod = HabitReportPeriod.day;
  String? _selectedQuitHabitId;
  bool _showAllReasons = false;
  bool _showAllTemptationTriggers = false;
  bool _showAllTemptationDays = false;
  bool _insightsExpanded = false;
  bool _temptationInsightsExpanded = false;
  final TemptationLogRepository _temptationRepository =
      TemptationLogRepository();
  final ScrollController _scrollController = ScrollController();
  Future<_PeriodReportData>? _reportFuture;
  HabitRepository? _reportRepository;
  List<Habit>? _reportHabits;
  DateTime? _reportSelectedDate;
  HabitReportPeriod? _reportSelectedPeriod;
  String? _reportSelectedQuitHabitId;
  bool? _reportQuitMode;
  bool _quitAccessChecked = false;
  bool _quitAccessGranted = false;
  bool _isCheckingQuitAccess = false;

  bool get _isQuitMode => widget.onlyQuitHabits;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    if (_isQuitMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _verifyQuitAccess();
      });
    } else {
      _quitAccessChecked = true;
      _quitAccessGranted = true;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _verifyQuitAccess() async {
    if (!_isQuitMode || _quitAccessGranted || _isCheckingQuitAccess) return;
    _isCheckingQuitAccess = true;
    try {
      final guard = QuitHabitReportAccessGuard();
      final unlocked = await guard.ensureQuitHabitsAccess(
        context,
        onSecurityEmergencyReset: () async {
          await ref.read(habitNotifierProvider.notifier).loadHabits();
        },
      );
      if (!mounted) return;
      if (!unlocked) {
        setState(() {
          _quitAccessChecked = true;
          _quitAccessGranted = false;
        });
        Navigator.of(context).maybePop();
        return;
      }

      setState(() {
        _quitAccessChecked = true;
        _quitAccessGranted = true;
      });
    } finally {
      _isCheckingQuitAccess = false;
    }
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  DateTime _addMonths(DateTime date, int delta) {
    final totalMonths = (date.year * 12) + (date.month - 1) + delta;
    final targetYear = totalMonths ~/ 12;
    final targetMonth = totalMonths % 12 + 1;
    final lastDay = DateTime(targetYear, targetMonth + 1, 0).day;
    return DateTime(targetYear, targetMonth, math.min(date.day, lastDay));
  }

  _PeriodRange _rangeFor(DateTime anchor, HabitReportPeriod period) {
    final today = _dateOnly(DateTime.now());
    final selected = _dateOnly(anchor);

    switch (period) {
      case HabitReportPeriod.day:
        return _PeriodRange(start: selected, end: selected, period: period);
      case HabitReportPeriod.week:
        final start = selected.subtract(Duration(days: selected.weekday - 1));
        final nominalEnd = start.add(const Duration(days: 6));
        final end =
            (start.isBefore(today) || start == today) &&
                nominalEnd.isAfter(today)
            ? today
            : nominalEnd;
        return _PeriodRange(start: start, end: end, period: period);
      case HabitReportPeriod.month:
        final start = DateTime(selected.year, selected.month, 1);
        final nominalEnd = DateTime(selected.year, selected.month + 1, 0);
        final end =
            (start.isBefore(today) || start == today) &&
                nominalEnd.isAfter(today)
            ? today
            : nominalEnd;
        return _PeriodRange(start: start, end: end, period: period);
    }
  }

  _PeriodRange _previousRange(_PeriodRange current) {
    if (current.period == HabitReportPeriod.month) {
      final prevMonthEnd = current.start.subtract(const Duration(days: 1));
      final prevMonthStart = DateTime(prevMonthEnd.year, prevMonthEnd.month, 1);
      return _PeriodRange(
        start: prevMonthStart,
        end: prevMonthEnd,
        period: current.period,
      );
    }
    final prevEnd = current.start.subtract(const Duration(days: 1));
    final prevStart = prevEnd.subtract(Duration(days: current.dayCount - 1));
    return _PeriodRange(start: prevStart, end: prevEnd, period: current.period);
  }

  String _periodChipLabel(HabitReportPeriod period) {
    switch (period) {
      case HabitReportPeriod.day:
        return 'Day';
      case HabitReportPeriod.week:
        return 'Week';
      case HabitReportPeriod.month:
        return 'Month';
    }
  }

  String _formatRange(_PeriodRange range) {
    switch (range.period) {
      case HabitReportPeriod.day:
        return DateFormat('EEEE, MMM d, yyyy').format(range.start);
      case HabitReportPeriod.week:
        return '${DateFormat('MMM d').format(range.start)} - ${DateFormat('MMM d, yyyy').format(range.end)}';
      case HabitReportPeriod.month:
        return DateFormat('MMMM yyyy').format(range.start);
    }
  }

  String _navigatorTitle(_PeriodRange range) {
    final today = _dateOnly(DateTime.now());
    if (range.period == HabitReportPeriod.day) {
      if (range.start == today) return 'Today';
      if (range.start == today.subtract(const Duration(days: 1))) {
        return 'Yesterday';
      }
      if (range.start == today.add(const Duration(days: 1))) return 'Tomorrow';
      return DateFormat('EEE, MMM d').format(range.start);
    }
    if (range.period == HabitReportPeriod.week) {
      return 'Week Report';
    }
    return 'Month Report';
  }

  DateTime _shiftedDate(int delta) {
    switch (_selectedPeriod) {
      case HabitReportPeriod.day:
        return _selectedDate.add(Duration(days: delta));
      case HabitReportPeriod.week:
        return _selectedDate.add(Duration(days: delta * 7));
      case HabitReportPeriod.month:
        return _addMonths(_selectedDate, delta);
    }
  }

  void _resetExpandedPanels() {
    _showAllReasons = false;
    _showAllTemptationTriggers = false;
    _showAllTemptationDays = false;
    _insightsExpanded = false;
    _temptationInsightsExpanded = false;
  }

  Future<DateTime?> _pickDateWithTodayShortcut(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return showDialog<DateTime>(
      context: context,
      builder: (context) => _ReportDatePickerDialog(
        initialDate: _dateOnly(_selectedDate),
        firstDate: DateTime(2020),
        lastDate: today.add(const Duration(days: 365)),
      ),
    );
  }

  Future<_DayReport> _collectDayReport(
    HabitRepository repository,
    List<Habit> activeHabits,
    DateTime date,
    _TemptationDayData? temptationData,
  ) async {
    final dateOnly = _dateOnly(date);
    final today = _dateOnly(DateTime.now());
    final isPastDay = dateOnly.isBefore(today);

    final completionsByHabit = await repository
        .getCompletionsForAllHabitsOnDate(dateOnly);

    var due = 0;
    var completed = 0;
    var skipped = 0;
    var missed = 0;
    var pending = 0;
    var pointsEarned = 0;
    var pointsLost = 0;

    final dueHabitIds = <String>{};
    final completedHabitIds = <String>{};
    final reasonsByKey = <String, int>{};
    final reasonDisplayByKey = <String, String>{};
    final skipCountByHabit = <String, int>{};

    for (final habit in activeHabits) {
      if (!habit.isDueOn(dateOnly)) continue;
      due++;
      dueHabitIds.add(habit.id);

      final completions =
          completionsByHabit[habit.id] ?? const <HabitCompletion>[];
      final hasAnyLog = completions.isNotEmpty;
      final hasCompleted = completions.any(
        (c) => _isSuccessfulCompletion(c, habit),
      );
      final hasSkipped = completions.any((c) => c.isSkipped);
      final isFutureDay = dateOnly.isAfter(today);

      if (habit.isQuitHabit) {
        // Quit habits are represented as Win (resisted) vs Slip.
        if (isFutureDay) {
          pending++;
        } else if (hasSkipped) {
          skipped++;
          skipCountByHabit[habit.id] = (skipCountByHabit[habit.id] ?? 0) + 1;
        } else {
          completed++;
          completedHabitIds.add(habit.id);
          if (!hasAnyLog) {
            // If no explicit log exists yet, infer a win reward for analytics view.
            pointsEarned += habit.effectiveDailyReward;
          }
        }
      } else {
        if (hasCompleted) {
          completed++;
          completedHabitIds.add(habit.id);
        } else if (hasSkipped) {
          skipped++;
          skipCountByHabit[habit.id] = (skipCountByHabit[habit.id] ?? 0) + 1;
        } else if (isPastDay) {
          missed++;
        } else {
          pending++;
        }
      }

      HabitCompletion? latestCompletion;
      DateTime? latestCompletionAt;
      for (final completion in completions) {
        final completionAt = completion.completedAt;
        if (latestCompletionAt == null ||
            completionAt.isAfter(latestCompletionAt)) {
          latestCompletion = completion;
          latestCompletionAt = completionAt;
        }

        if (completion.isSkipped) {
          final display = _reasonLabel(completion.skipReason);
          final key = display.toLowerCase();
          reasonDisplayByKey.putIfAbsent(key, () => display);
          reasonsByKey[key] = (reasonsByKey[key] ?? 0) + 1;
        }
      }

      if (latestCompletion != null) {
        if (latestCompletion.pointsEarned > 0) {
          pointsEarned += latestCompletion.pointsEarned;
        } else if (latestCompletion.pointsEarned < 0) {
          pointsLost += latestCompletion.pointsEarned.abs();
        }
      }
    }

    final reasons = <String, int>{
      for (final entry in reasonsByKey.entries)
        (reasonDisplayByKey[entry.key] ?? entry.key): entry.value,
    };

    return _DayReport(
      date: dateOnly,
      due: due,
      completed: completed,
      skipped: skipped,
      missed: missed,
      pending: pending,
      pointsEarned: pointsEarned,
      pointsLost: pointsLost,
      dueHabitIds: dueHabitIds,
      completedHabitIds: completedHabitIds,
      reasonCounts: reasons,
      skipCountByHabit: skipCountByHabit,
      temptationTotal: temptationData?.totalCount ?? 0,
      temptationResisted: temptationData?.resistedCount ?? 0,
      temptationSlipped: temptationData?.slippedCount ?? 0,
      temptationReasonCounts: temptationData?.reasonCounts ?? const {},
      temptationSlipReasonCounts: temptationData?.slipReasonCounts ?? const {},
      temptationIntensityCounts: temptationData?.intensityCounts ?? const {},
    );
  }

  Future<List<_DayReport>> _collectRange(
    HabitRepository repository,
    List<Habit> habits,
    _PeriodRange range,
    Map<DateTime, _TemptationDayData> temptationByDay,
  ) async {
    final days = <_DayReport>[];
    for (
      var date = range.start;
      !date.isAfter(range.end);
      date = date.add(const Duration(days: 1))
    ) {
      final dayReport = await _collectDayReport(
        repository,
        habits,
        date,
        temptationByDay[_dateOnly(date)],
      );
      days.add(dayReport);
    }
    return days;
  }

  Future<Map<DateTime, _TemptationDayData>> _collectTemptationDaysInRange(
    List<Habit> habits,
    _PeriodRange range,
  ) async {
    final trackedQuitHabits = habits
        .where(
          (habit) =>
              habit.isQuitHabit && (habit.enableTemptationTracking ?? true),
        )
        .toList();
    if (trackedQuitHabits.isEmpty) return const {};

    final buckets = <DateTime, _TemptationDayDataBuilder>{};
    final logsByHabit = await Future.wait(
      trackedQuitHabits.map(
        (habit) => _temptationRepository.getLogsForHabitInRange(
          habit.id,
          range.start,
          range.end,
          sortDescending: false,
        ),
      ),
    );

    for (final logs in logsByHabit) {
      for (final log in logs) {
        final date = _dateOnly(log.occurredAt);
        final count = log.count < 1 ? 1 : log.count;
        final bucket = buckets.putIfAbsent(date, _TemptationDayDataBuilder.new);

        bucket.totalCount += count;
        if (log.didResist) {
          bucket.resistedCount += count;
        } else {
          bucket.slippedCount += count;
        }

        final reason = _reasonLabel(log.reasonText);
        bucket.reasonCounts[reason] =
            (bucket.reasonCounts[reason] ?? 0) + count;
        if (!log.didResist) {
          bucket.slipReasonCounts[reason] =
              (bucket.slipReasonCounts[reason] ?? 0) + count;
        }

        final intensity = log.intensityName;
        bucket.intensityCounts[intensity] =
            (bucket.intensityCounts[intensity] ?? 0) + count;
      }
    }

    return buckets.map((key, value) => MapEntry(key, value.build()));
  }

  Future<_PeriodReportData> _buildReportData(
    HabitRepository repository,
    List<Habit> allHabits,
  ) async {
    final availableQuitHabits =
        allHabits
            .where((habit) => habit.isQuitHabit && !habit.isArchived)
            .toList()
          ..sort((a, b) => a.title.compareTo(b.title));

    var activeHabits = allHabits.where((habit) {
      if (habit.isArchived) return false;
      if (widget.onlyQuitHabits) return habit.isQuitHabit;
      return !habit.shouldHideQuitHabit;
    }).toList();

    String? selectedQuitHabitId;
    if (_isQuitMode && _selectedQuitHabitId != null) {
      final exists = activeHabits.any((h) => h.id == _selectedQuitHabitId);
      if (exists) {
        selectedQuitHabitId = _selectedQuitHabitId;
        activeHabits = activeHabits
            .where((h) => h.id == _selectedQuitHabitId)
            .toList();
      }
    }

    final currentRange = _rangeFor(_selectedDate, _selectedPeriod);
    final previousRange = _previousRange(currentRange);
    final temptationByRange = await Future.wait<Map<DateTime, _TemptationDayData>>([
      _collectTemptationDaysInRange(activeHabits, currentRange),
      _collectTemptationDaysInRange(activeHabits, previousRange),
    ]);
    final currentTemptationByDay = temptationByRange[0];
    final previousTemptationByDay = temptationByRange[1];

    final dayReportsByRange = await Future.wait<List<_DayReport>>([
      _collectRange(repository, activeHabits, currentRange, currentTemptationByDay),
      _collectRange(
        repository,
        activeHabits,
        previousRange,
        previousTemptationByDay,
      ),
    ]);
    final currentDays = dayReportsByRange[0];
    final previousDays = dayReportsByRange[1];

    final habitsById = <String, Habit>{
      for (final habit in activeHabits) habit.id: habit,
    };

    return _PeriodReportData(
      currentRange: currentRange,
      previousRange: previousRange,
      currentDays: currentDays,
      previousDays: previousDays,
      habitsById: habitsById,
      isQuitMode: _isQuitMode,
      availableQuitHabits: availableQuitHabits,
      selectedQuitHabitId: selectedQuitHabitId,
    );
  }

  bool _isSuccessfulCompletion(HabitCompletion completion, Habit habit) {
    if (completion.isSkipped || completion.isPostponed) return false;

    switch (habit.completionType) {
      case 'yesNo':
      case 'yes_no':
        return completion.answer == true || completion.count > 0;
      case 'numeric':
        if (completion.actualValue != null) {
          final target = habit.targetValue ?? 1;
          return completion.actualValue! >= target;
        }
        return completion.count > 0 || completion.answer == true;
      case 'timer':
        if (completion.actualDurationMinutes != null) {
          final target = habit.targetDurationMinutes ?? 1;
          return completion.actualDurationMinutes! >= target;
        }
        return completion.count > 0 || completion.answer == true;
      case 'checklist':
        final itemCount = habit.checklist?.length ?? 1;
        return completion.answer == true || completion.count >= itemCount;
      case 'quit':
        if (completion.answer != null) return completion.answer == true;
        return completion.count > 0;
      default:
        return completion.answer == true || completion.count > 0;
    }
  }

  String _reasonLabel(String? reason) {
    final value = (reason ?? '').trim();
    return value.isEmpty ? 'No reason provided' : value;
  }

  String _quitPerformanceLabel(double score) {
    if (score >= 80) return 'Excellent';
    if (score >= 65) return 'Good';
    if (score >= 50) return 'Fair';
    return 'At Risk';
  }

  Color _quitPerformanceColor(double score) {
    if (score >= 80) return _successColor;
    if (score >= 65) return _infoColor;
    if (score >= 50) return _warningColor;
    return _dangerColor;
  }

  Color _triggerRiskColor(double slipRate) {
    if (slipRate >= 0.6) return _dangerColor;
    if (slipRate >= 0.35) return _warningColor;
    return _successColor;
  }

  String _triggerRiskLabel(double slipRate) {
    if (slipRate >= 0.6) return 'Critical';
    if (slipRate >= 0.35) return 'High';
    if (slipRate >= 0.15) return 'Moderate';
    return 'Low';
  }

  Color _intensityColorForName(String intensityName) {
    switch (intensityName.toLowerCase()) {
      case 'mild':
        return const Color(0xFF4CAF50);
      case 'moderate':
        return _warningColor;
      case 'strong':
        return const Color(0xFFFF7043);
      case 'extreme':
        return _dangerColor;
      default:
        return _infoColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_isQuitMode && !_quitAccessChecked && !_isCheckingQuitAccess) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _verifyQuitAccess();
      });
    }
    if (_isQuitMode && !_quitAccessChecked) {
      return Scaffold(
        backgroundColor: isDark ? _bgDark : _bgLight,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_isQuitMode && !_quitAccessGranted) {
      return Scaffold(
        backgroundColor: isDark ? _bgDark : _bgLight,
        body: const SizedBox.shrink(),
      );
    }
    final habitsAsync = ref.watch(habitNotifierProvider);
    final repository = ref.watch(habitRepositoryProvider);

    return Scaffold(
      backgroundColor: isDark ? _bgDark : _bgLight,
      body: habitsAsync.when(
        data: (habits) {
          final shouldRefreshReport =
              _reportFuture == null ||
              _reportRepository != repository ||
              _reportHabits != habits ||
              _reportSelectedDate != _selectedDate ||
              _reportSelectedPeriod != _selectedPeriod ||
              _reportSelectedQuitHabitId != _selectedQuitHabitId ||
              _reportQuitMode != widget.onlyQuitHabits;
          if (shouldRefreshReport) {
            _reportFuture = _buildReportData(repository, habits);
            _reportRepository = repository;
            _reportHabits = habits;
            _reportSelectedDate = _selectedDate;
            _reportSelectedPeriod = _selectedPeriod;
            _reportSelectedQuitHabitId = _selectedQuitHabitId;
            _reportQuitMode = widget.onlyQuitHabits;
          }
          return FutureBuilder<_PeriodReportData>(
            future: _reportFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                if (snapshot.data != null) {
                  return _buildReportView(context, isDark, snapshot.data!);
                }
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final report = snapshot.data;
              if (report == null) {
                return const Center(child: Text('No report data available'));
              }

              return _buildReportView(context, isDark, report);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildReportView(
    BuildContext context,
    bool isDark,
    _PeriodReportData report,
  ) {
    final sectionBuilders = <Widget Function()>[
      () => _buildPeriodSelector(isDark),
      () => const SizedBox(height: 20),
      () => _buildDateNavigator(context, isDark, report.currentRange),
      if (_isQuitMode) () => const SizedBox(height: 14),
      if (_isQuitMode) () => _buildQuitHabitSelector(isDark, report),
      () => const SizedBox(height: 24),
      () => _buildOverallProgressCard(isDark, report),
      () => const SizedBox(height: 20),
      () => _buildTrendChartCard(isDark, report),
      () => const SizedBox(height: 20),
      () => _buildStatsGrid(isDark, report),
      () => const SizedBox(height: 20),
      if (_isQuitMode) () => _buildTemptationInsightsCard(isDark, report),
      if (!_isQuitMode) () => _buildHabitTypeBreakdownCard(isDark, report),
      () => const SizedBox(height: 20),
      () => _buildSkipReasonsVisualCard(isDark, report),
      () => const SizedBox(height: 20),
      () => _buildFocusAreasCard(context, isDark, report),
      () => const SizedBox(height: 20),
      () => _buildHabitPressureCard(context, isDark, report),
      if (!_isQuitMode) () => const SizedBox(height: 20),
      if (!_isQuitMode) () => _buildQuitReportEntryCard(context, isDark),
      () => const SizedBox(height: 40),
    ];

    return CustomScrollView(
      key: const PageStorageKey('habit_report_scroll'),
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildAppBar(isDark),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => sectionBuilders[index](),
              childCount: sectionBuilders.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOverallProgressCard(bool isDark, _PeriodReportData report) {
    final rate = report.completionRate;
    final percent = (rate * 100).round();
    final hasPrev = report.previousTotalDue > 0;
    final prevPercent = (report.previousCompletionRate * 100).round();
    final deltaPoints = report.completionDelta * 100;
    final isUp = deltaPoints >= 0;
    final trendColor = hasPrev
        ? (deltaPoints.abs() < 1.0
              ? _infoColor
              : (isUp ? _successColor : _dangerColor))
        : (isDark ? Colors.white38 : Colors.black38);
    final subtitle = hasPrev
        ? 'vs previous ${_periodChipLabel(report.currentRange.period).toLowerCase()} ($prevPercent%)'
        : 'No previous data';
    final headline = _isQuitMode ? 'RECOVERY SCORE' : 'OVERALL SCORE';
    final completedLabel = _isQuitMode ? 'Wins' : 'Completed';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? _surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headline,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$percent',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1E1E1E),
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '%',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: trendColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isUp
                                ? Icons.trending_up_rounded
                                : Icons.trending_down_rounded,
                            color: trendColor,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            hasPrev
                                ? '${deltaPoints >= 0 ? '+' : ''}${deltaPoints.toStringAsFixed(1)}%'
                                : 'N/A',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: trendColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ],
                ),
              ),
              _VisualProgressRing(
                progress: rate,
                size: 120,
                strokeWidth: 14,
                color: _accentColor,
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.05),
                child: Icon(
                  Icons.emoji_events_rounded,
                  size: 40,
                  color: _accentColor.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withValues(alpha: 0.2) : _bgLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    isDark: isDark,
                    label: completedLabel,
                    value: '${report.completed}/${report.totalDue}',
                    valueColor: _successColor,
                    alignCenter: true,
                  ),
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
                Expanded(
                  child: _MiniStat(
                    isDark: isDark,
                    label: 'Points',
                    value: '+${report.pointsEarned}',
                    valueColor: _accentColor,
                    alignCenter: true,
                  ),
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
                Expanded(
                  child: _MiniStat(
                    isDark: isDark,
                    label: 'Net',
                    value:
                        '${report.netPoints >= 0 ? '+' : ''}${report.netPoints}',
                    valueColor: report.netPoints >= 0
                        ? _successColor
                        : _dangerColor,
                    alignCenter: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendChartCard(bool isDark, _PeriodReportData report) {
    if (_isQuitMode) {
      final overallScore = report.quitPerformanceScore;
      final overallColor = _quitPerformanceColor(overallScore);
      final overallLabel = _quitPerformanceLabel(overallScore);
      final hasPrevious = report.previousDays.isNotEmpty;
      final delta = report.quitPerformanceDelta;

      if (_selectedPeriod == HabitReportPeriod.day) {
        final day = report.currentDays.isEmpty
            ? null
            : report.currentDays.first;
        if (day == null) {
          return _InfoCard(
            isDark: isDark,
            title: 'Overall Quit Performance',
            icon: Icons.insights_rounded,
            iconColor: _infoColor,
            child: const Text('No data for this day.'),
          );
        }

        final score = _quitPerformanceScoreForDay(day);
        final scoreColor = _quitPerformanceColor(score);
        final scoreLabel = _quitPerformanceLabel(score);
        final net = day.pointsEarned - day.pointsLost;

        return _InfoCard(
          isDark: isDark,
          title: 'Overall Quit Performance',
          icon: Icons.insights_rounded,
          iconColor: scoreColor,
          child: Row(
            children: [
              _VisualProgressRing(
                progress: score / 100,
                size: 84,
                strokeWidth: 10,
                color: scoreColor,
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.05),
                child: Text(
                  '${score.round()}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MiniStat(
                      isDark: isDark,
                      label: 'Status',
                      value: scoreLabel,
                      valueColor: scoreColor,
                    ),
                    const SizedBox(height: 10),
                    _MiniStat(
                      isDark: isDark,
                      label: 'Wins / Slips',
                      value: '${day.completed} / ${day.skipped}',
                      valueColor: day.skipped == 0
                          ? _successColor
                          : _warningColor,
                    ),
                    const SizedBox(height: 10),
                    _MiniStat(
                      isDark: isDark,
                      label: 'Net Points',
                      value: '${net >= 0 ? '+' : ''}$net',
                      valueColor: net >= 0 ? _successColor : _dangerColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }

      return _InfoCard(
        isDark: isDark,
        title: 'Overall Quit Performance',
        icon: Icons.insights_rounded,
        iconColor: overallColor,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: overallColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '${overallScore.round()}%',
            style: TextStyle(
              color: overallColor,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$overallLabel overall performance',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                if (hasPrevious)
                  Text(
                    '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} pts',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: delta >= 0 ? _successColor : _dangerColor,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 210,
              child: _QuitPerformanceLineChart(
                isDark: isDark,
                days: report.currentDays,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Score combines wins, temptations resisted, and point balance to show if you are doing good or not.',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white38 : Colors.black38,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    final snapshotTitle = _isQuitMode
        ? 'Daily Recovery Snapshot'
        : 'Today\'s Snapshot';

    if (_selectedPeriod == HabitReportPeriod.day) {
      final day = report.currentDays.isEmpty ? null : report.currentDays.first;
      if (day == null) {
        return _InfoCard(
          isDark: isDark,
          title: snapshotTitle,
          icon: Icons.show_chart_rounded,
          iconColor: _infoColor,
          child: const Text('No data for this day.'),
        );
      }
      // Day view: visual ring + key stats
      final dayRate = day.due == 0 ? 0.0 : day.completed / day.due;
      final dayPercent = (dayRate * 100).round();
      final net = day.pointsEarned - day.pointsLost;
      return _InfoCard(
        isDark: isDark,
        title: snapshotTitle,
        icon: Icons.show_chart_rounded,
        iconColor: _infoColor,
        child: Row(
          children: [
            _VisualProgressRing(
              progress: dayRate,
              size: 80,
              strokeWidth: 10,
              color: dayRate >= 0.5 ? _successColor : _dangerColor,
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.05),
              child: Text(
                '$dayPercent%',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MiniStat(
                    isDark: isDark,
                    label: _isQuitMode ? 'Wins' : 'Completed',
                    value: '${day.completed}/${day.due}',
                    valueColor: _successColor,
                  ),
                  const SizedBox(height: 12),
                  _MiniStat(
                    isDark: isDark,
                    label: 'Points Earned',
                    value: '+${day.pointsEarned}',
                    valueColor: _accentColor,
                  ),
                  const SizedBox(height: 12),
                  _MiniStat(
                    isDark: isDark,
                    label: 'Net',
                    value: '${net >= 0 ? '+' : ''}$net',
                    valueColor: net >= 0 ? _successColor : _dangerColor,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Week / Month: show daily completion rate (same metric as hero card)
    final isWeek = _selectedPeriod == HabitReportPeriod.week;

    // Determine trend direction by comparing first half vs second half of period
    var isDeclining = false;
    if (report.currentDays.length >= 2) {
      final midpoint = report.currentDays.length ~/ 2;
      double firstHalfCompleted = 0, firstHalfDue = 0;
      double secondHalfCompleted = 0, secondHalfDue = 0;
      for (var i = 0; i < report.currentDays.length; i++) {
        final d = report.currentDays[i];
        if (i < midpoint) {
          firstHalfCompleted += d.completed;
          firstHalfDue += d.due;
        } else {
          secondHalfCompleted += d.completed;
          secondHalfDue += d.due;
        }
      }
      final firstHalfRate = firstHalfDue == 0
          ? 0.0
          : firstHalfCompleted / firstHalfDue;
      final secondHalfRate = secondHalfDue == 0
          ? 0.0
          : secondHalfCompleted / secondHalfDue;
      isDeclining = secondHalfRate < firstHalfRate - 0.02; // 2pp tolerance
    }

    final trendColor = isDeclining ? _dangerColor : _successColor;

    return _InfoCard(
      isDark: isDark,
      title: _isQuitMode ? 'Recovery Trend' : 'Performance Trend',
      icon: Icons.show_chart_rounded,
      iconColor: isDeclining ? _dangerColor : _infoColor,
      trailing: report.currentDays.length >= 2
          ? Icon(
              isDeclining ? Icons.south_east_rounded : Icons.north_east_rounded,
              color: trendColor,
              size: 20,
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 200,
            child: isWeek
                ? _WeeklyCompletionBarChart(
                    isDark: isDark,
                    days: report.currentDays,
                  )
                : _CompletionRateTrendChart(
                    isDark: isDark,
                    days: report.currentDays,
                  ),
          ),
          const SizedBox(height: 12),
          Text(
            isWeek
                ? (_isQuitMode ? 'Win rate per day' : 'Completion rate per day')
                : (_isQuitMode
                      ? 'Daily win rate across the period'
                      : 'Daily completion rate across the period'),
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white38 : Colors.black38,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHabitTypeBreakdownCard(bool isDark, _PeriodReportData report) {
    final breakdown = report.completionTypeBreakdown;

    return _InfoCard(
      isDark: isDark,
      title: 'Habit Type Breakdown',
      icon: Icons.pie_chart_rounded,
      iconColor: _accentColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Completion rate by habit type, based on due days in this period.',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
          const SizedBox(height: 16),
          if (breakdown.isEmpty)
            Text(
              'No habits were due in this period.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ...breakdown.map(
            (stats) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _CompletionTypeRow(isDark: isDark, stats: stats),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemptationInsightsCard(bool isDark, _PeriodReportData report) {
    final temptationTotal = report.temptationTotal;
    final resisted = report.temptationResisted;
    final slipped = report.temptationSlipped;
    final ratePercent = (report.resistanceRate * 100).round();
    final controlPercent = (report.triggerControlScore * 100).round();
    final averagePerDay = report.averageTemptationsPerTrackedDay;
    final selectedHabit = report.selectedQuitHabit;
    final peakTemptationDay = report.peakTemptationDay;
    final temptationDays = report.temptationDaysWithEvents;
    final topTrigger = report.topTemptationReason;
    final topSlipTrigger = report.topSlipTemptationTrigger;
    final strongestResisted = report.strongestResistedTrigger;
    final highestRisk = report.highestRiskTrigger;
    final triggerInsights = report.temptationTriggerInsights;
    final visibleTriggers = _showAllTemptationTriggers
        ? triggerInsights
        : triggerInsights.take(4).toList();
    final intensityEntries =
        const <String>['Mild', 'Moderate', 'Strong', 'Extreme']
            .map(
              (name) =>
                  MapEntry(name, report.temptationIntensityCounts[name] ?? 0),
            )
            .where((entry) => entry.value > 0)
            .toList();

    final theme = Theme.of(context).copyWith(dividerColor: Colors.transparent);
    return Container(
      decoration: BoxDecoration(
        color: isDark ? _surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Theme(
        data: theme,
        child: ExpansionTile(
          key: const PageStorageKey<String>(
            'habit_report_temptation_expansion',
          ),
          initiallyExpanded: _temptationInsightsExpanded,
          onExpansionChanged: (value) =>
              setState(() => _temptationInsightsExpanded = value),
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _warningColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.psychology_rounded,
              color: _warningColor,
              size: 20,
            ),
          ),
          title: Text(
            'Temptation Intelligence',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          subtitle: Text(
            _temptationInsightsExpanded
                ? 'Detailed trigger, day-by-day, and slip-risk analysis'
                : 'Tap to open full temptation report',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (selectedHabit != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: _accentColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Focused habit: ${selectedHabit.title}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _accentColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  'Use period + calendar to inspect today, tomorrow, this month, last month, or any specific date.',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    _MiniStat(
                      isDark: isDark,
                      label: 'Temptations',
                      value: '$temptationTotal',
                      valueColor: _warningColor,
                    ),
                    _MiniStat(
                      isDark: isDark,
                      label: 'Resisted',
                      value: '$resisted',
                      valueColor: _successColor,
                    ),
                    _MiniStat(
                      isDark: isDark,
                      label: 'Led to slip',
                      value: '$slipped',
                      valueColor: _dangerColor,
                    ),
                    _MiniStat(
                      isDark: isDark,
                      label: 'Resistance',
                      value: '$ratePercent%',
                      valueColor: ratePercent >= 70
                          ? _successColor
                          : _warningColor,
                    ),
                    _MiniStat(
                      isDark: isDark,
                      label: 'Trigger Control',
                      value: '$controlPercent%',
                      valueColor: controlPercent >= 70
                          ? _successColor
                          : _warningColor,
                    ),
                    _MiniStat(
                      isDark: isDark,
                      label: 'Avg/day',
                      value: averagePerDay.toStringAsFixed(1),
                      valueColor: _infoColor,
                    ),
                    _MiniStat(
                      isDark: isDark,
                      label: 'Active days',
                      value:
                          '${temptationDays.length}/${report.currentDays.length}',
                      valueColor: _infoColor,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (topTrigger != null)
                  Text(
                    'Top trigger: "${topTrigger.key}" (${topTrigger.value}x)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  )
                else
                  Text(
                    'No temptation logs recorded in this period.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                if (topSlipTrigger != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Trigger causing most slips: "${topSlipTrigger.key}" (${topSlipTrigger.value} slips)',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ],
                if (peakTemptationDay != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Peak day: ${DateFormat('EEE, MMM d').format(peakTemptationDay.date)} '
                    '(${peakTemptationDay.temptationTotal} urges, ${peakTemptationDay.temptationSlipped} slipped)',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ],
                if (triggerInsights.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.03)
                          : Colors.black.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.04),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Trigger Risk Breakdown',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${triggerInsights.length} triggers',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white54 : Colors.black45,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...visibleTriggers.map((insight) {
                          final riskPercent = (insight.slipRate * 100).round();
                          final riskColor = _triggerRiskColor(insight.slipRate);
                          final riskLabel = _triggerRiskLabel(insight.slipRate);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        insight.trigger,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black87,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: riskColor.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '$riskLabel $riskPercent%',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: riskColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${insight.total} urges | ${insight.resisted} resisted | ${insight.slipped} slipped',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: insight.slipRate.clamp(0.0, 1.0),
                                    minHeight: 8,
                                    backgroundColor: isDark
                                        ? Colors.white.withValues(alpha: 0.07)
                                        : Colors.black.withValues(alpha: 0.06),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      riskColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        if (triggerInsights.length > 4)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => setState(
                                () => _showAllTemptationTriggers =
                                    !_showAllTemptationTriggers,
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: _warningColor,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                              ),
                              child: Text(
                                _showAllTemptationTriggers
                                    ? 'Show fewer triggers'
                                    : 'Show all triggers',
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                if (highestRisk != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Highest slip risk: "${highestRisk.trigger}" '
                    '(${(highestRisk.slipRate * 100).round()}% slip rate).',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _triggerRiskColor(highestRisk.slipRate),
                    ),
                  ),
                ],
                if (strongestResisted != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Best controlled trigger: "${strongestResisted.trigger}" '
                    '(${strongestResisted.resisted}/${strongestResisted.total} resisted).',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ],
                if (intensityEntries.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Urge intensity distribution',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...intensityEntries.map((entry) {
                    final share = temptationTotal == 0
                        ? 0.0
                        : entry.value / temptationTotal;
                    final intensityColor = _intensityColorForName(entry.key);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                entry.key,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black87,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${entry.value} (${(share * 100).round()}%)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: intensityColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: share.clamp(0.0, 1.0),
                              minHeight: 7,
                              backgroundColor: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : Colors.black.withValues(alpha: 0.06),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                intensityColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                if (temptationDays.isNotEmpty &&
                    _selectedPeriod != HabitReportPeriod.day) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Daily temptation timeline',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...(() {
                    final ordered = List<_DayReport>.from(temptationDays)
                      ..sort((a, b) => a.date.compareTo(b.date));
                    final visible = _showAllTemptationDays
                        ? ordered
                        : ordered.take(8).toList();
                    final maxDayLoad = ordered.fold<int>(
                      1,
                      (maxValue, day) =>
                          math.max(maxValue, day.temptationTotal),
                    );

                    return <Widget>[
                      ...visible.map((day) {
                        final slipRate = day.temptationTotal == 0
                            ? 0.0
                            : day.temptationSlipped / day.temptationTotal;
                        final barColor = _triggerRiskColor(slipRate);
                        final ratio =
                            day.temptationTotal / maxDayLoad.toDouble();
                        final dayRate = day.temptationTotal == 0
                            ? 0
                            : (day.temptationResisted /
                                      day.temptationTotal *
                                      100)
                                  .round();

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    DateFormat('EEE, MMM d').format(day.date),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black87,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${day.temptationTotal} urges | $dayRate% resisted',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.black54,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: ratio.clamp(0.0, 1.0).toDouble(),
                                  minHeight: 7,
                                  backgroundColor: isDark
                                      ? Colors.white.withValues(alpha: 0.06)
                                      : Colors.black.withValues(alpha: 0.06),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    barColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      if (ordered.length > 8)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => setState(
                              () => _showAllTemptationDays =
                                  !_showAllTemptationDays,
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: _warningColor,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                            ),
                            child: Text(
                              _showAllTemptationDays
                                  ? 'Show fewer days'
                                  : 'Show all days',
                            ),
                          ),
                        ),
                    ];
                  })(),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkipReasonsVisualCard(bool isDark, _PeriodReportData report) {
    final sorted = report.blockerReasonCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final title = _isQuitMode
        ? 'Slip Trigger Frequency'
        : 'Skip Reason Frequency';
    final emptyMessage = _isQuitMode
        ? 'No slip triggers logged in this period.'
        : 'No skip reasons logged in this period.';
    final logsLabel = _isQuitMode ? 'trigger logs' : 'logs';

    if (sorted.isEmpty) {
      return _InfoCard(
        isDark: isDark,
        title: _isQuitMode ? 'Slip Triggers' : 'Skip Reasons',
        icon: Icons.psychology_rounded,
        iconColor: _warningColor,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: Text(
              emptyMessage,
              style: TextStyle(
                color: isDark ? Colors.white38 : Colors.black38,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),
      );
    }

    final maxVal = sorted.first.value;
    final visible = _showAllReasons ? sorted : sorted.take(4).toList();

    return _InfoCard(
      isDark: isDark,
      title: title,
      icon: Icons.psychology_rounded,
      iconColor: _warningColor,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _warningColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '${report.totalReasonEntries} $logsLabel',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _warningColor,
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          ...visible.map((entry) {
            final ratio = entry.value / maxVal;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          entry.key,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                      Text(
                        '${entry.value}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _warningColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Stack(
                    children: [
                      Container(
                        height: 10,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: ratio,
                        child: Container(
                          height: 10,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _warningColor,
                                _warningColor.withValues(alpha: 0.6),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          if (sorted.length > 4)
            TextButton(
              onPressed: () =>
                  setState(() => _showAllReasons = !_showAllReasons),
              style: TextButton.styleFrom(foregroundColor: _warningColor),
              child: Text(
                _showAllReasons
                    ? 'Show Less'
                    : 'Show All ${sorted.length} Reasons',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAppBar(bool isDark) {
    final reportTitle =
        widget.titleOverride ??
        (widget.onlyQuitHabits ? 'Quit Habit Report' : 'Habit Report');
    final reportSubtitle = widget.subtitleOverride;
    final reportIcon = widget.onlyQuitHabits
        ? Icons.shield_rounded
        : Icons.insights_rounded;

    return SliverAppBar(
      pinned: true,
      expandedHeight: 0,
      toolbarHeight: 68,
      backgroundColor: isDark ? _bgDark : _bgLight,
      elevation: 0,
      centerTitle: false,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(reportIcon, color: _accentColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reportTitle,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF2D3436),
                    letterSpacing: -0.5,
                  ),
                ),
                if (reportSubtitle != null && reportSubtitle.isNotEmpty)
                  Text(
                    reportSubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () async {
            final picked = await _pickDateWithTodayShortcut(context);
            if (picked != null) {
              setState(() {
                _selectedDate = picked;
                _resetExpandedPanels();
              });
            }
          },
          icon: Icon(
            Icons.calendar_month_rounded,
            color: isDark ? Colors.white70 : Colors.black54,
            size: 22,
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildPeriodSelector(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? _surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.03),
        ),
      ),
      child: Row(
        children: HabitReportPeriod.values.map((period) {
          final selected = _selectedPeriod == period;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (_selectedPeriod == period) return;
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedPeriod = period;
                  _resetExpandedPanels();
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? (isDark
                            ? const Color(0xFF2C2C3E)
                            : const Color(0xFFF0F2F5))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _periodChipLabel(period),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? (isDark ? Colors.white : Colors.black87)
                        : (isDark ? Colors.white54 : Colors.black54),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDateNavigator(
    BuildContext context,
    bool isDark,
    _PeriodRange range,
  ) {
    final today = _dateOnly(DateTime.now());
    final quickActions = <MapEntry<String, DateTime>>[];
    switch (_selectedPeriod) {
      case HabitReportPeriod.day:
        quickActions.add(MapEntry('Today', today));
        quickActions.add(
          MapEntry('Tomorrow', today.add(const Duration(days: 1))),
        );
        break;
      case HabitReportPeriod.week:
        quickActions.add(MapEntry('This Week', today));
        quickActions.add(
          MapEntry('Last Week', today.subtract(const Duration(days: 7))),
        );
        break;
      case HabitReportPeriod.month:
        quickActions.add(MapEntry('This Month', today));
        quickActions.add(MapEntry('Last Month', _addMonths(today, -1)));
        break;
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedDate = _shiftedDate(-1);
                  _resetExpandedPanels();
                });
              },
              icon: Icon(
                Icons.chevron_left_rounded,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
              style: IconButton.styleFrom(
                backgroundColor: isDark ? _surfaceDark : Colors.white,
                padding: const EdgeInsets.all(12),
              ),
            ),
            Column(
              children: [
                Text(
                  _navigatorTitle(range),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatRange(range),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.black45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            IconButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedDate = _shiftedDate(1);
                  _resetExpandedPanels();
                });
              },
              icon: Icon(
                Icons.chevron_right_rounded,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
              style: IconButton.styleFrom(
                backgroundColor: isDark ? _surfaceDark : Colors.white,
                padding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: quickActions.map((action) {
            bool isSelected;
            if (_selectedPeriod == HabitReportPeriod.day) {
              isSelected = _dateOnly(_selectedDate) == _dateOnly(action.value);
            } else if (_selectedPeriod == HabitReportPeriod.week) {
              isSelected =
                  _rangeFor(_selectedDate, HabitReportPeriod.week).start ==
                  _rangeFor(action.value, HabitReportPeriod.week).start;
            } else {
              isSelected =
                  _selectedDate.year == action.value.year &&
                  _selectedDate.month == action.value.month;
            }
            return ChoiceChip(
              label: Text(action.key),
              selected: isSelected,
              onSelected: (_) {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedDate = action.value;
                  _resetExpandedPanels();
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildQuitHabitSelector(bool isDark, _PeriodReportData report) {
    final quitHabits = report.availableQuitHabits;
    if (quitHabits.isEmpty) return const SizedBox.shrink();

    final selectedId = report.selectedQuitHabitId;
    final selectedHabit = report.selectedQuitHabit;
    final subtitle = selectedHabit == null
        ? 'Viewing all quit habits'
        : 'Viewing "${selectedHabit.title}"';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? _surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quit Habit Focus',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('All Quit Habits'),
                  selected: selectedId == null,
                  onSelected: (_) {
                    if (_selectedQuitHabitId == null) return;
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selectedQuitHabitId = null;
                      _resetExpandedPanels();
                    });
                  },
                ),
                for (final habit in quitHabits) ...[
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(habit.title, overflow: TextOverflow.ellipsis),
                    selected: selectedId == habit.id,
                    onSelected: (_) {
                      if (_selectedQuitHabitId == habit.id) return;
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedQuitHabitId = habit.id;
                        _resetExpandedPanels();
                      });
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(bool isDark, _PeriodReportData report) {
    final isDay = _selectedPeriod == HabitReportPeriod.day;
    final bestDay = report.bestDay;
    final bestLabel = bestDay == null
        ? 'N/A'
        : '${DateFormat('E').format(bestDay.date)} '
              '${bestDay.due == 0 ? 0 : (bestDay.completed / bestDay.due * 100).round()}%';
    final recoveryRate = (report.completionRate * 100).round();
    final resistanceRate = (report.resistanceRate * 100).round();

    if (_isQuitMode) {
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.3,
        children: [
          _MetricCard(
            isDark: isDark,
            label: 'Due Days',
            value: '${report.totalDue}',
            icon: Icons.event_note_rounded,
            color: _accentColor,
          ),
          _MetricCard(
            isDark: isDark,
            label: 'Wins',
            value: '${report.completed}',
            icon: Icons.check_circle_rounded,
            color: _successColor,
          ),
          _MetricCard(
            isDark: isDark,
            label: 'Slips',
            value: '${report.skipped}',
            icon: Icons.warning_rounded,
            color: _dangerColor,
          ),
          _MetricCard(
            isDark: isDark,
            label: 'Temptations',
            value: '${report.temptationTotal}',
            icon: Icons.psychology_rounded,
            color: _warningColor,
          ),
          _MetricCard(
            isDark: isDark,
            label: 'Resisted',
            value: '${report.temptationResisted}',
            icon: Icons.shield_rounded,
            color: _successColor,
          ),
          _MetricCard(
            isDark: isDark,
            label: isDay ? 'Recovery' : 'Resistance',
            value: '${isDay ? recoveryRate : resistanceRate}%',
            icon: Icons.trending_up_rounded,
            color: (isDay ? recoveryRate : resistanceRate) >= 70
                ? _successColor
                : _warningColor,
          ),
        ],
      );
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: [
        _MetricCard(
          isDark: isDark,
          label: 'Due',
          value: '${report.totalDue}',
          icon: Icons.event_note_rounded,
          color: _accentColor,
        ),
        _MetricCard(
          isDark: isDark,
          label: 'Completed',
          value: '${report.completed}',
          icon: Icons.check_circle_rounded,
          color: _successColor,
        ),
        _MetricCard(
          isDark: isDark,
          label: 'Skipped',
          value: '${report.skipped}',
          icon: Icons.skip_next_rounded,
          color: _warningColor,
        ),
        _MetricCard(
          isDark: isDark,
          label: 'Missed',
          value: '${report.missed}',
          icon: Icons.error_outline_rounded,
          color: _dangerColor,
        ),
        if (isDay)
          _MetricCard(
            isDark: isDark,
            label: 'Pending',
            value: '${report.pending}',
            icon: Icons.pending_rounded,
            color: _infoColor,
          )
        else
          _MetricCard(
            isDark: isDark,
            label: 'Best Day',
            value: bestLabel,
            icon: Icons.star_rounded,
            color: _successColor,
          ),
        _MetricCard(
          isDark: isDark,
          label: 'Net Points',
          value: '${report.netPoints >= 0 ? '+' : ''}${report.netPoints}',
          icon: Icons.stars_rounded,
          color: report.netPoints >= 0 ? _successColor : _dangerColor,
        ),
      ],
    );
  }

  Widget _buildFocusAreasCard(
    BuildContext context,
    bool isDark,
    _PeriodReportData report,
  ) {
    final topReason = report.topReason;
    final topHabitEntry = report.topSkippedHabit;
    final topHabitName = topHabitEntry == null
        ? null
        : (report.habitsById[topHabitEntry.key]?.title ?? 'Unknown habit');
    final topTemptation = report.topTemptationReason;

    final trendLabel = _isQuitMode
        ? (report.completionDelta > 0.02
              ? 'Recovery momentum is improving. Keep protecting your trigger windows.'
              : report.completionDelta < -0.02
              ? 'Recovery momentum dropped. Strengthen your temptation response plan.'
              : 'Recovery is stable. Focus on your highest-risk triggers.')
        : (report.completionDelta > 0.02
              ? 'Momentum is positive. Your recovery strategy is working!'
              : report.completionDelta < -0.02
              ? 'Momentum is dropping. Consider reducing habit difficulty.'
              : 'Momentum is stable. Focus on your most frequent blocker.');
    final insightsTitle = _isQuitMode
        ? 'Recovery Insights'
        : 'Actionable Insights';
    final insightsSubtitle = _isQuitMode
        ? 'Tap to review slip and temptation risk areas'
        : 'Tap to view your focus areas';
    final blockerTitle = _isQuitMode ? 'Top Slip Trigger' : 'Primary Blocker';
    final blockerDescription = topReason == null
        ? (_isQuitMode
              ? 'No repeated slip trigger detected. Strong control this period.'
              : 'No repeated blockers detected. Great consistency!')
        : '"${topReason.key}" was cited ${topReason.value} times.';
    final impactedTitle = _isQuitMode ? 'Most Slipped Habit' : 'Most Impacted';
    final impactedDescription = topHabitName == null
        ? (_isQuitMode
              ? 'No recurring slip pressure across your quit habits.'
              : 'All habits are performing equally well.')
        : _isQuitMode
        ? '"$topHabitName" has the highest slip frequency.'
        : '"$topHabitName" has the highest skip rate.';
    final temptationTitle = _isQuitMode ? 'Temptation Driver' : 'Momentum';
    final temptationDescription = _isQuitMode
        ? (topTemptation == null
              ? 'No temptation logs yet in this period.'
              : '"${topTemptation.key}" appeared ${topTemptation.value} times.')
        : trendLabel;

    final theme = Theme.of(context).copyWith(dividerColor: Colors.transparent);
    return Container(
      decoration: BoxDecoration(
        color: isDark ? _surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Theme(
        data: theme,
        child: ExpansionTile(
          key: const PageStorageKey<String>('habit_report_insights_expansion'),
          initiallyExpanded: _insightsExpanded,
          onExpansionChanged: (value) =>
              setState(() => _insightsExpanded = value),
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: _accentColor,
              size: 20,
            ),
          ),
          title: Text(
            insightsTitle,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          subtitle: Text(
            insightsSubtitle,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _InsightCard(
                  isDark: isDark,
                  icon: Icons.lightbulb_rounded,
                  iconColor: _warningColor,
                  title: blockerTitle,
                  description: blockerDescription,
                ),
                const SizedBox(height: 12),
                _InsightCard(
                  isDark: isDark,
                  icon: Icons.track_changes_rounded,
                  iconColor: _dangerColor,
                  title: impactedTitle,
                  description: impactedDescription,
                ),
                const SizedBox(height: 12),
                _InsightCard(
                  isDark: isDark,
                  icon: _isQuitMode
                      ? Icons.psychology_rounded
                      : Icons.trending_up_rounded,
                  iconColor: _isQuitMode ? _warningColor : _successColor,
                  title: temptationTitle,
                  description: temptationDescription,
                ),
                if (_isQuitMode) ...[
                  const SizedBox(height: 12),
                  _InsightCard(
                    isDark: isDark,
                    icon: Icons.trending_up_rounded,
                    iconColor: _successColor,
                    title: 'Momentum',
                    description: trendLabel,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHabitPressureCard(
    BuildContext context,
    bool isDark,
    _PeriodReportData report,
  ) {
    final entries = report.skipCountByHabit.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (entries.isEmpty) return const SizedBox.shrink();

    return _InfoCard(
      isDark: isDark,
      title: _isQuitMode ? 'Most Slipped Habits' : 'Most Skipped Habits',
      icon: Icons.warning_rounded,
      iconColor: _dangerColor,
      child: Column(
        children: entries.take(5).map((entry) {
          final habit = report.habitsById[entry.key];
          if (habit == null) return const SizedBox.shrink();

          return GestureDetector(
            onTap: () => _openHabit(context, habit),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.black.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.03),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: habit.color.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      habit.icon ?? Icons.track_changes_rounded,
                      color: habit.color,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      habit.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _dangerColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${entry.value}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _dangerColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildQuitReportEntryCard(BuildContext context, bool isDark) {
    return InkWell(
      onTap: () => _openSecureQuitReport(context),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _dangerColor.withValues(alpha: 0.22),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: _dangerColor.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _dangerColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.health_and_safety_outlined,
                color: _dangerColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quit Habit Report',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF2D3436),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Open secure slip, temptation, and recovery analytics',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSecureQuitReport(BuildContext context) async {
    final guard = QuitHabitReportAccessGuard();
    final unlocked = await guard.ensureAccess(
      context,
      onSecurityEmergencyReset: () async {
        await ref.read(habitNotifierProvider.notifier).loadHabits();
      },
    );
    if (!context.mounted || !unlocked) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => HabitReportScreen(
          initialDate: _selectedDate,
          onlyQuitHabits: true,
          titleOverride: 'Quit Habit Report',
          subtitleOverride: 'Win, slip, and temptation analytics',
        ),
      ),
    );
  }

  void _openHabit(BuildContext context, Habit habit) {
    HabitDetailModal.show(context, habit: habit, selectedDate: _selectedDate);
  }
}
