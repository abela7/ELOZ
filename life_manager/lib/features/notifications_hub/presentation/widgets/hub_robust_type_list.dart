import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/models/notification_settings.dart';
import '../../../../core/models/special_task_sound.dart';
import '../../../../core/models/vibration_pattern.dart';
import '../../../../core/notifications/models/hub_custom_notification_type.dart';
import '../../../../core/notifications/models/hub_module_notification_settings.dart';
import '../../../../core/notifications/notifications.dart';
import '../../../../core/theme/color_schemes.dart';
import '../screens/hub_quick_type_manager_dialog.dart';
import '../screens/hub_type_editor_screen.dart';
import 'hub_sound_picker.dart';
import 'hub_vibration_picker.dart';

/// Robust notification type list with full CRUD, sound/vibration pickers,
/// alarm mode toggle, and test button. Used by HubFinanceModulePage and
/// HubModuleDetailPage for Finance.
class HubRobustTypeList extends StatelessWidget {
  final NotificationHub hub;
  final String moduleId;
  final String moduleDisplayName;
  final HubModuleNotificationSettings settings;
  final List<HubNotificationType> types;
  final Map<String, HubCustomNotificationType> customTypesById;
  final List<HubNotificationSection> sections;
  final bool isDark;
  final Color moduleColor;
  final Future<void> Function(HubModuleNotificationSettings) onSaveSettings;
  final Future<void> Function() onReload;

  const HubRobustTypeList({
    super.key,
    required this.hub,
    required this.moduleId,
    required this.moduleDisplayName,
    required this.settings,
    required this.types,
    required this.customTypesById,
    required this.sections,
    required this.isDark,
    required this.moduleColor,
    required this.onSaveSettings,
    required this.onReload,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Manage Types button
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showTypeManager(context),
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: const Text('Manage Types (Create, Edit, Delete)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColorSchemes.primaryGold,
                side: BorderSide(color: AppColorSchemes.primaryGold.withOpacity(0.5)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
        ...types.map((type) => _HubRobustTypeCard(
              type: type,
              hub: hub,
              moduleId: moduleId,
              moduleDisplayName: moduleDisplayName,
              settings: settings,
              customTypesById: customTypesById,
              sections: sections,
              isDark: isDark,
              moduleColor: moduleColor,
              onSaveSettings: onSaveSettings,
              onReload: onReload,
            )),
      ],
    );
  }

  Future<void> _showTypeManager(BuildContext context) async {
    final needsRefresh = await HubQuickTypeManagerDialog.show(
      context,
      moduleId: moduleId,
      types: types,
      sections: sections,
    );

    if (needsRefresh == true && context.mounted) {
      await onReload();
    }
  }
}

/// Single type card: compact row by default; tap to expand config.
class _HubRobustTypeCard extends StatefulWidget {
  final HubNotificationType type;
  final NotificationHub hub;
  final String moduleId;
  final String moduleDisplayName;
  final HubModuleNotificationSettings settings;
  final Map<String, HubCustomNotificationType> customTypesById;
  final List<HubNotificationSection> sections;
  final bool isDark;
  final Color moduleColor;
  final Future<void> Function(HubModuleNotificationSettings) onSaveSettings;
  final Future<void> Function() onReload;

  const _HubRobustTypeCard({
    required this.type,
    required this.hub,
    required this.moduleId,
    required this.moduleDisplayName,
    required this.settings,
    required this.customTypesById,
    required this.sections,
    required this.isDark,
    required this.moduleColor,
    required this.onSaveSettings,
    required this.onReload,
  });

  @override
  State<_HubRobustTypeCard> createState() => _HubRobustTypeCardState();
}

class _HubRobustTypeCardState extends State<_HubRobustTypeCard> {
  bool _expanded = false;

  bool get _isCustomType => widget.customTypesById.containsKey(widget.type.id);

  Color get _typeColor {
    final custom = widget.customTypesById[widget.type.id];
    if (custom != null) return Color(custom.colorValue);
    final config = widget.type.defaultConfig;
    if (config.useAlarmMode && config.bypassDnd) return Colors.deepPurple;
    if (config.useAlarmMode) return Colors.red;
    if (config.wakeScreen) return Colors.orange;
    if (config.channelKey == 'silent_reminders') return Colors.grey;
    return Colors.blue;
  }

  IconData get _typeIcon {
    final custom = widget.customTypesById[widget.type.id];
    if (custom != null) {
      return IconData(
        custom.iconCodePoint,
        fontFamily: custom.iconFontFamily,
        fontPackage: custom.iconFontPackage,
      );
    }
    final config = widget.type.defaultConfig;
    if (config.useAlarmMode && config.bypassDnd) return Icons.alarm_rounded;
    if (config.useAlarmMode) return Icons.priority_high_rounded;
    if (config.wakeScreen) return Icons.notification_important_rounded;
    if (config.channelKey == 'silent_reminders') {
      return Icons.notifications_off_rounded;
    }
    return Icons.notifications_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.type.defaultConfig;
    final override = widget.settings.overrideForType(widget.type.id);
    final hasTypeCustomization = override.hasOverrides || _isCustomType;

    // Module defaults (from Settings tab) apply to all types when no per-type override
    final effectiveSound = override.soundKey ??
        widget.settings.defaultSound ??
        config.soundKey ??
        'default';
    final effectiveStream = override.audioStream ?? config.audioStream;
    final effectiveVibration = override.vibrationPatternId ??
        widget.settings.defaultVibrationPattern ??
        config.vibrationPatternId ??
        'default';
    final effectiveAlarmMode = override.useAlarmMode ?? config.useAlarmMode;
    final effectiveWakeScreen = config.wakeScreen;
    final isDark = widget.isDark;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D23) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasTypeCustomization
              ? AppColorSchemes.primaryGold.withOpacity(0.3)
              : (isDark ? Colors.white10 : Colors.black.withOpacity(0.06)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Icon + type name (clean, no clutter)
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _typeColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_typeIcon, color: _typeColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.type.displayName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    size: 22,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ],
              ),
            ),
          ),
          // Row 2: Test, Edit, Delete actions (separate from name)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(
              children: [
                _buildTestButton(context),
                const SizedBox(width: 8),
                _buildActionButtons(context),
              ],
            ),
          ),
          if (_expanded) ...[
            Divider(
              height: 1,
              indent: 14,
              endIndent: 14,
              color: isDark ? Colors.white12 : Colors.black12,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                children: [
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
                        title: '${widget.type.displayName} Tone',
                      );
                      if (picked != null && context.mounted) {
                        await _saveOverride(soundKey: picked);
                      }
                    },
                  ),
                  _thinDivider(isDark),
                  _SettingRow(
                    icon: Icons.volume_up_rounded,
                    label: 'Volume Channel',
                    value: _audioStreamLabel(effectiveStream),
                    isDark: isDark,
                    isCustom: override.audioStream != null,
                    onTap: () => _showAudioStreamPicker(context),
                  ),
                  _thinDivider(isDark),
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
                        title: '${widget.type.displayName} Vibration',
                      );
                      if (picked != null && context.mounted) {
                        await _saveOverride(vibrationPatternId: picked);
                      }
                    },
                  ),
                  _thinDivider(isDark),
                  _ToggleRow(
                    icon: Icons.alarm_rounded,
                    label: 'Alarm Mode',
                    subtitle: 'Bypasses silent mode',
                    value: effectiveAlarmMode,
                    isDark: isDark,
                    isCustom: override.useAlarmMode != null,
                    onChanged: (val) => _saveOverride(useAlarmMode: val),
                  ),
                  _thinDivider(isDark),
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
                  if (hasTypeCustomization)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: () async {
                            HapticFeedback.mediumImpact();
                            if (_isCustomType) {
                              await widget.hub.customTypeStore.delete(widget.type.id);
                              await widget.hub.reloadCustomTypes();
                              await widget.onReload();
                              return;
                            }
                            final current = widget.settings;
                            await widget.onSaveSettings(current.withTypeOverride(widget.type.id, null));
                          },
                          icon: const Icon(Icons.restart_alt_rounded, size: 16),
                          label: const Text('Reset to defaults'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red.withOpacity(0.8),
                            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTestButton(BuildContext context) {
    return Material(
      color: _typeColor.withOpacity(0.15),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _testNotification(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.play_arrow_rounded, color: _typeColor, size: 18),
              const SizedBox(width: 4),
              Text('Test', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _typeColor)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => _editType(context),
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
        if (_isCustomType)
          IconButton(
            onPressed: () => _deleteType(context),
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

  Future<void> _saveOverride({
    String? soundKey,
    String? audioStream,
    String? vibrationPatternId,
    bool? useAlarmMode,
  }) async {
    final current = widget.settings;
    final overrides = Map<String, HubTypeDeliveryOverride>.from(current.typeOverrides ?? {});
    final existing = overrides[widget.type.id] ?? const HubTypeDeliveryOverride();
    overrides[widget.type.id] = HubTypeDeliveryOverride(
      soundKey: soundKey ?? existing.soundKey,
      audioStream: audioStream ?? existing.audioStream,
      vibrationPatternId: vibrationPatternId ?? existing.vibrationPatternId,
      useAlarmMode: useAlarmMode ?? existing.useAlarmMode,
      useFullScreenIntent: existing.useFullScreenIntent,
      channelKey: existing.channelKey,
    );
    await widget.onSaveSettings(current.copyWith(typeOverrides: overrides));
  }

  Future<void> _editType(BuildContext context) async {
    HubCustomNotificationType? customType = await widget.hub.customTypeStore.getById(widget.type.id);
    if (customType == null) {
      customType = HubCustomNotificationType.fromHubNotificationType(
        widget.type,
        iconCodePoint: _typeIcon.codePoint,
        colorValue: _typeColor.toARGB32(),
        isUserCreated: false,
        overridesAdapterTypeId: widget.type.id,
      );
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HubTypeEditorScreen(
          moduleId: widget.moduleId,
          sections: widget.sections,
          existingType: customType,
        ),
      ),
    );

    if (result != null && context.mounted) {
      try {
        await widget.hub.customTypeStore.save(result);
        await widget.hub.reloadCustomTypes();
        await widget.onReload();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✓ Type updated successfully'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update type: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteType(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Type?'),
        content: Text(
          'Are you sure you want to delete "${widget.type.displayName}"?\n\n'
          'This cannot be undone. Scheduled notifications using this type will continue to work.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final success = await widget.hub.customTypeStore.delete(widget.type.id);
        if (success) {
          await widget.hub.reloadCustomTypes();
          await widget.onReload();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('✓ "${widget.type.displayName}" deleted'), backgroundColor: Colors.green),
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete type: $e')),
          );
        }
      }
    }
  }

  void _showAudioStreamPicker(BuildContext context) {
    final override = widget.settings.overrideForType(widget.type.id);
    final currentStream = override.audioStream ?? widget.type.defaultConfig.audioStream;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: widget.isDark ? const Color(0xFF1A1D23) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                      color: (widget.isDark ? Colors.white : Colors.black).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._audioStreamOptions.map((opt) {
                    final isSelected = currentStream == opt.$1;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      leading: Icon(opt.$4, size: 20, color: isSelected ? AppColorSchemes.primaryGold : null),
                      title: Text(opt.$2),
                      subtitle: Text(opt.$3, style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.white54 : Colors.black54)),
                      trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: AppColorSchemes.primaryGold) : null,
                      onTap: () async {
                        HapticFeedback.selectionClick();
                        await _saveOverride(audioStream: opt.$1);
                        if (context.mounted) Navigator.pop(ctx);
                      },
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static const _audioStreamOptions = [
    ('notification', 'Notification Volume', 'Respects silent / vibrate mode', Icons.notifications_rounded),
    ('alarm', 'Alarm Volume', 'Plays even when phone is silent', Icons.alarm_rounded),
    ('ring', 'Ringtone Volume', 'Uses your ringtone volume slider', Icons.phone_rounded),
    ('media', 'Media Volume', 'Uses your media volume slider', Icons.music_note_rounded),
  ];

  Future<void> _testNotification(BuildContext context) async {
    HapticFeedback.mediumImpact();
    final now = DateTime.now();
    final result = await widget.hub.schedule(
      NotificationHubScheduleRequest(
        moduleId: widget.moduleId,
        entityId: 'test:${widget.type.id}:${now.millisecondsSinceEpoch}',
        title: 'Test: ${widget.type.displayName}',
        body: 'Testing ${widget.moduleDisplayName} → ${widget.type.displayName}',
        scheduledAt: now.add(const Duration(seconds: 3)),
        type: widget.type.id,
        priority: widget.type.defaultConfig.useAlarmMode ? 'High' : 'Medium',
        extras: const {'isTest': 'true'},
      ),
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: result.success ? const Color(0xFF1B5E20) : Colors.red,
          content: Text(
            result.success
                ? 'Arriving in 3 seconds...'
                : 'Failed: ${result.failureReason ?? "unknown"}',
          ),
        ),
      );
    }
  }

  String _channelLabel(String channelKey) {
    switch (channelKey) {
      case 'urgent_reminders': return 'Urgent';
      case 'silent_reminders': return 'Silent';
      case 'task_reminders': return 'Standard';
      default: return channelKey.isEmpty ? 'Default' : channelKey;
    }
  }

  String _soundDisplayName(String soundId) {
    if (soundId.isEmpty || soundId == 'silent') return 'Silent';
    if (soundId == 'default') return 'System Default';
    if (soundId.startsWith('content://')) return NotificationSettings.getSoundDisplayName(soundId);
    return SpecialTaskSound.getDisplayName(soundId);
  }

  String _audioStreamLabel(String stream) {
    switch (stream) {
      case 'alarm': return 'Alarm Volume';
      case 'ring': return 'Ringtone Volume';
      case 'media': return 'Media Volume';
      default: return 'Notification Volume';
    }
  }

  Widget _thinDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 0.5,
      color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.3)),
    );
  }
}

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
            Icon(icon, size: 18, color: isCustom ? AppColorSchemes.primaryGold : (isDark ? Colors.white38 : Colors.black38)),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black54)),
            const Spacer(),
            Flexible(child: Text(value, style: TextStyle(fontSize: 13, fontWeight: isCustom ? FontWeight.w700 : FontWeight.w500, color: isCustom ? AppColorSchemes.primaryGold : (isDark ? Colors.white : Colors.black87)), overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, size: 18, color: isDark ? Colors.white24 : Colors.black26),
          ],
        ),
      ),
    );
  }
}

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
          Icon(icon, size: 18, color: value ? Colors.red : (isDark ? Colors.white38 : Colors.black38)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black54)),
                Text(subtitle, style: TextStyle(fontSize: 11, color: isDark ? Colors.white24 : Colors.black26)),
              ],
            ),
          ),
          Switch.adaptive(value: value, activeColor: Colors.red, onChanged: (v) { HapticFeedback.selectionClick(); onChanged(v); }),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;
  final bool highlight;

  const _InfoRow({required this.icon, required this.label, required this.value, required this.isDark, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: highlight ? AppColorSchemes.primaryGold : (isDark ? Colors.white38 : Colors.black38)),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black54)),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: highlight ? FontWeight.w700 : FontWeight.w500, color: highlight ? AppColorSchemes.primaryGold : (isDark ? Colors.white : Colors.black87))),
        ],
      ),
    );
  }
}
