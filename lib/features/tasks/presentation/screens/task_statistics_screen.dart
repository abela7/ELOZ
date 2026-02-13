import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../data/models/task.dart';
import '../providers/task_providers.dart';
import '../providers/category_providers.dart';

/// Time period options for statistics
enum StatsPeriod {
  week,
  month,
  threeMonths,
  sixMonths,
  year,
  custom,
}

/// Statistics data model
class TaskStats {
  final int totalCreated;
  final int completed;
  final int notDone;
  final int pending;
  final int overdue;
  final int postponedAtLeastOnce;
  final int totalPostponeActions;
  final int routineTasks;
  final int recurringTasks;
  final int specialTasks;
  final double completionRate;
  final Map<String, int> categoryBreakdown;
  final Map<String, int> priorityBreakdown;
  final List<Task> tasksInPeriod;

  TaskStats({
    required this.totalCreated,
    required this.completed,
    required this.notDone,
    required this.pending,
    required this.overdue,
    required this.postponedAtLeastOnce,
    required this.totalPostponeActions,
    required this.routineTasks,
    required this.recurringTasks,
    required this.specialTasks,
    required this.completionRate,
    required this.categoryBreakdown,
    required this.priorityBreakdown,
    required this.tasksInPeriod,
  });
}

class TaskStatisticsScreen extends ConsumerStatefulWidget {
  const TaskStatisticsScreen({super.key});

  @override
  ConsumerState<TaskStatisticsScreen> createState() => _TaskStatisticsScreenState();
}

class _TaskStatisticsScreenState extends ConsumerState<TaskStatisticsScreen> 
    with SingleTickerProviderStateMixin {
  StatsPeriod _selectedPeriod = StatsPeriod.month;
  DateTime _customStartDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _customEndDate = DateTime.now();
  late AnimationController _animController;

  static const _accentColor = Color(0xFFCDAF56);
  static const _successColor = Color(0xFF4CAF50);
  static const _dangerColor = Color(0xFFFF6B6B);
  static const _warningColor = Color(0xFFFFB347);
  static const _infoColor = Color(0xFF5C9CE6);
  static const _purpleColor = Color(0xFF9D7CE5);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  DateTimeRange _getDateRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 23, 59, 59);
    
    switch (_selectedPeriod) {
      case StatsPeriod.week:
        return DateTimeRange(
          start: today.subtract(const Duration(days: 7)),
          end: today,
        );
      case StatsPeriod.month:
        return DateTimeRange(
          start: DateTime(now.year, now.month - 1, now.day),
          end: today,
        );
      case StatsPeriod.threeMonths:
        return DateTimeRange(
          start: DateTime(now.year, now.month - 3, now.day),
          end: today,
        );
      case StatsPeriod.sixMonths:
        return DateTimeRange(
          start: DateTime(now.year, now.month - 6, now.day),
          end: today,
        );
      case StatsPeriod.year:
        return DateTimeRange(
          start: DateTime(now.year - 1, now.month, now.day),
          end: today,
        );
      case StatsPeriod.custom:
        return DateTimeRange(
          start: _customStartDate,
          end: DateTime(_customEndDate.year, _customEndDate.month, _customEndDate.day, 23, 59, 59),
        );
    }
  }

  TaskStats _calculateStats(List<Task> allTasks, DateTimeRange range) {
    final tasksInPeriod = allTasks.where((task) {
      final createdAt = task.createdAt;
      final dueDate = task.dueDate;
      final completedAt = task.completedAt;
      
      bool inPeriod = false;
      
      if (dueDate.isAfter(range.start.subtract(const Duration(days: 1))) &&
          dueDate.isBefore(range.end.add(const Duration(days: 1)))) {
        inPeriod = true;
      }
      
      if (createdAt.isAfter(range.start.subtract(const Duration(days: 1))) &&
          createdAt.isBefore(range.end.add(const Duration(days: 1)))) {
        inPeriod = true;
      }
      
      if (completedAt != null &&
          completedAt.isAfter(range.start.subtract(const Duration(days: 1))) &&
          completedAt.isBefore(range.end.add(const Duration(days: 1)))) {
        inPeriod = true;
      }
      
      return inPeriod;
    }).toList();

    int completed = 0;
    int notDone = 0;
    int pending = 0;
    int overdue = 0;
    int postponedAtLeastOnce = 0;
    int totalPostponeActions = 0;
    int routineTasks = 0;
    int recurringTasks = 0;
    int specialTasks = 0;
    
    final Map<String, int> categoryBreakdown = {};
    final Map<String, int> priorityBreakdown = {};

    for (final task in tasksInPeriod) {
      switch (task.status) {
        case 'completed':
          completed++;
          break;
        case 'not_done':
          notDone++;
          break;
        case 'pending':
          if (task.isOverdue) {
            overdue++;
          } else {
            pending++;
          }
          break;
        case 'postponed':
          pending++;
          break;
      }
      
      if (task.postponeCount > 0) {
        postponedAtLeastOnce++;
        totalPostponeActions += task.postponeCount;
      }
      
      if (task.postponeHistory != null && task.postponeHistory!.isNotEmpty) {
        try {
          final historyList = jsonDecode(task.postponeHistory!) as List<dynamic>;
          for (final historyItem in historyList) {
            if (historyItem is Map<String, dynamic>) {
              final postponeDateStr = historyItem['postponedAt'];
              if (postponeDateStr != null) {
                final postponeDate = DateTime.tryParse(postponeDateStr.toString());
                if (postponeDate != null &&
                    postponeDate.isAfter(range.start.subtract(const Duration(days: 1))) &&
                    postponeDate.isBefore(range.end.add(const Duration(days: 1)))) {
                  // Counted via postponeCount
                }
              }
            }
          }
        } catch (_) {}
      }
      
      if (task.taskKind == TaskKind.routine || task.isRoutineTask) {
        routineTasks++;
      }
      if (task.taskKind == TaskKind.recurring || task.hasRecurrence) {
        recurringTasks++;
      }
      if (task.isSpecial) {
        specialTasks++;
      }
      
      final categoryId = task.categoryId ?? 'uncategorized';
      categoryBreakdown[categoryId] = (categoryBreakdown[categoryId] ?? 0) + 1;
      
      final priority = task.priority;
      priorityBreakdown[priority] = (priorityBreakdown[priority] ?? 0) + 1;
    }

    final totalCreated = tasksInPeriod.length;
    final completionRate = totalCreated > 0 ? (completed / totalCreated) * 100 : 0.0;

    return TaskStats(
      totalCreated: totalCreated,
      completed: completed,
      notDone: notDone,
      pending: pending,
      overdue: overdue,
      postponedAtLeastOnce: postponedAtLeastOnce,
      totalPostponeActions: totalPostponeActions,
      routineTasks: routineTasks,
      recurringTasks: recurringTasks,
      specialTasks: specialTasks,
      completionRate: completionRate,
      categoryBreakdown: categoryBreakdown,
      priorityBreakdown: priorityBreakdown,
      tasksInPeriod: tasksInPeriod,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tasksAsync = ref.watch(taskNotifierProvider);
    final categoriesAsync = ref.watch(categoryNotifierProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0F14) : const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          // Modern App Bar
          SliverAppBar(
            expandedHeight: 140,
            floating: false,
            pinned: true,
            backgroundColor: isDark ? const Color(0xFF0D0F14) : Colors.white,
            foregroundColor: isDark ? Colors.white : Colors.black87,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            const Color(0xFF1A1D23),
                            const Color(0xFF0D0F14),
                          ]
                        : [
                            Colors.white,
                            const Color(0xFFF8F9FA),
                          ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [_accentColor, _accentColor.withValues(alpha: 0.7)],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: _accentColor.withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.analytics_rounded, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Task Statistics',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    'Track your productivity trends',
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
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Period Selector
          SliverToBoxAdapter(
            child: _buildPeriodSelector(isDark),
          ),

          // Stats Content
          SliverToBoxAdapter(
            child: tasksAsync.when(
              data: (tasks) {
                final range = _getDateRange();
                final stats = _calculateStats(tasks, range);
                
                return categoriesAsync.when(
                  data: (categories) => _buildStatsContent(isDark, stats, categories, range),
                  loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
                  error: (e, _) => Center(child: Text('Error: $e')),
                );
              },
              loading: () => const SizedBox(height: 400, child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Center(child: Text('Error loading tasks: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector(bool isDark) {
    final periods = [
      (StatsPeriod.week, '7D', Icons.today_rounded),
      (StatsPeriod.month, '1M', Icons.calendar_view_month_rounded),
      (StatsPeriod.threeMonths, '3M', Icons.date_range_rounded),
      (StatsPeriod.sixMonths, '6M', Icons.calendar_today_rounded),
      (StatsPeriod.year, '1Y', Icons.event_note_rounded),
      (StatsPeriod.custom, '⚙️', Icons.tune_rounded),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D23) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: periods.map((p) {
              final isSelected = _selectedPeriod == p.$1;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedPeriod = p.$1);
                    _animController.reset();
                    _animController.forward();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(colors: [_accentColor, _accentColor.withValues(alpha: 0.8)])
                          : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      p.$2,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected 
                            ? Colors.white 
                            : (isDark ? Colors.white54 : Colors.grey.shade600),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (_selectedPeriod == StatsPeriod.custom)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _buildCustomDateRange(context, isDark),
            ),
        ],
      ),
    );
  }

  Widget _buildCustomDateRange(BuildContext context, bool isDark) {
    final dateFormat = DateFormat('MMM d, yyyy');
    
    return Row(
      children: [
        Expanded(
          child: _DatePickerButton(
            label: dateFormat.format(_customStartDate),
            isDark: isDark,
            accentColor: _accentColor,
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _customStartDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (date != null) {
                setState(() => _customStartDate = date);
              }
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Icon(Icons.arrow_forward_rounded, 
            size: 18, 
            color: isDark ? Colors.white38 : Colors.grey,
          ),
        ),
        Expanded(
          child: _DatePickerButton(
            label: dateFormat.format(_customEndDate),
            isDark: isDark,
            accentColor: _accentColor,
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _customEndDate,
                firstDate: _customStartDate,
                lastDate: DateTime.now(),
              );
              if (date != null) {
                setState(() => _customEndDate = date);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatsContent(bool isDark, TaskStats stats, List<dynamic> categories, DateTimeRange range) {
    final dateFormat = DateFormat('MMM d');
    final periodLabel = '${dateFormat.format(range.start)} - ${dateFormat.format(range.end)}';
    
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Period Label
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.date_range_rounded, size: 14, color: _accentColor),
                      const SizedBox(width: 8),
                      Text(
                        periodLabel,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Completion Rate Hero Card
              _buildCompletionHeroCard(isDark, stats),
              const SizedBox(height: 20),
              
              // Main Stats Row
              _buildMainStatsRow(isDark, stats),
              const SizedBox(height: 20),
              
              // Status Breakdown
              _buildStatusBreakdown(isDark, stats),
              const SizedBox(height: 20),
              
              // Postpone Analysis
              if (stats.postponedAtLeastOnce > 0 || stats.totalPostponeActions > 0)
                _buildPostponeCard(isDark, stats),
              if (stats.postponedAtLeastOnce > 0 || stats.totalPostponeActions > 0)
                const SizedBox(height: 20),
              
              // Task Types
              _buildTaskTypesRow(isDark, stats),
              const SizedBox(height: 20),
              
              // Priority Distribution
              _buildPriorityCard(isDark, stats),
              const SizedBox(height: 20),
              
              // Category Breakdown
              if (stats.categoryBreakdown.isNotEmpty)
                _buildCategoryCard(isDark, stats, categories),
              
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompletionHeroCard(bool isDark, TaskStats stats) {
    final rate = stats.completionRate;
    final rateColor = rate >= 80 ? _successColor : rate >= 50 ? _warningColor : _dangerColor;
    final rateLabel = rate >= 80 ? 'Excellent!' : rate >= 50 ? 'Good Progress' : 'Room to Grow';
    
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
        border: Border.all(
          color: rateColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: rateColor.withValues(alpha: isDark ? 0.15 : 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Circular Progress
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: rate / 100,
                        strokeWidth: 8,
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
                          '${rate.toInt()}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: rateColor,
                          ),
                        ),
                        Text(
                          '%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: rateColor.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Completion Rate',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white38 : Colors.grey,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rateLabel,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${stats.completed} of ${stats.totalCreated} tasks completed',
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
        ],
      ),
    );
  }

  Widget _buildMainStatsRow(bool isDark, TaskStats stats) {
    return Row(
      children: [
        Expanded(
          child: _StatMiniCard(
            icon: Icons.assignment_rounded,
            label: 'Total',
            value: stats.totalCreated,
            color: _accentColor,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatMiniCard(
            icon: Icons.check_circle_rounded,
            label: 'Done',
            value: stats.completed,
            color: _successColor,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatMiniCard(
            icon: Icons.cancel_rounded,
            label: 'Skipped',
            value: stats.notDone,
            color: _dangerColor,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBreakdown(bool isDark, TaskStats stats) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D23) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart_rounded, size: 18, color: _accentColor),
              const SizedBox(width: 10),
              Text(
                'Status Overview',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _StatusRow(label: 'Pending', value: stats.pending, color: _infoColor, total: stats.totalCreated, isDark: isDark),
          const SizedBox(height: 14),
          _StatusRow(label: 'Overdue', value: stats.overdue, color: _warningColor, total: stats.totalCreated, isDark: isDark),
          const SizedBox(height: 14),
          _StatusRow(label: 'Postponed', value: stats.postponedAtLeastOnce, color: _purpleColor, total: stats.totalCreated, isDark: isDark),
        ],
      ),
    );
  }

  Widget _buildPostponeCard(bool isDark, TaskStats stats) {
    final avgPostpones = stats.postponedAtLeastOnce > 0 
        ? (stats.totalPostponeActions / stats.postponedAtLeastOnce).toStringAsFixed(1)
        : '0';
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _purpleColor.withValues(alpha: isDark ? 0.15 : 0.1),
            _purpleColor.withValues(alpha: isDark ? 0.05 : 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _purpleColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _purpleColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.update_rounded, size: 18, color: _purpleColor),
              ),
              const SizedBox(width: 12),
              Text(
                'Postpone Insights',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _PostponeStat(
                  value: stats.postponedAtLeastOnce.toString(),
                  label: 'Tasks',
                  isDark: isDark,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: isDark ? Colors.white12 : Colors.grey.shade200,
              ),
              Expanded(
                child: _PostponeStat(
                  value: stats.totalPostponeActions.toString(),
                  label: 'Total',
                  isDark: isDark,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: isDark ? Colors.white12 : Colors.grey.shade200,
              ),
              Expanded(
                child: _PostponeStat(
                  value: avgPostpones,
                  label: 'Avg',
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTaskTypesRow(bool isDark, TaskStats stats) {
    return Row(
      children: [
        Expanded(
          child: _TypeCard(
            icon: Icons.loop_rounded,
            label: 'Routine',
            value: stats.routineTasks,
            color: _accentColor,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _TypeCard(
            icon: Icons.repeat_rounded,
            label: 'Recurring',
            value: stats.recurringTasks,
            color: _infoColor,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _TypeCard(
            icon: Icons.star_rounded,
            label: 'Special',
            value: stats.specialTasks,
            color: _warningColor,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildPriorityCard(bool isDark, TaskStats stats) {
    final high = stats.priorityBreakdown['High'] ?? 0;
    final medium = stats.priorityBreakdown['Medium'] ?? 0;
    final low = stats.priorityBreakdown['Low'] ?? 0;
    final total = high + medium + low;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D23) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag_rounded, size: 18, color: _dangerColor),
              const SizedBox(width: 10),
              Text(
                'Priority Distribution',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Stacked bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  if (high > 0)
                    Expanded(
                      flex: high,
                      child: Container(color: _dangerColor),
                    ),
                  if (medium > 0)
                    Expanded(
                      flex: medium,
                      child: Container(color: _warningColor),
                    ),
                  if (low > 0)
                    Expanded(
                      flex: low,
                      child: Container(color: _successColor),
                    ),
                  if (total == 0)
                    Expanded(
                      child: Container(
                        color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _PriorityLegend(label: 'High', value: high, color: _dangerColor, isDark: isDark),
              const Spacer(),
              _PriorityLegend(label: 'Medium', value: medium, color: _warningColor, isDark: isDark),
              const Spacer(),
              _PriorityLegend(label: 'Low', value: low, color: _successColor, isDark: isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(bool isDark, TaskStats stats, List<dynamic> categories) {
    final sortedCategories = stats.categoryBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D23) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.folder_rounded, size: 18, color: _accentColor),
              const SizedBox(width: 10),
              Text(
                'Categories',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const Spacer(),
              Text(
                '${sortedCategories.length} total',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white38 : Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...sortedCategories.take(6).map((entry) {
            final category = categories.cast<dynamic>().firstWhere(
              (c) => c.id == entry.key,
              orElse: () => null,
            );
            final categoryName = category?.name ?? 'Uncategorized';
            final categoryColor = category?.color ?? _accentColor;
            final percentage = stats.totalCreated > 0 
                ? (entry.value / stats.totalCreated * 100).toInt()
                : 0;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: categoryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      categoryName,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '$percentage%',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: categoryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      entry.value.toString(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: categoryColor,
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
}

// Helper Widgets

class _DatePickerButton extends StatelessWidget {
  final String label;
  final bool isDark;
  final Color accentColor;
  final VoidCallback onTap;

  const _DatePickerButton({
    required this.label,
    required this.isDark,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF252A31) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accentColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today_rounded, size: 14, color: accentColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatMiniCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color color;
  final bool isDark;

  const _StatMiniCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D23) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white54 : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final int total;
  final bool isDark;

  const _StatusRow({
    required this.label,
    required this.value,
    required this.color,
    required this.total,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = total > 0 ? value / total : 0.0;
    
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.grey.shade700,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage,
              minHeight: 6,
              backgroundColor: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 28,
          child: Text(
            value.toString(),
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _PostponeStat extends StatelessWidget {
  final String value;
  final String label;
  final bool isDark;

  const _PostponeStat({
    required this.value,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF9D7CE5),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white54 : Colors.grey,
          ),
        ),
      ],
    );
  }
}

class _TypeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color color;
  final bool isDark;

  const _TypeCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: isDark ? 0.15 : 0.1),
            color.withValues(alpha: isDark ? 0.05 : 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 8),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.white54 : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

class _PriorityLegend extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final bool isDark;

  const _PriorityLegend({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white54 : Colors.grey,
          ),
        ),
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }
}
