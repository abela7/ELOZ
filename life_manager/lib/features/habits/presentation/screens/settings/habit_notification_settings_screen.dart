import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/models/pending_notification_info.dart';
import '../../../../../core/notifications/notifications.dart';
import '../../../../../core/services/alarm_service.dart';
import '../../../../../core/services/notification_service.dart';
import '../../../../../core/services/reminder_manager.dart';
import '../../../../../core/theme/color_schemes.dart';
import '../../../../../core/theme/dark_gradient.dart';
import '../../../../../core/theme/typography.dart';
import '../../../../../core/widgets/settings_widgets.dart';
import '../../../../../core/widgets/sheet_dismiss_on_overscroll.dart';
import '../../../data/models/habit_notification_settings.dart';
import '../../../providers/habit_notification_settings_provider.dart';
import '../../widgets/habit_sound_picker.dart';
import '../../widgets/habit_template_builder.dart';
import '../../widgets/habit_vibration_picker.dart';
import '../../../data/repositories/habit_repository.dart';
import 'habit_notification_diagnostics_screen.dart';

class HabitNotificationSettingsScreen extends ConsumerStatefulWidget {
  final int initialTab;

  const HabitNotificationSettingsScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<HabitNotificationSettingsScreen> createState() =>
      _HabitNotificationSettingsScreenState();
}

class _HabitNotificationSettingsScreenState
    extends ConsumerState<HabitNotificationSettingsScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool _isTestingNotification = false;
  bool _isTestingSpecialNotification = false;
  int _pendingNotificationsCount = 0;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: 3, vsync: this, initialIndex: widget.initialTab);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(habitNotificationSettingsProvider.notifier).refreshPermissionStates();
      _loadPendingNotificationsCount();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      ref.read(habitNotificationSettingsProvider.notifier).refreshPermissionStates();
      _loadPendingNotificationsCount();
    }
  }

  Future<void> _loadPendingNotificationsCount() async {
    try {
      final count = await _countPendingHabitNotifications();
      if (mounted) {
        setState(() => _pendingNotificationsCount = count);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _pendingNotificationsCount = 0);
      }
    }
  }

  Future<int> _countPendingHabitNotifications() async {
    final all = await ReminderManager().getDetailedPendingNotifications();
    return all.where(_isHabitPendingNotification).length;
  }

  bool _isHabitPendingNotification(PendingNotificationInfo info) {
    if (info.type == NotificationHubModuleIds.habit) {
      return true;
    }
    final payload = info.payload;
    if (payload != null &&
        payload.startsWith('${NotificationHubModuleIds.habit}|')) {
      return true;
    }
    final parsed = NotificationHubPayload.tryParse(payload);
    if (parsed?.moduleId == NotificationHubModuleIds.habit) {
      return true;
    }
    return info.channelKey.startsWith('habit_');
  }

  Future<int> _clearAllPendingHabitNotifications() async {
    final reminderManager = ReminderManager();
    await reminderManager.cancelAllHabitReminders();

    final allPending = await reminderManager.getDetailedPendingNotifications();
    final pendingHabitNotifications = allPending
        .where(_isHabitPendingNotification)
        .toList();

    for (final info in pendingHabitNotifications) {
      await reminderManager.cancelPendingNotificationById(
        notificationId: info.id,
        entityId: info.entityId.isEmpty ? null : info.entityId,
      );
    }

    await NotificationHub().cancelForModule(
      moduleId: NotificationHubModuleIds.habit,
    );

    if (pendingHabitNotifications.isNotEmpty) {
      final habitRepo = HabitRepository();
      final habits = await habitRepo.getAllHabits(includeArchived: true);
      final habitIds = habits.map((h) => h.id).toSet();
      final orphanEntityIds = pendingHabitNotifications
          .map((n) => n.entityId.trim())
          .where((id) => id.isNotEmpty && !habitIds.contains(id))
          .toSet();

      if (orphanEntityIds.isNotEmpty) {
        final universalRepo = UniversalNotificationRepository();
        for (final entityId in orphanEntityIds) {
          await universalRepo.deleteByEntity(entityId);
        }
      }
    }

    return pendingHabitNotifications.length;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = ref.watch(habitNotificationSettingsProvider);
    final notifier = ref.read(habitNotificationSettingsProvider.notifier);

    final content = _buildContent(context, isDark, settings, notifier);
    return isDark ? DarkGradient.wrap(child: content) : content;
  }

  Widget _buildContent(
    BuildContext context,
    bool isDark,
    HabitNotificationSettings settings,
    HabitNotificationSettingsNotifier notifier,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Habit Notifications',
          style: AppTypography.titleMedium(context).copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: colorScheme.onSurface,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: colorScheme.onSurface,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
            onPressed: () {
              notifier.refreshPermissionStates();
              _loadPendingNotificationsCount();
            },
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColorSchemes.primaryGold,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
          indicatorColor: AppColorSchemes.primaryGold,
          tabs: const [
            Tab(text: 'General'),
            Tab(text: 'Habit Defaults'),
            Tab(text: 'Advanced'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGeneralTab(context, isDark, settings, notifier),
          _buildHabitDefaultsTab(context, isDark, settings, notifier),
          _buildAdvancedTab(context, isDark, settings, notifier),
        ],
      ),
    );
  }

  Widget _buildGeneralTab(
    BuildContext context,
    bool isDark,
    HabitNotificationSettings settings,
    HabitNotificationSettingsNotifier notifier,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final infoColor = colorScheme.secondary;
    final successColor = AppColorSchemes.success;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      physics: const BouncingScrollPhysics(),
      children: [
        if (!notifier.hasAllTrackedPermissions) ...[
          SettingsSection(
            title: 'SYSTEM PERMISSIONS',
            icon: Icons.security_rounded,
            child: _buildPermissionStatus(context, settings, notifier),
          ),
          const SizedBox(height: 20),
        ],
        SettingsSection(
          title: 'GENERAL',
          icon: Icons.tune_rounded,
          child: Column(
            children: [
              SettingsToggle(
                title: 'Global Notifications',
                subtitle: 'Enable or disable all habit reminders',
                value: settings.notificationsEnabled,
                icon: Icons.notifications_active_rounded,
                color: AppColorSchemes.primaryGold,
                onChanged: (val) => notifier.setNotificationsEnabled(val),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SettingsSection(
          title: 'SOUND & FEEDBACK',
          icon: Icons.volume_up_rounded,
          child: Column(
            children: [
              SettingsToggle(
                title: 'Sound',
                subtitle: 'Play alert sounds',
                value: settings.soundEnabled,
                icon: Icons.music_note_rounded,
                color: infoColor,
                onChanged: (val) => notifier.setSoundEnabled(val),
              ),
              if (settings.soundEnabled) ...[
                _buildDivider(isDark),
                SettingsTile(
                  title: 'Notification Tone',
                  value: HabitNotificationSettings.getSoundDisplayName(settings.defaultSound),
                  icon: Icons.graphic_eq_rounded,
                  color: infoColor,
                  onTap: () => notifier.pickDefaultSoundFromSystem(),
                ),
                _buildDivider(isDark),
                SettingsTile(
                  title: 'Sound Channel',
                  value: HabitNotificationSettings.getAudioStreamDisplayName(
                    settings.notificationAudioStream,
                  ),
                  icon: Icons.volume_up_rounded,
                  color: infoColor,
                  onTap: () => _showAudioStreamPicker(context, settings, notifier),
                ),
              ],
              _buildDivider(isDark),
              SettingsToggle(
                title: 'Haptic Vibration',
                subtitle: 'Tactile feedback for alerts',
                value: settings.vibrationEnabled,
                icon: Icons.vibration_rounded,
                color: successColor,
                onChanged: (val) => notifier.setVibrationEnabled(val),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Builder(
          builder: (context) {
            final isBlockedByQuietHours =
                settings.quietHoursEnabled && !settings.allowSpecialDuringQuietHours;
            final needsFullScreenPermission =
                !settings.hasFullScreenIntentPermission && settings.specialHabitAlarmMode;
            final needsOverlayPermission =
                Platform.isAndroid && settings.specialHabitAlarmMode && !settings.hasOverlayPermission;

            return SettingsSection(
              title: 'SPECIAL HABIT ALERTS',
              icon: Icons.star_rounded,
              child: Column(
                children: [
                  if (needsOverlayPermission) ...[
                    _buildWarningBanner(
                      context,
                      icon: Icons.layers_rounded,
                      color: AppColorSchemes.warning,
                      message:
                          'Enable “Appear on top” for Life Manager so the alarm UI can show instantly.',
                      onTap: () => notifier.openAppSettings(),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (needsFullScreenPermission) ...[
                    _buildWarningBanner(
                      context,
                      icon: Icons.warning_rounded,
                      color: AppColorSchemes.error,
                      message:
                          'Full-screen intent permission required for lock screen alarms.',
                      onTap: () => notifier.openFullScreenIntentSettings(),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (isBlockedByQuietHours) ...[
                    _buildInfoBanner(
                      context,
                      icon: Icons.info_outline_rounded,
                      color: AppColorSchemes.warning,
                      message:
                          'Special habit alerts are blocked during quiet hours. Enable them in Quiet Hours.',
                    ),
                    const SizedBox(height: 12),
                  ],
                  SettingsToggle(
                    title: 'Always Use Alarm Channel',
                    subtitle: isBlockedByQuietHours
                        ? 'Blocked by Quiet Hours settings'
                        : 'Special habits bypass silent mode & DND',
                    value: settings.alwaysUseAlarmForSpecialHabits,
                    icon: Icons.alarm_rounded,
                    color: isBlockedByQuietHours
                        ? colorScheme.onSurfaceVariant
                        : AppColorSchemes.error,
                    onChanged: isBlockedByQuietHours
                        ? null
                        : (val) => notifier.setAlwaysUseAlarmForSpecialHabits(val),
                  ),
                  if (settings.alwaysUseAlarmForSpecialHabits && !isBlockedByQuietHours) ...[
                    _buildDivider(isDark),
                    SettingsTile(
                      title: 'Special Habit Tone',
                      value: HabitNotificationSettings.getSoundDisplayName(
                        settings.specialHabitSound,
                      ),
                      icon: Icons.graphic_eq_rounded,
                      color: AppColorSchemes.warning,
                      onTap: () async {
                        final selected = await HabitSoundPicker.show(
                          context,
                          settings.specialHabitSound,
                        );
                        if (selected != null) {
                          await notifier.setSpecialHabitSound(selected);
                        }
                      },
                    ),
                    _buildDivider(isDark),
                    SettingsTile(
                      title: 'Vibration Pattern',
                      value: HabitNotificationSettings.getVibrationDisplayName(
                        settings.specialHabitVibrationPattern,
                      ),
                      icon: Icons.vibration_rounded,
                      color: AppColorSchemes.warning,
                      onTap: () async {
                        final selected = await HabitVibrationPicker.show(
                          context,
                          settings.specialHabitVibrationPattern,
                        );
                        if (selected != null) {
                          await notifier.setSpecialHabitVibrationPattern(selected);
                        }
                      },
                    ),
                    _buildDivider(isDark),
                    SettingsToggle(
                      title: 'Alarm Mode',
                      subtitle: 'Wake screen & show alarm popup',
                      value: settings.specialHabitAlarmMode,
                      icon: Icons.fullscreen_rounded,
                      color: AppColorSchemes.error,
                      onChanged: (val) => notifier.setSpecialHabitAlarmMode(val),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            children: [
              _buildActionButton(
                context,
                label: 'Test Habit Notification',
                icon: Icons.notification_add_rounded,
                isLoading: _isTestingNotification,
                onPressed: () => _testNotification(context),
              ),
              const SizedBox(height: 12),
              _buildActionButton(
                context,
                label: 'Test Special Habit Alert',
                icon: Icons.star_rounded,
                isLoading: _isTestingSpecialNotification,
                onPressed: () => _testSpecialNotification(context),
              ),
              const SizedBox(height: 12),
              _buildActionButton(
                context,
                label: 'Reset to Defaults',
                icon: Icons.refresh_rounded,
                isSecondary: true,
                onPressed: () => _showResetConfirmation(context, notifier),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildHabitDefaultsTab(
    BuildContext context,
    bool isDark,
    HabitNotificationSettings settings,
    HabitNotificationSettingsNotifier notifier,
  ) {
    final theme = Theme.of(context);
    final accentPurple = theme.colorScheme.tertiary;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      physics: const BouncingScrollPhysics(),
      children: [
        SettingsSection(
          title: 'DEFAULT REMINDER',
          icon: Icons.access_time_rounded,
          child: Column(
            children: [
              SettingsTile(
                title: 'Default Reminder Time',
                value: HabitNotificationSettings.getReminderTimeDisplayName(
                  settings.defaultHabitReminderTime,
                ),
                icon: Icons.notifications_active_rounded,
                color: AppColorSchemes.primaryGold,
                onTap: () => _showReminderTimePicker(context, settings, notifier),
              ),
              _buildDivider(isDark),
              SettingsTile(
                title: 'Morning Reminder Hour',
                value: HabitNotificationSettings.formatHourToTime(
                  settings.earlyMorningReminderHour,
                ),
                icon: Icons.wb_sunny_rounded,
                color: AppColorSchemes.warning,
                onTap: () => _showMorningHourPicker(context, settings, notifier),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SettingsSection(
          title: 'SNOOZE OPTIONS',
          icon: Icons.snooze_rounded,
          child: Column(
            children: [
              SettingsTile(
                title: 'Default Snooze Duration',
                value: HabitNotificationSettings.getSnoozeDurationDisplayName(
                  settings.defaultSnoozeDuration,
                ),
                icon: Icons.timer_rounded,
                color: accentPurple,
                onTap: () => _showSnoozeDurationPicker(context, settings, notifier),
              ),
              _buildDivider(isDark),
              SettingsTile(
                title: 'Max Snooze Count',
                value: settings.maxSnoozeCount == 999
                    ? 'Unlimited'
                    : '${settings.maxSnoozeCount} times',
                icon: Icons.repeat_rounded,
                color: accentPurple,
                onTap: () => _showMaxSnoozePicker(context, settings, notifier),
              ),
              _buildDivider(isDark),
              SettingsToggle(
                title: 'Smart Snooze',
                subtitle: 'Adjust snooze for habit streaks',
                value: settings.smartSnooze,
                icon: Icons.auto_fix_high_rounded,
                color: AppColorSchemes.success,
                onChanged: (val) => notifier.setSmartSnooze(val),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SettingsSection(
          title: 'SCHEDULING WINDOW',
          icon: Icons.date_range_rounded,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rolling Window Size',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'How many days to pre-schedule reminders.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    IconButton(
                      onPressed: settings.rollingWindowDays > 1
                          ? () => notifier.setRollingWindowDays(
                                settings.rollingWindowDays - 1,
                              )
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text(
                      '${settings.rollingWindowDays} days',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    IconButton(
                      onPressed: settings.rollingWindowDays < 30
                          ? () => notifier.setRollingWindowDays(
                                settings.rollingWindowDays + 1,
                              )
                          : null,
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildAdvancedTab(
    BuildContext context,
    bool isDark,
    HabitNotificationSettings settings,
    HabitNotificationSettingsNotifier notifier,
  ) {
    final theme = Theme.of(context);
    final accentPurple = theme.colorScheme.tertiary;
    final accentBlue = theme.colorScheme.secondary;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      physics: const BouncingScrollPhysics(),
      children: [
        SettingsSection(
          title: 'QUIET HOURS',
          icon: Icons.bedtime_rounded,
          child: Column(
            children: [
              SettingsToggle(
                title: 'Quiet Hours',
                subtitle: 'Silence alerts during rest',
                value: settings.quietHoursEnabled,
                icon: Icons.nightlight_rounded,
                color: accentPurple,
                onChanged: (val) => notifier.setQuietHoursEnabled(val),
              ),
              if (settings.quietHoursEnabled) ...[
                _buildDivider(isDark),
                SettingsTile(
                  title: 'Schedule',
                  value:
                      '${HabitNotificationSettings.formatMinutesToTime(settings.quietHoursStart)} - '
                      '${HabitNotificationSettings.formatMinutesToTime(settings.quietHoursEnd)}',
                  icon: Icons.schedule_rounded,
                  color: accentPurple,
                  onTap: () => _showQuietHoursPicker(context, settings, notifier),
                ),
                _buildDivider(isDark),
                SettingsTile(
                  title: 'Active Days',
                  value: settings.quietHoursDays.isEmpty
                      ? 'Every day'
                      : settings.quietHoursDays
                          .map((d) => HabitNotificationSettings.getWeekdayShortName(d))
                          .join(', '),
                  icon: Icons.calendar_today_rounded,
                  color: accentPurple,
                  onTap: () => _showQuietHoursDaysPicker(context, settings, notifier),
                ),
                _buildDivider(isDark),
                SettingsToggle(
                  title: 'Allow Special Habit Alerts',
                  subtitle: 'Special habits bypass quiet hours',
                  value: settings.allowSpecialDuringQuietHours,
                  icon: Icons.star_rounded,
                  color: AppColorSchemes.warning,
                  onChanged: (val) => notifier.setAllowSpecialDuringQuietHours(val),
                  compact: true,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        SettingsSection(
          title: 'DISPLAY OPTIONS',
          icon: Icons.visibility_rounded,
          child: Column(
            children: [
              SettingsToggle(
                title: 'Show on Lock Screen',
                subtitle: 'Display notifications when locked',
                value: settings.showOnLockScreen,
                icon: Icons.lock_open_rounded,
                color: accentBlue,
                onChanged: (val) => notifier.setShowOnLockScreen(val),
              ),
              _buildDivider(isDark),
              SettingsToggle(
                title: 'LED Indicator',
                subtitle: 'Flash LED light for notifications',
                value: settings.ledEnabled,
                icon: Icons.lightbulb_outline_rounded,
                color: AppColorSchemes.success,
                onChanged: (val) => notifier.setLedEnabled(val),
              ),
              _buildDivider(isDark),
              SettingsToggle(
                title: 'Persistent Notifications',
                subtitle: 'Keep notifications until dismissed',
                value: settings.persistentNotifications,
                icon: Icons.push_pin_rounded,
                color: accentPurple,
                onChanged: (val) => notifier.setPersistentNotifications(val),
              ),
              _buildDivider(isDark),
              SettingsToggle(
                title: 'Wake Screen',
                subtitle: 'Wake device for alerts',
                value: settings.wakeScreen,
                icon: Icons.screen_lock_portrait_rounded,
                color: accentBlue,
                onChanged: (val) => notifier.setWakeScreen(val),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SettingsSection(
          title: 'CONTENT OPTIONS',
          icon: Icons.article_rounded,
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColorSchemes.primaryGold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.dashboard_customize_rounded,
                    color: AppColorSchemes.primaryGold,
                    size: 22,
                  ),
                ),
                title: const Text(
                  'Notification Designer',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: Text(
                  'Customize what information to show',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColorSchemes.primaryGold,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'DESIGN',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
                onTap: () => HabitTemplateBuilder.show(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SettingsSection(
          title: 'STATISTICS & DEBUG',
          icon: Icons.analytics_rounded,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildStatRow(
                  context,
                  'Pending Notifications',
                  '$_pendingNotificationsCount',
                  Icons.schedule_rounded,
                ),
                const SizedBox(height: 12),
                _buildStatRow(
                  context,
                  'Permissions Granted',
                  '${notifier.grantedPermissionCount}/${notifier.totalPermissionCount}',
                  Icons.verified_rounded,
                ),
                const SizedBox(height: 12),
                _buildStatRow(
                  context,
                  'Quiet Hours Active',
                  settings.isInQuietHours() ? 'Yes' : 'No',
                  Icons.bedtime_rounded,
                ),
                const SizedBox(height: 12),
                _buildStatRow(
                  context,
                  'Global Toggle',
                  settings.notificationsEnabled ? 'ON' : 'OFF',
                  Icons.power_settings_new_rounded,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HabitNotificationDiagnosticsScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.info_outline_rounded, size: 18),
                    label: const Text('Habit Diagnostics'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.secondary,
                      side: BorderSide(color: theme.colorScheme.secondary.withOpacity(0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showCancelAllConfirmation(context),
                    icon: const Icon(Icons.clear_all_rounded, size: 18),
                    label: const Text('Cancel All Habit Notifications'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColorSchemes.error,
                      side: const BorderSide(color: AppColorSchemes.error),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 40),
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

  Widget _buildPermissionStatus(
    BuildContext context,
    HabitNotificationSettings settings,
    HabitNotificationSettingsNotifier notifier,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: notifier.permissionStatusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  notifier.hasAllCriticalPermissions
                      ? Icons.check_circle_rounded
                      : Icons.warning_rounded,
                  color: notifier.permissionStatusColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notifier.permissionStatusSummary,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: notifier.permissionStatusColor,
                        ),
                      ),
                      Text(
                        '${notifier.grantedPermissionCount}/${notifier.totalPermissionCount} permissions granted',
                        style: TextStyle(
                          color: notifier.permissionStatusColor.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => notifier.openAppSettings(),
                  icon: const Icon(Icons.settings_rounded),
                  color: notifier.permissionStatusColor,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _PermissionRow(
            title: 'Notification Permission',
            subtitle: 'Required for habit alerts',
            isGranted: settings.hasNotificationPermission,
            isCritical: true,
            onAction: () async {
              await notifier.requestNotificationPermission();
              await notifier.refreshPermissionStates();
            },
          ),
          const SizedBox(height: 10),
          _PermissionRow(
            title: 'Exact Alarm',
            subtitle: 'Improves on-time reminders',
            isGranted: settings.hasExactAlarmPermission,
            isCritical: true,
            onAction: () async {
              await notifier.requestExactAlarmPermission();
              await notifier.refreshPermissionStates();
            },
          ),
          const SizedBox(height: 10),
          _PermissionRow(
            title: 'Full Screen Intent',
            subtitle: 'Needed for alarm popups',
            isGranted: settings.hasFullScreenIntentPermission,
            onAction: () async {
              await notifier.openFullScreenIntentSettings();
              await notifier.refreshPermissionStates();
            },
          ),
          const SizedBox(height: 10),
          _PermissionRow(
            title: 'Overlay Permission',
            subtitle: 'Required for special alerts',
            isGranted: settings.hasOverlayPermission,
            onAction: () async {
              await notifier.openAppSettings();
              await notifier.refreshPermissionStates();
            },
          ),
          const SizedBox(height: 10),
          _PermissionRow(
            title: 'Unrestricted Battery',
            subtitle: 'Prevents missed reminders',
            isGranted: settings.hasBatteryOptimizationExemption,
            onAction: () async {
              await notifier.requestBatteryOptimizationExemption();
              await Future.delayed(const Duration(milliseconds: 500));
              await notifier.refreshPermissionStates();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWarningBanner(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String message,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 12,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: color, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    bool isLoading = false,
    bool isSecondary = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor =
        isSecondary ? colorScheme.surfaceContainerLow : AppColorSchemes.primaryGold;
    final textColor = isSecondary ? colorScheme.onSurface : colorScheme.onPrimary;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          elevation: isSecondary ? 0 : 4,
          shadowColor: AppColorSchemes.primaryGold.withOpacity(0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildStatRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: colorScheme.onSurface),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColorSchemes.primaryGold,
          ),
        ),
      ],
    );
  }

  void _showAudioStreamPicker(
    BuildContext context,
    HabitNotificationSettings settings,
    HabitNotificationSettingsNotifier notifier,
  ) {
    _showOptionPicker(
      context,
      title: 'Sound Channel',
      options: HabitNotificationSettings.availableAudioStreams.map((stream) {
        return _PickerOption(
          label: HabitNotificationSettings.getAudioStreamDisplayName(stream),
          isSelected: settings.notificationAudioStream == stream,
          onTap: () => notifier.setNotificationAudioStream(stream),
        );
      }).toList(),
    );
  }

  void _showReminderTimePicker(
    BuildContext context,
    HabitNotificationSettings settings,
    HabitNotificationSettingsNotifier notifier,
  ) {
    _showOptionPicker(
      context,
      title: 'Default Reminder Time',
      options: HabitNotificationSettings.availableReminderTimes.map((time) {
        return _PickerOption(
          label: HabitNotificationSettings.getReminderTimeDisplayName(time),
          isSelected: settings.defaultHabitReminderTime == time,
          onTap: () => notifier.setDefaultHabitReminderTime(time),
        );
      }).toList(),
    );
  }

  void _showSnoozeDurationPicker(
    BuildContext context,
    HabitNotificationSettings settings,
    HabitNotificationSettingsNotifier notifier,
  ) {
    _showOptionPicker(
      context,
      title: 'Default Snooze Duration',
      options: HabitNotificationSettings.availableSnoozeOptions.map((duration) {
        return _PickerOption(
          label: HabitNotificationSettings.getSnoozeDurationDisplayName(duration),
          isSelected: settings.defaultSnoozeDuration == duration,
          onTap: () => notifier.setDefaultSnoozeDuration(duration),
        );
      }).toList(),
    );
  }

  void _showMaxSnoozePicker(
    BuildContext context,
    HabitNotificationSettings settings,
    HabitNotificationSettingsNotifier notifier,
  ) {
    _showOptionPicker(
      context,
      title: 'Maximum Snooze Count',
      options: [1, 2, 3, 5, 10, 999].map((count) {
        return _PickerOption(
          label: count == 999 ? 'Unlimited' : '$count times',
          isSelected: settings.maxSnoozeCount == count,
          onTap: () => notifier.setMaxSnoozeCount(count),
        );
      }).toList(),
    );
  }

  void _showMorningHourPicker(
    BuildContext context,
    HabitNotificationSettings settings,
    HabitNotificationSettingsNotifier notifier,
  ) {
    _showOptionPicker(
      context,
      title: 'Morning Reminder Hour',
      options: List.generate(24, (i) => i).map((hour) {
        return _PickerOption(
          label: HabitNotificationSettings.formatHourToTime(hour),
          isSelected: settings.earlyMorningReminderHour == hour,
          onTap: () => notifier.setEarlyMorningReminderHour(hour),
        );
      }).toList(),
    );
  }

  void _showQuietHoursPicker(
    BuildContext context,
    HabitNotificationSettings settings,
    HabitNotificationSettingsNotifier notifier,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: true,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        return SheetDismissOnOverscroll(
          child: _PickerSheet(
            title: 'Quiet Hours Schedule',
            child: Column(
            children: [
              ListTile(
                title: const Text('Start Time'),
                subtitle: Text(
                  HabitNotificationSettings.formatMinutesToTime(settings.quietHoursStart),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _pickTime(
                  context,
                  settings.quietHoursStart,
                  (minutes) => notifier.setQuietHoursStart(minutes),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                title: const Text('End Time'),
                subtitle: Text(
                  HabitNotificationSettings.formatMinutesToTime(settings.quietHoursEnd),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _pickTime(
                  context,
                  settings.quietHoursEnd,
                  (minutes) => notifier.setQuietHoursEnd(minutes),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap a time to adjust',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            ),
          ),
        );
      },
    );
  }

  void _showQuietHoursDaysPicker(
    BuildContext context,
    HabitNotificationSettings settings,
    HabitNotificationSettingsNotifier notifier,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final selectedDays = List<int>.from(settings.quietHoursDays);
          final theme = Theme.of(context);
          return SheetDismissOnOverscroll(
            child: _PickerSheet(
              title: 'Quiet Hours Days',
              child: Column(
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(7, (index) {
                    final day = index + 1;
                    final isSelected = selectedDays.contains(day);
                    return FilterChip(
                      label: Text(HabitNotificationSettings.getWeekdayShortName(day)),
                      selected: isSelected,
                      onSelected: (selected) {
                        setSheetState(() {
                          if (selected) {
                            selectedDays.add(day);
                          } else {
                            selectedDays.remove(day);
                          }
                          selectedDays.sort();
                        });
                        notifier.setQuietHoursDays(selectedDays);
                      },
                      selectedColor: AppColorSchemes.primaryGold.withOpacity(0.3),
                      checkmarkColor: AppColorSchemes.primaryGold,
                      backgroundColor: theme.colorScheme.surfaceContainerLow,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? AppColorSchemes.primaryGold
                            : theme.colorScheme.onSurface,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                Text(
                  selectedDays.isEmpty
                      ? 'Quiet hours active every day'
                      : 'Quiet hours active on selected days only',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickTime(
    BuildContext context,
    int currentMinutes,
    Function(int) onSelected,
  ) async {
    final currentTime = TimeOfDay(
      hour: currentMinutes ~/ 60,
      minute: currentMinutes % 60,
    );

    final picked = await showTimePicker(
      context: context,
      initialTime: currentTime,
    );

    if (picked != null) {
      onSelected(picked.hour * 60 + picked.minute);
    }
  }

  void _showOptionPicker(
    BuildContext context, {
    required String title,
    required List<_PickerOption> options,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: true,
      showDragHandle: true,
      builder: (context) => SheetDismissOnOverscroll(
        child: _PickerSheet(
          title: title,
          child: Column(
            children: options.map((opt) => _PickerOptionTile(option: opt)).toList(),
          ),
        ),
      ),
    );
  }

  Future<void> _testNotification(BuildContext context) async {
    setState(() => _isTestingNotification = true);
    try {
      final settings = ref.read(habitNotificationSettingsProvider);
      if (!settings.notificationsEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Global habit notifications are disabled.'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColorSchemes.error,
            ),
          );
        }
        setState(() => _isTestingNotification = false);
        return;
      }

      await NotificationService().showTestHabitNotification(
        title: 'Habit Reminder',
        body: 'This is a test habit notification.',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Test notification sent.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColorSchemes.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColorSchemes.error,
          ),
        );
      }
    }
    setState(() => _isTestingNotification = false);
  }

  Future<void> _testSpecialNotification(BuildContext context) async {
    setState(() => _isTestingSpecialNotification = true);
    try {
      final settings = ref.read(habitNotificationSettingsProvider);
      if (!settings.notificationsEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Global habit notifications are disabled.'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColorSchemes.error,
            ),
          );
        }
        setState(() => _isTestingSpecialNotification = false);
        return;
      }

      if (settings.specialHabitAlarmMode) {
        final success = await AlarmService().scheduleTestAlarm(
          title: 'Special Habit Test',
          body: 'This simulates a special habit alert.',
          showFullscreen: true,
          soundId: settings.specialHabitSound,
          vibrationPatternId: settings.specialHabitVibrationPattern,
          iconCodePoint: Icons.star_rounded.codePoint,
          iconFontFamily: 'MaterialIcons',
        );

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Special habit alarm will ring in 3 seconds...'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColorSchemes.error,
            ),
          );
        }
      } else {
        await NotificationService().showTestSpecialHabitNotification(
          title: 'Special Habit Alert',
          body: 'This is a special habit test alert.',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColorSchemes.error,
          ),
        );
      }
    }
    setState(() => _isTestingSpecialNotification = false);
  }

  void _showResetConfirmation(
    BuildContext context,
    HabitNotificationSettingsNotifier notifier,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Defaults'),
        content: const Text('Reset all habit notification settings to defaults?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await notifier.resetToDefaults();
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColorSchemes.primaryGold,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _showCancelAllConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Habit Notifications'),
        content: const Text('Cancel all scheduled habit notifications?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final cleared = await _clearAllPendingHabitNotifications();
              if (context.mounted) {
                Navigator.pop(context);
                await _loadPendingNotificationsCount();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Cleared $cleared pending habit notification${cleared == 1 ? '' : 's'}.',
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColorSchemes.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Cancel All'),
          ),
        ],
      ),
    );
  }
}

class _PickerSheet extends StatelessWidget {
  final String title;
  final Widget child;

  const _PickerSheet({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Flexible(child: SingleChildScrollView(child: child)),
        ],
      ),
    );
  }
}

class _PickerOption {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  _PickerOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
}

class _PickerOptionTile extends StatelessWidget {
  final _PickerOption option;

  const _PickerOptionTile({required this.option});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: () {
        option.onTap();
        Navigator.pop(context);
      },
      title: Text(option.label),
      trailing: option.isSelected
          ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary)
          : Icon(Icons.circle_outlined, color: theme.colorScheme.onSurfaceVariant),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool isGranted;
  final bool isCritical;
  final VoidCallback onAction;

  const _PermissionRow({
    required this.title,
    this.subtitle,
    required this.isGranted,
    this.isCritical = false,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = isGranted
        ? AppColorSchemes.success
        : (isCritical ? AppColorSchemes.error : AppColorSchemes.warning);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: isCritical && !isGranted
            ? Border.all(color: AppColorSchemes.warning.withOpacity(0.3), width: 1)
            : null,
      ),
      child: Row(
        children: [
          Icon(
            isGranted ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: statusColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    if (isCritical && !isGranted) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColorSchemes.warning.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Required',
                          style: TextStyle(
                            color: AppColorSchemes.warning,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onAction,
            child: Text(isGranted ? 'Granted' : 'Fix'),
          ),
        ],
      ),
    );
  }
}
