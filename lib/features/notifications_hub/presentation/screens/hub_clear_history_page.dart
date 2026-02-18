import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/notifications/notifications.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/theme/color_schemes.dart';

/// Page to wipe Hub History and optionally perform a full hub reset.
///
/// Data is stored in:
/// - SharedPreferences: history log
/// - Hive: Universal Notification definitions
///
/// Use "Wipe history" to clear only the log, or "Full reset" for a brand new hub.
class HubClearHistoryPage extends StatefulWidget {
  const HubClearHistoryPage({super.key});

  @override
  State<HubClearHistoryPage> createState() => _HubClearHistoryPageState();
}

class _HubClearHistoryPageState extends State<HubClearHistoryPage> {
  final NotificationHub _hub = NotificationHub();
  bool _isWorking = false;
  bool _historyCleared = false;
  bool _fullResetDone = false;

  Future<void> _wipeHistoryOnly() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Wipe history log?'),
        content: const Text(
          'Permanently removes all notification log entries from storage.\n\n'
          'Active notifications are NOT cancelled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Wipe'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isWorking = true);
    HapticFeedback.heavyImpact();

    try {
      await _hub.clearHistory();
      if (mounted) {
        setState(() {
          _isWorking = false;
          _historyCleared = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('History log wiped'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isWorking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _fullReset() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Full hub reset?'),
        content: const Text(
          'This will:\n'
          '• Wipe the history log\n'
          '• Delete all stored Universal notification definitions from the database\n'
          '• Cancel all currently pending app notifications\n'
          '• Clear tracked notification bookkeeping data',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reset everything'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isWorking = true);
    HapticFeedback.heavyImpact();

    try {
      await _hub.initialize();

      // 1. Cancel all currently pending notifications across modules.
      final notificationService = NotificationService();
      await notificationService.initialize();
      final clearedPending = await notificationService
          .cancelAllPendingNotificationsDeep(logActivity: false);

      // 2. Wipe Universal definitions from Hive.
      final repo = UniversalNotificationRepository();
      await repo.init();
      final defsBefore = (await repo.getAll()).length;
      await repo.clearAll();

      // 3. Wipe history log from SharedPreferences.
      await _hub.clearHistory();

      if (mounted) {
        setState(() {
          _isWorking = false;
          _historyCleared = true;
          _fullResetDone = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Hub reset complete: cleared $clearedPending pending, '
              '$defsBefore definitions, and history log',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isWorking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Notification Hub'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.restart_alt_rounded,
              size: 56,
              color: AppColorSchemes.primaryGold.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 20),
            Text(
              'Brand new fresh hub',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Wipe dummy and test data from the Notification Hub.\n'
              'Data is stored in SharedPreferences (history) and Hive (definitions).',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Wipe history only
            _ActionCard(
              title: 'Wipe history log',
              subtitle:
                  'Removes all log entries (scheduled, tapped, failed, cancelled)',
              icon: Icons.history_rounded,
              color: Colors.orange,
              onPressed: _isWorking ? null : _wipeHistoryOnly,
              done: _historyCleared && !_fullResetDone,
            ),
            const SizedBox(height: 12),

            // Full reset
            _ActionCard(
              title: 'Full reset',
              subtitle:
                  'Wipe history + delete all universal definitions + cancel all pending notifications',
              icon: Icons.delete_forever_rounded,
              color: Colors.red,
              onPressed: _isWorking ? null : _fullReset,
              done: _fullResetDone,
            ),
            if (_isWorking)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(child: CircularProgressIndicator.adaptive()),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;
  final bool done;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onPressed,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: color.withValues(alpha: isDark ? 0.08 : 0.05),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withValues(alpha: isDark ? 0.2 : 0.15),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (done)
                Icon(Icons.check_circle_rounded, color: Colors.green, size: 24)
              else if (onPressed != null)
                Icon(Icons.chevron_right_rounded, color: color, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
