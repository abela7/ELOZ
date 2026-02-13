import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/notifications/notifications.dart';
import '../../../finance/data/models/bill.dart';
import '../../../finance/data/repositories/bill_repository.dart';
import '../../../finance/notifications/finance_notification_contract.dart';
import 'scheduled_notification_detail_sheet.dart';

/// Reusable section showing Finance scheduled notifications grouped by bill.
/// Used in HubModuleDetailPage (Finance) and HubFinanceModulePage.
/// Tapping a notification opens full detail sheet with Test button.
class FinanceScheduledSection extends StatelessWidget {
  final NotificationHub hub;
  final bool isDark;
  final VoidCallback? onDeleted;
  final int? refreshKey;

  const FinanceScheduledSection({
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
        FinanceNotificationContract.moduleId,
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
                  Icons.notifications_off_rounded,
                  size: 40,
                  color: isDark ? Colors.white24 : Colors.black26,
                ),
                const SizedBox(height: 12),
                Text(
                  'No scheduled bill reminders',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap Sync in Per-Module Settings → Finance to schedule',
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

        return FutureBuilder<List<Bill>>(
          future: BillRepository().getActiveBills(),
          builder: (context, billSnapshot) {
            final bills = billSnapshot.data ?? [];
            final billByName = {for (final b in bills) b.id: b};
            final grouped = _groupByBill(notifications, billByName);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: grouped
                  .map((e) => _ScheduledBillGroupCard(
                        billName: e.name,
                        notifications: e.notifications,
                        isDark: isDark,
                        hub: hub,
                        onBuildCard: _buildCard,
                        onDeleted: onDeleted,
                      ))
                  .toList(),
            );
          },
        );
      },
    );
  }

  static List<_BillGroup> _groupByBill(
    List<Map<String, dynamic>> notifications,
    Map<String, Bill> billByName,
  ) {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final n in notifications) {
      final entityId = n['entityId'] as String? ?? '';
      final targetId = n['targetEntityId'] as String?;
      String billId = targetId ?? 'other';
      if (billId == 'other' && entityId.startsWith('bill:')) {
        final parts = entityId.split(':');
        if (parts.length >= 2) billId = parts[1];
      }
      map.putIfAbsent(billId, () => []).add(n);
    }
    return map.entries.map((e) {
      final bill = billByName[e.key];
      return _BillGroup(
        name: bill?.name ?? 'Bill / Subscription',
        notifications: e.value,
      );
    }).toList();
  }

  static Widget _buildCard(
    Map<String, dynamic> notif,
    bool isDark, {
    VoidCallback? onTap,
  }) {
    final title = notif['title'] as String? ?? 'Notification';
    final body = notif['body'] as String? ?? '';
    final scheduledAt = notif['scheduledAt'] as DateTime?;
    final type = notif['type'] as String? ?? '';

    final content = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF12151A) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
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
                  color: _typeColor(type).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_typeIcon(type), color: _typeColor(type), size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (onTap != null)
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                      ],
                    ),
                    if (body.isNotEmpty)
                      Text(
                        body,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
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
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
                const SizedBox(width: 4),
                Text(
                  DateFormat('MMM d, h:mm a').format(scheduledAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: content,
      );
    }
    return content;
  }

  static Color _typeColor(String typeId) {
    switch (typeId) {
      case FinanceNotificationContract.typeBillUpcoming:
        return Colors.blue;
      case FinanceNotificationContract.typeBillTomorrow:
        return Colors.orange;
      case FinanceNotificationContract.typePaymentDue:
        return Colors.red;
      case FinanceNotificationContract.typeBillOverdue:
        return Colors.deepPurple;
      default:
        return Colors.grey;
    }
  }

  static IconData _typeIcon(String typeId) {
    switch (typeId) {
      case FinanceNotificationContract.typeBillUpcoming:
        return Icons.notifications_rounded;
      case FinanceNotificationContract.typeBillTomorrow:
        return Icons.notification_important_rounded;
      case FinanceNotificationContract.typePaymentDue:
        return Icons.priority_high_rounded;
      case FinanceNotificationContract.typeBillOverdue:
        return Icons.alarm_rounded;
      default:
        return Icons.notifications_outlined;
    }
  }
}

class _BillGroup {
  final String name;
  final List<Map<String, dynamic>> notifications;

  const _BillGroup({
    required this.name,
    required this.notifications,
  });
}

class _ScheduledBillGroupCard extends StatefulWidget {
  final String billName;
  final List<Map<String, dynamic>> notifications;
  final bool isDark;
  final NotificationHub hub;
  final Widget Function(Map<String, dynamic>, bool, {VoidCallback? onTap})
      onBuildCard;
  final VoidCallback? onDeleted;

  const _ScheduledBillGroupCard({
    required this.billName,
    required this.notifications,
    required this.isDark,
    required this.hub,
    required this.onBuildCard,
    this.onDeleted,
  });

  @override
  State<_ScheduledBillGroupCard> createState() =>
      _ScheduledBillGroupCardState();
}

class _ScheduledBillGroupCardState extends State<_ScheduledBillGroupCard> {
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
                      color: const Color(0xFFCDAF56).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: Color(0xFFCDAF56),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.billName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
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
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: isDark ? Colors.white54 : Colors.black54,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: isDark ? Colors.white12 : Colors.black12,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: widget.notifications
                    .map((n) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: widget.onBuildCard(
                            n,
                            isDark,
                            onTap: () => ScheduledNotificationDetailSheet.show(
                              context,
                              notif: n,
                              hub: widget.hub,
                              isDark: isDark,
                              onDeleted: widget.onDeleted,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
