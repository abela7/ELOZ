import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/notification_settings.dart';
import '../../../../core/models/special_task_sound.dart';
import '../../../../core/models/vibration_pattern.dart';
import '../../../../core/notifications/models/hub_module_notification_settings.dart';
import '../../../../core/notifications/models/hub_notification_type.dart';
import '../../../../core/notifications/notifications.dart';
import '../../../../core/theme/color_schemes.dart';
import '../../../../core/widgets/settings_widgets.dart';
import '../../../finance/data/models/bill.dart';
import '../../../finance/data/repositories/bill_repository.dart';
import '../../../finance/notifications/finance_notification_contract.dart';
import '../../../finance/notifications/finance_notification_scheduler.dart';
import '../../../../core/notifications/models/hub_custom_notification_type.dart';
import '../widgets/hub_finance_scheduled_section.dart';
import '../widgets/hub_robust_type_list.dart';
import '../widgets/hub_sound_picker.dart';
import '../widgets/hub_vibration_picker.dart';

/// Finance Module Notification Management Page
/// 
/// Comprehensive management for all Finance notifications with:
/// - Notification type overview and configuration
/// - Scheduled notifications list
/// - Test notification feature
/// - Diagnostics and sync status
class HubFinanceModulePage extends StatefulWidget {
  const HubFinanceModulePage({super.key});

  @override
  State<HubFinanceModulePage> createState() => _HubFinanceModulePageState();
}

class _HubFinanceModulePageState extends State<HubFinanceModulePage>
    with SingleTickerProviderStateMixin {
  final NotificationHub _hub = NotificationHub();
  final BillRepository _billRepo = BillRepository();
  final FinanceNotificationScheduler _scheduler = FinanceNotificationScheduler();
  
  late TabController _tabController;
  
  HubModuleNotificationSettings? _settings;
  List<HubNotificationType> _types = [];
  Map<String, HubCustomNotificationType> _customTypesById = {};
  List<HubNotificationSection> _sections = [];
  List<Bill> _activeBills = [];
  int _scheduledCount = 0;
  bool _loading = true;
  int _scheduledRefreshKey = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
    
    _settings = await _hub.getModuleSettings(FinanceNotificationContract.moduleId);
    _types = _hub.typeRegistry
        .typesForModule(FinanceNotificationContract.moduleId)
        .toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
    final customTypes =
        await _hub.customTypeStore.getAllForModule(FinanceNotificationContract.moduleId);
    _customTypesById = {for (final t in customTypes) t.id: t};
    final adapter = _hub.adapterFor(FinanceNotificationContract.moduleId);
    _sections = adapter?.sections ?? [];
    _activeBills = await _billRepo.getActiveBills();
    _scheduledCount = await _hub.getScheduledCountForModule(
      FinanceNotificationContract.moduleId,
    );
    
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveSettings(HubModuleNotificationSettings settings) async {
    await _hub.setModuleSettings(FinanceNotificationContract.moduleId, settings);
    setState(() => _settings = settings);
  }

  Future<void> _syncNotifications() async {
    setState(() => _loading = true);
    
    try {
      final result = await _scheduler.syncSchedules();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sync complete: ${result.scheduled} scheduled, ${result.cancelled} cancelled',
            ),
            backgroundColor: Colors.green,
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

  // ignore: unused_element - kept for potential Overview quick-test; HubRobustTypeList has its own test
  Future<void> _testNotification(HubNotificationType type) async {
    HapticFeedback.mediumImpact();
    
    // Get a real bill for realistic test data
    Bill? sampleBill;
    if (_activeBills.isNotEmpty) {
      // Prefer a bill with reminder enabled
      sampleBill = _activeBills.firstWhere(
        (b) => b.reminderEnabled,
        orElse: () => _activeBills.first,
      );
    }
    
    // Build realistic message based on type and template
    final testMessage = _buildTestMessage(type, sampleBill);
    
    // Determine priority based on type
    final priorityTier = _getPriorityForType(type.id);
    final priority = _priorityLabel(priorityTier);
    
    final result = await _hub.schedule(
      NotificationHubScheduleRequest(
        moduleId: FinanceNotificationContract.moduleId,
        entityId: 'test:${type.id}:${DateTime.now().millisecondsSinceEpoch}',
        title: testMessage.title,
        body: testMessage.body,
        scheduledAt: DateTime.now().add(const Duration(seconds: 3)),
        type: type.id,
        priority: priority,
        // Include real bill icon if available
        iconCodePoint: sampleBill?.iconCodePoint,
        iconFontFamily: sampleBill?.iconFontFamily,
        iconFontPackage: sampleBill?.iconFontPackage,
        colorValue: sampleBill?.colorValue,
        extras: {
          FinanceNotificationContract.extraManagedBy: FinanceNotificationContract.managedBy,
          FinanceNotificationContract.extraSection: FinanceNotificationContract.sectionBills,
          FinanceNotificationContract.extraScreen: FinanceNotificationContract.screenBills,
          FinanceNotificationContract.extraSource: FinanceNotificationContract.sourceBills,
          FinanceNotificationContract.extraTemplate: FinanceNotificationContract.templateBillDue,
          FinanceNotificationContract.extraPriorityTier: priorityTier,
          if (sampleBill != null)
            FinanceNotificationContract.extraTargetEntityId: sampleBill.id,
          'isTest': 'true',
        },
      ),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result.success
                    ? 'Test notification scheduled (3 seconds)'
                    : 'Failed to schedule test notification',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (result.success) ...[
                const SizedBox(height: 4),
                Text(
                  'Using ${type.defaultConfig.channelKey} channel • ${type.defaultConfig.audioStream} stream',
                  style: const TextStyle(fontSize: 12),
                ),
                if (type.defaultConfig.useAlarmMode)
                  const Text(
                    'Alarm mode enabled • Will bypass silent mode',
                    style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                  ),
              ],
            ],
          ),
          backgroundColor: result.success ? Colors.green : Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  /// Builds a realistic test message based on notification type
  ({String title, String body}) _buildTestMessage(
    HubNotificationType type,
    Bill? sampleBill,
  ) {
    // Use real bill data if available, otherwise use realistic sample
    final billName = sampleBill?.name ?? 'Netflix Subscription';
    final currency = sampleBill?.currency ?? '\$';
    final amount = sampleBill?.defaultAmount.toStringAsFixed(2) ?? '15.99';
    final amountStr = '$currency$amount';
    
    // Calculate realistic due date based on type
    final now = DateTime.now();
    DateTime dueDate;
    int dueDays;
    bool isOverdue;
    
    switch (type.id) {
      case FinanceNotificationContract.typeBillOverdue:
        dueDate = now.subtract(const Duration(days: 2));
        dueDays = -2;
        isOverdue = true;
        break;
      case FinanceNotificationContract.typePaymentDue:
        dueDate = now;
        dueDays = 0;
        isOverdue = false;
        break;
      case FinanceNotificationContract.typeBillTomorrow:
        dueDate = now.add(const Duration(days: 1));
        dueDays = 1;
        isOverdue = false;
        break;
      case FinanceNotificationContract.typeBillUpcoming:
        dueDate = now.add(const Duration(days: 3));
        dueDays = 3;
        isOverdue = false;
        break;
      default:
        dueDate = now.add(const Duration(days: 3));
        dueDays = 3;
        isOverdue = false;
    }
    
    final dueLabel = DateFormat('MMM d').format(dueDate);
    
    // Build message using same logic as production scheduler
    final title = isOverdue
        ? '$billName payment overdue'
        : dueDays == 0
        ? '$billName is due today'
        : '$billName due in $dueDays day${dueDays == 1 ? '' : 's'}';
    
    final body = '$amountStr - due $dueLabel';
    
    return (title: title, body: body);
  }

  String _getPriorityForType(String typeId) {
    switch (typeId) {
      case FinanceNotificationContract.typeBillOverdue:
        return 'high';
      case FinanceNotificationContract.typePaymentDue:
        return 'high';
      case FinanceNotificationContract.typeBillTomorrow:
        return 'medium';
      case FinanceNotificationContract.typeBillUpcoming:
        return 'low';
      default:
        return 'medium';
    }
  }

  String _priorityLabel(String priorityTier) {
    switch (priorityTier) {
      case 'high':
        return 'High';
      case 'low':
        return 'Low';
      default:
        return 'Medium';
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
                color: const Color(0xFFCDAF56).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: Color(0xFFCDAF56),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Finance Notifications',
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
          labelColor: AppColorSchemes.primaryGold,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          indicatorColor: AppColorSchemes.primaryGold,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Notification Types'),
            Tab(text: 'Scheduled'),
            Tab(text: 'Settings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(isDark),
          _buildTypesTab(isDark),
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
        // Stats Cards
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.notifications_active_rounded,
                label: 'Scheduled',
                value: _scheduledCount.toString(),
                color: Colors.blue,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.receipt_rounded,
                label: 'Active Bills',
                value: _activeBills.length.toString(),
                color: Colors.green,
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.category_rounded,
                label: 'Types',
                value: _types.length.toString(),
                color: Colors.orange,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.check_circle_rounded,
                label: 'Status',
                value: _settings?.notificationsEnabled ?? true ? 'Active' : 'Disabled',
                color: _settings?.notificationsEnabled ?? true ? Colors.green : Colors.red,
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Quick Actions
        SettingsSection(
          title: 'QUICK ACTIONS',
          icon: Icons.flash_on_rounded,
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.sync_rounded, color: Colors.blue, size: 20),
                ),
                title: const Text(
                  'Sync All Notifications',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                subtitle: const Text(
                  'Re-schedule all finance notifications',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: _syncNotifications,
              ),
              _buildDivider(isDark),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.clear_all_rounded, color: Colors.red, size: 20),
                ),
                title: const Text(
                  'Clear All Scheduled',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                subtitle: const Text(
                  'Cancel all pending finance notifications',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Clear All Notifications?'),
                      content: const Text(
                        'This will cancel all scheduled finance notifications. '
                        'You can re-sync them anytime.',
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

                  if (confirmed == true) {
                    final count = await _scheduler.clearScheduledNotifications();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Cleared $count notifications'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      await _load();
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTypesTab(bool isDark) {
    return HubRobustTypeList(
      hub: _hub,
      moduleId: FinanceNotificationContract.moduleId,
      moduleDisplayName: 'Finance Manager',
      settings: _settings ?? HubModuleNotificationSettings.empty,
      types: _types,
      customTypesById: _customTypesById,
      sections: _sections,
      isDark: isDark,
      moduleColor: const Color(0xFFCDAF56),
      onSaveSettings: _saveSettings,
      onReload: _load,
    );
  }

  Widget _buildScheduledTab(bool isDark) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          FinanceScheduledSection(
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
        // General Settings
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
                  'Enable Finance Notifications',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  _settings?.notificationsEnabled ?? true
                      ? 'All finance notifications are active'
                      : 'Finance notifications are disabled',
                  style: const TextStyle(fontSize: 12),
                ),
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCDAF56).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    color: Color(0xFFCDAF56),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Sound & Feedback
        SettingsSection(
          title: 'SOUND & FEEDBACK',
          icon: Icons.volume_up_rounded,
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.music_note_rounded, color: Colors.purple, size: 20),
                ),
                title: const Text(
                  'Default Sound',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                subtitle: Text(
                  _soundDisplayName(_settings?.defaultSound),
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () async {
                  final currentSound = _settings?.defaultSound ?? '';
                  final picked = await HubSoundPicker.show(
                    context,
                    currentSoundId: currentSound,
                    title: 'Default Sound for All Types',
                  );
                  if (picked != null) {
                    _saveSettings(_settings!.copyWith(defaultSound: picked));
                  }
                },
              ),
              _buildDivider(isDark),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.vibration_rounded, color: Colors.orange, size: 20),
                ),
                title: const Text(
                  'Default Vibration',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                subtitle: Text(
                  _vibrationDisplayName(_settings?.defaultVibrationPattern),
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () async {
                  final currentPattern = _settings?.defaultVibrationPattern ?? '';
                  final picked = await HubVibrationPicker.show(
                    context,
                    currentPatternId: currentPattern,
                    title: 'Default Vibration for All Types',
                  );
                  if (picked != null) {
                    _saveSettings(_settings!.copyWith(defaultVibrationPattern: picked));
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        const SizedBox(height: 24),

        // Reset Button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Reset All Settings?'),
                  content: const Text(
                    'This will reset all Finance notification settings to defaults:\n\n'
                    '• Enable notifications: ON\n'
                    '• Default sound: System default\n'
                    '• Default vibration: Default\n'
                    '• All per-type overrides: cleared\n\n'
                    'This cannot be undone.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Reset All'),
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
                      content: Text('All settings reset to defaults'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.restart_alt_rounded, size: 18, color: Colors.red),
            label: const Text('Reset All Settings', style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.red.withOpacity(0.3)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
    );
  }

  String _soundDisplayName(String? soundId) {
    if (soundId == null || soundId.isEmpty) return 'Default for all types';
    if (soundId == 'silent') return 'Silent';
    if (soundId == 'default') return 'System Default';
    if (soundId.startsWith('content://')) {
      return NotificationSettings.getSoundDisplayName(soundId);
    }
    return SpecialTaskSound.getDisplayName(soundId);
  }

  String _vibrationDisplayName(String? patternId) {
    if (patternId == null || patternId.isEmpty) return 'Default for all types';
    return VibrationPattern.getDisplayName(patternId);
  }

}
