import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../../../../core/theme/dark_gradient.dart';
import '../../../../../core/theme/color_schemes.dart';
import '../../../../../core/theme/typography.dart';
import '../../../../../core/models/notification_settings.dart';
import '../../../../../core/providers/notification_settings_provider.dart';
import '../../../../../core/services/notification_service.dart';
import '../../../../../core/services/reminder_manager.dart';
import '../../../../../core/services/android_system_status.dart';
import '../../../../../core/services/alarm_service.dart';
import '../../../../../core/models/special_task_sound.dart';
import '../../../../../core/models/vibration_pattern.dart';
import '../../../../../core/widgets/settings_widgets.dart';
import '../../../../../data/models/task.dart';
import '../../widgets/notification_template_builder.dart';
import '../../widgets/special_task_sound_picker.dart';
import '../../widgets/vibration_pattern_picker.dart';
import '../alarm_screen.dart';
import 'notification_diagnostics_screen.dart';

/// Enhanced, Professional Notification Settings Screen
///
/// Provides a comprehensive, production-ready UI for controlling all notification aspects:
/// - System permissions management
/// - Global notification preferences
/// - Sound and vibration settings
/// - Task reminder defaults
/// - Snooze configuration
/// - Quiet hours schedule
/// - Notification channels
/// - Advanced settings
/// - Debug and statistics

import '../../../../../core/models/reminder.dart';
import '../../../../../data/models/subtask.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  final int initialTab;

  const NotificationSettingsScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool _isTestingNotification = false;
  bool _isTestingSpecialNotification = false;
  int _pendingNotificationsCount = 0;
  bool _hasDndAccess = true; // Assume true until checked
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab,
    ); // 3 tabs: General, Task Defaults, Advanced
    // Add lifecycle observer to detect when app resumes
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationSettingsProvider.notifier).refreshPermissionStates();
      _loadPendingNotificationsCount();
      _checkDndAccess();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  /// Called when app lifecycle state changes (e.g., returning from settings)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // When user returns to the app (from settings), refresh permission states
    if (state == AppLifecycleState.resumed) {
      print('🔄 NotificationSettings: App resumed - refreshing permissions');
      ref.read(notificationSettingsProvider.notifier).refreshPermissionStates();
      _loadPendingNotificationsCount();
      _checkDndAccess();
    }
  }

  Future<void> _checkDndAccess() async {
    try {
      final hasAccess = await AndroidSystemStatus.hasDndAccess();
      if (mounted) {
        setState(() => _hasDndAccess = hasAccess);
      }
    } catch (e) {
      // Defensive: never let settings screen crash if OEM APIs fail.
      if (mounted) {
        setState(() => _hasDndAccess = false);
      }
    }
  }

  Future<void> _loadPendingNotificationsCount() async {
    try {
      final count = await ReminderManager().getPendingNotificationsCount();
      if (mounted) {
        setState(() => _pendingNotificationsCount = count);
      }
    } catch (_) {
      // If plugin isn't ready / OEM throws, keep UI usable.
      if (mounted) {
        setState(() => _pendingNotificationsCount = 0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = ref.watch(notificationSettingsProvider);
    final notifier = ref.read(notificationSettingsProvider.notifier);

    // IMPORTANT:
    // Avoid nesting Scaffold داخل Scaffold (Scaffold -> DecoratedBox -> Scaffold),
    // which can trigger rare semantics assertion failures on some devices.
    final content = _buildContent(context, isDark, settings, notifier);
    return isDark ? DarkGradient.wrap(child: content) : content;
  }

  Widget _buildContent(
    BuildContext context,
    bool isDark,
    NotificationSettings settings,
    NotificationSettingsNotifier notifier,
  ) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Notifications',
          style: AppTypography.titleMedium(context).copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: isDark ? Colors.white : AppColorSchemes.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : AppColorSchemes.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              color: isDark ? Colors.white70 : AppColorSchemes.textSecondary,
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
          unselectedLabelColor: isDark
              ? Colors.white54
              : AppColorSchemes.textSecondary,
          indicatorColor: AppColorSchemes.primaryGold,
          tabs: const [
            Tab(text: 'General'),
            Tab(text: 'Task Defaults'),
            Tab(text: 'Advanced'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGeneralTab(context, isDark, settings, notifier),
          _buildTaskDefaultsTab(context, isDark, settings, notifier),
          _buildAdvancedTab(context, isDark, settings, notifier),
        ],
      ),
    );
  }

  // ============================================
  // TAB 1: General Settings
  // ============================================
  Widget _buildGeneralTab(
    BuildContext context,
    bool isDark,
    NotificationSettings settings,
    NotificationSettingsNotifier notifier,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      physics: const BouncingScrollPhysics(),
      children: [
        // Permission Summary Section - Only show if not all permissions are granted
        if (!notifier.hasAllTrackedPermissions) ...[
          _buildSection(
            context,
            isDark,
            'SYSTEM PERMISSIONS',
            Icons.security_rounded,
            child: _buildPermissionStatus(context, isDark, settings, notifier),
          ),
          const SizedBox(height: 20),
        ],

        // Core Controls Section
        _buildSection(
          context,
          isDark,
          'GENERAL',
          Icons.tune_rounded,
          child: Column(
            children: [
              _SettingsToggle(
                title: 'Global Notifications',
                subtitle: 'Enable or disable all task reminders',
                value: settings.notificationsEnabled,
                icon: Icons.notifications_active_rounded,
                color: AppColorSchemes.primaryGold,
                onChanged: (val) => notifier.setNotificationsEnabled(val),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Sound & Feedback Section
        _buildSection(
          context,
          isDark,
          'SOUND & FEEDBACK',
          Icons.volume_up_rounded,
          child: Column(
            children: [
              _SettingsToggle(
                title: 'Sound',
                subtitle: 'Play alert sounds',
                value: settings.soundEnabled,
                icon: Icons.music_note_rounded,
                color: const Color(0xFF42A5F5),
                onChanged: (val) => notifier.setSoundEnabled(val),
              ),
              if (settings.soundEnabled) ...[
                _buildDivider(isDark),
                _SettingsTile(
                  title: 'Notification Tone',
                  value: NotificationSettings.getSoundDisplayName(
                    settings.defaultSound,
                  ),
                  icon: Icons.graphic_eq_rounded,
                  color: const Color(0xFF42A5F5),
                  onTap: () => notifier.pickDefaultSoundFromSystem(),
                ),
                _buildDivider(isDark),
                _SettingsTile(
                  title: 'Sound Channel',
                  value: NotificationSettings.getAudioStreamDisplayName(
                    settings.notificationAudioStream,
                  ),
                  icon: Icons.volume_up_rounded,
                  color: const Color(0xFF42A5F5),
                  onTap: () => _showAudioStreamPicker(
                    context,
                    isDark,
                    settings,
                    notifier,
                  ),
                ),
              ],
              _buildDivider(isDark),
              _SettingsToggle(
                title: 'Haptic Vibration',
                subtitle: 'Tactile feedback for alerts',
                value: settings.vibrationEnabled,
                icon: Icons.vibration_rounded,
                color: const Color(0xFF66BB6A),
                onChanged: (val) => notifier.setVibrationEnabled(val),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Special Task Alerts Section
        // Check if quiet hours blocks special task alarms
        Builder(
          builder: (context) {
            final isBlockedByQuietHours =
                settings.quietHoursEnabled &&
                !settings.allowUrgentDuringQuietHours;
            final needsFullScreenPermission =
                !settings.hasFullScreenIntentPermission &&
                settings.specialTaskAlarmMode;
            final needsOverlayPermission =
                Platform.isAndroid &&
                settings.specialTaskAlarmMode &&
                !settings.hasOverlayPermission;

            return _buildSection(
              context,
              isDark,
              'SPECIAL TASK ALERTS',
              Icons.star_rounded,
              child: Column(
                children: [
                  // "Appear on top" is required on many OEMs to show alarm UI immediately.
                  if (needsOverlayPermission) ...[
                    GestureDetector(
                      onTap: () => notifier.openAppSettings(),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9800).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFFF9800).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.layers_rounded,
                              color: Color(0xFFFF9800),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Enable “Appear on top” for Life Manager. Without it, the alarm screen may NOT pop up until you tap the notification.',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black87,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: Color(0xFFFF9800),
                              size: 14,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  // Show warning if full-screen intent permission not granted (Android 14+)
                  if (needsFullScreenPermission) ...[
                    GestureDetector(
                      onTap: () => notifier.openFullScreenIntentSettings(),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE53935).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFE53935).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning_rounded,
                              color: Color(0xFFE53935),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Full-screen intent permission required! Tap to grant permission for alarm UI to appear on lock screen.',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black87,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: Color(0xFFE53935),
                              size: 14,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  // Show warning if blocked by quiet hours
                  if (isBlockedByQuietHours) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9800).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFFF9800).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: const Color(0xFFFF9800),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Special task alarms are blocked during quiet hours. Enable "Allow Special Task Alerts" in Quiet Hours to use this feature.',
                              style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.black87,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  _SettingsToggle(
                    title: 'Always Use Alarm Channel',
                    subtitle: isBlockedByQuietHours
                        ? 'Blocked by Quiet Hours settings'
                        : 'Special tasks bypass silent mode & DND',
                    value: settings.alwaysUseAlarmForSpecialTasks,
                    icon: Icons.alarm_rounded,
                    color: isBlockedByQuietHours
                        ? Colors.grey
                        : const Color(0xFFE53935),
                    onChanged: isBlockedByQuietHours
                        ? null // Disable toggle when blocked
                        : (val) =>
                              notifier.setAlwaysUseAlarmForSpecialTasks(val),
                  ),
                  if (settings.alwaysUseAlarmForSpecialTasks &&
                      !isBlockedByQuietHours) ...[
                    _buildDivider(isDark),
                    _SettingsTile(
                      title: 'Special Task Tone',
                      value: SpecialTaskSound.getDisplayName(
                        settings.specialTaskSound,
                      ),
                      icon: Icons.graphic_eq_rounded,
                      color: const Color(0xFFFFB74D),
                      onTap: () async {
                        final selectedSound = await SpecialTaskSoundPicker.show(
                          context,
                          settings.specialTaskSound,
                        );
                        if (selectedSound != null) {
                          notifier.setSpecialTaskSound(selectedSound);
                        }
                      },
                    ),
                    _buildDivider(isDark),
                    _SettingsTile(
                      title: 'Vibration Pattern',
                      value: VibrationPattern.getDisplayName(
                        settings.specialTaskVibrationPattern,
                      ),
                      icon: Icons.vibration_rounded,
                      color: const Color(0xFF9C27B0),
                      onTap: () async {
                        final selectedPattern =
                            await VibrationPatternPicker.show(
                              context,
                              settings.specialTaskVibrationPattern,
                            );
                        if (selectedPattern != null) {
                          notifier.setSpecialTaskVibrationPattern(
                            selectedPattern,
                          );
                        }
                      },
                    ),
                    _buildDivider(isDark),
                    _SettingsToggle(
                      title: 'Alarm Mode',
                      subtitle: 'Wake screen & show alarm popup',
                      value: settings.specialTaskAlarmMode,
                      icon: Icons.fullscreen_rounded,
                      color: const Color(0xFFFF5722),
                      onChanged: (val) => notifier.setSpecialTaskAlarmMode(val),
                    ),
                  ],
                ],
              ),
            );
          },
        ),

        const SizedBox(height: 32),

        // Action Buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            children: [
              _buildActionButton(
                context,
                isDark,
                label: 'Test Regular Notification',
                icon: Icons.notification_add_rounded,
                isLoading: _isTestingNotification,
                onPressed: () => _testNotification(context),
              ),
              const SizedBox(height: 12),
              _buildActionButton(
                context,
                isDark,
                label: 'Test Special Task Notification',
                icon: Icons.star_rounded,
                isLoading: _isTestingSpecialNotification,
                onPressed: () => _testSpecialNotification(context),
              ),
              const SizedBox(height: 12),
              _buildActionButton(
                context,
                isDark,
                label: 'Reset to Defaults',
                icon: Icons.refresh_rounded,
                isSecondary: true,
                onPressed: () =>
                    _showResetConfirmation(context, isDark, notifier),
              ),
            ],
          ),
        ),

        const SizedBox(height: 40),
      ],
    );
  }

  // ============================================
  // TAB 2: Task Defaults
  // ============================================
  Widget _buildTaskDefaultsTab(
    BuildContext context,
    bool isDark,
    NotificationSettings settings,
    NotificationSettingsNotifier notifier,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      physics: const BouncingScrollPhysics(),
      children: [
        // Default Reminder Time
        _buildSection(
          context,
          isDark,
          'DEFAULT REMINDER',
          Icons.access_time_rounded,
          child: Column(
            children: [
              _SettingsTile(
                title: 'Default Reminder Time',
                value: NotificationSettings.getReminderTimeDisplayName(
                  settings.defaultTaskReminderTime,
                ),
                icon: Icons.notifications_active_rounded,
                color: AppColorSchemes.primaryGold,
                onTap: () => _showReminderTimePicker(
                  context,
                  isDark,
                  settings,
                  notifier,
                ),
              ),
              _buildDivider(isDark),
              _SettingsTile(
                title: 'Morning Reminder Hour',
                value: NotificationSettings.formatHourToTime(
                  settings.earlyMorningReminderHour,
                ),
                icon: Icons.wb_sunny_rounded,
                color: const Color(0xFFFFB74D),
                onTap: () =>
                    _showMorningHourPicker(context, isDark, settings, notifier),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Snooze Settings
        _buildSection(
          context,
          isDark,
          'SNOOZE OPTIONS',
          Icons.snooze_rounded,
          child: Column(
            children: [
              _SettingsTile(
                title: 'Default Snooze Duration',
                value: NotificationSettings.getSnoozeDurationDisplayName(
                  settings.defaultSnoozeDuration,
                ),
                icon: Icons.timer_rounded,
                color: const Color(0xFF7E57C2),
                onTap: () => _showSnoozeDurationPicker(
                  context,
                  isDark,
                  settings,
                  notifier,
                ),
              ),
              _buildDivider(isDark),
              _SettingsTile(
                title: 'Max Snooze Count',
                value: '${settings.maxSnoozeCount} times',
                icon: Icons.repeat_rounded,
                color: const Color(0xFF7E57C2),
                onTap: () =>
                    _showMaxSnoozePicker(context, isDark, settings, notifier),
              ),
              _buildDivider(isDark),
              _SettingsToggle(
                title: 'Smart Snooze',
                subtitle: 'Adjust snooze based on task priority',
                value: settings.smartSnooze,
                icon: Icons.auto_fix_high_rounded,
                color: const Color(0xFF66BB6A),
                onChanged: (val) => notifier.setSmartSnooze(val),
              ),
            ],
          ),
        ),

        const SizedBox(height: 40),
      ],
    );
  }

  // ============================================
  // TAB 3: Channels
  // ============================================
  Widget _buildChannelsTab(
    BuildContext context,
    bool isDark,
    NotificationSettings settings,
    NotificationSettingsNotifier notifier,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      physics: const BouncingScrollPhysics(),
      children: [
        // Info Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF42A5F5).withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF42A5F5).withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: Color(0xFF42A5F5),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Notification channels allow different types of alerts with unique behaviors.',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black87,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Task Reminders Channel
        _buildSection(
          context,
          isDark,
          'TASK REMINDERS',
          Icons.task_alt_rounded,
          child: Column(
            children: [
              _SettingsToggle(
                title: 'Enable Channel',
                subtitle: 'Regular task reminder notifications',
                value: settings.taskRemindersEnabled,
                icon: Icons.notifications_rounded,
                color: AppColorSchemes.primaryGold,
                onChanged: (val) => notifier.setTaskRemindersEnabled(val),
              ),
              if (settings.taskRemindersEnabled) ...[
                _buildDivider(isDark),
                _SettingsTile(
                  title: 'Channel Sound',
                  value: NotificationSettings.getSoundDisplayName(
                    settings.taskRemindersSound,
                  ),
                  icon: Icons.music_note_rounded,
                  color: AppColorSchemes.primaryGold,
                  onTap: () => _showChannelSoundPicker(
                    context,
                    isDark,
                    'Task Reminders',
                    settings.taskRemindersSound,
                    (sound) => notifier.setTaskRemindersSound(sound),
                  ),
                ),
                _buildDivider(isDark),
                _buildChannelSettingsButton(
                  context,
                  isDark,
                  'task_reminders',
                  notifier,
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Urgent Reminders Channel
        _buildSection(
          context,
          isDark,
          'URGENT REMINDERS',
          Icons.warning_amber_rounded,
          child: Column(
            children: [
              _SettingsToggle(
                title: 'Enable Channel',
                subtitle: 'Critical high-priority alerts',
                value: settings.urgentRemindersEnabled,
                icon: Icons.notifications_active_rounded,
                color: const Color(0xFFEF5350),
                onChanged: (val) => notifier.setUrgentRemindersEnabled(val),
              ),
              if (settings.urgentRemindersEnabled) ...[
                _buildDivider(isDark),
                _SettingsTile(
                  title: 'Channel Sound',
                  value: NotificationSettings.getSoundDisplayName(
                    settings.urgentRemindersSound,
                  ),
                  icon: Icons.music_note_rounded,
                  color: const Color(0xFFEF5350),
                  onTap: () => _showChannelSoundPicker(
                    context,
                    isDark,
                    'Urgent Reminders',
                    settings.urgentRemindersSound,
                    (sound) => notifier.setUrgentRemindersSound(sound),
                  ),
                ),
                _buildDivider(isDark),
                _buildChannelSettingsButton(
                  context,
                  isDark,
                  'urgent_reminders',
                  notifier,
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Silent Reminders Channel
        _buildSection(
          context,
          isDark,
          'SILENT REMINDERS',
          Icons.notifications_off_rounded,
          child: Column(
            children: [
              _SettingsToggle(
                title: 'Enable Channel',
                subtitle: 'Silent notifications (no sound/vibration)',
                value: settings.silentRemindersEnabled,
                icon: Icons.notifications_paused_rounded,
                color: const Color(0xFF78909C),
                onChanged: (val) => notifier.setSilentRemindersEnabled(val),
              ),
              if (settings.silentRemindersEnabled) ...[
                _buildDivider(isDark),
                _buildChannelSettingsButton(
                  context,
                  isDark,
                  'silent_reminders',
                  notifier,
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Default Channel
        _buildSection(
          context,
          isDark,
          'DEFAULT CHANNEL',
          Icons.tune_rounded,
          child: _SettingsTile(
            title: 'Default Channel',
            value: NotificationSettings.getChannelDisplayName(
              settings.defaultChannel,
            ),
            icon: Icons.speaker_notes_rounded,
            color: const Color(0xFF42A5F5),
            onTap: () =>
                _showDefaultChannelPicker(context, isDark, settings, notifier),
          ),
        ),

        const SizedBox(height: 40),
      ],
    );
  }

  // ============================================
  // TAB 4: Advanced
  // ============================================
  Widget _buildAdvancedTab(
    BuildContext context,
    bool isDark,
    NotificationSettings settings,
    NotificationSettingsNotifier notifier,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      physics: const BouncingScrollPhysics(),
      children: [
        // Quiet Hours
        _buildSection(
          context,
          isDark,
          'QUIET HOURS',
          Icons.bedtime_rounded,
          child: Column(
            children: [
              _SettingsToggle(
                title: 'Quiet Hours',
                subtitle: 'Silence alerts during rest',
                value: settings.quietHoursEnabled,
                icon: Icons.nightlight_rounded,
                color: const Color(0xFF7E57C2),
                onChanged: (val) => notifier.setQuietHoursEnabled(val),
              ),
              if (settings.quietHoursEnabled) ...[
                _buildDivider(isDark),
                _SettingsTile(
                  title: 'Schedule',
                  value:
                      '${NotificationSettings.formatMinutesToTime(settings.quietHoursStart)} - ${NotificationSettings.formatMinutesToTime(settings.quietHoursEnd)}',
                  icon: Icons.schedule_rounded,
                  color: const Color(0xFF7E57C2),
                  onTap: () => _showQuietHoursPicker(
                    context,
                    isDark,
                    settings,
                    notifier,
                  ),
                ),
                _buildDivider(isDark),
                _SettingsTile(
                  title: 'Active Days',
                  value: settings.quietHoursDays.isEmpty
                      ? 'Every day'
                      : settings.quietHoursDays
                            .map(
                              (d) =>
                                  NotificationSettings.getWeekdayShortName(d),
                            )
                            .join(', '),
                  icon: Icons.calendar_today_rounded,
                  color: const Color(0xFF7E57C2),
                  onTap: () => _showQuietHoursDaysPicker(
                    context,
                    isDark,
                    settings,
                    notifier,
                  ),
                ),
                _buildDivider(isDark),
                _SettingsToggle(
                  title: 'Allow Special Task Alerts',
                  subtitle: 'Special tasks bypass quiet hours',
                  value: settings.allowUrgentDuringQuietHours,
                  icon: Icons.star_rounded,
                  color: const Color(0xFFFFB74D),
                  onChanged: (val) =>
                      notifier.setAllowUrgentDuringQuietHours(val),
                  compact: true,
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Display Options
        _buildSection(
          context,
          isDark,
          'DISPLAY OPTIONS',
          Icons.visibility_rounded,
          child: Column(
            children: [
              _SettingsToggle(
                title: 'Show on Lock Screen',
                subtitle: 'Display notifications when locked',
                value: settings.showOnLockScreen,
                icon: Icons.lock_open_rounded,
                color: const Color(0xFF42A5F5),
                onChanged: (val) => notifier.setShowOnLockScreen(val),
              ),
              _buildDivider(isDark),
              _SettingsToggle(
                title: 'LED Indicator',
                subtitle: 'Flash LED light for notifications',
                value: settings.ledEnabled,
                icon: Icons.lightbulb_outline_rounded,
                color: const Color(0xFF66BB6A),
                onChanged: (val) => notifier.setLedEnabled(val),
              ),
              _buildDivider(isDark),
              _SettingsToggle(
                title: 'Persistent Notifications',
                subtitle: 'Keep notifications until dismissed',
                value: settings.persistentNotifications,
                icon: Icons.push_pin_rounded,
                color: const Color(0xFF7E57C2),
                onChanged: (val) => notifier.setPersistentNotifications(val),
              ),
              _buildDivider(isDark),
              // Test Button
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Color(0xFF4CAF50),
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Test Display Settings',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                subtitle: Text(
                  'Preview notification with current settings',
                  style: TextStyle(
                    color: isDark
                        ? Colors.white54
                        : AppColorSchemes.textSecondary,
                    fontSize: 12,
                  ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'TEST',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                onTap: () async {
                  try {
                    final settings = ref.read(notificationSettingsProvider);
                    final title = await NotificationService().renderTemplate(
                      settings.taskTitleTemplate,
                      _getDummyTask(false),
                      _getDummyReminder(),
                    );
                    final body = await NotificationService().renderTemplate(
                      settings.taskBodyTemplate,
                      _getDummyTask(false),
                      _getDummyReminder(),
                    );

                    await NotificationService().showTestDisplayNotification(
                      title: title,
                      body: body,
                    );

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            '⏱️ Test notification will fire in 5 seconds! Lock your screen to test.',
                          ),
                          backgroundColor: const Color(0xFF4CAF50),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 5),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('❌ Error: $e'),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Content Options
        _buildSection(
          context,
          isDark,
          'CONTENT OPTIONS',
          Icons.article_rounded,
          child: Column(
            children: [
              // Notification Designer Entry
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
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
                    color: isDark
                        ? Colors.white54
                        : AppColorSchemes.textSecondary,
                    fontSize: 12,
                  ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColorSchemes.primaryGold,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'DESIGN',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
                onTap: () => NotificationTemplateBuilder.show(context),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Statistics Section
        _buildSection(
          context,
          isDark,
          'STATISTICS & DEBUG',
          Icons.analytics_rounded,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildStatRow(
                  context,
                  isDark,
                  'Pending Notifications',
                  '$_pendingNotificationsCount',
                  Icons.schedule_rounded,
                ),
                const SizedBox(height: 12),
                _buildStatRow(
                  context,
                  isDark,
                  'Permissions Granted',
                  '${notifier.grantedPermissionCount}/${notifier.totalPermissionCount}',
                  Icons.verified_rounded,
                ),
                const SizedBox(height: 12),
                _buildStatRow(
                  context,
                  isDark,
                  'Quiet Hours Active',
                  settings.isInQuietHours() ? 'Yes' : 'No',
                  Icons.bedtime_rounded,
                ),
                const SizedBox(height: 12),
                _buildStatRow(
                  context,
                  isDark,
                  'Global Toggle',
                  settings.notificationsEnabled ? 'ON' : 'OFF',
                  Icons.power_settings_new_rounded,
                ),
                const SizedBox(height: 12),
                _buildStatRow(
                  context,
                  isDark,
                  'Alarm Mode',
                  settings.alarmModeEnabled ? 'Enabled' : 'Disabled',
                  Icons.alarm_rounded,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _showDiagnosticInfo(context, isDark, settings),
                    icon: const Icon(Icons.info_outline_rounded, size: 18),
                    label: const Text('View Full Diagnostic'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF42A5F5),
                      side: BorderSide(
                        color: const Color(0xFF42A5F5).withOpacity(0.5),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Notification Diagnostics - Full screen with test buttons
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const NotificationDiagnosticsScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.science_rounded, size: 18),
                    label: const Text('Notification Diagnostics'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColorSchemes.primaryGold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Preview & test pending notifications without waiting',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _showCancelAllConfirmation(context, isDark),
                    icon: const Icon(Icons.clear_all_rounded, size: 18),
                    label: const Text('Cancel All Notifications'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF5350),
                      side: const BorderSide(color: Color(0xFFEF5350)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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

  // ============================================
  // Helper Widgets
  // ============================================

  Widget _buildSection(
    BuildContext context,
    bool isDark,
    String title,
    IconData icon, {
    required Widget child,
  }) {
    return SettingsSection(
      title: title,
      icon: icon,
      isDarkOverride: isDark,
      child: child,
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 56,
      color: isDark
          ? Colors.white.withOpacity(0.05)
          : Colors.black.withOpacity(0.03),
    );
  }

  Widget _buildPermissionStatus(
    BuildContext context,
    bool isDark,
    NotificationSettings settings,
    NotificationSettingsNotifier notifier,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Summary Row
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
                        '${notifier.grantedPermissionCount} of ${notifier.totalPermissionCount} permissions',
                        style: TextStyle(
                          fontSize: 11,
                          color: notifier.permissionStatusColor.withOpacity(
                            0.7,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!notifier.hasAllCriticalPermissions)
                  TextButton(
                    onPressed: () => _grantAllPermissions(context, notifier),
                    style: TextButton.styleFrom(
                      foregroundColor: notifier.permissionStatusColor,
                      backgroundColor: notifier.permissionStatusColor
                          .withOpacity(0.1),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Grant All',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _PermissionRow(
            title: 'Notifications',
            subtitle: 'Required for all alerts',
            isGranted: settings.hasNotificationPermission,
            isCritical: true,
            onAction: () async {
              await notifier.requestNotificationPermission();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Please grant notification permission'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 8),
          _PermissionRow(
            title: 'Exact Alarms',
            subtitle: 'For precise reminder timing',
            isGranted: settings.hasExactAlarmPermission,
            isCritical: true,
            onAction: () async {
              await notifier.requestExactAlarmPermission();
            },
          ),
          const SizedBox(height: 8),
          _PermissionRow(
            title: 'Full Screen',
            subtitle:
                'Required for alarm-style lock screen overlays (Android 14+)',
            isGranted: settings.hasFullScreenIntentPermission,
            isCritical: true, // Mark as critical for alarm functionality
            onAction: () => notifier.openFullScreenIntentSettings(),
          ),
          if (Platform.isAndroid) ...[
            const SizedBox(height: 8),
            _PermissionRow(
              title: 'Display Over Apps',
              subtitle: 'For popup reminders',
              isGranted: settings.hasOverlayPermission,
              onAction: () => notifier.openAppSettings(),
            ),
            const SizedBox(height: 8),
            _PermissionRow(
              title: 'Unrestricted Battery',
              subtitle: 'Prevents missed reminders',
              isGranted: settings.hasBatteryOptimizationExemption,
              onAction: () async {
                await notifier.requestBatteryOptimizationExemption();
                // Give time for user to interact with system dialog
                await Future.delayed(const Duration(milliseconds: 500));
                await notifier.refreshPermissionStates();
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    bool isDark, {
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    bool isLoading = false,
    bool isSecondary = false,
  }) {
    final primaryColor = isSecondary
        ? (isDark ? Colors.white10 : Colors.black.withOpacity(0.05))
        : AppColorSchemes.primaryGold;

    final textColor = isSecondary
        ? (isDark ? Colors.white : AppColorSchemes.textPrimary)
        : const Color(0xFF1E1E1E);

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: textColor,
          elevation: isSecondary ? 0 : 4,
          shadowColor: AppColorSchemes.primaryGold.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
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
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildChannelSettingsButton(
    BuildContext context,
    bool isDark,
    String channelId,
    NotificationSettingsNotifier notifier,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: () => notifier.openChannelSettings(channelId),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF78909C).withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.settings_rounded,
          color: Color(0xFF78909C),
          size: 20,
        ),
      ),
      title: const Text(
        'System Channel Settings',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      trailing: Icon(
        Icons.open_in_new_rounded,
        size: 18,
        color: isDark ? Colors.white30 : Colors.black26,
      ),
    );
  }

  Widget _buildStatRow(
    BuildContext context,
    bool isDark,
    String label,
    String value,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: isDark ? Colors.white54 : AppColorSchemes.textSecondary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColorSchemes.primaryGold,
          ),
        ),
      ],
    );
  }

  // ============================================
  // Pickers and Dialogs
  // ============================================

  void _showSoundPicker(
    BuildContext context,
    bool isDark,
    NotificationSettings settings,
    NotificationSettingsNotifier notifier,
  ) {
    _showFeedbackPicker(
      context,
      isDark,
      'Notification Tone',
      NotificationSettings.availableSounds
          .map(
            (s) => _FeedbackOption(
              label: NotificationSettings.getSoundDisplayName(s),
              isSelected: settings.defaultSound == s,
              onTap: () => notifier.setDefaultSound(s),
              onPreview: () => notifier.previewSound(s),
              icon: s == 'silent'
                  ? Icons.volume_off_rounded
                  : Icons.music_note_rounded,
            ),
          )
          .toList(),
    );
  }

  void _showAudioStreamPicker(
    BuildContext context,
    bool isDark,
    NotificationSettings settings,
    NotificationSettingsNotifier notifier,
  ) {
    _showModernPicker(
      context,
      isDark,
      'Sound Channel',
      NotificationSettings.availableAudioStreams
          .map(
            (s) => _PickerOption(
              label: NotificationSettings.getAudioStreamDisplayName(s),
              isSelected: settings.notificationAudioStream == s,
              onTap: () => notifier.setNotificationAudioStream(s),
            ),
          )
          .toList(),
    );
  }

  void _showVibrationPicker(
    BuildContext context,
    bool isDark,
    NotificationSettings settings,
    NotificationSettingsNotifier notifier,
  ) {
    _showFeedbackPicker(
      context,
      isDark,
      'Vibration Pattern',
      NotificationSettings.availableVibrationPatterns
          .map(
            (p) => _FeedbackOption(
              label: NotificationSettings.getVibrationDisplayName(p),
              isSelected: settings.defaultVibrationPattern == p,
              onTap: () => notifier.setDefaultVibrationPattern(p),
              onPreview: () => _previewHapticPattern(p),
              icon: p == 'silent'
                  ? Icons.vibration_rounded
                  : Icons.waves_rounded,
            ),
          )
          .toList(),
    );
  }

  Future<void> _previewHapticPattern(String patternKey) async {
    // Haptic preview is more reliable than notification vibration on OEM ROMs.
    Future<void> pulse(
      int times, {
      Duration on = const Duration(milliseconds: 40),
      Duration off = const Duration(milliseconds: 80),
    }) async {
      for (int i = 0; i < times; i++) {
        await HapticFeedback.mediumImpact();
        await Future<void>.delayed(on);
        await Future<void>.delayed(off);
      }
    }

    switch (patternKey) {
      case 'silent':
        return;
      case 'short':
        await HapticFeedback.lightImpact();
        break;
      case 'long':
        await pulse(
          6,
          on: const Duration(milliseconds: 60),
          off: const Duration(milliseconds: 60),
        );
        break;
      case 'pulse':
        await pulse(
          10,
          on: const Duration(milliseconds: 35),
          off: const Duration(milliseconds: 55),
        );
        break;
      case 'default':
      default:
        await pulse(
          4,
          on: const Duration(milliseconds: 50),
          off: const Duration(milliseconds: 80),
        );
        break;
    }
  }

  void _showReminderTimePicker(
    BuildContext context,
    bool isDark,
    NotificationSettings settings,
    NotificationSettingsNotifier notifier,
  ) {
    _showModernPicker(
      context,
      isDark,
      'Default Reminder Time',
      NotificationSettings.availableReminderTimes
          .map(
            (t) => _PickerOption(
              label: NotificationSettings.getReminderTimeDisplayName(t),
              isSelected: settings.defaultTaskReminderTime == t,
              onTap: () => notifier.setDefaultTaskReminderTime(t),
            ),
          )
          .toList(),
    );
  }

  void _showSnoozeDurationPicker(
    BuildContext context,
    bool isDark,
    NotificationSettings settings,
    NotificationSettingsNotifier notifier,
  ) {
    _showModernPicker(
      context,
      isDark,
      'Default Snooze Duration',
      NotificationSettings.availableSnoozeOptions
          .map(
            (d) => _PickerOption(
              label: NotificationSettings.getSnoozeDurationDisplayName(d),
              isSelected: settings.defaultSnoozeDuration == d,
              onTap: () => notifier.setDefaultSnoozeDuration(d),
            ),
          )
          .toList(),
    );
  }

  void _showMaxSnoozePicker(
    BuildContext context,
    bool isDark,
    NotificationSettings settings,
    NotificationSettingsNotifier notifier,
  ) {
    _showModernPicker(
      context,
      isDark,
      'Maximum Snooze Count',
      [1, 2, 3, 5, 10, 999]
          .map(
            (c) => _PickerOption(
              label: c == 999 ? 'Unlimited' : '$c times',
              isSelected: settings.maxSnoozeCount == c,
              onTap: () => notifier.setMaxSnoozeCount(c),
            ),
          )
          .toList(),
    );
  }

  void _showDefaultChannelPicker(
    BuildContext context,
    bool isDark,
    NotificationSettings settings,
    NotificationSettingsNotifier notifier,
  ) {
    _showModernPicker(
      context,
      isDark,
      'Default Channel',
      NotificationSettings.availableChannels
          .map(
            (c) => _PickerOption(
              label: NotificationSettings.getChannelDisplayName(c),
              isSelected: settings.defaultChannel == c,
              onTap: () => notifier.setDefaultChannel(c),
            ),
          )
          .toList(),
    );
  }

  void _showChannelSoundPicker(
    BuildContext context,
    bool isDark,
    String channelName,
    String currentSound,
    Function(String) onSelected,
  ) {
    _showModernPicker(
      context,
      isDark,
      '$channelName Sound',
      NotificationSettings.availableSounds
          .map(
            (s) => _PickerOption(
              label: NotificationSettings.getSoundDisplayName(s),
              isSelected: currentSound == s,
              onTap: () => onSelected(s),
            ),
          )
          .toList(),
    );
  }

  void _showMorningHourPicker(
    BuildContext context,
    bool isDark,
    NotificationSettings settings,
    NotificationSettingsNotifier notifier,
  ) {
    _showModernPicker(
      context,
      isDark,
      'Morning Reminder Hour',
      List.generate(24, (i) => i)
          .map(
            (h) => _PickerOption(
              label: NotificationSettings.formatHourToTime(h),
              isSelected: settings.earlyMorningReminderHour == h,
              onTap: () => notifier.setEarlyMorningReminderHour(h),
            ),
          )
          .toList(),
    );
  }

  Task _getDummyTask(bool isSpecial) {
    return Task(
      id: 'dummy',
      title: 'Buy Groceries',
      description: 'Milk, Eggs, Bread',
      dueDate: DateTime.now(),
      dueTime: TimeOfDay.now(),
      priority: 'High',
      categoryId: 'Shopping',
      isSpecial: isSpecial,
      subtasks: [
        Subtask(title: 'Milk', isCompleted: true),
        Subtask(title: 'Eggs', isCompleted: true),
        Subtask(title: 'Bread', isCompleted: false),
      ],
      createdAt: DateTime.now(),
    );
  }

  Reminder _getDummyReminder() {
    return Reminder(type: 'at_time', value: 0);
  }

  void _showQuietHoursPicker(
    BuildContext context,
    bool isDark,
    NotificationSettings settings,
    NotificationSettingsNotifier notifier,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _ModernPickerSheet(
        title: 'Quiet Hours Schedule',
        isDark: isDark,
        child: Column(
          children: [
            _TimePickerTile(
              label: 'Start Time',
              timeMinutes: settings.quietHoursStart,
              isDark: isDark,
              onTap: () => _pickTime(
                context,
                isDark,
                settings.quietHoursStart,
                (m) => notifier.setQuietHoursStart(m),
              ),
            ),
            const SizedBox(height: 12),
            _TimePickerTile(
              label: 'End Time',
              timeMinutes: settings.quietHoursEnd,
              isDark: isDark,
              onTap: () => _pickTime(
                context,
                isDark,
                settings.quietHoursEnd,
                (m) => notifier.setQuietHoursEnd(m),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuietHoursDaysPicker(
    BuildContext context,
    bool isDark,
    NotificationSettings settings,
    NotificationSettingsNotifier notifier,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final selectedDays = List<int>.from(settings.quietHoursDays);

          return _ModernPickerSheet(
            title: 'Quiet Hours Days',
            isDark: isDark,
            child: Column(
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(7, (index) {
                    final day = index + 1; // 1 = Monday, 7 = Sunday
                    final isSelected = selectedDays.contains(day);
                    return FilterChip(
                      label: Text(
                        NotificationSettings.getWeekdayShortName(day),
                      ),
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
                      selectedColor: AppColorSchemes.primaryGold.withOpacity(
                        0.3,
                      ),
                      checkmarkColor: AppColorSchemes.primaryGold,
                      backgroundColor: isDark
                          ? Colors.white10
                          : Colors.black.withOpacity(0.05),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? AppColorSchemes.primaryGold
                            : (isDark ? Colors.white : Colors.black),
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                Text(
                  selectedDays.isEmpty
                      ? 'Quiet hours active every day'
                      : 'Quiet hours active on selected days only',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black54,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showModernPicker(
    BuildContext context,
    bool isDark,
    String title,
    List<_PickerOption> options,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _ModernPickerSheet(
        title: title,
        isDark: isDark,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: options
              .map(
                (opt) => ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  title: Text(
                    opt.label,
                    style: TextStyle(
                      color: isDark
                          ? Colors.white
                          : AppColorSchemes.textPrimary,
                      fontWeight: opt.isSelected
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                  trailing: opt.isSelected
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: AppColorSchemes.primaryGold,
                        )
                      : null,
                  onTap: () {
                    opt.onTap();
                    Navigator.pop(context);
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  void _showFeedbackPicker(
    BuildContext context,
    bool isDark,
    String title,
    List<_FeedbackOption> options,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _ModernPickerSheet(
        title: title,
        isDark: isDark,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...options.map(
              (opt) => Container(
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                decoration: BoxDecoration(
                  color: opt.isSelected
                      ? AppColorSchemes.primaryGold.withOpacity(
                          isDark ? 0.15 : 0.1,
                        )
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: opt.isSelected
                        ? AppColorSchemes.primaryGold.withOpacity(0.5)
                        : Colors.transparent,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:
                          (opt.isSelected
                                  ? AppColorSchemes.primaryGold
                                  : Colors.grey)
                              .withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      opt.icon,
                      size: 20,
                      color: opt.isSelected
                          ? AppColorSchemes.primaryGold
                          : (isDark ? Colors.white54 : Colors.grey),
                    ),
                  ),
                  title: Text(
                    opt.label,
                    style: TextStyle(
                      color: isDark
                          ? Colors.white
                          : AppColorSchemes.textPrimary,
                      fontWeight: opt.isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (opt.label != 'Silent' && opt.label != 'None')
                        IconButton(
                          icon: Icon(
                            title.contains('Vibration')
                                ? Icons.vibration_rounded
                                : Icons.play_circle_outline_rounded,
                            color: AppColorSchemes.primaryGold,
                          ),
                          tooltip: 'Preview',
                          onPressed: opt.onPreview,
                        ),
                      if (opt.isSelected)
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppColorSchemes.primaryGold,
                          size: 24,
                        ),
                    ],
                  ),
                  onTap: () {
                    opt.onTap();
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Note: Some patterns may depend on your device hardware.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white38 : Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTime(
    BuildContext context,
    bool isDark,
    int current,
    Function(int) onSelected,
  ) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (time != null) onSelected(time.hour * 60 + time.minute);
  }

  Future<void> _testNotification(BuildContext context) async {
    setState(() => _isTestingNotification = true);

    print('🔔 === TEST NOTIFICATION START ===');

    // Check 1: Global toggle
    final current = ref.read(notificationSettingsProvider);
    print('🔔 Global notifications enabled: ${current.notificationsEnabled}');
    if (!current.notificationsEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              '❌ Global notifications are disabled. Enable them first.',
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _isTestingNotification = false);
      return;
    }

    // Check 2: System permissions
    final plugin = FlutterLocalNotificationsPlugin();
    final androidPlugin = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin != null) {
      final granted = await androidPlugin.areNotificationsEnabled();
      print('🔔 System notifications enabled: $granted');

      if (granted == false) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                '❌ Notifications disabled in system settings!',
              ),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: 'Fix',
                textColor: Colors.white,
                onPressed: () => ref
                    .read(notificationSettingsProvider.notifier)
                    .openNotificationSettings(),
              ),
            ),
          );
        }
        setState(() => _isTestingNotification = false);
        return;
      }
    }

    print('🔔 Using channel: ${current.defaultChannel}');
    print('🔔 Sound enabled: ${current.soundEnabled}');
    print('🔔 Vibration enabled: ${current.vibrationEnabled}');
    print('🔔 Alarm mode: ${current.alarmModeEnabled}');

    try {
      await NotificationService().showTestNotification(
        title: '🔔 Test Notification',
        body: 'This test must respect Sound/Vibration toggles.',
      );

      print('🔔 Notification sent successfully!');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Test notification sent!'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: AppColorSchemes.primaryGold,
          ),
        );
      }
    } catch (e) {
      print('🔔 ERROR sending notification: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    print('🔔 === TEST NOTIFICATION END ===');
    setState(() => _isTestingNotification = false);
  }

  Future<void> _testSpecialNotification(BuildContext context) async {
    setState(() => _isTestingSpecialNotification = true);

    print('⭐ === TEST SPECIAL TASK NOTIFICATION START ===');

    // Check 1: Global toggle
    final current = ref.read(notificationSettingsProvider);
    print('⭐ Global notifications enabled: ${current.notificationsEnabled}');
    if (!current.notificationsEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              '❌ Global notifications are disabled. Enable them first.',
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _isTestingSpecialNotification = false);
      return;
    }

    // Check 2: System permissions
    final plugin = FlutterLocalNotificationsPlugin();
    final androidPlugin = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin != null) {
      final granted = await androidPlugin.areNotificationsEnabled();
      print('⭐ System notifications enabled: $granted');

      if (granted == false) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                '❌ Notifications disabled in system settings!',
              ),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: 'Fix',
                textColor: Colors.white,
                onPressed: () => ref
                    .read(notificationSettingsProvider.notifier)
                    .openNotificationSettings(),
              ),
            ),
          );
        }
        setState(() => _isTestingSpecialNotification = false);
        return;
      }
    }

    print('⭐ Always use alarm: ${current.alwaysUseAlarmForSpecialTasks}');
    print('⭐ Special task sound: ${current.specialTaskSound}');
    print('⭐ Alarm mode: ${current.specialTaskAlarmMode}');

    try {
      // If Alarm Mode is ON, use AlarmService (works when app is killed)
      if (current.specialTaskAlarmMode) {
        print('⭐ Using AlarmService for reliable alarm...');

        // Set up callback to show AlarmScreen when alarm rings
        AlarmService().onAlarmRing =
            (
              int alarmId,
              String title,
              String body,
              int? iconCodePoint,
              String? iconFontFamily,
              String? iconFontPackage,
            ) {
              if (mounted) {
                AlarmScreen.show(
                  context,
                  title: title.replaceFirst('⭐ ', ''),
                  body: body,
                  iconCodePoint:
                      iconCodePoint ?? Icons.directions_run_rounded.codePoint,
                  iconFontFamily: iconFontFamily ?? 'MaterialIcons',
                  iconFontPackage: iconFontPackage,
                  onDismiss: () {
                    AlarmService().stopRinging(alarmId);
                    print('⭐ Alarm dismissed');
                  },
                  onSnooze: () {
                    AlarmService().stopRinging(alarmId);
                    print('⭐ Alarm snoozed');
                  },
                );
              }
            };

        final success = await AlarmService().scheduleTestAlarm(
          title: 'Special Task Test',
          body: 'This simulates a special task reminder.',
          showFullscreen: true, // Alarm Mode is ON - show full-screen UI
          soundId: current.specialTaskSound,
          vibrationPatternId: current.specialTaskVibrationPattern,
          iconCodePoint: Icons.directions_run_rounded.codePoint,
          iconFontFamily: 'MaterialIcons',
        );

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                '⭐ Alarm scheduled! Will ring in 3 seconds...',
              ),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: const Color(0xFFE53935),
            ),
          );
        } else if (!success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                '❌ Failed to schedule alarm. Make sure you have an alarm.mp3 in assets/sounds/',
              ),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        // Alarm mode OFF - use regular notification with SoundPlayerService
        final showAlarmScreen = await NotificationService()
            .showTestSpecialTaskNotification(
              title: 'Special Task Test',
              body: 'This simulates a special task reminder.',
            );

        // If alarm mode is enabled (legacy check), show the full-screen alarm
        if (showAlarmScreen && mounted) {
          print('⭐ Showing AlarmScreen...');
          await AlarmScreen.show(
            context,
            title: 'Special Task Test',
            body: 'This simulates a special task reminder.',
            iconCodePoint: Icons.directions_run_rounded.codePoint,
            iconFontFamily: 'MaterialIcons',
            onDismiss: () {
              print('⭐ Alarm dismissed');
            },
            onSnooze: () {
              print('⭐ Alarm snoozed');
            },
          );
        } else {
          print('⭐ Special notification sent successfully!');

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('⭐ Special task notification sent!'),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: const Color(0xFFE53935),
              ),
            );
          }
        }
      }
    } catch (e) {
      print('⭐ ERROR sending notification: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    print('⭐ === TEST SPECIAL TASK NOTIFICATION END ===');
    setState(() => _isTestingSpecialNotification = false);
  }

  /// Simple standalone test that bypasses all app settings
  Future<void> _grantAllPermissions(
    BuildContext context,
    NotificationSettingsNotifier notifier,
  ) async {
    final settings = ref.read(notificationSettingsProvider);

    // Show progress indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              const Text('Requesting permissions...'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }

    // Request critical permissions first
    if (!settings.hasNotificationPermission) {
      await notifier.requestNotificationPermission();
      await Future.delayed(const Duration(milliseconds: 300));
    }

    if (!settings.hasExactAlarmPermission) {
      await notifier.requestExactAlarmPermission();
      await Future.delayed(const Duration(milliseconds: 300));
    }

    // Request optional permissions
    if (Platform.isAndroid) {
      if (!settings.hasBatteryOptimizationExemption) {
        await notifier.requestBatteryOptimizationExemption();
        await Future.delayed(const Duration(milliseconds: 300));
      }

      if (!settings.hasOverlayPermission) {
        await notifier.openAppSettings();
      }
    }

    // Refresh all permission states
    await notifier.refreshPermissionStates();

    if (mounted) {
      final granted = notifier.grantedPermissionCount;
      final total = notifier.totalPermissionCount;

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Permissions updated: $granted/$total granted'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: notifier.hasAllCriticalPermissions
              ? Colors.green
              : Colors.orange,
        ),
      );
    }
  }

  void _showResetConfirmation(
    BuildContext context,
    bool isDark,
    NotificationSettingsNotifier notifier,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E2230) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Reset Settings?'),
        content: const Text(
          'All your notification preferences will be returned to their default state.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.withOpacity(0.1),
              foregroundColor: Colors.red,
              elevation: 0,
            ),
            onPressed: () {
              notifier.resetToDefaults();
              Navigator.pop(context);
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _showPendingNotifications(BuildContext context, bool isDark) async {
    final pending = await ReminderManager().getPendingNotifications();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _ModernPickerSheet(
        title: 'Pending Notifications (${pending.length})',
        isDark: isDark,
        child: pending.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.notifications_off_rounded,
                      size: 48,
                      color: isDark ? Colors.white30 : Colors.black26,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No pending notifications',
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                children: pending
                    .take(20)
                    .map(
                      (n) => ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: AppColorSchemes.primaryGold
                              .withOpacity(0.15),
                          child: Text(
                            '${n.id}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColorSchemes.primaryGold,
                            ),
                          ),
                        ),
                        title: Text(
                          n.title ?? 'Untitled',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          n.body ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
              ),
      ),
    );
  }

  void _showCancelAllConfirmation(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E2230) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Cancel All Notifications?'),
        content: const Text(
          'This will cancel all scheduled task reminders. New reminders will be scheduled when tasks are created or updated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.withOpacity(0.1),
              foregroundColor: Colors.red,
              elevation: 0,
            ),
            onPressed: () async {
              await NotificationService().cancelAllNotifications();
              if (mounted) {
                Navigator.pop(context);
                _loadPendingNotificationsCount();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('All notifications cancelled'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: const Color(0xFFEF5350),
                  ),
                );
              }
            },
            child: const Text('Cancel All'),
          ),
        ],
      ),
    );
  }

  void _showDiagnosticInfo(
    BuildContext context,
    bool isDark,
    NotificationSettings settings,
  ) async {
    final plugin = FlutterLocalNotificationsPlugin();
    final androidPlugin = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    String systemStatus = 'Unknown';
    if (androidPlugin != null) {
      final enabled = await androidPlugin.areNotificationsEnabled();
      systemStatus = enabled == true ? '✅ Enabled' : '❌ Disabled';
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E2230) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.bug_report_rounded, color: Color(0xFF42A5F5)),
            const SizedBox(width: 12),
            const Text('Diagnostic Info'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDiagnosticItem('System Notifications', systemStatus),
              _buildDiagnosticItem(
                'App Toggle',
                settings.notificationsEnabled ? '✅ ON' : '❌ OFF',
              ),
              const Divider(height: 24),
              _buildDiagnosticItem(
                'Notification Permission',
                settings.hasNotificationPermission ? '✅' : '❌',
              ),
              _buildDiagnosticItem(
                'Exact Alarm Permission',
                settings.hasExactAlarmPermission ? '✅' : '❌',
              ),
              _buildDiagnosticItem(
                'Full Screen Permission',
                settings.hasFullScreenIntentPermission ? '✅' : '❌',
              ),
              _buildDiagnosticItem(
                'Overlay Permission',
                settings.hasOverlayPermission ? '✅' : '❌',
              ),
              _buildDiagnosticItem(
                'Battery Unrestricted',
                settings.hasBatteryOptimizationExemption ? '✅' : '❌',
              ),
              const Divider(height: 24),
              _buildDiagnosticItem(
                'Alarm Mode',
                settings.alarmModeEnabled ? 'Enabled' : 'Disabled',
              ),
              _buildDiagnosticItem(
                'Sound',
                settings.soundEnabled ? 'ON' : 'OFF',
              ),
              _buildDiagnosticItem(
                'Vibration',
                settings.vibrationEnabled ? 'ON' : 'OFF',
              ),
              _buildDiagnosticItem(
                'Default Channel',
                NotificationSettings.getChannelDisplayName(
                  settings.defaultChannel,
                ),
              ),
              _buildDiagnosticItem(
                'Quiet Hours',
                settings.quietHoursEnabled ? 'Active' : 'Inactive',
              ),
              const Divider(height: 24),
              _buildDiagnosticItem(
                'Pending Count',
                '$_pendingNotificationsCount',
              ),
              const SizedBox(height: 16),
              Text(
                'If test notifications don\'t appear, try:\n• Uninstall and reinstall the app\n• Check Android notification settings\n• Ensure battery optimization is disabled',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.black54,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColorSchemes.primaryGold,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// Reusable Widgets
// ============================================

class _SettingsToggle extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final IconData icon;
  final Color color;
  final ValueChanged<bool>? onChanged; // Nullable to support disabled state
  final bool compact;

  const _SettingsToggle({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.icon,
    required this.color,
    this.onChanged, // Optional - null means disabled
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsToggle(
      title: title,
      subtitle: subtitle,
      value: value,
      icon: icon,
      color: color,
      onChanged: onChanged,
      compact: compact,
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      title: title,
      value: value,
      icon: icon,
      color: color,
      onTap: onTap,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.03)
            : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(12),
        border: isCritical && !isGranted
            ? Border.all(color: Colors.orange.withOpacity(0.3), width: 1)
            : null,
      ),
      child: Row(
        children: [
          Icon(
            isGranted ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: isGranted
                ? Colors.green
                : (isCritical ? Colors.red : Colors.orange),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (isCritical && !isGranted) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Required',
                          style: TextStyle(
                            color: Colors.red,
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
                      color: isDark ? Colors.white38 : Colors.black45,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!isGranted)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: isCritical
                    ? Colors.red
                    : AppColorSchemes.primaryGold,
                backgroundColor:
                    (isCritical ? Colors.red : AppColorSchemes.primaryGold)
                        .withOpacity(0.1),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                isCritical ? 'Enable' : 'Fix',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_rounded, size: 12, color: Colors.green),
                  const SizedBox(width: 4),
                  const Text(
                    'Active',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
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

class _ModernPickerSheet extends StatelessWidget {
  final String title;
  final bool isDark;
  final Widget child;

  const _ModernPickerSheet({
    required this.title,
    required this.isDark,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2230) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 24),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: child,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _TimePickerTile extends StatelessWidget {
  final String label;
  final int timeMinutes;
  final bool isDark;
  final VoidCallback onTap;

  const _TimePickerTile({
    required this.label,
    required this.timeMinutes,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.03)
              : Colors.black.withOpacity(0.02),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(
              NotificationSettings.formatMinutesToTime(timeMinutes),
              style: const TextStyle(
                color: AppColorSchemes.primaryGold,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
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

class _FeedbackOption {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onPreview;
  final IconData icon;

  _FeedbackOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.onPreview,
    required this.icon,
  });
}
