import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/dark_gradient.dart';
import '../../../../core/widgets/color_picker_widget.dart';
import '../../../../core/widgets/icon_picker_widget.dart';
import '../../../notifications_hub/presentation/screens/notification_hub_screen.dart';
import '../../behavior_module.dart';
import '../../data/models/behavior.dart';
import '../../data/models/behavior_reason.dart';
import '../../data/models/behavior_type.dart';
import '../../data/services/behavior_api_service.dart';
import '../../notifications/behavior_notification_service.dart';

class BehaviorSettingsScreen extends StatefulWidget {
  const BehaviorSettingsScreen({super.key});

  @override
  State<BehaviorSettingsScreen> createState() => _BehaviorSettingsScreenState();
}

class _BehaviorSettingsScreenState extends State<BehaviorSettingsScreen>
    with SingleTickerProviderStateMixin {
  final BehaviorApiService _api = BehaviorApiService();
  late final TabController _tabController;

  bool _loading = true;
  bool _savingReminder = false;
  String? _error;
  List<Behavior> _behaviors = const <Behavior>[];
  List<BehaviorReason> _reasons = const <BehaviorReason>[];
  BehaviorReminderSettings _reminder = const BehaviorReminderSettings(
    enabled: false,
    hour: 20,
    minute: 0,
    daysOfWeek: <int>{1, 2, 3, 4, 5, 6, 7},
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    unawaited(_initialize());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    await BehaviorModule.init(preOpenBoxes: true);
    await _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final behaviorsFuture = _api.getBehaviors(includeInactive: true);
      final reasonsFuture = _api.getBehaviorReasons(includeInactive: true);
      final reminderFuture = _api.loadReminderSettings();

      final behaviors = await behaviorsFuture;
      final reasons = await reasonsFuture;
      final reminder = await reminderFuture;

      behaviors.sort((a, b) {
        final typeCompare = a.type.compareTo(b.type);
        if (typeCompare != 0) return typeCompare;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      reasons.sort((a, b) {
        final typeCompare = a.type.compareTo(b.type);
        if (typeCompare != 0) return typeCompare;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      if (!mounted) return;
      setState(() {
        _behaviors = behaviors;
        _reasons = reasons;
        _reminder = reminder;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  Future<void> _toggleBehaviorActive(Behavior behavior, bool value) async {
    try {
      await _api.putBehavior(behavior.id, isActive: value);
      await _reload();
    } catch (error) {
      _showError('Failed to update behavior: $error');
    }
  }

  Future<void> _toggleReasonActive(BehaviorReason reason, bool value) async {
    try {
      await _api.putBehaviorReason(reason.id, isActive: value);
      await _reload();
    } catch (error) {
      _showError('Failed to update reason: $error');
    }
  }

  Future<void> _deleteBehavior(Behavior behavior) async {
    final confirm = await _confirmDialog(
      title: 'Delete Behavior',
      message: 'Delete "${behavior.name}"? Existing logs remain readable.',
    );
    if (!confirm) return;
    try {
      await _api.deleteBehavior(behavior.id);
      await _reload();
    } catch (error) {
      _showError('Failed to delete behavior: $error');
    }
  }

  Future<void> _deleteReason(BehaviorReason reason) async {
    final confirm = await _confirmDialog(
      title: 'Delete Reason',
      message: 'Delete "${reason.name}"? Existing logs remain readable.',
    );
    if (!confirm) return;
    try {
      await _api.deleteBehaviorReason(reason.id);
      await _reload();
    } catch (error) {
      _showError('Failed to delete reason: $error');
    }
  }

  Future<void> _setReminderEnabled(bool enabled) async {
    if (_savingReminder) return;
    setState(() => _savingReminder = true);
    try {
      await _api.setDailyReminder(
        enabled: enabled,
        time: _reminder.time,
        daysOfWeek: _reminder.daysOfWeek,
      );
      final next = await _api.loadReminderSettings();
      if (!mounted) return;
      setState(() => _reminder = next);
    } catch (error) {
      _showError('Failed to update reminder: $error');
    } finally {
      if (mounted) setState(() => _savingReminder = false);
    }
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminder.time,
    );
    if (picked == null) return;
    setState(() => _savingReminder = true);
    try {
      await _api.setDailyReminder(
        enabled: _reminder.enabled,
        time: picked,
        daysOfWeek: _reminder.daysOfWeek,
      );
      final next = await _api.loadReminderSettings();
      if (!mounted) return;
      setState(() => _reminder = next);
    } catch (error) {
      _showError('Failed to update reminder time: $error');
    } finally {
      if (mounted) setState(() => _savingReminder = false);
    }
  }

  Future<void> _toggleReminderDay(int day) async {
    final nextDays = <int>{..._reminder.daysOfWeek};
    if (nextDays.contains(day)) {
      nextDays.remove(day);
    } else {
      nextDays.add(day);
    }
    if (nextDays.isEmpty) return;
    setState(() => _savingReminder = true);
    try {
      await _api.setDailyReminder(
        enabled: _reminder.enabled,
        time: _reminder.time,
        daysOfWeek: nextDays,
      );
      final next = await _api.loadReminderSettings();
      if (!mounted) return;
      setState(() => _reminder = next);
    } catch (error) {
      _showError('Failed to update reminder days: $error');
    } finally {
      if (mounted) setState(() => _savingReminder = false);
    }
  }

  Future<void> _showBehaviorDialog({Behavior? behavior}) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameController = TextEditingController(text: behavior?.name ?? '');
    var type = behavior?.type ?? BehaviorType.good;
    var reasonRequired = behavior?.reasonRequired ?? false;
    var isActive = behavior?.isActive ?? true;
    var icon = behavior?.icon ?? Icons.track_changes_rounded;
    var color = behavior != null
        ? Color(behavior.colorValue)
        : const Color(0xFF00897B);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _DraggableBehaviorSheet(
          isDark: isDark,
          title: behavior == null ? 'Add Behavior' : 'Edit Behavior',
          onDelete: behavior == null
              ? null
              : () async {
                  final confirmed = await _confirmDialog(
                    title: 'Delete Behavior',
                    message:
                        'Delete "${behavior.name}"? Existing logs remain readable.',
                  );
                  if (confirmed && mounted) {
                    Navigator.of(sheetContext).pop();
                    await _deleteBehavior(behavior);
                  }
                },
          builder: (scrollController) {
            return StatefulBuilder(
              builder: (context, setSheetState) {
                return SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBehaviorFormCard(
                        isDark,
                        sectionLabel: 'BASIC INFO',
                        children: [
                          _buildBehaviorTextField(
                            controller: nameController,
                            label: 'Behavior name',
                            hint: 'e.g., Focus Session',
                            icon: Icons.label_outline_rounded,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'TYPE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white38 : Colors.black38,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildBehaviorTypeSelector(
                            type,
                            (value) => setSheetState(() => type = value),
                            isDark,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildBehaviorFormCard(
                        isDark,
                        sectionLabel: 'PREVIEW',
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 20,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.04)
                                  : Colors.black.withValues(alpha: 0.02),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.black.withValues(alpha: 0.06),
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: color,
                                  child: Icon(
                                    icon,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Selected icon & color',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.white54
                                              : Colors.black54,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        reasonRequired
                                            ? 'Reason required'
                                            : 'Reason optional',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildBehaviorFormCard(
                        isDark,
                        sectionLabel: 'ICON',
                        children: [
                          _buildBehaviorIconPickerTile(
                            selectedIcon: icon,
                            selectedColor: color,
                            isDark: isDark,
                            onTap: () async {
                              final picked = await showDialog<IconData>(
                                context: context,
                                builder: (_) => IconPickerWidget(
                                  selectedIcon: icon,
                                  isDark: isDark,
                                ),
                              );
                              if (picked != null) {
                                setSheetState(() => icon = picked);
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildBehaviorFormCard(
                        isDark,
                        sectionLabel: 'COLOR',
                        children: [
                          _buildBehaviorColorPickerTile(
                            selectedColor: color,
                            isDark: isDark,
                            onTap: () async {
                              final picked = await showDialog<Color>(
                                context: context,
                                builder: (_) => ColorPickerWidget(
                                  selectedColor: color,
                                  isDark: isDark,
                                ),
                              );
                              if (picked != null) {
                                setSheetState(() => color = picked);
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildBehaviorFormCard(
                        isDark,
                        sectionLabel: 'OPTIONS',
                        children: [
                          _buildBehaviorSwitch(
                            title: 'Reason required',
                            subtitle: 'Must provide reason when logging',
                            value: reasonRequired,
                            onChanged: (value) =>
                                setSheetState(() => reasonRequired = value),
                            icon: Icons.question_answer_rounded,
                            isDark: isDark,
                          ),
                          _buildBehaviorSwitch(
                            title: 'Active',
                            subtitle: 'Include in behavior picker',
                            value: isActive,
                            onChanged: (value) =>
                                setSheetState(() => isActive = value),
                            icon: Icons.toggle_on_rounded,
                            isDark: isDark,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildBehaviorSaveButton(
                        label: behavior == null ? 'SAVE' : 'UPDATE',
                        onPressed: () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) {
                            _showError('Behavior name is required.');
                            return;
                          }
                          try {
                            if (behavior == null) {
                              await _api.postBehavior(
                                name: name,
                                type: type,
                                iconCodePoint: icon.codePoint,
                                iconFontFamily: icon.fontFamily,
                                iconFontPackage: icon.fontPackage,
                                colorValue: color.toARGB32(),
                                reasonRequired: reasonRequired,
                                isActive: isActive,
                              );
                            } else {
                              await _api.putBehavior(
                                behavior.id,
                                name: name,
                                type: type,
                                iconCodePoint: icon.codePoint,
                                iconFontFamily: icon.fontFamily,
                                iconFontPackage: icon.fontPackage,
                                colorValue: color.toARGB32(),
                                reasonRequired: reasonRequired,
                                isActive: isActive,
                              );
                            }
                            if (!mounted || !context.mounted) return;
                            Navigator.of(sheetContext).pop();
                            await _reload();
                          } catch (error) {
                            _showError('Failed to save behavior: $error');
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? const Color(0xFFBDBDBD)
                                  : const Color(0xFF6E6E6E),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _showReasonDialog({BehaviorReason? reason}) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameController = TextEditingController(text: reason?.name ?? '');
    var type = reason?.type ?? BehaviorType.good;
    var isActive = reason?.isActive ?? true;
    var previewColor = _typeColor(type);
    var previewIcon = type == BehaviorType.good
        ? Icons.trending_up_rounded
        : Icons.trending_down_rounded;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _DraggableBehaviorSheet(
          isDark: isDark,
          title: reason == null ? 'Add Reason' : 'Edit Reason',
          onDelete: reason == null
              ? null
              : () async {
                  final confirmed = await _confirmDialog(
                    title: 'Delete Reason',
                    message:
                        'Delete "${reason.name}"? Existing logs remain readable.',
                  );
                  if (confirmed && mounted) {
                    Navigator.of(sheetContext).pop();
                    await _deleteReason(reason);
                  }
                },
          builder: (scrollController) {
            return StatefulBuilder(
              builder: (context, setSheetState) {
                return SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBehaviorFormCard(
                        isDark,
                        sectionLabel: 'REASON DETAILS',
                        children: [
                          _buildBehaviorTextField(
                            controller: nameController,
                            label: 'Reason name',
                            hint: 'e.g., Work pressure',
                            icon: Icons.label_outline_rounded,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'TYPE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white38 : Colors.black38,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildBehaviorTypeSelector(
                            type,
                            (value) {
                              setSheetState(() {
                                type = value;
                                previewColor = _typeColor(value);
                                previewIcon = value == BehaviorType.good
                                    ? Icons.trending_up_rounded
                                    : Icons.trending_down_rounded;
                              });
                            },
                            isDark,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildBehaviorFormCard(
                        isDark,
                        sectionLabel: 'PREVIEW',
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 20,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.04)
                                  : Colors.black.withValues(alpha: 0.02),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.black.withValues(alpha: 0.06),
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: previewColor,
                                  child: Icon(
                                    previewIcon,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Reason type preview',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.white54
                                              : Colors.black54,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        type == BehaviorType.good
                                            ? 'Used by Good behaviors'
                                            : 'Used by Bad behaviors',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildBehaviorFormCard(
                        isDark,
                        sectionLabel: 'OPTIONS',
                        children: [
                          _buildBehaviorSwitch(
                            title: 'Active',
                            subtitle: 'Include in reason picker when logging',
                            value: isActive,
                            onChanged: (value) =>
                                setSheetState(() => isActive = value),
                            icon: Icons.toggle_on_rounded,
                            isDark: isDark,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildBehaviorSaveButton(
                        label: reason == null ? 'SAVE' : 'UPDATE',
                        onPressed: () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) {
                            _showError('Reason name is required.');
                            return;
                          }
                          try {
                            if (reason == null) {
                              await _api.postBehaviorReason(
                                name: name,
                                type: type,
                                isActive: isActive,
                              );
                            } else {
                              await _api.putBehaviorReason(
                                reason.id,
                                name: name,
                                type: type,
                                isActive: isActive,
                              );
                            }
                            if (!mounted || !context.mounted) return;
                            Navigator.of(sheetContext).pop();
                            await _reload();
                          } catch (error) {
                            _showError('Failed to save reason: $error');
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? const Color(0xFFBDBDBD)
                                  : const Color(0xFF6E6E6E),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildBehaviorFormCard(
    bool isDark, {
    required String sectionLabel,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
        border: Border.all(
          color: isDark
              ? const Color(0xFF3E4148)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sectionLabel,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Color(0xFFCDAF56),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildBehaviorTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white38 : Colors.black38,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: isDark ? Colors.white10 : Colors.black12,
            ),
            prefixIcon: Icon(icon, size: 20, color: const Color(0xFFCDAF56)),
            filled: true,
            fillColor: isDark
                ? Colors.white.withValues(alpha: 0.02)
                : Colors.black.withValues(alpha: 0.01),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.05),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.05),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFFCDAF56),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBehaviorTypeSelector(
    String type,
    void Function(String) onChanged,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildBehaviorTypeButton(
              value: BehaviorType.good,
              label: 'Good',
              icon: Icons.thumb_up_rounded,
              color: _typeColor(BehaviorType.good),
              currentType: type,
              onChanged: onChanged,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildBehaviorTypeButton(
              value: BehaviorType.bad,
              label: 'Bad',
              icon: Icons.thumb_down_rounded,
              color: _typeColor(BehaviorType.bad),
              currentType: type,
              onChanged: onChanged,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBehaviorTypeButton({
    required String value,
    required String label,
    required IconData icon,
    required Color color,
    required String currentType,
    required void Function(String) onChanged,
    required bool isDark,
  }) {
    final isSelected = currentType == value;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onChanged(value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white24 : Colors.grey[400]!),
              size: 20,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white38 : Colors.grey[500]!),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBehaviorIconPickerTile({
    required IconData selectedIcon,
    required Color selectedColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: selectedColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: selectedColor.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(selectedIcon, size: 24, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tap to choose icon',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    '1700+ icons • Search & categories',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.white38 : Colors.black38,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBehaviorColorPickerTile({
    required Color selectedColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selectedColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.black.withValues(alpha: 0.08),
                ),
                boxShadow: [
                  BoxShadow(
                    color: selectedColor.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tap to choose color',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    'Palette • Custom • Saved colors',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.white38 : Colors.black38,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBehaviorSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.02)
            : Colors.black.withValues(alpha: 0.01),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white24 : Colors.black26,
          ),
        ),
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFCDAF56).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFFCDAF56), size: 18),
        ),
        value: value,
        onChanged: (next) {
          HapticFeedback.lightImpact();
          onChanged(next);
        },
        activeColor: const Color(0xFFCDAF56),
        activeTrackColor: const Color(0xFFCDAF56).withValues(alpha: 0.3),
        inactiveThumbColor: isDark ? Colors.white24 : Colors.grey[400]!,
        inactiveTrackColor: isDark ? Colors.white10 : Colors.grey[200]!,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildBehaviorSaveButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFCDAF56),
          foregroundColor: const Color(0xFF1E1E1E),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 14,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Color _typeColor(String type) {
    return type == BehaviorType.good
        ? const Color(0xFF4CAF50)
        : const Color(0xFFEF5350);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final content = Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Behavior Settings'),
        actions: [
          IconButton(
            onPressed: _loading ? null : () => unawaited(_reload()),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Behaviors'),
            Tab(text: 'Reasons'),
            Tab(text: 'Reminder'),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFCDAF56)),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildBehaviorsTab(isDark),
                _buildReasonsTab(isDark),
                _buildReminderTab(isDark),
              ],
            ),
    );
    return Scaffold(body: isDark ? DarkGradient.wrap(child: content) : content);
  }

  Widget _buildBehaviorsTab(bool isDark) {
    final good = _behaviors.where((item) => item.type == BehaviorType.good);
    final bad = _behaviors.where((item) => item.type == BehaviorType.bad);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        _groupHeader('GOOD'),
        const SizedBox(height: 8),
        ...good.map((behavior) => _behaviorTile(isDark, behavior)),
        const SizedBox(height: 14),
        _groupHeader('BAD'),
        const SizedBox(height: 8),
        ...bad.map((behavior) => _behaviorTile(isDark, behavior)),
        const SizedBox(height: 14),
        _buildBehaviorSaveButton(
          label: '+ ADD BEHAVIOR',
          onPressed: () => unawaited(_showBehaviorDialog()),
        ),
        if (_error?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }

  Widget _buildReasonsTab(bool isDark) {
    final good = _reasons.where((item) => item.type == BehaviorType.good);
    final bad = _reasons.where((item) => item.type == BehaviorType.bad);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        _groupHeader('GOOD'),
        const SizedBox(height: 8),
        ...good.map((reason) => _reasonTile(isDark, reason)),
        const SizedBox(height: 14),
        _groupHeader('BAD'),
        const SizedBox(height: 8),
        ...bad.map((reason) => _reasonTile(isDark, reason)),
        const SizedBox(height: 14),
        _buildBehaviorSaveButton(
          label: '+ ADD REASON',
          onPressed: () => unawaited(_showReasonDialog()),
        ),
      ],
    );
  }

  Widget _buildReminderTab(bool isDark) {
    final weekdayLabels = <int, String>{
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
      7: 'Sun',
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        _card(
          isDark,
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Daily reminder'),
                subtitle: const Text('Remind me to log behavior'),
                value: _reminder.enabled,
                onChanged: _savingReminder
                    ? null
                    : (value) => unawaited(_setReminderEnabled(value)),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule_rounded),
                title: const Text('Reminder time'),
                subtitle: Text(_formatTime(_reminder.time)),
                onTap: _reminder.enabled
                    ? () => unawaited(_pickReminderTime())
                    : null,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Days',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: weekdayLabels.entries.map((entry) {
                  final selected = _reminder.daysOfWeek.contains(entry.key);
                  return FilterChip(
                    selected: selected,
                    onSelected: _reminder.enabled && !_savingReminder
                        ? (_) => unawaited(_toggleReminderDay(entry.key))
                        : null,
                    label: Text(entry.value),
                  );
                }).toList(growable: false),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _card(
          isDark,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.hub_rounded, color: Color(0xFFCDAF56)),
            title: const Text('Notification Hub'),
            subtitle: const Text('Open global quiet-hours and advanced settings'),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const NotificationHubScreen(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _behaviorTile(bool isDark, Behavior behavior) {
    final color = Color(behavior.colorValue);
    return InkWell(
      onTap: () => unawaited(_showBehaviorDialog(behavior: behavior)),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(behavior.icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    behavior.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    '${behavior.type} ${behavior.reasonRequired ? '| reason required' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: behavior.isActive,
              onChanged: (value) =>
                  unawaited(_toggleBehaviorActive(behavior, value)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reasonTile(bool isDark, BehaviorReason reason) {
    return InkWell(
      onTap: () => unawaited(_showReasonDialog(reason: reason)),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                reason.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            Switch(
              value: reason.isActive,
              onChanged: (value) => unawaited(_toggleReasonActive(reason, value)),
            ),
            IconButton(
              onPressed: () => unawaited(_deleteReason(reason)),
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _groupHeader(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: Color(0xFFCDAF56),
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _card(bool isDark, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  Future<bool> _confirmDialog({
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result == true;
  }

  String _formatTime(TimeOfDay value) {
    final h = value.hourOfPeriod == 0 ? 12 : value.hourOfPeriod;
    final m = value.minute.toString().padLeft(2, '0');
    return value.period == DayPeriod.am ? '$h:$m AM' : '$h:$m PM';
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _DraggableBehaviorSheet extends StatefulWidget {
  const _DraggableBehaviorSheet({
    required this.isDark,
    required this.title,
    required this.builder,
    this.onDelete,
  });

  final bool isDark;
  final String title;
  final Widget Function(ScrollController scrollController) builder;
  final VoidCallback? onDelete;

  @override
  State<_DraggableBehaviorSheet> createState() => _DraggableBehaviorSheetState();
}

class _DraggableBehaviorSheetState extends State<_DraggableBehaviorSheet> {
  late final DraggableScrollableController _controller;

  @override
  void initState() {
    super.initState();
    _controller = DraggableScrollableController();
    _controller.addListener(_onDrag);
  }

  void _onDrag() {
    if (_controller.size <= 0.4 && mounted) {
      _controller.removeListener(_onDrag);
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onDrag);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    return DraggableScrollableSheet(
      controller: _controller,
      initialChildSize: 0.9,
      minChildSize: 0.35,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2D3139) : const Color(0xFFFFFFFF),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, -4),
                    ),
                  ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF3E4148)
                            : const Color(0xFFE0E0E0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.arrow_back_rounded,
                          color: isDark ? Colors.white : Colors.black87,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    if (widget.onDelete != null)
                      GestureDetector(
                        onTap: widget.onDelete,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF5350).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            color: Color(0xFFEF5350),
                            size: 20,
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 44),
                  ],
                ),
              ),
              Flexible(child: widget.builder(scrollController)),
            ],
          ),
        );
      },
    );
  }
}
