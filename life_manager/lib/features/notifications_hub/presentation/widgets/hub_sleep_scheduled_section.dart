import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/notifications/notifications.dart';
import '../../../sleep/notifications/sleep_notification_contract.dart';
import 'scheduled_notification_detail_sheet.dart';

/// Section showing Sleep scheduled notifications grouped by section.
/// Used in HubSleepModulePage.
class SleepScheduledSection extends StatelessWidget {
  final NotificationHub hub;
  final bool isDark;
  final VoidCallback? onDeleted;
  final int? refreshKey;

  const SleepScheduledSection({
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
        SleepNotificationContract.moduleId,
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
                  Icons.bedtime_rounded,
                  size: 40,
                  color: isDark ? Colors.white24 : Colors.black26,
                ),
                const SizedBox(height: 12),
                Text(
                  'No scheduled sleep reminders',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Add reminders in Sleep → Settings',
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

        final grouped = _groupBySection(notifications);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: grouped
              .map((e) => _SleepGroupCard(
                    sectionName: e.name,
                    sectionIcon: e.icon,
                    notifications: e.notifications,
                    isDark: isDark,
                    hub: hub,
                    onDeleted: onDeleted,
                  ))
              .toList(),
        );
      },
    );
  }

  static List<_SleepGroup> _groupBySection(
    List<Map<String, dynamic>> notifications,
  ) {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final n in notifications) {
      final section = n['section'] as String? ?? 'bedtime';
      final name = _sectionDisplayName(section);
      final icon = _sectionIcon(section);
      final key = section;
      map.putIfAbsent(key, () => []).add(n);
    }
    return map.entries.map((e) {
      final first = e.value.first;
      final section = first['section'] as String? ?? 'bedtime';
      return _SleepGroup(
        name: _sectionDisplayName(section),
        icon: _sectionIcon(section),
        notifications: e.value,
      );
    }).toList();
  }

  static String _sectionDisplayName(String section) {
    switch (section) {
      case 'bedtime':
        return 'Bedtime';
      case 'wakeup':
        return 'Wake Up';
      case 'winddown':
        return 'Wind-Down';
      default:
        return section;
    }
  }

  static IconData _sectionIcon(String section) {
    switch (section) {
      case 'bedtime':
        return Icons.nightlight_round;
      case 'wakeup':
        return Icons.wb_sunny_rounded;
      case 'winddown':
        return Icons.bedtime_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }
}

class _SleepGroup {
  final String name;
  final IconData icon;
  final List<Map<String, dynamic>> notifications;

  const _SleepGroup({
    required this.name,
    required this.icon,
    required this.notifications,
  });
}

class _SleepGroupCard extends StatefulWidget {
  final String sectionName;
  final IconData sectionIcon;
  final List<Map<String, dynamic>> notifications;
  final bool isDark;
  final NotificationHub hub;
  final VoidCallback? onDeleted;

  const _SleepGroupCard({
    required this.sectionName,
    required this.sectionIcon,
    required this.notifications,
    required this.isDark,
    required this.hub,
    this.onDeleted,
  });

  @override
  State<_SleepGroupCard> createState() => _SleepGroupCardState();
}

class _SleepGroupCardState extends State<_SleepGroupCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final count = widget.notifications.length;
    final isDark = widget.isDark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
                      color: Colors.indigo.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      widget.sectionIcon,
                      color: Colors.indigo,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.sectionName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          count == 1
                              ? '1 reminder scheduled'
                              : '$count reminders scheduled',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: isDark ? Colors.white54 : Colors.black54,
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
    final notificationId = notif['notificationId'] as int?;
    final entityId = notif['entityId'] as String? ?? '';
    final payload = notif['payload'] as String? ?? '';

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
            color: widget.isDark ? const Color(0xFF12151A) : const Color(0xFFF5F5F5),
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
                      color: Colors.indigo.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      widget.sectionIcon,
                      color: Colors.indigo,
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
