import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/dark_gradient.dart';
import '../../../../data/models/task.dart';
import 'add_task_screen.dart';
import 'edit_task_screen.dart';
import 'task_statistics_screen.dart';
import '../widgets/task_detail_modal.dart';
import '../providers/task_providers.dart';
import '../providers/category_providers.dart';

/// Sort Options
enum TaskSortBy {
  dueDateAsc,
  dueDateDesc,
  titleAsc,
  titleDesc,
  priorityHighToLow,
  priorityLowToHigh,
  createdDateDesc,
  createdDateAsc,
}

/// Date Filter Options
enum DateFilterType {
  all,
  today,
  tomorrow,
  thisWeek,
  thisMonth,
  custom,
  customRange,
}

/// Advanced Filter Configuration
class TaskFilter {
  final DateFilterType dateFilter;
  final DateTime? customDate;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<String> categoryIds;
  final List<String> priorities;
  final List<String> statuses;
  final List<String> taskKinds;
  
  const TaskFilter({
    this.dateFilter = DateFilterType.all,
    this.customDate,
    this.startDate,
    this.endDate,
    this.categoryIds = const [],
    this.priorities = const [],
    this.statuses = const [],
    this.taskKinds = const [],
  });
  
  TaskFilter copyWith({
    DateFilterType? dateFilter,
    DateTime? customDate,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? categoryIds,
    List<String>? priorities,
    List<String>? statuses,
    List<String>? taskKinds,
  }) {
    return TaskFilter(
      dateFilter: dateFilter ?? this.dateFilter,
      customDate: customDate ?? this.customDate,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      categoryIds: categoryIds ?? this.categoryIds,
      priorities: priorities ?? this.priorities,
      statuses: statuses ?? this.statuses,
      taskKinds: taskKinds ?? this.taskKinds,
    );
  }
  
  bool get hasActiveFilters {
    return dateFilter != DateFilterType.all ||
           categoryIds.isNotEmpty ||
           priorities.isNotEmpty ||
           statuses.isNotEmpty ||
           taskKinds.isNotEmpty;
  }
  
  int get activeFilterCount {
    int count = 0;
    if (dateFilter != DateFilterType.all) count++;
    if (categoryIds.isNotEmpty) count++;
    if (priorities.isNotEmpty) count++;
    if (statuses.isNotEmpty) count++;
    if (taskKinds.isNotEmpty) count++;
    return count;
  }
}

/// View All Tasks Screen - List and Grid/Carousel view modes
class ViewAllTasksScreen extends ConsumerStatefulWidget {
  const ViewAllTasksScreen({super.key});

  @override
  ConsumerState<ViewAllTasksScreen> createState() => _ViewAllTasksScreenState();
}

class _ViewAllTasksScreenState extends ConsumerState<ViewAllTasksScreen> with SingleTickerProviderStateMixin {
  // View mode: true = List, false = Grid/Carousel
  bool _isListView = true;
  
  // Smart View Mode: 'active' (default) or 'history'
  // Active: Shows only pending/overdue (actionable tasks)
  // History: Shows all tasks within a month range
  String _smartViewMode = 'active';
  DateTime _historyMonth = DateTime.now(); // For month navigation in history mode
  
  // Filters
  static const List<String> _subFilterOptions = ['Total', 'Completed', 'Not Done', 'Overdue', 'Routine', 'Special'];
  String _mainFilter = 'All'; // 'All', 'Today'
  String _subFilter = 'Total'; // 'Total', 'Routine', 'Completed', 'Overdue', 'Postponed', 'Not Done'

  // Advanced Filters
  TaskFilter _advancedFilter = const TaskFilter();
  TaskSortBy _sortBy = TaskSortBy.dueDateAsc;

  // Search state
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  
  // Tab controller for Main Filter
  late TabController _tabController;

  // Selection Mode State
  bool _isSelectionMode = false;
  final Set<String> _selectedTaskIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _mainFilter = _tabController.index == 0 ? 'All' : 'Today';
          // Exit selection mode when changing tabs
          if (_isSelectionMode) {
            _exitSelectionMode();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onSwipe(bool isRightSwipe) {
    if (_isSearching || _isSelectionMode) return;
    
    final currentIndex = _subFilterOptions.indexOf(_subFilter);
    int nextIndex;
    
    if (isRightSwipe) {
      // Right swipe -> Previous filter (loop to end if at 0)
      nextIndex = (currentIndex - 1 + _subFilterOptions.length) % _subFilterOptions.length;
    } else {
      // Left swipe -> Next filter (loop to start if at end)
      nextIndex = (currentIndex + 1) % _subFilterOptions.length;
    }
    
    setState(() {
      _subFilter = _subFilterOptions[nextIndex];
    });
  }

  void _enterSelectionMode(String initialTaskId) {
    setState(() {
      _isSelectionMode = true;
      _selectedTaskIds.add(initialTaskId);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedTaskIds.clear();
    });
  }

  void _showTaskContextMenu(BuildContext context, Task task, bool isDark) {
    HapticFeedback.mediumImpact();
    const accentGold = Color(0xFFCDAF56);
    
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
              child: Row(
                children: [
                  if (task.isSpecial)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(Icons.star_rounded, size: 18, color: accentGold),
                    ),
                  Expanded(
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
                ],
              ),
            ),
            const Divider(height: 1),
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
                if (mounted) {
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
                  ref.invalidate(taskNotifierProvider);
                }
              },
            ),
            // Select Option
            ListTile(
              leading: Icon(
                Icons.check_circle_outline_rounded,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
              title: Text(
                'Select Task',
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
              ),
              subtitle: Text(
                'Enter selection mode for bulk actions',
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black54,
                  fontSize: 12,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _enterSelectionMode(task.id);
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
                _showDeleteConfirmation(context, task, isDark);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Task task, bool isDark) {
    // Check task type
    final bool isRecurring = task.taskKind == TaskKind.recurring || 
                              task.recurrenceGroupId != null || 
                              task.hasRecurrence;
    final bool isRoutine = task.taskKind == TaskKind.routine || 
                            task.isRoutineTask;
    
    if (isRoutine) {
      _showRoutineDeleteSheet(context, task, isDark);
    } else if (isRecurring) {
      _showRecurringDeleteSheet(context, task, isDark);
    } else {
      _showNormalDeleteSheet(context, task, isDark);
    }
  }

  /// Get routine instance count
  int _getRoutineInstanceCount(Task task) {
    final tasksAsync = ref.read(taskNotifierProvider);
    int count = 0;
    tasksAsync.whenData((tasks) {
      final groupId = task.effectiveRoutineGroupId;
      count = tasks.where((t) => 
        t.id == groupId || t.routineGroupId == groupId
      ).length;
    });
    return count;
  }

  /// Get recurring instance count
  int _getRecurringInstanceCount(Task task) {
    final tasksAsync = ref.read(taskNotifierProvider);
    int count = 0;
    tasksAsync.whenData((tasks) {
      if (task.recurrenceGroupId != null) {
        count = tasks.where((t) => 
          t.recurrenceGroupId == task.recurrenceGroupId
        ).length;
      }
    });
    return count;
  }

  void _showRoutineDeleteSheet(BuildContext context, Task task, bool isDark) {
    final instanceCount = _getRoutineInstanceCount(task);
    final dateFormat = DateFormat('MMM d, yyyy');
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
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
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Header
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
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.loop_rounded, color: Colors.red, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Delete Routine',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              Text(
                                task.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                  ),
                  const SizedBox(height: 16),
                  
                  // Info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 14, color: isDark ? Colors.white38 : Colors.grey),
                      const SizedBox(width: 6),
                      Text(dateFormat.format(task.dueDate), style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey)),
                      const SizedBox(width: 16),
                      Icon(Icons.layers_rounded, size: 14, color: isDark ? Colors.white38 : Colors.grey),
                      const SizedBox(width: 6),
                      Text('$instanceCount instances', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Option 1: Delete this instance
                  _buildDeleteOptionTile(
                    context: sheetContext,
                    isDark: isDark,
                    icon: Icons.event_rounded,
                    iconColor: const Color(0xFFCDAF56),
                    title: 'Delete this occurrence',
                    subtitle: 'Remove only this routine instance',
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      await ref.read(taskNotifierProvider.notifier).deleteTask(task.id);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Routine occurrence deleted'), behavior: SnackBarBehavior.floating),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  
                  // Option 2: Delete entire routine
                  _buildDeleteOptionTile(
                    context: sheetContext,
                    isDark: isDark,
                    icon: Icons.delete_forever_rounded,
                    iconColor: Colors.red,
                    title: 'Delete entire routine',
                    subtitle: 'Remove all $instanceCount instances permanently',
                    isDangerous: true,
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      final confirmed = await _showDangerConfirmDialog(
                        context,
                        isDark,
                        'Delete All Routine Instances?',
                        'This will permanently delete all $instanceCount instances of this routine. This cannot be undone.',
                      );
                      if (confirmed == true) {
                        final routineGroupId = task.effectiveRoutineGroupId;
                        final deletedCount = await ref.read(taskNotifierProvider.notifier).deleteRoutineSeries(routineGroupId);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Routine deleted ($deletedCount instances removed)'), behavior: SnackBarBehavior.floating, backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Cancel
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showRecurringDeleteSheet(BuildContext context, Task task, bool isDark) {
    final instanceCount = _getRecurringInstanceCount(task);
    final dateFormat = DateFormat('MMM d, yyyy');
    final recurrenceDesc = task.recurrence?.getDescription() ?? 'Recurring';
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
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
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Header
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
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.repeat_rounded, color: Colors.red, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Delete Recurring Task',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              Text(
                                task.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                  ),
                  const SizedBox(height: 16),
                  
                  // Info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.repeat_rounded, size: 14, color: isDark ? Colors.white38 : Colors.grey),
                      const SizedBox(width: 6),
                      Text(recurrenceDesc, style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey)),
                      const SizedBox(width: 16),
                      Icon(Icons.layers_rounded, size: 14, color: isDark ? Colors.white38 : Colors.grey),
                      const SizedBox(width: 6),
                      Text('${instanceCount > 0 ? instanceCount : 1} tasks', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Option 1: Delete this occurrence
                  _buildDeleteOptionTile(
                    context: sheetContext,
                    isDark: isDark,
                    icon: Icons.event_rounded,
                    iconColor: const Color(0xFFCDAF56),
                    title: 'Delete this occurrence',
                    subtitle: 'Remove only ${dateFormat.format(task.dueDate)}',
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      await ref.read(taskNotifierProvider.notifier).deleteTask(task.id);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Task occurrence deleted'), behavior: SnackBarBehavior.floating),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  
                  // Option 2: Delete all occurrences
                  _buildDeleteOptionTile(
                    context: sheetContext,
                    isDark: isDark,
                    icon: Icons.delete_forever_rounded,
                    iconColor: Colors.red,
                    title: 'Delete all occurrences',
                    subtitle: 'Remove entire recurring series${instanceCount > 0 ? ' ($instanceCount tasks)' : ''}',
                    isDangerous: true,
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      final confirmed = await _showDangerConfirmDialog(
                        context,
                        isDark,
                        'Delete Entire Series?',
                        'This will permanently delete all occurrences of this recurring task. This cannot be undone.',
                      );
                      if (confirmed == true) {
                        if (task.recurrenceGroupId != null) {
                          await ref.read(taskNotifierProvider.notifier).deleteRecurringSeries(task.recurrenceGroupId!);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Recurring series deleted'), behavior: SnackBarBehavior.floating, backgroundColor: Colors.red),
                            );
                          }
                        } else {
                          await ref.read(taskNotifierProvider.notifier).deleteTask(task.id);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Task deleted'), behavior: SnackBarBehavior.floating),
                            );
                          }
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Cancel
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showNormalDeleteSheet(BuildContext context, Task task, bool isDark) {
    final dateFormat = DateFormat('MMM d, yyyy');
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
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
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Header
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
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(task.icon ?? Icons.task_rounded, color: Colors.red, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Delete Task',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              Text(
                                task.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                  ),
                  const SizedBox(height: 16),
                  
                  // Warning
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'This action cannot be undone.',
                            style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.grey.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 14, color: isDark ? Colors.white38 : Colors.grey),
                      const SizedBox(width: 6),
                      Text(dateFormat.format(task.dueDate), style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey)),
                      if (task.priority == 'High') ...[
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('High Priority', style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                            ),
                          ),
                          child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white70 : Colors.grey.shade700, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.of(sheetContext).pop();
                            await ref.read(taskNotifierProvider.notifier).deleteTask(task.id);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Task deleted'), behavior: SnackBarBehavior.floating),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.delete_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('Delete', style: TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDeleteOptionTile({
    required BuildContext context,
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDangerous = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDangerous
                ? Colors.red.withValues(alpha: isDark ? 0.1 : 0.05)
                : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDangerous
                  ? Colors.red.withValues(alpha: 0.4)
                  : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDangerous ? Colors.red : (isDark ? Colors.white : Colors.black87),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white24 : Colors.grey.shade400, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _showDangerConfirmDialog(BuildContext context, bool isDark, String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF2D3139) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.warning_rounded, color: Colors.red, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.grey.shade700, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Delete Permanently', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _toggleTaskSelection(String taskId) {
    setState(() {
      if (_selectedTaskIds.contains(taskId)) {
        _selectedTaskIds.remove(taskId);
        if (_selectedTaskIds.isEmpty) {
          _exitSelectionMode();
        }
      } else {
        _selectedTaskIds.add(taskId);
      }
    });
  }

  void _selectAll(List<Task> tasks) {
    setState(() {
      final allIds = tasks.map((t) => t.id).toSet();
      final isAllSelected = allIds.every((id) => _selectedTaskIds.contains(id));
      
      if (isAllSelected) {
        _selectedTaskIds.removeAll(allIds);
        if (_selectedTaskIds.isEmpty) _exitSelectionMode();
      } else {
        _selectedTaskIds.addAll(allIds);
      }
    });
  }

  Future<void> _performBulkAction(String action, List<Task> tasks) async {
    final selectedIds = _selectedTaskIds.toList();
    if (selectedIds.isEmpty) return;

    final notifier = ref.read(taskNotifierProvider.notifier);
    
    // Show confirmation for delete
    if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Tasks'),
          content: Text('Are you sure you want to delete ${selectedIds.length} tasks?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      
      if (confirmed != true) return;
    }

    // Perform actions using robust undo system
    int successCount = 0;
    int autoDeletedCount = 0;
    
    for (final id in selectedIds) {
      switch (action) {
        case 'done':
          // Only complete if not already completed
          final task = tasks.firstWhere((t) => t.id == id, orElse: () => Task(title: '', dueDate: DateTime.now()));
          if (task.status != 'completed') {
            await notifier.completeTask(id);
            successCount++;
          }
          break;
        case 'undo':
          // Use robust undo system - get info first for tracking
          final task = tasks.firstWhere((t) => t.id == id, orElse: () => Task(title: '', dueDate: DateTime.now()));
          final undoInfo = notifier.getUndoInfo(id);
          autoDeletedCount += undoInfo['willDeleteTasks'] as int;
          
          // Route to appropriate undo based on task status
          if (task.status == 'completed') {
            await notifier.undoTaskComplete(id);
          } else if (task.status == 'not_done') {
            await notifier.undoTaskSkip(id);
          } else if (task.parentTaskId != null) {
            await notifier.undoPostpone(id);
          } else {
            await notifier.undoTask(id);
          }
          successCount++;
          break;
        case 'delete':
          await notifier.deleteTask(id);
          successCount++;
          break;
      }
    }

    _exitSelectionMode();
    
    if (mounted) {
      String message;
      if (action == 'delete') {
        message = '$successCount task${successCount != 1 ? 's' : ''} deleted';
      } else if (action == 'done') {
        message = '$successCount task${successCount != 1 ? 's' : ''} marked as done';
      } else {
        message = '$successCount task${successCount != 1 ? 's' : ''} undone';
        if (autoDeletedCount > 0) {
          message += ' ($autoDeletedCount auto-generated occurrence${autoDeletedCount != 1 ? 's' : ''} removed)';
        }
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Check if Smart View Mode should be active
  /// Only applies when: All Tasks tab + no date filters
  bool get _isSmartViewApplicable {
    return _mainFilter == 'All' && _advancedFilter.dateFilter == DateFilterType.all;
  }

  List<Task> _filterTasks(List<Task> allTasks) {
    if (_isSearching && _searchController.text.isNotEmpty) {
      // When searching, apply advanced filters and sorting
      allTasks = _applyAdvancedFilters(allTasks);
      return _applySorting(allTasks);
    }

    List<Task> filtered = allTasks;

    // SMART VIEW MODE FILTER
    // Only applies when: Main Filter is "All" AND no advanced date filter
    // When "Today" or specific date is selected, show ALL tasks for that period
    if (_isSmartViewApplicable) {
      if (_smartViewMode == 'active') {
        // ACTIVE MODE: Show only actionable tasks (pending, overdue)
        // Exclude completed, not_done (historical data)
        filtered = filtered.where((task) {
          final status = task.status;
          return status == 'pending' || status == 'postponed';
        }).toList();
      } else if (_smartViewMode == 'history') {
        // HISTORY MODE: Show all tasks within the selected month range
        final monthStart = DateTime(_historyMonth.year, _historyMonth.month, 1);
        final monthEnd = DateTime(_historyMonth.year, _historyMonth.month + 1, 0, 23, 59, 59);
        
        filtered = filtered.where((task) {
          final relevantDate = task.completedAt ?? task.dueDate;
          return relevantDate.isAfter(monthStart.subtract(const Duration(days: 1))) &&
                 relevantDate.isBefore(monthEnd.add(const Duration(days: 1)));
        }).toList();
      }
    } else {
      // When "Today" tab or date filter is active:
      // Apply the date filter first, then show ALL statuses
      
      // Main Filter: Today
      if (_mainFilter == 'Today' && _advancedFilter.dateFilter == DateFilterType.all) {
        final today = DateTime.now();
        filtered = filtered.where((task) {
          final taskDate = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
          final todayDate = DateTime(today.year, today.month, today.day);
          return taskDate.isAtSameMomentAs(todayDate);
        }).toList();
      }
      
      // Advanced date filters are applied in _applyAdvancedFilters
    }

    // Sub Filters - work differently based on context
    switch (_subFilter) {
      case 'Special':
        filtered = filtered.where((task) => task.isSpecial).toList();
        break;
      case 'Routine':
        filtered = filtered.where((task) => task.taskKind == TaskKind.routine).toList();
        break;
      case 'Completed':
        filtered = filtered.where((task) => task.status == 'completed').toList();
        break;
      case 'Overdue':
        filtered = filtered.where((task) => task.isOverdue && task.status != 'completed').toList();
        break;
      case 'Postponed':
        filtered = filtered.where((task) => 
          task.postponeCount > 0 || task.status == 'postponed'
        ).toList();
        break;
      case 'Not Done':
        filtered = filtered.where((task) => task.status == 'not_done').toList();
        break;
      case 'Total':
      default:
        break;
    }

    // Apply Advanced Filters (date range, categories, priorities, etc.)
    filtered = _applyAdvancedFilters(filtered);

    // Apply Sorting
    filtered = _applySorting(filtered);

    return filtered;
  }

  List<Task> _applyAdvancedFilters(List<Task> tasks) {
    List<Task> filtered = tasks;

    // Date Filter
    switch (_advancedFilter.dateFilter) {
      case DateFilterType.today:
        final today = DateTime.now();
        filtered = filtered.where((task) {
          final taskDate = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
          final todayDate = DateTime(today.year, today.month, today.day);
          return taskDate.isAtSameMomentAs(todayDate);
        }).toList();
        break;
      case DateFilterType.tomorrow:
        final tomorrow = DateTime.now().add(const Duration(days: 1));
        filtered = filtered.where((task) {
          final taskDate = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
          final tomorrowDate = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
          return taskDate.isAtSameMomentAs(tomorrowDate);
        }).toList();
        break;
      case DateFilterType.thisWeek:
        final now = DateTime.now();
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        filtered = filtered.where((task) {
          final taskDate = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
          return taskDate.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
                 taskDate.isBefore(endOfWeek.add(const Duration(days: 1)));
        }).toList();
        break;
      case DateFilterType.thisMonth:
        final now = DateTime.now();
        filtered = filtered.where((task) {
          return task.dueDate.year == now.year && task.dueDate.month == now.month;
        }).toList();
        break;
      case DateFilterType.custom:
        if (_advancedFilter.customDate != null) {
          final customDate = _advancedFilter.customDate!;
          filtered = filtered.where((task) {
            final taskDate = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
            final targetDate = DateTime(customDate.year, customDate.month, customDate.day);
            return taskDate.isAtSameMomentAs(targetDate);
          }).toList();
        }
        break;
      case DateFilterType.customRange:
        if (_advancedFilter.startDate != null && _advancedFilter.endDate != null) {
          final start = DateTime(_advancedFilter.startDate!.year, 
                                 _advancedFilter.startDate!.month, 
                                 _advancedFilter.startDate!.day);
          final end = DateTime(_advancedFilter.endDate!.year, 
                               _advancedFilter.endDate!.month, 
                               _advancedFilter.endDate!.day, 23, 59, 59);
          filtered = filtered.where((task) {
            final taskDate = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
            return (taskDate.isAtSameMomentAs(start) || taskDate.isAfter(start)) &&
                   (taskDate.isAtSameMomentAs(end) || taskDate.isBefore(end));
          }).toList();
        }
        break;
      case DateFilterType.all:
      default:
        break;
    }

    // Category Filter
    if (_advancedFilter.categoryIds.isNotEmpty) {
      filtered = filtered.where((task) {
        return task.categoryId != null && _advancedFilter.categoryIds.contains(task.categoryId);
      }).toList();
    }

    // Priority Filter
    if (_advancedFilter.priorities.isNotEmpty) {
      filtered = filtered.where((task) {
        return _advancedFilter.priorities.contains(task.priority.toLowerCase());
      }).toList();
    }

    // Status Filter
    if (_advancedFilter.statuses.isNotEmpty) {
      filtered = filtered.where((task) {
        return _advancedFilter.statuses.contains(task.status);
      }).toList();
    }

    // Task Kind Filter
    if (_advancedFilter.taskKinds.isNotEmpty) {
      filtered = filtered.where((task) {
        return _advancedFilter.taskKinds.contains(task.taskKind);
      }).toList();
    }

    return filtered;
  }

  List<Task> _applySorting(List<Task> tasks) {
    final List<Task> sorted = List.from(tasks);

    switch (_sortBy) {
      case TaskSortBy.dueDateAsc:
        sorted.sort((a, b) {
          final aDate = DateTime(a.dueDate.year, a.dueDate.month, a.dueDate.day,
              a.dueTimeHour ?? 23, a.dueTimeMinute ?? 59);
          final bDate = DateTime(b.dueDate.year, b.dueDate.month, b.dueDate.day,
              b.dueTimeHour ?? 23, b.dueTimeMinute ?? 59);
          return aDate.compareTo(bDate);
        });
        break;
      case TaskSortBy.dueDateDesc:
        sorted.sort((a, b) {
          final aDate = DateTime(a.dueDate.year, a.dueDate.month, a.dueDate.day,
              a.dueTimeHour ?? 23, a.dueTimeMinute ?? 59);
          final bDate = DateTime(b.dueDate.year, b.dueDate.month, b.dueDate.day,
              b.dueTimeHour ?? 23, b.dueTimeMinute ?? 59);
          return bDate.compareTo(aDate);
        });
        break;
      case TaskSortBy.titleAsc:
        sorted.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case TaskSortBy.titleDesc:
        sorted.sort((a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
        break;
      case TaskSortBy.priorityHighToLow:
        sorted.sort((a, b) {
          const priorityOrder = {'high': 0, 'medium': 1, 'low': 2};
          return (priorityOrder[a.priority.toLowerCase()] ?? 3)
              .compareTo(priorityOrder[b.priority.toLowerCase()] ?? 3);
        });
        break;
      case TaskSortBy.priorityLowToHigh:
        sorted.sort((a, b) {
          const priorityOrder = {'low': 0, 'medium': 1, 'high': 2};
          return (priorityOrder[a.priority.toLowerCase()] ?? 3)
              .compareTo(priorityOrder[b.priority.toLowerCase()] ?? 3);
        });
        break;
      case TaskSortBy.createdDateDesc:
        sorted.sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));
        break;
      case TaskSortBy.createdDateAsc:
        sorted.sort((a, b) => (a.createdAt ?? DateTime(2000)).compareTo(b.createdAt ?? DateTime(2000)));
        break;
    }

    return sorted;
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FilterBottomSheet(
        currentFilter: _advancedFilter,
        currentSort: _sortBy,
        onApply: (filter, sort) {
          setState(() {
            _advancedFilter = filter;
            _sortBy = sort;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Use smartTaskListProvider for All Tasks view to prevent endless recurring task scroll
    // This shows only the NEXT pending occurrence per recurring group
    final tasksAsync = _isSearching && _searchController.text.isNotEmpty
        ? ref.watch(taskSearchProvider(_searchController.text))
        : ref.watch(smartTaskListProvider);

    return Scaffold(
      body: isDark
          ? DarkGradient.wrap(child: _buildContent(context, isDark, tasksAsync))
          : _buildContent(context, isDark, tasksAsync),
      floatingActionButton: !_isSelectionMode ? FloatingActionButton(
        onPressed: () => context.pushNamed('add-task'),
        backgroundColor: const Color(0xFFCDAF56), // Gold
        foregroundColor: const Color(0xFF1E1E1E), // Dark text
        child: const Icon(Icons.add_rounded),
      ) : null,
    );
  }

  Widget _buildContent(BuildContext context, bool isDark, AsyncValue<List<Task>> tasksAsync) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: _isSelectionMode 
        ? AppBar(
            backgroundColor: isDark ? Colors.black26 : Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: _exitSelectionMode,
            ),
            title: Text('${_selectedTaskIds.length} Selected'),
            actions: [
              IconButton(
                icon: const Icon(Icons.select_all),
                tooltip: 'Select All',
                onPressed: () => tasksAsync.whenData((allTasks) {
                  final filtered = _filterTasks(allTasks);
                  _selectAll(filtered);
                }),
              ),
              IconButton(
                icon: const Icon(Icons.check_circle_outlined),
                tooltip: 'Mark Done',
                onPressed: () => tasksAsync.whenData((tasks) => _performBulkAction('done', tasks)),
              ),
              IconButton(
                icon: const Icon(Icons.undo),
                tooltip: 'Undo',
                onPressed: () => tasksAsync.whenData((tasks) => _performBulkAction('undo', tasks)),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete',
                color: Colors.red[400],
                onPressed: () => tasksAsync.whenData((tasks) => _performBulkAction('delete', tasks)),
              ),
            ],
          )
        : AppBar(
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
            : const Text('Tasks Manager'),
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
          else ...[
            // Statistics Button
            IconButton(
              icon: const Icon(Icons.bar_chart_rounded),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const TaskStatisticsScreen(),
                  ),
                );
              },
              tooltip: 'Statistics',
            ),
            // Filter & Sort Button
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.filter_list_rounded),
                  onPressed: _showFilterBottomSheet,
                  tooltip: 'Filter & Sort',
                ),
                if (_advancedFilter.hasActiveFilters)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFCDAF56),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '${_advancedFilter.activeFilterCount}',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.search_rounded),
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
              tooltip: 'Search Tasks',
            ),
            IconButton(
              icon: Icon(_isListView ? Icons.grid_view_rounded : Icons.view_list_rounded),
              onPressed: () {
                setState(() {
                  _isListView = !_isListView;
                });
              },
              tooltip: _isListView ? 'Grid View' : 'List View',
            ),
          ],
        ],
        bottom: !_isSearching 
            ? TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFFCDAF56),
                labelColor: const Color(0xFFCDAF56),
                unselectedLabelColor: isDark ? Colors.grey : Colors.grey[700],
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                tabs: const [
                  Tab(text: 'All Tasks'),
                  Tab(text: 'Today'),
                ],
              )
            : null,
      ),
      body: Column(
        children: [
          // Smart View Mode Toggle (Active vs History)
          // Only show when: All Tasks tab + no date filters active
          if (!_isSearching && !_isSelectionMode && _isSmartViewApplicable)
            _buildSmartViewToggle(context, isDark),
          
          // Month Navigator (only in History mode + when applicable)
          if (!_isSearching && !_isSelectionMode && _isSmartViewApplicable && _smartViewMode == 'history')
            _buildMonthNavigator(context, isDark),
          
          // Sub-filters (Chips) - show different filters based on context
          if (!_isSearching && !_isSelectionMode) 
            _buildSubFilters(context, isDark)
          else if (_isSearching)
            const SizedBox(height: 12), // Add breathing room below search bar
          
          // Content Area with animated transition
          Expanded(
            child: GestureDetector(
              onHorizontalDragEnd: (details) {
                if (details.primaryVelocity == null) return;
                // Velocity > 0 means swiping Right (shows previous filter)
                // Velocity < 0 means swiping Left (shows next filter)
                if (details.primaryVelocity! > 500) {
                  _onSwipe(true);
                } else if (details.primaryVelocity! < -500) {
                  _onSwipe(false);
                }
              },
              behavior: HitTestBehavior.opaque,
              child: tasksAsync.when(
                data: (allTasks) {
                  final filteredTasks = _filterTasks(allTasks);
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.05, 0),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeInOut,
                          )),
                          child: child,
                        ),
                      );
                    },
                    child: _isListView
                        ? _buildListView(context, isDark, filteredTasks)
                        : _buildGridView(context, isDark, filteredTasks),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(
                  child: Text('Error loading tasks: $error'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Smart View Toggle: Active (actionable) vs History (all tasks by month)
  Widget _buildSmartViewToggle(BuildContext context, bool isDark) {
    final accentColor = const Color(0xFFCDAF56);
    
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          // Active Mode Button
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _smartViewMode = 'active';
                  // Reset to Total if current filter won't show results in active mode
                  if (_subFilter == 'Completed' || _subFilter == 'Not Done') {
                    _subFilter = 'Total';
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _smartViewMode == 'active'
                      ? accentColor
                      : (isDark ? const Color(0xFF2D3139) : Colors.grey.shade100),
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                  border: Border.all(
                    color: _smartViewMode == 'active'
                        ? accentColor
                        : (isDark ? Colors.white12 : Colors.grey.shade300),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.pending_actions_rounded,
                      size: 18,
                      color: _smartViewMode == 'active'
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.grey.shade700),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Active',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _smartViewMode == 'active'
                            ? Colors.white
                            : (isDark ? Colors.white70 : Colors.grey.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // History Mode Button
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _smartViewMode = 'history';
                  _historyMonth = DateTime.now(); // Reset to current month
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _smartViewMode == 'history'
                      ? accentColor
                      : (isDark ? const Color(0xFF2D3139) : Colors.grey.shade100),
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
                  border: Border.all(
                    color: _smartViewMode == 'history'
                        ? accentColor
                        : (isDark ? Colors.white12 : Colors.grey.shade300),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: 18,
                      color: _smartViewMode == 'history'
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.grey.shade700),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'History',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _smartViewMode == 'history'
                            ? Colors.white
                            : (isDark ? Colors.white70 : Colors.grey.shade700),
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

  /// Month Navigator for History Mode
  Widget _buildMonthNavigator(BuildContext context, bool isDark) {
    final accentColor = const Color(0xFFCDAF56);
    final monthFormat = DateFormat('MMMM yyyy');
    final now = DateTime.now();
    final isCurrentMonth = _historyMonth.year == now.year && _historyMonth.month == now.month;
    
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          // Previous Month Button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _historyMonth = DateTime(_historyMonth.year, _historyMonth.month - 1, 1);
                });
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2D3139) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                ),
                child: Icon(
                  Icons.chevron_left_rounded,
                  size: 20,
                  color: isDark ? Colors.white70 : Colors.grey.shade700,
                ),
              ),
            ),
          ),
          
          // Current Month Display
          Expanded(
            child: GestureDetector(
              onTap: () => _showMonthPicker(context, isDark),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_month_rounded, size: 18, color: accentColor),
                    const SizedBox(width: 8),
                    Text(
                      monthFormat.format(_historyMonth),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_drop_down_rounded, size: 20, color: accentColor),
                  ],
                ),
              ),
            ),
          ),
          
          // Next Month Button (disabled if current month)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isCurrentMonth ? null : () {
                HapticFeedback.selectionClick();
                setState(() {
                  _historyMonth = DateTime(_historyMonth.year, _historyMonth.month + 1, 1);
                });
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2D3139) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isCurrentMonth
                        ? (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200)
                        : (isDark ? Colors.white12 : Colors.grey.shade300),
                  ),
                ),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: isCurrentMonth
                      ? (isDark ? Colors.white24 : Colors.grey.shade400)
                      : (isDark ? Colors.white70 : Colors.grey.shade700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Show month picker dialog
  void _showMonthPicker(BuildContext context, bool isDark) {
    final accentColor = const Color(0xFFCDAF56);
    final now = DateTime.now();
    int selectedYear = _historyMonth.year;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.5,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2D3139) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  
                  // Header with year selector
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: () => setSheetState(() => selectedYear--),
                          icon: Icon(Icons.chevron_left_rounded, color: isDark ? Colors.white70 : Colors.grey.shade700),
                        ),
                        Text(
                          '$selectedYear',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        IconButton(
                          onPressed: selectedYear >= now.year ? null : () => setSheetState(() => selectedYear++),
                          icon: Icon(
                            Icons.chevron_right_rounded,
                            color: selectedYear >= now.year
                                ? (isDark ? Colors.white24 : Colors.grey.shade400)
                                : (isDark ? Colors.white70 : Colors.grey.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Month grid
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: 12,
                      itemBuilder: (context, index) {
                        final month = index + 1;
                        final monthDate = DateTime(selectedYear, month, 1);
                        final isFuture = monthDate.isAfter(now);
                        final isSelected = _historyMonth.year == selectedYear && _historyMonth.month == month;
                        final monthName = DateFormat('MMM').format(monthDate);
                        
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: isFuture ? null : () {
                              setState(() {
                                _historyMonth = DateTime(selectedYear, month, 1);
                              });
                              Navigator.of(sheetContext).pop();
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? accentColor
                                    : (isFuture
                                        ? (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade100)
                                        : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50)),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? accentColor
                                      : (isFuture
                                          ? Colors.transparent
                                          : (isDark ? Colors.white12 : Colors.grey.shade200)),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  monthName,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected
                                        ? Colors.white
                                        : (isFuture
                                            ? (isDark ? Colors.white24 : Colors.grey.shade400)
                                            : (isDark ? Colors.white70 : Colors.grey.shade700)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSubFilters(BuildContext context, bool isDark) {
    // Dynamic filters based on context:
    // - Active mode (All Tasks + no date filter): Hide Completed/Not Done (they're in History)
    // - History mode or Today/specific date: Show all filters
    final bool isActiveMode = _isSmartViewApplicable && _smartViewMode == 'active';
    
    List<String> filters;
    if (isActiveMode) {
      // Active mode: only actionable filters
      filters = ['Total', 'Overdue', 'Routine', 'Special', 'Postponed'];
    } else {
      // History mode or specific date: all filters
      filters = ['Total', 'Completed', 'Not Done', 'Overdue', 'Routine', 'Special', 'Postponed'];
    }
    
    // Reset sub-filter if current selection is not available
    if (!filters.contains(_subFilter)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _subFilter = 'Total');
      });
    }
    
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _subFilter == filter;
          
          Color chipColor;
          switch (filter) {
            case 'Special': chipColor = const Color(0xFFCDAF56); break;
            case 'Routine': chipColor = const Color(0xFFCDAF56); break;
            case 'Completed': chipColor = Colors.green; break;
            case 'Overdue': chipColor = Colors.red; break;
            case 'Postponed': chipColor = Colors.orange; break;
            case 'Not Done': chipColor = Colors.grey; break;
            default: chipColor = const Color(0xFFCDAF56);
          }

          return FilterChip(
            label: Text(filter),
            selected: isSelected,
            onSelected: (selected) {
              setState(() {
                _subFilter = filter;
              });
            },
            selectedColor: chipColor.withValues(alpha: 0.25),
            backgroundColor: isDark ? const Color(0xFF2D3139) : Colors.white,
            labelStyle: TextStyle(
              color: isSelected ? chipColor : (isDark ? Colors.grey[400] : Colors.grey[700]),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
            side: BorderSide(
              color: isSelected ? chipColor : (isDark ? const Color(0xFF3E4148) : Colors.grey[300]!),
              width: isSelected ? 1.5 : 1,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            showCheckmark: false,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            avatar: isSelected ? Icon(
              _getFilterIcon(filter),
              size: 16,
              color: chipColor,
            ) : null,
          );
        },
      ),
    );
  }
  
  IconData _getFilterIcon(String filter) {
    switch (filter) {
      case 'Special': return Icons.star_rounded;
      case 'Routine': return Icons.loop_rounded;
      case 'Completed': return Icons.check_circle_rounded;
      case 'Overdue': return Icons.warning_rounded;
      case 'Postponed': return Icons.schedule_rounded;
      case 'Not Done': return Icons.cancel_rounded;
      default: return Icons.list_rounded;
    }
  }

  Widget _buildListView(BuildContext context, bool isDark, List<Task> tasks) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.task_alt_rounded,
              size: 64,
              color: isDark ? Colors.white10 : Colors.grey[200],
            ),
            const SizedBox(height: 16),
            Text(
              'No tasks found',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      key: ValueKey('list_$_mainFilter$_subFilter'),
      padding: EdgeInsets.fromLTRB(16, _isSearching ? 20 : 0, 16, 80),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        final isSelected = _selectedTaskIds.contains(task.id);
        
        return Dismissible(
          key: ValueKey('task_list_${task.id}'),
          background: _TaskSwipeBackground(
            icon: task.status == 'completed' ? Icons.undo_rounded : Icons.check_circle_rounded,
            label: task.status == 'completed' ? 'Undo' : 'Done',
            color: const Color(0xFF4CAF50),
            isDark: isDark,
            alignRight: false,
          ),
          secondaryBackground: _TaskSwipeBackground(
            icon: Icons.delete_rounded,
            label: 'Delete',
            color: const Color(0xFFFF6B6B),
            isDark: isDark,
            alignRight: true,
          ),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.startToEnd) {
              // Swipe right - toggle done/undo
              if (task.status == 'completed') {
                await ref.read(taskNotifierProvider.notifier).undoTaskComplete(task.id);
              } else {
                await ref.read(taskNotifierProvider.notifier).completeTask(task.id);
              }
              // Force refresh to show updated status
              ref.invalidate(taskNotifierProvider);
              return false;
            }
            if (direction == DismissDirection.endToStart) {
              // Swipe left - delete
              await ref.read(taskNotifierProvider.notifier).deleteTask(task.id);
              return true;
            }
            return false;
          },
          child: _TaskListCard(
            task: task,
            isDark: isDark,
            isSelectionMode: _isSelectionMode,
            isSelected: isSelected,
            onTap: () {
              if (_isSelectionMode) {
                _toggleTaskSelection(task.id);
              } else {
                TaskDetailModal.show(
                  context,
                  task: task,
                  onTaskUpdated: () {
                  ref.invalidate(taskNotifierProvider);
                },
              );
            }
          },
          onLongPress: () {
            if (_isSelectionMode) {
              _toggleTaskSelection(task.id);
            } else {
              _showTaskContextMenu(context, task, isDark);
            }
          },
          ),
        );
      },
    );
  }

  Widget _buildGridView(BuildContext context, bool isDark, List<Task> tasks) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.grid_view_rounded,
              size: 64,
              color: isDark ? Colors.white10 : Colors.grey[200],
            ),
            const SizedBox(height: 16),
            Text(
              'No tasks found',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      key: ValueKey('grid_$_mainFilter$_subFilter'),
      padding: EdgeInsets.fromLTRB(16, _isSearching ? 20 : 0, 16, 80),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.85, // Compact cards
      ),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        final isSelected = _selectedTaskIds.contains(task.id);
        
        return Dismissible(
          key: ValueKey('task_grid_${task.id}'),
          background: _TaskSwipeBackground(
            icon: task.status == 'completed' ? Icons.undo_rounded : Icons.check_circle_rounded,
            label: task.status == 'completed' ? 'Undo' : 'Done',
            color: const Color(0xFF4CAF50),
            isDark: isDark,
            alignRight: false,
          ),
          secondaryBackground: _TaskSwipeBackground(
            icon: Icons.delete_rounded,
            label: 'Delete',
            color: const Color(0xFFFF6B6B),
            isDark: isDark,
            alignRight: true,
          ),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.startToEnd) {
              // Swipe right - toggle done/undo
              if (task.status == 'completed') {
                await ref.read(taskNotifierProvider.notifier).undoTaskComplete(task.id);
              } else {
                await ref.read(taskNotifierProvider.notifier).completeTask(task.id);
              }
              // Force refresh to show updated status
              ref.invalidate(taskNotifierProvider);
              return false;
            }
            if (direction == DismissDirection.endToStart) {
              // Swipe left - delete
              await ref.read(taskNotifierProvider.notifier).deleteTask(task.id);
              return true;
            }
            return false;
          },
          child: _TaskGridCard(
            task: task,
            isDark: isDark,
            isSelectionMode: _isSelectionMode,
            isSelected: isSelected,
            onTap: () {
              if (_isSelectionMode) {
                _toggleTaskSelection(task.id);
            } else {
              TaskDetailModal.show(
                context,
                task: task,
                onTaskUpdated: () {
                  ref.invalidate(taskNotifierProvider);
                },
              );
            }
          },
          onLongPress: () {
            if (_isSelectionMode) {
              _toggleTaskSelection(task.id);
            } else {
              _showTaskContextMenu(context, task, isDark);
            }
          },
          ),
        );
      },
    );
  }
}

/// Swipe background for task actions
class _TaskSwipeBackground extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final bool alignRight;

  const _TaskSwipeBackground({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.alignRight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.2 : 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (alignRight) ...[
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Icon(
            icon,
            color: color,
          ),
          if (!alignRight) ...[
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Task List Card Widget
class _TaskListCard extends ConsumerWidget {
  final Task task;
  final bool isDark;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _TaskListCard({
    required this.task,
    required this.isDark,
    this.isSelectionMode = false,
    this.isSelected = false,
    required this.onTap,
    required this.onLongPress,
  });

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return const Color(0xFFFF5252);
      case 'medium':
        return const Color(0xFFFFA726);
      case 'low':
        return const Color(0xFF66BB6A);
      default:
        return Colors.grey;
    }
  }

  String _formatDateTime() {
    String timeStr = '';
    if (task.dueTimeHour != null && task.dueTimeMinute != null) {
      final hour = task.dueTimeHour!;
      final minute = task.dueTimeMinute!;
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      timeStr = '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
    }
    return '${DateFormat('MMM d').format(task.dueDate)}${timeStr.isNotEmpty ? ', $timeStr' : ''}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOverdue = task.isOverdue && task.status != 'completed';
    final priorityColor = _getPriorityColor(task.priority);

    // Get category from database if available
    final categoryAsync = task.categoryId != null
        ? ref.watch(categoryByIdProvider(task.categoryId!))
        : null;

    return Card(
      elevation: 0,
      color: isDark 
          ? (isSelected ? const Color(0xFFCDAF56).withOpacity(0.15) : const Color(0xFF2D3139))
          : (isSelected ? const Color(0xFFCDAF56).withOpacity(0.1) : Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected 
              ? const Color(0xFFCDAF56) 
              : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
          width: isSelected ? 2 : 1,
        ),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias, // Ensure content doesn't overflow rounded corners
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Row(
                children: [
                  // Selection Checkbox or Category Icon
                  if (isSelectionMode)
                     Container(
                      margin: const EdgeInsets.only(right: 16),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? const Color(0xFFCDAF56) : Colors.transparent,
                        border: Border.all(
                          color: isSelected ? const Color(0xFFCDAF56) : Colors.grey,
                          width: 2,
                        ),
                      ),
                      child: isSelected 
                        ? const Icon(Icons.check, size: 16, color: Colors.white) 
                        : null,
                    )
                  else ...[
                    // Task Icon (prioritized) or Category Icon or status indicator
                    (() {
                      final taskIcon = task.icon;
                      
                      // Handle the case where category might still be loading or errored
                      return categoryAsync?.when(
                        data: (category) {
                          final Color color = category?.color ?? Colors.grey;
                          final IconData icon = taskIcon ?? category?.icon ?? Icons.task_alt_rounded;
                          
                          return Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              clipBehavior: Clip.none,
                              children: [
                                Icon(
                                  icon,
                                  color: color,
                                  size: 22,
                                ),
                                if (task.isRoutineTask)
                                  Positioned(
                                    right: -2,
                                    bottom: -2,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF2D3139) : Colors.white,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(0xFFCDAF56).withOpacity(0.5),
                                          width: 1,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.sync_rounded,
                                        size: 10,
                                        color: const Color(0xFFCDAF56),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                        loading: () => Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              Icon(
                                taskIcon ?? Icons.task_alt_rounded,
                                color: Colors.grey,
                                size: 22,
                              ),
                              if (task.isRoutineTask)
                                Positioned(
                                  right: -2,
                                  bottom: -2,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF2D3139) : Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFFCDAF56).withOpacity(0.5),
                                        width: 1,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.sync_rounded,
                                      size: 10,
                                      color: Color(0xFFCDAF56),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        error: (_, __) => _buildDefaultIcon(isDark),
                      ) ?? Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            Icon(
                              taskIcon ?? Icons.task_alt_rounded,
                              color: Colors.grey,
                              size: 22,
                            ),
                            if (task.isRoutineTask)
                              Positioned(
                                right: -2,
                                bottom: -2,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF2D3139) : Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.grey.withOpacity(0.5),
                                      width: 1,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.sync_rounded,
                                    size: 10,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    })(),
                    
                    const SizedBox(width: 16),
                  ],
                  
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                task.title,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: task.status == 'completed'
                                          ? const Color(0xFF4CAF50) // Green for completed
                                          : task.status == 'not_done'
                                              ? const Color(0xFFFF6B6B) // Red for not done
                                              : (isDark ? Colors.white : const Color(0xFF1E1E1E)),
                                      fontWeight: task.status == 'not_done' ? FontWeight.w700 : FontWeight.w600,
                                      decoration: task.status == 'completed'
                                          ? TextDecoration.lineThrough
                                          : null,
                                      decorationThickness: task.status == 'completed' ? 2 : null,
                                      decorationColor: const Color(0xFF4CAF50),
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (task.status == 'not_done') ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF6B6B).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: const Color(0xFFFF6B6B).withOpacity(0.3),
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  'Not Done',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFFFF6B6B),
                                  ),
                                ),
                              ),
                            ],
                            if (task.status == 'completed') ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4CAF50).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: const Color(0xFF4CAF50).withOpacity(0.3),
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  'Done',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF4CAF50),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: 14,
                                  color: isOverdue
                                      ? Colors.red[400]
                                      : (isDark ? Colors.grey[400] : Colors.grey[600]),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _formatDateTime(),
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: isOverdue
                                            ? Colors.red[400]
                                            : (isDark ? Colors.grey[400] : Colors.grey[600]),
                                        fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal,
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  if (isOverdue && !isSelectionMode) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.error_outline_rounded, size: 20, color: Colors.red[400]),
                  ],
                  
                  const SizedBox(width: 12),
                ],
              ),
            ),
            
            // Priority Tag or Special Badge (Top Right Corner)
            if (!isSelectionMode)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: task.isSpecial 
                        ? const Color(0xFFCDAF56).withOpacity(0.15)
                        : priorityColor.withOpacity(0.15),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: task.isSpecial 
                            ? const Color(0xFFCDAF56).withOpacity(0.3)
                            : priorityColor.withOpacity(0.3), 
                        width: 1,
                      ),
                      left: BorderSide(
                        color: task.isSpecial 
                            ? const Color(0xFFCDAF56).withOpacity(0.3)
                            : priorityColor.withOpacity(0.3), 
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (task.isSpecial) ...[
                        const Icon(Icons.star_rounded, size: 10, color: Color(0xFFCDAF56)),
                        const SizedBox(width: 3),
                      ],
                      Text(
                        task.isSpecial ? 'SPECIAL' : task.priority.toUpperCase(),
                        style: TextStyle(
                          color: task.isSpecial ? const Color(0xFFCDAF56) : priorityColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultIcon(bool isDark) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.task_alt_rounded,
        color: isDark ? Colors.grey[400] : Colors.grey[600],
        size: 22,
      ),
    );
  }
}

/// Task Grid Card Widget
class _TaskGridCard extends ConsumerWidget {
  final Task task;
  final bool isDark;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _TaskGridCard({
    required this.task,
    required this.isDark,
    this.isSelectionMode = false,
    this.isSelected = false,
    required this.onTap,
    required this.onLongPress,
  });

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return const Color(0xFFFF5252);
      case 'medium':
        return const Color(0xFFFFA726);
      case 'low':
        return const Color(0xFF66BB6A);
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
    return 'No time';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final priorityColor = _getPriorityColor(task.priority);
    final progress = task.subtaskProgress;
    final isOverdue = task.isOverdue && task.status != 'completed';
    
    // Get category from database if available
    final categoryAsync = task.categoryId != null
        ? ref.watch(categoryByIdProvider(task.categoryId!))
        : null;

    final themeColor = isOverdue ? Colors.red[400]! : priorityColor;

    // Determine border color based on category or priority
    Color borderColor = priorityColor;
    if (categoryAsync != null) {
      final categoryData = categoryAsync.valueOrNull;
      if (categoryData?.color != null) {
        borderColor = categoryData!.color;
      }
    }

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: isDark 
          ? (isSelected ? const Color(0xFFCDAF56).withOpacity(0.12) : const Color(0xFF252A31))
          : (isSelected ? const Color(0xFFCDAF56).withOpacity(0.08) : Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected 
              ? const Color(0xFFCDAF56) 
              : (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06)),
          width: isSelected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // Background Watermark Icon
            Positioned(
              right: -10,
              bottom: -10,
              child: Icon(
                task.icon ?? Icons.task_alt_rounded,
                size: 65,
                color: (task.isSpecial ? const Color(0xFFCDAF56) : borderColor).withOpacity(isDark ? 0.1 : 0.06),
              ),
            ),
            
            // Left Color Accent
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 4,
                color: task.isSpecial ? const Color(0xFFCDAF56) : borderColor,
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Selection Checkbox or Icon
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                       if (isSelectionMode)
                         Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected ? const Color(0xFFCDAF56) : Colors.transparent,
                            border: Border.all(
                              color: isSelected ? const Color(0xFFCDAF56) : Colors.grey,
                              width: 2,
                            ),
                          ),
                          child: isSelected 
                            ? const Icon(Icons.check, size: 12, color: Colors.white) 
                            : null,
                        )
                      else
                        categoryAsync?.when(
                          data: (category) {
                            final Color color = category?.color ?? Colors.grey;
                            return Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                clipBehavior: Clip.none,
                                children: [
                                  Icon(
                                    task.icon ?? category?.icon ?? Icons.task_alt_rounded,
                                    size: 14,
                                    color: color,
                                  ),
                                  if (task.isRoutineTask)
                                    Positioned(
                                      right: -4,
                                      bottom: -4,
                                      child: Container(
                                        padding: const EdgeInsets.all(1),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF252A31) : Colors.white,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: const Color(0xFFCDAF56).withOpacity(0.5),
                                            width: 0.5,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.sync_rounded,
                                          size: 8,
                                          color: const Color(0xFFCDAF56),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                          loading: () => Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              clipBehavior: Clip.none,
                              children: [
                                Icon(
                                  task.icon ?? Icons.task_alt_rounded,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                                if (task.isRoutineTask)
                                  Positioned(
                                    right: -4,
                                    bottom: -4,
                                    child: Container(
                                      padding: const EdgeInsets.all(1),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF252A31) : Colors.white,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(0xFFCDAF56).withOpacity(0.5),
                                          width: 0.5,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.sync_rounded,
                                        size: 8,
                                        color: Color(0xFFCDAF56),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          error: (_, __) => const SizedBox(width: 24, height: 24),
                        ) ?? Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              Icon(
                                task.icon ?? Icons.task_alt_rounded,
                                size: 14,
                                color: Colors.grey,
                              ),
                              if (task.isRoutineTask)
                                Positioned(
                                  right: -4,
                                  bottom: -4,
                                  child: Container(
                                    padding: const EdgeInsets.all(1),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF252A31) : Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.grey.withOpacity(0.5),
                                        width: 0.5,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.sync_rounded,
                                      size: 8,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  
                  const SizedBox(height: 10),
                  
                  // Task Title and Overdue Icon
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Flexible(
                              child: Text(
                                task.title,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: task.status == 'completed'
                                          ? const Color(0xFF4CAF50) // Green for completed
                                          : task.status == 'not_done'
                                              ? const Color(0xFFFF6B6B) // Red for not done
                                              : (isDark ? Colors.white : const Color(0xFF1E1E1E)),
                                      fontWeight: task.status == 'not_done' ? FontWeight.w800 : FontWeight.w700,
                                      fontSize: 15,
                                      height: 1.25,
                                      decoration: task.status == 'completed'
                                          ? TextDecoration.lineThrough
                                          : null,
                                      decorationThickness: task.status == 'completed' ? 2 : null,
                                      decorationColor: const Color(0xFF4CAF50),
                                    ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (task.status == 'not_done') ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF6B6B).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(
                                    color: const Color(0xFFFF6B6B).withOpacity(0.3),
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  'Not Done',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFFFF6B6B),
                                  ),
                                ),
                              ),
                            ],
                            if (task.status == 'completed') ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4CAF50).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(
                                    color: const Color(0xFF4CAF50).withOpacity(0.3),
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  'Done',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF4CAF50),
                                  ),
                                ),
                              ),
                            ],
                            if (isOverdue && !isSelectionMode)
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Icon(Icons.error_outline_rounded, size: 16, color: Colors.red[400]),
                              ),
                          ],
                        ),
                        if (task.description != null && task.description!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            task.description!,
                            style: TextStyle(
                              color: isDark ? Colors.white54 : Colors.black54,
                              fontSize: 11,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  // Bottom Info - Clean row
                  if (!isSelectionMode)
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 12,
                          color: isOverdue ? Colors.red[400] : (isDark ? Colors.white38 : Colors.black38),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${DateFormat('MMM d').format(task.dueDate)} · ${_formatTime()}',
                            style: TextStyle(
                              color: isOverdue ? Colors.red[400] : (isDark ? Colors.white54 : Colors.black54),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            
            // Priority Tag or Special Badge (Top Right Corner)
            if (!isSelectionMode)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: task.isSpecial 
                        ? const Color(0xFFCDAF56).withOpacity(0.15)
                        : priorityColor.withOpacity(0.15),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(10),
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: task.isSpecial 
                            ? const Color(0xFFCDAF56).withOpacity(0.2)
                            : priorityColor.withOpacity(0.2), 
                        width: 1,
                      ),
                      left: BorderSide(
                        color: task.isSpecial 
                            ? const Color(0xFFCDAF56).withOpacity(0.2)
                            : priorityColor.withOpacity(0.2), 
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (task.isSpecial) ...[
                        const Icon(Icons.star_rounded, size: 8, color: Color(0xFFCDAF56)),
                        const SizedBox(width: 2),
                      ],
                      Text(
                        task.isSpecial ? 'SPECIAL' : task.priority.toUpperCase(),
                        style: TextStyle(
                          color: task.isSpecial ? const Color(0xFFCDAF56) : priorityColor,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Filter Bottom Sheet Widget
class _FilterBottomSheet extends ConsumerStatefulWidget {
  final TaskFilter currentFilter;
  final TaskSortBy currentSort;
  final Function(TaskFilter, TaskSortBy) onApply;

  const _FilterBottomSheet({
    required this.currentFilter,
    required this.currentSort,
    required this.onApply,
  });

  @override
  ConsumerState<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends ConsumerState<_FilterBottomSheet> {
  late TaskFilter _filter;
  late TaskSortBy _sortBy;

  @override
  void initState() {
    super.initState();
    _filter = widget.currentFilter;
    _sortBy = widget.currentSort;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle Bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black26,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filter & Sort',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _filter = const TaskFilter();
                      _sortBy = TaskSortBy.dueDateAsc;
                    });
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Reset'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFCDAF56),
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date Filter Section
                  _buildSectionTitle('Date Filter', Icons.calendar_today_rounded),
                  const SizedBox(height: 12),
                  _buildDateFilterOptions(isDark),
                  
                  const SizedBox(height: 24),
                  
                  // Sort Section
                  _buildSectionTitle('Sort By', Icons.sort_rounded),
                  const SizedBox(height: 12),
                  _buildSortOptions(isDark),
                  
                  const SizedBox(height: 24),
                  
                  // Priority Filter Section
                  _buildSectionTitle('Priority', Icons.flag_rounded),
                  const SizedBox(height: 12),
                  _buildPriorityFilter(isDark),
                  
                  const SizedBox(height: 24),
                  
                  // Status Filter Section
                  _buildSectionTitle('Status', Icons.check_circle_outline_rounded),
                  const SizedBox(height: 12),
                  _buildStatusFilter(isDark),
                  
                  const SizedBox(height: 24),
                  
                  // Task Kind Filter Section
                  _buildSectionTitle('Task Type', Icons.task_alt_rounded),
                  const SizedBox(height: 12),
                  _buildTaskKindFilter(isDark),
                  
                  const SizedBox(height: 24),
                  
                  // Category Filter Section
                  _buildSectionTitle('Categories', Icons.category_rounded),
                  const SizedBox(height: 12),
                  _buildCategoryFilter(isDark),
                  
                  const SizedBox(height: 80), // Extra space for button
                ],
              ),
            ),
          ),
          
          // Apply Button
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2D3139) : Colors.grey[50],
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
              ),
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onApply(_filter, _sortBy);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCDAF56),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Apply Filters',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: const Color(0xFFCDAF56),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildDateFilterOptions(bool isDark) {
    return Column(
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildFilterChip(
              'All',
              _filter.dateFilter == DateFilterType.all,
              () => setState(() => _filter = _filter.copyWith(dateFilter: DateFilterType.all)),
              isDark,
            ),
            _buildFilterChip(
              'Today',
              _filter.dateFilter == DateFilterType.today,
              () => setState(() => _filter = _filter.copyWith(dateFilter: DateFilterType.today)),
              isDark,
            ),
            _buildFilterChip(
              'Tomorrow',
              _filter.dateFilter == DateFilterType.tomorrow,
              () => setState(() => _filter = _filter.copyWith(dateFilter: DateFilterType.tomorrow)),
              isDark,
            ),
            _buildFilterChip(
              'This Week',
              _filter.dateFilter == DateFilterType.thisWeek,
              () => setState(() => _filter = _filter.copyWith(dateFilter: DateFilterType.thisWeek)),
              isDark,
            ),
            _buildFilterChip(
              'This Month',
              _filter.dateFilter == DateFilterType.thisMonth,
              () => setState(() => _filter = _filter.copyWith(dateFilter: DateFilterType.thisMonth)),
              isDark,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _filter.customDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: ColorScheme.light(
                            primary: const Color(0xFFCDAF56),
                            onPrimary: Colors.black,
                            surface: isDark ? const Color(0xFF2D3139) : Colors.white,
                            onSurface: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (date != null) {
                    setState(() {
                      _filter = _filter.copyWith(
                        dateFilter: DateFilterType.custom,
                        customDate: date,
                      );
                    });
                  }
                },
                icon: Icon(
                  Icons.calendar_today_rounded,
                  size: 18,
                  color: _filter.dateFilter == DateFilterType.custom
                      ? const Color(0xFFCDAF56)
                      : (isDark ? Colors.white70 : Colors.black54),
                ),
                label: Text(
                  _filter.dateFilter == DateFilterType.custom && _filter.customDate != null
                      ? DateFormat('MMM d, yyyy').format(_filter.customDate!)
                      : 'Pick Date',
                  style: TextStyle(
                    color: _filter.dateFilter == DateFilterType.custom
                        ? const Color(0xFFCDAF56)
                        : (isDark ? Colors.white70 : Colors.black54),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: _filter.dateFilter == DateFilterType.custom
                        ? const Color(0xFFCDAF56)
                        : (isDark ? Colors.white24 : Colors.black26),
                  ),
                  backgroundColor: _filter.dateFilter == DateFilterType.custom
                      ? const Color(0xFFCDAF56).withOpacity(0.1)
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                    initialDateRange: _filter.startDate != null && _filter.endDate != null
                        ? DateTimeRange(start: _filter.startDate!, end: _filter.endDate!)
                        : null,
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: ColorScheme.light(
                            primary: const Color(0xFFCDAF56),
                            onPrimary: Colors.black,
                            surface: isDark ? const Color(0xFF2D3139) : Colors.white,
                            onSurface: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (range != null) {
                    setState(() {
                      _filter = _filter.copyWith(
                        dateFilter: DateFilterType.customRange,
                        startDate: range.start,
                        endDate: range.end,
                      );
                    });
                  }
                },
                icon: Icon(
                  Icons.date_range_rounded,
                  size: 18,
                  color: _filter.dateFilter == DateFilterType.customRange
                      ? const Color(0xFFCDAF56)
                      : (isDark ? Colors.white70 : Colors.black54),
                ),
                label: Text(
                  _filter.dateFilter == DateFilterType.customRange &&
                          _filter.startDate != null &&
                          _filter.endDate != null
                      ? 'Range Set'
                      : 'Date Range',
                  style: TextStyle(
                    color: _filter.dateFilter == DateFilterType.customRange
                        ? const Color(0xFFCDAF56)
                        : (isDark ? Colors.white70 : Colors.black54),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: _filter.dateFilter == DateFilterType.customRange
                        ? const Color(0xFFCDAF56)
                        : (isDark ? Colors.white24 : Colors.black26),
                  ),
                  backgroundColor: _filter.dateFilter == DateFilterType.customRange
                      ? const Color(0xFFCDAF56).withOpacity(0.1)
                      : null,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSortOptions(bool isDark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildFilterChip(
          'Due Date ↑',
          _sortBy == TaskSortBy.dueDateAsc,
          () => setState(() => _sortBy = TaskSortBy.dueDateAsc),
          isDark,
          icon: Icons.arrow_upward_rounded,
        ),
        _buildFilterChip(
          'Due Date ↓',
          _sortBy == TaskSortBy.dueDateDesc,
          () => setState(() => _sortBy = TaskSortBy.dueDateDesc),
          isDark,
          icon: Icons.arrow_downward_rounded,
        ),
        _buildFilterChip(
          'Title A-Z',
          _sortBy == TaskSortBy.titleAsc,
          () => setState(() => _sortBy = TaskSortBy.titleAsc),
          isDark,
        ),
        _buildFilterChip(
          'Title Z-A',
          _sortBy == TaskSortBy.titleDesc,
          () => setState(() => _sortBy = TaskSortBy.titleDesc),
          isDark,
        ),
        _buildFilterChip(
          'Priority High-Low',
          _sortBy == TaskSortBy.priorityHighToLow,
          () => setState(() => _sortBy = TaskSortBy.priorityHighToLow),
          isDark,
        ),
        _buildFilterChip(
          'Priority Low-High',
          _sortBy == TaskSortBy.priorityLowToHigh,
          () => setState(() => _sortBy = TaskSortBy.priorityLowToHigh),
          isDark,
        ),
        _buildFilterChip(
          'Created (New)',
          _sortBy == TaskSortBy.createdDateDesc,
          () => setState(() => _sortBy = TaskSortBy.createdDateDesc),
          isDark,
        ),
        _buildFilterChip(
          'Created (Old)',
          _sortBy == TaskSortBy.createdDateAsc,
          () => setState(() => _sortBy = TaskSortBy.createdDateAsc),
          isDark,
        ),
      ],
    );
  }

  Widget _buildPriorityFilter(bool isDark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildFilterChip(
          'High',
          _filter.priorities.contains('high'),
          () {
            setState(() {
              final priorities = List<String>.from(_filter.priorities);
              if (priorities.contains('high')) {
                priorities.remove('high');
              } else {
                priorities.add('high');
              }
              _filter = _filter.copyWith(priorities: priorities);
            });
          },
          isDark,
          color: const Color(0xFFFF5252),
        ),
        _buildFilterChip(
          'Medium',
          _filter.priorities.contains('medium'),
          () {
            setState(() {
              final priorities = List<String>.from(_filter.priorities);
              if (priorities.contains('medium')) {
                priorities.remove('medium');
              } else {
                priorities.add('medium');
              }
              _filter = _filter.copyWith(priorities: priorities);
            });
          },
          isDark,
          color: const Color(0xFFFFA726),
        ),
        _buildFilterChip(
          'Low',
          _filter.priorities.contains('low'),
          () {
            setState(() {
              final priorities = List<String>.from(_filter.priorities);
              if (priorities.contains('low')) {
                priorities.remove('low');
              } else {
                priorities.add('low');
              }
              _filter = _filter.copyWith(priorities: priorities);
            });
          },
          isDark,
          color: const Color(0xFF66BB6A),
        ),
      ],
    );
  }

  Widget _buildStatusFilter(bool isDark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildFilterChip(
          'Pending',
          _filter.statuses.contains('pending'),
          () {
            setState(() {
              final statuses = List<String>.from(_filter.statuses);
              if (statuses.contains('pending')) {
                statuses.remove('pending');
              } else {
                statuses.add('pending');
              }
              _filter = _filter.copyWith(statuses: statuses);
            });
          },
          isDark,
        ),
        _buildFilterChip(
          'Completed',
          _filter.statuses.contains('completed'),
          () {
            setState(() {
              final statuses = List<String>.from(_filter.statuses);
              if (statuses.contains('completed')) {
                statuses.remove('completed');
              } else {
                statuses.add('completed');
              }
              _filter = _filter.copyWith(statuses: statuses);
            });
          },
          isDark,
          color: Colors.green,
        ),
        _buildFilterChip(
          'Not Done',
          _filter.statuses.contains('not_done'),
          () {
            setState(() {
              final statuses = List<String>.from(_filter.statuses);
              if (statuses.contains('not_done')) {
                statuses.remove('not_done');
              } else {
                statuses.add('not_done');
              }
              _filter = _filter.copyWith(statuses: statuses);
            });
          },
          isDark,
          color: Colors.grey,
        ),
      ],
    );
  }

  Widget _buildTaskKindFilter(bool isDark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildFilterChip(
          'Normal',
          _filter.taskKinds.contains(TaskKind.normal),
          () {
            setState(() {
              final kinds = List<String>.from(_filter.taskKinds);
              if (kinds.contains(TaskKind.normal)) {
                kinds.remove(TaskKind.normal);
              } else {
                kinds.add(TaskKind.normal);
              }
              _filter = _filter.copyWith(taskKinds: kinds);
            });
          },
          isDark,
          icon: Icons.event_rounded,
        ),
        _buildFilterChip(
          'Routine',
          _filter.taskKinds.contains(TaskKind.routine),
          () {
            setState(() {
              final kinds = List<String>.from(_filter.taskKinds);
              if (kinds.contains(TaskKind.routine)) {
                kinds.remove(TaskKind.routine);
              } else {
                kinds.add(TaskKind.routine);
              }
              _filter = _filter.copyWith(taskKinds: kinds);
            });
          },
          isDark,
          icon: Icons.loop_rounded,
          color: const Color(0xFFCDAF56),
        ),
        _buildFilterChip(
          'Recurring',
          _filter.taskKinds.contains(TaskKind.recurring),
          () {
            setState(() {
              final kinds = List<String>.from(_filter.taskKinds);
              if (kinds.contains(TaskKind.recurring)) {
                kinds.remove(TaskKind.recurring);
              } else {
                kinds.add(TaskKind.recurring);
              }
              _filter = _filter.copyWith(taskKinds: kinds);
            });
          },
          isDark,
          icon: Icons.repeat_rounded,
          color: const Color(0xFFCDAF56),
        ),
      ],
    );
  }

  Widget _buildCategoryFilter(bool isDark) {
    final categoriesAsync = ref.watch(categoryNotifierProvider);
    
    return categoriesAsync.when(
      data: (categories) {
        if (categories.isEmpty) {
          return Text(
            'No categories available',
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.black54,
              fontSize: 14,
            ),
          );
        }
        
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: categories.map((category) {
            final isSelected = _filter.categoryIds.contains(category.id);
            return _buildFilterChip(
              category.name,
              isSelected,
              () {
                setState(() {
                  final categoryIds = List<String>.from(_filter.categoryIds);
                  if (categoryIds.contains(category.id)) {
                    categoryIds.remove(category.id);
                  } else {
                    categoryIds.add(category.id);
                  }
                  _filter = _filter.copyWith(categoryIds: categoryIds);
                });
              },
              isDark,
              icon: category.icon,
              color: category.color,
            );
          }).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Text(
        'Error loading categories',
        style: TextStyle(
          color: isDark ? Colors.red[300] : Colors.red,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    bool isSelected,
    VoidCallback onTap,
    bool isDark, {
    IconData? icon,
    Color? color,
  }) {
    final chipColor = color ?? const Color(0xFFCDAF56);
    
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: isSelected ? chipColor : (isDark ? Colors.white54 : Colors.black54)),
            const SizedBox(width: 4),
          ],
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: chipColor.withOpacity(0.2),
      backgroundColor: isDark ? const Color(0xFF2D3139) : Colors.grey[100],
      labelStyle: TextStyle(
        color: isSelected ? chipColor : (isDark ? Colors.white70 : Colors.black87),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 13,
      ),
      side: BorderSide(
        color: isSelected ? chipColor : (isDark ? Colors.white24 : Colors.black26),
        width: isSelected ? 1.5 : 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }
}
