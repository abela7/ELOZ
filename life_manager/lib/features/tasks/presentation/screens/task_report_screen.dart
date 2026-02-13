import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../data/models/category.dart';
import '../../../../data/models/task.dart';
import '../providers/category_providers.dart';
import '../providers/task_providers.dart';
import '../widgets/task_detail_modal.dart';

/// Comprehensive Daily Task Report Screen
class TaskReportScreen extends ConsumerStatefulWidget {
  final DateTime? initialDate;

  const TaskReportScreen({super.key, this.initialDate});

  @override
  ConsumerState<TaskReportScreen> createState() => _TaskReportScreenState();
}

enum ReportTab { overview, timeline }

class _TaskReportScreenState extends ConsumerState<TaskReportScreen>
    with SingleTickerProviderStateMixin {
  late DateTime _selectedDate;
  late AnimationController _animController;
  bool _showAllNotDoneReasons = false;
  bool _showAllPostponeReasons = false;
  bool _showPointsBreakdown = false;
  ReportTab _selectedTab = ReportTab.overview;

  // Theme colors
  static const _accentColor = Color(0xFFCDAF56);
  static const _successColor = Color(0xFF4CAF50);
  static const _dangerColor = Color(0xFFFF6B6B);
  static const _warningColor = Color(0xFFFFB347);
  static const _infoColor = Color(0xFF5C9CE6);
  static const _purpleColor = Color(0xFF9D7CE5);

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    final today = _dateOnly(now);
    final target = _dateOnly(date);

    if (target == today) return 'Today';
    if (target == today.subtract(const Duration(days: 1))) return 'Yesterday';
    if (target == today.add(const Duration(days: 1))) return 'Tomorrow';
    return DateFormat('EEE, MMM d').format(date);
  }

  /// Get all tasks that were planned for this date
  List<Task> _getPlannedTasks(List<Task> allTasks, DateTime date) {
    final target = _dateOnly(date);
    final Set<String> seenIds = {};
    final List<Task> result = [];

    for (final task in allTasks) {
      // Task is due on this date
      if (_dateOnly(task.dueDate) == target) {
        if (!seenIds.contains(task.id)) {
          seenIds.add(task.id);
          result.add(task);
        }
        continue;
      }

      // Task was originally due on this date but moved
      if (task.originalDueDate != null && _dateOnly(task.originalDueDate!) == target) {
        if (!seenIds.contains(task.id)) {
          seenIds.add(task.id);
          result.add(task);
        }
        continue;
      }

      // Check postpone history
      final historyJson = task.postponeHistory;
      if (historyJson != null && historyJson.isNotEmpty) {
        try {
          final history = List<Map<String, dynamic>>.from(jsonDecode(historyJson));
          for (final entry in history) {
            final fromStr = entry['from'] as String?;
            if (fromStr == null) continue;
            final fromDate = _dateOnly(DateTime.parse(fromStr));
            if (fromDate == target) {
              if (!seenIds.contains(task.id)) {
                seenIds.add(task.id);
                result.add(task);
              }
              break;
            }
          }
        } catch (_) {}
      }
    }

    return result;
  }

  /// Get tasks completed on this specific date (regardless of when they were due)
  List<Task> _getCompletedOnDate(List<Task> allTasks, DateTime date) {
    final target = _dateOnly(date);
    return allTasks.where((t) {
      if (t.status != 'completed' || t.completedAt == null) return false;
      return _isSameDay(_dateOnly(t.completedAt!), target);
    }).toList();
  }

  String _getPostponeReason(Task task, DateTime date) {
    final target = _dateOnly(date);
    final historyJson = task.postponeHistory;

    if (historyJson != null && historyJson.isNotEmpty) {
      try {
        final history = List<Map<String, dynamic>>.from(jsonDecode(historyJson));
        for (final entry in history.reversed) {
          final fromStr = entry['from'] as String?;
          if (fromStr == null) continue;
          final fromDate = _dateOnly(DateTime.parse(fromStr));
          if (fromDate != target) continue;

          final reason = (entry['reason'] as String?)?.trim();
          if (reason != null && reason.isNotEmpty) return reason;
        }
      } catch (_) {}
    }

    final fallback = task.postponeReason?.trim();
    return (fallback == null || fallback.isEmpty) ? 'No reason provided' : fallback;
  }

  List<Map<String, dynamic>> _decodePostponeHistory(Task task) {
    final raw = task.postponeHistory;
    if (raw == null || raw.isEmpty) return const [];
    try {
      return List<Map<String, dynamic>>.from(jsonDecode(raw));
    } catch (_) {
      return const [];
    }
  }

  bool _isCompletedOnDate(Task task, DateTime date) {
    if (task.completedAt == null) return false;
    return _isSameDay(_dateOnly(task.completedAt!), _dateOnly(date));
  }

  bool _wasPostponedFromDate(Task task, DateTime date) {
    final target = _dateOnly(date);

    // Legacy archived tasks (old system)
    if (task.status == 'postponed' && _dateOnly(task.dueDate) == target) {
      return true;
    }

    // New system: original due date moved away
    if (task.originalDueDate != null &&
        _dateOnly(task.originalDueDate!) == target &&
        _dateOnly(task.dueDate) != target) {
      return true;
    }

    // Check postpone history (new system)
    final history = _decodePostponeHistory(task);
    for (final entry in history) {
      final fromStr = entry['from'] as String?;
      if (fromStr == null) continue;
      final fromDate = DateTime.tryParse(fromStr);
      if (fromDate == null) continue;
      if (_dateOnly(fromDate) == target) return true;
    }

    return false;
  }

  bool _isNotDoneOnDate(Task task, DateTime date) {
    if (task.status != 'not_done') return false;
    final target = _dateOnly(date);

    if (_dateOnly(task.dueDate) == target) return true;
    if (task.originalDueDate != null && _dateOnly(task.originalDueDate!) == target) {
      return true;
    }
    return false;
  }

  int _postponePenaltyOnDate(Task task, DateTime date) {
    final target = _dateOnly(date);
    final history = _decodePostponeHistory(task);
    int totalPenalty = 0;

    for (final entry in history) {
      DateTime? actionDate;
      final postponedAt = entry['postponedAt'] as String?;
      if (postponedAt != null) {
        actionDate = DateTime.tryParse(postponedAt);
      } else {
        final fromStr = entry['from'] as String?;
        actionDate = fromStr != null ? DateTime.tryParse(fromStr) : null;
      }

      if (actionDate == null) continue;
      if (_dateOnly(actionDate) != target) continue;

      int penalty = 0;
      final rawPenalty = entry['penaltyApplied'];
      if (rawPenalty is num) {
        penalty = rawPenalty.toInt();
      } else if (rawPenalty is String) {
        penalty = int.tryParse(rawPenalty) ?? 0;
      } else {
        penalty = -5; // Legacy default
      }

      if (penalty > 0) penalty = -penalty;
      totalPenalty += penalty;
    }

    return totalPenalty;
  }

  Map<String, int> _countReasons(Iterable<String?> reasons) {
    final Map<String, String> displayByKey = {};
    final Map<String, int> counts = {};

    for (final raw in reasons) {
      final trimmed = (raw ?? '').trim();
      final display = trimmed.isEmpty ? 'No reason provided' : trimmed;
      final key = display.toLowerCase();

      displayByKey.putIfAbsent(key, () => display);
      counts[key] = (counts[key] ?? 0) + 1;
    }

    final Map<String, int> result = {};
    for (final entry in counts.entries) {
      final display = displayByKey[entry.key] ?? entry.key;
      result[display] = entry.value;
    }

    return result;
  }

  /// Get hourly completion distribution
  Map<int, int> _getHourlyCompletions(List<Task> completedTasks) {
    final Map<int, int> hourly = {};
    for (int i = 0; i < 24; i++) {
      hourly[i] = 0;
    }
    
    for (final task in completedTasks) {
      if (task.completedAt != null) {
        final hour = task.completedAt!.hour;
        hourly[hour] = (hourly[hour] ?? 0) + 1;
      }
    }
    
    return hourly;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tasksAsync = ref.watch(taskNotifierProvider);
    final categories = ref.watch(categoryNotifierProvider).valueOrNull ?? const <Category>[];

    final categoriesById = <String, Category>{
      for (final c in categories) c.id: c,
    };

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0F14) : const Color(0xFFF8F9FA),
      body: tasksAsync.when(
        data: (allTasks) => _buildContent(context, isDark, allTasks, categoriesById),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    bool isDark,
    List<Task> allTasks,
    Map<String, Category> categoriesById,
  ) {
    return Column(
      children: [
        _buildAppBar(isDark),
        _buildTabSelector(isDark),
        Expanded(
          child: _selectedTab == ReportTab.overview
              ? _buildOverviewTab(context, isDark, allTasks, categoriesById)
              : _buildTimelineTab(context, isDark, allTasks, categoriesById),
        ),
      ],
    );
  }

  Widget _buildTabSelector(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF1A1D23) : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = ReportTab.overview),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: _selectedTab == ReportTab.overview ? _accentColor : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Text(
                  'Overview',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _selectedTab == ReportTab.overview 
                        ? _accentColor 
                        : (isDark ? Colors.white54 : Colors.grey),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = ReportTab.timeline),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: _selectedTab == ReportTab.timeline ? _accentColor : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Text(
                  'Timeline',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _selectedTab == ReportTab.timeline 
                        ? _accentColor 
                        : (isDark ? Colors.white54 : Colors.grey),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(
    BuildContext context,
    bool isDark,
    List<Task> allTasks,
    Map<String, Category> categoriesById,
  ) {
    // All tasks planned for this date
    final planned = _getPlannedTasks(allTasks, _selectedDate);
    final totalPlanned = planned.length;

    // All tasks actually completed on this date (may include tasks due on other days)
    final actualCompletionsOnDate = _getCompletedOnDate(allTasks, _selectedDate);

    // Categorize planned tasks by status
    final List<Task> completedTasks = [];      // Planned & completed on date
    final List<Task> notDoneTasks = [];        // Planned & marked not done
    final List<Task> postponedTasks = [];      // Planned & moved to another date
    final List<Task> pendingTasks = [];        // Planned & still pending

    for (final task in planned) {
      if (_isCompletedOnDate(task, _selectedDate)) {
        completedTasks.add(task);
      } else if (_wasPostponedFromDate(task, _selectedDate)) {
        postponedTasks.add(task);
      } else if (_isNotDoneOnDate(task, _selectedDate)) {
        notDoneTasks.add(task);
      } else {
        pendingTasks.add(task);
      }
    }

    // === METRICS ===
    
    final completionRate = totalPlanned == 0 ? 0.0 : completedTasks.length / totalPlanned;
    final failureRate = totalPlanned == 0 ? 0.0 : notDoneTasks.length / totalPlanned;
    final postponeRate = totalPlanned == 0 ? 0.0 : postponedTasks.length / totalPlanned;

    // === POINTS CALCULATION (Real data from tasks) ===
    // Each task stores its actual points earned/lost when completed/not done/postponed
    // We aggregate these real values to show the daily points summary
    
    int pointsEarned = 0;
    int pointsLost = 0;
    
    // 1. Points from tasks COMPLETED on this date
    // (Uses actual reward points stored in task.pointsEarned)
    for (final task in actualCompletionsOnDate) {
      final points = task.pointsEarned; // Real reward from task
      if (points > 0) {
        pointsEarned += points;
      } else if (points < 0) {
        // Rare case: completed task with negative points
        pointsLost += points.abs();
      }
    }

    // 2. Points from tasks marked NOT DONE on this date
    // (Uses actual penalty points stored in task.pointsEarned when marked not done)
    for (final task in notDoneTasks) {
      final penalty = task.pointsEarned; // Real penalty from task (negative)
      if (penalty < 0) {
        pointsLost += penalty.abs();
      } else if (penalty > 0) {
        // Edge case: not done task with positive points (shouldn't happen normally)
        pointsEarned += penalty;
      }
    }

    // 3. Points from tasks POSTPONED on this date
    // (Uses actual penalty from each postpone action in history)
    // We check all tasks to find any postpones that happened on this specific date
    for (final task in allTasks) {
      final postponePenalty = _postponePenaltyOnDate(task, _selectedDate);
      if (postponePenalty < 0) {
        pointsLost += postponePenalty.abs();
      } else if (postponePenalty > 0) {
        // Edge case: positive postpone penalty (shouldn't happen)
        pointsEarned += postponePenalty;
      }
    }

    final netPoints = pointsEarned - pointsLost;

    // Reasons analysis
    final notDoneReasonCounts = _countReasons(notDoneTasks.map((t) => t.notDoneReason));
    final postponedReasonCounts = _countReasons(
      postponedTasks.map((t) => _getPostponeReason(t, _selectedDate)),
    );

    // Priority breakdown
    final priorityStats = _buildPriorityStats(planned, completedTasks);

    // Task type breakdown
    final typeStats = _buildTypeStats(planned, completedTasks);
    final hasTypeStats = typeStats.values.any((stat) => stat.planned > 0);

    // Category breakdown
    final categoryStats = _buildCategoryStats(planned, completedTasks, categoriesById);

    // Hourly completions
    final hourlyCompletions = _getHourlyCompletions(actualCompletionsOnDate);
    final peakHour = hourlyCompletions.entries.reduce((a, b) => a.value >= b.value ? a : b);

    // Special tasks
    final specialPlanned = planned.where((t) => t.isSpecial).length;
    final specialCompleted = completedTasks.where((t) => t.isSpecial).length;

    return _buildReport(context, isDark, planned, completedTasks, notDoneTasks, postponedTasks, 
        pendingTasks, totalPlanned, completionRate, actualCompletionsOnDate, netPoints, 
        pointsEarned, pointsLost, peakHour.key, notDoneReasonCounts, postponedReasonCounts, 
        priorityStats, typeStats, hasTypeStats, categoryStats, specialPlanned, 
        specialCompleted, categoriesById);
  }

  Widget _buildReport(
    BuildContext context,
    bool isDark,
    List<Task> planned,
    List<Task> completedTasks,
    List<Task> notDoneTasks,
    List<Task> postponedTasks,
    List<Task> pendingTasks,
    int totalPlanned,
    double completionRate,
    List<Task> actualCompletionsOnDate,
    int netPoints,
    int pointsEarned,
    int pointsLost,
    int peakHourKey,
    Map<String, int> notDoneReasonCounts,
    Map<String, int> postponedReasonCounts,
    Map<String, _PriorityStat> priorityStats,
    Map<String, _TypeStat> typeStats,
    bool hasTypeStats,
    List<_CategoryStat> categoryStats,
    int specialPlanned,
    int specialCompleted,
    Map<String, Category> categoriesById,
  ) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildDateNavigator(isDark)),
        SliverToBoxAdapter(
          child: AnimatedBuilder(
            animation: _animController,
            builder: (context, child) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // === HERO SECTION ===
                    _buildHeroCard(isDark, totalPlanned, completedTasks.length, completionRate),
                    const SizedBox(height: 20),

                    // === QUICK STATS ROW ===
                    _buildQuickStats(isDark, actualCompletionsOnDate.length, netPoints, peakHourKey),
                    const SizedBox(height: 20),

                    // === STATUS BREAKDOWN ===
                    _buildSection(isDark, 'Status Breakdown', Icons.donut_large_rounded),
                    const SizedBox(height: 12),
                    _buildStatusGrid(isDark, totalPlanned, completedTasks.length, 
                        notDoneTasks.length, postponedTasks.length, pendingTasks.length),
                    const SizedBox(height: 12),
                    if (totalPlanned > 0)
                      _buildVisualBar(isDark, completedTasks.length, notDoneTasks.length, 
                          postponedTasks.length, pendingTasks.length),
                    if (totalPlanned > 0) const SizedBox(height: 20),

                    // === HOURLY ACTIVITY ===
                    if (actualCompletionsOnDate.isNotEmpty)
                      _buildHourlyChart(isDark, _getHourlyCompletions(actualCompletionsOnDate), peakHourKey),
                    if (actualCompletionsOnDate.isNotEmpty) const SizedBox(height: 20),

                    // === PRIORITY ANALYSIS ===
                    if (priorityStats.isNotEmpty)
                      _buildPriorityCard(isDark, priorityStats),
                    if (priorityStats.isNotEmpty) const SizedBox(height: 20),

                    // === TASK TYPE ANALYSIS ===
                    if (hasTypeStats)
                      _buildTypeCard(isDark, typeStats),
                    if (hasTypeStats) const SizedBox(height: 20),

                    // === SPECIAL TASKS ===
                    if (specialPlanned > 0)
                      _buildSpecialTasksCard(isDark, specialPlanned, specialCompleted),
                    if (specialPlanned > 0) const SizedBox(height: 20),

                    // === NOT DONE REASONS ===
                    if (notDoneTasks.isNotEmpty)
                      _buildReasonsCard(
                        isDark,
                        'Why Tasks Were Skipped',
                        Icons.psychology_rounded,
                        _dangerColor,
                        notDoneReasonCounts,
                        notDoneTasks.length,
                        _showAllNotDoneReasons,
                        () => setState(() => _showAllNotDoneReasons = !_showAllNotDoneReasons),
                      ),
                    if (notDoneTasks.isNotEmpty) const SizedBox(height: 16),

                    // === POSTPONE REASONS ===
                    if (postponedTasks.isNotEmpty)
                      _buildReasonsCard(
                        isDark,
                        'Why Tasks Were Postponed',
                        Icons.schedule_rounded,
                        _purpleColor,
                        postponedReasonCounts,
                        postponedTasks.length,
                        _showAllPostponeReasons,
                        () => setState(() => _showAllPostponeReasons = !_showAllPostponeReasons),
                      ),
                    if (postponedTasks.isNotEmpty) const SizedBox(height: 20),

                    // === CATEGORY PERFORMANCE ===
                    if (categoryStats.isNotEmpty)
                      _buildCategoryCard(isDark, categoryStats),
                    if (categoryStats.isNotEmpty) const SizedBox(height: 20),

                    // === TASK LISTS ===
                    _buildSection(isDark, 'Task Details', Icons.list_alt_rounded),
                    const SizedBox(height: 12),

                    if (completedTasks.isNotEmpty)
                      _buildTaskList(isDark, 'Completed', Icons.check_circle_rounded, 
                          _successColor, completedTasks, categoriesById,
                          (t) => t.completedAt != null 
                              ? 'Done at ${DateFormat('h:mm a').format(t.completedAt!)}' 
                              : 'Completed'),
                    if (completedTasks.isNotEmpty) const SizedBox(height: 12),

                    if (notDoneTasks.isNotEmpty)
                      _buildTaskList(isDark, 'Not Done', Icons.cancel_rounded, 
                          _dangerColor, notDoneTasks, categoriesById,
                          (t) => t.notDoneReason ?? 'No reason'),
                    if (notDoneTasks.isNotEmpty) const SizedBox(height: 12),

                    if (postponedTasks.isNotEmpty)
                      _buildTaskList(isDark, 'Postponed', Icons.update_rounded, 
                          _purpleColor, postponedTasks, categoriesById,
                          (t) => 'Moved to ${DateFormat('MMM d').format(t.dueDate)}'),
                    if (postponedTasks.isNotEmpty) const SizedBox(height: 12),

                    if (pendingTasks.isNotEmpty)
                      _buildTaskList(isDark, 'Still Pending', Icons.pending_rounded, 
                          _infoColor, pendingTasks, categoriesById,
                          (t) => _formatTime(t)),

                    // Empty state
                    if (totalPlanned == 0)
                      _buildEmptyState(isDark),

                    const SizedBox(height: 24),

                    // === POINTS SUMMARY (Small, at bottom) ===
                    _buildCompactPointsCard(
                      isDark, 
                      pointsEarned, 
                      pointsLost, 
                      netPoints,
                      actualCompletionsOnDate,
                      notDoneTasks,
                      _getPlannedTasks([], _selectedDate),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineTab(
    BuildContext context,
    bool isDark,
    List<Task> allTasks,
    Map<String, Category> categoriesById,
  ) {
    // Get all tasks planned for this date, sorted by time
    final planned = _getPlannedTasks(allTasks, _selectedDate);
    final tasksWithTime = planned.where((t) => t.dueTimeHour != null).toList();
    
    tasksWithTime.sort((a, b) {
      final aHour = a.dueTimeHour ?? 0;
      final aMin = a.dueTimeMinute ?? 0;
      final bHour = b.dueTimeHour ?? 0;
      final bMin = b.dueTimeMinute ?? 0;
      
      if (aHour != bHour) return aHour.compareTo(bHour);
      return aMin.compareTo(bMin);
    });

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildDateNavigator(isDark)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: tasksWithTime.isEmpty
                ? _buildTimelineEmptyState(isDark)
                : _buildTimelineView(context, isDark, tasksWithTime, categoriesById),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineView(
    BuildContext context,
    bool isDark,
    List<Task> tasksWithTime,
    Map<String, Category> categoriesById,
  ) {
    return Column(
      children: [
        // Timeline header with stats
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFF1E2128), const Color(0xFF1A1D23)]
                  : [Colors.white, const Color(0xFFFAFAFA)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _accentColor.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _accentColor.withOpacity(isDark ? 0.15 : 0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_accentColor, _accentColor.withOpacity(0.8)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: _accentColor.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.timeline_rounded,
                      size: 24,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daily Timeline',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          '${tasksWithTime.length} scheduled tasks',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white54 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Time range indicator
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _accentColor.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.access_time_rounded, size: 16, color: _accentColor),
                    const SizedBox(width: 8),
                    Text(
                      'Timeline: 00:00 - 23:59',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _accentColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Timeline with modern design
        ..._buildModernTimelineItems(context, isDark, tasksWithTime, categoriesById),
      ],
    );
  }

  List<Widget> _buildModernTimelineItems(
    BuildContext context,
    bool isDark,
    List<Task> tasksWithTime,
    Map<String, Category> categoriesById,
  ) {
    final items = <Widget>[];

    for (int i = 0; i < tasksWithTime.length; i++) {
      final task = tasksWithTime[i];
      final isLast = i == tasksWithTime.length - 1;
      final category = task.categoryId != null ? categoriesById[task.categoryId] : null;
      final catColor = category?.color ?? _accentColor;

      final hour = task.dueTimeHour ?? 0;
      final minute = task.dueTimeMinute ?? 0;
      final timeStr = DateFormat('h:mm a').format(DateTime(2000, 1, 1, hour, minute));

      items.add(
        _ModernTimelineItem(
          time: timeStr,
          task: task,
          category: category,
          catColor: catColor,
          isDark: isDark,
          isLast: isLast,
          onTap: () => _openTask(context, task),
        ),
      );
    }

    return items;
  }

  Widget _buildTimelineEmptyState(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D23) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(
            Icons.schedule_rounded,
            size: 64,
            color: isDark ? Colors.white24 : Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No Tasks Scheduled',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No tasks with times assigned for this day',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white54 : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // ========== UI COMPONENTS ==========

  Widget _buildAppBar(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1A1D23), const Color(0xFF0D0F14)]
              : [Colors.white, const Color(0xFFF8F9FA)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_accentColor, _accentColor.withOpacity(0.7)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: _accentColor.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.assessment_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Report',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      'Comprehensive day analysis',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    color: isDark ? Colors.white70 : Colors.black54,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateNavigator(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D23) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _NavButton(
            icon: Icons.chevron_left_rounded,
            isDark: isDark,
            onTap: () {
              HapticFeedback.selectionClick();
            setState(() {
                _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                _showAllNotDoneReasons = false;
                _showAllPostponeReasons = false;
              });
              _animController.reset();
              _animController.forward();
            },
          ),
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) {
                  setState(() {
                    _selectedDate = date;
                    _showAllNotDoneReasons = false;
                    _showAllPostponeReasons = false;
                  });
                  _animController.reset();
                  _animController.forward();
                }
              },
            child: Column(
                  children: [
                    Text(
                    _dateLabel(_selectedDate),
                    style: TextStyle(
                      fontSize: 18,
                            fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                          ),
                    ),
                    Text(
                    DateFormat('MMMM d, yyyy').format(_selectedDate),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.grey,
                          ),
                    ),
                  ],
                ),
            ),
          ),
          _NavButton(
            icon: Icons.chevron_right_rounded,
            isDark: isDark,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _selectedDate = _selectedDate.add(const Duration(days: 1));
                _showAllNotDoneReasons = false;
                _showAllPostponeReasons = false;
              });
              _animController.reset();
              _animController.forward();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(bool isDark, int total, int completed, double rate) {
    final rateColor = rate >= 0.8 ? _successColor : rate >= 0.5 ? _warningColor : _dangerColor;
    final percent = (rate * 100).toInt();
    final label = rate >= 0.8 ? 'Excellent!' : rate >= 0.5 ? 'Good' : 'Needs Improvement';

    return Container(
      padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1E2128), const Color(0xFF16181D)]
              : [Colors.white, const Color(0xFFFAFAFA)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _accentColor.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _accentColor.withValues(alpha: isDark ? 0.15 : 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: CircularProgressIndicator(
                    value: rate,
                    strokeWidth: 12,
                    strokeCap: StrokeCap.round,
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(rateColor),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$percent',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: rateColor,
                      ),
                    ),
                    Text(
                      '%',
                      style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                        color: rateColor.withValues(alpha: 0.7),
                          ),
                    ),
                  ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                    color: rateColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: rateColor,
                                  ),
                            ),
                          ),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '$completed',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      TextSpan(
                        text: ' / $total',
                        style: TextStyle(
                          fontSize: 20,
                                  fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white54 : Colors.grey,
                                ),
                          ),
                        ],
                      ),
                ),
                Text(
                  'tasks completed',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(bool isDark, int totalCompletions, int netPoints, int peakHour) {
    final hourLabel = peakHour == 0 ? '12 AM' : 
        peakHour < 12 ? '$peakHour AM' : 
        peakHour == 12 ? '12 PM' : '${peakHour - 12} PM';

    return Row(
              children: [
        Expanded(
          child: _QuickStatChip(
            icon: Icons.bolt_rounded,
            label: 'Total Done',
            value: totalCompletions.toString(),
            color: _successColor,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickStatChip(
            icon: Icons.stars_rounded,
            label: 'Net Points',
            value: netPoints > 0 ? '+$netPoints' : netPoints == 0 ? '0' : '$netPoints',
            color: netPoints > 0 ? _successColor : netPoints < 0 ? _dangerColor : _accentColor,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickStatChip(
            icon: Icons.schedule_rounded,
            label: 'Peak Hour',
            value: totalCompletions == 0 ? '—' : hourLabel,
            color: _accentColor,
            isDark: isDark,
          ),
        ),
      ],
            );
  }

  Widget _buildSection(bool isDark, String title, IconData icon) {
    return Row(
              children: [
        Icon(icon, size: 18, color: _accentColor),
        const SizedBox(width: 8),
                Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusGrid(bool isDark, int total, int completed, int notDone, int postponed, int pending) {
                    return Column(
                      children: [
                        Row(
                          children: [
            Expanded(child: _StatCard(
              icon: Icons.assignment_rounded,
              value: total,
              label: 'Planned',
              color: _accentColor,
              isDark: isDark,
            )),
            const SizedBox(width: 10),
            Expanded(child: _StatCard(
              icon: Icons.check_circle_rounded,
              value: completed,
              label: 'Done',
              color: _successColor,
              isDark: isDark,
            )),
          ],
        ),
        const SizedBox(height: 10),
                        Row(
                          children: [
            Expanded(child: _StatCard(
              icon: Icons.cancel_rounded,
              value: notDone,
              label: 'Not Done',
              color: _dangerColor,
              isDark: isDark,
            )),
            const SizedBox(width: 10),
            Expanded(child: _StatCard(
              icon: Icons.update_rounded,
              value: postponed,
              label: 'Postponed',
              color: _purpleColor,
              isDark: isDark,
            )),
          ],
        ),
        if (pending > 0) ...[
          const SizedBox(height: 10),
          _StatCard(
            icon: Icons.pending_rounded,
            value: pending,
            label: 'Still Pending',
            color: _infoColor,
            isDark: isDark,
          ),
        ],
      ],
    );
  }

  Widget _buildVisualBar(bool isDark, int completed, int notDone, int postponed, int pending) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D23) : Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 14,
              child: Row(
                children: [
                  if (completed > 0) Expanded(flex: completed, child: Container(color: _successColor)),
                  if (notDone > 0) Expanded(flex: notDone, child: Container(color: _dangerColor)),
                  if (postponed > 0) Expanded(flex: postponed, child: Container(color: _purpleColor)),
                  if (pending > 0) Expanded(flex: pending, child: Container(color: _infoColor)),
              ],
            ),
          ),
        ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _Legend(color: _successColor, label: 'Done', value: completed, isDark: isDark),
              _Legend(color: _dangerColor, label: 'Not Done', value: notDone, isDark: isDark),
              _Legend(color: _purpleColor, label: 'Postponed', value: postponed, isDark: isDark),
              if (pending > 0) _Legend(color: _infoColor, label: 'Pending', value: pending, isDark: isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPointsCard(bool isDark, int earned, int lost, int net) {
    return Container(
            padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _accentColor.withValues(alpha: isDark ? 0.15 : 0.1),
            _accentColor.withValues(alpha: isDark ? 0.05 : 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accentColor.withValues(alpha: 0.3)),
      ),
            child: Column(
              children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.stars_rounded, size: 20, color: _accentColor),
              ),
              const SizedBox(width: 14),
                Text(
                'Points Summary',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                  color: net >= 0 ? _successColor.withValues(alpha: 0.2) : _dangerColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                        child: Text(
                  net >= 0 ? '+$net net' : '$net net',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: net >= 0 ? _successColor : _dangerColor,
                              ),
                        ),
                      ),
            ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
              Expanded(
                child: _PointsStat(
                  label: 'Earned',
                  value: '+$earned',
                  color: _successColor,
                      isDark: isDark,
                    ),
              ),
              Container(width: 1, height: 40, color: isDark ? Colors.white12 : Colors.grey.shade200),
              Expanded(
                child: _PointsStat(
                  label: 'Lost',
                  value: '-$lost',
                  color: _dangerColor,
                      isDark: isDark,
                ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildCompactPointsCard(
    bool isDark, 
    int earned, 
    int lost, 
    int net,
    List<Task> completedTasks,
    List<Task> notDoneTasks,
    List<Task> allTasks,
  ) {
    // Calculate breakdown details
    int completionPoints = 0;
    int notDonePenalty = 0;
    int postponePenalty = 0;

    for (final task in completedTasks) {
      if (task.pointsEarned > 0) completionPoints += task.pointsEarned;
    }

    for (final task in notDoneTasks) {
      if (task.pointsEarned < 0) notDonePenalty += task.pointsEarned.abs();
    }

    for (final task in allTasks) {
      final penalty = _postponePenaltyOnDate(task, _selectedDate);
      if (penalty < 0) postponePenalty += penalty.abs();
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D23) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _accentColor.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.15 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header - Clickable to expand
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _showPointsBreakdown = !_showPointsBreakdown);
            },
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.stars_rounded, size: 16, color: _accentColor.withOpacity(0.8)),
                  const SizedBox(width: 8),
                  Text(
                    'Points',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const Spacer(),
                  // Earned
                  Text(
                    '+$earned',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _successColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(width: 1, height: 14, color: isDark ? Colors.white12 : Colors.grey.shade300),
                  const SizedBox(width: 8),
                  // Lost
                  Text(
                    '-$lost',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _dangerColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Net
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (net > 0 ? _successColor : net < 0 ? _dangerColor : _accentColor).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      net > 0 ? '+$net' : net == 0 ? '0' : '$net',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: net > 0 ? _successColor : net < 0 ? _dangerColor : _accentColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: _showPointsBreakdown ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: isDark ? Colors.white38 : Colors.black26,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Breakdown - Expandable
          if (_showPointsBreakdown)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(
                children: [
                  Divider(height: 1, thickness: 1, color: isDark ? Colors.white12 : Colors.grey.shade200),
                  const SizedBox(height: 12),
                  _buildPointBreakdownRow(
                    'Completed Tasks',
                    completionPoints,
                    true,
                    isDark,
                    Icons.check_circle_rounded,
                    _successColor,
                  ),
                  const SizedBox(height: 8),
                  _buildPointBreakdownRow(
                    'Not Done Penalties',
                    notDonePenalty,
                    false,
                    isDark,
                    Icons.cancel_rounded,
                    _dangerColor,
                  ),
                  const SizedBox(height: 8),
                  _buildPointBreakdownRow(
                    'Postpone Penalties',
                    postponePenalty,
                    false,
                    isDark,
                    Icons.schedule_rounded,
                    _purpleColor,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                    decoration: BoxDecoration(
                      color: (net > 0 ? _successColor : net < 0 ? _dangerColor : _accentColor).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (net > 0 ? _successColor : net < 0 ? _dangerColor : _accentColor).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.calculate_rounded,
                              size: 14,
                              color: net > 0 ? _successColor : net < 0 ? _dangerColor : _accentColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Net Points',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          net > 0 ? '+$net' : net == 0 ? '0' : '$net',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: net > 0 ? _successColor : net < 0 ? _dangerColor : _accentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Formula: Earned ($earned) - Lost ($lost) = Net ($net)',
                    style: TextStyle(
                      fontSize: 9,
                      fontStyle: FontStyle.italic,
                      color: isDark ? Colors.white24 : Colors.black26,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPointBreakdownRow(
    String label,
    int value,
    bool isPositive,
    bool isDark,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color.withOpacity(0.7)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ),
        Text(
          isPositive ? '+$value' : '-$value',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildHourlyChart(bool isDark, Map<int, int> hourly, int peakHour) {
    final maxValue = hourly.values.reduce((a, b) => a > b ? a : b);
    if (maxValue == 0) return const SizedBox.shrink();

    // Show hours 6 AM to 11 PM (17 hours)
    final displayHours = List.generate(18, (i) => i + 6);

    return Container(
                  padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D23) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
                  child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
          Row(
            children: [
              Icon(Icons.timeline_rounded, size: 18, color: _accentColor),
              const SizedBox(width: 10),
                      Text(
                'Hourly Activity',
                style: TextStyle(
                  fontSize: 15,
                              fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                            ),
                      ),
              const Spacer(),
                      Text(
                'Peak: ${peakHour == 12 ? '12 PM' : peakHour > 12 ? '${peakHour - 12} PM' : '$peakHour AM'}',
                style: TextStyle(
                  fontSize: 12,
                  color: _accentColor,
                  fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
          const SizedBox(height: 20),
          SizedBox(
            height: 80,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: displayHours.map((hour) {
                final value = hourly[hour] ?? 0;
                final height = maxValue > 0 ? (value / maxValue) * 60 : 0.0;
                final isPeak = hour == peakHour && value > 0;
                
                return Expanded(
                child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                        if (value > 0)
                      Text(
                            '$value',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                              color: isPeak ? _accentColor : (isDark ? Colors.white54 : Colors.grey),
                            ),
                          ),
                        const SizedBox(height: 2),
                        Container(
                          height: height.clamp(4.0, 60.0),
                          decoration: BoxDecoration(
                            color: isPeak ? _accentColor : (value > 0 ? _successColor : (isDark ? Colors.white12 : Colors.grey.shade200)),
                            borderRadius: BorderRadius.circular(4),
                            ),
                      ),
                    ],
                  ),
                ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('6 AM', style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.grey)),
              Text('12 PM', style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.grey)),
              Text('6 PM', style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.grey)),
              Text('11 PM', style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Map<String, _PriorityStat> _buildPriorityStats(List<Task> planned, List<Task> completed) {
    final Map<String, _PriorityStat> stats = {};
    for (final p in ['High', 'Medium', 'Low']) {
      stats[p] = _PriorityStat();
    }
    
    for (final task in planned) {
      final p = task.priority;
      if (stats.containsKey(p)) stats[p]!.planned++;
    }
    for (final task in completed) {
      final p = task.priority;
      if (stats.containsKey(p)) stats[p]!.done++;
    }
    
    return stats;
  }

  Widget _buildPriorityCard(bool isDark, Map<String, _PriorityStat> stats) {
    final colors = {'High': _dangerColor, 'Medium': _warningColor, 'Low': _successColor};
    
    return Container(
      padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D23) : Colors.white,
        borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                    Row(
                      children: [
              Icon(Icons.flag_rounded, size: 18, color: _dangerColor),
              const SizedBox(width: 10),
                        Text(
                'Priority Performance',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                              ),
                        ),
                      ],
                    ),
          const SizedBox(height: 16),
          ...['High', 'Medium', 'Low'].map((priority) {
            final stat = stats[priority]!;
            final rate = stat.planned > 0 ? stat.done / stat.planned : 0.0;
            final color = colors[priority]!;
            
                      return Padding(
              padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 60,
                              child: Text(
                      priority,
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.grey.shade700),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: rate,
                        minHeight: 8,
                        backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${stat.done}/${stat.planned}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      );
          }),
        ],
      ),
    );
  }

  Map<String, _TypeStat> _buildTypeStats(List<Task> planned, List<Task> completed) {
    final stats = <String, _TypeStat>{
      'Normal': _TypeStat(Icons.task_alt_rounded, _infoColor),
      'Routine': _TypeStat(Icons.loop_rounded, _accentColor),
      'Recurring': _TypeStat(Icons.repeat_rounded, _purpleColor),
    };
    
    for (final task in planned) {
      final type = task.taskKind == TaskKind.routine || task.isRoutineTask 
          ? 'Routine' 
          : task.taskKind == TaskKind.recurring || task.hasRecurrence 
              ? 'Recurring' 
              : 'Normal';
      stats[type]!.planned++;
    }
    for (final task in completed) {
      final type = task.taskKind == TaskKind.routine || task.isRoutineTask 
          ? 'Routine' 
          : task.taskKind == TaskKind.recurring || task.hasRecurrence 
              ? 'Recurring' 
              : 'Normal';
      stats[type]!.done++;
    }
    
    return stats;
  }

  Widget _buildTypeCard(bool isDark, Map<String, _TypeStat> stats) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D23) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
                    Row(
                      children: [
              Icon(Icons.category_rounded, size: 18, color: _accentColor),
              const SizedBox(width: 10),
                        Text(
                'Task Types',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                              ),
                        ),
                      ],
                    ),
          const SizedBox(height: 16),
          Row(
            children: stats.entries.where((e) => e.value.planned > 0).map((entry) {
              return Expanded(
                child: _TypeChip(
                  icon: entry.value.icon,
                  label: entry.key,
                  done: entry.value.done,
                  total: entry.value.planned,
                  color: entry.value.color,
                  isDark: isDark,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecialTasksCard(bool isDark, int planned, int completed) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _warningColor.withValues(alpha: isDark ? 0.15 : 0.1),
            _warningColor.withValues(alpha: isDark ? 0.05 : 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _warningColor.withValues(alpha: 0.3)),
      ),
                        child: Row(
                          children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _warningColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.star_rounded, size: 20, color: _warningColor),
          ),
          const SizedBox(width: 14),
                            Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Special Tasks',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  '$completed of $planned completed',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${planned > 0 ? ((completed / planned) * 100).toInt() : 0}%',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _warningColor,
                              ),
                            ),
                          ],
                        ),
                      );
  }

  Widget _buildReasonsCard(
    bool isDark,
    String title,
    IconData icon,
    Color color,
    Map<String, int> reasons,
    int total,
    bool showAll,
    VoidCallback onToggle,
  ) {
    final sorted = reasons.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final display = showAll ? sorted : sorted.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D23) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
                    Row(
                      children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              Text(
                '$total total',
                style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
          const SizedBox(height: 16),
          ...display.map((entry) {
            final percent = total > 0 ? (entry.value / total * 100).toInt() : 0;
                      return Padding(
              padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                      entry.key,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                            Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                      '${entry.value} ($percent%)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      );
          }),
          if (sorted.length > 3)
            GestureDetector(
              onTap: onToggle,
                    child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  showAll ? 'Show less' : 'Show all ${sorted.length} reasons',
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<_CategoryStat> _buildCategoryStats(List<Task> planned, List<Task> completed, Map<String, Category> categoriesById) {
    final Map<String?, _CategoryStat> stats = {};

    for (final task in planned) {
      final catId = task.categoryId;
      final cat = catId != null ? categoriesById[catId] : null;
      stats.putIfAbsent(catId, () => _CategoryStat(
        name: cat?.name ?? 'Uncategorized',
        color: cat?.color ?? Colors.grey,
      ));
      stats[catId]!.planned++;
    }

    for (final task in completed) {
      final catId = task.categoryId;
      if (stats.containsKey(catId)) stats[catId]!.done++;
    }

    return stats.values.toList()..sort((a, b) => b.planned.compareTo(a.planned));
  }

  Widget _buildCategoryCard(bool isDark, List<_CategoryStat> stats) {
    return Container(
      padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D23) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
          Row(
            children: [
              Icon(Icons.folder_rounded, size: 18, color: _accentColor),
              const SizedBox(width: 10),
                  Text(
                'Category Performance',
                style: TextStyle(
                  fontSize: 15,
                          fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...stats.take(6).map((stat) {
            final rate = stat.planned > 0 ? stat.done / stat.planned : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: stat.color, shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(stat.name, style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.grey.shade700)),
                  ),
                  Text('${stat.done}/${stat.planned}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
                        const SizedBox(width: 8),
                  SizedBox(
                    width: 50,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: rate,
                        minHeight: 6,
                        backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(stat.color),
                      ),
                              ),
                        ),
                      ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTaskList(
    bool isDark,
    String title,
    IconData icon,
    Color color,
    List<Task> tasks,
    Map<String, Category> categoriesById,
    String Function(Task) subtitleBuilder,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D23) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
                    Row(
                      children: [
              Icon(icon, size: 18, color: color),
                        const SizedBox(width: 8),
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: Text('${tasks.length}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
          ...tasks.take(5).map((task) {
            final cat = task.categoryId != null ? categoriesById[task.categoryId] : null;
            final catColor = cat?.color ?? _accentColor;
            return GestureDetector(
              onTap: () => _openTask(context, task),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF252A31) : const Color(0xFFF8F8F8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(color: catColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                      child: Icon(task.icon ?? cat?.icon ?? Icons.task_alt_rounded, size: 16, color: catColor),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                          Text(task.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(subtitleBuilder(task), style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                                    ),
                              ),
                          ],
                          ),
                        ),
                      );
          }),
          if (tasks.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('+ ${tasks.length - 5} more', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color)),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
                        padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D23) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
                        child: Column(
                          children: [
          Icon(Icons.event_available_rounded, size: 64, color: isDark ? Colors.white24 : Colors.grey.shade300),
                            const SizedBox(height: 16),
          Text('No tasks planned', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : Colors.grey.shade700)),
          const SizedBox(height: 8),
          Text('No tasks were scheduled for this day', style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.grey)),
        ],
      ),
    );
  }

  String _formatTime(Task task) {
    final h = task.dueTimeHour;
    final m = task.dueTimeMinute;
    if (h == null || m == null) return 'No time set';
    return DateFormat('h:mm a').format(DateTime(2000, 1, 1, h, m));
  }

  void _openTask(BuildContext context, Task task) {
    TaskDetailModal.show(context, task: task, onTaskUpdated: () => ref.invalidate(taskNotifierProvider));
  }
}

// ========== MODERN TIMELINE ITEM WIDGET ==========

class _ModernTimelineItem extends StatefulWidget {
  final String time;
  final Task task;
  final Category? category;
  final Color catColor;
  final bool isDark;
  final bool isLast;
  final VoidCallback onTap;

  const _ModernTimelineItem({
    required this.time,
    required this.task,
    required this.category,
    required this.catColor,
    required this.isDark,
    required this.isLast,
    required this.onTap,
  });

  @override
  State<_ModernTimelineItem> createState() => _ModernTimelineItemState();
}

class _ModernTimelineItemState extends State<_ModernTimelineItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _expandController;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left side: Timeline
          SizedBox(
            width: 70,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Time badge - Modern & minimal
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: widget.catColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: widget.catColor.withOpacity(0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        widget.time.split(' ')[0],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: widget.catColor,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        widget.time.split(' ')[1],
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: widget.catColor.withOpacity(0.7),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                // Timeline dot - Minimal
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: widget.catColor,
                    shape: BoxShape.circle,
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      color: widget.isDark
                          ? const Color(0xFF0D0F14)
                          : const Color(0xFFF8F9FA),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                // Timeline connector line - Simple solid line
                if (!widget.isLast)
                  Container(
                    width: 2,
                    height: 65,
                    margin: const EdgeInsets.only(top: 6),
                    color: widget.catColor.withOpacity(0.3),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // Right side: Task card
          Expanded(
            child: GestureDetector(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
                if (_isExpanded) {
                  _expandController.forward();
                } else {
                  _expandController.reverse();
                }
              });
            },
            child: Container(
              decoration: BoxDecoration(
                color: widget.isDark ? const Color(0xFF1A1D23) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: widget.catColor.withOpacity(0.25),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(
                      widget.isDark ? 0.08 : 0.04,
                    ),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Top accent line
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: widget.catColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(14),
                          topRight: Radius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  // Content
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Task icon
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: widget.catColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                widget.task.icon ??
                                    widget.category?.icon ??
                                    Icons.task_alt_rounded,
                                color: widget.catColor,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 11),
                            // Task info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.task.title,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: widget.isDark
                                          ? Colors.white
                                          : Colors.black87,
                                      letterSpacing: -0.2,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (widget.category != null) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          widget.category!.icon,
                                          size: 14,
                                          color: widget.catColor.withOpacity(0.7),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          widget.category!.name,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: widget.isDark
                                                ? Colors.white54
                                                : Colors.grey.shade600,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Status badge and expand arrow
                            Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _getModernStatusBadge(),
                                const SizedBox(height: 4),
                                AnimatedRotation(
                                  turns: _isExpanded ? 0.5 : 0,
                                  duration: const Duration(milliseconds: 300),
                                  child: Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: widget.isDark
                                        ? Colors.white38
                                        : Colors.black26,
                                    size: 24,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        // Expanded content
                        if (_isExpanded) ...[
                          const SizedBox(height: 16),
                          Divider(
                            height: 1,
                            color: widget.isDark
                                ? Colors.white12
                                : Colors.grey.shade200,
                          ),
                          const SizedBox(height: 16),
                          // Description
                          if (widget.task.description != null &&
                              widget.task.description!.isNotEmpty) ...[
                            Text(
                              'Details',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: widget.isDark
                                    ? Colors.white54
                                    : Colors.grey.shade600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.task.description!,
                              style: TextStyle(
                                fontSize: 13,
                                color: widget.isDark
                                    ? Colors.white70
                                    : Colors.grey.shade700,
                                height: 1.6,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          // Action button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: widget.onTap,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: widget.catColor,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 4,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.open_in_new_rounded,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'View Full Details',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      letterSpacing: 0.3,
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
                ],
              ),
            ),
          ),
        ),
      ],
    ),
    );
  }

  Widget _getModernStatusBadge() {
    final (icon, label, bgColor, textColor) = _getStatusInfo();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: bgColor),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: bgColor,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  (IconData, String, Color, Color) _getStatusInfo() {
    if (widget.task.status == 'completed') {
      return (
        Icons.check_circle_rounded,
        'Done',
        const Color(0xFF4CAF50),
        const Color(0xFF2E7D32),
      );
    } else if (widget.task.status == 'not_done') {
      return (
        Icons.close_rounded,
        'Skipped',
        const Color(0xFFFF6B6B),
        const Color(0xFFD32F2F),
      );
    } else if (widget.task.status == 'postponed') {
      return (
        Icons.schedule_rounded,
        'Moved',
        const Color(0xFF9D7CE5),
        const Color(0xFF6A1B9A),
      );
    } else {
      return (
        Icons.pending_rounded,
        'Pending',
        widget.catColor,
        widget.catColor.withOpacity(0.9),
      );
    }
  }
}

// ========== TIMELINE ITEM WIDGET ==========

class _TimelineItem extends StatefulWidget {
  final String time;
  final Task task;
  final Category? category;
  final Color catColor;
  final bool isDark;
  final bool isLast;
  final VoidCallback onTap;

  const _TimelineItem({
    required this.time,
    required this.task,
    required this.category,
    required this.catColor,
    required this.isDark,
    required this.isLast,
    required this.onTap,
  });

  @override
  State<_TimelineItem> createState() => _TimelineItemState();
}

class _TimelineItemState extends State<_TimelineItem> with SingleTickerProviderStateMixin {
  late AnimationController _expandController;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
              if (_isExpanded) {
                _expandController.forward();
              } else {
                _expandController.reverse();
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: widget.isDark ? const Color(0xFF1A1D23) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.catColor.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(widget.isDark ? 0.1 : 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Time
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: widget.catColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        widget.time,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: widget.catColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Task Icon and Title
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: widget.catColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        widget.task.icon ?? widget.category?.icon ?? Icons.task_alt_rounded,
                        color: widget.catColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.task.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: widget.isDark ? Colors.white : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.category != null)
                            Text(
                              widget.category!.name,
                              style: TextStyle(
                                fontSize: 11,
                                color: widget.isDark ? Colors.white54 : Colors.grey,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Status indicator
                    _getStatusBadge(),
                    const SizedBox(width: 8),
                    // Expand arrow
                    AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: widget.isDark ? Colors.white38 : Colors.black26,
                      ),
                    ),
                  ],
                ),
                // Expanded content
                if (_isExpanded) ...[
                  const SizedBox(height: 16),
                  Divider(
                    height: 1,
                    color: widget.isDark ? Colors.white12 : Colors.grey.shade200,
                  ),
                  const SizedBox(height: 16),
                  // Task details
                  if (widget.task.description != null && widget.task.description!.isNotEmpty) ...[
                    Text(
                      widget.task.description!,
                      style: TextStyle(
                        fontSize: 13,
                        color: widget.isDark ? Colors.white70 : Colors.grey.shade700,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // Action button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: widget.onTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.catColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.open_in_new_rounded, size: 16),
                          const SizedBox(width: 8),
                          Text('View Full Details'),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        // Timeline connector line
        if (!widget.isLast) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 25),
            child: Container(
              width: 3,
              height: 20,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    widget.catColor.withOpacity(0.5),
                    widget.catColor.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _getStatusBadge() {
    if (widget.task.status == 'completed') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF4CAF50).withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_rounded, size: 12, color: const Color(0xFF4CAF50)),
            const SizedBox(width: 4),
            Text(
              'Done',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF4CAF50),
              ),
            ),
          ],
        ),
      );
    } else if (widget.task.status == 'not_done') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFF6B6B).withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.close_rounded, size: 12, color: const Color(0xFFFF6B6B)),
            const SizedBox(width: 4),
            Text(
              'Skipped',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFFF6B6B),
              ),
            ),
          ],
        ),
      );
    } else if (widget.task.status == 'postponed') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF9D7CE5).withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule_rounded, size: 12, color: const Color(0xFF9D7CE5)),
            const SizedBox(width: 4),
            Text(
              'Moved',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF9D7CE5),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: widget.catColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pending_rounded, size: 12, color: widget.catColor),
            const SizedBox(width: 4),
            Text(
              'Pending',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: widget.catColor,
              ),
            ),
          ],
        ),
      );
    }
  }
}

// ========== HELPER CLASSES ==========

class _CategoryStat {
  final String name;
  final Color color;
  int planned = 0;
  int done = 0;
  _CategoryStat({required this.name, required this.color});
}

class _PriorityStat {
  int planned = 0;
  int done = 0;
}

class _TypeStat {
  final IconData icon;
  final Color color;
  int planned = 0;
  int done = 0;
  _TypeStat(this.icon, this.color);
}

// ========== HELPER WIDGETS ==========

class _NavButton extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;
  const _NavButton({required this.icon, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: isDark ? const Color(0xFF252A31) : const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, size: 24, color: isDark ? Colors.white70 : Colors.grey.shade700),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;
  final Color color;
  final bool isDark;
  const _StatCard({required this.icon, required this.value, required this.label, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D23) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value.toString(), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
              Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickStatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;
  const _QuickStatChip({required this.icon, required this.label, required this.value, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D23) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
          Text(label, style: TextStyle(fontSize: 9, color: isDark ? Colors.white54 : Colors.grey)),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  final int value;
  final bool isDark;
  const _Legend({required this.color, required this.label, required this.value, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text('$label: $value', style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.grey.shade700)),
      ],
    );
  }
}

class _PointsStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;
  const _PointsStat({required this.label, required this.value, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey)),
      ],
    );
  }
}

class _CompactPointStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;
  const _CompactPointStat({required this.label, required this.value, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color.withOpacity(0.8),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final int done;
  final int total;
  final Color color;
  final bool isDark;
  const _TypeChip({required this.icon, required this.label, required this.done, required this.total, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.1 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text('$done/$total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
          Text(label, style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.grey)),
        ],
      ),
    );
  }
}
