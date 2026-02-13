import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/notifications/notifications.dart';
import '../../../habits/data/models/habit.dart';
import '../../../habits/data/repositories/habit_repository.dart';
import '../../../habits/presentation/screens/create_habit_screen.dart';
import 'scheduled_notification_detail_sheet.dart';

/// Section showing Habit scheduled notifications grouped by habit.
/// Used in HubHabitModulePage.
class HabitScheduledSection extends StatelessWidget {
  final NotificationHub hub;
  final bool isDark;
  final VoidCallback? onDeleted;
  final int? refreshKey;

  const HabitScheduledSection({
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
        NotificationHubModuleIds.habit,
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
                  Icons.auto_awesome_rounded,
                  size: 40,
                  color: isDark ? Colors.white24 : Colors.black26,
                ),
                const SizedBox(height: 12),
                Text(
                  'No scheduled habit reminders',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Add reminders when creating or editing habits',
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

        final grouped = _groupByHabit(notifications);

        return FutureBuilder<Map<String, Habit?>>(
          future: _fetchHabits(grouped.keys.toList()),
          builder: (context, habitSnapshot) {
            final habitMap = habitSnapshot.data ?? {};
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: grouped.entries.map((e) {
                final habit = habitMap[e.key];
                return _HabitGroupCard(
                  habitTitle: habit?.title ?? 'Habit',
                  habitId: e.key,
                  habit: habit,
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

  static Map<String, List<Map<String, dynamic>>> _groupByHabit(
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

  static Future<Map<String, Habit?>> _fetchHabits(List<String> habitIds) async {
    final repo = HabitRepository();
    final result = <String, Habit?>{};
    for (final id in habitIds) {
      if (id == 'unknown') continue;
      result[id] = await repo.getHabitById(id);
    }
    return result;
  }
}

class _HabitGroupCard extends StatefulWidget {
  final String habitTitle;
  final String habitId;
  final Habit? habit;
  final List<Map<String, dynamic>> notifications;
  final bool isDark;
  final NotificationHub hub;
  final VoidCallback? onDeleted;

  const _HabitGroupCard({
    required this.habitTitle,
    required this.habitId,
    required this.habit,
    required this.notifications,
    required this.isDark,
    required this.hub,
    this.onDeleted,
  });

  @override
  State<_HabitGroupCard> createState() => _HabitGroupCardState();
}

class _HabitGroupCardState extends State<_HabitGroupCard> {
  bool _expanded = false;
  static const _habitColor = Colors.deepPurple;

  @override
  Widget build(BuildContext context) {
    final count = widget.notifications.length;

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
                      color: _habitColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: _habitColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.habitTitle,
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
                  if (widget.habit != null)
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, size: 20),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CreateHabitScreen(
                              habit: widget.habit,
                            ),
                          ),
                        );
                      },
                      tooltip: 'Edit habit',
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
                      color: _habitColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.notifications_rounded,
                      color: _habitColor,
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
