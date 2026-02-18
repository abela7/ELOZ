import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/notifications/notifications.dart';
import '../../../../core/services/alarm_service.dart';
import '../../../../core/notifications/services/notification_recovery_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/widgets/settings_widgets.dart';
import '../../../../data/repositories/task_repository.dart';
import '../../../habits/data/repositories/habit_repository.dart';
import '../../../habits/data/models/habit_notification_settings.dart';
import '../../../habits/presentation/screens/settings/habit_notification_settings_screen.dart';
import '../widgets/hub_habit_scheduled_section.dart';
import 'hub_orphaned_notifications_page.dart';

/// Habit Module Notification Management Page
///
/// Overview, Scheduled, and Settings for Habit Manager reminders.
/// Aligns with Finance and Sleep module pages.
class HubHabitModulePage extends StatefulWidget {
  const HubHabitModulePage({super.key});

  @override
  State<HubHabitModulePage> createState() => _HubHabitModulePageState();
}

class _HubHabitModulePageState extends State<HubHabitModulePage>
    with SingleTickerProviderStateMixin {
  final NotificationHub _hub = NotificationHub();
  late TabController _tabController;

  HubModuleNotificationSettings? _settings;
  int _scheduledCount = 0;
  int _orphanedCount = 0;
  bool _loading = true;
  int _scheduledRefreshKey = 0;

  static const _habitColor = Colors.deepPurple;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    await _hub.initialize();

    _settings = await _hub.getModuleSettings(NotificationHubModuleIds.habit);
    _scheduledCount = await _hub.getScheduledCountForModule(
      NotificationHubModuleIds.habit,
    );
    _orphanedCount = await _countOrphanedNotifications('habit');

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveSettings(HubModuleNotificationSettings settings) async {
    await _hub.setModuleSettings(NotificationHubModuleIds.habit, settings);
    await _syncLegacyHabitToggle(settings.notificationsEnabled);
    setState(() => _settings = settings);
  }

  Future<void> _syncLegacyHabitToggle(bool? enabled) async {
    if (enabled == null) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(habitNotificationSettingsKey);
    final current = raw == null
        ? HabitNotificationSettings.defaults
        : HabitNotificationSettings.fromJsonString(raw);
    final updated = current.copyWith(notificationsEnabled: enabled);
    await prefs.setString(habitNotificationSettingsKey, updated.toJsonString());
    try {
      await NotificationService().reloadSettings();
    } catch (_) {
      // Best-effort sync with legacy habit settings screen.
    }
  }

  Future<void> _syncNotifications() async {
    setState(() => _loading = true);

    try {
      final result = await NotificationRecoveryService.runRecovery(
        bootstrapForBackground: false,
        sourceFlow: 'hub_habit_manual_sync',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.success
                  ? 'Synced: ${result.habitRescheduled} habit reminders rescheduled'
                  : 'Sync failed: ${result.error}',
            ),
            backgroundColor: result.success ? Colors.green : Colors.red,
          ),
        );
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _clearAllScheduled() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Habit Notifications?'),
        content: const Text(
          'This will cancel all scheduled habit reminders. '
          'You can re-sync them from the Habit Manager or here.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final count = await _hub.cancelForModule(
        moduleId: NotificationHubModuleIds.habit,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cleared $count notification(s)'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() => _scheduledRefreshKey++);
        await _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_loading || _settings == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0F14) : const Color(0xFFF8F9FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: theme.colorScheme.onSurface,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _habitColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: _habitColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Habit Notifications',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: theme.colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sync Notifications',
            onPressed: _syncNotifications,
            icon: Icon(
              Icons.sync_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: Icon(
              Icons.refresh_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: _habitColor,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          indicatorColor: _habitColor,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Scheduled'),
            Tab(text: 'Settings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(isDark),
          _buildScheduledTab(isDark),
          _buildSettingsTab(isDark),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildOrphanWarning(isDark),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.notifications_active_rounded,
                label: 'Scheduled',
                value: _scheduledCount.toString(),
                color: Colors.deepPurple,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: _orphanedCount > 0
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_rounded,
                label: _orphanedCount > 0 ? 'Orphaned' : 'Status',
                value: _orphanedCount > 0
                    ? _orphanedCount.toString()
                    : (_settings?.notificationsEnabled ?? true
                        ? 'Active'
                        : 'Disabled'),
                color: _orphanedCount > 0
                    ? Colors.orange
                    : (_settings?.notificationsEnabled ?? true
                        ? Colors.green
                        : Colors.red),
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        SettingsSection(
          title: 'QUICK ACTIONS',
          icon: Icons.flash_on_rounded,
          child: Column(
            children: [
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _habitColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.sync_rounded,
                    color: _habitColor,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Sync All Habit Reminders',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                subtitle: const Text(
                  'Re-schedule reminders for all habits',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: _syncNotifications,
              ),
              _buildDivider(isDark),
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _habitColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: _habitColor,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Open Habit Manager',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                subtitle: const Text(
                  'Add or edit habits and their reminders',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pop();
                  context.go('/habits');
                },
              ),
              _buildDivider(isDark),
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.clear_all_rounded,
                    color: Colors.red,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Clear All Scheduled',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                subtitle: const Text(
                  'Cancel all pending habit notifications',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: _clearAllScheduled,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1D23) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.06),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 20,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Habit reminders are set per habit when creating or editing. '
                  'Use Habit Manager to add reminders (e.g. "At habit time", "5 min before").',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScheduledTab(bool isDark) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          HabitScheduledSection(
            hub: _hub,
            isDark: isDark,
            refreshKey: _scheduledRefreshKey,
            onDeleted: () => setState(() => _scheduledRefreshKey++),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SettingsSection(
          title: 'GENERAL',
          icon: Icons.tune_rounded,
          child: Column(
            children: [
              SwitchListTile(
                value: _settings?.notificationsEnabled ?? true,
                onChanged: (val) {
                  _saveSettings(_settings!.copyWith(notificationsEnabled: val));
                },
                title: const Text(
                  'Enable Habit Notifications',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  _settings?.notificationsEnabled ?? true
                      ? 'All habit reminders are active'
                      : 'Habit reminders are disabled',
                  style: const TextStyle(fontSize: 12),
                ),
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _habitColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    color: _habitColor,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _habitColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.settings_rounded,
              color: _habitColor,
              size: 20,
            ),
          ),
          title: const Text(
            'Habit Notification Settings',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          subtitle: const Text(
            'Sounds, special reminders, diagnostics',
            style: TextStyle(fontSize: 12),
          ),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const HabitNotificationSettingsScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Reset Habit Notification Settings?'),
                  content: const Text(
                    'This will reset Habit notification settings in the Hub to defaults. '
                    'Reminders will stay scheduled; only Hub-level overrides are cleared.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              );
              if (confirmed == true && mounted) {
                HapticFeedback.heavyImpact();
                await _saveSettings(HubModuleNotificationSettings.empty);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Settings reset to defaults'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            icon: const Icon(
              Icons.restart_alt_rounded,
              size: 18,
              color: Colors.red,
            ),
            label: const Text(
              'Reset Hub Settings',
              style: TextStyle(color: Colors.red),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.red.withOpacity(0.3)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D23) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 56,
      color: isDark
          ? Colors.white.withOpacity(0.08)
          : Colors.black.withOpacity(0.06),
    );
  }

  /// Counts pending notifications whose parent entity no longer exists.
  /// Includes native alarms (AlarmBootReceiver) - Android has no API to list
  /// AlarmManager alarms; we read our own persistence.
  Future<int> _countOrphanedNotifications(String type) async {
    try {
      final habitRepo = HabitRepository();
      final taskRepo = TaskRepository();

      final habitIds =
          (await habitRepo.getAllHabits(includeArchived: true))
              .map((h) => h.id)
              .toSet();
      final taskIds =
          (await taskRepo.getAllTasks()).map((t) => t.id).toSet();

      var count = 0;

      final all =
          await NotificationService().getDetailedPendingNotifications();
      count += all.where((info) {
        if (info.entityId.isEmpty) return false;
        if (info.type != type) return false;
        if (info.type == 'habit') return !habitIds.contains(info.entityId);
        if (info.type == 'task') return !taskIds.contains(info.entityId);
        return false;
      }).length;

      if (Platform.isAndroid) {
        final native = await AlarmService().getScheduledAlarmsFromNative();
        for (final alarm in native) {
          final payload = alarm['payload'] as String? ?? '';
          final parts = payload.split('|');
          if (parts.length < 2 || parts[0] != type) continue;
          final entityId = parts[1];
          if (entityId.isEmpty) continue;
          final isOrphan = type == 'habit'
              ? !habitIds.contains(entityId)
              : !taskIds.contains(entityId);
          if (isOrphan) count++;
        }
      }

      return count;
    } catch (_) {
      return 0;
    }
  }

  Widget _buildOrphanWarning(bool isDark) {
    if (_orphanedCount == 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  const HubOrphanedNotificationsPage(filterType: 'habit'),
            ),
          );
          _load(); // Refresh counts after returning
        },
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.orange, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_orphanedCount orphaned notification${_orphanedCount == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Notifications for deleted habits still pending',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ],
        ),
      ),
    );
  }
}
