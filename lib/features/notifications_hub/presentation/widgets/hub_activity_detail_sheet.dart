import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/notifications/models/notification_lifecycle_event.dart';
import '../../../../core/notifications/models/notification_log_entry.dart';
import '../../../../core/notifications/notifications.dart';
import '../../../../core/theme/color_schemes.dart';

/// Bottom sheet showing today's notification log entries for a given event
/// (Failed, Tapped, Actions). Opened when user taps an Activity chip.
class HubActivityDetailSheet extends StatelessWidget {
  final NotificationLifecycleEvent event;
  final VoidCallback? onDismiss;

  const HubActivityDetailSheet({
    super.key,
    required this.event,
    this.onDismiss,
  });

  static Future<void> show(
    BuildContext context, {
    required NotificationLifecycleEvent event,
    VoidCallback? onDismiss,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      isDismissible: true,
      useSafeArea: true,
      builder: (ctx) => HubActivityDetailSheet(
        event: event,
        onDismiss: onDismiss ?? () => Navigator.pop(ctx),
      ),
    );
  }

  String get _title {
    switch (event) {
      case NotificationLifecycleEvent.failed:
        return 'Failed Today';
      case NotificationLifecycleEvent.tapped:
        return 'Tapped Today';
      case NotificationLifecycleEvent.action:
        return 'Actions Today';
      default:
        return event.label;
    }
  }

  IconData get _icon {
    switch (event) {
      case NotificationLifecycleEvent.failed:
        return Icons.error_outline_rounded;
      case NotificationLifecycleEvent.tapped:
        return Icons.touch_app_rounded;
      case NotificationLifecycleEvent.action:
        return Icons.bolt_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color get _accentColor {
    switch (event) {
      case NotificationLifecycleEvent.failed:
        return Colors.red;
      case NotificationLifecycleEvent.tapped:
        return Colors.green;
      case NotificationLifecycleEvent.action:
        return Colors.amber;
      default:
        return AppColorSchemes.primaryGold;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hub = NotificationHub();

    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfTomorrow = startOfToday.add(const Duration(days: 1));

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: isDark ? theme.colorScheme.surface : theme.colorScheme.surface,
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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _accentColor.withOpacity(isDark ? 0.2 : 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_icon, color: _accentColor, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          DateFormat('EEEE, MMM d').format(now),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<NotificationLogEntry>>(
                future: hub.getHistory(
                  event: event,
                  from: startOfToday,
                  to: startOfTomorrow,
                  limit: 200,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(
                      child: CircularProgressIndicator.adaptive(),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Failed to load: ${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    );
                  }

                  final entries = snapshot.data ?? [];
                  if (entries.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _icon,
                              size: 48,
                              color: theme.colorScheme.onSurfaceVariant
                                  .withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No ${event.label.toLowerCase()} today',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: scrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return _ActivityTile(
                        entry: entry,
                        moduleName: hub.moduleDisplayName(entry.moduleId),
                        isDark: isDark,
                        theme: theme,
                        accentColor: _accentColor,
                        showMetadata: event ==
                            NotificationLifecycleEvent.failed,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final NotificationLogEntry entry;
  final String moduleName;
  final bool isDark;
  final ThemeData theme;
  final Color accentColor;
  final bool showMetadata;

  const _ActivityTile({
    required this.entry,
    required this.moduleName,
    required this.isDark,
    required this.theme,
    required this.accentColor,
    this.showMetadata = false,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr =
        '${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerLow
            : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(isDark ? 0.2 : 0.3),
        ),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.notifications_rounded, color: accentColor, size: 18),
        ),
        title: Text(
          entry.title.isEmpty ? 'Notification' : entry.title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '$moduleName · $timeStr',
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 11,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        children: [
          if (entry.body.isNotEmpty) _detailRow('Body', entry.body),
          if (entry.payload != null) _detailRow('Payload', entry.payload!),
          if (showMetadata && entry.metadata.isNotEmpty)
            _detailRow(
              'Reason',
              entry.metadata.entries
                  .map((e) => '${e.key}: ${e.value}')
                  .join(', '),
            ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
