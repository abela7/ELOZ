import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/notifications/notifications.dart';
import '../../../../core/theme/color_schemes.dart';
import 'hub_type_editor_screen.dart';

/// Quick Type Manager — full CRUD for notification types.
///
/// Features:
/// - Create new types from scratch
/// - Edit existing types (name, icon, config)
/// - Duplicate types as templates
/// - Delete custom types
/// - Reset all to defaults
class HubQuickTypeManagerDialog extends StatefulWidget {
  final String moduleId;
  final List<HubNotificationType> types;
  final List<HubNotificationSection> sections;

  const HubQuickTypeManagerDialog({
    super.key,
    required this.moduleId,
    required this.types,
    required this.sections,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String moduleId,
    required List<HubNotificationType> types,
    required List<HubNotificationSection> sections,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => HubQuickTypeManagerDialog(
        moduleId: moduleId,
        types: types,
        sections: sections,
      ),
    );
  }

  @override
  State<HubQuickTypeManagerDialog> createState() => _HubQuickTypeManagerDialogState();
}

class _HubQuickTypeManagerDialogState extends State<HubQuickTypeManagerDialog> {
  final NotificationHub _hub = NotificationHub();
  
  Future<void> _createType() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HubTypeEditorScreen(
          moduleId: widget.moduleId,
          sections: widget.sections,
        ),
      ),
    );

    if (result != null && mounted) {
      try {
        await _hub.customTypeStore.save(result);
        await _hub.reloadCustomTypes();
        Navigator.pop(context, true); // Signal refresh needed
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Type created successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create type: $e')),
        );
      }
    }
  }

  Future<void> _duplicateType(HubNotificationType type) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HubTypeEditorScreen(
          moduleId: widget.moduleId,
          sections: widget.sections,
          templateType: type,
        ),
      ),
    );

    if (result != null && mounted) {
      try {
        await _hub.customTypeStore.save(result);
        await _hub.reloadCustomTypes();
        Navigator.pop(context, true);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Type duplicated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to duplicate: $e')),
        );
      }
    }
  }

  Future<void> _resetAllToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Defaults?'),
        content: const Text(
          'This will delete all custom notification types and restore '
          'the original types from the code. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final count = await _hub.customTypeStore.deleteAllForModule(widget.moduleId);
        await _hub.reloadCustomTypes();
        Navigator.pop(context, true);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Reset complete: $count custom types deleted'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reset: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1D23) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // Header
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
                      child: const Icon(
                        Icons.tune_rounded,
                        color: AppColorSchemes.primaryGold,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notification Types',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            '${widget.types.length} types available',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close_rounded,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              Divider(
                height: 1,
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
              ),

              // Action buttons
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _createType,
                        icon: const Icon(Icons.add_rounded, size: 20),
                        label: const Text('Create New Type'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColorSchemes.primaryGold,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _resetAllToDefaults,
                        icon: const Icon(Icons.restart_alt_rounded, size: 18, color: Colors.red),
                        label: const Text('Reset to Defaults', style: TextStyle(color: Colors.red)),
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
                ),
              ),

              Divider(
                height: 1,
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
              ),

              // Info banner
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Colors.blue, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Create new types, duplicate templates, or reset custom types to defaults.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.blue[200] : Colors.blue[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Types list
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: widget.types.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final type = widget.types[index];
                    return _TypeQuickCard(
                      type: type,
                      isDark: isDark,
                      onDuplicate: () => _duplicateType(type),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TypeQuickCard extends StatelessWidget {
  final HubNotificationType type;
  final bool isDark;
  final VoidCallback onDuplicate;

  const _TypeQuickCard({
    required this.type,
    required this.isDark,
    required this.onDuplicate,
  });

  @override
  Widget build(BuildContext context) {
    final config = type.defaultConfig;
    
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D0F14) : const Color(0xFFF8F9FC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with duplicate button
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Type name
                    Text(
                      type.displayName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    
                    // Type ID
                    Text(
                      type.id,
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        color: isDark ? Colors.white24 : Colors.black26,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onDuplicate,
                icon: const Icon(Icons.content_copy_rounded, size: 18),
                tooltip: 'Duplicate',
                style: IconButton.styleFrom(
                  backgroundColor: AppColorSchemes.primaryGold.withOpacity(0.15),
                  foregroundColor: AppColorSchemes.primaryGold,
                  padding: const EdgeInsets.all(8),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 10),
          
          // Config summary
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _ConfigChip(
                label: _channelLabel(config.channelKey),
                icon: Icons.category_rounded,
                color: Colors.blue,
              ),
              _ConfigChip(
                label: _audioStreamLabel(config.audioStream),
                icon: Icons.volume_up_rounded,
                color: Colors.purple,
              ),
              if (config.useAlarmMode)
                const _ConfigChip(
                  label: 'ALARM',
                  icon: Icons.alarm_rounded,
                  color: Colors.red,
                ),
              if (config.wakeScreen)
                const _ConfigChip(
                  label: 'WAKE',
                  icon: Icons.phone_android_rounded,
                  color: Colors.orange,
                ),
              if (config.bypassDnd)
                const _ConfigChip(
                  label: 'BYPASS DND',
                  icon: Icons.do_not_disturb_off_rounded,
                  color: Colors.deepPurple,
                ),
            ],
          ),
        ],
      ),
    );
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

  String _audioStreamLabel(String stream) {
    switch (stream) {
      case 'alarm':
        return 'Alarm Vol';
      case 'ring':
        return 'Ring Vol';
      case 'media':
        return 'Media Vol';
      case 'notification':
      default:
        return 'Notif Vol';
    }
  }
}

class _ConfigChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _ConfigChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
