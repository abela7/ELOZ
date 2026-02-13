import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/notifications/models/notification_creator_context.dart';
import '../../../../core/notifications/notifications.dart';
import '../../../../core/notifications/services/universal_notification_display_helper.dart';
import '../../../../core/notifications/services/universal_notification_scheduler.dart';
import '../../../../core/theme/color_schemes.dart';
import 'universal_notification_creator_sheet.dart';

/// Displays reminders from universal storage and offers "Add Reminder".
///
/// Replaces module-specific reminder editors. Uses [UniversalNotificationRepository]
/// and opens [UniversalNotificationCreatorSheet] for new reminders.
/// Pass [creatorContext] for the entity (bill, debt, income, task, habit, etc.).
class UniversalReminderSection extends StatefulWidget {
  final NotificationCreatorContext creatorContext;
  final bool isDark;
  final VoidCallback? onRemindersChanged;
  final String? title;

  const UniversalReminderSection({
    super.key,
    required this.creatorContext,
    required this.isDark,
    this.onRemindersChanged,
    this.title,
  });

  @override
  State<UniversalReminderSection> createState() =>
      _UniversalReminderSectionState();
}

class _UniversalReminderSectionState extends State<UniversalReminderSection> {
  static const _gold = AppColorSchemes.primaryGold;
  final _repo = UniversalNotificationRepository();
  late Future<List<UniversalNotification>> _remindersFuture;

  Future<List<UniversalNotification>> _loadReminders() async {
    await _repo.init();
    return _repo.getByEntity(widget.creatorContext.entityId);
  }

  void _refresh() {
    setState(() {
      _remindersFuture = _loadReminders();
    });
  }

  @override
  void initState() {
    super.initState();
    _remindersFuture = _loadReminders();
  }

  @override
  void didUpdateWidget(covariant UniversalReminderSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.creatorContext.entityId != widget.creatorContext.entityId) {
      _remindersFuture = _loadReminders();
    }
  }

  Future<void> _openCreator([UniversalNotification? existing]) async {
    await UniversalNotificationCreatorSheet.show(
      context,
      creatorContext: widget.creatorContext,
      existing: existing,
      repository: _repo,
    );
    if (mounted) {
      _refresh();
      widget.onRemindersChanged?.call();
    }
  }

  Future<void> _deleteReminder(UniversalNotification n) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Reminder?'),
        content: FutureBuilder<String>(
          future: resolveUniversalNotificationDisplayTitle(n),
          builder: (_, snap) {
            final label = snap.hasData && snap.data!.isNotEmpty
                ? snap.data!
                : (n.titleTemplate.isNotEmpty ? n.titleTemplate : 'Reminder');
            final clean = label.replaceAll(RegExp(r'\{[^}]*\}'), '…').trim();
            return Text('Remove "${clean.isNotEmpty ? clean : 'Reminder'}"?');
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await UniversalNotificationScheduler().cancelForNotification(n);
      await _repo.delete(n.id);
      _refresh();
      if (mounted) widget.onRemindersChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1A1D23) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (widget.isDark ? Colors.white : Colors.black).withOpacity(0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_rounded, size: 20, color: _gold),
              const SizedBox(width: 10),
              Text(
                widget.title ?? 'Reminders',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: widget.isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<UniversalNotification>>(
            future: _remindersFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Could not load reminders',
                    style: TextStyle(
                      fontSize: 14,
                      color: (widget.isDark ? Colors.white : Colors.black).withOpacity(0.6),
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const SizedBox(
                  height: 48,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                );
              }
              final reminders = snapshot.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (reminders.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'No reminders yet',
                        style: TextStyle(
                          fontSize: 13,
                          color: (widget.isDark ? Colors.white : Colors.black).withOpacity(0.5),
                        ),
                      ),
                    ),
                  ...reminders.map((n) => _buildReminderTile(n)),
                  OutlinedButton.icon(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      _openCreator();
                    },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add Reminder'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _gold,
                      side: BorderSide(color: _gold.withOpacity(0.6)),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReminderTile(UniversalNotification n) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: (widget.isDark ? Colors.white : Colors.black).withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _openCreator(n),
              borderRadius: BorderRadius.circular(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FutureBuilder<String>(
                    future: resolveUniversalNotificationDisplayTitle(n),
                    builder: (_, snap) {
                      final title = snap.hasData
                          ? snap.data!
                          : n.titleTemplate.replaceAll(RegExp(r'\{[^}]*\}'), '…');
                      return Text(
                        title.isNotEmpty ? title : 'Reminder',
                            style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: widget.isDark ? Colors.white : Colors.black87,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 2),
                  Text(
                    n.timingDescription,
                    style: TextStyle(
                      fontSize: 11,
                      color: (widget.isDark ? Colors.white : Colors.black).withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red.withOpacity(0.8)),
            onPressed: () => _deleteReminder(n),
          ),
        ],
      ),
    );
  }
}
