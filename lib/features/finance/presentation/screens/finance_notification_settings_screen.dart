import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/notifications/notifications.dart';
import '../../../../core/theme/color_schemes.dart';
import '../../../../core/theme/dark_gradient.dart';
import '../../../notifications_hub/presentation/screens/notification_hub_screen.dart';
import '../../data/models/finance_notification_settings.dart';
import '../../data/services/finance_notification_settings_service.dart';
import '../../notifications/finance_notification_contract.dart';
import '../../notifications/finance_notification_scheduler.dart';

class FinanceNotificationSettingsScreen extends StatefulWidget {
  const FinanceNotificationSettingsScreen({super.key});

  @override
  State<FinanceNotificationSettingsScreen> createState() =>
      _FinanceNotificationSettingsScreenState();
}

class _FinanceNotificationSettingsScreenState
    extends State<FinanceNotificationSettingsScreen> {
  final FinanceNotificationSettingsService _settingsService =
      FinanceNotificationSettingsService();
  final FinanceNotificationScheduler _scheduler =
      FinanceNotificationScheduler();
  final NotificationHub _notificationHub = NotificationHub();

  FinanceNotificationSettings _settings = FinanceNotificationSettings.defaults;
  bool _loading = true;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _notificationHub.initialize();
    final settings = await _settingsService.load();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _loading = false;
    });
  }

  Future<void> _update(
    FinanceNotificationSettings next, {
    bool haptic = true,
  }) async {
    if (haptic) {
      HapticFeedback.selectionClick();
    }

    setState(() {
      _settings = next;
    });
    await _settingsService.save(next);
    await _applyHubBridge(next);
    if (!next.notificationsEnabled) {
      await _scheduler.clearScheduledNotifications();
    }
  }

  Future<void> _applyHubBridge(FinanceNotificationSettings settings) async {
    final moduleSettings = await _notificationHub.getModuleSettings(
      FinanceNotificationContract.moduleId,
    );
    await _notificationHub.setModuleSettings(
      FinanceNotificationContract.moduleId,
      moduleSettings.copyWith(
        notificationsEnabled: settings.notificationsEnabled,
        maxAllowedType:
            settings.overdueAlertsUseAlarm || settings.dueTodayAlertsUseAlarm
            ? null
            : 'regular',
      ),
    );
  }

  Future<void> _syncNow() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    HapticFeedback.mediumImpact();

    try {
      await _settingsService.save(_settings);
      await _applyHubBridge(_settings);
      final result = await _scheduler.syncSchedules();

      if (!mounted) return;
      final sectionBreakdown = result.scheduledBySection.entries
          .map((entry) => '${entry.key}: ${entry.value}')
          .join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Finance notifications synced: '
            '${result.scheduled} scheduled, ${result.cancelled} cleared, ${result.failed} failed'
            '${sectionBreakdown.isEmpty ? '' : ' - $sectionBreakdown'}',
          ),
          backgroundColor: AppColorSchemes.primaryGold,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync failed: $error'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
      }
    }
  }

  Future<void> _clearAllScheduled() async {
    HapticFeedback.heavyImpact();
    final cleared = await _scheduler.clearScheduledNotifications();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Cleared $cleared scheduled Finance notifications'),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  void _openHub() {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const NotificationHubScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final content = Scaffold(
      backgroundColor: isDark ? Colors.transparent : const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: const Text('Finance Notifications'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Sync now',
            onPressed: _syncing ? null : _syncNow,
            icon: _syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              children: [
                _sectionTitle('Master Control'),
                const SizedBox(height: 10),
                _card(
                  isDark,
                  child: Column(
                    children: [
                      _switchTile(
                        title: 'Enable Finance Notifications',
                        subtitle:
                            'Allow Finance mini app to send notification intents to Notification Hub.',
                        value: _settings.notificationsEnabled,
                        onChanged: (value) => _update(
                          _settings.copyWith(notificationsEnabled: value),
                        ),
                        icon: Icons.notifications_active_rounded,
                      ),
                      _divider(isDark),
                      _switchTile(
                        title: 'Sync On App Startup',
                        subtitle:
                            'Refresh Finance schedules automatically during startup maintenance.',
                        value: _settings.syncOnStartup,
                        onChanged: _settings.notificationsEnabled
                            ? (value) => _update(
                                _settings.copyWith(syncOnStartup: value),
                              )
                            : null,
                        icon: Icons.play_circle_outline_rounded,
                      ),
                      _divider(isDark),
                      _sliderRow(
                        isDark: isDark,
                        title: 'Planning Window',
                        subtitle:
                            'How far ahead Finance pre-schedules reminders. '
                            'Bills: 1 at a time (rolling). Income: up to window '
                            'days per stream.',
                        value: _settings.planningWindowDays.toDouble(),
                        min: 7,
                        max: 365,
                        label: '${_settings.planningWindowDays} days',
                        onChanged: _settings.notificationsEnabled
                            ? (value) => _update(
                                _settings.copyWith(
                                  planningWindowDays: value.round(),
                                ),
                                haptic: false,
                              )
                            : null,
                      ),
                      _divider(isDark),
                      _hourSelector(isDark),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                _sectionTitle('Finance Sections'),
                const SizedBox(height: 10),
                _card(
                  isDark,
                  child: Column(
                    children: [
                      _switchTile(
                        title: 'Bills & Subscriptions',
                        subtitle: 'Due reminders and overdue alerts.',
                        value: _settings.billsEnabled,
                        onChanged: _settings.notificationsEnabled
                            ? (value) => _update(
                                _settings.copyWith(billsEnabled: value),
                              )
                            : null,
                        icon: Icons.receipt_long_rounded,
                      ),
                      _divider(isDark),
                      _switchTile(
                        title: 'Debt Payments',
                        subtitle: 'Debts you owe and payment due reminders.',
                        value: _settings.debtsEnabled,
                        onChanged: _settings.notificationsEnabled
                            ? (value) => _update(
                                _settings.copyWith(debtsEnabled: value),
                              )
                            : null,
                        icon: Icons.account_balance_rounded,
                      ),
                      _divider(isDark),
                      _switchTile(
                        title: 'Lending Collections',
                        subtitle: 'Money owed to you and collection reminders.',
                        value: _settings.lendingEnabled,
                        onChanged: _settings.notificationsEnabled
                            ? (value) => _update(
                                _settings.copyWith(lendingEnabled: value),
                              )
                            : null,
                        icon: Icons.trending_up_rounded,
                      ),
                      _divider(isDark),
                      _switchTile(
                        title: 'Budget Alerts',
                        subtitle: 'Threshold and period-end budget reminders.',
                        value: _settings.budgetsEnabled,
                        onChanged: _settings.notificationsEnabled
                            ? (value) => _update(
                                _settings.copyWith(budgetsEnabled: value),
                              )
                            : null,
                        icon: Icons.pie_chart_rounded,
                      ),
                      _divider(isDark),
                      _switchTile(
                        title: 'Savings Goal Deadlines',
                        subtitle:
                            'Goal target-date reminders and overdue nudges.',
                        value: _settings.savingsGoalsEnabled,
                        onChanged: _settings.notificationsEnabled
                            ? (value) => _update(
                                _settings.copyWith(savingsGoalsEnabled: value),
                              )
                            : null,
                        icon: Icons.savings_rounded,
                      ),
                      _divider(isDark),
                      _switchTile(
                        title: 'Recurring Income',
                        subtitle: 'Upcoming expected-income reminders.',
                        value: _settings.recurringIncomeEnabled,
                        onChanged: _settings.notificationsEnabled
                            ? (value) => _update(
                                _settings.copyWith(
                                  recurringIncomeEnabled: value,
                                ),
                              )
                            : null,
                        icon: Icons.repeat_rounded,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                _sectionTitle('Priority Routing'),
                const SizedBox(height: 10),
                _card(
                  isDark,
                  child: Column(
                    children: [
                      _switchTile(
                        title: 'Overdue Alerts Use Alarm Channel',
                        subtitle:
                            'Allow overdue payment alerts to use high-priority alarm delivery.',
                        value: _settings.overdueAlertsUseAlarm,
                        onChanged: _settings.notificationsEnabled
                            ? (value) => _update(
                                _settings.copyWith(
                                  overdueAlertsUseAlarm: value,
                                ),
                              )
                            : null,
                        icon: Icons.alarm_rounded,
                      ),
                      _divider(isDark),
                      _switchTile(
                        title: 'Due-Today Alerts Use Alarm Channel',
                        subtitle:
                            'Promote same-day deadlines to high-priority channel.',
                        value: _settings.dueTodayAlertsUseAlarm,
                        onChanged: _settings.notificationsEnabled
                            ? (value) => _update(
                                _settings.copyWith(
                                  dueTodayAlertsUseAlarm: value,
                                ),
                              )
                            : null,
                        icon: Icons.notifications_rounded,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _actionButton(
                  title: 'Sync Finance Schedules Now',
                  subtitle:
                      'Cancel stale reminders and re-register all active Finance notifications.',
                  icon: Icons.sync_rounded,
                  color: AppColorSchemes.primaryGold,
                  onTap: _syncing ? null : _syncNow,
                ),
                const SizedBox(height: 10),
                _actionButton(
                  title: 'Open Notification Hub',
                  subtitle:
                      'Review hub-wide history, channels, and module integrations.',
                  icon: Icons.hub_rounded,
                  color: Colors.teal,
                  onTap: _openHub,
                ),
                const SizedBox(height: 10),
                _actionButton(
                  title: 'Clear Scheduled Finance Notifications',
                  subtitle:
                      'Remove every pending Finance notification from Notification Hub.',
                  icon: Icons.delete_sweep_rounded,
                  color: Theme.of(context).colorScheme.error,
                  onTap: _clearAllScheduled,
                ),
              ],
            ),
    );

    return isDark ? DarkGradient.wrap(child: content) : content;
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: AppColorSchemes.primaryGold,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _card(bool isDark, {required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: child,
    );
  }

  Widget _divider(bool isDark) {
    return Divider(
      height: 1,
      indent: 58,
      endIndent: 16,
      color: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.08),
    );
  }

  Widget _switchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
    required IconData icon,
  }) {
    final isDisabled = onChanged == null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Opacity(
      opacity: isDisabled ? 0.55 : 1,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColorSchemes.primaryGold.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: AppColorSchemes.primaryGold),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white70 : Colors.black54,
            height: 1.25,
          ),
        ),
        trailing: Switch.adaptive(
          value: value,
          activeTrackColor: AppColorSchemes.primaryGold,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _sliderRow({
    required bool isDark,
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required String label,
    required ValueChanged<double>? onChanged,
  }) {
    return Opacity(
      opacity: onChanged == null ? 0.55 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            Slider(
              value: value,
              min: min,
              max: max,
              divisions: ((max - min) / 7).round(),
              label: label,
              activeColor: AppColorSchemes.primaryGold,
              onChanged: onChanged,
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColorSchemes.primaryGold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hourSelector(bool isDark) {
    final items = List<DropdownMenuItem<int>>.generate(18, (index) {
      final hour = index + 5;
      final labelHour = hour == 12
          ? 12
          : hour > 12
          ? hour - 12
          : hour;
      final suffix = hour >= 12 ? 'PM' : 'AM';
      return DropdownMenuItem<int>(
        value: hour,
        child: Text('$labelHour:00 $suffix'),
      );
    });

    return Opacity(
      opacity: _settings.notificationsEnabled ? 1 : 0.55,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColorSchemes.primaryGold.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.access_time_rounded,
            size: 20,
            color: AppColorSchemes.primaryGold,
          ),
        ),
        title: Text(
          'Default Reminder Time',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Text(
          'Time used when an item does not define an exact reminder hour.',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        trailing: DropdownButton<int>(
          value: _settings.defaultReminderHour,
          items: items,
          onChanged: _settings.notificationsEnabled
              ? (hour) {
                  if (hour == null) return;
                  _update(_settings.copyWith(defaultReminderHour: hour));
                }
              : null,
        ),
      ),
    );
  }

  Widget _actionButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
