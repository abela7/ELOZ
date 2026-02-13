import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/models/notification_settings.dart';
import '../../../../core/models/special_task_sound.dart';
import '../../../../core/models/vibration_pattern.dart';
import '../../../../core/notifications/models/hub_custom_notification_type.dart';
import '../../../../core/notifications/notifications.dart';
import '../../../../core/theme/color_schemes.dart';
import '../../../../core/theme/dark_gradient.dart';
import '../widgets/hub_sound_picker.dart';
import '../widgets/hub_vibration_picker.dart';
import 'hub_quick_type_manager_dialog.dart';
import 'hub_type_editor_screen.dart';

/// Module Detail Page – clean, test-friendly management screen for a
/// module's notifications inside the Hub.
///
/// Each notification type gets its own card showing:
/// - Current effective config at a glance
/// - Inline toggles for alarm mode / wake screen
/// - Tappable rows for sound, channel, vibration
/// - Big prominent TEST button
class HubModuleDetailPage extends StatefulWidget {
  final String moduleId;

  const HubModuleDetailPage({super.key, required this.moduleId});

  @override
  State<HubModuleDetailPage> createState() => _HubModuleDetailPageState();
}

class _HubModuleDetailPageState extends State<HubModuleDetailPage> {
  final NotificationHub _hub = NotificationHub();

  NotificationHubModule? _module;
  MiniAppNotificationAdapter? _adapter;
  HubModuleNotificationSettings? _settings;
  List<HubNotificationSection> _sections = [];
  List<HubNotificationType> _types = [];
  Map<String, HubCustomNotificationType> _customTypesById = {};
  int _scheduledCount = 0;
  bool _loading = true;

  // Track which section filter is active (null = all)
  String? _activeSectionId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await _hub.initialize();

    _adapter = _hub.adapterFor(widget.moduleId);
    _module = _adapter?.module;
    _settings = await _hub.getModuleSettings(widget.moduleId);
    _sections = _adapter?.sections ?? [];
    _types = _hub.typeRegistry
        .typesForModule(widget.moduleId)
        .toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
    final customTypes =
        await _hub.customTypeStore.getAllForModule(widget.moduleId);
    _customTypesById = {
      for (final t in customTypes) t.id: t,
    };
    _scheduledCount = await _hub.getScheduledCountForModule(widget.moduleId);

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveSettings(HubModuleNotificationSettings s) async {
    await _hub.setModuleSettings(widget.moduleId, s);
    setState(() => _settings = s);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final content = _buildContent(context, isDark);
    return isDark ? DarkGradient.wrap(child: content) : content;
  }

  Widget _buildContent(BuildContext context, bool isDark) {
    if (_loading || _module == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    final moduleColor = Color(_module!.colorValue);
    final filteredTypes = _activeSectionId == null
        ? _types
        : _types.where((t) => t.sectionId == _activeSectionId).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : Colors.black87,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: moduleColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                IconData(
                  _module!.iconCodePoint,
                  fontFamily: _module!.iconFontFamily,
                  fontPackage: _module!.iconFontPackage,
                ),
                color: moduleColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _module!.displayName,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Manage Types',
            onPressed: () => _showTypeManager(isDark),
            icon: Icon(
              Icons.tune_rounded,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: Icon(
              Icons.refresh_rounded,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
        physics: const BouncingScrollPhysics(),
        children: [
          // ── Quick stats ─────────────────────────────────────────
          _buildStatsRow(isDark, moduleColor),
          const SizedBox(height: 16),

          // ── Module enabled toggle ──────────────────────────────
          _buildEnabledToggle(isDark),
          const SizedBox(height: 20),

          // ── Section filter chips (if sections exist) ───────────
          if (_sections.isNotEmpty) ...[
            _buildSectionFilters(isDark),
            const SizedBox(height: 16),
          ],

          // ── Section heading ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 16,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
                const SizedBox(width: 8),
                Text(
                  '${filteredTypes.length} Notification Type${filteredTypes.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white54 : Colors.black54,
                    letterSpacing: 0.3,
                  ),
                ),
                const Spacer(),
                Text(
                  'Tap settings to customize',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white24 : Colors.black26,
                  ),
                ),
              ],
            ),
          ),

          // ── Notification type cards ────────────────────────────
          ...filteredTypes
              .map((type) => _buildTypeCard(type, isDark, moduleColor)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Quick stats
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildStatsRow(bool isDark, Color moduleColor) {
    final enabled = _settings?.notificationsEnabled ?? true;
    final customCount = _customTypesById.length;

    return Row(
      children: [
        _MiniStat(
          icon: Icons.notifications_active_rounded,
          value: _scheduledCount.toString(),
          label: 'Scheduled',
          color: Colors.blue,
          isDark: isDark,
        ),
        const SizedBox(width: 8),
        _MiniStat(
          icon: Icons.category_rounded,
          value: _types.length.toString(),
          label: 'Types',
          color: moduleColor,
          isDark: isDark,
        ),
        const SizedBox(width: 8),
        _MiniStat(
          icon: Icons.tune_rounded,
          value: customCount.toString(),
          label: 'Custom',
          color: customCount > 0 ? AppColorSchemes.primaryGold : Colors.grey,
          isDark: isDark,
        ),
        const SizedBox(width: 8),
        _MiniStat(
          icon: enabled
              ? Icons.check_circle_rounded
              : Icons.cancel_rounded,
          value: enabled ? 'ON' : 'OFF',
          label: 'Status',
          color: enabled ? Colors.green : Colors.red,
          isDark: isDark,
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Enabled toggle
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildEnabledToggle(bool isDark) {
    final enabled = _settings?.notificationsEnabled ?? true;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D23) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (enabled ? Colors.green : Colors.red).withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            enabled
                ? Icons.notifications_active_rounded
                : Icons.notifications_off_rounded,
            color: enabled ? Colors.green : Colors.red,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              enabled
                  ? 'Module Notifications Active'
                  : 'All Notifications Disabled',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          Switch.adaptive(
            value: enabled,
            activeColor: AppColorSchemes.primaryGold,
            onChanged: (val) {
              HapticFeedback.selectionClick();
              _saveSettings(_settings!.copyWith(notificationsEnabled: val));
            },
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Section filter chips
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSectionFilters(bool isDark) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // "All" chip
          _buildFilterChip(
            label: 'All',
            icon: Icons.grid_view_rounded,
            isActive: _activeSectionId == null,
            color: AppColorSchemes.primaryGold,
            isDark: isDark,
            onTap: () => setState(() => _activeSectionId = null),
          ),
          const SizedBox(width: 8),
          ..._sections.map((s) {
            final count =
                _types.where((t) => t.sectionId == s.id).length;
            if (count == 0) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildFilterChip(
                label: '${s.displayName} ($count)',
                icon: IconData(
                  s.iconCodePoint,
                  fontFamily: s.iconFontFamily,
                  fontPackage: s.iconFontPackage,
                ),
                isActive: _activeSectionId == s.id,
                color: Color(s.colorValue),
                isDark: isDark,
                onTap: () => setState(() => _activeSectionId = s.id),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool isActive,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? color.withOpacity(0.2)
              : (isDark ? const Color(0xFF1A1D23) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? color.withOpacity(0.5)
                : (isDark ? Colors.white12 : Colors.black12),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: isActive ? color : (isDark ? Colors.white54 : Colors.black54)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? color : (isDark ? Colors.white70 : Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Notification type card — the main UI unit
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTypeCard(
    HubNotificationType type,
    bool isDark,
    Color moduleColor,
  ) {
    final config = type.defaultConfig;
    final override = _settings?.overrideForType(type.id) ??
        const HubTypeDeliveryOverride();
    final hasCustom = override.hasOverrides;
    final hasTypeCustomization = hasCustom || _isCustomType(type.id);

    // Effective values (override wins, then default)
    final effectiveSound = override.soundKey ?? config.soundKey ?? 'default';
    final effectiveStream = override.audioStream ?? config.audioStream;
    final effectiveVibration =
        override.vibrationPatternId ?? config.vibrationPatternId ?? 'default';
    final effectiveAlarmMode = override.useAlarmMode ?? config.useAlarmMode;
    final effectiveWakeScreen = config.wakeScreen; // read from default

    final typeColor = _getTypeColor(type);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D23) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasTypeCustomization
              ? AppColorSchemes.primaryGold.withOpacity(0.3)
              : (isDark ? Colors.white10 : Colors.black.withOpacity(0.06)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: type name + urgency badge + actions ───
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
            child: Row(
              children: [
                // Type icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getTypeIcon(type),
                    color: typeColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                // Name + badges
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type.displayName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _Badge(
                            label: _channelLabel(config.channelKey),
                            color: typeColor,
                          ),
                          if (effectiveAlarmMode)
                            const _Badge(
                              label: 'ALARM',
                              color: Colors.red,
                            ),
                          if (config.bypassDnd)
                            const _Badge(
                              label: 'BYPASS DND',
                              color: Colors.deepPurple,
                            ),
                          if (hasTypeCustomization)
                            const _Badge(
                              label: 'CUSTOMIZED',
                              color: AppColorSchemes.primaryGold,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Action buttons
                Column(
                  children: [
                    _buildTestButton(type, typeColor),
                    const SizedBox(height: 6),
                    _buildActionButtons(type, isDark),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Config summary bar (always visible) ────────────────
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                // Sound
                _SettingRow(
                  icon: Icons.graphic_eq_rounded,
                  label: 'Sound',
                  value: _soundDisplayName(effectiveSound),
                  isDark: isDark,
                  isCustom: override.soundKey != null,
                  onTap: () async {
                    final picked = await HubSoundPicker.show(
                      context,
                      currentSoundId: effectiveSound,
                      title: '${type.displayName} Tone',
                    );
                    if (picked != null && mounted) {
                      await _saveTypeOverride(type.id, soundKey: picked);
                    }
                  },
                ),

                _thinDivider(isDark),

                // Sound Channel
                _SettingRow(
                  icon: Icons.volume_up_rounded,
                  label: 'Volume Channel',
                  value: _audioStreamLabel(effectiveStream),
                  isDark: isDark,
                  isCustom: override.audioStream != null,
                  onTap: () => _showAudioStreamPicker(type, isDark),
                ),

                _thinDivider(isDark),

                // Vibration
                _SettingRow(
                  icon: Icons.vibration_rounded,
                  label: 'Vibration',
                  value: VibrationPattern.getDisplayName(effectiveVibration),
                  isDark: isDark,
                  isCustom: override.vibrationPatternId != null,
                  onTap: () async {
                    final picked = await HubVibrationPicker.show(
                      context,
                      currentPatternId: effectiveVibration,
                      title: '${type.displayName} Vibration',
                    );
                    if (picked != null && mounted) {
                      await _saveTypeOverride(
                        type.id,
                        vibrationPatternId: picked,
                      );
                    }
                  },
                ),

                _thinDivider(isDark),

                // Alarm Mode toggle
                _ToggleRow(
                  icon: Icons.alarm_rounded,
                  label: 'Alarm Mode',
                  subtitle: 'Bypasses silent mode',
                  value: effectiveAlarmMode,
                  isDark: isDark,
                  isCustom: override.useAlarmMode != null,
                  onChanged: (val) {
                    _saveTypeOverride(type.id, useAlarmMode: val);
                  },
                ),

                _thinDivider(isDark),

                // Wake Screen (read-only info for now)
                _InfoRow(
                  icon: Icons.phone_android_rounded,
                  label: 'Wake Screen',
                  value: effectiveWakeScreen ? 'Yes' : 'No',
                  isDark: isDark,
                  highlight: effectiveWakeScreen,
                ),

                if (config.bypassDnd) ...[
                  _thinDivider(isDark),
                  _InfoRow(
                    icon: Icons.do_not_disturb_off_rounded,
                    label: 'Bypass Do Not Disturb',
                    value: 'Yes',
                    isDark: isDark,
                    highlight: true,
                  ),
                ],
              ],
            ),
          ),

          // ── Reset button (only if customized) ──────────────────
          if (hasTypeCustomization)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () async {
                    HapticFeedback.mediumImpact();
                    final isCustomType = _isCustomType(type.id);
                    if (isCustomType) {
                      await _hub.customTypeStore.delete(type.id);
                      await _hub.reloadCustomTypes();
                      await _load();
                      return;
                    }

                    final current =
                        _settings ?? HubModuleNotificationSettings.empty;
                    await _saveSettings(
                      current.withTypeOverride(type.id, null),
                    );
                  },
                  icon: const Icon(Icons.restart_alt_rounded, size: 16),
                  label: const Text('Reset to defaults'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.withOpacity(0.8),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Action buttons (test, edit, delete)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTestButton(HubNotificationType type, Color typeColor) {
    return Material(
      color: typeColor.withOpacity(0.15),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _testNotification(type),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.play_arrow_rounded, color: typeColor, size: 18),
              const SizedBox(width: 4),
              Text(
                'Test',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: typeColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(HubNotificationType type, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Edit button
        IconButton(
          onPressed: () => _editType(type),
          icon: const Icon(Icons.edit_rounded, size: 16),
          tooltip: 'Edit Type',
          style: IconButton.styleFrom(
            backgroundColor: AppColorSchemes.primaryGold.withOpacity(0.15),
            foregroundColor: AppColorSchemes.primaryGold,
            padding: const EdgeInsets.all(6),
            minimumSize: const Size(32, 32),
          ),
        ),
        const SizedBox(width: 4),
        // Delete button (only for custom types)
        if (_isCustomType(type.id))
          IconButton(
            onPressed: () => _deleteType(type),
            icon: const Icon(Icons.delete_rounded, size: 16),
            tooltip: 'Delete Type',
            style: IconButton.styleFrom(
              backgroundColor: Colors.red.withOpacity(0.15),
              foregroundColor: Colors.red,
              padding: const EdgeInsets.all(6),
              minimumSize: const Size(32, 32),
            ),
          ),
      ],
    );
  }

  bool _isCustomType(String typeId) {
    return _customTypesById.containsKey(typeId);
  }

  Future<void> _editType(HubNotificationType type) async {
    HubCustomNotificationType? customType =
        await _hub.customTypeStore.getById(type.id);
    if (customType == null) {
      // Adapter type: start an override entry using same ID.
      customType = HubCustomNotificationType.fromHubNotificationType(
        type,
        iconCodePoint: _getTypeIcon(type).codePoint,
        colorValue: _getTypeColor(type).toARGB32(),
        isUserCreated: false,
        overridesAdapterTypeId: type.id,
      );
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HubTypeEditorScreen(
          moduleId: widget.moduleId,
          sections: _sections,
          existingType: customType,
        ),
      ),
    );

    if (result != null && mounted) {
      try {
        await _hub.customTypeStore.save(result);
        await _hub.reloadCustomTypes();
        await _load(); // Refresh the list
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Type updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update type: $e')),
        );
      }
    }
  }

  Future<void> _deleteType(HubNotificationType type) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Type?'),
        content: Text(
          'Are you sure you want to delete "${type.displayName}"?\n\n'
          'This cannot be undone. Scheduled notifications using this type will continue to work.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final success = await _hub.customTypeStore.delete(type.id);
        if (success) {
          await _hub.reloadCustomTypes();
          await _load(); // Refresh the list
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ "${type.displayName}" deleted'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Type not found or already deleted'),
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete type: $e')),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Audio stream picker
  // ═══════════════════════════════════════════════════════════════════════════

  void _showAudioStreamPicker(HubNotificationType type, bool isDark) {
    final override = _settings?.overrideForType(type.id) ??
        const HubTypeDeliveryOverride();
    final currentStream =
        override.audioStream ?? type.defaultConfig.audioStream;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1D23) : Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                const SizedBox(height: 8),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color:
                        (isDark ? Colors.white : Colors.black).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColorSchemes.primaryGold.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.volume_up_rounded,
                            color: AppColorSchemes.primaryGold, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Volume Channel',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            Text(
                              'Which volume slider controls this notification',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Divider(
                  height: 1,
                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
                ),
                ..._audioStreamOptions.map((opt) {
                  final isSelected = currentStream == opt.id;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 4,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isSelected
                                ? AppColorSchemes.primaryGold
                                : (isDark ? Colors.white38 : Colors.black38))
                            .withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        opt.icon,
                        size: 20,
                        color: isSelected
                            ? AppColorSchemes.primaryGold
                            : (isDark ? Colors.white54 : Colors.black54),
                      ),
                    ),
                    title: Text(
                      opt.label,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 15,
                        color: isSelected
                            ? AppColorSchemes.primaryGold
                            : (isDark ? Colors.white : Colors.black87),
                      ),
                    ),
                    subtitle: Text(
                      opt.desc,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded,
                            color: AppColorSchemes.primaryGold, size: 24)
                        : Icon(Icons.circle_outlined,
                            size: 24,
                            color: isDark ? Colors.white12 : Colors.black12),
                    onTap: () async {
                      HapticFeedback.selectionClick();
                      Navigator.pop(ctx);
                      await _saveTypeOverride(type.id, audioStream: opt.id);
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

  static const _audioStreamOptions = [
    _AudioStreamOption(
      id: 'notification',
      label: 'Notification Volume',
      desc: 'Respects silent / vibrate mode',
      icon: Icons.notifications_rounded,
    ),
    _AudioStreamOption(
      id: 'alarm',
      label: 'Alarm Volume',
      desc: 'Plays even when phone is silent',
      icon: Icons.alarm_rounded,
    ),
    _AudioStreamOption(
      id: 'ring',
      label: 'Ringtone Volume',
      desc: 'Uses your ringtone volume slider',
      icon: Icons.phone_rounded,
    ),
    _AudioStreamOption(
      id: 'media',
      label: 'Media Volume',
      desc: 'Uses your media volume slider',
      icon: Icons.music_note_rounded,
    ),
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  // Save override
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _saveTypeOverride(
    String typeId, {
    String? soundKey,
    String? audioStream,
    String? vibrationPatternId,
    bool? useAlarmMode,
  }) async {
    final current = _settings ?? HubModuleNotificationSettings.empty;
    final overrides =
        Map<String, HubTypeDeliveryOverride>.from(current.typeOverrides ?? {});

    final existing = overrides[typeId] ?? const HubTypeDeliveryOverride();
    overrides[typeId] = HubTypeDeliveryOverride(
      soundKey: soundKey ?? existing.soundKey,
      audioStream: audioStream ?? existing.audioStream,
      vibrationPatternId: vibrationPatternId ?? existing.vibrationPatternId,
      useAlarmMode: useAlarmMode ?? existing.useAlarmMode,
      useFullScreenIntent: existing.useFullScreenIntent,
      channelKey: existing.channelKey,
    );

    await _saveSettings(current.copyWith(typeOverrides: overrides));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Test notification
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _testNotification(HubNotificationType type) async {
    HapticFeedback.mediumImpact();

    final override = _settings?.overrideForType(type.id) ??
        const HubTypeDeliveryOverride();
    final effectiveStream =
        override.audioStream ?? type.defaultConfig.audioStream;
    final effectiveAlarm = override.useAlarmMode ?? type.defaultConfig.useAlarmMode;

    final now = DateTime.now();
    final result = await _hub.schedule(
      NotificationHubScheduleRequest(
        moduleId: widget.moduleId,
        entityId: 'test:${type.id}:${now.millisecondsSinceEpoch}',
        title: 'Test: ${type.displayName}',
        body: 'Testing ${_module!.displayName} → ${type.displayName}',
        scheduledAt: now.add(const Duration(seconds: 3)),
        type: type.id,
        priority: type.defaultConfig.useAlarmMode ? 'High' : 'Medium',
        extras: const {'isTest': 'true'},
      ),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: result.success ? const Color(0xFF1B5E20) : Colors.red,
          duration: const Duration(seconds: 4),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    result.success
                        ? Icons.check_circle_rounded
                        : Icons.error_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    result.success
                        ? 'Arriving in 3 seconds...'
                        : 'Failed: ${result.failureReason ?? "unknown"}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              if (result.success) ...[
                const SizedBox(height: 6),
                Text(
                  'Channel: ${_audioStreamLabel(effectiveStream)}'
                  '${effectiveAlarm ? ' • Alarm mode ON' : ''}',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ],
          ),
        ),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════════════════════════════════════

  Color _getTypeColor(HubNotificationType type) {
    final custom = _customTypesById[type.id];
    if (custom != null) {
      return Color(custom.colorValue);
    }
    final config = type.defaultConfig;
    if (config.useAlarmMode && config.bypassDnd) return Colors.deepPurple;
    if (config.useAlarmMode) return Colors.red;
    if (config.wakeScreen) return Colors.orange;
    if (config.channelKey == 'silent_reminders') return Colors.grey;
    return Colors.blue;
  }

  IconData _getTypeIcon(HubNotificationType type) {
    final custom = _customTypesById[type.id];
    if (custom != null) {
      return IconData(
        custom.iconCodePoint,
        fontFamily: custom.iconFontFamily,
        fontPackage: custom.iconFontPackage,
      );
    }
    final config = type.defaultConfig;
    if (config.useAlarmMode && config.bypassDnd) return Icons.alarm_rounded;
    if (config.useAlarmMode) return Icons.priority_high_rounded;
    if (config.wakeScreen) return Icons.notification_important_rounded;
    if (config.channelKey == 'silent_reminders') {
      return Icons.notifications_off_rounded;
    }
    return Icons.notifications_rounded;
  }

  String _channelLabel(String channelKey) {
    switch (channelKey) {
      case 'urgent_reminders':
        return 'Urgent';
      case 'silent_reminders':
        return 'Silent';
      case 'task_reminders':
        return 'Standard';
      default:
        return channelKey.isEmpty ? 'Default' : channelKey;
    }
  }

  String _soundDisplayName(String soundId) {
    if (soundId.isEmpty || soundId == 'silent') return 'Silent';
    if (soundId == 'default') return 'System Default';
    if (soundId.startsWith('content://')) {
      return NotificationSettings.getSoundDisplayName(soundId);
    }
    return SpecialTaskSound.getDisplayName(soundId);
  }

  String _audioStreamLabel(String stream) {
    switch (stream) {
      case 'alarm':
        return 'Alarm Volume';
      case 'ring':
        return 'Ringtone Volume';
      case 'media':
        return 'Media Volume';
      case 'notification':
      default:
        return 'Notification Volume';
    }
  }

  Widget _thinDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 0.5,
      color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Type manager dialog
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _showTypeManager(bool isDark) async {
    final needsRefresh = await HubQuickTypeManagerDialog.show(
      context,
      moduleId: widget.moduleId,
      types: _types,
      sections: _sections,
    );

    if (needsRefresh == true && mounted) {
      // Reload types after CRUD operations
      await _load();
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Reusable sub-widgets
// ═══════════════════════════════════════════════════════════════════════════════

/// Mini stat chip for the top row.
class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final bool isDark;

  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D23) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small colored badge (ALARM, CUSTOM, etc.)
class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Tappable setting row (sound, channel, vibration).
class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;
  final bool isCustom;
  final VoidCallback onTap;

  const _SettingRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
    this.isCustom = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isCustom
                  ? AppColorSchemes.primaryGold
                  : (isDark ? Colors.white38 : Colors.black38),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const Spacer(),
            Flexible(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isCustom ? FontWeight.w700 : FontWeight.w500,
                  color: isCustom
                      ? AppColorSchemes.primaryGold
                      : (isDark ? Colors.white : Colors.black87),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }
}

/// Toggle row for boolean settings (alarm mode).
class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final bool isDark;
  final bool isCustom;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.isDark,
    this.isCustom = false,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: value
                ? Colors.red
                : (isDark ? Colors.white38 : Colors.black38),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    if (isCustom) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppColorSchemes.primaryGold.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'CUSTOM',
                          style: TextStyle(
                            fontSize: 7,
                            fontWeight: FontWeight.w800,
                            color: AppColorSchemes.primaryGold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white24 : Colors.black26,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeColor: Colors.red,
            onChanged: (val) {
              HapticFeedback.selectionClick();
              onChanged(val);
            },
          ),
        ],
      ),
    );
  }
}

/// Read-only info row.
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;
  final bool highlight;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: highlight
                ? AppColorSchemes.primaryGold
                : (isDark ? Colors.white38 : Colors.black38),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
              color: highlight
                  ? AppColorSchemes.primaryGold
                  : (isDark ? Colors.white : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

/// Audio stream option model.
class _AudioStreamOption {
  final String id;
  final String label;
  final String desc;
  final IconData icon;

  const _AudioStreamOption({
    required this.id,
    required this.label,
    required this.desc,
    required this.icon,
  });
}
