import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/dark_gradient.dart';
import '../../../../core/models/reminder.dart';
import '../../../../core/services/reminder_manager.dart';
import '../../../../data/models/task.dart';
import '../../../../data/models/category.dart';
import 'add_task_screen.dart';
import 'edit_task_screen.dart';
import 'view_all_tasks_screen.dart';
import 'completed_tasks_screen.dart';
import 'task_settings_screen.dart';
import 'task_report_screen.dart';
import 'routines_screen.dart';
import '../widgets/task_detail_modal.dart';
import '../../../../features/notifications_hub/presentation/widgets/universal_reminder_section.dart';
import '../../notifications/task_notification_creator_context.dart';
import '../../../../core/widgets/date_navigator_widget.dart';
import '../providers/task_providers.dart';
import '../providers/category_providers.dart';
import '../providers/task_reason_providers.dart';
import '../../../../data/models/task_reason.dart';
import 'reminders_screen.dart';
import '../widgets/add_reminder_sheet.dart';

/// Tasks Screen - Task Mini-App Dashboard
class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _isSearching = false;
  bool _showCompletedTasks = false; // Accordion state for completed tasks
  bool _showNotDoneTasks = false; // Accordion state for not done tasks
  bool _showPostponedTasks = false; // Accordion state for postponed tasks
  String _selectedFilter = 'total'; // Filter: 'total', 'completed', 'pending', 'overdue'
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Returns the appropriate progress label based on selected date
  String _getProgressLabel() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    
    if (selected == today) {
      return "Today's Progress";
    } else if (selected == today.subtract(const Duration(days: 1))) {
      return "Yesterday's Progress";
    } else if (selected == today.add(const Duration(days: 1))) {
      return "Tomorrow's Progress";
    } else {
      return "${DateFormat('MMM d').format(selected)}'s Progress";
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tasksAsync = _isSearching && _searchController.text.isNotEmpty
        ? ref.watch(taskSearchProvider(_searchController.text))
        : ref.watch(tasksForDateProvider(_selectedDate));
    
    // Get ALL tasks to check for postponed tasks FROM the selected date
    final allTasksAsync = ref.watch(taskNotifierProvider);

    return Scaffold(
      body: isDark
          ? DarkGradient.wrap(child: _buildContent(context, isDark, tasksAsync))
          : _buildContent(context, isDark, tasksAsync),
    );
  }

  Widget _buildContent(BuildContext context, bool isDark, AsyncValue<List<Task>> tasksAsync) {
    // Get ALL tasks to check for postponed tasks FROM the selected date
    final allTasksAsync = ref.watch(taskNotifierProvider);
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                decoration: InputDecoration(
                  hintText: 'Search tasks...',
                  hintStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() {});
                },
              )
            : const Text('Tasks'),
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchController.clear();
                });
              },
              tooltip: 'Close Search',
            )
          else
            IconButton(
              icon: const Icon(Icons.search_rounded),
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
              tooltip: 'Search Tasks',
            ),
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.add_rounded),
              onPressed: () => context.pushNamed('add-task'),
              tooltip: 'New Task',
            ),
        ],
      ),
      body: SafeArea(
        child: tasksAsync.when(
          data: (tasks) {
            if (_isSearching && _searchController.text.isNotEmpty) {
              return _buildSearchResults(context, isDark, tasks);
            }
            return allTasksAsync.when(
              data: (allTasks) => _buildTasksContent(context, isDark, tasks, allTasks),
              loading: () => _buildTasksContent(context, isDark, tasks, []),
              error: (_, __) => _buildTasksContent(context, isDark, tasks, []),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Text('Error loading tasks: $error'),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults(BuildContext context, bool isDark, List<Task> tasks) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: isDark ? Colors.white10 : Colors.grey[200],
            ),
            const SizedBox(height: 16),
            Text(
              'No tasks match your search',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _TaskCard(
            task: task,
            isDark: isDark,
            onTap: () {
              TaskDetailModal.show(
                context,
                task: task,
                onTaskUpdated: () {
                  ref.invalidate(taskNotifierProvider);
                },
              );
            },
            onTaskUpdated: () {
              ref.invalidate(taskNotifierProvider);
            },
          ),
        );
      },
    );
  }

  Widget _buildTasksContent(BuildContext context, bool isDark, List<Task> tasks, List<Task> allTasks) {
    // Get tasks that were "postponed FROM" this date (now on another date)
    final postponedFromTodayAsync = ref.watch(tasksPostponedFromDateProvider(_selectedDate));
    final postponedFromTodayList = postponedFromTodayAsync.whenOrNull(
      data: (tasks) => tasks,
    ) ?? <Task>[];

    // Calculate statistics for selected date
    // Total includes tasks on this date + tasks moved away (postponed)
    final totalTasksCount = tasks.length + postponedFromTodayList.length;
    final completedTasks = tasks.where((t) => t.status == 'completed').length;
    final pendingTasks = tasks.where((t) => t.status == 'pending' && !t.isOverdue).length;
    
    // OVERDUE: Use allTasks to show TOTAL overdue tasks in the system, 
    // not just for the selected date. This matches the user's expectation.
    final totalOverdueTasks = allTasks.where((t) => 
      t.isOverdue && 
      t.status != 'completed' && 
      t.status != 'not_done'
    ).toList();
    final overdueTasksCount = totalOverdueTasks.length;
    
    // Calculate progress percentage
    final progress = totalTasksCount > 0 ? completedTasks / totalTasksCount : 0.0;
    
    // Filter tasks for display based on selected stat card
    final displayTasks = (() {
      switch (_selectedFilter) {
        case 'completed':
          return tasks.where((t) => t.status == 'completed').toList();
        case 'pending':
          // Pending means status is 'pending' AND it's not overdue
          return tasks.where((t) => t.status == 'pending' && !t.isOverdue).toList();
        case 'overdue':
          // Show ALL overdue tasks from the system when Overdue filter is selected
          return totalOverdueTasks;
        case 'total':
        default:
          // In Total view, show active pending tasks for this date AND overdue tasks (if date is today)
          // Exclude completed, postponed, and not_done (as they have their own accordions)
          final isToday = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day)
              .isAtSameMomentAs(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day));
          
          final dayTasks = tasks.where((t) => 
            (t.status == 'pending' || t.isOverdue) && 
            t.status != 'completed' && 
            t.status != 'postponed' && 
            t.status != 'not_done'
          ).toList();

          if (isToday) {
            // If viewing today, also include overdue tasks from previous days
            final previousOverdue = totalOverdueTasks.where((t) {
              final taskDate = DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day);
              final todayDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
              return taskDate.isBefore(todayDate);
            }).toList();
            
            // Avoid duplicates just in case
            for (final ot in previousOverdue) {
              if (!dayTasks.any((t) => t.id == ot.id)) {
                dayTasks.add(ot);
              }
            }
          }
          
          return dayTasks;
      }
    })()
      ..sort((a, b) {
        // Overdue tasks from previous days come first in the Today view
        final todayDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
        final aDateOnly = DateTime(a.dueDate.year, a.dueDate.month, a.dueDate.day);
        final bDateOnly = DateTime(b.dueDate.year, b.dueDate.month, b.dueDate.day);
        
        final aIsPreviousOverdue = a.isOverdue && aDateOnly.isBefore(todayDate);
        final bIsPreviousOverdue = b.isOverdue && bDateOnly.isBefore(todayDate);
        
        if (aIsPreviousOverdue && !bIsPreviousOverdue) return -1;
        if (!aIsPreviousOverdue && bIsPreviousOverdue) return 1;

        // Special tasks come next
        if (a.isSpecial && !b.isSpecial) return -1;
        if (!a.isSpecial && b.isSpecial) return 1;
        
        // Then sort by due date/time
        final aDate = DateTime(a.dueDate.year, a.dueDate.month, a.dueDate.day,
            a.dueTimeHour ?? 23, a.dueTimeMinute ?? 59);
        final bDate = DateTime(b.dueDate.year, b.dueDate.month, b.dueDate.day,
            b.dueTimeHour ?? 23, b.dueTimeMinute ?? 59);
        return aDate.compareTo(bDate);
      });
    
    // Filter completed tasks for accordion
    final completedTasksList = tasks
        .where((t) => t.status == 'completed')
        .toList()
      ..sort((a, b) {
        // Sort by completion time (most recent first)
        if (a.completedAt == null && b.completedAt == null) return 0;
        if (a.completedAt == null) return 1;
        if (b.completedAt == null) return -1;
        return b.completedAt!.compareTo(a.completedAt!);
      });
    
    // Filter not done tasks for accordion
    final notDoneTasksList = tasks
        .where((t) => t.status == 'not_done')
        .toList()
      ..sort((a, b) => b.dueDate.compareTo(a.dueDate));
    
    // Also include legacy archived tasks (status='postponed') from this date
    final legacyPostponedList = tasks
        .where((t) => t.status == 'postponed')
        .toList();
    
    // Combine both lists (avoiding duplicates)
    final allPostponedFromToday = <Task>[
      ...postponedFromTodayList,
      ...legacyPostponedList.where((legacy) => 
        !postponedFromTodayList.any((t) => t.id == legacy.id)
      ),
    ]..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    
    // Check if there are ANY tasks at all for the current filter
    final hasTasksToShow = displayTasks.isNotEmpty || 
                          (_selectedFilter == 'total' && (
                            completedTasksList.isNotEmpty || 
                            notDoneTasksList.isNotEmpty || 
                            allPostponedFromToday.isNotEmpty
                          ));

    // Wrap content in GestureDetector for swipe navigation (no animations - instant updates)
    return GestureDetector(
      behavior: HitTestBehavior.opaque, // Allow gestures even on transparent areas
      onHorizontalDragEnd: (details) {
        // Swipe left (positive velocity) → tomorrow (forward) - swapped based on user feedback
        if (details.primaryVelocity != null && details.primaryVelocity! > 500) {
          HapticFeedback.selectionClick();
          setState(() {
            _selectedDate = _selectedDate.subtract(const Duration(days: 1));
          });
        }
        // Swipe right (negative velocity) → yesterday (backward) - swapped based on user feedback
        else if (details.primaryVelocity != null && details.primaryVelocity! < -500) {
          HapticFeedback.selectionClick();
          setState(() {
            _selectedDate = _selectedDate.add(const Duration(days: 1));
          });
        }
      },
      child: ListView(
      padding: const EdgeInsets.only(bottom: 100), // Space for bottom nav
      children: [
        // Date Navigator Widget
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: DateNavigatorWidget(
            selectedDate: _selectedDate,
            onDateChanged: (newDate) {
              setState(() {
                _selectedDate = newDate;
              });
            },
          ),
        ),

        const SizedBox(height: 16),

        // Overview Stats Section - 2x2 Grid
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 1.55,
            children: [
              _StatCard(
                label: 'Total',
                value: totalTasksCount.toString(),
                icon: Icons.task_alt_rounded,
                accentColor: const Color(0xFFCDAF56), // Gold
                isDark: isDark,
                isSelected: _selectedFilter == 'total',
                onTap: () {
                  setState(() {
                    _selectedFilter = 'total';
                  });
                },
              ),
              _StatCard(
                label: 'Completed',
                value: completedTasks.toString(),
                icon: Icons.check_circle_rounded,
                accentColor: const Color(0xFF4CAF50), // Green
                isDark: isDark,
                isSelected: _selectedFilter == 'completed',
                onTap: () {
                  setState(() {
                    _selectedFilter = 'completed';
                  });
                },
              ),
              _StatCard(
                label: 'Pending',
                value: pendingTasks.toString(),
                icon: Icons.pending_rounded,
                accentColor: const Color(0xFFFFA726), // Orange
                isDark: isDark,
                isSelected: _selectedFilter == 'pending',
                onTap: () {
                  setState(() {
                    _selectedFilter = 'pending';
                  });
                },
              ),
              _StatCard(
                label: 'Overdue',
                value: overdueTasksCount.toString(),
                icon: Icons.warning_rounded,
                accentColor: const Color(0xFFEF5350), // Red
                isDark: isDark,
                isSelected: _selectedFilter == 'overdue',
                onTap: () {
                  setState(() {
                    _selectedFilter = 'overdue';
                  });
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Tasks for the Day Section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                'Tasks for the Day',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? Colors.white
                          : const Color(0xFF1E1E1E),
                    ),
              ),
              const SizedBox(height: 16),
              // Show "No tasks" only if there are NO tasks at all for the current view
              if (!hasTasksToShow)
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Text(
                      _selectedFilter == 'total' 
                          ? 'No tasks for this day'
                          : 'No ${_selectedFilter} tasks found',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isDark
                                ? const Color(0xFFBDBDBD)
                                : const Color(0xFF6E6E6E),
                          ),
                    ),
                  ),
                )
              // Show active tasks (pending, postponed, overdue, or filtered list)
              else if (displayTasks.isNotEmpty)
                ...displayTasks.map((task) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _TaskCard(
                        task: task,
                        isDark: isDark,
                        onTap: () {
                          TaskDetailModal.show(
                            context,
                            task: task,
                            onTaskUpdated: () {
                              // Refresh the task list
                              ref.invalidate(tasksForDateProvider(_selectedDate));
                            },
                          );
                        },
                        onTaskUpdated: () {
                          ref.invalidate(tasksForDateProvider(_selectedDate));
                        },
                      ),
                    )),
              
              // Completed Tasks Accordion (only show in Total view)
              if (completedTasksList.isNotEmpty && _selectedFilter == 'total') ...[
                const SizedBox(height: 24),
                _CompletedTasksAccordion(
                  completedTasks: completedTasksList,
                  isDark: isDark,
                  isExpanded: _showCompletedTasks,
                  onExpansionChanged: (expanded) {
                    setState(() {
                      _showCompletedTasks = expanded;
                    });
                  },
                  onTaskTap: (task) {
                    TaskDetailModal.show(
                      context,
                      task: task,
                      onTaskUpdated: () {
                        ref.invalidate(tasksForDateProvider(_selectedDate));
                      },
                    );
                  },
                ),
              ],
              
              // Not Done Tasks Accordion (only show in Total view)
              if (notDoneTasksList.isNotEmpty && _selectedFilter == 'total') ...[
                const SizedBox(height: 16),
                _NotDoneTasksAccordion(
                  notDoneTasks: notDoneTasksList,
                  isDark: isDark,
                  isExpanded: _showNotDoneTasks,
                  onExpansionChanged: (expanded) {
                    setState(() {
                      _showNotDoneTasks = expanded;
                    });
                  },
                  onTaskTap: (task) {
                    TaskDetailModal.show(
                      context,
                      task: task,
                      onTaskUpdated: () {
                        ref.invalidate(tasksForDateProvider(_selectedDate));
                      },
                    );
                  },
                ),
              ],
              
              // Postponed FROM Here Accordion
              // Shows tasks that were originally scheduled for this date but moved elsewhere
              // Includes both new system (postponeHistory) and legacy (status='postponed')
              if (allPostponedFromToday.isNotEmpty && _selectedFilter == 'total') ...[
                const SizedBox(height: 16),
                _PostponedTasksAccordion(
                  postponedTasks: allPostponedFromToday,
                  isDark: isDark,
                  isExpanded: _showPostponedTasks,
                  onExpansionChanged: (expanded) {
                    setState(() {
                      _showPostponedTasks = expanded;
                    });
                  },
                  onTaskTap: (task) {
                    TaskDetailModal.show(
                      context,
                      task: task,
                      onTaskUpdated: () {
                        ref.invalidate(tasksForDateProvider(_selectedDate));
                      },
                    );
                  },
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Daily Progress Bar Section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2D3139) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: isDark
                  ? Border.all(
                      color: const Color(0xFF3E4148),
                      width: 1,
                    )
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _getProgressLabel(),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1E1E1E),
                          ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCDAF56).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${(progress * 100).toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: const Color(0xFFCDAF56),
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: isDark
                        ? const Color(0xFF3E4148)
                        : const Color(0xFFEDE9E0),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFFCDAF56),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '$completedTasks of $totalTasksCount tasks completed',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? const Color(0xFFBDBDBD)
                            : const Color(0xFF6E6E6E),
                        fontSize: 13,
                      ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Quick Actions Section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                'Quick Actions',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? Colors.white
                          : const Color(0xFF1E1E1E),
                    ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _QuickActionButton(
                      icon: Icons.add_task_rounded,
                      label: 'Add Task',
                      isDark: isDark,
                      onTap: () => context.pushNamed('add-task'),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _QuickActionButton(
                      icon: Icons.list_rounded,
                      label: 'View All',
                      isDark: isDark,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const ViewAllTasksScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _QuickActionButton(
                      icon: Icons.bar_chart_rounded,
                      label: 'Report',
                      isDark: isDark,
                      accentColor: const Color(0xFFCDAF56),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => TaskReportScreen(initialDate: _selectedDate),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickActionButton(
                      icon: Icons.loop_rounded,
                      label: 'Routines',
                      isDark: isDark,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const RoutinesScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _QuickActionButton(
                      icon: Icons.notifications_active_rounded,
                      label: 'Reminders',
                      isDark: isDark,
                      accentColor: const Color(0xFFCDAF56),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const RemindersScreen(),
                          ),
                        );
                      },
                      onLongPress: () {
                        HapticFeedback.mediumImpact();
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => AddReminderSheet(
                            isDark: isDark,
                            initialDate: DateTime.now(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickActionButton(
                      icon: Icons.settings_rounded,
                      label: 'Settings',
                      isDark: isDark,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const TaskSettingsScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
      ],
      ),
    );
  }
}

/// Stat Card Widget - Modern Clean Design with Icon Integration
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;
  final bool isDark;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
    required this.isDark,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2D3139) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected 
                  ? accentColor 
                  : (isDark ? const Color(0xFF3E4148) : Colors.grey.shade200),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: accentColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                              height: 1.1,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark ? const Color(0xFFBDBDBD) : const Color(0xFF6E6E6E),
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Quick Action Button
class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Color? accentColor;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
    this.onLongPress,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isGold = accentColor != null;
    final color = accentColor ?? (isDark ? const Color(0xFFBDBDBD) : const Color(0xFF6E6E6E));
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        splashColor: (isGold ? const Color(0xFFCDAF56) : color).withOpacity(0.15),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2D3139) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isGold 
                  ? const Color(0xFFCDAF56).withOpacity(0.5)
                  : (isDark ? const Color(0xFF3E4148) : Colors.grey.shade200),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Task Card Widget - Now accepts Task object and shows category icon
/// EDITED
class _TaskCard extends ConsumerWidget {
  final Task task;
  final bool isDark;
  final VoidCallback? onTap;
  final VoidCallback? onTaskUpdated;

  const _TaskCard({
    required this.task,
    required this.isDark,
    this.onTap,
    this.onTaskUpdated,
  });

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatTime() {
    if (task.dueTimeHour != null && task.dueTimeMinute != null) {
      final hour = task.dueTimeHour!;
      final minute = task.dueTimeMinute!;
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
    }
    return '';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final priorityColor = _getPriorityColor(task.priority);
    final categoryAsync = task.categoryId != null
        ? ref.watch(categoryByIdProvider(task.categoryId!))
        : null;

    // Status styling
    Color? statusColor;
    TextDecoration? textDecoration;
    FontWeight fontWeight = FontWeight.w600;
    
    if (task.status == 'completed') {
      statusColor = isDark ? Colors.white54 : Colors.grey; // Dimmed for completed
      textDecoration = TextDecoration.lineThrough;
    } else if (task.status == 'not_done') {
      statusColor = const Color(0xFFFF6B6B); // Red for not done - no strikethrough
      fontWeight = FontWeight.w800; // Bold red text
    } else if (task.status == 'postponed') {
      statusColor = const Color(0xFFFFB347); // Orange
    }

    final textColor = statusColor ?? (isDark ? Colors.white : const Color(0xFF1E1E1E));

    return InkWell(
      onTap: onTap,
      onLongPress: () => _showContextMenu(context, ref),
      borderRadius: BorderRadius.circular(20),
      child: categoryAsync?.when(
        data: (category) {
          final themeColor = category?.color ?? const Color(0xFFCDAF56);
          return _buildCardContent(context, ref, themeColor, statusColor, textColor, textDecoration, fontWeight, category);
        },
        loading: () => _buildCardContent(context, ref, const Color(0xFFCDAF56), statusColor, textColor, textDecoration, fontWeight, null),
        error: (_, __) => _buildCardContent(context, ref, const Color(0xFFCDAF56), statusColor, textColor, textDecoration, fontWeight, null),
      ) ?? _buildCardContent(context, ref, const Color(0xFFCDAF56), statusColor, textColor, textDecoration, fontWeight, null),
    );
  }

  void _showContextMenu(BuildContext context, WidgetRef ref) {
    HapticFeedback.mediumImpact();
    final accentGold = const Color(0xFFCDAF56);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF252A31) : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            // Task Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                task.title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: isDark ? Colors.white : Colors.black,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Divider(height: 1),
            // Reminders
            ListTile(
              leading: Icon(
                Icons.notifications_active_rounded,
                color: accentGold,
              ),
              title: Text(
                'Reminders',
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
              ),
              subtitle: Text(
                'Add, edit, or delete reminders',
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black54,
                  fontSize: 12,
                ),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                await _showRemindersEditor(context, ref);
                onTaskUpdated?.call();
              },
            ),
            // Star/Unstar Option
            ListTile(
              leading: Icon(
                task.isSpecial ? Icons.star_rounded : Icons.star_outline_rounded,
                color: accentGold,
              ),
              title: Text(
                task.isSpecial ? 'Unstar Task' : 'Star Task',
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
              ),
              subtitle: Text(
                task.isSpecial ? 'Remove from special tasks' : 'Pin to top as special',
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black54,
                  fontSize: 12,
                ),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                final updatedTask = task.copyWith(isSpecial: !task.isSpecial);
                await ref.read(taskNotifierProvider.notifier).updateTask(updatedTask);
                onTaskUpdated?.call();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(updatedTask.isSpecial ? 'Task starred!' : 'Task unstarred'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
            // Edit Option
            ListTile(
              leading: Icon(
                Icons.edit_rounded,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
              title: Text(
                'Edit Task',
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                final result = await context.pushNamed('edit-task', extra: task);
                if (result == true) {
                  onTaskUpdated?.call();
                }
              },
            ),
            // Delete Option
            ListTile(
              leading: Icon(
                Icons.delete_rounded,
                color: Colors.red[400],
              ),
              title: Text(
                'Delete Task',
                style: TextStyle(color: Colors.red[400]),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showDeleteConfirmation(context, ref);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _showRemindersEditor(BuildContext context, WidgetRef ref) async {

    final isDarkLocal = Theme.of(context).brightness == Brightness.dark;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setState) => Container(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.of(context).padding.bottom,
          ),
          decoration: BoxDecoration(
            color: isDarkLocal ? const Color(0xFF1A1C1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.notifications_active_rounded, color: Color(0xFFCDAF56)),
                  const SizedBox(width: 10),
                  Text(
                    'Task reminders',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: isDarkLocal ? Colors.white : Colors.black,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFFCDAF56)),
                    child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              UniversalReminderSection(
                creatorContext: TaskNotificationCreatorContext.forTask(
                  taskId: task.id,
                  taskTitle: task.title,
                ),
                isDark: isDarkLocal,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
    // Check task type and route to appropriate delete method
    final bool isRecurring = task.taskKind == TaskKind.recurring || 
                              task.recurrenceGroupId != null || 
                              task.hasRecurrence;
    final bool isRoutine = task.taskKind == TaskKind.routine || 
                            task.isRoutineTask;
    
    if (isRoutine) {
      _showRoutineDeleteSheet(context, ref);
    } else if (isRecurring) {
      _showRecurringDeleteSheet(context, ref);
    } else {
      _showNormalDeleteSheet(context, ref);
    }
  }

  int _getRoutineInstanceCount(WidgetRef ref) {
    final tasksAsync = ref.read(taskNotifierProvider);
    int count = 0;
    tasksAsync.whenData((tasks) {
      final groupId = task.effectiveRoutineGroupId;
      count = tasks.where((t) => t.id == groupId || t.routineGroupId == groupId).length;
    });
    return count;
  }

  int _getRecurringInstanceCount(WidgetRef ref) {
    final tasksAsync = ref.read(taskNotifierProvider);
    int count = 0;
    tasksAsync.whenData((tasks) {
      if (task.recurrenceGroupId != null) {
        count = tasks.where((t) => t.recurrenceGroupId == task.recurrenceGroupId).length;
      }
    });
    return count;
  }

  void _showRoutineDeleteSheet(BuildContext context, WidgetRef ref) {
    final instanceCount = _getRoutineInstanceCount(ref);
    final dateFormat = DateFormat('MMM d, yyyy');
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D3139) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.loop_rounded, color: Colors.red, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Delete Routine', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
                          Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.grey.shade600)),
                        ]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.calendar_today_rounded, size: 14, color: isDark ? Colors.white38 : Colors.grey),
                  const SizedBox(width: 6),
                  Text(dateFormat.format(task.dueDate), style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey)),
                  const SizedBox(width: 16),
                  Icon(Icons.layers_rounded, size: 14, color: isDark ? Colors.white38 : Colors.grey),
                  const SizedBox(width: 6),
                  Text('$instanceCount instances', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey)),
                ]),
                const SizedBox(height: 20),
                _buildDeleteOption(sheetContext, Icons.event_rounded, const Color(0xFFCDAF56), 'Delete this occurrence', 'Remove only this routine instance', false, () async {
                  Navigator.of(sheetContext).pop();
                  await ref.read(taskNotifierProvider.notifier).deleteTask(task.id);
                  onTaskUpdated?.call();
                }),
                const SizedBox(height: 10),
                _buildDeleteOption(sheetContext, Icons.delete_forever_rounded, Colors.red, 'Delete entire routine', 'Remove all $instanceCount instances permanently', true, () async {
                  Navigator.of(sheetContext).pop();
                  final confirmed = await _showDangerConfirmDialog(context, 'Delete All Routine Instances?', 'This will permanently delete all $instanceCount instances of this routine. This cannot be undone.');
                  if (confirmed == true) {
                    final deletedCount = await ref.read(taskNotifierProvider.notifier).deleteRoutineSeries(task.effectiveRoutineGroupId);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Routine deleted ($deletedCount instances removed)'), backgroundColor: Colors.red));
                    onTaskUpdated?.call();
                  }
                }),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, child: TextButton(onPressed: () => Navigator.of(sheetContext).pop(), child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRecurringDeleteSheet(BuildContext context, WidgetRef ref) {
    final instanceCount = _getRecurringInstanceCount(ref);
    final dateFormat = DateFormat('MMM d, yyyy');
    final recurrenceDesc = task.recurrence?.getDescription() ?? 'Recurring';
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D3139) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.repeat_rounded, color: Colors.red, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Delete Recurring Task', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
                          Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.grey.shade600)),
                        ]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.repeat_rounded, size: 14, color: isDark ? Colors.white38 : Colors.grey),
                  const SizedBox(width: 6),
                  Text(recurrenceDesc, style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey)),
                  const SizedBox(width: 16),
                  Icon(Icons.layers_rounded, size: 14, color: isDark ? Colors.white38 : Colors.grey),
                  const SizedBox(width: 6),
                  Text('${instanceCount > 0 ? instanceCount : 1} tasks', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey)),
                ]),
                const SizedBox(height: 20),
                _buildDeleteOption(sheetContext, Icons.event_rounded, const Color(0xFFCDAF56), 'Delete this occurrence', 'Remove only ${dateFormat.format(task.dueDate)}', false, () async {
                  Navigator.of(sheetContext).pop();
                  await ref.read(taskNotifierProvider.notifier).deleteTask(task.id);
                  onTaskUpdated?.call();
                }),
                const SizedBox(height: 10),
                _buildDeleteOption(sheetContext, Icons.delete_forever_rounded, Colors.red, 'Delete all occurrences', 'Remove entire recurring series${instanceCount > 0 ? ' ($instanceCount tasks)' : ''}', true, () async {
                  Navigator.of(sheetContext).pop();
                  final confirmed = await _showDangerConfirmDialog(context, 'Delete Entire Series?', 'This will permanently delete all occurrences of this recurring task. This cannot be undone.');
                  if (confirmed == true) {
                    if (task.recurrenceGroupId != null) {
                      await ref.read(taskNotifierProvider.notifier).deleteRecurringSeries(task.recurrenceGroupId!);
                    } else {
                      await ref.read(taskNotifierProvider.notifier).deleteTask(task.id);
                    }
                    onTaskUpdated?.call();
                  }
                }),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, child: TextButton(onPressed: () => Navigator.of(sheetContext).pop(), child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showNormalDeleteSheet(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('MMM d, yyyy');
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D3139) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.red.withValues(alpha: 0.3))),
                  child: Row(children: [
                    Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)), child: Icon(task.icon ?? Icons.task_rounded, color: Colors.red, size: 24)),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Delete Task', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
                      Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.grey.shade600)),
                    ])),
                  ]),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.withValues(alpha: 0.3))),
                  child: Row(children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text('This action cannot be undone.', style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.grey.shade700))),
                  ]),
                ),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.calendar_today_rounded, size: 14, color: isDark ? Colors.white38 : Colors.grey),
                  const SizedBox(width: 6),
                  Text(dateFormat.format(task.dueDate), style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey)),
                  if (task.priority == 'High') ...[
                    const SizedBox(width: 16),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)), child: const Text('High Priority', style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.w600))),
                  ],
                ]),
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(child: TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300))),
                    child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white70 : Colors.grey.shade700, fontWeight: FontWeight.w600)),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: ElevatedButton(
                    onPressed: () async {
                      Navigator.of(sheetContext).pop();
                      await ref.read(taskNotifierProvider.notifier).deleteTask(task.id);
                      onTaskUpdated?.call();
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.delete_rounded, size: 18), SizedBox(width: 8), Text('Delete', style: TextStyle(fontWeight: FontWeight.w600))]),
                  )),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteOption(BuildContext context, IconData icon, Color iconColor, String title, String subtitle, bool isDangerous, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDangerous ? Colors.red.withValues(alpha: isDark ? 0.1 : 0.05) : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDangerous ? Colors.red.withValues(alpha: 0.4) : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200)),
          ),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: iconColor, size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDangerous ? Colors.red : (isDark ? Colors.white : Colors.black87))),
              Text(subtitle, style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey.shade600)),
            ])),
            Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white24 : Colors.grey.shade400, size: 20),
          ]),
        ),
      ),
    );
  }

  Future<bool?> _showDangerConfirmDialog(BuildContext context, String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF2D3139) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.warning_rounded, color: Colors.red, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87))),
        ]),
        content: Text(message, style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.grey.shade700, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey.shade600))),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
            child: const Text('Delete Permanently', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildCardContent(
    BuildContext context, 
    WidgetRef ref,
    Color themeColor, 
    Color? statusColor, 
    Color textColor, 
    TextDecoration? textDecoration,
    FontWeight fontWeight,
    Category? category,
  ) {
    final isOverdueTask = task.isOverdue && task.status != 'completed' && task.status != 'not_done';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D3139) : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOverdueTask 
              ? const Color(0xFFFF6B6B) // Red for overdue
              : themeColor.withOpacity(isDark ? 0.4 : 0.5), // Category color for normal tasks
          width: isOverdueTask ? 2.0 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Main Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon Section - Toggle Button
                InkWell(
                  onTap: () {
                    if (task.status == 'completed') {
                      ref.read(taskNotifierProvider.notifier).undoTask(task.id);
                    } else {
                      ref.read(taskNotifierProvider.notifier).completeTask(task.id);
                    }
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 44,
                    height: 44,
                    margin: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      color: (isOverdueTask ? const Color(0xFFFF6B6B) : themeColor).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: task.status == 'completed'
                        ? Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              Icon(Icons.check_rounded, color: themeColor, size: 22),
                              if (task.isRoutineTask)
                                Positioned(
                                  right: -4,
                                  bottom: -4,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF2D3139) : Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: themeColor.withOpacity(0.5),
                                        width: 1,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.sync_rounded,
                                      size: 10,
                                      color: themeColor,
                                    ),
                                  ),
                                ),
                            ],
                          )
                        : Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              Icon(
                                task.icon ?? category?.icon ?? Icons.task_alt_rounded,
                                color: isOverdueTask ? const Color(0xFFFF6B6B) : themeColor,
                                size: 22,
                              ),
                              if (task.isRoutineTask)
                                Positioned(
                                  right: -4,
                                  bottom: -4,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF2D3139) : Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: (isOverdueTask ? const Color(0xFFFF6B6B) : themeColor).withOpacity(0.5),
                                        width: 1,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.sync_rounded,
                                      size: 10,
                                      color: isOverdueTask ? const Color(0xFFFF6B6B) : themeColor,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ),

                // Content Section
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title Area
                      Padding(
                        padding: const EdgeInsets.only(right: 60), // Space for priority tag
                        child: Text(
                          task.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: isOverdueTask ? FontWeight.w800 : fontWeight,
                                fontSize: 16,
                                color: isOverdueTask ? const Color(0xFFFF6B6B) : textColor,
                                decoration: textDecoration,
                                decorationColor: task.status == 'completed' 
                                    ? (isDark ? Colors.white70 : Colors.black87) 
                                    : statusColor,
                                decorationThickness: task.status == 'completed' ? 2.5 : null,
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      
                      const SizedBox(height: 10),
                      
                      // Smart Tags Row
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          // Explicit Overdue Tag
                          if (isOverdueTask)
                            _SmartTag(
                              label: 'Overdue',
                              color: const Color(0xFFFF6B6B),
                              isDark: isDark,
                              icon: Icons.warning_rounded,
                              fontWeight: FontWeight.w900,
                            ),
                            
                          // Time Chip
                          if (_formatTime().isNotEmpty)
                            _SmartTag(
                              label: _formatTime(),
                              color: isOverdueTask
                                  ? const Color(0xFFFF6B6B)
                                  : (isDark ? const Color(0xFFBDBDBD) : const Color(0xFF6E6E6E)),
                              isDark: isDark,
                              icon: Icons.access_time_rounded,
                              fontWeight: isOverdueTask 
                                  ? FontWeight.w900 
                                  : null,
                            ),
    
                          // Postponed Chip
                          if (task.status == 'postponed' || task.postponeCount > 0)
                            _SmartTag(
                              label: task.status == 'postponed' 
                                  ? 'Postponed' 
                                  : '${task.postponeCount}x Postponed',
                              color: const Color(0xFFFFB347),
                              isDark: isDark,
                              icon: Icons.schedule_rounded,
                            ),
                            
                          // Status Chip (if not active/pending)
                          if (task.status == 'completed')
                            _SmartTag(
                              label: 'Done',
                              color: const Color(0xFF4CAF50),
                              isDark: isDark,
                              icon: Icons.check_circle_rounded,
                            )
                          else if (task.status == 'not_done')
                            _SmartTag(
                              label: 'Not Done',
                              color: const Color(0xFFFF6B6B),
                              isDark: isDark,
                              icon: Icons.cancel_rounded,
                            ),
                        ],
                      ),

                      // Recurrence Chip - Now on its own line below other tags
                      if (task.hasRecurrence) ...[
                        const SizedBox(height: 8),
                        _SmartTag(
                          label: task.recurrence?.getDescription() ?? 'Recurring',
                          color: const Color(0xFF9C27B0),
                          isDark: isDark,
                          icon: Icons.repeat_rounded,
                        ),
                      ],
    
                      // Subtasks Progress
                      if (task.subtasks != null && task.subtasks!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              '${(task.subtaskProgress * 100).toInt()}%',
                              style: TextStyle(
                                color: task.subtaskProgress == 1.0 ? Colors.green : const Color(0xFFCDAF56),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: task.subtaskProgress,
                                  backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    task.subtaskProgress == 1.0 ? Colors.green : const Color(0xFFCDAF56),
                                  ),
                                  minHeight: 6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Priority Tag or Special Badge (Top Right Corner)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: task.isSpecial 
                    ? const Color(0xFFCDAF56).withOpacity(0.15)
                    : _getPriorityColor(task.priority).withOpacity(0.15),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(16),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: task.isSpecial 
                        ? const Color(0xFFCDAF56).withOpacity(0.3)
                        : _getPriorityColor(task.priority).withOpacity(0.3),
                    width: 1,
                  ),
                  left: BorderSide(
                    color: task.isSpecial 
                        ? const Color(0xFFCDAF56).withOpacity(0.3)
                        : _getPriorityColor(task.priority).withOpacity(0.3),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    task.isSpecial ? Icons.star_rounded : Icons.flag_rounded,
                    size: 12,
                    color: task.isSpecial 
                        ? const Color(0xFFCDAF56)
                        : _getPriorityColor(task.priority),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    task.isSpecial ? 'SPECIAL' : task.priority,
                    style: TextStyle(
                      color: task.isSpecial 
                          ? const Color(0xFFCDAF56)
                          : _getPriorityColor(task.priority),
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
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
}

class _SmartTag extends StatelessWidget {
  final String label;
  final Color color;
  final bool isDark;
  final IconData? icon;
  final double? maxWidth;
  final FontWeight? fontWeight;

  const _SmartTag({
    required this.label,
    required this.color,
    required this.isDark,
    this.icon,
    this.maxWidth,
    this.fontWeight,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: fontWeight ?? FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    if (maxWidth != null) {
      content = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth!),
        child: content,
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: content,
    );
  }
}

/// Completed Tasks Accordion Widget
class _CompletedTasksAccordion extends StatelessWidget {
  final List<Task> completedTasks;
  final bool isDark;
  final bool isExpanded;
  final ValueChanged<bool> onExpansionChanged;
  final ValueChanged<Task> onTaskTap;

  const _CompletedTasksAccordion({
    required this.completedTasks,
    required this.isDark,
    required this.isExpanded,
    required this.onExpansionChanged,
    required this.onTaskTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF2D3139)
            : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF4CAF50).withOpacity(0.3), // Green border
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Accordion Header
          InkWell(
            onTap: () => onExpansionChanged(!isExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF4CAF50),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Completed Tasks',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? const Color(0xFFFFFFFF)
                                    : const Color(0xFF1E1E1E),
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${completedTasks.length} task${completedTasks.length != 1 ? 's' : ''} completed',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: isDark
                                    ? const Color(0xFFBDBDBD)
                                    : const Color(0xFF6E6E6E),
                              ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: isDark
                          ? const Color(0xFFBDBDBD)
                          : const Color(0xFF6E6E6E),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Accordion Content
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: completedTasks.map((task) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _CompletedTaskCard(
                        task: task,
                        isDark: isDark,
                        onTap: () => onTaskTap(task),
                      ),
                    )).toList(),
              ),
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }
}

/// Completed Task Card Widget (simplified version for accordion)
class _CompletedTaskCard extends ConsumerWidget {
  final Task task;
  final bool isDark;
  final VoidCallback onTap;

  const _CompletedTaskCard({
    required this.task,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get category from database if available
    final categoryAsync = task.categoryId != null
        ? ref.watch(categoryByIdProvider(task.categoryId!))
        : null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF4CAF50).withOpacity(isDark ? 0.1 : 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF4CAF50).withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Task Icon (preferred) or Check icon (fallback)
            if (task.icon != null)
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      task.icon,
                      color: const Color(0xFF4CAF50),
                      size: 18,
                    ),
                    if (task.isRoutineTask)
                      Positioned(
                        right: -3,
                        bottom: -3,
                        child: Container(
                          padding: const EdgeInsets.all(1.5),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2D3139) : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF4CAF50).withOpacity(0.5),
                              width: 0.8,
                            ),
                          ),
                          child: const Icon(
                            Icons.sync_rounded,
                            size: 8,
                            color: Color(0xFF4CAF50),
                          ),
                        ),
                      ),
                  ],
                ),
              )
            else
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(
                      Icons.check_rounded,
                      color: Color(0xFF4CAF50),
                      size: 18,
                    ),
                    if (task.isRoutineTask)
                      Positioned(
                        right: -3,
                        bottom: -3,
                        child: Container(
                          padding: const EdgeInsets.all(1.5),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2D3139) : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF4CAF50).withOpacity(0.5),
                              width: 0.8,
                            ),
                          ),
                          child: const Icon(
                            Icons.sync_rounded,
                            size: 8,
                            color: Color(0xFF4CAF50),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(width: 12),
            // Category Icon (if no task icon)
            if (task.icon == null && categoryAsync != null)
              categoryAsync.when(
                data: (category) {
                  if (category == null) return const SizedBox.shrink();
                  return Container(
                    width: 28,
                    height: 28,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: category.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      category.icon,
                      color: category.color,
                      size: 16,
                    ),
                  );
                },
                loading: () => const SizedBox(width: 28, height: 28),
                error: (_, __) => const SizedBox.shrink(),
              ),
            // Task title
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white54
                              : Colors.grey,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: isDark
                              ? Colors.white70
                              : Colors.black87,
                          decorationThickness: 2.5,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (task.completedAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Completed at ${DateFormat('h:mm a').format(task.completedAt!)}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: isDark
                                ? const Color(0xFFBDBDBD)
                                : const Color(0xFF6E6E6E),
                            fontSize: 10,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            // Show net points for completed tasks with penalties
            if (task.cumulativePostponePenalty < 0 && task.pointsEarned > 0) ...[
              // Show breakdown: penalty + reward = net
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: task.netPoints >= 0 
                      ? const Color(0xFFCDAF56).withOpacity(0.2)
                      : const Color(0xFFFF6B6B).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${task.cumulativePostponePenalty}',
                      style: const TextStyle(
                        color: Color(0xFFFF6B6B),
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      ' + ',
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black45,
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      '+${task.pointsEarned}',
                      style: const TextStyle(
                        color: Color(0xFFCDAF56),
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      ' = ',
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black45,
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      '${task.netPoints >= 0 ? '+' : ''}${task.netPoints}',
                      style: TextStyle(
                        color: task.netPoints >= 0 
                            ? const Color(0xFFCDAF56)
                            : const Color(0xFFFF6B6B),
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (task.pointsEarned > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFCDAF56).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+${task.pointsEarned}',
                  style: const TextStyle(
                    color: Color(0xFFCDAF56),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              )
            else if (task.cumulativePostponePenalty < 0)
              // Pending task with penalties - just show the penalty
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B6B).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${task.cumulativePostponePenalty}',
                  style: const TextStyle(
                    color: Color(0xFFFF6B6B),
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Not Done Tasks Accordion Widget
class _NotDoneTasksAccordion extends StatelessWidget {
  final List<Task> notDoneTasks;
  final bool isDark;
  final bool isExpanded;
  final ValueChanged<bool> onExpansionChanged;
  final ValueChanged<Task> onTaskTap;

  const _NotDoneTasksAccordion({
    required this.notDoneTasks,
    required this.isDark,
    required this.isExpanded,
    required this.onExpansionChanged,
    required this.onTaskTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF2D3139)
            : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFF6B6B).withOpacity(0.3), // Red border
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Accordion Header
          InkWell(
            onTap: () => onExpansionChanged(!isExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B6B).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.cancel_rounded,
                      color: Color(0xFFFF6B6B),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Not Done Tasks',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? const Color(0xFFFFFFFF)
                                    : const Color(0xFF1E1E1E),
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${notDoneTasks.length} task${notDoneTasks.length != 1 ? 's' : ''} not done',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: isDark
                                    ? const Color(0xFFBDBDBD)
                                    : const Color(0xFF6E6E6E),
                              ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: isDark
                          ? const Color(0xFFBDBDBD)
                          : const Color(0xFF6E6E6E),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Accordion Content
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: notDoneTasks.map((task) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _NotDoneTaskCard(
                        task: task,
                        isDark: isDark,
                        onTap: () => onTaskTap(task),
                      ),
                    )).toList(),
              ),
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }
}

/// Not Done Task Card Widget
class _NotDoneTaskCard extends ConsumerWidget {
  final Task task;
  final bool isDark;
  final VoidCallback onTap;

  const _NotDoneTaskCard({
    required this.task,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryAsync = task.categoryId != null
        ? ref.watch(categoryByIdProvider(task.categoryId!))
        : null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFF6B6B).withOpacity(isDark ? 0.1 : 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFFF6B6B).withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Task Icon (preferred) or X icon (fallback)
            if (task.icon != null)
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B6B).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      task.icon,
                      color: const Color(0xFFFF6B6B),
                      size: 18,
                    ),
                    if (task.isRoutineTask)
                      Positioned(
                        right: -3,
                        bottom: -3,
                        child: Container(
                          padding: const EdgeInsets.all(1.5),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2D3139) : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFFF6B6B).withOpacity(0.5),
                              width: 0.8,
                            ),
                          ),
                          child: const Icon(
                            Icons.sync_rounded,
                            size: 8,
                            color: Color(0xFFFF6B6B),
                          ),
                        ),
                      ),
                  ],
                ),
              )
            else
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B6B).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(
                      Icons.close_rounded,
                      color: Color(0xFFFF6B6B),
                      size: 18,
                    ),
                    if (task.isRoutineTask)
                      Positioned(
                        right: -3,
                        bottom: -3,
                        child: Container(
                          padding: const EdgeInsets.all(1.5),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2D3139) : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFFF6B6B).withOpacity(0.5),
                              width: 0.8,
                            ),
                          ),
                          child: const Icon(
                            Icons.sync_rounded,
                            size: 8,
                            color: Color(0xFFFF6B6B),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(width: 12),
            // Category Icon (if no task icon)
            if (task.icon == null && categoryAsync != null)
              categoryAsync.when(
                data: (category) {
                  if (category == null) return const SizedBox.shrink();
                  return Container(
                    width: 28,
                    height: 28,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: category.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      category.icon,
                      color: category.color,
                      size: 16,
                    ),
                  );
                },
                loading: () => const SizedBox(width: 28, height: 28),
                error: (_, __) => const SizedBox.shrink(),
              ),
            // Task info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    task.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white54
                              : Colors.grey,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: const Color(0xFFFF6B6B),
                          decorationThickness: 2.5,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // Due date - clear and visible
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 12,
                        color: const Color(0xFFFF6B6B).withOpacity(0.8),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Due: ${DateFormat('MMM d, yyyy').format(task.dueDate)}',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: const Color(0xFFFF6B6B).withOpacity(0.9),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                          overflow: TextOverflow.visible,
                        ),
                      ),
                    ],
                  ),
                  if (task.notDoneReason != null && task.notDoneReason!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Consumer(
                      builder: (context, ref, _) {
                        final reasonsAsync = ref.watch(notDoneReasonsProvider);
                        final reasonText = reasonsAsync.maybeWhen(
                          data: (reasons) {
                            // If it's a UUID, try to find the reason name
                            if (task.notDoneReason!.length > 20) {
                              final reason = reasons.firstWhere(
                                (r) => r.id == task.notDoneReason,
                                orElse: () => TaskReason(text: task.notDoneReason!, typeIndex: 0),
                              );
                              return reason.text;
                            }
                            return task.notDoneReason!;
                          },
                          orElse: () => task.notDoneReason!,
                        );
                        
                        return Text(
                          reasonText,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: const Color(0xFFFF6B6B).withOpacity(0.7),
                                fontSize: 10,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
            // Show net points for not done tasks with postpone penalties
            if (task.cumulativePostponePenalty < 0 && task.pointsEarned != 0) ...[
              // Show breakdown: postpone penalty + skip penalty = net
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B6B).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${task.cumulativePostponePenalty}',
                      style: const TextStyle(
                        color: Color(0xFFFF6B6B),
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      ' + ',
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black45,
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      '${task.pointsEarned}',
                      style: const TextStyle(
                        color: Color(0xFFFF6B6B),
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      ' = ',
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black45,
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      '${task.netPoints}',
                      style: const TextStyle(
                        color: Color(0xFFFF6B6B),
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (task.pointsEarned < 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B6B).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${task.pointsEarned}',
                  style: const TextStyle(
                    color: Color(0xFFFF6B6B),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Postponed Tasks Accordion Widget
class _PostponedTasksAccordion extends StatelessWidget {
  final List<Task> postponedTasks;
  final bool isDark;
  final bool isExpanded;
  final ValueChanged<bool> onExpansionChanged;
  final ValueChanged<Task> onTaskTap;

  const _PostponedTasksAccordion({
    required this.postponedTasks,
    required this.isDark,
    required this.isExpanded,
    required this.onExpansionChanged,
    required this.onTaskTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF2D3139)
            : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFFB347).withOpacity(0.3), // Orange border
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Accordion Header
          InkWell(
            onTap: () => onExpansionChanged(!isExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB347).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.schedule_rounded,
                      color: Color(0xFFFFB347),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Postponed Tasks',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? const Color(0xFFFFFFFF)
                                    : const Color(0xFF1E1E1E),
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${postponedTasks.length} task${postponedTasks.length != 1 ? 's' : ''} postponed',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: isDark
                                    ? const Color(0xFFBDBDBD)
                                    : const Color(0xFF6E6E6E),
                              ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: isDark
                          ? const Color(0xFFBDBDBD)
                          : const Color(0xFF6E6E6E),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Accordion Content
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: postponedTasks.map((task) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _PostponedTaskCard(
                        task: task,
                        isDark: isDark,
                        onTap: () => onTaskTap(task),
                      ),
                    )).toList(),
              ),
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }
}

/// Postponed Task Card Widget
class _PostponedTaskCard extends ConsumerWidget {
  final Task task;
  final bool isDark;
  final VoidCallback onTap;

  const _PostponedTaskCard({
    required this.task,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryAsync = task.categoryId != null
        ? ref.watch(categoryByIdProvider(task.categoryId!))
        : null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFB347).withOpacity(isDark ? 0.1 : 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFFFB347).withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Task Icon (preferred) or Schedule icon (fallback)
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFFFB347).withOpacity(isDark ? 0.15 : 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    task.icon ?? Icons.directions_run_rounded,
                    color: const Color(0xFFFFB347),
                    size: 22,
                  ),
                  if (task.isRoutineTask)
                    Positioned(
                      right: -3,
                      bottom: -3,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2D3139) : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFFFB347).withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.sync_rounded,
                          size: 10,
                          color: Color(0xFFFFB347),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Task info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  Text(
                    task.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFFFFFFFF)
                              : const Color(0xFF1E1E1E),
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // Original due date
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 13,
                        color: const Color(0xFFFFB347).withOpacity(0.8),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'Was due: ${DateFormat('MMM d, yyyy').format(task.originalDueDate ?? task.dueDate)}',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: const Color(0xFFFFB347).withOpacity(0.9),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  // Postpone reason or "No reason provided"
                  const SizedBox(height: 4),
                  if (task.postponeReason != null && task.postponeReason!.isNotEmpty)
                    Consumer(
                      builder: (context, ref, _) {
                        final reasonsAsync = ref.watch(postponeReasonsProvider);
                        final reasonText = reasonsAsync.maybeWhen(
                          data: (reasons) {
                            // If it's a UUID, try to find the reason name
                            if (task.postponeReason!.length > 20) {
                              final reason = reasons.firstWhere(
                                (r) => r.id == task.postponeReason,
                                orElse: () => TaskReason(text: task.postponeReason!, typeIndex: 1),
                              );
                              return reason.text;
                            }
                            return task.postponeReason!;
                          },
                          orElse: () => task.postponeReason!,
                        );
                        
                        return Text(
                          reasonText,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: isDark
                                    ? const Color(0xFFBDBDBD)
                                    : const Color(0xFF6E6E6E),
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    )
                  else
                    Text(
                      'No reason provided',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: (isDark
                                ? const Color(0xFFBDBDBD)
                                : const Color(0xFF6E6E6E)).withOpacity(0.6),
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Right side badges column
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Postponed badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB347),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFB347).withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Postponed',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                // Postpone count badge (if postponed more than once)
                Consumer(
                  builder: (context, ref, _) {
                    final postponeCountAsync = ref.watch(postponeCountProvider(task.id));
                    return postponeCountAsync.when(
                      data: (count) {
                        if (count > 1) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFB347).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFFFB347).withOpacity(0.4),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                '${count}x',
                                style: const TextStyle(
                                  color: Color(0xFFFFB347),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
