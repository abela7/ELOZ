import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/notifications/models/notification_hub_modules.dart';
import '../../../../core/notifications/notification_hub.dart';
import '../../../../core/notifications/services/universal_notification_repository.dart';
import '../../../../core/theme/dark_gradient.dart';
import '../providers/sleep_providers.dart';
import 'manage_sleep_factors_screen.dart';
import 'sleep_target_screen.dart';
import 'manage_sleep_templates_screen.dart';
import 'wind_down_settings_screen.dart';
import 'sleep_statistics_screen.dart';
import 'sleep_debt_report_screen.dart';

/// Sleep Settings Screen - Configuration and management for sleep tracking
class SleepSettingsScreen extends ConsumerStatefulWidget {
  const SleepSettingsScreen({super.key});

  @override
  ConsumerState<SleepSettingsScreen> createState() => _SleepSettingsScreenState();
}

class _SleepSettingsScreenState extends ConsumerState<SleepSettingsScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: isDark
          ? DarkGradient.wrap(child: _buildContent(context, isDark))
          : _buildContent(context, isDark),
    );
  }

  Widget _buildContent(BuildContext context, bool isDark) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Sleep Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Sleep Target Section
                _buildSectionHeader(context, isDark, 'Sleep Target'),
                const SizedBox(height: 16),
                _buildSettingCard(
                  context,
                  isDark,
                  title: 'Target & Thresholds',
                  subtitle: 'Set your sleep target and status ranges (Dangerous, Poor, Healthy, Overslept)',
                  icon: Icons.flag_rounded,
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const SleepTargetScreen()),
                  ),
                ),

                const SizedBox(height: 32),

                // Pre-Sleep Factors Section
                _buildSectionHeader(context, isDark, 'Pre-Sleep Factors'),
                const SizedBox(height: 16),
                _buildSettingCard(
                  context,
                  isDark,
                  title: 'Manage Factors',
                  subtitle: 'Track what affects your sleep quality',
                  icon: Icons.psychology_rounded,
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const ManageSleepFactorsScreen()),
                  ),
                ),

                const SizedBox(height: 32),

                // Sleep Templates Section
                _buildSectionHeader(context, isDark, 'Sleep Templates'),
                const SizedBox(height: 16),
                _buildSettingCard(
                  context,
                  isDark,
                  title: 'Manage Templates',
                  subtitle: 'Create quick presets for fast logging',
                  icon: Icons.library_books_rounded,
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const ManageSleepTemplatesScreen()),
                  ),
                ),

                const SizedBox(height: 32),

                // Reminders & Notifications Section
                _buildSectionHeader(context, isDark, 'Reminders & Notifications'),
                const SizedBox(height: 16),
                _buildSettingCard(
                  context,
                  isDark,
                  title: 'Wind-Down Reminders',
                  subtitle: 'Set bedtime per day, get notified before sleep',
                  icon: Icons.bedtime_rounded,
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const WindDownSettingsScreen(),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Statistics & Reports Section
                _buildSectionHeader(context, isDark, 'Statistics & Reports'),
                const SizedBox(height: 16),
                _buildSettingCard(
                  context,
                  isDark,
                  title: 'View Statistics',
                  subtitle: 'Detailed sleep analytics and insights',
                  icon: Icons.assessment_rounded,
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const SleepStatisticsScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildSettingCard(
                  context,
                  isDark,
                  title: 'Sleep Debt Report',
                  subtitle: 'Daily, weekly, monthly, yearly and all-time debt',
                  icon: Icons.trending_down_rounded,
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const SleepDebtReportScreen(),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // App Settings Section
                _buildSectionHeader(context, isDark, 'App Settings'),
                const SizedBox(height: 16),
                _buildSettingCard(
                  context,
                  isDark,
                  title: 'Reset All Data',
                  subtitle: 'Clear all sleep records, factors, templates, and settings',
                  icon: Icons.delete_forever_rounded,
                  iconColor: Colors.red,
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () => _showResetConfirmation(context, isDark),
                ),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, bool isDark, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: const Color(0xFFCDAF56),
            fontSize: 14,
            letterSpacing: 0.5,
          ),
    );
  }

  Widget _buildSettingCard(
    BuildContext context,
    bool isDark, {
    required String title,
    required String subtitle,
    required IconData icon,
    Color? iconColor,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D3139) : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (iconColor ?? const Color(0xFFCDAF56)).withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (iconColor ?? const Color(0xFFCDAF56)).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor ?? const Color(0xFFCDAF56),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isDark ? const Color(0xFFBDBDBD) : const Color(0xFF6E6E6E),
                            ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showResetConfirmation(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF2D3139) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.warning_rounded,
                color: Colors.red,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Reset All Data?'),
            ),
          ],
        ),
        content: Text(
          'This will permanently delete all sleep records, factors, templates, reminders, and settings. The app will be reset to a fresh state. This cannot be undone.',
          style: TextStyle(
            color: isDark ? const Color(0xFFBDBDBD) : const Color(0xFF6E6E6E),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.grey[700],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              
              try {
                // Show loading
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => AlertDialog(
                    backgroundColor: isDark ? const Color(0xFF2D3139) : Colors.white,
                    content: Row(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(width: 20),
                        Text(
                          'Resetting data...',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                );

                final hub = NotificationHub();
                await hub.initialize();

                // 1. Delete all sleep records (batch delete avoids loading all into memory)
                final recordRepository = ref.read(sleepRecordRepositoryProvider);
                final ids = await recordRepository.getAllIds();
                await recordRepository.deleteBatch(ids);

                // 2. Reset factors and templates to defaults
                await ref.read(sleepFactorRepositoryProvider).resetToDefaults();
                await ref.read(sleepTemplateRepositoryProvider).resetToDefaults();

                // 3. Clear all sleep-related SharedPreferences
                final prefs = await SharedPreferences.getInstance();
                final sleepKeys = prefs.getKeys().where((k) => k.startsWith('sleep_')).toList();
                for (final key in sleepKeys) {
                  await prefs.remove(key);
                }

                // 4. Delete sleep reminder configs from universal notification repository
                final universalRepo = UniversalNotificationRepository();
                await universalRepo.init();
                final sleepNotifs =
                    await universalRepo.getAll(moduleId: NotificationHubModuleIds.sleep);
                for (final n in sleepNotifs) {
                  await universalRepo.delete(n.id);
                }

                // 5. Cancel all scheduled sleep notifications (legacy + hub)
                await ref.read(sleepReminderServiceProvider).cancelTrackedReminders();
                await hub.cancelForModule(moduleId: 'sleep_reminder');
                await hub.cancelForModule(moduleId: NotificationHubModuleIds.sleep);

                Navigator.of(context).pop(); // Close loading

                if (mounted) {
                  ref.invalidate(sleepRecordsProvider);
                  ref.invalidate(sleepRecordsStreamProvider);
                  ref.invalidate(sleepFactorsStreamProvider);
                  ref.invalidate(sleepFactorsProvider);
                  ref.invalidate(sleepTemplatesStreamProvider);
                  ref.invalidate(sleepTemplatesProvider);
                  ref.invalidate(defaultSleepTemplateProvider);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'All sleep data has been reset. The app is fresh and ready to use.',
                      ),
                      backgroundColor: Color(0xFF4CAF50),
                    ),
                  );

                  _loadSettings();
                }
              } catch (e) {
                Navigator.of(context).pop(); // Close loading
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error resetting data: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

}
