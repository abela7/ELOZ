import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/widgets/icon_picker_widget.dart';
import '../../../../core/notifications/models/notification_creator_context.dart';
import '../../../../core/notifications/models/universal_notification.dart';
import '../../../../core/notifications/notification_hub.dart';
import '../../../../core/notifications/notifications.dart';
import '../../../../core/notifications/services/universal_notification_scheduler.dart';
import '../../../../core/theme/color_schemes.dart';

/// Universal Notification Creator bottom sheet.
///
/// 6-step wizard: Title → Body → Icon → Action Buttons → Type & Schedule → Condition.
/// Uses [context] for pre-filled defaults and available variables/actions/conditions.
class UniversalNotificationCreatorSheet extends StatefulWidget {
  final NotificationCreatorContext context;
  final UniversalNotification? existing;
  final Future<void> Function(UniversalNotification)? onSave;
  final UniversalNotificationRepository? repository;

  const UniversalNotificationCreatorSheet({
    super.key,
    required this.context,
    this.existing,
    this.onSave,
    this.repository,
  });

  /// Shows the creator as a modal bottom sheet.
  static Future<UniversalNotification?> show(
    BuildContext context, {
    required NotificationCreatorContext creatorContext,
    UniversalNotification? existing,
    UniversalNotificationRepository? repository,
  }) async {
    UniversalNotification? result;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => UniversalNotificationCreatorSheet(
        context: creatorContext,
        existing: existing,
        repository: repository,
        onSave: (n) async {
          result = n;
          if (ctx.mounted) Navigator.of(ctx).pop();
        },
      ),
    );
    return result;
  }

  @override
  State<UniversalNotificationCreatorSheet> createState() =>
      _UniversalNotificationCreatorSheetState();
}

class _UniversalNotificationCreatorSheetState
    extends State<UniversalNotificationCreatorSheet> {
  static const _gold = AppColorSchemes.primaryGold;

  late int _step;
  late TextEditingController _titleController;
  late TextEditingController _bodyController;
  late String _titleTemplate;
  late String _bodyTemplate;
  late int? _iconCodePoint;
  late String? _iconFontFamily;
  late String? _iconFontPackage;
  late int? _colorValue;
  late List<UniversalNotificationAction> _actions;
  late bool _actionsEnabled;
  late String _typeId;
  late String _timing;
  late int _timingValue;
  late String _timingUnit;
  late int _hour;
  late int _minute;
  late String _condition;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    NotificationHub().typeRegistry.ensureBuiltInsRegistered();
    final c = widget.context;
    final existing = widget.existing;
    final d = c.defaults;
    _step = 0;
    if (existing != null) {
      _titleTemplate = existing.titleTemplate;
      _bodyTemplate = existing.bodyTemplate;
      _iconCodePoint = existing.iconCodePoint;
      _iconFontFamily = existing.iconFontFamily;
      _iconFontPackage = existing.iconFontPackage;
      _colorValue = existing.colorValue;
      _actions = existing.actions;
      _actionsEnabled = existing.actionsEnabled;
      _typeId = existing.typeId;
      _timing = existing.timing;
      _timingValue = existing.timingValue;
      _timingUnit = existing.timingUnit;
      _hour = existing.hour;
      _minute = existing.minute;
      _condition = existing.condition;
    } else {
      _titleTemplate = d.titleTemplate;
      _bodyTemplate = d.bodyTemplate;
      _iconCodePoint = d.iconCodePoint;
      _iconFontFamily = d.iconFontFamily;
      _iconFontPackage = d.iconFontPackage;
      _colorValue = d.colorValue;
      _actions = d.actions.map((a) => a.toUniversalAction()).toList();
      _actionsEnabled = d.actionsEnabled;
      _typeId = d.typeId;
      _timing = d.timing;
      _timingValue = d.timingValue;
      _timingUnit = d.timingUnit;
      _hour = d.hour;
      _minute = d.minute;
      _condition = d.condition;
    }
    _titleController = TextEditingController(text: _titleTemplate);
    _bodyController = TextEditingController(text: _bodyTemplate);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  bool get _hasKindStep =>
      widget.context.notificationKinds != null &&
      widget.context.notificationKinds!.isNotEmpty &&
      widget.existing == null;

  int get _maxStep => _hasKindStep ? 6 : 5;

  void _applyKindDefaults(NotificationCreatorKind kind) {
    final d = kind.defaults;
    _titleTemplate = d.titleTemplate;
    _bodyTemplate = d.bodyTemplate;
    _titleController.text = _titleTemplate;
    _bodyController.text = _bodyTemplate;
    _iconCodePoint = d.iconCodePoint;
    _iconFontFamily = d.iconFontFamily;
    _iconFontPackage = d.iconFontPackage;
    _colorValue = d.colorValue;
    _actions = d.actions.map((a) => a.toUniversalAction()).toList();
    _actionsEnabled = kind.defaults.actionsEnabled;
    _typeId = d.typeId;
    _timing = d.timing;
    _timingValue = d.timingValue;
    _timingUnit = d.timingUnit;
    _hour = d.hour;
    _minute = d.minute;
    _condition = d.condition;
  }

  void _nextStep() {
    if (_step < _maxStep) {
      setState(() => _step++);
    }
  }

  void _prevStep() {
    if (_step > 0) {
      setState(() => _step--);
    }
  }

  bool get _canSave => _titleTemplate.trim().isNotEmpty;

  Future<void> _save() async {
    if (_saving || !_canSave) return;
    setState(() => _saving = true);
    try {
      final c = widget.context;
      final existing = widget.existing;
      final notification = UniversalNotification(
        id: existing?.id,
        moduleId: c.moduleId,
        section: c.section,
        entityId: c.entityId,
        entityName: c.entityName,
        titleTemplate: _titleTemplate,
        createdAt: existing?.createdAt,
        updatedAt: null,
        bodyTemplate: _bodyTemplate,
        iconCodePoint: _iconCodePoint,
        iconFontFamily: _iconFontFamily,
        iconFontPackage: _iconFontPackage,
        colorValue: _colorValue,
        typeId: _typeId,
        timing: _timing,
        timingValue: _timingValue,
        timingUnit: _timingUnit,
        hour: _hour,
        minute: _minute,
        condition: _condition,
        enabled: true,
        actionsEnabled: _actionsEnabled,
      );
      notification.actions = _actions;

      final repo = widget.repository;
      if (repo != null) {
        await repo.init();
        await repo.save(notification);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Reminder saved. Scheduling in background.'),
              backgroundColor: Colors.green.shade700,
            ),
          );
        }
        unawaited(UniversalNotificationScheduler().syncForEntity(notification.entityId));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reminder saved (no repository)')),
        );
      }

      if (widget.onSave != null) {
        await widget.onSave!(notification);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _isDark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D23) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(isDark),
          _buildStepIndicator(isDark),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: _buildStepContent(isDark),
            ),
          ),
          _buildNavigation(isDark),
        ],
      ),
    );
  }

  Widget _buildHandle(bool isDark) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.2),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(bool isDark) {
    final stepCount = _maxStep + 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: List.generate(stepCount, (i) {
          final active = i == _step;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i < stepCount - 1 ? 4 : 0),
              height: 4,
              decoration: BoxDecoration(
                color: active
                    ? _gold
                    : (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent(bool isDark) {
    if (_hasKindStep && _step == 0) {
      return _buildKindStep(isDark);
    }
    final contentStep = _hasKindStep ? _step - 1 : _step;
    switch (contentStep) {
      case 0:
        return _buildTitleStep(isDark);
      case 1:
        return _buildBodyStep(isDark);
      case 2:
        return _buildIconStep(isDark);
      case 3:
        return _buildActionsStep(isDark);
      case 4:
        return _buildScheduleStep(isDark);
      case 5:
        return _buildConditionStep(isDark);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildKindStep(bool isDark) {
    final kinds = widget.context.notificationKinds!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'What kind of reminder?',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose the type of notification to create.',
          style: TextStyle(
            fontSize: 12,
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 20),
        ...kinds.map((kind) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _applyKindDefaults(kind);
                  _step = 1;
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _gold.withOpacity(0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kind.label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (kind.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        kind.description!,
                        style: TextStyle(
                          fontSize: 12,
                          color: (isDark ? Colors.white : Colors.black)
                              .withOpacity(0.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTitleStep(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Notification Title',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Use variables to personalize. Tap a chip to insert.',
          style: TextStyle(
            fontSize: 12,
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _titleController,
          onChanged: (v) => setState(() => _titleTemplate = v),
          maxLines: 2,
          style: TextStyle(
            fontSize: 15,
            color: isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: 'e.g. {billName} due in {daysLeft} days',
            hintStyle: TextStyle(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.35),
            ),
            filled: true,
            fillColor: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.context.variables.map((v) {
            return ActionChip(
              label: Text(v.key, style: const TextStyle(fontSize: 11)),
              onPressed: () {
                HapticFeedback.selectionClick();
                final t = _titleController.text;
                final sel = _titleController.selection.baseOffset;
                final newText = t.substring(0, sel) + v.key + t.substring(sel);
                _titleController.text = newText;
                _titleController.selection = TextSelection.collapsed(offset: sel + v.key.length);
                setState(() => _titleTemplate = newText);
              },
              backgroundColor: _gold.withOpacity(0.15),
              side: BorderSide(color: _gold.withOpacity(0.4)),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBodyStep(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Notification Body',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _bodyController,
          onChanged: (v) => setState(() => _bodyTemplate = v),
          maxLines: 3,
          style: TextStyle(
            fontSize: 15,
            color: isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: 'e.g. {amount} - due {dueDate}',
            hintStyle: TextStyle(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.35),
            ),
            filled: true,
            fillColor: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.context.variables.map((v) {
            return ActionChip(
              label: Text(v.key, style: const TextStyle(fontSize: 11)),
              onPressed: () {
                HapticFeedback.selectionClick();
                final t = _bodyController.text;
                final sel = _bodyController.selection.baseOffset;
                final newText = t.substring(0, sel) + v.key + t.substring(sel);
                _bodyController.text = newText;
                _bodyController.selection = TextSelection.collapsed(offset: sel + v.key.length);
                setState(() => _bodyTemplate = newText);
              },
              backgroundColor: _gold.withOpacity(0.15),
              side: BorderSide(color: _gold.withOpacity(0.4)),
            );
          }).toList(),
        ),
      ],
    );
  }

  IconData? get _currentIconData {
    if (_iconCodePoint == null) return null;
    return IconData(
      _iconCodePoint!,
      fontFamily: _iconFontFamily ?? 'MaterialIcons',
      fontPackage: _iconFontPackage,
    );
  }

  Widget _buildIconStep(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Notification Icon',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Tap to open the full icon picker (1700+ icons).',
          style: TextStyle(
            fontSize: 12,
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () async {
            HapticFeedback.selectionClick();
            final icon = await showDialog<IconData>(
              context: context,
              builder: (ctx) => IconPickerWidget(
                selectedIcon: _currentIconData ?? Icons.notifications_rounded,
                isDark: isDark,
              ),
            );
            if (icon != null && mounted) {
              setState(() {
                _iconCodePoint = icon.codePoint;
                _iconFontFamily = icon.fontFamily ?? 'MaterialIcons';
                _iconFontPackage = icon.fontPackage;
              });
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _gold.withOpacity(0.5),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _gold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _currentIconData ?? Icons.notifications_rounded,
                    size: 32,
                    color: _gold,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choose Icon',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap to browse 1700+ icons',
                        style: TextStyle(
                          fontSize: 12,
                          color: (isDark ? Colors.white : Colors.black)
                              .withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.4),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionsStep(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Action Buttons',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          title: Text(
            'Show action buttons on notification',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          subtitle: Text(
            _actionsEnabled
                ? 'Up to 3 buttons will appear on the notification'
                : 'Notification will show without action buttons',
            style: TextStyle(
              fontSize: 12,
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
            ),
          ),
          value: _actionsEnabled,
          onChanged: (v) => setState(() => _actionsEnabled = v),
          activeColor: _gold,
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 12),
        if (_actionsEnabled) ...[
          Text(
            'Suggested for this reminder type. Tap to add (up to 3) or remove.',
            style: TextStyle(
              fontSize: 12,
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (_actionsEnabled) ..._actions.asMap().entries.map((e) {
          return ListTile(
            leading: Icon(Icons.circle, size: 8, color: _gold),
            title: Text(e.value.label),
            trailing: IconButton(
              icon: Icon(Icons.close, size: 18, color: Colors.red.withOpacity(0.7)),
              onPressed: () {
                setState(() => _actions.removeAt(e.key));
              },
            ),
          );
        }),
        if (_actionsEnabled && _actions.length < 3)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.context.availableActions
                .where((a) => !_actions.any((x) => x.actionId == a.actionId))
                .map((a) {
              return Tooltip(
                message: _actionTooltip(a.actionId),
                child: ActionChip(
                  label: Text(a.label),
                  avatar: Icon(
                    a.iconCodePoint != null
                        ? IconData(
                            a.iconCodePoint!,
                            fontFamily: a.iconFontFamily ?? 'MaterialIcons',
                            fontPackage: a.iconFontPackage,
                          )
                        : Icons.add_rounded,
                    size: 16,
                    color: _gold,
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() => _actions.add(a.toUniversalAction()));
                  },
                  backgroundColor: _gold.withOpacity(0.15),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  static String _actionTooltip(String actionId) {
    switch (actionId) {
      case 'view':
      case 'open':
        return 'Opens the detail screen';
      case 'mark_done':
      case 'done':
        return 'Marks as complete';
      case 'mark_paid':
        return 'Records payment';
      case 'snooze':
        return 'Reminds again later';
      case 'skip':
        return 'Skips this occurrence';
      case 'dismiss':
        return 'Dismisses the reminder';
      case 'go_to_sleep':
        return 'Opens Sleep screen';
      default:
        return 'Runs the "$actionId" action';
    }
  }

  Widget _buildScheduleStep(bool isDark) {
    final registry = NotificationHub().typeRegistry;
    final moduleTypes = registry.typesForModule(widget.context.moduleId);
    final types = [...registry.builtInTypes, ...moduleTypes];
    final suppressTiming = widget.context.suppressTimingEdits;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'When to Notify',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Notification type (sound, priority)',
          style: TextStyle(
            fontSize: 12,
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: types.map((t) {
            final selected = _typeId == t.id;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _typeId = t.id);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: (selected ? _gold : (isDark ? Colors.white : Colors.black))
                      .withOpacity(selected ? 0.25 : 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? _gold : Colors.transparent,
                  ),
                ),
                child: Text(
                  t.displayName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? _gold : (isDark ? Colors.white54 : Colors.black54),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (suppressTiming) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _gold.withOpacity(0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 18, color: _gold),
                    const SizedBox(width: 8),
                    Text(
                      '$_timingValue min before your bedtime',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
                if (widget.context.timingSummaryText != null &&
                    widget.context.timingSummaryText!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Calculated fire times:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: (isDark ? Colors.white70 : Colors.black54),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.context.timingSummaryText!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _gold,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  'From your bedtime per day (Wind-Down settings). Cannot edit here.',
                  style: TextStyle(
                    fontSize: 12,
                    color: (isDark ? Colors.white54 : Colors.black54),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          const SizedBox(height: 20),
          Text(
            'Timing (relative to due date)',
            style: TextStyle(
              fontSize: 12,
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildScheduleChip('3 days before', 'before', 3, isDark),
              const SizedBox(width: 8),
              _buildScheduleChip('1 day before', 'before', 1, isDark),
              _buildScheduleChip('On due', 'on_due', 0, isDark),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildScheduleChip('1 day after', 'after_due', 1, isDark),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Time of day',
            style: TextStyle(
              fontSize: 12,
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(hour: _hour, minute: _minute),
              );
              if (picked != null && mounted) {
                setState(() {
                  _hour = picked.hour;
                  _minute = picked.minute;
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _gold.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 20,
                    color: _gold,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.edit_rounded,
                    size: 18,
                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildScheduleChip(String label, String timing, int value, bool isDark) {
    final selected = _timing == timing && _timingValue == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _timing = timing;
            _timingValue = value;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: (selected ? _gold : (isDark ? Colors.white : Colors.black))
                .withOpacity(selected ? 0.2 : 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? _gold : Colors.transparent,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? _gold : (isDark ? Colors.white54 : Colors.black54),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConditionStep(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'When to Fire',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        ...widget.context.conditions.map((c) {
          final selected = _condition == c.id;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _condition = c.id);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: (selected ? _gold : (isDark ? Colors.white : Colors.black))
                      .withOpacity(selected ? 0.2 : 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      selected ? Icons.check_circle : Icons.circle_outlined,
                      size: 20,
                      color: selected ? _gold : (isDark ? Colors.white38 : Colors.black38),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      c.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildNavigation(bool isDark) {
    final isKindStep = _hasKindStep && _step == 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.03),
      ),
      child: Row(
        children: [
          if (_step > 0)
            TextButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                _prevStep();
              },
              child: const Text('Back'),
            ),
          const Spacer(),
          if (!isKindStep && _step < _maxStep)
            FilledButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                _nextStep();
              },
              style: FilledButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: Colors.black87,
              ),
              child: const Text('Next'),
            )
          else if (_step == _maxStep)
            FilledButton(
              onPressed: (_saving || !_canSave) ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: Colors.black87,
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
        ],
      ),
    );
  }
}
