import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/dark_gradient.dart';
import '../../../../core/widgets/color_picker_widget.dart';
import '../../../../core/widgets/icon_picker_widget.dart';
import '../widgets/mood_emoji_picker.dart'
    show showMoodEmojiPicker, kEmojiClearSentinel;
import '../../../notifications_hub/presentation/screens/notification_hub_screen.dart';
import '../../data/models/mood.dart';
import '../../data/models/mood_emoji_options.dart';
import '../../data/models/mood_polarity.dart';
import '../../data/models/mood_reason.dart';
import '../../data/services/mood_api_service.dart';
import '../../mbt_module.dart';
import '../../notifications/mbt_mood_notification_service.dart';

class MoodSettingsScreen extends StatefulWidget {
  const MoodSettingsScreen({super.key});

  @override
  State<MoodSettingsScreen> createState() => _MoodSettingsScreenState();
}

class _MoodSettingsScreenState extends State<MoodSettingsScreen>
    with SingleTickerProviderStateMixin {
  final MoodApiService _api = MoodApiService();
  final MbtMoodNotificationService _notificationService =
      MbtMoodNotificationService();

  late final TabController _tabController;

  bool _loading = true;
  bool _savingReminder = false;
  String? _error;
  List<Mood> _moods = const <Mood>[];
  List<MoodReason> _reasons = const <MoodReason>[];
  MbtMoodReminderSettings _reminderSettings = const MbtMoodReminderSettings(
    enabled: false,
    hour: 20,
    minute: 30,
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
    await MbtModule.init(preOpenBoxes: true);
    await _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final moodsFuture = _api.getMoods(includeInactive: true);
      final reasonsFuture = _api.getReasons(includeInactive: true);
      final reminderFuture = _notificationService.loadSettings();

      final moods = await moodsFuture;
      final reasons = await reasonsFuture;
      final reminder = await reminderFuture;

      moods.sort((a, b) {
        final activeCompare = (b.isActive ? 1 : 0).compareTo(
          a.isActive ? 1 : 0,
        );
        if (activeCompare != 0) return activeCompare;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      reasons.sort((a, b) {
        final typeCompare = a.type.compareTo(b.type);
        if (typeCompare != 0) return typeCompare;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      if (!mounted) return;
      setState(() {
        _moods = moods;
        _reasons = reasons;
        _reminderSettings = reminder;
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

  Future<void> _toggleMoodActive(Mood mood, bool isActive) async {
    try {
      await _api.putMood(mood.id, isActive: isActive);
      await _reload();
    } catch (error) {
      _showError('Failed to update mood: $error');
    }
  }

  Future<void> _toggleReasonActive(MoodReason reason, bool isActive) async {
    try {
      await _api.putReason(reason.id, isActive: isActive);
      await _reload();
    } catch (error) {
      _showError('Failed to update reason: $error');
    }
  }

  Future<void> _deleteMood(Mood mood) async {
    final confirmed = await _confirm(
      title: 'Delete Mood',
      message:
          'Delete "${mood.name}"? Existing entries stay readable but may show missing mood.',
    );
    if (!confirmed) return;
    try {
      await _api.deleteMood(mood.id);
      await _reload();
    } catch (error) {
      _showError('Failed to delete mood: $error');
    }
  }

  Future<void> _deleteReason(MoodReason reason) async {
    final confirmed = await _confirm(
      title: 'Delete Reason',
      message:
          'Delete "${reason.name}"? Existing entries stay readable but may show missing reason.',
    );
    if (!confirmed) return;
    try {
      await _api.deleteReason(reason.id);
      await _reload();
    } catch (error) {
      _showError('Failed to delete reason: $error');
    }
  }

  Future<void> _setReminderEnabled(bool enabled) async {
    if (_savingReminder) return;
    setState(() => _savingReminder = true);
    try {
      await _notificationService.setDailyReminder(
        enabled: enabled,
        time: _reminderSettings.time,
      );
      final updated = await _notificationService.loadSettings();
      if (!mounted) return;
      setState(() => _reminderSettings = updated);
    } catch (error) {
      _showError('Failed to update reminder: $error');
    } finally {
      if (mounted) {
        setState(() => _savingReminder = false);
      }
    }
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderSettings.time,
    );
    if (picked == null) return;

    setState(() => _savingReminder = true);
    try {
      await _notificationService.setDailyReminder(
        enabled: _reminderSettings.enabled,
        time: picked,
      );
      final updated = await _notificationService.loadSettings();
      if (!mounted) return;
      setState(() => _reminderSettings = updated);
    } catch (error) {
      _showError('Failed to update reminder time: $error');
    } finally {
      if (mounted) {
        setState(() => _savingReminder = false);
      }
    }
  }

  Future<void> _showMoodDialog({Mood? mood}) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameController = TextEditingController(text: mood?.name ?? '');
    final pointController = TextEditingController(
      text: mood == null ? '0' : '${mood.pointValue}',
    );
    var reasonRequired = mood?.reasonRequired ?? false;
    var polarity = mood?.polarity ?? MoodPolarity.good;
    var isActive = mood?.isActive ?? true;
    var selectedIcon = mood?.icon ?? Icons.sentiment_satisfied_rounded;
    var selectedColor = mood != null
        ? Color(mood.colorValue)
        : const Color(0xFF2E7D32);
    var selectedEmojiCodePoint = mood?.emojiCodePoint;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _DraggableMoodSheet(
          isDark: isDark,
          title: mood == null ? 'Add Mood' : 'Edit Mood',
          onDelete: mood != null
              ? () async {
                  final confirmed = await _confirm(
                    title: 'Delete Mood',
                    message:
                        'Delete "${mood.name}"? Existing entries stay readable but may show missing mood.',
                  );
                  if (confirmed && mounted) {
                    Navigator.of(sheetContext).pop();
                    await _deleteMood(mood);
                  }
                }
              : null,
          builder: (scrollController) {
            return StatefulBuilder(
              builder: (context, setDialogState) {
                return SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMoodFormCard(
                        isDark,
                        sectionLabel: 'BASIC INFO',
                        children: [
                          _buildMoodTextField(
                            controller: nameController,
                            label: 'Mood name',
                            hint: 'e.g., Very Happy',
                            icon: Icons.label_outline_rounded,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 20),
                          _buildMoodTextField(
                            controller: pointController,
                            label: 'Point value',
                            hint: '0',
                            icon: Icons.numbers_rounded,
                            isDark: isDark,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              signed: true,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildPolaritySelector(
                            polarity,
                            (v) => setDialogState(() => polarity = v),
                            isDark,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildMoodFormCard(
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
                                  backgroundColor: selectedColor,
                                  child: selectedEmojiCodePoint != null
                                      ? Text(
                                          emojiFromCodePoint(
                                            selectedEmojiCodePoint!,
                                          ),
                                          style: const TextStyle(fontSize: 32),
                                        )
                                      : Icon(
                                          selectedIcon,
                                          color: Colors.white,
                                          size: 32,
                                        ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        selectedEmojiCodePoint != null
                                            ? 'Selected emoji & color'
                                            : 'Selected icon & color',
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
                                        'Your mood will appear like this',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black54,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 2,
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
                      _buildMoodFormCard(
                        isDark,
                        sectionLabel: 'ICON',
                        children: [
                          _buildIconPickerTile(
                            selectedIcon,
                            selectedColor,
                            isDark,
                            onTap: () async {
                              final icon = await showDialog<IconData>(
                                context: context,
                                builder: (ctx) => IconPickerWidget(
                                  selectedIcon: selectedIcon,
                                  isDark: isDark,
                                ),
                              );
                              if (icon != null) {
                                setDialogState(() => selectedIcon = icon);
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildMoodFormCard(
                        isDark,
                        sectionLabel: 'COLOR',
                        children: [
                          _buildColorPickerTile(
                            selectedColor,
                            isDark,
                            onTap: () async {
                              final color = await showDialog<Color>(
                                context: context,
                                builder: (ctx) => ColorPickerWidget(
                                  selectedColor: selectedColor,
                                  isDark: isDark,
                                ),
                              );
                              if (color != null) {
                                setDialogState(() => selectedColor = color);
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildMoodFormCard(
                        isDark,
                        sectionLabel: 'EMOJI',
                        children: [
                          _buildEmojiPickerTile(
                            selectedEmojiCodePoint,
                            selectedColor,
                            isDark,
                            onTap: (codePoint) => setDialogState(
                              () => selectedEmojiCodePoint = codePoint,
                            ),
                            onClear: () => setDialogState(
                              () => selectedEmojiCodePoint = null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildMoodFormCard(
                        isDark,
                        sectionLabel: 'OPTIONS',
                        children: [
                          _buildMoodSwitch(
                            title: 'Reason required',
                            subtitle: 'Must provide reason when logging',
                            value: reasonRequired,
                            onChanged: (v) =>
                                setDialogState(() => reasonRequired = v),
                            icon: Icons.question_answer_rounded,
                            isDark: isDark,
                          ),
                          _buildMoodSwitch(
                            title: 'Active',
                            subtitle: 'Include in mood picker',
                            value: isActive,
                            onChanged: (v) =>
                                setDialogState(() => isActive = v),
                            icon: Icons.toggle_on_rounded,
                            isDark: isDark,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildMoodSaveButton(
                        isDark,
                        mood: mood,
                        onPressed: () async {
                          final name = nameController.text.trim();
                          final points =
                              int.tryParse(pointController.text.trim());
                          if (name.isEmpty || points == null) {
                            _showError(
                              'Enter a valid mood name and point value.',
                            );
                            return;
                          }
                          try {
                            if (mood == null) {
                              await _api.postMood(
                                name: name,
                                iconCodePoint: selectedIcon.codePoint,
                                iconFontFamily:
                                    selectedIcon.fontFamily,
                                iconFontPackage:
                                    selectedIcon.fontPackage,
                                emojiCodePoint: selectedEmojiCodePoint,
                                colorValue: selectedColor.toARGB32(),
                                pointValue: points,
                                reasonRequired: reasonRequired,
                                polarity: polarity,
                                isActive: isActive,
                              );
                            } else {
                              await _api.putMood(
                                mood.id,
                                name: name,
                                iconCodePoint: selectedIcon.codePoint,
                                iconFontFamily:
                                    selectedIcon.fontFamily,
                                iconFontPackage:
                                    selectedIcon.fontPackage,
                                emojiCodePoint: selectedEmojiCodePoint,
                                clearEmoji: selectedEmojiCodePoint == null
                                    && mood.emojiCodePoint != null,
                                colorValue: selectedColor.toARGB32(),
                                pointValue: points,
                                reasonRequired: reasonRequired,
                                polarity: polarity,
                                isActive: isActive,
                              );
                            }
                            if (!mounted || !context.mounted) return;
                            Navigator.of(sheetContext).pop();
                            await _reload();
                          } catch (error) {
                            _showError('Failed to save mood: $error');
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton(
                          onPressed: () =>
                              Navigator.of(sheetContext).pop(),
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

  Widget _buildMoodFormCard(
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

  Widget _buildMoodTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    TextInputType? keyboardType,
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
          keyboardType: keyboardType,
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

  Widget _buildPolaritySelector(
    String polarity,
    void Function(String) onChanged,
    bool isDark,
  ) {
    const goodColor = Color(0xFF4CAF50);
    const badColor = Color(0xFFEF5350);
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
            child: _buildPolarityButton(
              MoodPolarity.good,
              'Good',
              Icons.thumb_up_rounded,
              goodColor,
              polarity,
              onChanged,
              isDark,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildPolarityButton(
              MoodPolarity.bad,
              'Bad',
              Icons.thumb_down_rounded,
              badColor,
              polarity,
              onChanged,
              isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolarityButton(
    String value,
    String label,
    IconData icon,
    Color color,
    String currentPolarity,
    void Function(String) onChanged,
    bool isDark,
  ) {
    final isSelected = currentPolarity == value;
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

  Widget _buildIconPickerTile(
    IconData selectedIcon,
    Color selectedColor,
    bool isDark, {
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
              child: Icon(
                selectedIcon,
                size: 24,
                color: Colors.white,
              ),
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

  Widget _buildColorPickerTile(
    Color selectedColor,
    bool isDark, {
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

  Widget _buildEmojiPickerTile(
    int? selectedEmojiCodePoint,
    Color selectedColor,
    bool isDark, {
    required void Function(int?) onTap,
    required VoidCallback onClear,
  }) {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.lightImpact();
        final codePoint = await showMoodEmojiPicker(
          context,
          isDark: isDark,
          selectedCodePoint: selectedEmojiCodePoint,
        );
        if (codePoint != null && codePoint > 0 && mounted) {
          onTap(codePoint);
        } else if (codePoint == kEmojiClearSentinel && mounted) {
          onClear();
        }
      },
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
                color: selectedEmojiCodePoint != null
                    ? selectedColor.withValues(alpha: 0.2)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.04)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selectedEmojiCodePoint != null
                      ? selectedColor
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.05)),
                ),
              ),
              alignment: Alignment.center,
              child: selectedEmojiCodePoint != null
                  ? Text(
                      emojiFromCodePoint(selectedEmojiCodePoint),
                      style: const TextStyle(fontSize: 24),
                    )
                  : Icon(
                      Icons.emoji_emotions_outlined,
                      size: 24,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedEmojiCodePoint != null
                        ? 'Tap to change emoji'
                        : 'Tap to choose emoji',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    '1500+ emojis • Search & categories',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            if (selectedEmojiCodePoint != null)
              IconButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onClear();
                },
                icon: Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFEF5350).withValues(alpha: 0.1),
                  foregroundColor: const Color(0xFFEF5350),
                ),
              )
            else
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

  Widget _buildMoodSwitch({
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
        onChanged: (v) {
          HapticFeedback.lightImpact();
          onChanged(v);
        },
        activeColor: const Color(0xFFCDAF56),
        activeTrackColor: const Color(0xFFCDAF56).withValues(alpha: 0.3),
        inactiveThumbColor: isDark ? Colors.white24 : Colors.grey[400]!,
        inactiveTrackColor: isDark ? Colors.white10 : Colors.grey[200]!,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildMoodSaveButton(
    bool isDark, {
    Mood? mood,
    String? saveLabel,
    required VoidCallback onPressed,
  }) {
    final label = saveLabel ?? (mood == null ? 'SAVE' : 'UPDATE');
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

  Future<void> _showReasonDialog({MoodReason? reason}) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameController = TextEditingController(text: reason?.name ?? '');
    var type = reason?.type ?? MoodPolarity.good;
    var isActive = reason?.isActive ?? true;
    var selectedIcon = reason != null
        ? reason.icon
        : Icons.lightbulb_outline_rounded;
    var selectedColor = Color(reason?.colorValue ?? 0xFFCDAF56);
    var selectedEmojiCodePoint = reason?.emojiCodePoint;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _DraggableMoodSheet(
          isDark: isDark,
          title: reason == null ? 'Add Reason' : 'Edit Reason',
          onDelete: reason != null
              ? () async {
                  final confirmed = await _confirm(
                    title: 'Delete Reason',
                    message:
                        'Delete "${reason.name}"? Existing entries stay readable but may show missing reason.',
                  );
                  if (confirmed && mounted) {
                    Navigator.of(sheetContext).pop();
                    await _deleteReason(reason);
                  }
                }
              : null,
          builder: (scrollController) {
            return StatefulBuilder(
              builder: (context, setDialogState) {
                return SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMoodFormCard(
                        isDark,
                        sectionLabel: 'REASON DETAILS',
                        children: [
                          _buildMoodTextField(
                            controller: nameController,
                            label: 'Reason name',
                            hint: 'e.g., Work meeting',
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
                          _buildPolaritySelector(
                            type,
                            (v) => setDialogState(() => type = v),
                            isDark,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildMoodFormCard(
                        isDark,
                        sectionLabel: 'ICON',
                        children: [
                          _buildIconPickerTile(
                            selectedIcon,
                            selectedColor,
                            isDark,
                            onTap: () async {
                              final icon = await showDialog<IconData>(
                                context: context,
                                builder: (ctx) => IconPickerWidget(
                                  selectedIcon: selectedIcon,
                                  isDark: isDark,
                                ),
                              );
                              if (icon != null) {
                                setDialogState(() => selectedIcon = icon);
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildMoodFormCard(
                        isDark,
                        sectionLabel: 'COLOR',
                        children: [
                          _buildColorPickerTile(
                            selectedColor,
                            isDark,
                            onTap: () async {
                              final color = await showDialog<Color>(
                                context: context,
                                builder: (ctx) => ColorPickerWidget(
                                  selectedColor: selectedColor,
                                  isDark: isDark,
                                ),
                              );
                              if (color != null) {
                                setDialogState(() => selectedColor = color);
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildMoodFormCard(
                        isDark,
                        sectionLabel: 'EMOJI',
                        children: [
                          _buildEmojiPickerTile(
                            selectedEmojiCodePoint,
                            selectedColor,
                            isDark,
                            onTap: (codePoint) => setDialogState(
                              () => selectedEmojiCodePoint = codePoint,
                            ),
                            onClear: () => setDialogState(
                              () => selectedEmojiCodePoint = null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildMoodFormCard(
                        isDark,
                        sectionLabel: 'OPTIONS',
                        children: [
                          _buildMoodSwitch(
                            title: 'Active',
                            subtitle: 'Include in reason picker when logging',
                            value: isActive,
                            onChanged: (v) =>
                                setDialogState(() => isActive = v),
                            icon: Icons.toggle_on_rounded,
                            isDark: isDark,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildMoodSaveButton(
                        isDark,
                        saveLabel: reason == null ? 'SAVE' : 'UPDATE',
                        onPressed: () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) {
                            _showError('Reason name is required.');
                            return;
                          }
                          try {
                            if (reason == null) {
                              await _api.postReason(
                                name: name,
                                type: type,
                                isActive: isActive,
                                iconCodePoint: selectedIcon.codePoint,
                                colorValue: selectedColor.toARGB32(),
                                emojiCodePoint: selectedEmojiCodePoint,
                              );
                            } else {
                              await _api.putReason(
                                reason.id,
                                name: name,
                                type: type,
                                isActive: isActive,
                                iconCodePoint: selectedIcon.codePoint,
                                colorValue: selectedColor.toARGB32(),
                                emojiCodePoint: selectedEmojiCodePoint,
                                clearEmoji: selectedEmojiCodePoint == null &&
                                    reason.emojiCodePoint != null,
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
                          onPressed: () =>
                              Navigator.of(sheetContext).pop(),
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

  Future<bool> _confirm({
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final content = _buildContent(context, isDark);
    return Scaffold(body: isDark ? DarkGradient.wrap(child: content) : content);
  }

  Widget _buildContent(BuildContext context, bool isDark) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'MBT Settings',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: isDark ? Colors.white : const Color(0xFF1E1E1E),
            letterSpacing: -0.5,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: const Color(0xFFCDAF56),
                borderRadius: BorderRadius.circular(12),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: isDark ? Colors.black : Colors.white,
              unselectedLabelColor: isDark ? Colors.white70 : Colors.black54,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              tabs: const [
                Tab(text: 'Moods'),
                Tab(text: 'Reasons'),
                Tab(text: 'Reminder'),
              ],
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFCDAF56)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildMoodsTab(context, isDark),
                _buildReasonsTab(context, isDark),
                _buildReminderTab(context, isDark),
              ],
            ),
    );
  }

  Widget _buildMoodsTab(BuildContext context, bool isDark) {
    final goodMoods = _moods.where((m) => m.polarity == MoodPolarity.good);
    final badMoods = _moods.where((m) => m.polarity == MoodPolarity.bad);

    Widget moodGroup(String title, Iterable<Mood> moods) {
      final list = moods.toList(growable: false);
      final groupColor = title == 'Good' ? const Color(0xFF4CAF50) : const Color(0xFFEF5350);
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: groupColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white38 : Colors.black38,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Divider(
                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                  thickness: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 24, left: 12),
              child: Text(
                'No moods added for this category',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: isDark ? Colors.white24 : Colors.black26,
                ),
              ),
            )
          else
            ...list.map(
              (mood) => _buildMoodListItem(context, mood, isDark),
            ),
          const SizedBox(height: 12),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        Row(
          children: [
            _sectionHeader('MOODS', isDark),
            const Spacer(),
            Text(
              '${_moods.length} total',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        moodGroup('Good', goodMoods),
        moodGroup('Bad', badMoods),
        const SizedBox(height: 12),
        _buildMoodSaveButton(
          isDark,
          saveLabel: '+ ADD MOOD',
          onPressed: () => _showMoodDialog(),
        ),
        const SizedBox(height: 100),
        if (_error?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMoodListItem(BuildContext context, Mood mood, bool isDark) {
    return InkWell(
      onTap: () => _showMoodDialog(mood: mood),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
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
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Color(mood.colorValue).withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: mood.emojiCodePoint != null
                  ? Text(
                      mood.emojiCharacter,
                      style: const TextStyle(fontSize: 26),
                    )
                  : Icon(
                      mood.icon,
                      color: Color(mood.colorValue),
                      size: 24,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mood.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (mood.polarity == MoodPolarity.good ? const Color(0xFF4CAF50) : const Color(0xFFEF5350)).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          mood.polarity.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: mood.polarity == MoodPolarity.good ? const Color(0xFF4CAF50) : const Color(0xFFEF5350),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${mood.pointValue > 0 ? '+' : ''}${mood.pointValue} pts',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                      if (mood.reasonRequired) ...[
                        const SizedBox(width: 8),
                        const Text('•', style: TextStyle(color: Colors.grey, fontSize: 10)),
                        const SizedBox(width: 8),
                        const Icon(Icons.comment_rounded, size: 12, color: Colors.grey),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Switch(
              value: mood.isActive,
              onChanged: (value) => _toggleMoodActive(mood, value),
              activeColor: const Color(0xFFCDAF56),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReasonsTab(BuildContext context, bool isDark) {
    final goodReasons = _reasons.where((r) => r.type == MoodPolarity.good);
    final badReasons = _reasons.where((r) => r.type == MoodPolarity.bad);

    Widget reasonGroup(String title, Iterable<MoodReason> reasons) {
      final list = reasons.toList(growable: false);
      final groupColor = title == 'Good' ? const Color(0xFF4CAF50) : const Color(0xFFEF5350);
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: groupColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white38 : Colors.black38,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Divider(
                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                  thickness: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 24, left: 12),
              child: Text(
                'No reasons added for this category',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: isDark ? Colors.white24 : Colors.black26,
                ),
              ),
            )
          else
            ...list.map(
              (reason) => _buildReasonListItem(context, reason, isDark),
            ),
          const SizedBox(height: 12),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        _sectionHeader('REASONS', isDark),
        const SizedBox(height: 20),
        reasonGroup('Good', goodReasons),
        reasonGroup('Bad', badReasons),
        const SizedBox(height: 12),
        _buildMoodSaveButton(
          isDark,
          saveLabel: '+ ADD REASON',
          onPressed: () => _showReasonDialog(),
        ),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildReasonListItem(BuildContext context, MoodReason reason, bool isDark) {
    final accent = Color(reason.colorValue);
    final hasIcon = reason.hasUserIcon;
    final hasEmoji = reason.emojiCharacter.isNotEmpty;

    return InkWell(
      onTap: () => _showReasonDialog(reason: reason),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: hasIcon
                    ? Icon(reason.icon, size: 20, color: accent)
                    : hasEmoji
                        ? Text(
                            reason.emojiCharacter,
                            style: const TextStyle(fontSize: 20),
                          )
                        : Icon(
                            Icons.help_outline_rounded,
                            size: 20,
                            color: accent,
                          ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                reason.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                ),
              ),
            ),
            Switch(
              value: reason.isActive,
              onChanged: (value) => _toggleReasonActive(reason, value),
              activeColor: const Color(0xFFCDAF56),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderTab(BuildContext context, bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        _sectionHeader('DAILY REMINDER', isDark),
        const SizedBox(height: 16),
        _buildMoodFormCard(
          isDark,
          sectionLabel: 'REMINDER SETTINGS',
          children: [
            _buildMoodSwitch(
              title: 'Daily Reminder',
              subtitle: 'How was your day today?',
              value: _reminderSettings.enabled,
              onChanged: _savingReminder ? (v) {} : _setReminderEnabled,
              icon: Icons.notifications_active_rounded,
              isDark: isDark,
            ),
            const SizedBox(height: 8),
            _buildReminderTimeTile(
              label: 'Reminder time',
              value: _reminderSettings.enabled ? _formatTime(_reminderSettings.time) : 'Disabled',
              icon: Icons.schedule_rounded,
              onTap: _reminderSettings.enabled ? _pickReminderTime : null,
              isDark: isDark,
              enabled: _reminderSettings.enabled && !_savingReminder,
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildMoodFormCard(
          isDark,
          sectionLabel: 'ADVANCED POLICY',
          children: [
            _buildReminderTimeTile(
              label: 'Notification Hub',
              value: 'Open advanced policy and quiet-hours settings',
              icon: Icons.hub_rounded,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const NotificationHubScreen(),
                  ),
                );
              },
              isDark: isDark,
              enabled: true,
              showTrailing: true,
            ),
          ],
        ),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildReminderTimeTile({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback? onTap,
    required bool isDark,
    bool enabled = true,
    bool showTrailing = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.01),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (onTap == null ? Colors.grey : const Color(0xFFCDAF56)).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 18,
                color: onTap == null ? Colors.grey : const Color(0xFFCDAF56),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white38 : Colors.black38,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: enabled
                          ? (isDark ? Colors.white : Colors.black87)
                          : (isDark ? Colors.white24 : Colors.black26),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                showTrailing ? Icons.arrow_forward_ios_rounded : Icons.keyboard_arrow_right_rounded,
                size: showTrailing ? 14 : 20,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String label, bool isDark) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        color: Color(0xFFCDAF56),
        letterSpacing: 1.2,
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Wraps the mood sheet in a [DraggableScrollableSheet] so the user can pull
/// down to close. Applies design_rules polish (surface colors, spacing, typography).
class _DraggableMoodSheet extends StatefulWidget {
  const _DraggableMoodSheet({
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
  State<_DraggableMoodSheet> createState() => _DraggableMoodSheetState();
}

class _DraggableMoodSheetState extends State<_DraggableMoodSheet> {
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
              // Drag handle
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
              // Header row: matches task/habit edit page layout [Back | Title | Delete]
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
