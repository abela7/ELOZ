import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/notifications/notifications.dart';
import '../../../finance/notifications/finance_notification_contract.dart';
import 'scheduled_notification_detail_sheet.dart';

/// Reusable section showing Finance scheduled notifications grouped by entity.
/// Supports Bills, Budgets, Debts, Lending, Savings Goals, Recurring Income.
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
                  Icons.schedule_rounded,
                  size: 40,
                  color: isDark ? Colors.white24 : Colors.black26,
                ),
                const SizedBox(height: 12),
                Text(
                  'No upcoming finance notifications',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This shows only future reminders. After a notification fires '
                  '(e.g. Budget review at 9am), it no longer appears here. '
                  'Check the Notification Hub History tab for past activity.\n\n'
                  'To schedule: turn on Budget Alerts or add bill reminders in '
                  'Finance, then tap Sync above.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.black38,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final grouped = _groupByEntity(notifications);

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
  }

  /// Groups Finance notifications by entity (bill, budget, debt, etc.).
  /// Resolves display names from title patterns (e.g. "Budget review: Save Money").
  static List<_BillGroup> _groupByEntity(
    List<Map<String, dynamic>> notifications,
  ) {
    final map = <String, _GroupAccumulator>{};
    for (final n in notifications) {
      final entityId = n['entityId'] as String? ?? '';
      final targetId = n['targetEntityId'] as String?;
      final title = n['title'] as String? ?? 'Notification';
      final section = n['section'] as String? ?? '';

      String groupKey;
      String displayName;

      final extracted = _entityNameFromTitle(title);
      if (entityId.startsWith('bill:')) {
        final parts = entityId.split(':');
        groupKey = 'bill:${targetId ?? (parts.length >= 2 ? parts[1] : entityId)}';
        displayName = extracted.isEmpty ? 'Bill / Subscription' : extracted;
      } else if (entityId.startsWith('budget:')) {
        groupKey = entityId.length > 30 ? entityId.substring(0, 30) : entityId;
        displayName = extracted.isEmpty ? 'Budget' : extracted;
      } else if (entityId.startsWith('debt:')) {
        final parts = entityId.split(':');
        final debtId = targetId ?? (parts.length >= 3 ? parts[2] : entityId);
        final dir = parts.length >= 2 ? parts[1] : '';
        groupKey = 'debt:$dir:$debtId';
        displayName = extracted.isEmpty
            ? (dir == 'lent' ? 'Lending' : 'Debt')
            : extracted;
      } else if (entityId.startsWith('savings:') ||
          section == FinanceNotificationContract.sectionSavingsGoals) {
        groupKey = 'savings:${targetId ?? entityId}';
        displayName = extracted.isEmpty ? 'Savings Goal' : extracted;
      } else if (entityId.startsWith('income:') ||
          section == FinanceNotificationContract.sectionRecurringIncome) {
        groupKey = 'income:${targetId ?? entityId}';
        displayName = extracted.isEmpty ? 'Recurring Income' : extracted;
      } else {
        groupKey = entityId.isNotEmpty ? entityId : 'other:${n.hashCode}';
        displayName = extracted.isEmpty ? 'Finance' : extracted;
      }

      map.putIfAbsent(
        groupKey,
        () => _GroupAccumulator(name: displayName, notifications: []),
      ).notifications.add(n);
    }

    return map.values
        .map((g) => _BillGroup(name: g.name, notifications: g.notifications))
        .toList();
  }

  static String _entityNameFromTitle(String title) {
    final lower = title.toLowerCase();
    const afterColon = [' review: ', ' exceeded: ', ' warning: '];
    for (final p in afterColon) {
      final idx = lower.indexOf(p);
      if (idx >= 0 && idx + p.length < title.length) {
        final name = title.substring(idx + p.length).trim();
        if (name.length >= 2) return name;
      }
    }
    const beforePhrase = [
      ' due ', ' payment ', ' reminder ', ' is ', ' overdue',
      ' tomorrow', ' today', ' due in', ' collection ',
    ];
    for (final p in beforePhrase) {
      final idx = lower.indexOf(p);
      if (idx > 0) {
        final name = title.substring(0, idx).trim();
        if (name.length >= 2) return name;
      }
    }
    return title.length <= 35 ? title : '${title.substring(0, 32)}...';
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
      case FinanceNotificationContract.typeBudgetLimit:
      case FinanceNotificationContract.typeBudgetWindow:
        return Colors.teal;
      case FinanceNotificationContract.typeDebtReminder:
      case FinanceNotificationContract.typeLendingReminder:
        return Colors.indigo;
      case FinanceNotificationContract.typeSavingsDeadline:
        return Colors.green;
      case FinanceNotificationContract.typeIncomeReminder:
        return Colors.lightGreen;
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
      case FinanceNotificationContract.typeBudgetLimit:
      case FinanceNotificationContract.typeBudgetWindow:
        return Icons.pie_chart_rounded;
      case FinanceNotificationContract.typeDebtReminder:
      case FinanceNotificationContract.typeLendingReminder:
        return Icons.account_balance_rounded;
      case FinanceNotificationContract.typeSavingsDeadline:
        return Icons.savings_rounded;
      case FinanceNotificationContract.typeIncomeReminder:
        return Icons.repeat_rounded;
      default:
        return Icons.notifications_outlined;
    }
  }
}

class _GroupAccumulator {
  final String name;
  final List<Map<String, dynamic>> notifications;

  _GroupAccumulator({required this.name, required this.notifications});
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
