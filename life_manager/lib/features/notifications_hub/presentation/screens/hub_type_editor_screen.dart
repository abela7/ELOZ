import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/notifications/models/hub_custom_notification_type.dart';
import '../../../../core/notifications/models/hub_notification_section.dart';
import '../../../../core/notifications/models/hub_notification_type.dart';
import '../../../../core/theme/color_schemes.dart';
import '../../../../core/widgets/icon_picker_widget.dart';
import '../../../../core/widgets/color_picker_widget.dart';

/// Type Editor Screen — create or edit custom notification types.
///
/// Features:
/// - Display name input
/// - Section selection
/// - Icon picker (Material Icons presets)
/// - Color picker (preset colors)
/// - Full delivery config editor
/// - Live preview
class HubTypeEditorScreen extends StatefulWidget {
  final String moduleId;
  final List<HubNotificationSection> sections;
  final HubCustomNotificationType? existingType; // null = create mode
  final HubNotificationType? templateType; // for duplicating adapter types

  const HubTypeEditorScreen({
    super.key,
    required this.moduleId,
    required this.sections,
    this.existingType,
    this.templateType,
  });

  @override
  State<HubTypeEditorScreen> createState() => _HubTypeEditorScreenState();
}

class _HubTypeEditorScreenState extends State<HubTypeEditorScreen> {
  late TextEditingController _nameController;
  String? _selectedSectionId;
  int _selectedIconCodePoint = 0xe145; // notifications_rounded
  int _selectedColorValue = 0xFF2196F3; // blue
  
  // Delivery config
  String _channelKey = 'task_reminders';
  String _audioStream = 'notification';
  bool _useAlarmMode = false;
  bool _wakeScreen = false;
  bool _bypassDnd = false;
  bool _bypassQuietHours = false;
  bool _persistent = false;

  @override
  void initState() {
    super.initState();
    
    if (widget.existingType != null) {
      // Edit mode
      final type = widget.existingType!;
      _nameController = TextEditingController(text: type.displayName);
      _selectedSectionId = type.sectionId;
      _selectedIconCodePoint = type.iconCodePoint;
      _selectedColorValue = type.colorValue;
      
      final config = type.deliveryConfigJson;
      _channelKey = config['channelKey'] as String? ?? 'task_reminders';
      _audioStream = config['audioStream'] as String? ?? 'notification';
      _useAlarmMode = config['useAlarmMode'] as bool? ?? false;
      _wakeScreen = config['wakeScreen'] as bool? ?? false;
      _bypassDnd = config['bypassDnd'] as bool? ?? false;
      _bypassQuietHours = config['bypassQuietHours'] as bool? ?? false;
      _persistent = config['persistent'] as bool? ?? false;
    } else if (widget.templateType != null) {
      // Duplicate mode
      final template = widget.templateType!;
      _nameController = TextEditingController(text: '${template.displayName} (Copy)');
      _selectedSectionId = template.sectionId;
      
      final config = template.defaultConfig;
      _channelKey = config.channelKey;
      _audioStream = config.audioStream;
      _useAlarmMode = config.useAlarmMode;
      _wakeScreen = config.wakeScreen;
      _bypassDnd = config.bypassDnd;
      _bypassQuietHours = config.bypassQuietHours;
      _persistent = config.persistent;
    } else {
      // Create mode
      _nameController = TextEditingController(text: 'New Notification Type');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0F14) : const Color(0xFFF8F9FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.existingType != null ? 'Edit Type' : 'Create Type',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text(
              'Save',
              style: TextStyle(
                color: AppColorSchemes.primaryGold,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Basic Info Section
          _SectionHeader(title: 'BASIC INFO', isDark: isDark),
          const SizedBox(height: 12),
          _buildBasicInfoCard(isDark),
          const SizedBox(height: 20),

          // Delivery Config Section
          _SectionHeader(title: 'DELIVERY CONFIGURATION', isDark: isDark),
          const SizedBox(height: 12),
          _buildDeliveryConfigCard(isDark),
          const SizedBox(height: 20),

          // Preview Section
          _SectionHeader(title: 'PREVIEW', isDark: isDark),
          const SizedBox(height: 12),
          _buildPreviewCard(isDark),
          
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildBasicInfoCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D23) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Display Name
          Text(
            'Display Name *',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: 'e.g., Urgent Payment Reminder',
              filled: true,
              fillColor: (isDark ? Colors.white : Colors.black).withOpacity(0.03),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Section
          Text(
            'Section',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            value: _selectedSectionId,
            decoration: InputDecoration(
              filled: true,
              fillColor: (isDark ? Colors.white : Colors.black).withOpacity(0.03),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('No Section (General)')),
              ...widget.sections.map((s) => DropdownMenuItem(
                value: s.id,
                child: Text(s.displayName),
              )),
            ],
            onChanged: (val) => setState(() => _selectedSectionId = val),
          ),
          
          const SizedBox(height: 16),
          
          // Icon & Color
          Row(
            children: [
              Expanded(
                child: _buildIconPicker(isDark),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildColorPicker(isDark),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconPicker(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Icon',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _showIconPicker(isDark),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  IconData(_selectedIconCodePoint, fontFamily: 'MaterialIcons'),
                  color: Color(_selectedColorValue),
                  size: 28,
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.edit_rounded,
                  size: 14,
                  color: isDark ? Colors.white24 : Colors.black26,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildColorPicker(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Color',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _showColorPicker(isDark),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Color(_selectedColorValue),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: (isDark ? Colors.white : Colors.black).withOpacity(0.2),
                      width: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.edit_rounded,
                  size: 14,
                  color: isDark ? Colors.white24 : Colors.black26,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryConfigCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D23) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Channel
          _buildDropdownRow(
            'Channel',
            _channelKey,
            const [
              ('task_reminders', 'Standard'),
              ('urgent_reminders', 'Urgent'),
              ('silent_reminders', 'Silent'),
            ],
            (val) => setState(() => _channelKey = val!),
            isDark,
          ),
          
          const SizedBox(height: 12),
          
          // Audio Stream
          _buildDropdownRow(
            'Volume Channel',
            _audioStream,
            const [
              ('notification', 'Notification Volume'),
              ('alarm', 'Alarm Volume'),
              ('ring', 'Ringtone Volume'),
              ('media', 'Media Volume'),
            ],
            (val) => setState(() => _audioStream = val!),
            isDark,
          ),
          
          const SizedBox(height: 16),
          Divider(height: 1, color: (isDark ? Colors.white : Colors.black).withOpacity(0.06)),
          const SizedBox(height: 16),
          
          // Toggles
          _buildToggleRow('Alarm Mode', _useAlarmMode, (val) => setState(() => _useAlarmMode = val), isDark),
          _buildToggleRow('Wake Screen', _wakeScreen, (val) => setState(() => _wakeScreen = val), isDark),
          _buildToggleRow('Bypass Do Not Disturb', _bypassDnd, (val) => setState(() => _bypassDnd = val), isDark),
          _buildToggleRow('Bypass Quiet Hours', _bypassQuietHours, (val) => setState(() => _bypassQuietHours = val), isDark),
          _buildToggleRow('Persistent', _persistent, (val) => setState(() => _persistent = val), isDark),
        ],
      ),
    );
  }

  Widget _buildDropdownRow(
    String label,
    String value,
    List<(String, String)> options,
    ValueChanged<String?> onChanged,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(
            filled: true,
            fillColor: (isDark ? Colors.white : Colors.black).withOpacity(0.03),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          items: options.map((opt) => DropdownMenuItem(
            value: opt.$1,
            child: Text(opt.$2),
          )).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildToggleRow(String label, bool value, ValueChanged<bool> onChanged, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            activeColor: value ? (label == 'Alarm Mode' ? Colors.red : AppColorSchemes.primaryGold) : null,
            onChanged: (val) {
              HapticFeedback.selectionClick();
              onChanged(val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D23) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Color(_selectedColorValue).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Color(_selectedColorValue).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  IconData(_selectedIconCodePoint, fontFamily: 'MaterialIcons'),
                  color: Color(_selectedColorValue),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _nameController.text.isEmpty ? 'Type Name' : _nameController.text,
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
                        if (_useAlarmMode)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'ALARM',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        if (_wakeScreen)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'WAKE',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                        if (_bypassDnd)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'BYPASS DND',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.deepPurple,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showIconPicker(bool isDark) async {
    final icon = await showDialog<IconData>(
      context: context,
      builder: (context) => IconPickerWidget(
        selectedIcon: IconData(_selectedIconCodePoint, fontFamily: 'MaterialIcons'),
        isDark: isDark,
      ),
    );
    
    if (icon != null) {
      setState(() => _selectedIconCodePoint = icon.codePoint);
    }
  }

  Future<void> _showColorPicker(bool isDark) async {
    final color = await showDialog<Color>(
      context: context,
      builder: (context) => ColorPickerWidget(
        selectedColor: Color(_selectedColorValue),
        isDark: isDark,
      ),
    );
    
    if (color != null) {
      setState(() => _selectedColorValue = color.value);
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || name.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name must be at least 3 characters')),
      );
      return;
    }

    final customType = widget.existingType ??
        HubCustomNotificationType.blank(
          moduleId: widget.moduleId,
          sectionId: _selectedSectionId,
        );

    customType.update(
      displayName: name,
      iconCodePoint: _selectedIconCodePoint,
      colorValue: _selectedColorValue,
      deliveryConfigJson: {
        'channelKey': _channelKey,
        'audioStream': _audioStream,
        'useAlarmMode': _useAlarmMode,
        'useFullScreenIntent': false,
        'bypassDnd': _bypassDnd,
        'bypassQuietHours': _bypassQuietHours,
        'persistent': _persistent,
        'wakeScreen': _wakeScreen,
      },
    );
    // Allow explicitly clearing section back to general.
    customType.sectionId = _selectedSectionId;
    customType.updatedAt = DateTime.now();

    Navigator.pop(context, customType);
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final bool isDark;

  const _SectionHeader({required this.title, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: isDark ? Colors.white38 : Colors.black38,
        letterSpacing: 0.5,
      ),
    );
  }
}
