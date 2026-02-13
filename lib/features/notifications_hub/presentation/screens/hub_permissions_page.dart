import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/notification_settings.dart';
import '../../../../core/providers/notification_settings_provider.dart';
import '../../../../core/services/android_system_status.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/color_schemes.dart';
import '../../../../core/widgets/settings_widgets.dart';

/// Permissions & device health page.
///
/// Uses the same robust permission detection as Task notification settings:
/// - permission_handler for notification, exact alarm, overlay
/// - AndroidSystemStatus for battery optimization and full-screen intent
/// Includes "Send Test Notification" to verify delivery.
class HubPermissionsPage extends ConsumerStatefulWidget {
  const HubPermissionsPage({super.key});

  @override
  ConsumerState<HubPermissionsPage> createState() =>
      _HubPermissionsPageState();
}

class _HubPermissionsPageState extends ConsumerState<HubPermissionsPage>
    with WidgetsBindingObserver {
  bool _isTestingNotification = false;
  bool _batterySaverActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationSettingsProvider.notifier).refreshPermissionStates();
      _checkBatterySaver();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      ref.read(notificationSettingsProvider.notifier).refreshPermissionStates();
      _checkBatterySaver();
    }
  }

  Future<void> _checkBatterySaver() async {
    if (!Platform.isAndroid) return;
    try {
      final status = await AndroidSystemStatus.getBatteryStatus();
      final restricted = status['isBackgroundRestricted'] as bool? ?? false;
      final ignoring = status['isIgnoringBatteryOptimizations'] as bool? ?? false;
      if (mounted) {
        setState(() => _batterySaverActive = restricted || !ignoring);
      }
    } catch (_) {
      if (mounted) setState(() => _batterySaverActive = false);
    }
  }

  int _healthScore(NotificationSettings settings) {
    var score = 0;
    if (settings.hasNotificationPermission) score += 20;
    if (settings.hasExactAlarmPermission) score += 20;
    if (settings.hasFullScreenIntentPermission) score += 15;
    if (settings.hasBatteryOptimizationExemption) score += 20;
    if (!_batterySaverActive) score += 15;
    if (settings.hasOverlayPermission) score += 10;
    return score;
  }

  Future<void> _requestPermission(String type) async {
    HapticFeedback.selectionClick();
    final notifier = ref.read(notificationSettingsProvider.notifier);

    switch (type) {
      case 'notification':
        await notifier.requestNotificationPermission();
        break;
      case 'exact_alarm':
        await notifier.requestExactAlarmPermission();
        break;
      case 'battery':
        await notifier.requestBatteryOptimizationExemption();
        await _checkBatterySaver();
        break;
      case 'overlay':
        if (Platform.isAndroid) {
          await notifier.openAppSettings();
        }
        break;
      case 'fullscreen':
        await notifier.openFullScreenIntentSettings();
        break;
    }
    await notifier.refreshPermissionStates();
    if (mounted) setState(() {});
  }

  Future<void> _openSettings(String target) async {
    final notifier = ref.read(notificationSettingsProvider.notifier);
    switch (target) {
      case 'notifications':
        await notifier.openNotificationSettings();
        break;
      case 'battery':
        await notifier.openBatteryOptimizationSettings();
        break;
      case 'app_info':
        await notifier.openAppSettings();
        break;
    }
  }

  Future<void> _sendTestNotification() async {
    if (_isTestingNotification) return;

    final settings = ref.read(notificationSettingsProvider);

    if (!settings.hasNotificationPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Grant notification permission first, then try again.',
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Grant',
              textColor: Colors.white,
              onPressed: () => _requestPermission('notification'),
            ),
          ),
        );
      }
      return;
    }

    if (!settings.notificationsEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Enable notifications in Notification Hub → Global Settings first.',
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Open',
              textColor: Colors.white,
              onPressed: () => _openSettings('notifications'),
            ),
          ),
        );
      }
      return;
    }

    setState(() => _isTestingNotification = true);
    HapticFeedback.mediumImpact();

    try {
      if (Platform.isAndroid) {
        final plugin = FlutterLocalNotificationsPlugin();
        final androidPlugin = plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin != null) {
          final granted = await androidPlugin.areNotificationsEnabled();
          if (granted != true) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                    'Notifications disabled in system settings.',
                  ),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                  action: SnackBarAction(
                    label: 'Open',
                    textColor: Colors.white,
                    onPressed: () => _openSettings('notifications'),
                  ),
                ),
              );
            }
            setState(() => _isTestingNotification = false);
            return;
          }
        }
      }

      await NotificationService().showTestNotification(
        title: 'Hub Health Test',
        body: 'If you see this, notifications are working.',
        useNotificationChannel: true,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Test notification sent. Check your status bar.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTestingNotification = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(notificationSettingsProvider);
    final theme = Theme.of(context);
    final score = _healthScore(settings);
    final isDark = theme.brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
      children: [
        _ScoreCard(score: score),
        const SizedBox(height: 20),

        SettingsSection(
          title: 'VERIFY DELIVERY',
          icon: Icons.notifications_active_rounded,
          child: Column(
            children: [
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColorSchemes.primaryGold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.send_rounded,
                    color: AppColorSchemes.primaryGold,
                    size: 22,
                  ),
                ),
                title: const Text(
                  'Send Test Notification',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                subtitle: Text(
                  'Fire a real notification now to verify permissions work',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                ),
                trailing: _isTestingNotification
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : FilledButton(
                        onPressed: _sendTestNotification,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColorSchemes.primaryGold,
                          foregroundColor: Colors.black87,
                        ),
                        child: const Text('Send'),
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        SettingsSection(
          title: 'PERMISSIONS',
          icon: Icons.security_rounded,
          child: Column(
            children: [
              _PermTile(
                title: 'Notification Permission',
                subtitle: 'Required to show any notification',
                granted: settings.hasNotificationPermission,
                onGrant: () => _requestPermission('notification'),
              ),
              _buildDivider(isDark),
              _PermTile(
                title: 'Exact Alarm Permission',
                subtitle: 'Required for precise reminder scheduling',
                granted: settings.hasExactAlarmPermission,
                onGrant: () => _requestPermission('exact_alarm'),
              ),
              _buildDivider(isDark),
              _PermTile(
                title: 'Full-Screen Intent',
                subtitle: 'Show alarm-style full-screen alerts',
                granted: settings.hasFullScreenIntentPermission,
                onGrant: () => _requestPermission('fullscreen'),
              ),
              _buildDivider(isDark),
              _PermTile(
                title: 'Battery Optimization Exempt',
                subtitle: 'Prevents system from killing reminders',
                granted: settings.hasBatteryOptimizationExemption,
                onGrant: () => _requestPermission('battery'),
              ),
              _buildDivider(isDark),
              _PermTile(
                title: 'Overlay Permission',
                subtitle: 'For in-app notification popups',
                granted: settings.hasOverlayPermission,
                onGrant: () => _requestPermission('overlay'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        SettingsSection(
          title: 'DEVICE HEALTH',
          icon: Icons.health_and_safety_rounded,
          child: Column(
            children: [
              _HealthTile(
                title: 'Battery Restrictions',
                subtitle: _batterySaverActive
                    ? 'Active – may delay or block notifications'
                    : 'Not restricting this app',
                isWarning: _batterySaverActive,
                icon: Icons.battery_alert_rounded,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        SettingsSection(
          title: 'QUICK LINKS',
          icon: Icons.link_rounded,
          child: Column(
            children: [
              SettingsTile(
                title: 'Notification Settings',
                value: 'System',
                icon: Icons.notifications_outlined,
                color: Colors.blue,
                onTap: () => _openSettings('notifications'),
              ),
              _buildDivider(isDark),
              SettingsTile(
                title: 'Battery Settings',
                value: 'System',
                icon: Icons.battery_saver_outlined,
                color: Colors.green,
                onTap: () => _openSettings('battery'),
              ),
              _buildDivider(isDark),
              SettingsTile(
                title: 'App Info',
                value: 'System',
                icon: Icons.info_outlined,
                color: Colors.orange,
                onTap: () => _openSettings('app_info'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 56,
      color: AppColorSchemes.textSecondary.withOpacity(isDark ? 0.2 : 0.1),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final int score;

  const _ScoreCard({required this.score});

  Color _color() {
    if (score >= 80) return AppColors.success;
    if (score >= 50) return Colors.amber;
    return Colors.red;
  }

  String _label() {
    if (score >= 80) return 'All Good';
    if (score >= 50) return 'Needs Attention';
    return 'Action Required';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final c = _color();
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            c.withOpacity(isDark ? 0.15 : 0.12),
            c.withOpacity(isDark ? 0.1 : 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.withOpacity(isDark ? 0.4 : 0.3), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(shape: BoxShape.circle),
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: CircularProgressIndicator(
                    value: score / 100,
                    color: c,
                    backgroundColor: c.withOpacity(0.2),
                    strokeWidth: 7,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Text(
                  '$score',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                    color: c,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Device Health Score',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _label(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: c,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
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

class _PermTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool granted;
  final VoidCallback onGrant;

  const _PermTile({
    required this.title,
    required this.subtitle,
    required this.granted,
    required this.onGrant,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = granted ? AppColors.success : theme.colorScheme.error;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: c.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          granted ? Icons.check_circle_rounded : Icons.warning_rounded,
          color: c,
          size: 22,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
      ),
      trailing: granted
          ? Icon(Icons.check_rounded, color: c, size: 20)
          : Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onGrant,
                borderRadius: BorderRadius.circular(12),
                child: Ink(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.primary.withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Grant',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _HealthTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isWarning;
  final IconData icon;

  const _HealthTile({
    required this.title,
    required this.subtitle,
    required this.isWarning,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final c = isWarning ? Colors.orange : AppColors.success;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: c.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: c, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12),
      ),
    );
  }
}
