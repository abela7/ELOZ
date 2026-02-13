import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/models/special_task_sound.dart';
import '../../../../core/models/vibration_pattern.dart';
import '../../../../core/notifications/models/hub_module_notification_settings.dart';
import '../../../../core/notifications/models/hub_notification_type.dart';
import '../../../../core/notifications/notifications.dart';
import '../../../../core/theme/color_schemes.dart';
import '../../../../core/widgets/settings_widgets.dart';
import '../../../finance/notifications/finance_notification_contract.dart';
import '../widgets/hub_sound_picker.dart';
import '../widgets/hub_template_designer.dart';
import '../widgets/hub_vibration_picker.dart';
import 'hub_finance_module_page.dart';

/// Per-module notification settings page.
///
/// Shows a tab for each registered module. Each field shows "Using global
/// default" with the ability to toggle an override.
class HubModuleSettingsPage extends StatefulWidget {
  const HubModuleSettingsPage({super.key});

  @override
  State<HubModuleSettingsPage> createState() => _HubModuleSettingsPageState();
}

class _HubModuleSettingsPageState extends State<HubModuleSettingsPage>
    with SingleTickerProviderStateMixin {
  final NotificationHub _hub = NotificationHub();
  TabController? _tabController;
  List<NotificationHubModule> _modules = [];
  Map<String, HubModuleNotificationSettings> _allSettings = {};
  Map<String, List<HubNotificationType>> _moduleTypes = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await _hub.initialize();
    _modules = _hub.getRegisteredModules();
    _moduleTypes = <String, List<HubNotificationType>>{};
    for (final m in _modules) {
      _allSettings[m.moduleId] = await _hub.getModuleSettings(m.moduleId);
      final moduleTypes = _hub.typeRegistry.typesForModule(m.moduleId).toList()
        ..sort((a, b) => a.displayName.compareTo(b.displayName));
      _moduleTypes[m.moduleId] = moduleTypes;
    }
    _tabController?.dispose();
    _tabController = TabController(length: _modules.length, vsync: this);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save(String moduleId, HubModuleNotificationSettings s) async {
    await _hub.setModuleSettings(moduleId, s);
    setState(() => _allSettings[moduleId] = s);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _tabController == null) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (_modules.isEmpty) {
      return Center(
        child: Text(
          'No modules registered.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    final theme = Theme.of(context);

    return Column(
      children: [
        // ── Module tabs ──
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: _modules.length > 3,
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: theme.colorScheme.primary,
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: theme.colorScheme.onPrimary,
            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: _modules.map((m) => Tab(text: m.displayName)).toList(),
          ),
        ),
        const SizedBox(height: 8),
        // ── Tab content ──
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: _modules.map((m) {
              final settings =
                  _allSettings[m.moduleId] ?? HubModuleNotificationSettings.empty;
              return _ModuleSettingsBody(
                moduleId: m.moduleId,
                settings: settings,
                moduleTypes:
                    _moduleTypes[m.moduleId] ?? const <HubNotificationType>[],
                onUpdate: (s) => _save(m.moduleId, s),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ─── Body for one module ───────────────────────────────────────────────────

class _ModuleSettingsBody extends StatelessWidget {
  final String moduleId;
  final HubModuleNotificationSettings settings;
  final List<HubNotificationType> moduleTypes;
  final ValueChanged<HubModuleNotificationSettings> onUpdate;

  const _ModuleSettingsBody({
    required this.moduleId,
    required this.settings,
    required this.moduleTypes,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
      children: [
        // ── Enhanced Module Management (Finance only for now) ──
        if (moduleId == FinanceNotificationContract.moduleId) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFCDAF56).withOpacity(0.15),
                  const Color(0xFFCDAF56).withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFCDAF56).withOpacity(0.3),
              ),
            ),
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const HubFinanceModulePage(),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCDAF56).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Color(0xFFCDAF56),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Finance Module Manager',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFCDAF56),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Manage types, test notifications & view scheduled',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: Color(0xFFCDAF56),
                  ),
                ],
              ),
            ),
          ),
        ],
        
        // ── General ──
        SettingsSection(
          title: 'GENERAL',
          icon: Icons.tune_rounded,
          child: Column(
            children: [
              // Master Enable
              _OverrideSwitch(
                title: 'Notifications Enabled',
                subtitle: 'Override global master toggle',
                overrideValue: settings.notificationsEnabled,
                onChanged: (val) => onUpdate(settings.copyWith(
                  notificationsEnabled: val,
                )),
              ),
              _buildDivider(isDark),
              // Urgency
              _UrgencySelector(
                value: settings.defaultUrgency,
                onChanged: (v) => onUpdate(settings.copyWith(defaultUrgency: v)),
              ),
              _buildDivider(isDark),
              // Max Notification Level
              _MaxTypeLevelSelector(
                value: settings.maxAllowedType,
                onChanged: (v) => onUpdate(settings.copyWith(maxAllowedType: v)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Sound & Feedback ──
        SettingsSection(
          title: 'SOUND & FEEDBACK',
          icon: Icons.volume_up_rounded,
          child: Column(
            children: [
              SettingsTile(
                title: 'Sound Override',
                value: settings.defaultSound ?? 'Global Default',
                icon: Icons.graphic_eq_rounded,
                color: theme.colorScheme.secondary,
                onTap: () async {
                  final picked = await HubSoundPicker.show(
                    context,
                    currentSoundId: settings.defaultSound ?? 'default',
                    title: 'Module Sound',
                  );
                  if (picked != null) onUpdate(settings.copyWith(defaultSound: picked));
                },
              ),
              _buildDivider(isDark),
              SettingsTile(
                title: 'Vibration Override',
                value: settings.defaultVibrationPattern ?? 'Global Default',
                icon: Icons.vibration_rounded,
                color: AppColorSchemes.success,
                onTap: () async {
                  final picked = await HubVibrationPicker.show(
                    context,
                    currentPatternId: settings.defaultVibrationPattern ?? 'default',
                    title: 'Module Vibration',
                  );
                  if (picked != null) onUpdate(settings.copyWith(defaultVibrationPattern: picked));
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Advanced ──
        SettingsSection(
          title: 'ADVANCED',
          icon: Icons.settings_applications_rounded,
          child: Column(
            children: [
              _OverrideSwitch(
                title: 'Always Use Alarm Mode',
                subtitle: 'Force native alarm for this module',
                overrideValue: settings.alwaysUseAlarmMode,
                onChanged: (val) => onUpdate(settings.copyWith(alwaysUseAlarmMode: val)),
              ),
              _buildDivider(isDark),
              _OverrideSwitch(
                title: 'Allow During Quiet Hours',
                subtitle: 'Bypass quiet hours',
                overrideValue: settings.allowDuringQuietHours,
                onChanged: (val) => onUpdate(settings.copyWith(allowDuringQuietHours: val)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Content ──
        SettingsSection(
          title: 'CONTENT',
          icon: Icons.article_rounded,
          child: Column(
            children: [
              SettingsTile(
                title: 'Template Designer',
                value: 'Customize',
                icon: Icons.design_services_rounded,
                color: Colors.deepPurple,
                onTap: () async {
                  final updated = await HubTemplateDesigner.show(
                    context,
                    moduleId: moduleId,
                    currentSettings: settings,
                  );
                  if (updated != null) onUpdate(updated);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Reset ──
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              HapticFeedback.heavyImpact();
              onUpdate(HubModuleNotificationSettings.empty);
            },
            icon: Icon(Icons.restart_alt_rounded, size: 18, color: theme.colorScheme.error),
            label: Text('Reset All Overrides', style: TextStyle(color: theme.colorScheme.error)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.3)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
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

// ─── Helper Widgets ────────────────────────────────────────────────────────

class _OverrideSwitch extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool? overrideValue;
  final ValueChanged<bool?> onChanged;

  const _OverrideSwitch({
    required this.title,
    required this.subtitle,
    required this.overrideValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasOverride = overrideValue != null;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.toggle_on_rounded, color: theme.colorScheme.primary, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
      subtitle: Text(
        hasOverride ? (overrideValue! ? 'Overridden: ON' : 'Overridden: OFF') : 'Using Global Default',
        style: TextStyle(
          color: hasOverride ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
          fontWeight: hasOverride ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
      ),
      trailing: PopupMenuButton<bool?>(
        initialValue: overrideValue,
        onSelected: onChanged,
        itemBuilder: (context) => [
          const PopupMenuItem(value: null, child: Text('Use Global Default')),
          const PopupMenuItem(value: true, child: Text('Force ON')),
          const PopupMenuItem(value: false, child: Text('Force OFF')),
        ],
        child: Chip(
          label: Text(hasOverride ? (overrideValue! ? 'ON' : 'OFF') : 'Default'),
          backgroundColor: hasOverride
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          labelStyle: TextStyle(
            color: hasOverride
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

class _UrgencySelector extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  const _UrgencySelector({this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final options = ['default', 'urgent', 'silent'];
    final current = value ?? 'default';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.priority_high_rounded, color: Colors.orange, size: 20),
      ),
      title: const Text('Urgency Override', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
      subtitle: Wrap(
        spacing: 8,
        children: options.map((o) {
          final selected = o == current;
          return GestureDetector(
            onTap: () => onChanged(o == 'default' ? null : o),
            child: Text(
              o == 'default' ? 'Default' : (o == 'urgent' ? 'Urgent' : 'Silent'),
              style: TextStyle(
                color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
                decoration: selected ? TextDecoration.underline : null,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _MaxTypeLevelSelector extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  const _MaxTypeLevelSelector({this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // null means "allow all" (same as 'special')
    final current = value ?? 'special';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.deepPurple.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.shield_rounded, color: Colors.deepPurple, size: 20),
      ),
      title: const Text(
        'Max Notification Level',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      subtitle: Text(
        HubNotificationTypeLevel.displayName(current),
        style: TextStyle(
          color: theme.colorScheme.onSurfaceVariant,
          fontSize: 12,
        ),
      ),
      trailing: PopupMenuButton<String?>(
        initialValue: value,
        onSelected: onChanged,
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: null,
            child: Text('Allow All (Special)'),
          ),
          const PopupMenuItem(
            value: 'alarm',
            child: Text('Alarm (Bypass DND)'),
          ),
          const PopupMenuItem(
            value: 'regular',
            child: Text('Regular'),
          ),
          const PopupMenuItem(
            value: 'silent',
            child: Text('Silent Only'),
          ),
        ],
        child: Chip(
          label: Text(
            current == 'special' ? 'All' : current.substring(0, 1).toUpperCase() + current.substring(1),
          ),
          backgroundColor: current != 'special'
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          labelStyle: TextStyle(
            color: current != 'special'
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}
