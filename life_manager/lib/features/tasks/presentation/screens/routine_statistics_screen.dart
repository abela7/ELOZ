import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/task_reason_providers.dart';
import '../providers/task_type_providers.dart';
import '../../../../data/models/task.dart';
import '../../../../data/models/subtask.dart';
import '../providers/task_providers.dart';
import '../providers/category_providers.dart';
import '../widgets/task_detail_modal.dart';

/// Comprehensive Statistics Screen for Routine Tasks
/// 3 Tabs: Statistics, Calendar, Timeline
class RoutineStatisticsScreen extends ConsumerStatefulWidget {
  final Task routineTask;

  const RoutineStatisticsScreen({
    super.key,
    required this.routineTask,
  });

  @override
  ConsumerState<RoutineStatisticsScreen> createState() => _RoutineStatisticsScreenState();
}

class _RoutineStatisticsScreenState extends ConsumerState<RoutineStatisticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final routineGroupId = widget.routineTask.effectiveRoutineGroupId;
    final routineGroupAsync = ref.watch(routineGroupProvider(routineGroupId));
    final routineStatsAsync = ref.watch(routineStatsProvider(routineGroupId));
    
    // Get category info
    final categoryAsync = widget.routineTask.categoryId != null
        ? ref.watch(categoryByIdProvider(widget.routineTask.categoryId!))
        : null;
    final categoryColor = categoryAsync?.value?.color ?? const Color(0xFFCDAF56); // Default to a gold color instead of purple

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1114) : const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1D24) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white : Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.routineTask.title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              'Routine Statistics',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ],
        ),
        actions: [
          // Plan Next Quick Action
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: categoryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.add_rounded,
                color: categoryColor,
                size: 20,
              ),
            ),
            onPressed: () => _showPlanNextModal(context),
            tooltip: 'Plan Next',
          ),
          // More options menu
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert_rounded,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: isDark ? const Color(0xFF2D3139) : Colors.white,
            onSelected: (value) {
              if (value == 'delete_all') {
                _showDeleteEntireRoutineDialog(context, categoryColor);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'delete_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever_rounded, color: Colors.red[400], size: 20),
                    const SizedBox(width: 12),
                    Text(
                      'Delete Entire Routine',
                      style: TextStyle(color: Colors.red[400], fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: categoryColor,
          indicatorWeight: 3,
          labelColor: categoryColor,
          unselectedLabelColor: isDark ? Colors.white54 : Colors.black45,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          tabs: const [
            Tab(text: 'Statistics'),
            Tab(text: 'Calendar'),
            Tab(text: 'Timeline'),
          ],
        ),
      ),
      body: routineGroupAsync.when(
        data: (tasks) => routineStatsAsync.when(
          data: (stats) => TabBarView(
            controller: _tabController,
            children: [
              _buildStatisticsTab(context, tasks, stats, categoryColor, isDark),
              _buildCalendarTab(context, tasks, categoryColor, isDark),
              _buildTimelineTab(context, tasks, categoryColor, isDark),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  // ==================== STATISTICS TAB ====================
  Widget _buildStatisticsTab(
    BuildContext context,
    List<Task> tasks,
    Map<String, dynamic> stats,
    Color accentColor,
    bool isDark,
  ) {
    final completed = stats['completed'] as int? ?? 0;
    final upcoming = stats['upcoming'] as int? ?? 0;
    final total = stats['total'] as int? ?? 0;
    final avgInterval = stats['averageInterval'] as double? ?? 0;
    final lastCompletedAt = stats['lastCompletedAt'] as DateTime?;
    final nextScheduledDateTime = stats['nextScheduledDateTime'] as DateTime?;

    // Calculate additional stats
    final skipped = tasks.where((t) => t.status == 'not_done').length;
    final completionRate = total > 0 ? (completed / total * 100) : 0.0;
    
    // Calculate streak
    int currentStreak = 0;
    final completedTasks = tasks.where((t) => t.status == 'completed').toList()
      ..sort((a, b) => (b.completedAt ?? b.dueDate).compareTo(a.completedAt ?? a.dueDate));
    for (final task in completedTasks) {
      if (task.status == 'completed') {
        currentStreak++;
      } else {
        break;
      }
    }

    // Points earned
    final totalPoints = tasks.fold<int>(0, (sum, t) => sum + (t.pointsEarned));

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          _buildTabSectionHeader('KEY METRICS', Icons.analytics_rounded, accentColor, isDark),
          const SizedBox(height: 16),

          // Overview Grid (4 items)
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              _buildCompactStatCard(
                icon: Icons.check_circle_rounded,
                label: 'Completed',
                value: '$completed',
                color: const Color(0xFF4CAF50),
                isDark: isDark,
              ),
              _buildCompactStatCard(
                icon: Icons.schedule_rounded,
                label: 'Upcoming',
                value: '$upcoming',
                color: const Color(0xFFCDAF56),
                isDark: isDark,
              ),
              _buildCompactStatCard(
                icon: Icons.skip_next_rounded,
                label: 'Skipped',
                value: '$skipped',
                color: const Color(0xFFFF6B6B),
                isDark: isDark,
              ),
              _buildCompactStatCard(
                icon: Icons.stars_rounded,
                label: 'Points',
                value: '$totalPoints',
                color: accentColor,
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Completion Rate Card (Full Width, Sleeker)
          _buildCompletionRateCard(completionRate, accentColor, isDark),
          const SizedBox(height: 24),

          // Performance Insights
          _buildTabSectionHeader('PERFORMANCE', Icons.insights_rounded, accentColor, isDark),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildCompactInfoCard(
                  icon: Icons.timeline_rounded,
                  label: 'Avg Interval',
                  value: _formatInterval(avgInterval),
                  color: const Color(0xFF00BCD4),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCompactInfoCard(
                  icon: Icons.local_fire_department_rounded,
                  label: 'Current Streak',
                  value: '$currentStreak',
                  color: const Color(0xFFFF5722),
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Schedule Section
          _buildTabSectionHeader('SCHEDULE', Icons.event_note_rounded, accentColor, isDark),
          const SizedBox(height: 16),
          if (lastCompletedAt != null || nextScheduledDateTime != null) ...[
            _buildTimeCard(
              lastCompletedAt: lastCompletedAt,
              nextScheduledDateTime: nextScheduledDateTime,
              isDark: isDark,
            ),
            const SizedBox(height: 24),
          ],

          // Recent Activity
          _buildRecentActivitySection(tasks, isDark),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildTabSectionHeader(String title, IconData icon, Color color, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color.withOpacity(0.7)),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D24) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.15),
          width: 1.5,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: color.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white38 : Colors.black45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionRateCard(double rate, Color accentColor, bool isDark) {
    final rateColor = rate >= 80
        ? const Color(0xFF4CAF50)
        : rate >= 50
            ? const Color(0xFFFFB347)
            : const Color(0xFFFF6B6B);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D24) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: rateColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.donut_large_rounded, color: rateColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Completion Rate',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              Text(
                '${rate.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: rateColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Stack(
            children: [
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              FractionallySizedBox(
                widthFactor: (rate / 100).clamp(0.0, 1.0),
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [rateColor.withOpacity(0.6), rateColor],
                    ),
                    borderRadius: BorderRadius.circular(5),
                    boxShadow: [
                      BoxShadow(
                        color: rateColor.withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D24) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white38 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeCard({
    DateTime? lastCompletedAt,
    DateTime? nextScheduledDateTime,
    required bool isDark,
  }) {
    final now = DateTime.now();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D24) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Column(
        children: [
          if (lastCompletedAt != null)
            _buildTimeRow(
              icon: Icons.history_rounded,
              label: 'Last Completed',
              date: lastCompletedAt,
              relative: _formatRelativeTime(lastCompletedAt, now),
              color: const Color(0xFF4CAF50),
              isDark: isDark,
              showDivider: nextScheduledDateTime != null,
            ),
          if (nextScheduledDateTime != null)
            _buildTimeRow(
              icon: Icons.event_rounded,
              label: 'Next Scheduled',
              date: nextScheduledDateTime,
              relative: _formatCountdown(nextScheduledDateTime, now),
              color: const Color(0xFFCDAF56),
              isDark: isDark,
              isOverdue: nextScheduledDateTime.isBefore(now),
              showDivider: false,
            ),
        ],
      ),
    );
  }

  Widget _buildTimeRow({
    required IconData icon,
    required String label,
    required DateTime date,
    required String relative,
    required Color color,
    required bool isDark,
    bool isOverdue = false,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white38 : Colors.black45,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      relative,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isOverdue ? const Color(0xFFFF6B6B) : (isDark ? Colors.white : Colors.black87),
                      ),
                    ),
                    Text(
                      DateFormat('MMM d, h:mm a').format(date),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white24 : Colors.black38,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: isDark ? Colors.white10 : Colors.black12,
              ),
            ],
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
              height: 1,
            ),
          ),
      ],
    );
  }

  Widget _buildRecentActivitySection(List<Task> tasks, bool isDark) {
    final recentTasks = tasks.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RECENT ACTIVITY',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1D24) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
            ),
          ),
          child: recentTasks.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No activity yet',
                      style: TextStyle(
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ),
                )
              : Column(
                  children: recentTasks.asMap().entries.map((entry) {
                    final task = entry.value;
                    final isLast = entry.key == recentTasks.length - 1;
                    return _buildActivityItem(task, isLast, isDark);
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildActivityItem(Task task, bool isLast, bool isDark) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (task.status) {
      case 'completed':
        statusColor = const Color(0xFF4CAF50);
        statusIcon = Icons.check_circle_rounded;
        statusText = task.completedAt != null
            ? DateFormat('MMM d, yyyy').format(task.completedAt!)
            : DateFormat('MMM d, yyyy').format(task.dueDate);
        break;
      case 'pending':
        statusColor = const Color(0xFFCDAF56);
        statusIcon = Icons.schedule_rounded;
        statusText = 'Scheduled: ${DateFormat('MMM d, yyyy').format(task.dueDate)}';
        break;
      case 'not_done':
        statusColor = const Color(0xFFFF6B6B);
        statusIcon = Icons.cancel_rounded;
        statusText = DateFormat('MMM d, yyyy').format(task.dueDate);
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.circle;
        statusText = DateFormat('MMM d, yyyy').format(task.dueDate);
    }

    return Column(
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(statusIcon, color: statusColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                statusText,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                task.status == 'completed'
                    ? 'Done'
                    : task.status == 'pending'
                        ? 'Upcoming'
                        : 'Skipped',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Divider(
              color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08),
              height: 1,
            ),
          ),
      ],
    );
  }

  // ==================== CALENDAR TAB ====================
  Widget _buildCalendarTab(
    BuildContext context,
    List<Task> tasks,
    Color accentColor,
    bool isDark,
  ) {
    return _RoutineCalendarView(
      tasks: tasks,
      routineTask: widget.routineTask,
      accentColor: accentColor,
      isDark: isDark,
      onTaskTap: (task) => _showTaskOptions(context, task),
    );
  }

  // ==================== TIMELINE TAB ====================
  Widget _buildTimelineTab(
    BuildContext context,
    List<Task> tasks,
    Color accentColor,
    bool isDark,
  ) {
    return _RoutineTimelineView(
      tasks: tasks,
      routineTask: widget.routineTask,
      accentColor: accentColor,
      isDark: isDark,
      onEdit: (task) => _showEditInstanceModal(context, task),
      onDelete: (task) => _deleteTask(context, task),
      onPlanNext: () => _showPlanNextModal(context),
    );
  }

  // ==================== HELPER METHODS ====================
  String _formatInterval(double days) {
    if (days == 0) return '-';
    if (days < 1) return '< 1 day';
    if (days < 7) return '${days.round()} days';
    if (days < 30) return '${(days / 7).round()} weeks';
    if (days < 365) return '${(days / 30).round()} months';
    return '${(days / 365).round()} years';
  }

  String _formatRelativeTime(DateTime date, DateTime now) {
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).round()} weeks ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).round()} months ago';
    return '${(diff.inDays / 365).round()} years ago';
  }

  String _formatCountdown(DateTime date, DateTime now) {
    final diff = date.difference(now);
    if (diff.isNegative) {
      final absDiff = now.difference(date);
      if (absDiff.inDays == 0) return 'Overdue today';
      return 'Overdue by ${absDiff.inDays} days';
    }
    if (diff.inMinutes < 60) return 'In ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'In ${diff.inHours} hours';
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Tomorrow';
    if (diff.inDays < 7) return 'In ${diff.inDays} days';
    if (diff.inDays < 30) return 'In ${(diff.inDays / 7).round()} weeks';
    return 'In ${(diff.inDays / 30).round()} months';
  }

  void _showPlanNextModal(BuildContext context) {
    // Get category info from the build method's scope or recalculate
    final categoryAsync = widget.routineTask.categoryId != null
        ? ref.read(categoryByIdProvider(widget.routineTask.categoryId!))
        : null;
    final accentColor = categoryAsync?.value?.color ?? const Color(0xFFCDAF56);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PlanNextRoutineModalContent(
        task: widget.routineTask,
        accentColor: accentColor,
        onTaskUpdated: () {
          ref.invalidate(routineGroupProvider(widget.routineTask.effectiveRoutineGroupId));
        },
      ),
    );
  }

  void _showEditInstanceModal(BuildContext context, Task task) {
    final categoryAsync = widget.routineTask.categoryId != null
        ? ref.read(categoryByIdProvider(widget.routineTask.categoryId!))
        : null;
    final accentColor = categoryAsync?.value?.color ?? const Color(0xFFCDAF56);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditRoutineInstanceModal(
        task: task,
        accentColor: accentColor,
        onUpdated: () {
          ref.invalidate(routineGroupProvider(widget.routineTask.effectiveRoutineGroupId));
        },
      ),
    );
  }

  void _showTaskOptions(BuildContext context, Task task) {
    TaskDetailModal.show(
      context,
      task: task,
      onTaskUpdated: () {
        ref.invalidate(routineGroupProvider(widget.routineTask.effectiveRoutineGroupId));
      },
    );
  }

  Future<void> _deleteTask(BuildContext context, Task task) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final instanceCount = _getRoutineInstanceCount();
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
                // Option 1: Delete this instance only
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
                    ref.invalidate(routineGroupProvider(widget.routineTask.effectiveRoutineGroupId));
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: const Text('Routine instance deleted'), backgroundColor: const Color(0xFF64748B), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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
                    if (confirmed == true && mounted) {
                      final routineGroupId = widget.routineTask.effectiveRoutineGroupId;
                      final deletedCount = await ref.read(taskNotifierProvider.notifier).deleteRoutineSeries(routineGroupId);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Routine deleted ($deletedCount instances removed)'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        );
                        // Close the statistics screen since the routine is deleted
                        Navigator.of(context).pop();
                      }
                    }
                  },
                ),
                const SizedBox(height: 16),
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
      ),
    );
  }

  int _getRoutineInstanceCount() {
    final tasksAsync = ref.read(taskNotifierProvider);
    int count = 0;
    tasksAsync.whenData((tasks) {
      final groupId = widget.routineTask.effectiveRoutineGroupId;
      count = tasks.where((t) => t.id == groupId || t.routineGroupId == groupId).length;
    });
    return count;
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

  Future<bool?> _showDangerConfirmDialog(BuildContext context, bool isDark, String title, String message) {
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

  void _showDeleteEntireRoutineDialog(BuildContext context, Color accentColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF3D4251) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.red[400], size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Delete Entire Routine?',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will permanently delete:',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _buildDeleteWarningItem(Icons.loop_rounded, 'The routine "${widget.routineTask.title}"', isDark),
            const SizedBox(height: 8),
            _buildDeleteWarningItem(Icons.history_rounded, 'All past occurrences & history', isDark),
            const SizedBox(height: 8),
            _buildDeleteWarningItem(Icons.event_rounded, 'All planned future instances', isDark),
            const SizedBox(height: 8),
            _buildDeleteWarningItem(Icons.analytics_rounded, 'All statistics & tracking data', isDark),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Colors.red[400], size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone!',
                      style: TextStyle(
                        color: Colors.red[400],
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _performDeleteEntireRoutine(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.delete_forever_rounded, size: 18),
            label: const Text('Delete All'),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteWarningItem(IconData icon, String text, bool isDark) {
    return Row(
      children: [
        Icon(icon, color: Colors.red[400], size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black87,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _performDeleteEntireRoutine(BuildContext context) async {
    final routineGroupId = widget.routineTask.effectiveRoutineGroupId;
    
    final deletedCount = await ref.read(taskNotifierProvider.notifier).deleteRoutineSeries(routineGroupId);
    
    if (mounted) {
      // Navigate back since the routine no longer exists
      Navigator.of(context).pop();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Routine deleted! ($deletedCount instances removed)'),
              ),
            ],
          ),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }
}

// ==================== CALENDAR VIEW ====================
class _RoutineCalendarView extends StatefulWidget {
  final List<Task> tasks;
  final Task routineTask;
  final Color accentColor;
  final bool isDark;
  final Function(Task) onTaskTap;

  const _RoutineCalendarView({
    required this.tasks,
    required this.routineTask,
    required this.accentColor,
    required this.isDark,
    required this.onTaskTap,
  });

  @override
  State<_RoutineCalendarView> createState() => _RoutineCalendarViewState();
}

class _RoutineCalendarViewState extends State<_RoutineCalendarView> {
  late DateTime _focusedMonth;

  @override
  void initState() {
    super.initState();
    _focusedMonth = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final firstDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final lastDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    final startWeekday = firstDayOfMonth.weekday % 7;

    // Create map of tasks by date
    final tasksByDate = <DateTime, List<Task>>{};
    for (final task in widget.tasks) {
      final dateKey = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
      tasksByDate.putIfAbsent(dateKey, () => []).add(task);
    }

    // Count stats for this month
    int monthCompleted = 0;
    int monthSkipped = 0;
    int monthUpcoming = 0;
    for (final task in widget.tasks) {
      if (task.dueDate.month == _focusedMonth.month && task.dueDate.year == _focusedMonth.year) {
        if (task.status == 'completed') {
          monthCompleted++;
        } else if (task.status == 'not_done') {
          monthSkipped++;
        } else if (task.status == 'pending') {
          monthUpcoming++;
        }
      }
    }

    return Column(
      children: [
        // Header
        _buildCalendarHeader(),
        const SizedBox(height: 12),

        // Legend
        _buildLegend(),
        const SizedBox(height: 8),

        // Weekday headers
        _buildWeekdayHeaders(),
        const SizedBox(height: 8),

        // Calendar grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: 42,
            itemBuilder: (context, index) {
              final dayOffset = index - startWeekday;
              if (dayOffset < 0 || dayOffset >= daysInMonth) {
                return const SizedBox.shrink();
              }

              final date = DateTime(_focusedMonth.year, _focusedMonth.month, dayOffset + 1);
              final dateKey = DateTime(date.year, date.month, date.day);
              final dayTasks = tasksByDate[dateKey] ?? [];

              return _buildDayCell(date, dayTasks);
            },
          ),
        ),

        // Month stats
        _buildMonthStats(monthCompleted, monthSkipped, monthUpcoming),
      ],
    );
  }

  Widget _buildCalendarHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildNavButton(Icons.chevron_left_rounded, () {
            setState(() {
              _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
            });
          }),
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
          _buildNavButton(Icons.chevron_right_rounded, () {
            setState(() {
              _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
            });
          }),
        ],
      ),
    );
  }

  Widget _buildNavButton(IconData icon, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: widget.isDark ? Colors.white70 : Colors.black54),
      ),
    );
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLegendItem(const Color(0xFF4CAF50), 'Done'),
          const SizedBox(width: 20),
          _buildLegendItem(const Color(0xFFCDAF56), 'Upcoming'),
          const SizedBox(width: 20),
          _buildLegendItem(const Color(0xFFFF6B6B), 'Skipped'),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withOpacity(0.3),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color, width: 2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: widget.isDark ? Colors.white54 : Colors.black45,
          ),
        ),
      ],
    );
  }

  Widget _buildWeekdayHeaders() {
    const weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: weekdays.map((day) => SizedBox(
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
        )).toList(),
      ),
    );
  }

  Widget _buildDayCell(DateTime date, List<Task> dayTasks) {
    final now = DateTime.now();
    final isToday = date.day == now.day && date.month == now.month && date.year == now.year;
    final isFuture = date.isAfter(now);

    Color? bgColor;
    Color? borderColor;
    Color textColor = widget.isDark ? Colors.white54 : Colors.black54;

    if (dayTasks.isNotEmpty) {
      final task = dayTasks.first;
      switch (task.status) {
        case 'completed':
          bgColor = const Color(0xFF4CAF50).withOpacity(0.15);
          borderColor = const Color(0xFF4CAF50);
          textColor = widget.isDark ? Colors.white : const Color(0xFF2E7D32);
          break;
        case 'pending':
          bgColor = const Color(0xFFCDAF56).withOpacity(0.15);
          borderColor = const Color(0xFFCDAF56);
          textColor = widget.isDark ? Colors.white : const Color(0xFF8D6E3F);
          break;
        case 'not_done':
          bgColor = const Color(0xFFFF6B6B).withOpacity(0.15);
          borderColor = const Color(0xFFFF6B6B);
          textColor = widget.isDark ? Colors.white : const Color(0xFFC62828);
          break;
      }
    }

    return GestureDetector(
      onTap: dayTasks.isNotEmpty ? () => widget.onTaskTap(dayTasks.first) : null,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor ?? (widget.isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isToday
                ? widget.accentColor
                : (borderColor ?? (widget.isDark ? Colors.white.withOpacity(0.08) : Colors.transparent)),
            width: isToday ? 2.5 : (borderColor != null ? 2 : 1),
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: dayTasks.isNotEmpty ? FontWeight.w800 : FontWeight.w600,
                  color: isFuture && dayTasks.isEmpty
                      ? (widget.isDark ? Colors.white24 : Colors.black26)
                      : textColor,
                ),
              ),
              if (dayTasks.isNotEmpty)
                Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    color: borderColor,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthStats(int completed, int skipped, int upcoming) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            widget.accentColor.withOpacity(0.1),
            widget.accentColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.accentColor.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMonthStatItem('$completed', 'Done', const Color(0xFF4CAF50)),
          Container(width: 1, height: 40, color: widget.isDark ? Colors.white12 : Colors.black12),
          _buildMonthStatItem('$upcoming', 'Upcoming', const Color(0xFFCDAF56)),
          Container(width: 1, height: 40, color: widget.isDark ? Colors.white12 : Colors.black12),
          _buildMonthStatItem('$skipped', 'Skipped', const Color(0xFFFF6B6B)),
        ],
      ),
    );
  }

  Widget _buildMonthStatItem(String value, String label, Color color) {
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
            color: widget.isDark ? Colors.white54 : Colors.black45,
          ),
        ),
      ],
    );
  }
}

// ==================== TIMELINE VIEW ====================
class _RoutineTimelineView extends StatelessWidget {
  final List<Task> tasks;
  final Task routineTask;
  final Color accentColor;
  final bool isDark;
  final Function(Task) onEdit;
  final Function(Task) onDelete;
  final VoidCallback onPlanNext;

  const _RoutineTimelineView({
    required this.tasks,
    required this.routineTask,
    required this.accentColor,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
    required this.onPlanNext,
  });

  @override
  Widget build(BuildContext context) {
    // Sort tasks chronologically: oldest first (ascending)
    final allTasks = List<Task>.from(tasks)..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    
    final pastTasks = allTasks.where((t) => t.status != 'pending').toList();
    final upcomingTasks = allTasks.where((t) => t.status == 'pending').toList();

    final timelineItems = <_TimelineItem>[];

    // 1. "Routine Created" at the TOP
    timelineItems.add(_TimelineItem(
      type: _TimelineItemType.created,
      date: routineTask.createdAt,
    ));

    // 2. Past activity (Ascending)
    for (final task in pastTasks) {
      timelineItems.add(_TimelineItem(
        type: task.status == 'completed' ? _TimelineItemType.completed : _TimelineItemType.skipped,
        task: task,
        date: task.completedAt ?? task.dueDate,
      ));
    }

    // 3. "Now" Marker
    timelineItems.add(_TimelineItem(
      type: _TimelineItemType.nowMarker,
      date: DateTime.now(),
    ));

    // 4. Upcoming tasks (Ascending)
    for (final task in upcomingTasks) {
      timelineItems.add(_TimelineItem(
        type: _TimelineItemType.upcoming,
        task: task,
        date: task.dueDate,
      ));
    }

    // 5. "Plan Next" at the BOTTOM
    timelineItems.add(_TimelineItem(
      type: _TimelineItemType.planNext,
      date: DateTime.now(),
    ));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      itemCount: timelineItems.length,
      itemBuilder: (context, index) {
        final item = timelineItems[index];
        final isFirst = index == 0;
        final isLast = index == timelineItems.length - 1;

        return _buildTimelineItem(context, item, isFirst, isLast);
      },
    );
  }

  Widget _buildTimelineItem(BuildContext context, _TimelineItem item, bool isFirst, bool isLast) {
    // Determine connector color based on type
    Color connectorColor = isDark ? Colors.white12 : Colors.black12;
    if (item.type == _TimelineItemType.completed) connectorColor = const Color(0xFF4CAF50).withOpacity(0.3);
    if (item.type == _TimelineItemType.skipped) connectorColor = const Color(0xFFFF6B6B).withOpacity(0.3);
    if (item.type == _TimelineItemType.planNext) connectorColor = accentColor.withOpacity(0.3);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline Path (Continuous Line)
          SizedBox(
            width: 32,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                // The vertical line
                if (!isLast)
                  Positioned(
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 2,
                      color: connectorColor,
                    ),
                  ),
                // The Dot/Icon
                Positioned(
                  top: 0,
                  child: _buildTimelineMarker(item),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // The Content Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: _buildItemContent(context, item),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineMarker(_TimelineItem item) {
    switch (item.type) {
      case _TimelineItemType.created:
        return Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1D24) : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: isDark ? Colors.white38 : Colors.black38, width: 2),
          ),
          child: Icon(Icons.flag_rounded, size: 10, color: isDark ? Colors.white38 : Colors.black38),
        );
      case _TimelineItemType.completed:
        return Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: const Color(0xFF4CAF50).withOpacity(0.4), blurRadius: 8)],
          ),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 12),
        );
      case _TimelineItemType.skipped:
        return Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B6B),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: const Color(0xFFFF6B6B).withOpacity(0.4), blurRadius: 8)],
          ),
          child: const Icon(Icons.close_rounded, color: Colors.white, size: 12),
        );
      case _TimelineItemType.nowMarker:
        return Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: accentColor,
            shape: BoxShape.circle,
            border: Border.all(color: isDark ? const Color(0xFF0F1114) : const Color(0xFFF5F6FA), width: 3),
            boxShadow: [BoxShadow(color: accentColor.withOpacity(0.5), blurRadius: 10, spreadRadius: 2)],
          ),
        );
      case _TimelineItemType.upcoming:
        return Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1D24) : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFCDAF56), width: 2),
          ),
          child: Container(
            margin: const EdgeInsets.all(3),
            decoration: const BoxDecoration(color: Color(0xFFCDAF56), shape: BoxShape.circle),
          ),
        );
      case _TimelineItemType.planNext:
        return Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [accentColor, accentColor.withOpacity(0.8)]),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: accentColor.withOpacity(0.4), blurRadius: 10)],
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 16),
        );
    }
  }

  Widget _buildItemContent(BuildContext context, _TimelineItem item) {
    switch (item.type) {
      case _TimelineItemType.created:
        return _buildCreatedCard(item.date);
      case _TimelineItemType.nowMarker:
        return _buildNowBadge();
      case _TimelineItemType.planNext:
        return _buildPlanNextCardEnhanced(context);
      case _TimelineItemType.upcoming:
      case _TimelineItemType.completed:
      case _TimelineItemType.skipped:
        return _buildTaskCardEnhanced(context, item);
    }
  }

  Widget _buildCreatedCard(DateTime date) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Icon(Icons.rocket_launch_rounded, size: 18, color: isDark ? Colors.white38 : Colors.black38),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Routine Created',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: isDark ? Colors.white54 : Colors.black54, letterSpacing: 0.5),
              ),
              Text(
                DateFormat('MMMM d, yyyy').format(date),
                style: TextStyle(fontSize: 11, color: isDark ? Colors.white24 : Colors.black38),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNowBadge() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accentColor.withOpacity(0.3)),
          ),
          child: Text(
            'NOW',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: accentColor),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: accentColor.withOpacity(0.2), thickness: 1)),
      ],
    );
  }

  Widget _buildTaskCardEnhanced(BuildContext context, _TimelineItem item) {
    final task = item.task!;
    final isUpcoming = item.type == _TimelineItemType.upcoming;
    final isCompleted = item.type == _TimelineItemType.completed;
    final now = DateTime.now();
    
    Color statusColor = isCompleted ? const Color(0xFF4CAF50) : (isUpcoming ? const Color(0xFFCDAF56) : const Color(0xFFFF6B6B));

    // Calculate time difference
    // IMPORTANT: Upcoming items must use the task's due *date + time*.
    // If we use date-only (midnight), the UI can incorrectly show
    // things like "9 hours overdue" even when it's still upcoming today.
    final scheduledDateTime = DateTime(
      item.date.year,
      item.date.month,
      item.date.day,
      task.dueTime?.hour ?? 23,
      task.dueTime?.minute ?? 59,
    );

    final timeText = isUpcoming
        ? _formatTimeUntil(scheduledDateTime, now)
        : _formatTimeSince(item.date, now);
    final timeIcon = isUpcoming ? Icons.schedule_rounded : Icons.history_rounded;

    return GestureDetector(
      onTap: isUpcoming ? () => _showCountdownModal(context, task) : null,
      child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D24) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(isDark ? 0.2 : 0.15), width: 1.5),
        boxShadow: [
          if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Date, Status Badge, and Options
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE, MMM d, yyyy').format(item.date),
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87),
                    ),
                    if (task.dueTime != null)
                      Text(
                        DateFormat('h:mm a').format(DateTime(2024, 1, 1, task.dueTime!.hour, task.dueTime!.minute)),
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black45, fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ),
              // Routine Icon Indicator
              if (task.isRoutineTask)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.sync_rounded,
                    size: 14,
                    color: statusColor,
                  ),
                ),
              // Options Menu
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: isDark ? Colors.white38 : Colors.black38,
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: isDark ? const Color(0xFF252A31) : Colors.white,
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_rounded, size: 18, color: isDark ? Colors.white70 : Colors.black54),
                        const SizedBox(width: 10),
                        Text('Edit', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFFF6B6B)),
                        const SizedBox(width: 10),
                        const Text('Delete', style: TextStyle(color: Color(0xFFFF6B6B))),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit(task);
                  } else if (value == 'delete') {
                    onDelete(task);
                  }
                },
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Time Elapsed/Remaining Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(timeIcon, size: 14, color: statusColor),
                    const SizedBox(width: 6),
                    Text(
                      timeText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isCompleted 
                    ? 'DONE' 
                    : (isUpcoming 
                        ? (task.postponeCount > 0 ? 'RESCHEDULED' : 'PLANNED') 
                        : 'SKIPPED'),
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: statusColor, letterSpacing: 0.5),
                ),
              ),
            ],
          ),
          
          // Reason (if skipped)
          if (task.notDoneReason != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 14, color: statusColor.withOpacity(0.7)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      task.notDoneReason!,
                      style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: isDark ? Colors.white54 : Colors.black54),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // Progress Bar for Upcoming Timeline Item
          if (isUpcoming) ...[
            const SizedBox(height: 16),
            Builder(
              builder: (context) {
                // Use the task's routineProgress getter for accurate calculation
                final progress = task.routineProgress.clamp(0.0, 1.5);
                final isOverdue = progress > 1.0;
                final displayProgress = isOverdue ? 1.0 : progress;
                
                // Format the progress start date info
                final startDate = task.effectiveProgressStartDate;
                final startLabel = DateFormat('MMM d').format(startDate);
                final endLabel = DateFormat('MMM d').format(task.dueDate);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date Range Labels
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            startLabel,
                            style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${(displayProgress * 100).toInt()}%',
                            style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            endLabel,
                            style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      height: 12,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isOverdue ? Colors.red.withOpacity(0.5) : statusColor.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Reference Track (Background)
                          Positioned.fill(
                            child: Container(
                              margin: const EdgeInsets.all(1.5),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.black26 : Colors.black.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                          ),
                          // Progress Fill
                          FractionallySizedBox(
                            widthFactor: displayProgress,
                            child: Container(
                              margin: const EdgeInsets.all(1.5),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isOverdue 
                                    ? [Colors.red.withOpacity(0.7), Colors.red]
                                    : [statusColor.withOpacity(0.7), statusColor],
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isOverdue)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Center(
                          child: Text(
                            'OVERDUE',
                            style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.w800, letterSpacing: 1),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
          
          // Tap hint for upcoming
          if (isUpcoming) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.touch_app_rounded, size: 14, color: isDark ? Colors.white24 : Colors.black26),
                const SizedBox(width: 6),
                Text(
                  'Tap for live countdown',
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white24 : Colors.black26, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ],
      ),
    ),
    );
  }

  void _showCountdownModal(BuildContext context, Task task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _LiveCountdownModal(
        task: task,
        accentColor: accentColor,
        isDark: isDark,
      ),
    );
  }

  /// Format time since a past date with smart precision
  /// Examples: "45 minutes ago", "5 hours ago", "14 days ago", "1 month 2 days ago", "2 years 3 months ago"
  String _formatTimeSince(DateTime pastDate, DateTime now) {
    final difference = now.difference(pastDate);
    final totalMinutes = difference.inMinutes;
    final totalHours = difference.inHours;
    final totalDays = difference.inDays;
    
    // Less than 1 hour: show minutes
    if (totalMinutes < 60) {
      if (totalMinutes <= 1) return 'Just now';
      return '$totalMinutes minutes ago';
    }
    
    // Less than 24 hours: show hours
    if (totalHours < 24) {
      return '$totalHours ${totalHours == 1 ? 'hour' : 'hours'} ago';
    }
    
    // Less than 30 days: show days
    if (totalDays < 30) {
      return '$totalDays ${totalDays == 1 ? 'day' : 'days'} ago';
    }
    
    // Less than 12 months: show months and days
    if (totalDays < 365) {
      final months = totalDays ~/ 30;
      final remainingDays = totalDays % 30;
      if (remainingDays == 0) {
        return '$months ${months == 1 ? 'month' : 'months'} ago';
      }
      return '$months ${months == 1 ? 'month' : 'months'} $remainingDays ${remainingDays == 1 ? 'day' : 'days'} ago';
    }
    
    // 12+ months: show years and months
    final years = totalDays ~/ 365;
    final remainingMonths = (totalDays % 365) ~/ 30;
    if (remainingMonths == 0) {
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    }
    return '$years ${years == 1 ? 'year' : 'years'} $remainingMonths ${remainingMonths == 1 ? 'month' : 'months'} ago';
  }

  /// Format time until a future date with smart precision
  String _formatTimeUntil(DateTime futureDate, DateTime now) {
    final difference = futureDate.difference(now);
    final totalMinutes = difference.inMinutes;
    final totalHours = difference.inHours;
    final totalDays = difference.inDays;
    
    // Overdue
    if (difference.isNegative) {
      return _formatTimeSince(futureDate, now).replaceAll(' ago', ' overdue');
    }
    
    // Less than 1 hour
    if (totalMinutes < 60) {
      if (totalMinutes <= 1) return 'Now';
      return 'In $totalMinutes minutes';
    }
    
    // Less than 24 hours
    if (totalHours < 24) {
      return 'In $totalHours ${totalHours == 1 ? 'hour' : 'hours'}';
    }
    
    // Less than 30 days
    if (totalDays < 30) {
      return 'In $totalDays ${totalDays == 1 ? 'day' : 'days'}';
    }
    
    // Less than 12 months
    if (totalDays < 365) {
      final months = totalDays ~/ 30;
      final remainingDays = totalDays % 30;
      if (remainingDays == 0) {
        return 'In $months ${months == 1 ? 'month' : 'months'}';
      }
      return 'In $months ${months == 1 ? 'month' : 'months'} $remainingDays days';
    }
    
    // 12+ months
    final years = totalDays ~/ 365;
    final remainingMonths = (totalDays % 365) ~/ 30;
    if (remainingMonths == 0) {
      return 'In $years ${years == 1 ? 'year' : 'years'}';
    }
    return 'In $years ${years == 1 ? 'year' : 'years'} $remainingMonths months';
  }

  Widget _buildPlanNextCardEnhanced(BuildContext context) {
    return GestureDetector(
      onTap: onPlanNext,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark 
              ? [accentColor.withOpacity(0.2), accentColor.withOpacity(0.1)]
              : [accentColor.withOpacity(0.08), accentColor.withOpacity(0.04)],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: accentColor.withOpacity(0.3), width: 2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.event_available_rounded, color: accentColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Plan Next Routine',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: accentColor),
                  ),
                  Text(
                    'Keep the momentum going!',
                    style: TextStyle(fontSize: 13, color: accentColor.withOpacity(0.8), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: accentColor, size: 18),
          ],
        ),
      ),
    );
  }

}

enum _TimelineItemType {
  planNext,
  upcoming,
  nowMarker,
  completed,
  skipped,
  created,
}

class _TimelineItem {
  final _TimelineItemType type;
  final Task? task;
  final DateTime date;

  _TimelineItem({
    required this.type,
    this.task,
    required this.date,
  });
}

// ==================== PLAN NEXT MODAL ====================
class _PlanNextRoutineModalContent extends ConsumerStatefulWidget {
  final Task task;
  final Color accentColor;
  final VoidCallback? onTaskUpdated;

  const _PlanNextRoutineModalContent({
    required this.task,
    required this.accentColor,
    this.onTaskUpdated,
  });

  @override
  ConsumerState<_PlanNextRoutineModalContent> createState() => _PlanNextRoutineModalContentState();
}

class _PlanNextRoutineModalContentState extends ConsumerState<_PlanNextRoutineModalContent> {
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 14));
  TimeOfDay _selectedTime = TimeOfDay.now();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E2228) : const Color(0xFFF8F9FA);
    final cardColor = isDark ? const Color(0xFF252A31) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1C1E);
    final accentColor = widget.accentColor;
    
    // Get the last completed date from the routine group for accurate progress start
    final routineStatsAsync = ref.watch(routineStatsProvider(widget.task.effectiveRoutineGroupId));
    final lastCompletedAt = routineStatsAsync.valueOrNull?['lastCompletedAt'] as DateTime?;
    
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 24,
        right: 24,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
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
          
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.loop_rounded, color: accentColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Plan Next Routine',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                    Text(
                      widget.task.title,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Quick Date Options
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildQuickDateChip('1 Week', 7, isDark),
              _buildQuickDateChip('2 Weeks', 14, isDark),
              _buildQuickDateChip('1 Month', 30, isDark),
              _buildQuickDateChip('3 Months', 90, isDark),
            ],
          ),
          const SizedBox(height: 20),
          
          // Selected Date Display
          GestureDetector(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
              );
              if (date != null) {
                setState(() => _selectedDate = date);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: accentColor.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_month_rounded, color: accentColor),
                  const SizedBox(width: 12),
                  Text(
                    DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.edit_rounded,
                    size: 18,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          // Time Picker
          GestureDetector(
            onTap: () async {
              final time = await showTimePicker(
                context: context,
                initialTime: _selectedTime,
              );
              if (time != null) {
                setState(() => _selectedTime = time);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.access_time_rounded, color: isDark ? Colors.white54 : Colors.black45),
                  const SizedBox(width: 12),
                  Text(
                    _selectedTime.format(context),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.edit_rounded,
                    size: 18,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () async {
                    final newDueDate = DateTime(
                      _selectedDate.year,
                      _selectedDate.month,
                      _selectedDate.day,
                      _selectedTime.hour,
                      _selectedTime.minute,
                    );
                    
                    // FIXED: Use lastCompletedAt from stats provider so progress
                    // starts from when the LAST routine was actually completed
                    // This ensures consistent progress calculation everywhere
                    final nextTask = widget.task.createNextRoutineInstance(
                      newDueDate: newDueDate,
                      newDueTime: _selectedTime,
                      progressStartDate: lastCompletedAt ?? DateTime.now(),
                    );
                    
                    await ref.read(taskNotifierProvider.notifier).addTask(nextTask);
                    
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              Icon(Icons.loop_rounded, color: Colors.white),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Next "${widget.task.title}" scheduled for ${DateFormat('MMM dd').format(_selectedDate)}',
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: accentColor,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                      widget.onTaskUpdated?.call();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_rounded, size: 18),
                      SizedBox(width: 6),
                      Text('Plan Next', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickDateChip(String label, int days, bool isDark) {
    final targetDate = DateTime.now().add(Duration(days: days));
    final isSelected = _selectedDate.year == targetDate.year &&
        _selectedDate.month == targetDate.month &&
        _selectedDate.day == targetDate.day;
    final accentColor = widget.accentColor;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedDate = targetDate);
        HapticFeedback.lightImpact();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withOpacity(0.15)
              : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? accentColor : Colors.transparent,
            width: isSelected ? 1.5 : 0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? accentColor
                : (isDark ? Colors.white70 : Colors.black54),
          ),
        ),
      ),
    );
  }
}

// ==================== LIVE COUNTDOWN MODAL ====================
class _LiveCountdownModal extends StatefulWidget {
  final Task task;
  final Color accentColor;
  final bool isDark;

  const _LiveCountdownModal({
    required this.task,
    required this.accentColor,
    required this.isDark,
  });

  @override
  State<_LiveCountdownModal> createState() => _LiveCountdownModalState();
}

class _LiveCountdownModalState extends State<_LiveCountdownModal> with SingleTickerProviderStateMixin {
  late Timer _timer;
  late DateTime _targetDate;
  Duration _remaining = Duration.zero;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _targetDate = DateTime(
      widget.task.dueDate.year,
      widget.task.dueDate.month,
      widget.task.dueDate.day,
      widget.task.dueTime?.hour ?? 0,
      widget.task.dueTime?.minute ?? 0,
    );
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateRemaining());
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _updateRemaining() {
    setState(() {
      _remaining = _targetDate.difference(DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDark ? const Color(0xFF0F1114) : const Color(0xFFF5F6FA);
    final cardColor = widget.isDark ? const Color(0xFF1A1D24) : Colors.white;
    final textColor = widget.isDark ? Colors.white : const Color(0xFF1A1C1E);
    
    final isOverdue = _remaining.isNegative;
    final displayRemaining = isOverdue ? Duration.zero - _remaining : _remaining;
    
    // Parse into components
    final years = displayRemaining.inDays ~/ 365;
    final months = (displayRemaining.inDays % 365) ~/ 30;
    final days = displayRemaining.inDays % 30;
    final hours = displayRemaining.inHours % 24;
    final minutes = displayRemaining.inMinutes % 60;
    final seconds = displayRemaining.inSeconds % 60;

    // Calculate progress based on when the task was created/planned to when it's due
    // Progress = (time elapsed since start) / (total time from start to due)
    // Uses the new routineProgress getter from the Task model
    final startDate = widget.task.effectiveProgressStartDate;
    final progress = widget.task.routineProgress.clamp(0.0, 1.5);
    final displayProgress = progress > 1.0 ? 1.0 : progress;
    
    // Calculate remaining percentage for display
    final remainingPercent = ((1.0 - displayProgress) * 100).clamp(0.0, 100.0);

    // Urgency color
    Color urgencyColor;
    if (isOverdue) {
      urgencyColor = const Color(0xFFFF6B6B);
    } else if (displayRemaining.inHours < 24) {
      urgencyColor = const Color(0xFFFF9800);
    } else if (displayRemaining.inDays < 7) {
      urgencyColor = const Color(0xFFCDAF56);
    } else {
      urgencyColor = const Color(0xFF4CAF50);
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
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
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Column(
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [urgencyColor.withOpacity(0.2), urgencyColor.withOpacity(0.1)],
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        isOverdue ? Icons.warning_rounded : Icons.timer_rounded,
                        color: urgencyColor,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isOverdue 
                                ? 'OVERDUE' 
                                : (widget.task.postponeCount > 0 ? 'RESCHEDULED' : 'COUNTDOWN'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              color: urgencyColor,
                            ),
                          ),
                          Text(
                            widget.task.title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close_rounded,
                        color: widget.isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 32),
                
                // Main Countdown Display
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: isOverdue || displayRemaining.inHours < 24 ? _pulseAnimation.value : 1.0,
                      child: child,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          urgencyColor.withOpacity(widget.isDark ? 0.15 : 0.08),
                          urgencyColor.withOpacity(widget.isDark ? 0.08 : 0.03),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: urgencyColor.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        // Time Units Grid
                        _buildCountdownGrid(years, months, days, hours, minutes, seconds, urgencyColor, textColor),
                        
                        const SizedBox(height: 24),
                        
                        // Target Date
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: widget.isDark ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.event_rounded, size: 16, color: urgencyColor),
                                  const SizedBox(width: 8),
                                  Text(
                                    DateFormat('EEE, MMM d, yyyy').format(_targetDate),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: textColor.withOpacity(0.8),
                                    ),
                                  ),
                                ],
                              ),
                              if (widget.task.dueTime != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('h:mm a').format(_targetDate),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: urgencyColor,
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
                
                const SizedBox(height: 28),
                
                // Progress Bar - shows elapsed time from creation to due date
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              'TIME ELAPSED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: widget.isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: urgencyColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${remainingPercent.toStringAsFixed(0)}% left',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: urgencyColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${(displayProgress * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: urgencyColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Show date range
                    Text(
                      'From ${DateFormat('MMM d').format(startDate)} → Due ${DateFormat('MMM d').format(_targetDate)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: widget.isDark ? Colors.white24 : Colors.black26,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 16,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: urgencyColor.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Reference Track (Background)
                          Positioned.fill(
                            child: Container(
                              margin: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: widget.isDark ? Colors.black26 : Colors.black.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                          // Progress Fill
                          FractionallySizedBox(
                            widthFactor: displayProgress,
                            child: Container(
                              margin: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    urgencyColor.withOpacity(0.7),
                                    urgencyColor,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(5),
                                boxShadow: [
                                  BoxShadow(
                                    color: urgencyColor.withOpacity(0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 28),
                
                // Status Message
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: urgencyColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _getStatusIcon(displayRemaining, isOverdue),
                          color: urgencyColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getStatusTitle(displayRemaining, isOverdue),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: textColor,
                              ),
                            ),
                            Text(
                              _getStatusSubtitle(displayRemaining, isOverdue),
                              style: TextStyle(
                                fontSize: 12,
                                color: textColor.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownGrid(int years, int months, int days, int hours, int minutes, int seconds, Color color, Color textColor) {
    final List<Map<String, dynamic>> units = [];
    
    if (years > 0) {
      units.add({'value': years, 'label': 'YRS'});
    }
    if (months > 0 || years > 0) {
      units.add({'value': months, 'label': 'MO'});
    }
    if (days > 0 || months > 0 || years > 0) {
      units.add({'value': days, 'label': 'DAYS'});
    }
    units.add({'value': hours, 'label': 'HRS'});
    units.add({'value': minutes, 'label': 'MIN'});
    units.add({'value': seconds, 'label': 'SEC'});

    // Limit to 6 units max
    final displayUnits = units.take(6).toList();
    final unitCount = displayUnits.length;

    // Use FittedBox to ensure all units fit in one row
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: displayUnits.asMap().entries.map((entry) {
          final index = entry.key;
          final unit = entry.value;
          return Padding(
            padding: EdgeInsets.only(right: index < unitCount - 1 ? 6 : 0),
            child: _buildCountdownUnit(
              unit['value'] as int,
              unit['label'] as String,
              color,
              textColor,
              unitCount: unitCount,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCountdownUnit(int value, String label, Color color, Color textColor, {int unitCount = 4}) {
    // Adjust size based on how many units we're showing
    final double boxWidth = unitCount >= 6 ? 52 : (unitCount >= 5 ? 56 : 64);
    final double fontSize = unitCount >= 6 ? 20 : (unitCount >= 5 ? 22 : 26);
    final double labelSize = unitCount >= 6 ? 7 : 8;
    final double verticalPadding = unitCount >= 6 ? 8 : 12;
    
    return Container(
      width: boxWidth,
      padding: EdgeInsets.symmetric(vertical: verticalPadding, horizontal: 4),
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value.toString().padLeft(2, '0'),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              color: color,
              fontFamily: 'monospace',
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: labelSize,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: textColor.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(Duration remaining, bool isOverdue) {
    if (isOverdue) return Icons.warning_amber_rounded;
    if (remaining.inHours < 1) return Icons.alarm_rounded;
    if (remaining.inHours < 24) return Icons.hourglass_bottom_rounded;
    if (remaining.inDays < 7) return Icons.calendar_today_rounded;
    return Icons.event_available_rounded;
  }

  String _getStatusTitle(Duration remaining, bool isOverdue) {
    if (isOverdue) return 'This routine is overdue!';
    if (remaining.inHours < 1) return 'Almost time!';
    if (remaining.inHours < 24) return 'Coming up today!';
    if (remaining.inDays < 7) return 'This week';
    if (remaining.inDays < 30) return 'Coming up soon';
    return 'Scheduled ahead';
  }

  String _getStatusSubtitle(Duration remaining, bool isOverdue) {
    if (isOverdue) return 'Consider completing or rescheduling it.';
    if (remaining.inHours < 1) return 'Get ready to complete this routine.';
    if (remaining.inHours < 24) return 'Make sure you\'re prepared.';
    if (remaining.inDays < 7) return 'You have time to plan ahead.';
    return 'Plenty of time to prepare.';
  }
}

// ==================== EDIT INSTANCE MODAL ====================
class _EditRoutineInstanceModal extends ConsumerStatefulWidget {
  final Task task;
  final Color accentColor;
  final VoidCallback onUpdated;

  const _EditRoutineInstanceModal({
    required this.task,
    required this.accentColor,
    required this.onUpdated,
  });

  @override
  ConsumerState<_EditRoutineInstanceModal> createState() => _EditRoutineInstanceModalState();
}

class _EditRoutineInstanceModalState extends ConsumerState<_EditRoutineInstanceModal> {
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late String _status;
  String? _selectedReason;
  final TextEditingController _reasonController = TextEditingController();
  late DateTime _progressStartDate; // When the progress bar countdown starts

  @override
  void initState() {
    super.initState();
    final initialDate = widget.task.status == 'completed' 
        ? (widget.task.completedAt ?? widget.task.dueDate)
        : widget.task.dueDate;
    
    _selectedDate = initialDate;
    _selectedTime = TimeOfDay.fromDateTime(initialDate);
    _status = widget.task.status == 'completed' 
        ? 'done' 
        : (widget.task.status == 'not_done' ? 'skipped' : 'planned');
    _selectedReason = widget.task.notDoneReason;
    _reasonController.text = widget.task.notDoneReason ?? '';
    _progressStartDate = widget.task.effectiveProgressStartDate;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _selectProgressStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _progressStartDate,
      firstDate: DateTime(2020),
      lastDate: _selectedDate, // Can't be after the due date
    );
    if (picked != null) {
      setState(() => _progressStartDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E2228) : const Color(0xFFF8F9FA);
    final cardColor = isDark ? const Color(0xFF252A31) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1C1E);
    final subtextColor = isDark ? Colors.white70 : Colors.black54;
    final accentColor = widget.accentColor;
    
    final reasonsAsync = ref.watch(notDoneReasonsProvider);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24,
        right: 24,
        top: 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
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
          const SizedBox(height: 24),
          
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.edit_calendar_rounded, color: accentColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _status == 'planned' ? 'Reschedule Routine' : 'Edit Routine Record',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textColor),
                    ),
                    Text(
                      widget.task.title,
                      style: TextStyle(fontSize: 13, color: subtextColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),

          // Status Selection (only if not planned)
          if (_status != 'planned') ...[
            Text(
              'Status',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: subtextColor, letterSpacing: 0.5),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildStatusChip('done', 'Done', Icons.check_circle_rounded, const Color(0xFF4CAF50)),
                const SizedBox(width: 12),
                _buildStatusChip('skipped', 'Skipped', Icons.skip_next_rounded, const Color(0xFFFF6B6B)),
              ],
            ),
            const SizedBox(height: 24),
          ],

          // Date & Time
          Row(
            children: [
              Expanded(
                flex: 3, // Give more space to date
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _status == 'done' ? 'Date Done' : (_status == 'skipped' ? 'Date Skipped' : 'Due Date'),
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: subtextColor, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: _selectDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 16, color: textColor.withOpacity(0.6)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                DateFormat('MMM d, yyyy').format(_selectedDate),
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2, // Give less space to time
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Time',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: subtextColor, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: _selectTime,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.access_time_rounded, size: 16, color: textColor.withOpacity(0.6)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selectedTime.format(context),
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Progress Start Date (only for upcoming routines)
          if (_status == 'planned') ...[
            const SizedBox(height: 24),
            Text(
              'Progress Start Date',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: subtextColor, letterSpacing: 0.5),
            ),
            const SizedBox(height: 4),
            Text(
              'When the countdown progress bar starts filling up',
              style: TextStyle(fontSize: 11, color: subtextColor.withOpacity(0.7)),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _selectProgressStartDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.play_arrow_rounded, size: 18, color: accentColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              DateFormat('MMM d, yyyy').format(_progressStartDate),
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () => setState(() => _progressStartDate = DateTime.now()),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: accentColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    'Today',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: accentColor),
                  ),
                ),
              ],
            ),
          ],

          if (_status == 'skipped') ...[
            const SizedBox(height: 24),
            Text(
              'Reason for skipping',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: subtextColor, letterSpacing: 0.5),
            ),
            const SizedBox(height: 12),
            reasonsAsync.when(
              data: (reasons) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: reasons.map((r) => ChoiceChip(
                  label: Text(r.text),
                  selected: _selectedReason == r.text,
                  onSelected: (selected) {
                    setState(() {
                      _selectedReason = selected ? r.text : null;
                      if (selected) _reasonController.text = r.text;
                    });
                  },
                )).toList(),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Text('Error loading reasons'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reasonController,
              decoration: InputDecoration(
                hintText: 'Or enter custom reason...',
                filled: true,
                fillColor: cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) => setState(() => _selectedReason = val),
            ),
          ],
          
          const SizedBox(height: 32),

          // Save Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text(
                'Save Changes',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String value, String label, IconData icon, Color color) {
    final isSelected = _status == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _status = value),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.15) : (isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? color : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: isSelected ? color : Colors.grey),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? color : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final newDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final notifier = ref.read(taskNotifierProvider.notifier);
    final wasCompleted = widget.task.status == 'completed';
    final wasSkipped = widget.task.status == 'not_done';
    
    if (_status == 'planned') {
      // When changing back to 'planned', we need to properly reset ALL fields
      // This is essentially an "undo" operation for routines
      if (wasCompleted || wasSkipped) {
        // Use the robust undo system for proper reset
        if (wasCompleted) {
          await notifier.undoTaskComplete(widget.task.id);
        } else {
          await notifier.undoTaskSkip(widget.task.id);
        }
        
        // Check if date/time was changed and update if needed
        final dateTimeChanged = widget.task.dueDate != _selectedDate || 
            widget.task.dueTime?.hour != _selectedTime.hour ||
            widget.task.dueTime?.minute != _selectedTime.minute ||
            widget.task.routineProgressStartDate != _progressStartDate;
        
        if (dateTimeChanged) {
          // Create updated task with new date/time
          // The undo already reset status, so we just update date/time
          final taskWithNewDate = widget.task.copyWith(
            status: 'pending', // Undo sets this
            routineStatus: 'planned', // Undo sets this
            dueDate: _selectedDate,
            dueTime: _selectedTime,
            routineProgressStartDate: _progressStartDate,
          );
          await notifier.updateTask(taskWithNewDate);
        }
      } else {
        // Task was already planned, just update date/time
        final updatedTask = widget.task.copyWith(
          dueDate: _selectedDate,
          dueTime: _selectedTime,
          routineProgressStartDate: _progressStartDate,
        );
        await notifier.updateTask(updatedTask);
      }
    } else if (_status == 'done') {
      // Mark as done with points
      int points = 10;
      if (widget.task.taskTypeId != null) {
        final taskType = await ref.read(taskTypeByIdProvider(widget.task.taskTypeId!).future);
        if (taskType != null) {
          points = taskType.rewardOnDone;
        }
      }
      
      // Reset subtasks to completed if any exist
      List<Subtask>? completedSubtasks;
      if (widget.task.subtasks != null && widget.task.subtasks!.isNotEmpty) {
        completedSubtasks = widget.task.subtasks!.map((s) => s.copyWith(isCompleted: true)).toList();
      }
      
      final updatedTask = widget.task.copyWith(
        status: 'completed',
        routineStatus: 'done',
        completedAt: newDateTime,
        pointsEarned: points,
        dueDate: _selectedDate,
        dueTime: _selectedTime,
        subtasks: completedSubtasks,
      );
      
      // Also clear any notDoneReason if it was previously skipped
      updatedTask.notDoneReason = null;
      
      await notifier.updateTask(updatedTask);
    } else {
      // Skipped
      int penalty = -5;
      if (widget.task.taskTypeId != null) {
        final taskType = await ref.read(taskTypeByIdProvider(widget.task.taskTypeId!).future);
        if (taskType != null) {
          penalty = -taskType.penaltyNotDone;
        }
      }
      
      final updatedTask = widget.task.copyWith(
        status: 'not_done',
        routineStatus: 'skipped',
        notDoneReason: _reasonController.text.isNotEmpty ? _reasonController.text : 'No reason provided',
        pointsEarned: penalty,
        dueDate: _selectedDate,
        dueTime: _selectedTime,
      );
      
      // Clear completedAt if was previously done
      updatedTask.completedAt = null;
      
      await notifier.updateTask(updatedTask);
    }

    widget.onUpdated();
    if (mounted) Navigator.pop(context);
    
    HapticFeedback.mediumImpact();
  }
}
