import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/notifications/notifications.dart';
import '../../../../data/models/task.dart';
import '../../../../data/repositories/task_repository.dart';
import 'scheduled_notification_detail_sheet.dart';

/// Section showing Task scheduled notifications grouped by task.
/// Used in HubTaskModulePage.
class TaskScheduledSection extends StatelessWidget {
  final NotificationHub hub;
  final bool isDark;
  final VoidCallback? onDeleted;
  final int? refreshKey;

  const TaskScheduledSection({
    super.key,
    required this.hub,
    required this.isDark,
    this.onDeleted,
    this.refreshKey,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      key: refreshKey != null ? ValueKey(refreshKey) : null,
      future: hub.getScheduledNotificationsForModule(
        NotificationHubModuleIds.task,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator.adaptive()),
          );
        }

        final notifications = snapshot.data ?? [];

        if (notifications.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1D23) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.06),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.task_alt_rounded,
                  size: 40,
                  color: isDark ? Colors.white24 : Colors.black26,
                ),
                const SizedBox(height: 12),
                Text(
                  'No scheduled task reminders',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Add reminders when creating or editing tasks',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final grouped = _groupByTask(notifications);

        return FutureBuilder<Map<String, Task?>>(
          future: _fetchTasks(grouped.keys.toList()),
          builder: (context, taskSnapshot) {
            final taskMap = taskSnapshot.data ?? {};
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: grouped.entries.map((e) {
                final task = taskMap[e.key];
                return _TaskGroupCard(
                  taskTitle: task?.title ?? 'Task',
                  taskId: e.key,
                  task: task,
                  notifications: e.value,
                  isDark: isDark,
                  hub: hub,
                  onDeleted: onDeleted,
                );
              }).toList(),
            );
          },
        );
      },
    );
  }

  static Map<String, List<Map<String, dynamic>>> _groupByTask(
    List<Map<String, dynamic>> notifications,
  ) {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final n in notifications) {
      final entityId = n['entityId'] as String? ?? '';
      final key = entityId.isEmpty ? 'unknown' : entityId;
      map.putIfAbsent(key, () => []).add(n);
    }
    return map;
  }

  static Future<Map<String, Task?>> _fetchTasks(List<String> taskIds) async {
    final repo = TaskRepository();
    final result = <String, Task?>{};
    for (final id in taskIds) {
      if (id == 'unknown') continue;
      result[id] = await repo.getTaskById(id);
    }
    return result;
  }
}

class _TaskGroupCard extends StatefulWidget {
  final String taskTitle;
  final String taskId;
  final Task? task;
  final List<Map<String, dynamic>> notifications;
  final bool isDark;
  final NotificationHub hub;
  final VoidCallback? onDeleted;

  const _TaskGroupCard({
    required this.taskTitle,
    required this.taskId,
    required this.task,
    required this.notifications,
    required this.isDark,
    required this.hub,
    this.onDeleted,
  });

  @override
  State<_TaskGroupCard> createState() => _TaskGroupCardState();
}

class _TaskGroupCardState extends State<_TaskGroupCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final count = widget.notifications.length;
    const taskColor = Colors.blue;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1A1D23) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.06),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: taskColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.task_alt_rounded,
                      color: taskColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.taskTitle,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: widget.isDark
                                ? Colors.white
                                : Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          count == 1
                              ? '1 reminder scheduled'
                              : '$count reminders scheduled',
                          style: TextStyle(
                            fontSize: 12,
                            color: widget.isDark
                                ? Colors.white54
                                : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.task != null)
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, size: 20),
                      onPressed: () {
                        context.pushNamed(
                          'edit-task',
                          extra: widget.task,
                        );
                      },
                      tooltip: 'Edit task',
                    ),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: widget.isDark ? Colors.white54 : Colors.black54,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: widget.notifications
                    .map((n) => _buildNotificationCard(n))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notif) {
    final title = notif['title'] as String? ?? 'Reminder';
    final body = notif['body'] as String? ?? '';
    final scheduledAt = notif['scheduledAt'] as DateTime?;
    const taskColor = Colors.blue;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          ScheduledNotificationDetailSheet.show(
            context,
            notif: notif,
            hub: widget.hub,
            isDark: Theme.of(context).brightness == Brightness.dark,
            onDeleted: widget.onDeleted,
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.isDark
                ? const Color(0xFF12151A)
                : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isDark
                  ? Colors.white10
                  : Colors.black.withOpacity(0.05),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: taskColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.notifications_rounded,
                      color: taskColor,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color:
                                widget.isDark ? Colors.white : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (body.isNotEmpty)
                          Text(
                            body,
                            style: TextStyle(
                              fontSize: 11,
                              color: widget.isDark
                                  ? Colors.white54
                                  : Colors.black54,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: widget.isDark ? Colors.white38 : Colors.black38,
                  ),
                ],
              ),
              if (scheduledAt != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 12,
                      color: widget.isDark
                          ? Colors.white38
                          : Colors.black38,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('MMM d, h:mm a').format(scheduledAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: widget.isDark
                            ? Colors.white38
                            : Colors.black38,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
