import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../data/models/simple_reminder.dart';
import '../providers/reminder_providers.dart';
import '../../../../core/widgets/icon_picker_widget.dart';
import '../../../../core/widgets/color_picker_widget.dart';

/// Bottom sheet for adding a new simple reminder
class AddReminderSheet extends ConsumerStatefulWidget {
  final bool isDark;
  final DateTime initialDate;
  final SimpleReminder? existingReminder;
  final VoidCallback? onReminderAdded;

  const AddReminderSheet({
    super.key,
    required this.isDark,
    required this.initialDate,
    this.existingReminder,
    this.onReminderAdded,
  });

  @override
  ConsumerState<AddReminderSheet> createState() => _AddReminderSheetState();
}

class _AddReminderSheetState extends ConsumerState<AddReminderSheet> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late DateTime _selectedDate;
  TimeOfDay _selectedTime = TimeOfDay.now();
  String _timerMode = ReminderTimerMode.countdown; // Default to countdown
  IconData? _selectedIcon;
  Color? _selectedColor;
  bool _showOptionalFields = false;
  bool _isSaving = false;
  String _timePreset = '5min'; // Default to 5 minutes
  bool _isCustomTime = false;

  // Accordion states
  bool _showWhenAccordion = true;
  bool _showTimerAccordion = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;

    if (widget.existingReminder != null) {
      final reminder = widget.existingReminder!;
      _titleController.text = reminder.title;
      _descriptionController.text = reminder.description ?? '';
      _selectedIcon = reminder.icon;
      _selectedColor = reminder.color;
      _timerMode = reminder.timerMode;
      _isCustomTime = true;
      _timePreset = '';
      _selectedDate = reminder.scheduledAt;
      _selectedTime = TimeOfDay(
        hour: reminder.scheduledAt.hour,
        minute: reminder.scheduledAt.minute,
      );
      _showOptionalFields = reminder.description?.isNotEmpty == true ||
          reminder.iconCodePoint != null ||
          reminder.colorValue != null;
      _showWhenAccordion = false; // Collapse by default when editing
    } else {
      // Set default time to 5 minutes from now
      _applyTimePreset('5min');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  DateTime get _scheduledDateTime {
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
  }

  void _applyTimePreset(String preset) {
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    DateTime targetTime;

    switch (preset) {
      case '1min':
        targetTime = now.add(const Duration(minutes: 1));
        break;
      case '5min':
        targetTime = now.add(const Duration(minutes: 5));
        break;
      case '10min':
        targetTime = now.add(const Duration(minutes: 10));
        break;
      case '15min':
        targetTime = now.add(const Duration(minutes: 15));
        break;
      case '30min':
        targetTime = now.add(const Duration(minutes: 30));
        break;
      case '1hr':
        targetTime = now.add(const Duration(hours: 1));
        break;
      default:
        targetTime = now.add(const Duration(minutes: 5));
    }

    setState(() {
      _timePreset = preset;
      _isCustomTime = false;
      _selectedDate = targetTime;
      _selectedTime = TimeOfDay(hour: targetTime.hour, minute: targetTime.minute);
    });
  }

  void _selectCustomTime() {
    HapticFeedback.selectionClick();
    setState(() {
      _isCustomTime = true;
      _timePreset = '';
    });
  }

  Future<void> _saveReminder() async {
    if (!_formKey.currentState!.validate()) return;

    // Check if time is in the past
    if (_scheduledDateTime.isBefore(DateTime.now())) {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a future time for the reminder'),
          backgroundColor: Color(0xFFFF6B6B),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final isEditing = widget.existingReminder != null;
      final reminder = (widget.existingReminder ?? SimpleReminder(
            title: _titleController.text.trim(),
            scheduledAt: _scheduledDateTime,
          ))
          .copyWith(
            title: _titleController.text.trim(),
            scheduledAt: _scheduledDateTime,
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            timerMode: _timerMode,
            iconCodePoint: _selectedIcon?.codePoint,
            iconFontFamily: _selectedIcon?.fontFamily,
            iconFontPackage: _selectedIcon?.fontPackage,
            colorValue: _selectedColor?.value,
          );

      final notifier = ref.read(reminderNotifierProvider.notifier);
      final success = isEditing
          ? await notifier.updateReminder(reminder)
          : await notifier.addReminder(reminder);

      if (success && mounted) {
        HapticFeedback.mediumImpact();
        widget.onReminderAdded?.call();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditing
                  ? 'Reminder updated'
                  : 'Reminder set for ${DateFormat('h:mm a').format(_scheduledDateTime)}',
            ),
            backgroundColor: const Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create reminder'),
            backgroundColor: Color(0xFFFF6B6B),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFFF6B6B),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _selectTime() async {
    HapticFeedback.selectionClick();
    if (!_isCustomTime) {
      setState(() => _isCustomTime = true);
    }
    
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: widget.isDark
                ? const ColorScheme.dark(
                    primary: Color(0xFFCDAF56),
                    onPrimary: Colors.black,
                    surface: Color(0xFF2D3139),
                    onSurface: Colors.white,
                  )
                : const ColorScheme.light(
                    primary: Color(0xFFCDAF56),
                    onPrimary: Colors.white,
                  ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _selectDate() async {
    HapticFeedback.selectionClick();
    if (!_isCustomTime) {
      setState(() => _isCustomTime = true);
    }
    
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: widget.isDark
                ? const ColorScheme.dark(
                    primary: Color(0xFFCDAF56),
                    onPrimary: Colors.black,
                    surface: Color(0xFF2D3139),
                    onSurface: Colors.white,
                  )
                : const ColorScheme.light(
                    primary: Color(0xFFCDAF56),
                    onPrimary: Colors.white,
                  ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _showIconPicker() async {
    HapticFeedback.selectionClick();
    final icon = await showDialog<IconData>(
      context: context,
      builder: (context) => IconPickerWidget(
        selectedIcon: _selectedIcon ?? Icons.notifications_active_rounded,
        isDark: widget.isDark,
      ),
    );
    if (icon != null && mounted) {
      setState(() => _selectedIcon = icon);
    }
  }

  Future<void> _showColorPicker() async {
    HapticFeedback.selectionClick();
    final color = await showDialog<Color>(
      context: context,
      builder: (context) => ColorPickerWidget(
        selectedColor: _selectedColor ?? const Color(0xFFCDAF56),
        isDark: widget.isDark,
      ),
    );
    if (color != null && mounted) {
      setState(() => _selectedColor = color);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final isEditing = widget.existingReminder != null;
    final accentColor = const Color(0xFFCDAF56);

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: 24 + bottomPadding,
      ),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1A1D24) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: widget.isDark ? Colors.white12 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isEditing ? Icons.edit_notifications_rounded : Icons.notifications_active_rounded,
                      color: accentColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    isEditing ? 'Edit Reminder' : 'New Reminder',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: widget.isDark ? Colors.white : Colors.black87,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close_rounded,
                      color: widget.isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Title Input
              TextFormField(
                controller: _titleController,
                autofocus: !isEditing,
                style: TextStyle(
                  color: widget.isDark ? Colors.white : Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  labelText: 'What do you need to remember?',
                  labelStyle: TextStyle(
                    color: widget.isDark ? Colors.white54 : Colors.grey.shade600,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  hintText: 'e.g., Call John back',
                  hintStyle: TextStyle(
                    color: widget.isDark ? Colors.white24 : Colors.grey.shade400,
                  ),
                  filled: true,
                  fillColor: widget.isDark
                      ? Colors.white.withOpacity(0.03)
                      : Colors.grey.withOpacity(0.04),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: accentColor.withOpacity(0.3), width: 1.5),
                  ),
                  prefixIcon: Icon(
                    Icons.text_fields_rounded,
                    color: widget.isDark ? Colors.white38 : Colors.black38,
                    size: 20,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a reminder title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // When Accordion
              _buildAccordion(
                title: 'When?',
                subtitle: _isCustomTime 
                    ? '${DateFormat('MMM d').format(_selectedDate)} at ${_selectedTime.format(context)}'
                    : 'In ${_timePreset.replaceAll('min', ' mins').replaceAll('hr', ' hour')}',
                icon: Icons.schedule_rounded,
                isExpanded: _showWhenAccordion,
                onToggle: () => setState(() => _showWhenAccordion = !_showWhenAccordion),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _TimePresetChip(
                          label: '1 min',
                          isSelected: _timePreset == '1min' && !_isCustomTime,
                          isDark: widget.isDark,
                          onTap: () => _applyTimePreset('1min'),
                        ),
                        _TimePresetChip(
                          label: '5 min',
                          isSelected: _timePreset == '5min' && !_isCustomTime,
                          isDark: widget.isDark,
                          onTap: () => _applyTimePreset('5min'),
                        ),
                        _TimePresetChip(
                          label: '15 min',
                          isSelected: _timePreset == '15min' && !_isCustomTime,
                          isDark: widget.isDark,
                          onTap: () => _applyTimePreset('15min'),
                        ),
                        _TimePresetChip(
                          label: '30 min',
                          isSelected: _timePreset == '30min' && !_isCustomTime,
                          isDark: widget.isDark,
                          onTap: () => _applyTimePreset('30min'),
                        ),
                        _TimePresetChip(
                          label: '1 hr',
                          isSelected: _timePreset == '1hr' && !_isCustomTime,
                          isDark: widget.isDark,
                          onTap: () => _applyTimePreset('1hr'),
                        ),
                        _TimePresetChip(
                          label: 'Custom',
                          isSelected: _isCustomTime,
                          isDark: widget.isDark,
                          isCustom: true,
                          onTap: _selectCustomTime,
                        ),
                      ],
                    ),
                    if (_isCustomTime) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _ModernPickerTile(
                              icon: Icons.calendar_today_rounded,
                              label: 'Date',
                              value: DateFormat('MMM d, yyyy').format(_selectedDate),
                              onTap: _selectDate,
                              isDark: widget.isDark,
                              color: accentColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ModernPickerTile(
                              icon: Icons.access_time_rounded,
                              label: 'Time',
                              value: _selectedTime.format(context),
                              onTap: _selectTime,
                              isDark: widget.isDark,
                              color: accentColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Timer Display Accordion
              _buildAccordion(
                title: 'Timer Display',
                subtitle: _timerMode == ReminderTimerMode.countdown 
                    ? 'Countdown' 
                    : (_timerMode == ReminderTimerMode.countup ? 'Count Up' : 'None'),
                icon: Icons.timer_rounded,
                isExpanded: _showTimerAccordion,
                onToggle: () => setState(() => _showTimerAccordion = !_showTimerAccordion),
                child: Row(
                  children: [
                    _TimerModeChip(
                      label: 'Countdown',
                      icon: Icons.timer_rounded,
                      isSelected: _timerMode == ReminderTimerMode.countdown,
                      isDark: widget.isDark,
                      onTap: () => setState(() => _timerMode = ReminderTimerMode.countdown),
                    ),
                    const SizedBox(width: 8),
                    _TimerModeChip(
                      label: 'Count Up',
                      icon: Icons.timer_off_rounded,
                      isSelected: _timerMode == ReminderTimerMode.countup,
                      isDark: widget.isDark,
                      onTap: () => setState(() => _timerMode = ReminderTimerMode.countup),
                    ),
                    const SizedBox(width: 8),
                    _TimerModeChip(
                      label: 'None',
                      icon: Icons.close_rounded,
                      isSelected: _timerMode == ReminderTimerMode.none,
                      isDark: widget.isDark,
                      onTap: () => setState(() => _timerMode = ReminderTimerMode.none),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Optional Fields Accordion
              _buildAccordion(
                title: 'Optional Details',
                subtitle: _selectedIcon != null || _descriptionController.text.isNotEmpty 
                    ? 'Custom icon/description set' 
                    : 'Icon, color, description',
                icon: Icons.tune_rounded,
                isExpanded: _showOptionalFields,
                onToggle: () => setState(() => _showOptionalFields = !_showOptionalFields),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 2,
                      style: TextStyle(
                        color: widget.isDark ? Colors.white : Colors.black87,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Description',
                        labelStyle: TextStyle(
                          color: widget.isDark ? Colors.white54 : Colors.grey.shade600,
                        ),
                        hintText: 'Add more details...',
                        hintStyle: TextStyle(
                          color: widget.isDark ? Colors.white24 : Colors.grey.shade400,
                        ),
                        filled: true,
                        fillColor: widget.isDark
                            ? Colors.white.withOpacity(0.03)
                            : Colors.grey.withOpacity(0.04),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: Icon(
                          Icons.notes_rounded,
                          color: widget.isDark ? Colors.white38 : Colors.black38,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _ModernPickerTile(
                            icon: _selectedIcon ?? Icons.add_rounded,
                            label: 'Icon',
                            value: _selectedIcon != null ? 'Change' : 'Add',
                            onTap: _showIconPicker,
                            isDark: widget.isDark,
                            color: _selectedColor ?? accentColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: _showColorPicker,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: widget.isDark
                                    ? Colors.white.withOpacity(0.03)
                                    : Colors.grey.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: widget.isDark
                                      ? Colors.white.withOpacity(0.05)
                                      : Colors.grey.withOpacity(0.1),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: _selectedColor ?? accentColor,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: (_selectedColor ?? accentColor).withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Color',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: widget.isDark ? Colors.white54 : Colors.grey.shade500,
                                        ),
                                      ),
                                      Text(
                                        'Change',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: widget.isDark ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveReminder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation(Colors.black),
                          ),
                        )
                      : Text(
                          isEditing ? 'Update Reminder' : 'Set Reminder',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccordion({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isExpanded,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onToggle();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: widget.isDark
                  ? Colors.white.withOpacity(0.03)
                  : Colors.grey.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isExpanded 
                    ? Colors.white.withOpacity(0.1)
                    : (widget.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isExpanded ? Colors.white : (widget.isDark ? Colors.white54 : Colors.black45),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: widget.isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (!isExpanded)
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: widget.isDark ? Colors.white38 : Colors.black38,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: widget.isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 12, left: 4, right: 4),
            child: child,
          ),
          crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }
}

class _ModernPickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool isDark;
  final Color color;

  const _ModernPickerTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    required this.isDark,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white54 : Colors.grey.shade500,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Time Preset Selection Chip
class _TimePresetChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isDark;
  final bool isCustom;
  final VoidCallback onTap;

  const _TimePresetChip({
    required this.label,
    required this.isSelected,
    required this.isDark,
    this.isCustom = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = const Color(0xFFCDAF56);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withOpacity(0.15)
              : (isDark ? Colors.white.withOpacity(0.03) : Colors.grey.withOpacity(0.04)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? accentColor
                : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1)),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCustom)
              Icon(
                Icons.edit_calendar_rounded,
                size: 16,
                color: isSelected
                    ? accentColor
                    : (isDark ? Colors.white54 : Colors.grey),
              ),
            if (isCustom) const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? accentColor
                    : (isDark ? Colors.white70 : Colors.black54),
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Timer Mode Selection Chip
class _TimerModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _TimerModeChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = const Color(0xFFCDAF56);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? accentColor.withOpacity(0.15)
                : (isDark ? Colors.white.withOpacity(0.03) : Colors.grey.withOpacity(0.04)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? accentColor
                  : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1)),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? accentColor
                    : (isDark ? Colors.white54 : Colors.grey),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? accentColor
                      : (isDark ? Colors.white70 : Colors.black54),
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
