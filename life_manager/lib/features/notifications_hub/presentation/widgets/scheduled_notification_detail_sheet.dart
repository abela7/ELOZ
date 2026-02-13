import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/notifications/models/notification_hub_payload.dart';
import '../../../../core/notifications/models/notification_hub_schedule_request.dart';
import '../../../../core/notifications/notifications.dart';
import '../../../finance/notifications/finance_notification_contract.dart';
import '../screens/manage_group_reminders_page.dart';

/// Bottom sheet showing full details of a scheduled notification with Test button.
class ScheduledNotificationDetailSheet extends StatelessWidget {
  final Map<String, dynamic> notif;
  final NotificationHub hub;
  final bool isDark;
  final ScrollController? scrollController;
  final VoidCallback? onDismiss;
  final VoidCallback? onDeleted;

  const ScheduledNotificationDetailSheet({
    super.key,
    required this.notif,
    required this.hub,
    required this.isDark,
    this.scrollController,
    this.onDismiss,
    this.onDeleted,
  });

  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> notif,
    required NotificationHub hub,
    required bool isDark,
    VoidCallback? onDeleted,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      isDismissible: true,
      useSafeArea: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.2,
        maxChildSize: 0.9,
        expand: false,
        snap: true,
        shouldCloseOnMinExtent: true,
        builder: (context, scrollController) => ScheduledNotificationDetailSheet(
          notif: notif,
          hub: hub,
          isDark: isDark,
          scrollController: scrollController,
          onDismiss: () => Navigator.pop(ctx),
          onDeleted: onDeleted,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = notif['title'] as String? ?? 'Notification';
    final body = notif['body'] as String? ?? '';
    final scheduledAt = notif['scheduledAt'] as DateTime?;
    final typeId = notif['type'] as String? ?? '';
    final section = notif['section'] as String? ?? '';
    final condition = notif['condition'] as String? ?? '';
    final channelKey = notif['channelKey'] as String? ?? '';
    final channelName = notif['channelName'] as String? ?? '';
    final soundKey = notif['soundKey'] as String? ?? '';
    final soundName = notif['soundName'] as String? ?? '';
    final vibrationPattern = notif['vibrationPattern'] as String? ?? '';
    final audioStream = notif['audioStream'] as String? ?? '';
    final useAlarmMode = notif['useAlarmMode'] as bool? ?? false;
    final entityId = notif['entityId'] as String? ?? '';
    final targetEntityId = notif['targetEntityId'] as String? ?? '';
    final moduleId = notif['moduleId'] as String? ?? '';

    // Enriched from UniversalNotification (when created via creator)
    final iconCodePoint = notif['iconCodePoint'] as int?;
    final iconFontFamily = notif['iconFontFamily'] as String? ?? 'MaterialIcons';
    final iconFontPackage = notif['iconFontPackage'] as String?;
    final colorValue = notif['colorValue'] as int?;
    final actionsEnabled = notif['actionsEnabled'] as bool? ?? false;
    final actionsJson = notif['actionsJson'] as String?;
    final timing = notif['timing'] as String? ?? '';
    final timingValue = notif['timingValue'] as int? ?? 0;
    final timingUnit = notif['timingUnit'] as String? ?? '';
    final hour = notif['hour'] as int? ?? 9;
    final minute = notif['minute'] as int? ?? 0;
    final entityName = notif['entityName'] as String? ?? '';

    final bg = isDark ? const Color(0xFF1A1D23) : const Color(0xFFF5F5F7);
    final fg = isDark ? Colors.white : Colors.black87;
    final muted = isDark ? Colors.white54 : Colors.black54;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white30 : Colors.black26,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.goldOpacity02,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    color: AppColors.gold,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notification Details',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: fg,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        '${hub.moduleDisplayName(moduleId.isNotEmpty ? moduleId : "finance")} • ${_sectionLabel(section)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              children: [
                _DetailSection(
                  title: 'Content',
                  isDark: isDark,
                  children: [
                    _DetailRow(label: 'Title', value: title, isDark: isDark),
                    if (body.isNotEmpty)
                      _DetailRow(label: 'Body', value: body, isDark: isDark),
                  ],
                ),
                if (iconCodePoint != null || colorValue != null)
                  _DetailSection(
                    title: 'Appearance',
                    isDark: isDark,
                    children: [
                      if (iconCodePoint != null)
                        _AppearanceRow(
                          label: 'Icon',
                          isDark: isDark,
                          icon: Icon(
                            IconData(
                              iconCodePoint,
                              fontFamily: iconFontFamily,
                              fontPackage: iconFontPackage?.isEmpty == true
                                  ? null
                                  : iconFontPackage,
                            ),
                            color: Color(colorValue ?? 0xFFCDAF56),
                            size: 32,
                          ),
                          value: 'Code point: 0x${iconCodePoint.toRadixString(16)}',
                        ),
                      if (colorValue != null)
                        _DetailRow(
                          label: 'Color',
                          value: '#${(colorValue & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
                          isDark: isDark,
                        ),
                    ],
                  ),
                _DetailSection(
                  title: 'Action Buttons',
                  isDark: isDark,
                  children: [
                    _DetailRow(
                      label: 'Shown on notification',
                      value: actionsEnabled ? 'Yes' : 'No',
                      isDark: isDark,
                    ),
                    if (actionsEnabled &&
                        actionsJson != null &&
                        actionsJson.isNotEmpty)
                      ..._buildActionButtonRows(actionsJson, isDark),
                  ],
                ),
                if (timing.isNotEmpty) ...[
                  _DetailSection(
                    title: 'Timing',
                    isDark: isDark,
                    children: [
                      _DetailRow(
                        label: 'When',
                        value: _timingDescription(
                          timing,
                          timingValue,
                          timingUnit,
                          hour,
                          minute,
                        ),
                        isDark: isDark,
                      ),
                    ],
                  ),
                ],
                _DetailSection(
                  title: 'Schedule',
                  isDark: isDark,
                  children: [
                    _DetailRow(
                      label: 'Date & Time',
                      value: scheduledAt != null
                          ? DateFormat('EEEE, MMM d, y • h:mm a')
                              .format(scheduledAt)
                          : 'Unknown',
                      isDark: isDark,
                    ),
                    _DetailRow(
                      label: 'Condition',
                      value: _conditionLabel(condition),
                      isDark: isDark,
                    ),
                    _DetailRow(
                      label: 'Action on tap',
                      value:
                          'Opens ${_sectionLabel(section)} → ${_tapDestinationLabel(section, targetEntityId.isNotEmpty)}',
                      isDark: isDark,
                    ),
                  ],
                ),
                _DetailSection(
                  title: 'Delivery Settings',
                  isDark: isDark,
                  children: [
                    _DetailRow(
                      label: 'Channel',
                      value: channelName.isNotEmpty ? channelName : channelKey,
                      isDark: isDark,
                    ),
                    _DetailRow(
                      label: 'Sound',
                      value: soundName.isNotEmpty ? soundName : soundKey,
                      isDark: isDark,
                    ),
                    _DetailRow(
                      label: 'Vibration',
                      value: vibrationPattern.isNotEmpty
                          ? vibrationPattern
                          : 'Default',
                      isDark: isDark,
                    ),
                    _DetailRow(
                      label: 'Volume stream',
                      value: _audioStreamLabel(audioStream),
                      isDark: isDark,
                    ),
                    _DetailRow(
                      label: 'Alarm mode',
                      value: useAlarmMode ? 'Yes (bypasses silent)' : 'No',
                      isDark: isDark,
                    ),
                  ],
                ),
                _DetailSection(
                  title: 'Technical',
                  isDark: isDark,
                  children: [
                    _DetailRow(
                      label: 'Type',
                      value: _typeLabel(typeId),
                      isDark: isDark,
                    ),
                    if (entityName.isNotEmpty)
                      _DetailRow(
                        label: 'Entity name',
                        value: entityName,
                        isDark: isDark,
                      ),
                    _DetailRow(
                      label: 'Entity ID',
                      value: entityId,
                      isDark: isDark,
                      monospace: true,
                    ),
                    if (targetEntityId.isNotEmpty)
                      _DetailRow(
                        label: 'Target',
                        value: targetEntityId,
                        isDark: isDark,
                        monospace: true,
                      ),
                    _DetailRow(
                      label: 'Reminder',
                      value:
                          '${notif['reminderType'] ?? 'at_time'} | ${notif['reminderValue'] ?? '0'} ${notif['reminderUnit'] ?? 'minutes'}',
                      isDark: isDark,
                    ),
                    if ((notif['payload'] as String? ?? '').isNotEmpty)
                      _DetailRow(
                        label: 'Payload',
                        value: notif['payload'] as String,
                        isDark: isDark,
                        monospace: true,
                      ),
                  ],
                ),
                _HealthCheck(notif: notif, isDark: isDark),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: () => _testNotification(context),
                    icon: const Icon(Icons.play_arrow_rounded, size: 24),
                    label: const Text(
                      'Test This Notification',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                if (_canManageGroup(section, targetEntityId)) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: () => _openManageGroup(context,
                        targetEntityId: targetEntityId,
                        section: section,
                        entityName: _entityNameFromTitle(title),
                      ),
                      icon: const Icon(Icons.edit_notifications_rounded, size: 22),
                      label: Text(
                        'Manage all reminders for ${_entityNameFromTitle(title)}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.gold,
                        side: const BorderSide(color: AppColors.gold),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: () => _deleteNotification(context),
                    icon: const Icon(Icons.delete_outline_rounded, size: 22),
                    label: const Text(
                      'Delete This Notification',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: TextButton(
                    onPressed: onDismiss ?? () => Navigator.pop(context),
                    child: Text(
                      'Close',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: muted,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteNotification(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Notification?'),
        content: const Text(
          'This will cancel the notification and remove the reminder from the '
          'source (bill, debt, etc.) so it will not be rescheduled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    HapticFeedback.mediumImpact();
    final notifId = notif['id'];
    final entityId = notif['entityId'] as String? ?? '';
    final payload = notif['payload'] as String? ?? '';

    if (notifId == null || entityId.isEmpty || payload.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot delete: invalid notification data'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final success = await hub.deleteAndNotifyModule(
      notificationId: (notifId is int) ? notifId : (notifId as num).toInt(),
      entityId: entityId,
      payload: payload,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Notification deleted permanently' : 'Deleted but failed to update source',
          ),
          backgroundColor: success ? Colors.green : Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      onDeleted?.call();
      onDismiss?.call();
    }
  }

  Future<void> _testNotification(BuildContext context) async {
    HapticFeedback.mediumImpact();
    final title = notif['title'] as String? ?? 'Test';
    final body = notif['body'] as String? ?? '';
    final typeId = notif['type'] as String? ?? FinanceNotificationContract.typeReminder;
    final payload = notif['payload'] as String? ?? '';
    final parsed = NotificationHubPayload.tryParse(payload);
    if (parsed == null) return;

    final now = DateTime.now();
    final testEntityId = 'test:${parsed.entityId}:${now.millisecondsSinceEpoch}';

    final result = await hub.schedule(
      NotificationHubScheduleRequest(
        moduleId: FinanceNotificationContract.moduleId,
        entityId: testEntityId,
        title: title,
        body: body,
        scheduledAt: now.add(const Duration(seconds: 3)),
        type: typeId,
        priority: (notif['useAlarmMode'] == true) ? 'High' : 'Medium',
        extras: Map.from(parsed.extras)..['isTest'] = 'true',
      ),
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.success
                ? 'Test notification scheduled – arriving in 3 seconds'
                : 'Failed: ${result.failureReason ?? "unknown"}',
          ),
          backgroundColor: result.success ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (result.success) onDismiss?.call();
    }
  }

  static bool _canManageGroup(String section, String targetEntityId) {
    if (targetEntityId.isEmpty) return false;
    return section == FinanceNotificationContract.sectionBills ||
        section == FinanceNotificationContract.sectionDebts ||
        section == FinanceNotificationContract.sectionLending ||
        section == FinanceNotificationContract.sectionRecurringIncome;
  }

  static String _entityNameFromTitle(String title) {
    final lower = title.toLowerCase();
    const stopPhrases = [
      ' due ', ' payment ', ' reminder ', ' is ', ' overdue',
      ' tomorrow', ' today', ' due in', ' collection ',
    ];
    for (final phrase in stopPhrases) {
      final idx = lower.indexOf(phrase);
      if (idx > 0) {
        final name = title.substring(0, idx).trim();
        if (name.length >= 2) return name;
      }
    }
    return title.length <= 35 ? title : '${title.substring(0, 32)}...';
  }

  void _openManageGroup(
    BuildContext context, {
    required String targetEntityId,
    required String section,
    required String entityName,
  }) {
    Navigator.pop(context);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ManageGroupRemindersPage(
          targetEntityId: targetEntityId,
          section: section,
          entityName: entityName,
        ),
      ),
    );
  }

  static String _sectionLabel(String section) {
    switch (section) {
      case FinanceNotificationContract.sectionBills:
        return 'Bills & Subscriptions';
      case FinanceNotificationContract.sectionDebts:
        return 'Debts';
      case FinanceNotificationContract.sectionLending:
        return 'Lending';
      case FinanceNotificationContract.sectionBudgets:
        return 'Budgets';
      case FinanceNotificationContract.sectionSavingsGoals:
        return 'Savings Goals';
      default:
        return section.isNotEmpty ? section : 'Finance';
    }
  }

  static String _tapDestinationLabel(String section, bool hasTargetEntity) {
    if (!hasTargetEntity) {
      return 'Finance';
    }
    switch (section) {
      case FinanceNotificationContract.sectionDebts:
        return 'Debt detail';
      case FinanceNotificationContract.sectionLending:
        return 'Lending detail';
      case FinanceNotificationContract.sectionBills:
        return 'Bill detail';
      default:
        return 'Detail';
    }
  }

  static String _conditionLabel(String condition) {
    switch (condition) {
      case FinanceNotificationContract.conditionAlways:
        return 'Always – fires at scheduled time';
      case FinanceNotificationContract.conditionOnce:
        return 'Once – fires only one time';
      case FinanceNotificationContract.conditionIfUnpaid:
        return 'If unpaid – only when balance/payment is still open';
      case FinanceNotificationContract.conditionIfOverdue:
        return 'If overdue – only when item is past due';
      default:
        return condition.isNotEmpty ? condition : 'Always';
    }
  }

  static String _typeLabel(String typeId) {
    switch (typeId) {
      case FinanceNotificationContract.typeBillOverdue:
        return 'Bill Overdue';
      case FinanceNotificationContract.typePaymentDue:
        return 'Payment Due';
      case FinanceNotificationContract.typeBillTomorrow:
        return 'Bill Tomorrow';
      case FinanceNotificationContract.typeBillUpcoming:
        return 'Bill Upcoming';
      default:
        return typeId.isNotEmpty ? typeId : 'Reminder';
    }
  }

  static String _audioStreamLabel(String stream) {
    switch (stream) {
      case 'alarm':
        return 'Alarm Volume';
      case 'ring':
        return 'Ringtone Volume';
      case 'media':
        return 'Media Volume';
      default:
        return 'Notification Volume';
    }
  }

  static String _timingDescription(
    String timing,
    int timingValue,
    String timingUnit,
    int hour,
    int minute,
  ) {
    final timeStr =
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    switch (timing) {
      case 'before':
        return '$timingValue $timingUnit before at $timeStr';
      case 'on_due':
        return 'On due date at $timeStr';
      case 'after_due':
        return '$timingValue $timingUnit after at $timeStr';
      default:
        return 'At $timeStr';
    }
  }

  static List<Widget> _buildActionButtonRows(String actionsJson, bool isDark) {
    try {
      final decoded = jsonDecode(actionsJson);
      if (decoded is! List) return [];
      final rows = <Widget>[];
      for (final e in decoded) {
        if (e is! Map<String, dynamic>) continue;
        final actionId = e['actionId'] as String? ?? '';
        final label = e['label'] as String? ?? 'Action';
        final desc = _actionDescription(actionId);
        rows.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (e['iconCodePoint'] != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Icon(
                          IconData(
                            (e['iconCodePoint'] as num).toInt(),
                            fontFamily:
                                e['iconFontFamily'] as String? ?? 'MaterialIcons',
                            fontPackage: e['iconFontPackage'] as String?,
                          ),
                          size: 20,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            desc,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }
      return rows;
    } catch (_) {
      return [];
    }
  }

  static String _actionDescription(String actionId) {
    switch (actionId) {
      case 'view':
      case 'open':
        return 'Opens the detail screen for this item';
      case 'mark_done':
      case 'mark_paid':
        return 'Marks as done / records payment';
      case 'snooze':
        return 'Snoozes the reminder';
      case 'snooze_5':
        return 'Snoozes for 5 minutes';
      case 'skip':
        return 'Skips this occurrence (habits)';
      default:
        return 'Runs the "$actionId" action';
    }
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final bool isDark;
  final List<Widget> children;

  const _DetailSection({
    required this.title,
    required this.isDark,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.whiteOpacity01 : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: isDark ? null : [
                BoxShadow(
                  color: AppColors.blackOpacity005,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  final bool monospace;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.isDark,
    this.monospace = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black87,
              fontFamily: monospace ? 'monospace' : null,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _AppearanceRow extends StatelessWidget {
  final String label;
  final Widget icon;
  final String value;
  final bool isDark;

  const _AppearanceRow({
    required this.label,
    required this.icon,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              icon,
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HealthCheck extends StatelessWidget {
  final Map<String, dynamic> notif;
  final bool isDark;

  const _HealthCheck({required this.notif, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final issues = <String>[];
    final scheduledAt = notif['scheduledAt'] as DateTime?;
    if (scheduledAt == null) {
      issues.add('Fire time unknown');
    } else if (scheduledAt.isBefore(DateTime.now())) {
      issues.add('Scheduled time is in the past');
    }
    final title = notif['title'] as String? ?? '';
    if (title.isEmpty) issues.add('No title');
    final payload = notif['payload'] as String? ?? '';
    if (payload.isEmpty) issues.add('Missing payload');

    final healthy = issues.isEmpty;
    final color = healthy ? AppColors.success : AppColors.warning;
    final cardBg = healthy
        ? (isDark ? const Color(0x1A4CAF50) : const Color(0x0D4CAF50))
        : (isDark ? const Color(0x1AFFA726) : const Color(0x0DFFA726));
    final border = healthy
        ? (isDark ? const Color(0x664CAF50) : const Color(0x334CAF50))
        : (isDark ? const Color(0x66FFA726) : const Color(0x33FFA726));

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'HEALTH CHECK',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: border,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  healthy ? Icons.check_circle_rounded : Icons.warning_rounded,
                  size: 24,
                  color: color,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        healthy ? 'Ready to trigger' : 'Potential Issues',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (issues.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        ...issues.map((i) => Text(
                              '• $i',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            )),
                      ],
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
}
