import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/dark_gradient.dart';
import '../../../../data/models/task.dart';
import '../providers/task_providers.dart';
import '../providers/category_providers.dart';
import '../widgets/task_detail_modal.dart';
import 'add_task_screen.dart';

/// Filter type for routines
enum RoutineFilter { all, active, inactive }

/// Routines Screen - View all routine tasks with their history
class RoutinesScreen extends ConsumerStatefulWidget {
  const RoutinesScreen({super.key});

  @override
  ConsumerState<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends ConsumerState<RoutinesScreen> {
  RoutineFilter _selectedFilter = RoutineFilter.active;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final routinesAsync = ref.watch(allRoutinesProvider);

    return Scaffold(
      body: isDark
          ? DarkGradient.wrap(child: _buildContent(context, isDark, routinesAsync))
          : _buildContent(context, isDark, routinesAsync),
    );
  }

  List<Task> _filterRoutines(List<Task> routines) {
    switch (_selectedFilter) {
      case RoutineFilter.active:
        return routines.where((r) => r.isRoutineActive).toList();
      case RoutineFilter.inactive:
        return routines.where((r) => !r.isRoutineActive).toList();
      case RoutineFilter.all:
        return routines;
    }
  }

  Widget _buildContent(BuildContext context, bool isDark, AsyncValue<List<Task>> routinesAsync) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Routines'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
          onPressed: () => context.pushNamed('add-task'),
            tooltip: 'Add New Routine',
          ),
        ],
      ),
      body: SafeArea(
        child: routinesAsync.when(
          data: (routines) {
            final filteredRoutines = _filterRoutines(routines);
            if (routines.isEmpty) {
              return _buildEmptyState(context, isDark);
            }
            return _buildRoutinesList(context, isDark, filteredRoutines, routines.length);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Text('Error loading routines: $error'),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF9C27B0).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.loop_rounded,
                size: 64,
                color: const Color(0xFF9C27B0).withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Routines Yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Routines are tasks you do regularly, like haircuts, '
              'dentist visits, or car maintenance. Create a task and '
              'enable "Routine Mode" to track them here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
          onPressed: () => context.pushNamed('add-task'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create Routine'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9C27B0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoutinesList(BuildContext context, bool isDark, List<Task> routines, int totalCount) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      itemCount: routines.length + 1, // +1 for header
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildHeader(context, isDark, routines.length, totalCount);
        }
        
        final routine = routines[index - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _RoutineCard(
            routine: routine,
            isDark: isDark,
            onTap: () {
              TaskDetailModal.show(
                context,
                task: routine,
                onTaskUpdated: () {
                  ref.invalidate(allRoutinesProvider);
                },
              );
            },
            onToggleActive: () async {
              final updatedTask = routine.copyWith(
                isRoutineActive: !routine.isRoutineActive,
              );
              await ref.read(taskNotifierProvider.notifier).updateTask(updatedTask);
            },
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark, int count, int totalCount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        children: [
          // Main header card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFCDAF56).withOpacity(isDark ? 0.2 : 0.12),
                  const Color(0xFFCDAF56).withOpacity(isDark ? 0.1 : 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFCDAF56).withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCDAF56).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.loop_rounded,
                    color: Color(0xFFCDAF56),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Routines',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$count of $totalCount routine${totalCount == 1 ? '' : 's'}',
                        style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Filter chips
          Row(
            children: [
              _buildFilterChip(
                label: 'Active',
                icon: Icons.play_circle_outline_rounded,
                isSelected: _selectedFilter == RoutineFilter.active,
                color: const Color(0xFF4CAF50),
                onTap: () => setState(() => _selectedFilter = RoutineFilter.active),
                isDark: isDark,
              ),
              const SizedBox(width: 10),
              _buildFilterChip(
                label: 'Paused',
                icon: Icons.pause_circle_outline_rounded,
                isSelected: _selectedFilter == RoutineFilter.inactive,
                color: Colors.orange,
                onTap: () => setState(() => _selectedFilter = RoutineFilter.inactive),
                isDark: isDark,
              ),
              const SizedBox(width: 10),
              _buildFilterChip(
                label: 'All',
                icon: Icons.all_inclusive_rounded,
                isSelected: _selectedFilter == RoutineFilter.all,
                color: const Color(0xFFCDAF56),
                onTap: () => setState(() => _selectedFilter = RoutineFilter.all),
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected 
                ? color.withOpacity(0.2) 
                : (isDark ? const Color(0xFF2D3139) : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? color : (isDark ? Colors.white54 : Colors.grey),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? color : (isDark ? Colors.white54 : Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Routine Card Widget
class _RoutineCard extends ConsumerWidget {
  final Task routine;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback? onToggleActive;

  const _RoutineCard({
    required this.routine,
    required this.isDark,
    required this.onTap,
    this.onToggleActive,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routineGroupId = routine.effectiveRoutineGroupId;
    final statsAsync = ref.watch(routineStatsProvider(routineGroupId));
    final categoryAsync = routine.categoryId != null
        ? ref.watch(categoryByIdProvider(routine.categoryId!))
        : null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D3139) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF9C27B0).withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  // Icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF9C27B0).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      routine.icon ?? Icons.loop_rounded,
                      color: const Color(0xFF9C27B0),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  
                  // Title & Category
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          routine.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (categoryAsync != null)
                          categoryAsync.when(
                            data: (category) => category != null
                                ? Row(
                                    children: [
                                      Icon(
                                        category.icon ?? Icons.folder_rounded,
                                        size: 12,
                                        color: category.color,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        category.name,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: category.color,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  )
                                : const SizedBox.shrink(),
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                      ],
                    ),
                  ),
                  
                  // Active/Paused Status Badge (Tappable)
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      onToggleActive?.call();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: routine.isRoutineActive
                            ? const Color(0xFF4CAF50).withOpacity(0.15)
                            : Colors.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: routine.isRoutineActive
                              ? const Color(0xFF4CAF50).withOpacity(0.3)
                              : Colors.orange.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            routine.isRoutineActive
                                ? Icons.play_circle_filled_rounded
                                : Icons.pause_circle_filled_rounded,
                            size: 14,
                            color: routine.isRoutineActive
                                ? const Color(0xFF4CAF50)
                                : Colors.orange,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            routine.isRoutineActive ? 'Active' : 'Paused',
                            style: TextStyle(
                              color: routine.isRoutineActive
                                  ? const Color(0xFF4CAF50)
                                  : Colors.orange,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Countdown Progress Bar & Stats
              statsAsync.when(
                data: (stats) {
                  final completed = stats['completed'] as int;
                  final lastCompletedAt = stats['lastCompletedAt'] as DateTime?;
                  final nextScheduledDateTime = stats['nextScheduledDateTime'] as DateTime?;
                  final nextTask = stats['nextTask'] as Task?;
                  final avgInterval = stats['averageInterval'] as double;
                  final hasTime = stats['hasTime'] as bool? ?? false;
                  
                  return Column(
                    children: [
                      // Countdown Progress Bar with next happening date
                      if (nextTask != null && nextScheduledDateTime != null)
                        _buildCountdownProgressBar(
                          context,
                          nextTask,
                          nextScheduledDateTime,
                          hasTime,
                          isDark,
                        ),
                      
                      // No upcoming - Show days since last
                      if (nextTask == null && lastCompletedAt != null)
                        _buildDaysSinceLastBar(context, lastCompletedAt, isDark),
                      
                      const SizedBox(height: 14),
                      
                      // Stats Row
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark 
                              ? Colors.white.withOpacity(0.05) 
                              : Colors.grey.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem(
                              context,
                              Icons.check_circle_rounded,
                              completed.toString(),
                              'Times Done',
                              const Color(0xFF4CAF50),
                              isDark,
                            ),
                            _buildDivider(isDark),
                            _buildStatItem(
                              context,
                              Icons.timeline_rounded,
                              avgInterval > 0 
                                  ? _formatIntervalSmart(avgInterval)
                                  : '-',
                              'Avg Interval',
                              const Color(0xFFCDAF56),
                              isDark,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Countdown Progress Bar - Shows how close we are to the next routine
  /// Uses the Task's routineProgress getter for accurate calculation
  Widget _buildCountdownProgressBar(
    BuildContext context,
    Task nextTask,
    DateTime nextScheduledDateTime,
    bool hasTime,
    bool isDark,
  ) {
    final now = DateTime.now();
    
    // Calculate exact time difference
    final difference = nextScheduledDateTime.difference(now);
    final totalMinutes = difference.inMinutes;
    final totalHours = difference.inHours;
    final totalDays = difference.inDays;
    
    // Check if overdue
    final isOverdue = difference.isNegative;
    final absDifference = isOverdue ? now.difference(nextScheduledDateTime) : difference;
    final absDays = absDifference.inDays;
    final absHours = absDifference.inHours;
    final absMinutes = absDifference.inMinutes;
    
    // Use the Task's routineProgress getter for accurate progress
    final progress = nextTask.routineProgress.clamp(0.0, 1.5);
    final displayProgress = progress > 1.0 ? 1.0 : progress;
    
    // Get the start and due dates for display
    final startDate = nextTask.effectiveProgressStartDate;
    final dueDate = nextTask.dueDate;
    final startLabel = DateFormat('MMM d').format(startDate);
    final dueDateLabel = DateFormat('EEE, MMM d').format(dueDate);
    final dueTimeLabel = hasTime 
        ? DateFormat('h:mm a').format(nextScheduledDateTime)
        : null;
    
    // Check if this task was postponed
    final isPostponed = nextTask.postponeCount > 0;
    
    // Determine urgency color
    Color progressColor;
    Color bgColor;
    String label;
    
    if (isOverdue) {
      progressColor = const Color(0xFFFF6B6B);
      bgColor = const Color(0xFFFF6B6B).withOpacity(0.15);
      label = 'Overdue!';
    } else if (totalHours < 1) {
      progressColor = const Color(0xFFFF6B6B);
      bgColor = const Color(0xFFFF6B6B).withOpacity(0.15);
      label = totalMinutes <= 0 ? "It's time!" : 'Less than 1 hour';
    } else if (totalHours < 24) {
      progressColor = const Color(0xFFFFB347);
      bgColor = const Color(0xFFFFB347).withOpacity(0.15);
      label = isPostponed ? 'Rescheduled - Today' : 'Today';
    } else if (totalDays <= 3) {
      progressColor = const Color(0xFFFFB347);
      bgColor = const Color(0xFFFFB347).withOpacity(0.15);
      label = isPostponed ? 'Rescheduled' : 'Coming up';
    } else if (totalDays <= 7) {
      progressColor = const Color(0xFFCDAF56);
      bgColor = const Color(0xFFCDAF56).withOpacity(0.15);
      label = isPostponed ? 'Rescheduled' : 'This week';
    } else {
      progressColor = const Color(0xFF9C27B0);
      bgColor = const Color(0xFF9C27B0).withOpacity(0.12);
      label = isPostponed ? 'Rescheduled' : 'Scheduled';
    }
    
    // Use Duration directly to avoid triple-counting bug
    final countdownText = _formatCountdownFromDuration(
      difference: absDifference,
      isOverdue: isOverdue,
    );
    
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: progressColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          // Next Happening Date - The main info
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: progressColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isOverdue 
                      ? Icons.warning_rounded 
                      : Icons.event_rounded,
                  color: progressColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dueDateLabel,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (dueTimeLabel != null)
                      Text(
                        dueTimeLabel,
                        style: TextStyle(
                          color: progressColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: progressColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: progressColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    countdownText,
                    style: TextStyle(
                      color: progressColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Date Range Labels
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  startLabel,
                  style: TextStyle(
                    fontSize: 10, 
                    color: isDark ? Colors.white38 : Colors.black38, 
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${(displayProgress * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 10, 
                    color: progressColor, 
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  DateFormat('MMM d').format(dueDate),
                  style: TextStyle(
                    fontSize: 10, 
                    color: isDark ? Colors.white38 : Colors.black38, 
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          
          // Progress Bar
          Container(
            height: 10,
            decoration: BoxDecoration(
              color: isDark 
                  ? Colors.white.withOpacity(0.08) 
                  : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: isOverdue 
                    ? progressColor.withOpacity(0.5) 
                    : progressColor.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Stack(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  height: 8,
                  width: double.infinity,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: displayProgress,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            progressColor.withOpacity(0.7),
                            progressColor,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          if (isOverdue)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Center(
                child: Text(
                  'OVERDUE',
                  style: TextStyle(
                    fontSize: 10, 
                    color: progressColor, 
                    fontWeight: FontWeight.w800, 
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Days Since Last Bar - Shows when no upcoming routine is scheduled
  /// Uses actual completedAt timestamp for accurate calculation
  Widget _buildDaysSinceLastBar(
    BuildContext context,
    DateTime lastCompletedAt,
    bool isDark,
  ) {
    final now = DateTime.now();
    
    // Calculate exact time difference
    final difference = now.difference(lastCompletedAt);
    final totalMinutes = difference.inMinutes;
    final totalHours = difference.inHours;
    final totalDays = difference.inDays;
    
    // Use Duration directly to avoid triple-counting bug
    final timeSinceText = _formatDurationFromDifference(difference);
    
    // Color based on how long ago
    Color accentColor;
    String message;
    
    if (totalMinutes < 60) {
      accentColor = const Color(0xFF4CAF50);
      message = 'Just now';
    } else if (totalHours < 24) {
      accentColor = const Color(0xFF4CAF50);
      message = 'Today';
    } else if (totalDays <= 7) {
      accentColor = const Color(0xFF4CAF50);
      message = 'Recent';
    } else if (totalDays <= 30) {
      accentColor = const Color(0xFFCDAF56);
      message = 'A while ago';
    } else if (totalDays <= 90) {
      accentColor = const Color(0xFFFFB347);
      message = 'Long ago';
    } else {
      accentColor = const Color(0xFFFF6B6B);
      message = 'Very long ago';
    }
    
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accentColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.history_rounded,
              color: accentColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black45,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$timeSinceText ago',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                DateFormat('MMM d, h:mm a').format(lastCompletedAt),
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF9C27B0).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Plan Next →',
                  style: TextStyle(
                    color: Color(0xFF9C27B0),
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    IconData icon,
    String value,
    String label,
    Color color,
    bool isDark,
  ) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white.withOpacity(0.5) : Colors.grey.shade500,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider(bool isDark) {
    return Container(
      width: 1,
      height: 30,
      color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
    );
  }

  /// Countdown formatter from Duration - correctly calculates time
  String _formatCountdownFromDuration({
    required Duration difference,
    required bool isOverdue,
  }) {
    final totalMinutes = difference.inMinutes.abs();
    final totalHours = difference.inHours.abs();
    final totalDays = difference.inDays.abs();
    
    final suffix = isOverdue ? ' overdue' : '';
    
    // Under 1 minute
    if (totalMinutes <= 0) return isOverdue ? 'Overdue!' : 'Now!';
    
    // Under 1 hour - show minutes
    if (totalHours < 1) {
      return '${totalMinutes}m$suffix';
    }
    
    // Under 24 hours - show hours and minutes
    if (totalHours < 24) {
      final remainingMinutes = totalMinutes % 60;
      if (remainingMinutes == 0) {
        return '${totalHours}h$suffix';
      }
      return '${totalHours}h ${remainingMinutes}m$suffix';
    }
    
    // Under 7 days - show days
    if (totalDays < 7) {
      final remainingHours = totalHours % 24;
      if (remainingHours == 0) {
        return '${totalDays}d$suffix';
      }
      return '${totalDays}d ${remainingHours}h$suffix';
    }
    
    // Weeks (7-29 days)
    if (totalDays < 30) {
      final weeks = totalDays ~/ 7;
      final remainingDays = totalDays % 7;
      if (remainingDays == 0) {
        return '${weeks}w$suffix';
      }
      return '${weeks}w ${remainingDays}d$suffix';
    }
    
    // Months (30-364 days)
    if (totalDays < 365) {
      final months = totalDays ~/ 30;
      return '${months}mo$suffix';
    }
    
    // Years (365+ days)
    final years = totalDays ~/ 365;
    return '${years}y$suffix';
  }

  /// Duration formatter from Duration object - correctly calculates time
  String _formatDurationFromDifference(Duration difference) {
    final totalMinutes = difference.inMinutes.abs();
    final totalHours = difference.inHours.abs();
    final totalDays = difference.inDays.abs();
    
    // Just now (under 1 minute)
    if (totalMinutes <= 0) return 'just now';
    
    // Under 1 hour - show exact minutes
    if (totalMinutes < 60) {
      return '${totalMinutes}m ago';
    }
    
    // Under 24 hours - show hours
    if (totalHours < 24) {
      final remainingMinutes = totalMinutes % 60;
      if (remainingMinutes == 0) {
        return '${totalHours}h ago';
      }
      return '${totalHours}h ${remainingMinutes}m ago';
    }
    
    // Under 7 days - show days
    if (totalDays < 7) {
      final remainingHours = totalHours % 24;
      if (remainingHours == 0) {
        return '${totalDays}d ago';
      }
      return '${totalDays}d ${remainingHours}h ago';
    }
    
    // Weeks (7-29 days)
    if (totalDays < 30) {
      final weeks = totalDays ~/ 7;
      final remainingDays = totalDays % 7;
      if (remainingDays == 0) {
        return '${weeks}w ago';
      }
      return '${weeks}w ${remainingDays}d ago';
    }
    
    // Months (30-364 days)
    if (totalDays < 365) {
      final months = totalDays ~/ 30;
      return '${months}mo ago';
    }
    
    // Years (365+ days)
    final years = totalDays ~/ 365;
    return '${years}y ago';
  }

  /// Format interval for average display
  String _formatIntervalSmart(double avgDays) {
    final days = avgDays.round();
    if (days == 0) return '-';
    if (days == 1) return '1 day';
    if (days < 7) return '$days days';
    if (days == 7) return '1 week';
    if (days < 14) return '~1 week';
    if (days < 30) return '~${(days / 7).round()} weeks';
    if (days < 45) return '~1 month';
    if (days < 365) return '~${(days / 30).round()} months';
    return '~${(days / 365).round()} year${days >= 730 ? 's' : ''}';
  }
}
