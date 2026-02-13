import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../data/models/task.dart';
import '../../../../main.dart';
import '../../../tasks/presentation/providers/task_providers.dart';
import '../../../tasks/presentation/screens/add_task_screen.dart';
import '../../../tasks/presentation/screens/task_settings_screen.dart';
import '../../../tasks/presentation/screens/tasks_screen.dart';
import '../../../tasks/presentation/widgets/task_detail_modal.dart';
import '../widgets/today_home_widget.dart';
import '../../../../core/theme/dark_gradient.dart';

/// Home Screen - Premium modern design with dark/light theme support
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeMode = ref.watch(themeModeProvider);
    
    // Watch task stats for today
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final tasksAsync = ref.watch(tasksForDateProvider(today));
    final postponedAsync = ref.watch(tasksPostponedFromDateProvider(today));
    
    final taskStats = tasksAsync.when(
      data: (tasks) => postponedAsync.when(
        data: (postponed) => {
          'total': tasks.length + postponed.length,
          'completed': tasks.where((t) => t.status == 'completed').length,
        },
        loading: () => {'total': tasks.length, 'completed': 0},
        error: (_, __) => {'total': tasks.length, 'completed': 0},
      ),
      loading: () => {'total': 0, 'completed': 0},
      error: (_, __) => {'total': 0, 'completed': 0},
    );

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark 
              ? [
                  const Color(0xFF2A2D3A), // Top - Dark blue-gray
                  const Color(0xFF212529), // Middle - Charcoal
                  const Color(0xFF1A1D23), // Bottom - Almost black
                ]
              : [
                  const Color(0xFFF9F7F2),
                  const Color(0xFFEDE9E0),
                ],
          ),
        ),
        // Add subtle noise texture overlay for dark mode
        child: isDark
          ? Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.02), // 2% noise effect
              ),
              child: _buildContent(context, ref, isDark, themeMode, taskStats),
            )
          : _buildContent(context, ref, isDark, themeMode, taskStats),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, bool isDark, ThemeMode themeMode, Map<String, int> taskStats) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 100), // Space for bottom nav
        children: [
          // Header Section with Theme Toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Greeting text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hey Abela! 👋',
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: isDark 
                            ? const Color(0xFFFFFFFF)
                            : const Color(0xFF1E1E1E),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ready to manage your day?',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontSize: 16,
                          color: isDark
                            ? const Color(0xFFBDBDBD)
                            : const Color(0xFF6E6E6E),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Theme Toggle Button
                Container(
                  decoration: BoxDecoration(
                    color: isDark
                      ? const Color(0xFF2D3139) // Dark gray
                      : const Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFCDAF56),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        // Toggle theme
                        ref.read(themeModeProvider.notifier).state = 
                          themeMode == ThemeMode.dark
                            ? ThemeMode.light
                            : ThemeMode.dark;
                      },
                      borderRadius: BorderRadius.circular(12),
                      splashColor: const Color(0xFFCDAF56).withOpacity(0.2),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Icon(
                          themeMode == ThemeMode.dark
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded,
                          color: const Color(0xFFCDAF56),
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Today Overview Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                  ? const Color(0xFF2D3139) // Dark gray card
                  : const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(20),
                border: isDark
                  ? Border.all(
                      color: const Color(0xFF3E4148).withOpacity(0.5),
                      width: 1,
                    )
                  : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Today Overview',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: isDark
                        ? const Color(0xFFFFFFFF)
                        : const Color(0xFF1E1E1E),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatItem(
                        icon: Icons.task_alt_rounded,
                        label: 'Tasks',
                        value: '${taskStats['completed']}/${taskStats['total']}',
                        isDark: isDark,
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: isDark
                          ? const Color(0xFF3E4148)
                          : const Color(0xFFEDE9E0),
                      ),
                      _StatItem(
                        icon: Icons.auto_awesome_rounded,
                        label: 'Habits',
                        value: '3/5',
                        isDark: isDark,
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: isDark
                          ? const Color(0xFF3E4148)
                          : const Color(0xFFEDE9E0),
                      ),
                      _StatItem(
                        icon: Icons.mood_rounded,
                        label: 'Mood',
                        value: '😊',
                        isDark: isDark,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Today's Tasks
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _TodayTasksPanel(isDark: isDark),
          ),

          const SizedBox(height: 24),

          // Quick Actions Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Actions',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: isDark
                      ? const Color(0xFFFFFFFF)
                      : const Color(0xFF1E1E1E),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Row 1
                Row(
                  children: [
                    Expanded(
                      child: _QuickActionButton(
                        icon: Icons.add_task_rounded,
                        label: 'Add Task',
                        isDark: isDark,
                        onTap: () {},
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickActionButton(
                        icon: Icons.check_circle_outline_rounded,
                        label: 'Log Habit',
                        isDark: isDark,
                        onTap: () {},
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Row 2
                Row(
                  children: [
                    Expanded(
                      child: _QuickActionButton(
                        icon: Icons.bar_chart_rounded,
                        label: 'View Stats',
                        isDark: isDark,
                        onTap: () {},
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickActionButton(
                        icon: Icons.more_horiz_rounded,
                        label: 'More',
                        isDark: isDark,
                        onTap: () {},
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

class _TodayTasksPanel extends ConsumerStatefulWidget {
  final bool isDark;

  const _TodayTasksPanel({required this.isDark});

  @override
  ConsumerState<_TodayTasksPanel> createState() => _TodayTasksPanelState();
}

class _TodayTasksPanelState extends ConsumerState<_TodayTasksPanel> {
  late final DateTime _today = () {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }();

  bool _showCompleted = false;
  bool _showPostponed = false;
  bool _showNotDone = false;
  String _lastWidgetSnapshot = '';

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksForDateProvider(_today));
    final postponedAsync = ref.watch(tasksPostponedFromDateProvider(_today));

    return Container(
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF252A34) : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.isDark
              ? const Color(0xFF353A44)
              : const Color(0xFFE7E0D6),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(widget.isDark ? 0.28 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: tasksAsync.when(
        data: (tasks) => postponedAsync.when(
          data: (postponed) => _buildContent(context, tasks, postponed),
          loading: () => _buildContent(context, tasks, []),
          error: (_, __) => _buildContent(context, tasks, []),
        ),
        loading: () => const SizedBox(
          height: 140,
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Color(0xFFCDAF56),
            ),
          ),
        ),
        error: (error, _) => _buildError(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<Task> tasks, List<Task> postponedTasks) {
    // Total tasks includes current tasks for today + tasks moved away (postponed)
    final total = tasks.length + postponedTasks.length;
    final completed = tasks.where((t) => t.status == 'completed').length;
    final pending = tasks.where((t) => t.status == 'pending').length;
    final overdue = tasks
        .where((t) => t.isOverdue && t.status != 'completed' && t.status != 'not_done')
        .length;

    final filtered = _filteredTasks(tasks);
    final progress = total == 0 ? 0.0 : completed / total;

    _pushWidgetUpdate(tasks, pending, completed, overdue);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Today's Tasks",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: widget.isDark
                              ? const Color(0xFFFFFFFF)
                              : const Color(0xFF1E1E1E),
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${DateFormat('EEE, MMM d').format(_today)} • $pending pending • $completed done${overdue > 0 ? ' • $overdue overdue' : ''}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: widget.isDark
                              ? const Color(0xFFBDBDBD)
                              : const Color(0xFF6E6E6E),
                        ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                _IconPill(
                  icon: Icons.tune_rounded,
                  tooltip: 'Settings & filters',
                  isDark: widget.isDark,
                  onTap: () => _openSettings(context),
                ),
                const SizedBox(width: 8),
                _IconPill(
                  icon: Icons.view_agenda_rounded,
                  tooltip: 'View all tasks',
                  isDark: widget.isDark,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const TasksScreen()),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: widget.isDark
                ? const Color(0xFF343945)
                : const Color(0xFFEDE9E0),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFCDAF56)),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _StatusChip(
              label: 'Pending $pending',
              color: const Color(0xFF4ECDC4),
            ),
            const SizedBox(width: 8),
            _StatusChip(
              label: 'Completed $completed',
              color: const Color(0xFF7BD88F),
            ),
            if (overdue > 0) ...[
              const SizedBox(width: 8),
              _StatusChip(
                label: 'Overdue $overdue',
                color: const Color(0xFFFF6B6B),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        if (filtered.isEmpty)
          _buildEmptyState(context)
        else
          Column(
            children: filtered
                .take(4)
                .map(
                  (task) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Dismissible(
                      key: ValueKey('task_${task.id}'),
                      background: _TaskSwipeBackground(
                        icon: task.status == 'completed' ? Icons.undo_rounded : Icons.check_circle_rounded,
                        label: task.status == 'completed' ? 'Undo' : 'Done',
                        color: const Color(0xFF4CAF50),
                        isDark: widget.isDark,
                        alignRight: false,
                      ),
                      secondaryBackground: _TaskSwipeBackground(
                        icon: Icons.delete_rounded,
                        label: 'Delete',
                        color: const Color(0xFFFF6B6B),
                        isDark: widget.isDark,
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
                          ref.invalidate(tasksForDateProvider(_today));
                          return false;
                        }
                        if (direction == DismissDirection.endToStart) {
                          // Swipe left - delete
                          await ref.read(taskNotifierProvider.notifier).deleteTask(task.id);
                          return true;
                        }
                        return false;
                      },
                      child: _buildTaskTile(context, task),
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  List<Task> _filteredTasks(List<Task> tasks) {
    final filtered = tasks.where((task) {
      if (task.status == 'completed' && !_showCompleted) return false;
      if (task.status == 'postponed' && !_showPostponed) return false;
      if (task.status == 'not_done' && !_showNotDone) return false;
      return true;
    }).toList();

    filtered.sort((a, b) {
      final aDate = DateTime(
        a.dueDate.year,
        a.dueDate.month,
        a.dueDate.day,
        a.dueTimeHour ?? 23,
        a.dueTimeMinute ?? 59,
      );
      final bDate = DateTime(
        b.dueDate.year,
        b.dueDate.month,
        b.dueDate.day,
        b.dueTimeHour ?? 23,
        b.dueTimeMinute ?? 59,
      );
      return aDate.compareTo(bDate);
    });

    return filtered;
  }

  Widget _buildTaskTile(BuildContext context, Task task) {
    final icon = task.iconCodePoint != null
        ? IconData(
            task.iconCodePoint!,
            fontFamily: task.iconFontFamily,
            fontPackage: task.iconFontPackage,
          )
        : Icons.check_circle_outline_rounded;

    final statusColor = _statusColor(task);
    final hasTime = task.dueTimeHour != null && task.dueTimeMinute != null;
    final timeLabel = hasTime
        ? TimeOfDay(hour: task.dueTimeHour!, minute: task.dueTimeMinute!).format(context)
        : 'All day';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          TaskDetailModal.show(
            context,
            task: task,
            onTaskUpdated: () {
              ref.invalidate(tasksForDateProvider(_today));
            },
          );
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: widget.isDark ? const Color(0xFF1F232B) : const Color(0xFFFDFBF6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isDark
                  ? const Color(0xFF343945)
                  : const Color(0xFFE0D8CB),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: widget.isDark
                        ? [statusColor.withOpacity(0.18), statusColor.withOpacity(0.28)]
                        : [statusColor.withOpacity(0.12), statusColor.withOpacity(0.18)],
                  ),
                ),
                child: Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        icon,
                        color: statusColor,
                        size: 22,
                      ),
                      if (task.isRoutineTask)
                        Positioned(
                          right: -4,
                          bottom: -4,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: widget.isDark ? const Color(0xFF1F232B) : const Color(0xFFFDFBF6),
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
                ),
              ),
              const SizedBox(width: 12),
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
                                  fontWeight: FontWeight.w700,
                                  color: task.status == 'completed'
                                      ? const Color(0xFF4CAF50)
                                      : (widget.isDark
                                          ? const Color(0xFFF8F8F8)
                                          : const Color(0xFF1E1E1E)),
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
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _SmallChip(
                          label: timeLabel,
                          color: statusColor.withOpacity(0.14),
                          textColor: statusColor,
                        ),
                        if (task.hasRecurrence)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Icon(
                              Icons.repeat_rounded,
                              size: 14,
                              color: const Color(0xFFCDAF56).withOpacity(0.8),
                            ),
                          ),
                        _SmallChip(
                          label: task.priority ?? 'Medium',
                          color: const Color(0xFF3A3F4A).withOpacity(widget.isDark ? 0.38 : 0.12),
                          textColor: widget.isDark
                              ? const Color(0xFFF1F1F1)
                              : const Color(0xFF444444),
                        ),
                        if (task.tags != null && task.tags!.isNotEmpty)
                          _SmallChip(
                            label: '#${task.tags!.first}',
                            color: const Color(0xFFCDAF56).withOpacity(0.16),
                            textColor: const Color(0xFFCDAF56),
                          ),
                      ],
                    ),
                    // Subtask Progress Indicator
                    if (task.subtasks != null && task.subtasks!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.checklist_rounded,
                            size: 12,
                            color: widget.isDark
                                ? const Color(0xFFBDBDBD)
                                : const Color(0xFF6E6E6E),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${(task.subtaskProgress * 100).toInt()}%',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: task.subtaskProgress == 1.0
                                      ? Colors.green
                                      : const Color(0xFFCDAF56),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: task.subtaskProgress,
                                backgroundColor: widget.isDark
                                    ? Colors.white.withOpacity(0.1)
                                    : Colors.grey.withOpacity(0.2),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  task.subtaskProgress == 1.0
                                      ? Colors.green
                                      : const Color(0xFFCDAF56),
                                ),
                                minHeight: 3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _StatusDot(color: statusColor),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(Task task) {
    switch (task.status) {
      case 'completed':
        return const Color(0xFF7BD88F);
      case 'postponed':
        return const Color(0xFFFFB347);
      case 'not_done':
        return const Color(0xFFFF6B6B);
      default:
        return task.isOverdue ? const Color(0xFFFF6B6B) : const Color(0xFF4ECDC4);
    }
  }

  void _pushWidgetUpdate(List<Task> tasks, int pending, int completed, int overdue) {
    final ids = tasks.take(3).map((t) => t.id).join('|');
    final snapshot = '$pending|$completed|$overdue|$ids';
    if (snapshot == _lastWidgetSnapshot) return;
    _lastWidgetSnapshot = snapshot;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      updateTodayHomeWidget(tasks: tasks);
    });
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1F232B) : const Color(0xFFFDFBF6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isDark
              ? const Color(0xFF343945)
              : const Color(0xFFE0D8CB),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.sentiment_satisfied_alt_rounded,
            color: widget.isDark ? const Color(0xFFCDAF56) : const Color(0xFFB68D2C),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'You are all set for today. Add a new task?',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: widget.isDark
                        ? const Color(0xFFDFDFDF)
                        : const Color(0xFF4A4A4A),
                  ),
            ),
          ),
          TextButton(
            onPressed: () {
              context.pushNamed('add-task');
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFCDAF56),
            ),
            child: const Text('Add Task'),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Colors.redAccent.shade200,
            ),
            const SizedBox(width: 8),
            Text(
              'Could not load today\'s tasks',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: widget.isDark
                        ? const Color(0xFFDFDFDF)
                        : const Color(0xFF4A4A4A),
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () {
            ref.refresh(taskNotifierProvider);
          },
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Retry'),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFCDAF56),
          ),
        ),
      ],
    );
  }

  void _openSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.isDark ? const Color(0xFF1F232B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 50,
                      height: 4,
                      decoration: BoxDecoration(
                        color: widget.isDark
                            ? const Color(0xFF3A3F4A)
                            : const Color(0xFFE0D8CB),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Today widget settings',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: widget.isDark
                                    ? const Color(0xFFF8F8F8)
                                    : const Color(0xFF1E1E1E),
                              ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          color: widget.isDark ? const Color(0xFFBDBDBD) : const Color(0xFF6E6E6E),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _SettingSwitch(
                      label: 'Show completed',
                      value: _showCompleted,
                      onChanged: (value) {
                        setSheetState(() => _showCompleted = value);
                        setState(() {});
                      },
                      isDark: widget.isDark,
                    ),
                    const SizedBox(height: 6),
                    _SettingSwitch(
                      label: 'Show postponed',
                      value: _showPostponed,
                      onChanged: (value) {
                        setSheetState(() => _showPostponed = value);
                        setState(() {});
                      },
                      isDark: widget.isDark,
                    ),
                    const SizedBox(height: 6),
                    _SettingSwitch(
                      label: 'Show not done',
                      value: _showNotDone,
                      onChanged: (value) {
                        setSheetState(() => _showNotDone = value);
                        setState(() {});
                      },
                      isDark: widget.isDark,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const TasksScreen()),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: const Color(0xFFCDAF56).withOpacity(0.6)),
                              foregroundColor: const Color(0xFFCDAF56),
                            ),
                            icon: const Icon(Icons.view_agenda_rounded, size: 18),
                            label: const Text('View all'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const TaskSettingsScreen()),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFCDAF56),
                              foregroundColor: widget.isDark ? Colors.black : Colors.white,
                            ),
                            icon: const Icon(Icons.settings_suggest_rounded, size: 18),
                            label: const Text('Open settings'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          context.pushNamed('add-task');
                        },
                        icon: const Icon(Icons.add_task_rounded, size: 18),
                        label: const Text('Add a task'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFCDAF56),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
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

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
      ),
    );
  }
}

class _IconPill extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isDark;

  const _IconPill({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: isDark ? const Color(0xFF2D3139) : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(
              icon,
              size: 20,
              color: const Color(0xFFCDAF56),
            ),
          ),
        ),
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;

  const _SmallChip({
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final Color color;

  const _StatusDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _SettingSwitch extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isDark;

  const _SettingSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF262B33) : const Color(0xFFF7F2E9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF343945) : const Color(0xFFE0D8CB),
        ),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFFCDAF56),
        title: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFF1F1F1) : const Color(0xFF2C2C2C),
              ),
        ),
      ),
    );
  }
}

/// Stat Item Widget - Clean design with gold accent
class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          color: const Color(0xFFCDAF56), // Gold accent always
          size: 28,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: isDark
              ? const Color(0xFFFFFFFF)
              : const Color(0xFF1E1E1E),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 12,
            color: isDark
              ? const Color(0xFFBDBDBD)
              : const Color(0xFF6E6E6E),
          ),
        ),
      ],
    );
  }
}

/// Quick Action Button - Outline style with gold accent
class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
          ? const Color(0xFF2D3139) // Dark gray
          : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFCDAF56), // Gold border
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: const Color(0xFFCDAF56).withOpacity(0.2),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: const Color(0xFFCDAF56), // Gold icon
                  size: 24,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark
                        ? const Color(0xFFFFFFFF)
                        : const Color(0xFF1E1E1E),
                    ),
                    overflow: TextOverflow.ellipsis,
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
