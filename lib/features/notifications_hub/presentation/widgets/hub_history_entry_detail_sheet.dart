import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/notifications/models/notification_hub_payload.dart';
import '../../../../core/notifications/models/notification_lifecycle_event.dart';
import '../../../../core/notifications/models/notification_log_entry.dart';
import '../../../../core/notifications/notifications.dart';

/// Bottom sheet showing advanced details for a history log entry with
/// "Go to source" and "Delete reminder from source" actions.
class HubHistoryEntryDetailSheet extends StatelessWidget {
  static String _formatSnoozeDuration(dynamic minutes) {
    final m = minutes is int
        ? minutes
        : (minutes is num ? minutes.toInt() : int.tryParse('$minutes') ?? 0);
    if (m < 60) return '$m min';
    final h = m ~/ 60;
    final r = m % 60;
    return r == 0 ? '$h hr' : '$h hr $r min';
  }
  final NotificationLogEntry entry;
  final NotificationHub hub;
  final bool isDark;
  final ScrollController? scrollController;
  final VoidCallback? onDismiss;
  final VoidCallback? onDeleted;

  const HubHistoryEntryDetailSheet({
    super.key,
    required this.entry,
    required this.hub,
    required this.isDark,
    this.scrollController,
    this.onDismiss,
    this.onDeleted,
  });

  static Future<void> show(
    BuildContext context, {
    required NotificationLogEntry entry,
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
        initialChildSize: 0.75,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        expand: false,
        snap: true,
        shouldCloseOnMinExtent: true,
        builder: (context, scrollController) => HubHistoryEntryDetailSheet(
          entry: entry,
          hub: hub,
          isDark: isDark,
          scrollController: scrollController,
          onDismiss: () => Navigator.pop(ctx),
          onDeleted: onDeleted,
        ),
      ),
    );
  }

  NotificationHubPayload? get _parsed =>
      entry.payload != null ? NotificationHubPayload.tryParse(entry.payload!) : null;

  String get _sectionDisplay {
    final p = _parsed;
    if (p == null || p.extras.isEmpty) return entry.moduleId;
    final sectionId = p.extras['section'] ?? p.extras['type'] ?? '';
    if (sectionId.isEmpty) return hub.moduleDisplayName(entry.moduleId);
    return hub.sectionDisplayName(entry.moduleId, sectionId) ?? sectionId;
  }

  bool get _canGoToSource =>
      entry.payload != null &&
      _parsed != null &&
      hub.adapterFor(entry.moduleId) != null;

  bool get _canDelete =>
      entry.notificationId != null &&
      entry.entityId.isNotEmpty &&
      (entry.payload != null && entry.payload!.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final parsed = _parsed;
    final fg = isDark ? Colors.white : Colors.black87;
    final muted = isDark ? Colors.white54 : Colors.black54;
    final bg = isDark ? const Color(0xFF1A1D23) : const Color(0xFFF5F5F7);

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
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.goldOpacity02,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _eventIcon(entry.event),
                    color: _eventColor(entry.event),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title.isEmpty ? 'Notification' : entry.title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: fg,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${hub.moduleDisplayName(entry.moduleId)} • $_sectionDisplay',
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
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              children: [
                _DetailSection(
                  title: 'Source & Event',
                  isDark: isDark,
                  children: [
                    _DetailRow(
                      label: 'From',
                      value: hub.moduleDisplayName(entry.moduleId),
                      isDark: isDark,
                    ),
                    _DetailRow(
                      label: 'Section',
                      value: _sectionDisplay,
                      isDark: isDark,
                    ),
                    _DetailRow(
                      label: 'Event',
                      value: entry.event.label,
                      isDark: isDark,
                    ),
                    _DetailRow(
                      label: 'When',
                      value: DateFormat('EEEE, MMM d, y • h:mm a')
                          .format(entry.timestamp),
                      isDark: isDark,
                    ),
                  ],
                ),
                _DetailSection(
                  title: 'Content',
                  isDark: isDark,
                  children: [
                    if (entry.body.isNotEmpty)
                      _DetailRow(
                        label: 'Message',
                        value: entry.body,
                        isDark: isDark,
                      ),
                  ],
                ),
                if (parsed != null)
                  _DetailSection(
                    title: 'Reminder Details',
                    isDark: isDark,
                    children: [
                      _DetailRow(
                        label: 'Entity ID',
                        value: entry.entityId,
                        isDark: isDark,
                        monospace: true,
                      ),
                      _DetailRow(
                        label: 'Reminder',
                        value:
                            '${parsed.reminderType} | ${parsed.reminderValue} ${parsed.reminderUnit}',
                        isDark: isDark,
                      ),
                      if (parsed.extras.isNotEmpty)
                        _DetailRow(
                          label: 'Extras',
                          value: parsed.extras.entries
                              .map((e) => '${e.key}: ${e.value}')
                              .join(', '),
                          isDark: isDark,
                          monospace: true,
                        ),
                    ],
                  ),
                if (entry.event == NotificationLifecycleEvent.snoozed &&
                    entry.metadata['snoozeDurationMinutes'] != null)
                  _DetailSection(
                    title: 'Snooze',
                    isDark: isDark,
                    children: [
                      _DetailRow(
                        label: 'Duration',
                        value: _formatSnoozeDuration(
                            entry.metadata['snoozeDurationMinutes']),
                        isDark: isDark,
                      ),
                    ],
                  ),
                _DetailSection(
                  title: 'Delivery',
                  isDark: isDark,
                  children: [
                    if (entry.channelKey != null)
                      _DetailRow(
                        label: 'Channel',
                        value: entry.channelKey!,
                        isDark: isDark,
                      ),
                    if (entry.soundKey != null)
                      _DetailRow(
                        label: 'Sound',
                        value: entry.soundKey!,
                        isDark: isDark,
                      ),
                    if (entry.actionId != null)
                      _DetailRow(
                        label: 'Action',
                        value: entry.actionId!,
                        isDark: isDark,
                      ),
                  ],
                ),
                if (entry.metadata.isNotEmpty)
                  _DetailSection(
                    title: 'Metadata',
                    isDark: isDark,
                    children: [
                      _DetailRow(
                        label: 'Details',
                        value: entry.metadata.entries
                            .map((e) => '${e.key}: ${e.value}')
                            .join('\n'),
                        isDark: isDark,
                        monospace: true,
                      ),
                    ],
                  ),
                _DetailSection(
                  title: 'Technical',
                  isDark: isDark,
                  children: [
                    if (entry.notificationId != null)
                      _DetailRow(
                        label: 'Notification ID',
                        value: '#${entry.notificationId}',
                        isDark: isDark,
                        monospace: true,
                      ),
                    _DetailRow(
                      label: 'Log ID',
                      value: entry.id,
                      isDark: isDark,
                      monospace: true,
                    ),
                    if (entry.payload != null)
                      _DetailRow(
                        label: 'Payload',
                        value: entry.payload!,
                        isDark: isDark,
                        monospace: true,
                        maxLines: 5,
                      ),
                  ],
                ),
                // Actions
                const SizedBox(height: 8),
                if (_canGoToSource)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: () => _goToSource(context),
                      icon: const Icon(Icons.open_in_new_rounded, size: 22),
                      label: const Text(
                        'Go to Source',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                if (_canGoToSource) const SizedBox(height: 10),
                if (_canDelete)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: () => _deleteFromSource(context),
                      icon: const Icon(Icons.delete_outline_rounded, size: 22),
                      label: const Text(
                        'Delete Reminder from Source',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                if (_canDelete) const SizedBox(height: 10),
                Row(
                  children: [
                    if (entry.notificationId != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _copy(context, '#${entry.notificationId}'),
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: const Text('Copy ID', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: muted,
                            side: BorderSide(color: muted.withOpacity(0.5)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    if (entry.notificationId != null) const SizedBox(width: 8),
                    if (entry.payload != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _copy(context, entry.payload!),
                          icon: const Icon(Icons.code_rounded, size: 18),
                          label: const Text('Copy Payload', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: muted,
                            side: BorderSide(color: muted.withOpacity(0.5)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
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

  void _goToSource(BuildContext context) {
    if (entry.payload == null) return;
    HapticFeedback.mediumImpact();
    Navigator.pop(context);
    hub.handleNotificationTap(entry.payload!);
  }

  Future<void> _deleteFromSource(BuildContext context) async {
    if (!_canDelete) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Reminder from Source?'),
        content: const Text(
          'This will cancel any pending notification and remove the reminder '
          'from the source (bill, debt, habit, etc.) so it will not be rescheduled.',
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
    final success = await hub.deleteAndNotifyModule(
      notificationId: entry.notificationId!,
      entityId: entry.entityId,
      payload: entry.payload!,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Reminder deleted from source'
                : 'Deleted but failed to update source',
          ),
          backgroundColor: success ? Colors.green : Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      onDeleted?.call();
      onDismiss?.call();
    }
  }

  void _copy(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ),
    );
  }

  IconData _eventIcon(NotificationLifecycleEvent event) {
    return switch (event) {
      NotificationLifecycleEvent.scheduled => Icons.schedule_rounded,
      NotificationLifecycleEvent.delivered => Icons.check_circle_rounded,
      NotificationLifecycleEvent.tapped => Icons.touch_app_rounded,
      NotificationLifecycleEvent.action => Icons.touch_app_rounded,
      NotificationLifecycleEvent.snoozed => Icons.snooze_rounded,
      NotificationLifecycleEvent.cancelled => Icons.cancel_rounded,
      NotificationLifecycleEvent.missed => Icons.warning_rounded,
      NotificationLifecycleEvent.failed => Icons.error_rounded,
    };
  }

  Color _eventColor(NotificationLifecycleEvent event) {
    return switch (event) {
      NotificationLifecycleEvent.scheduled => Colors.blue,
      NotificationLifecycleEvent.delivered => Colors.green,
      NotificationLifecycleEvent.tapped => Colors.green,
      NotificationLifecycleEvent.action => Colors.teal,
      NotificationLifecycleEvent.snoozed => Colors.deepPurple,
      NotificationLifecycleEvent.cancelled => Colors.orange,
      NotificationLifecycleEvent.missed => Colors.amber,
      NotificationLifecycleEvent.failed => Colors.red,
    };
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
    if (children.isEmpty) return const SizedBox.shrink();

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
              boxShadow: isDark
                  ? null
                  : [
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
  final int maxLines;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.isDark,
    this.monospace = false,
    this.maxLines = 3,
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
          SelectableText(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black87,
              fontFamily: monospace ? 'monospace' : null,
            ),
            maxLines: maxLines,
          ),
        ],
      ),
    );
  }
}
