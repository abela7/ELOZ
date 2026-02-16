import 'package:flutter/material.dart';
import 'package:app_settings/app_settings.dart';
import 'dart:io';
import '../../../../core/theme/dark_gradient.dart';
import '../../../../core/theme/color_schemes.dart';
import '../../../notifications_hub/presentation/screens/notification_hub_screen.dart';
import '../../../tasks/presentation/screens/settings/notification_settings_screen.dart';
import 'comprehensive_data_backup_screen.dart';

/// More Screen - Menu for other mini apps and settings
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: isDark
          ? DarkGradient.wrap(child: _buildContent(context))
          : _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('More')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _MenuSection(
              title: 'Trackers',
              items: [
                _MenuTile(
                  icon: Icons.mood_rounded,
                  title: 'Mood Tracker',
                  subtitle: 'Track your daily mood',
                  color: Colors.pink,
                ),
                _MenuTile(
                  icon: Icons.account_balance_wallet_rounded,
                  title: 'Finance Tracker',
                  subtitle: 'Manage your expenses',
                  color: Colors.green,
                ),
                _MenuTile(
                  icon: Icons.bedtime_rounded,
                  title: 'Sleep Tracker',
                  subtitle: 'Monitor your sleep',
                  color: Colors.indigo,
                ),
                _MenuTile(
                  icon: Icons.phone_android_rounded,
                  title: 'Screen Time',
                  subtitle: 'Track device usage',
                  color: Colors.blue,
                ),
              ],
            ),
            const SizedBox(height: 24),
            _MenuSection(
              title: 'Notifications & Alerts',
              items: [
                _MenuTile(
                  icon: Icons.hub_rounded,
                  title: 'Notification Hub',
                  subtitle: 'Manage all mini app notifications in one place',
                  color: Colors.teal,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const NotificationHubScreen(),
                    ),
                  ),
                ),
                _MenuTile(
                  icon: Icons.notifications_active_rounded,
                  title: 'Legacy Task Settings',
                  subtitle: 'Existing task notification settings screen',
                  color: AppColorSchemes.primaryGold,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const NotificationSettingsScreen(),
                    ),
                  ),
                ),
                _MenuTile(
                  icon: Icons.alarm_on_rounded,
                  title: 'System Notification Settings',
                  subtitle: 'Open Android notification settings',
                  color: Colors.orange,
                  onTap: () => _openNotificationSettings(),
                ),
                _MenuTile(
                  icon: Icons.layers_rounded,
                  title: 'Display Over Other Apps',
                  subtitle: 'Enable pop-up alerts over other apps',
                  color: Colors.purple,
                  onTap: () => _openOverlayPermission(),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _MenuSection(
              title: 'Settings',
              items: [
                _MenuTile(
                  icon: Icons.cloud_upload_rounded,
                  title: 'Data & Backup',
                  subtitle: 'Manage your data',
                  color: Colors.purple,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          const ComprehensiveDataBackupScreen(),
                    ),
                  ),
                ),
                _MenuTile(
                  icon: Icons.settings_rounded,
                  title: 'Settings',
                  subtitle: 'App preferences',
                  color: Colors.grey,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openOverlayPermission() async {
    if (Platform.isAndroid) {
      // On Samsung/Android this is controlled by system notification pop-up style
      // and the app's notification category settings (show as pop-up).
      // We send users straight to notification settings.
      await AppSettings.openAppSettings(type: AppSettingsType.notification);
    }
  }

  void _openNotificationSettings() async {
    if (Platform.isAndroid) {
      // Open notification settings for the app
      await AppSettings.openAppSettings(type: AppSettingsType.notification);
    }
  }
}

class _MenuSection extends StatelessWidget {
  final String title;
  final List<Widget> items;

  const _MenuSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        Card(child: Column(children: items)),
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(title, style: Theme.of(context).textTheme.titleSmall),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 16,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }
}
