import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/notifications/models/notification_hub_payload.dart';
import '../../../../core/notifications/models/notification_log_entry.dart';
import '../../../../core/notifications/notifications.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/theme/color_schemes.dart';
import '../../../finance/notifications/finance_notification_contract.dart';
import '../../../finance/presentation/screens/bills_subscriptions_screen.dart';
import '../../../finance/presentation/screens/debts_screen.dart';
import '../../../finance/presentation/screens/lending_screen.dart';
import 'package:life_manager/data/repositories/task_repository.dart';
import '../../../habits/data/repositories/habit_repository.dart';
import '../../../habits/presentation/widgets/habit_detail_modal.dart';
import '../../../tasks/presentation/widgets/task_detail_modal.dart';

/// Full page dedicated to failed notifications: detailed diagnostics,
/// suggested fixes, clear/delete, and test-after-fix.
class HubFailedNotificationsPage extends StatefulWidget {
  const HubFailedNotificationsPage({super.key});

  @override
  State<HubFailedNotificationsPage> createState() =>
      _HubFailedNotificationsPageState();
}

class _HubFailedNotificationsPageState extends State<HubFailedNotificationsPage> {
  final NotificationHub _hub = NotificationHub();
  int _refreshSeed = 0;
  String _timeFilter = 'today'; // today, week, all

  DateTime? get _from {
    final now = DateTime.now();
    switch (_timeFilter) {
      case 'today':
        return DateTime(now.year, now.month, now.day);
      case 'week':
        return now.subtract(const Duration(days: 7));
      case 'all':
        return null;
      default:
        return DateTime(now.year, now.month, now.day);
    }
  }

  DateTime? get _to {
    if (_timeFilter == 'all') return null;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day)
        .add(const Duration(days: 1));
  }

  Future<List<NotificationLogEntry>> _loadFailed() async {
    await _hub.initialize();
    return _hub.getHistory(
      event: NotificationLifecycleEvent.failed,
      from: _from,
      to: _to,
      limit: 500,
    );
  }

  Future<void> _refresh() async {
    HapticFeedback.mediumImpact();
    setState(() => _refreshSeed++);
  }

  Future<void> _clearOne(NotificationLogEntry entry) async {
    await _hub.deleteLogEntry(entry.id);
    if (mounted) _refresh();
    if (mounted) {
      final reason = entry.metadata['reason'] as String?;
      final message = _clearMessageForReason(reason);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _clearMessageForReason(String? reason) {
    switch (reason) {
      case 'tap_handler_error':
        return 'Stale notification cleared (entity may have been deleted)';
      case 'action_handler_error':
        return 'Action error entry cleared';
      case 'delete_notify_error':
        return 'Delete error entry cleared';
      case 'action_not_handled_by_adapter':
        return 'Unhandled action entry cleared';
      default:
        return 'Entry cleared from log';
    }
  }

  Future<void> _clearAll(List<NotificationLogEntry> entries) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Failed?'),
        content: Text(
          'Remove ${entries.length} failed notification${entries.length == 1 ? '' : 's'} from the log?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Clear', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await _hub.deleteLogEntries(entries.map((e) => e.id).toSet());
      if (mounted) _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cleared ${entries.length} failed notification${entries.length == 1 ? '' : 's'}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColorSchemes.primaryGold,
          ),
        );
      }
    }
  }

  Future<void> _testNotification() async {
    final svc = NotificationService();
    await svc.initialize();
    await svc.showTestNotification(
      title: 'Hub Health Test',
      body: 'If you see this, notifications are working after your fix.',
      useNotificationChannel: true,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Test notification sent. Check your status bar.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _openEntity(NotificationLogEntry entry) async {
    final payload = entry.payload != null
        ? NotificationHubPayload.tryParse(entry.payload!)
        : null;
    final moduleId = entry.moduleId;
    final entityId = entry.entityId;

    if (moduleId == 'task' && entityId.isNotEmpty) {
      final task = await TaskRepository().getTaskById(entityId);
      if (task != null && mounted) {
        TaskDetailModal.show(context, task: task);
      } else if (mounted) {
        _showCantOpenSnackbar('Task may have been deleted');
      }
      return;
    }

    if (moduleId == 'habit' && entityId.isNotEmpty) {
      final habit = await HabitRepository().getHabitById(entityId);
      if (habit != null && mounted) {
        HabitDetailModal.show(context, habit: habit);
      } else if (mounted) {
        _showCantOpenSnackbar('Habit may have been deleted');
      }
      return;
    }

    if (moduleId == FinanceNotificationContract.moduleId && payload != null) {
      final section = payload.extras[FinanceNotificationContract.extraSection];
      final targetId =
          payload.extras[FinanceNotificationContract.extraTargetEntityId] ??
              entityId;
      if (!mounted) return;
      if (section == FinanceNotificationContract.sectionBills) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const BillsSubscriptionsScreen(),
          ),
        );
      } else if (section == FinanceNotificationContract.sectionDebts) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DebtDetailsScreen(debtId: targetId),
          ),
        );
      } else if (section == FinanceNotificationContract.sectionLending) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LendingDetailsScreen(debtId: targetId),
          ),
        );
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const BillsSubscriptionsScreen(),
          ),
        );
      }
      return;
    }

    if (mounted) {
      _showCantOpenSnackbar('Cannot open this entity');
    }
  }

  void _showCantOpenSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Failed Notifications'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: FutureBuilder<List<NotificationLogEntry>>(
        key: ValueKey('failed-$_refreshSeed-$_timeFilter'),
        future: _loadFailed(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load',
                      style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final entries = snapshot.data ?? [];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildFilterBar(theme, isDark),
              if (entries.isNotEmpty) ...[
                _buildUsageHint(theme),
                _buildBulkActions(theme, entries),
              ],
              Expanded(
                child: entries.isEmpty
                    ? _buildEmptyState(theme, isDark)
                    : RefreshIndicator(
                        onRefresh: _refresh,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
                          itemCount: entries.length,
                          itemBuilder: (context, index) {
                            return _FailedCard(
                              entry: entries[index],
                              hub: _hub,
                              isDark: isDark,
                              theme: theme,
                              onClear: () => _clearOne(entries[index]),
                              onOpen: () => _openEntity(entries[index]),
                              onTest: _testNotification,
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUsageHint(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        'Each card shows: module (app), section (area), reason, and how to fix.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _buildFilterBar(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: theme.colorScheme.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'SHOW',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
              ),
            ),
            const SizedBox(width: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'today', label: Text('Today')),
                ButtonSegment(value: 'week', label: Text('7 days')),
                ButtonSegment(value: 'all', label: Text('All')),
              ],
              selected: {_timeFilter},
              onSelectionChanged: (Set<String> s) {
                setState(() => _timeFilter = s.first);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBulkActions(
    ThemeData theme,
    List<NotificationLogEntry> entries,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _clearAll(entries),
                icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                label: Text('Clear all (${entries.length})'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  side: BorderSide(
                    color: theme.colorScheme.error.withOpacity(0.6),
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: _testNotification,
                icon: const Icon(Icons.notifications_active_rounded, size: 18),
                label: const Text('Test notification'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColorSchemes.primaryGold,
                  foregroundColor: Colors.black87,
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 64,
              color: Colors.green.withOpacity(isDark ? 0.6 : 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              'No failed notifications',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _timeFilter == 'today'
                  ? 'Nothing has failed today.'
                  : _timeFilter == 'week'
                      ? 'No failures in the last 7 days.'
                      : 'No failed notifications in history.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _FailedCard extends StatelessWidget {
  final NotificationLogEntry entry;
  final NotificationHub hub;
  final bool isDark;
  final ThemeData theme;
  final VoidCallback onClear;
  final VoidCallback onOpen;
  final VoidCallback onTest;

  const _FailedCard({
    required this.entry,
    required this.hub,
    required this.isDark,
    required this.theme,
    required this.onClear,
    required this.onOpen,
    required this.onTest,
  });

  ({String reason, String suggestion}) _getFailureInfo() {
    final reason = entry.metadata['reason'] as String? ?? 'unknown';
    final error = entry.metadata['error'] as String? ?? '';

    switch (reason) {
      case 'module_not_registered':
        return (
          reason: 'Module not registered',
          suggestion:
              'Go to Notification Hub > Settings. The module may need a restart '
              'or reinstall. Clear these entries after fixing.',
        );
      case 'module_disabled':
        return (
          reason: 'Module disabled in Hub',
          suggestion:
              'Notification Hub > Settings > enable this module. '
              'Then re-schedule reminders from the source app.',
        );
      case 'module_notifications_disabled':
        return (
          reason: 'Notifications off for this module',
          suggestion:
              'Notification Hub > Module Settings > enable notifications for '
              'this module. Then re-schedule.',
        );
      case 'tap_handler_error':
        return (
          reason: error.isNotEmpty ? error : 'Tap handler threw an error',
          suggestion:
              'The item (task/habit/bill) may have been deleted, or the app '
              'was in a bad state. Open the item to verify it exists. If deleted, '
              'clear this entry. Then test notifications.',
        );
      case 'action_handler_error':
        return (
          reason: error.isNotEmpty ? error : 'Action button handler failed',
          suggestion:
              'Same as tap: entity may be deleted or corrupted. Open to verify, '
              'clear if gone, then test.',
        );
      case 'action_not_handled_by_adapter':
        return (
          reason: 'Adapter did not handle this action',
          suggestion:
              'The module may not support this action. Update the app or clear.',
        );
      case 'delete_notify_error':
        return (
          reason: error.isNotEmpty ? error : 'Delete/cancel handler failed',
          suggestion:
              'Entity may have been modified. Open it, remove reminders if needed, '
              'and clear this entry.',
        );
      default:
        return (
          reason: error.isNotEmpty ? error : reason,
          suggestion:
              'Schedule was rejected. Check: Permissions, Quiet Hours, module '
              'enabled, notifications on. Fix in Hub Settings, then clear and '
              're-schedule from source.',
        );
    }
  }

  /// Extracts section/source from payload extras for display.
  String? _getSectionFromPayload() {
    final payload = entry.payload;
    if (payload == null || payload.isEmpty) return null;
    final parsed = NotificationHubPayload.tryParse(payload);
    if (parsed == null) return null;
    final section = parsed.extras['section'];
    if (section != null && section.isNotEmpty) return section;
    final type = parsed.extras['type'];
    if (type != null && type.isNotEmpty) return type;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final info = _getFailureInfo();
    final moduleName = hub.moduleDisplayName(entry.moduleId);
    final section = _getSectionFromPayload();
    final sectionDisplay =
        section != null ? hub.sectionDisplayName(entry.moduleId, section) ?? section : null;
    final timeStr = DateFormat('HH:mm').format(entry.timestamp);
    final dateStr = DateFormat('MMM d').format(entry.timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerLow
            : theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.red.withOpacity(isDark ? 0.3 : 0.25),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.red,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title.isEmpty ? 'Notification' : entry.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _Chip(label: moduleName, color: AppColorSchemes.primaryGold),
                          if (sectionDisplay != null)
                            _Chip(
                              label: sectionDisplay,
                              color: Colors.teal.withOpacity(0.8),
                            ),
                          _Chip(label: '$dateStr $timeStr', color: Colors.grey),
                          if (entry.actionId != null &&
                              entry.actionId!.isNotEmpty)
                            _Chip(
                              label: 'Action: ${entry.actionId}',
                              color: Colors.amber,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(isDark ? 0.08 : 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.red.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Why it failed',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    info.reason,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'How to fix',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColorSchemes.primaryGold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    info.suggestion,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('Open entity'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColorSchemes.primaryGold,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: onTest,
                  icon: const Icon(Icons.notifications_active_rounded, size: 16),
                  label: const Text('Test notification'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text('Clear'),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 160),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
