import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/notification_settings.dart';
import '../../../../core/services/android_system_status.dart';
import '../../../../core/providers/notification_settings_provider.dart';
import '../../../../core/theme/color_schemes.dart';
import '../../../../core/widgets/settings_widgets.dart';
import '../widgets/hub_sound_picker.dart';
import '../widgets/hub_vibration_picker.dart';

/// Global notification settings page – hub-wide defaults used by all modules.
///
/// Uses [notificationSettingsProvider] so all changes propagate to
/// [NotificationService] and the hub immediately.
class HubGlobalSettingsPage extends ConsumerStatefulWidget {
  const HubGlobalSettingsPage({super.key});

  @override
  ConsumerState<HubGlobalSettingsPage> createState() =>
      _HubGlobalSettingsPageState();
}

class _HubGlobalSettingsPageState extends ConsumerState<HubGlobalSettingsPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(notificationSettingsProvider.notifier).refreshPermissionStates();
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(notificationSettingsProvider);
    final notifier = ref.read(notificationSettingsProvider.notifier);

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      physics: const BouncingScrollPhysics(),
      children: [
        // ── Master toggle ──
        SettingsSection(
          title: 'GENERAL',
          icon: Icons.tune_rounded,
          child: Column(
            children: [
              SettingsToggle(
                title: 'Notifications Enabled',
                subtitle: 'Master toggle for all notifications',
                value: settings.notificationsEnabled,
                icon: Icons.notifications_active_rounded,
                color: AppColorSchemes.primaryGold,
                onChanged: (v) => notifier.setNotificationsEnabled(v),
              ),
              _buildDivider(isDark),
              _buildPermissionStatusLine(settings, notifier),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Sound & vibration ──
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
                color: colorScheme.secondary,
                onChanged: (v) => notifier.setSoundEnabled(v),
              ),
              if (settings.soundEnabled) ...[
                _buildDivider(isDark),
                SettingsTile(
                  title: 'Default Sound',
                  value: NotificationSettings.getSoundDisplayName(
                    settings.defaultSound,
                  ),
                  icon: Icons.graphic_eq_rounded,
                  color: colorScheme.secondary,
                  onTap: () async {
                    final picked = await HubSoundPicker.show(
                      context,
                      currentSoundId: settings.defaultSound,
                      title: 'Default Notification Tone',
                    );
                    if (picked != null && mounted) {
                      await notifier.setDefaultSound(picked);
                    }
                  },
                ),
              ],
              _buildDivider(isDark),
              SettingsToggle(
                title: 'Vibration',
                subtitle: 'Tactile feedback for alerts',
                value: settings.vibrationEnabled,
                icon: Icons.vibration_rounded,
                color: AppColorSchemes.success,
                onChanged: (v) => notifier.setVibrationEnabled(v),
              ),
              if (settings.vibrationEnabled) ...[
                _buildDivider(isDark),
                SettingsTile(
                  title: 'Vibration Pattern',
                  value: NotificationSettings.getVibrationDisplayName(
                    settings.defaultVibrationPattern,
                  ),
                  icon: Icons.waves_rounded,
                  color: AppColorSchemes.success,
                  onTap: () async {
                    final picked = await HubVibrationPicker.show(
                      context,
                      currentPatternId: settings.defaultVibrationPattern,
                      title: 'Default Vibration',
                    );
                    if (picked != null && mounted) {
                      await notifier.setDefaultVibrationPattern(picked);
                    }
                  },
                ),
              ],
              _buildDivider(isDark),
              SettingsToggle(
                title: 'LED Indicator',
                subtitle: 'Flash LED light for notifications',
                value: settings.ledEnabled,
                icon: Icons.lightbulb_outline_rounded,
                color: Colors.amber,
                onChanged: (v) => notifier.setLedEnabled(v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Audio stream ──
        SettingsSection(
          title: 'AUDIO CHANNEL',
          icon: Icons.speaker_group_rounded,
          child: Column(
            children: [
              SettingsTile(
                title: 'Audio Stream',
                value: _displayName(settings.notificationAudioStream),
                icon: Icons.volume_up_rounded,
                color: Colors.deepPurple,
                onTap: () => _showStreamPicker(context, settings, notifier),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Snooze ──
        SettingsSection(
          title: 'SNOOZE OPTIONS',
          icon: Icons.snooze_rounded,
          child: Column(
            children: [
              SettingsTile(
                title: 'Default Snooze Duration',
                value: '${settings.defaultSnoozeDuration} minutes',
                icon: Icons.timer_rounded,
                color: theme.colorScheme.tertiary,
                onTap: () => _showSnoozePicker(context, settings, notifier),
              ),
              _buildDivider(isDark),
              SettingsTile(
                title: 'Max Snooze Count',
                value: '${settings.maxSnoozeCount}',
                icon: Icons.repeat_rounded,
                color: theme.colorScheme.tertiary,
                onTap: () => _showMaxSnoozePicker(context, settings, notifier),
              ),
              _buildDivider(isDark),
              SettingsToggle(
                title: 'Smart Snooze',
                subtitle: 'Adjusts snooze based on priority',
                value: settings.smartSnooze,
                icon: Icons.auto_fix_high_rounded,
                color: AppColorSchemes.success,
                onChanged: (v) => notifier.setSmartSnooze(v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Reliability (nek12 Layer 5: OEM guidance) ──
        if (Platform.isAndroid) _buildReliabilitySection(context, isDark),

        // ── Display ──
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
                color: Colors.blue,
                onChanged: (v) => notifier.setShowOnLockScreen(v),
              ),
              _buildDivider(isDark),
              SettingsToggle(
                title: 'Wake Screen',
                subtitle: 'Wake device for alerts',
                value: settings.wakeScreen,
                icon: Icons.screen_lock_portrait_rounded,
                color: Colors.blue,
                onChanged: (v) => notifier.setWakeScreen(v),
              ),
              _buildDivider(isDark),
              SettingsToggle(
                title: 'Persistent Notifications',
                subtitle: 'Keep notifications until dismissed',
                value: settings.persistentNotifications,
                icon: Icons.push_pin_rounded,
                color: theme.colorScheme.tertiary,
                onChanged: (v) => notifier.setPersistentNotifications(v),
              ),
              _buildDivider(isDark),
              SettingsToggle(
                title: 'Group Notifications',
                subtitle: 'Group by app',
                value: settings.groupNotifications,
                icon: Icons.folder_open_rounded,
                color: Colors.teal,
                onChanged: (v) => notifier.setGroupNotifications(v),
              ),
              _buildDivider(isDark),
              SettingsToggle(
                title: 'Auto-Expand',
                subtitle: 'Show expanded content by default',
                value: settings.autoExpandNotifications,
                icon: Icons.unfold_more_rounded,
                color: Colors.teal,
                onChanged: (v) => notifier.setAutoExpandNotifications(v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildReliabilitySection(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsSection(
          title: 'RELIABILITY',
          icon: Icons.verified_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 16, 12),
                child: Text(
                  'For best delivery when the app is closed, disable battery '
                  'optimization for this app. Some devices (Xiaomi, Samsung, '
                  'Huawei) need extra steps – search "dontkillmyapp" for guides.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
              _buildDivider(isDark),
              SettingsTile(
                title: 'Open Battery Settings',
                value: 'Tap to open',
                icon: Icons.battery_charging_full_rounded,
                color: AppColorSchemes.success,
                onTap: () => AndroidSystemStatus.openAppDetailsSettings(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildPermissionStatusLine(
    NotificationSettings settings,
    NotificationSettingsNotifier notifier,
  ) {
    final hasPermission = settings.hasNotificationPermission;
    final statusColor = hasPermission ? AppColorSchemes.success : Colors.red;
    final statusText = hasPermission ? 'Allowed' : 'Blocked';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_rounded, size: 18, color: statusColor),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Notifications permission',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                statusText,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ],
          ),
          if (!hasPermission) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                await notifier.openNotificationSettings();
                await notifier.refreshPermissionStates();
              },
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Open notification settings'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 56,
      color: AppColorSchemes.textSecondary.withValues(
        alpha: isDark ? 0.2 : 0.1,
      ),
    );
  }

  // ── Pickers ──

  void _showStreamPicker(
    BuildContext context,
    NotificationSettings settings,
    NotificationSettingsNotifier notifier,
  ) {
    final streams = ['notification', 'alarm', 'ring', 'media'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    'Select Audio Stream',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...streams.map((s) {
                    final selected = s == settings.notificationAudioStream;
                    return ListTile(
                      leading: Icon(
                        selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      title: Text(_displayName(s)),
                      onTap: () {
                        notifier.setNotificationAudioStream(s);
                        Navigator.of(ctx).pop();
                      },
                    );
                  }),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSnoozePicker(
    BuildContext context,
    NotificationSettings settings,
    NotificationSettingsNotifier notifier,
  ) {
    final options = [5, 10, 15, 20, 30, 45, 60];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    'Default Snooze Duration',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...options.map((m) {
                    final selected = m == settings.defaultSnoozeDuration;
                    return ListTile(
                      leading: Icon(
                        selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      title: Text('$m minutes'),
                      onTap: () {
                        notifier.setDefaultSnoozeDuration(m);
                        Navigator.of(ctx).pop();
                      },
                    );
                  }),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showMaxSnoozePicker(
    BuildContext context,
    NotificationSettings settings,
    NotificationSettingsNotifier notifier,
  ) {
    final options = [1, 2, 3, 5, 10];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    'Max Snooze Count',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...options.map((m) {
                    final selected = m == settings.maxSnoozeCount;
                    return ListTile(
                      leading: Icon(
                        selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      title: Text('$m times'),
                      onTap: () {
                        notifier.setMaxSnoozeCount(m);
                        Navigator.of(ctx).pop();
                      },
                    );
                  }),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _displayName(String stream) {
    switch (stream) {
      case 'notification':
        return 'Notification';
      case 'alarm':
        return 'Alarm';
      case 'ring':
        return 'Ring';
      case 'media':
        return 'Media';
      default:
        return stream;
    }
  }
}
