import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/dark_gradient.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/widgets/icon_picker_widget.dart';
import '../../../../core/widgets/color_picker_widget.dart';
import '../../../../core/widgets/form_components.dart';
import '../../../../core/models/recurrence_rule.dart';
import '../../data/models/habit_category.dart';
import '../../../../data/models/subtask.dart';
import '../providers/habit_category_providers.dart';
import '../../data/models/habit.dart';
import '../../data/models/habit_unit.dart';
import '../../data/models/completion_type_config.dart';
import '../providers/habit_providers.dart';
import '../providers/habit_tag_providers.dart';
import '../providers/habit_unit_providers.dart';
import '../providers/completion_type_config_providers.dart';
import '../providers/habit_type_providers.dart';
import '../../data/models/habit_type.dart';

/// Create Habit Screen - Modern design following Task app style
class CreateHabitScreen extends ConsumerStatefulWidget {
  final Habit? habit; // If editing existing habit

  const CreateHabitScreen({super.key, this.habit});

  @override
  ConsumerState<CreateHabitScreen> createState() => _CreateHabitScreenState();
}

class _CreateHabitScreenState extends ConsumerState<CreateHabitScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();
  final _motivationController = TextEditingController();
  final _titleFocusNode = FocusNode();
  
  // Basic Info
  IconData _selectedIcon = Icons.check_circle_outline;
  Color _selectedColor = const Color(0xFFCDAF56);
  String? _selectedCategoryId;
  String? _selectedHabitTypeId;
  bool _isSpecial = false;

  // Frequency
  String _frequencyType = 'daily';
  List<int> _weekDays = [];
  int _targetCount = 1;
  int? _customIntervalDays;
  String _frequencyPeriod = 'day';
  final _frequencyTimesController = TextEditingController(text: '1');

  // End Condition
  String _endCondition = 'never'; // 'never', 'on_date', 'after_occurrences'
  DateTime? _endDate;
  int? _endOccurrences;

  // Reminder
  bool _reminderEnabled = false;
  TimeOfDay? _reminderTime = const TimeOfDay(hour: 9, minute: 0);
  String _reminderDuration = 'At habit time';

  // Habit Time (specific time vs anytime)
  bool _hasSpecificTime = false;
  TimeOfDay? _habitTime = const TimeOfDay(hour: 9, minute: 0);

  // Goal/Milestone
  String? _goalType; // null, 'streak', 'count', 'duration'
  int? _goalTarget;
  bool _showGoal = false;

  // Habit Status (lifecycle)
  String _habitStatus = 'active'; // 'active', 'built', 'paused', 'failed', 'completed'
  DateTime? _pausedUntil;

  // Checklist
  final _subtaskController = TextEditingController();
  List<String> _checklist = [];

  // Tags
  List<String> _selectedTags = [];

  // Collapsible sections
  bool _showCategory = false;
  bool _showEndCondition = false;
  bool _showDescriptionSection = false;
  bool _showNotesSection = false;
  bool _showChecklist = false; // Collapsed by default
  bool _showGoalSection = false; // Collapsed by default
  bool _showStatusSection = false; // Collapsed by default

  // Completion Type
  String _completionType = 'yesNo'; // 'yesNo', 'numeric', 'timer', 'quit'
  
  // Yes/No fields
  int? _customYesPoints;
  int? _customNoPoints;
  int? _customPostponePoints;

  // Numeric fields
  double? _targetValue;
  String? _selectedUnitId;
  String _pointCalculation = 'proportional';
  double? _thresholdPercent = 80;
  int? _pointsPerUnit = 1;

  // Timer fields
  int? _targetDurationValue; // Value in selected unit
  String _timerType = 'target';
  double? _bonusPerMinute = 0.1;
  bool _allowOvertimeBonus = false;
  String _timeUnit = 'hour';

  // Quit fields
  int? _dailyReward = 10;
  int? _slipPenalty = -20;
  String _slipCalculation = 'fixed';
  int? _penaltyPerUnit = -5;
  int? _streakProtection = 0;
  double? _costPerUnit = 0;
  bool _enableCostTracking = false;
  String _currencyType = 'usd'; // usd, gbp, custom
  String _customCurrency = '';
  bool _enableTemptationTracking = true;
  bool _quitHabitActive = true;
  bool _hideQuitHabit = true;
  String _quitActionName = 'Drink';
  String _quitSubstance = '';

  bool _appliedQuitDefaults = false;

  // Start Date - when the habit officially begins
  DateTime _startDate = DateTime.now();

  // Default quit actions
  static const List<Map<String, dynamic>> _quitActions = [
    {'name': 'Drink', 'icon': Icons.local_bar_rounded, 'examples': 'Alcohol, Soda, Coffee'},
    {'name': 'Smoke', 'icon': Icons.smoking_rooms_rounded, 'examples': 'Cigarettes, Vape'},
    {'name': 'Eat', 'icon': Icons.fastfood_rounded, 'examples': 'Junk Food, Sweets, Snacks'},
    {'name': 'Watch', 'icon': Icons.tv_rounded, 'examples': 'TV, Social Media, YouTube'},
    {'name': 'Play', 'icon': Icons.sports_esports_rounded, 'examples': 'Video Games, Gambling'},
    {'name': 'Use', 'icon': Icons.phone_android_rounded, 'examples': 'Phone, Apps'},
    {'name': 'Do', 'icon': Icons.do_not_disturb_rounded, 'examples': 'Any other bad habit'},
  ];

  @override
  void initState() {
    super.initState();
    _initializeFromHabit();
  }

  void _initializeFromHabit() {
    final habit = widget.habit;
    if (habit != null) {
      _titleController.text = habit.title;
      _descriptionController.text = habit.description ?? '';
      _notesController.text = habit.notes ?? '';
      _motivationController.text = habit.motivation ?? '';
      _selectedIcon = habit.icon ?? Icons.check_circle_outline;
      _selectedColor = habit.color;
      _selectedCategoryId = habit.categoryId;
      _frequencyType = habit.frequencyType;
      _weekDays = List.from(habit.weekDays ?? []);
      _targetCount = habit.targetCount;
      _customIntervalDays = habit.customIntervalDays;
      _frequencyPeriod = habit.frequencyPeriod ?? 'day';
      _frequencyTimesController.text = habit.targetCount.toString();
      _endCondition = habit.endCondition ?? 'never';
      _endDate = habit.endDate;
      _endOccurrences = habit.endOccurrences;
      _reminderEnabled = habit.reminderEnabled;
      _reminderDuration = _normalizeReminderDuration(
        habit.reminderDuration ?? 'At habit time',
      );
      if (habit.reminderMinutes != null) {
        _reminderTime = TimeOfDay(
          hour: habit.reminderMinutes! ~/ 60,
          minute: habit.reminderMinutes! % 60,
        );
      }
      _hasSpecificTime = habit.hasSpecificTime;
      if (habit.habitTimeMinutes != null) {
        _habitTime = TimeOfDay(
          hour: habit.habitTimeMinutes! ~/ 60,
          minute: habit.habitTimeMinutes! % 60,
        );
      }
      _goalType = habit.goalType;
      _goalTarget = habit.goalTarget;
      if (habit.hasGoal) {
        _showGoalSection = true;
      }
      _habitStatus = habit.habitStatus;
      _pausedUntil = habit.pausedUntil;
      if (habit.habitStatus != 'active') {
        _showStatusSection = true;
      }
      _showDescriptionSection = (habit.description ?? '').isNotEmpty;
      _showNotesSection = (habit.notes ?? '').isNotEmpty;
      _selectedTags = List.from(habit.tags ?? []);
      _checklist = (habit.checklist ?? []).map((s) => s.title).toList();
      _completionType = habit.completionType;
      _selectedHabitTypeId = habit.habitTypeId;
      _isSpecial = habit.isSpecial;
      
      // Type-specific fields
      _customYesPoints = habit.customYesPoints;
      _customNoPoints = habit.customNoPoints;
      _customPostponePoints = habit.customPostponePoints;
      _targetValue = habit.targetValue;
      _selectedUnitId = habit.unit;
      _pointCalculation = habit.pointCalculation ?? 'proportional';
      _thresholdPercent = habit.thresholdPercent ?? 80;
      _pointsPerUnit = habit.pointsPerUnit ?? 1;
      
      _timerType = habit.timerType ?? 'target';
      _bonusPerMinute = habit.bonusPerMinute ?? 0.1;
      _allowOvertimeBonus = habit.allowOvertimeBonus ?? false;
      _timeUnit = habit.timeUnit ?? 'hour';
      if (habit.targetDurationMinutes != null) {
         if (_timeUnit == 'hour') {
          _targetDurationValue = habit.targetDurationMinutes! ~/ 60;
        } else if (_timeUnit == 'minute') {
          _targetDurationValue = habit.targetDurationMinutes;
        } else {
          _targetDurationValue = habit.targetDurationMinutes! * 60;
        }
      }

      _dailyReward = habit.dailyReward ?? 10;
      _slipPenalty = habit.slipPenalty ?? -20;
      _slipCalculation = habit.slipCalculation ?? 'fixed';
      _penaltyPerUnit = habit.penaltyPerUnit ?? -5;
      _streakProtection = habit.streakProtection ?? 0;
      _costPerUnit = habit.costPerUnit ?? 0;
      _enableCostTracking = habit.costTrackingEnabled ??
          ((habit.costPerUnit ?? 0) > 0);
      final symbol = (habit.currencySymbol ?? '\$').trim();
      if (symbol == '£') {
        _currencyType = 'gbp';
        _customCurrency = '';
      } else if (symbol == '\$' || symbol.isEmpty) {
        _currencyType = 'usd';
        _customCurrency = '';
      } else {
        _currencyType = 'custom';
        _customCurrency = symbol;
      }
      _enableTemptationTracking = habit.enableTemptationTracking ?? true;
      _quitHabitActive = habit.quitHabitActive ?? true;
      _hideQuitHabit = habit.hideQuitHabit ?? true;
      _quitActionName = habit.quitActionName ?? 'Drink';
      _quitSubstance = habit.quitSubstance ?? '';
      
      // Load start date from existing habit
      _startDate = habit.startDate;
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.habit == null) {
        _titleFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    _motivationController.dispose();
    _subtaskController.dispose();
    _frequencyTimesController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  /// Build a RecurrenceRule from the current frequency settings
  RecurrenceRule? _buildRecurrenceRule() {
    final startDate = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
    );
    
    switch (_frequencyType) {
      case 'daily':
        return RecurrenceRule.daily(
          startDate: startDate,
          interval: 1,
          endCondition: _endCondition,
          endDate: _endCondition == 'on_date' ? _endDate : null,
          occurrences: _endCondition == 'after_occurrences' ? _endOccurrences : null,
        );
      
      case 'weekly':
        // Convert weekdays to Sunday=0 format for RecurrenceRule
        return RecurrenceRule.weekly(
          startDate: startDate,
          daysOfWeek: _weekDays.isEmpty ? [startDate.weekday % 7] : _weekDays,
          interval: 1,
          endCondition: _endCondition,
          endDate: _endCondition == 'on_date' ? _endDate : null,
          occurrences: _endCondition == 'after_occurrences' ? _endOccurrences : null,
        );
      
      case 'xTimesPerWeek':
        // Weekly with flexible days
        return RecurrenceRule.weekly(
          startDate: startDate,
          daysOfWeek: List.generate(7, (i) => i), // All days available
          interval: 1,
          endCondition: _endCondition,
          endDate: _endCondition == 'on_date' ? _endDate : null,
          occurrences: _endCondition == 'after_occurrences' ? _endOccurrences : null,
        );
      
      case 'xTimesPerMonth':
        // Monthly (1st of month as anchor)
        return RecurrenceRule.monthly(
          startDate: startDate,
          daysOfMonth: [1], // Anchor to 1st, user tracks quota separately
          interval: 1,
          endCondition: _endCondition,
          endDate: _endCondition == 'on_date' ? _endDate : null,
          occurrences: _endCondition == 'after_occurrences' ? _endOccurrences : null,
        );
      
      case 'custom':
        // Map period to RecurrenceRule unit
        final period = _frequencyPeriod ?? 'day';
        switch (period) {
          case 'day':
            return RecurrenceRule.daily(
              startDate: startDate,
              interval: 1,
              endCondition: _endCondition,
              endDate: _endCondition == 'on_date' ? _endDate : null,
              occurrences: _endCondition == 'after_occurrences' ? _endOccurrences : null,
            );
          case 'week':
            return RecurrenceRule.weekly(
              startDate: startDate,
              daysOfWeek: List.generate(7, (i) => i),
              interval: 1,
              endCondition: _endCondition,
              endDate: _endCondition == 'on_date' ? _endDate : null,
              occurrences: _endCondition == 'after_occurrences' ? _endOccurrences : null,
            );
          case 'month':
            return RecurrenceRule.monthly(
              startDate: startDate,
              daysOfMonth: [1],
              interval: 1,
              endCondition: _endCondition,
              endDate: _endCondition == 'on_date' ? _endDate : null,
              occurrences: _endCondition == 'after_occurrences' ? _endOccurrences : null,
            );
          case 'year':
            return RecurrenceRule.yearly(
              startDate: startDate,
              dayOfYear: {'month': startDate.month, 'day': startDate.day},
              endCondition: _endCondition,
              endDate: _endCondition == 'on_date' ? _endDate : null,
              occurrences: _endCondition == 'after_occurrences' ? _endOccurrences : null,
            );
          default:
            return null;
        }
      
      default:
        return null;
    }
  }

  Future<void> _saveHabit() async {
    if (_titleController.text.trim().isEmpty) {
      HapticFeedback.heavyImpact();
      AppSnackbar.showError(context, 'Please enter a habit title');
      return;
    }

    if (_completionType == 'numeric' && _targetValue == null) {
      HapticFeedback.heavyImpact();
      AppSnackbar.showError(context, 'Please enter a target value');
      return;
    }

    if (_completionType == 'timer' && _targetDurationValue == null) {
      HapticFeedback.heavyImpact();
      AppSnackbar.showError(context, 'Please enter target duration');
      return;
    }

    HapticFeedback.mediumImpact();

    // Convert duration back to minutes
    int? targetDurationMinutes;
    if (_completionType == 'timer' && _targetDurationValue != null) {
      if (_timeUnit == 'hour') {
        targetDurationMinutes = _targetDurationValue! * 60;
      } else if (_timeUnit == 'minute') {
        targetDurationMinutes = _targetDurationValue;
      } else {
        targetDurationMinutes = (_targetDurationValue! / 60).round();
      }
    }

    // Build RecurrenceRule for cross-app integration
    final recurrenceRule = _buildRecurrenceRule();

    final habit = Habit(
      id: widget.habit?.id,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      iconCodePoint: _selectedIcon.codePoint,
      iconFontFamily: _selectedIcon.fontFamily,
      iconFontPackage: _selectedIcon.fontPackage,
      colorValue: _selectedColor.value,
      categoryId: _selectedCategoryId,
      habitTypeId: _selectedHabitTypeId,
      frequencyType: _frequencyType,
      weekDays: _frequencyType == 'weekly' ? _weekDays : null,
      targetCount: _frequencyType == 'custom' ? (int.tryParse(_frequencyTimesController.text) ?? 1) : 1,
      customIntervalDays: _frequencyType == 'custom' ? _customIntervalDays : null,
      frequencyPeriod: _frequencyType == 'custom' ? _frequencyPeriod : 'day',
      endCondition: _endCondition,
      endDate: _endCondition == 'on_date' ? _endDate : null,
      endOccurrences: _endCondition == 'after_occurrences' ? _endOccurrences : null,
      reminderEnabled: _reminderEnabled,
      reminderMinutes: _reminderEnabled
          ? (_hasSpecificTime && _habitTime != null
              ? _habitTime!.hour * 60 + _habitTime!.minute
              : 9 * 60)
          : null,
      reminderDuration: _reminderEnabled ? _reminderDuration : 'No reminder',
      hasSpecificTime: _hasSpecificTime,
      habitTimeMinutes: _hasSpecificTime && _habitTime != null
          ? _habitTime!.hour * 60 + _habitTime!.minute
          : null,
      goalType: _goalType,
      goalTarget: _goalTarget,
      goalStartDate: _goalType != null && _goalTarget != null ? _startDate : null,
      habitStatus: _habitStatus,
      statusChangedDate: widget.habit == null ? DateTime.now() : null,
      pausedUntil: _pausedUntil,
      motivation: _motivationController.text.trim().isEmpty ? null : _motivationController.text.trim(),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      tags: _selectedTags.isEmpty ? null : _selectedTags,
      isSpecial: _isSpecial,
      completionType: _completionType,
      customYesPoints: _completionType == 'yesNo' ? _customYesPoints : null,
      customNoPoints: _completionType == 'yesNo' ? _customNoPoints : null,
      customPostponePoints: _completionType == 'yesNo' ? _customPostponePoints : null,
      targetValue: _completionType == 'numeric' ? _targetValue : null,
      unit: (_completionType == 'numeric' || _completionType == 'quit') ? _selectedUnitId : null,
      pointCalculation: _completionType == 'numeric' ? _pointCalculation : null,
      thresholdPercent: _completionType == 'numeric' && _pointCalculation == 'threshold' ? _thresholdPercent : null,
      pointsPerUnit: _completionType == 'numeric' && _pointCalculation == 'perUnit' ? _pointsPerUnit : null,
      targetDurationMinutes: targetDurationMinutes,
      timerType: _completionType == 'timer' ? _timerType : null,
      bonusPerMinute: _completionType == 'timer' ? _bonusPerMinute : null,
      allowOvertimeBonus: _completionType == 'timer' ? _allowOvertimeBonus : null,
      timeUnit: _completionType == 'timer' ? _timeUnit : null,
      dailyReward: _completionType == 'quit' ? _dailyReward : null,
      slipPenalty: _completionType == 'quit' ? _slipPenalty : null,
      slipCalculation: _completionType == 'quit' ? _slipCalculation : null,
      penaltyPerUnit: _completionType == 'quit' ? _penaltyPerUnit : null,
      streakProtection: _completionType == 'quit' ? _streakProtection : null,
      costPerUnit: _completionType == 'quit' && _enableCostTracking ? _costPerUnit : null,
      costTrackingEnabled: _completionType == 'quit' ? _enableCostTracking : null,
      currencySymbol: _completionType == 'quit' && _enableCostTracking ? _selectedCurrencySymbol() : null,
      enableTemptationTracking: _completionType == 'quit' ? _enableTemptationTracking : null,
      quitHabitActive: _completionType == 'quit' ? _quitHabitActive : null,
      hideQuitHabit: _completionType == 'quit' ? _hideQuitHabit : null,
      quitActionName: _completionType == 'quit' ? _quitActionName : null,
      quitSubstance: _completionType == 'quit' && _quitSubstance.isNotEmpty ? _quitSubstance : null,
      checklist: _checklist.isEmpty ? null : _checklist.map((title) => Subtask(title: title)).toList().cast<Subtask>(),
      createdAt: widget.habit?.createdAt,
      startDate: _startDate, // User-defined start date!
      recurrence: recurrenceRule,
    );

    try {
      if (widget.habit == null) {
        await ref.read(habitNotifierProvider.notifier).addHabit(habit);
      } else {
        await ref.read(habitNotifierProvider.notifier).updateHabit(habit);
      }

      if (mounted) {
        AppSnackbar.showSuccess(context, widget.habit == null ? 'Habit created!' : 'Habit updated!');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, 'Error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.habit == null && !_appliedQuitDefaults) {
      ref.listen<AsyncValue<List<CompletionTypeConfig>>>(
        completionTypeConfigNotifierProvider,
        (previous, next) {
          if (_appliedQuitDefaults) return;
          next.whenData((configs) {
            final quitConfig = configs.firstWhere(
              (c) => c.typeId == 'quit',
              orElse: () => CompletionTypeConfig.quitDefault(),
            );
            if (!mounted) return;
            setState(() {
              _hideQuitHabit = quitConfig.defaultHideQuitHabit ?? true;
              _appliedQuitDefaults = true;
            });
          });
        },
      );
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1A1D23) : Colors.grey.shade50,
      body: isDark
          ? DarkGradient.wrap(child: _buildBody(context, isDark))
          : _buildBody(context, isDark),
    );
  }

  Widget _buildBody(BuildContext context, bool isDark) {
    return SafeArea(
      child: Column(
        children: [
          _buildAppBar(context, isDark),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Input
                  _buildTitleInput(context, isDark),
                  const SizedBox(height: 18),

                  // Description (Accordion)
                  _buildExpandableSection(
                    context: context,
                    isDark: isDark,
                    title: 'Description',
                    icon: Icons.subject_rounded,
                    isExpanded: _showDescriptionSection,
                    onToggle: () => setState(() => _showDescriptionSection = !_showDescriptionSection),
                    child: _buildDescriptionField(isDark),
                  ),
                  const SizedBox(height: 18),
                  
                  // Icon & Color Row
                  Row(
                    children: [
                      Expanded(child: _buildIconSelection(context, isDark)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildColorSelection(context, isDark)),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Special Habit Toggle
                  _buildSpecialHabitToggle(isDark),
                  const SizedBox(height: 18),

                  // The "Why" Factor
                  _buildMotivationInput(context, isDark),
                  const SizedBox(height: 18),
                  
                  // Completion Type Section
                  _buildCompletionTypeSection(context, isDark),
                  const SizedBox(height: 18),

                  // Subtasks Section (Always available)
                  _buildExpandableSection(
                    context: context,
                    isDark: isDark,
                    title: 'Subtasks',
                    icon: Icons.checklist_rounded,
                    isExpanded: _showChecklist,
                    onToggle: () => setState(() => _showChecklist = !_showChecklist),
                    badge: _checklist.isNotEmpty ? _checklist.length.toString() : null,
                    child: _buildChecklistSection(isDark),
                  ),
                  const SizedBox(height: 18),

                  // Quick Start Date Buttons
                  _buildQuickStartDateButtons(context, isDark),
                  const SizedBox(height: 18),
                  
                  // Start Date Section
                  _buildStartDateSection(context, isDark),
                  const SizedBox(height: 18),
                  
                  // Frequency Section
                  _buildFrequencySection(context, isDark),
                  const SizedBox(height: 18),

                  // Habit Time Section
                  _buildHabitTimeSection(context, isDark),
                  const SizedBox(height: 18),
                  
                  // Category Section (Accordion)
                  _buildExpandableSection(
                    context: context,
                    isDark: isDark,
                    title: 'Category',
                    icon: Icons.category_rounded,
                    isExpanded: _showCategory,
                    onToggle: () => setState(() => _showCategory = !_showCategory),
                    child: _buildCategorySection(context, isDark),
                  ),
                  const SizedBox(height: 18),
                  
                  // End Condition Section (Accordion)
                  _buildExpandableSection(
                    context: context,
                    isDark: isDark,
                    title: 'End Condition',
                    icon: Icons.event_available_rounded,
                    isExpanded: _showEndCondition,
                    onToggle: () => setState(() => _showEndCondition = !_showEndCondition),
                    child: _buildEndConditionSection(context, isDark),
                  ),
                  const SizedBox(height: 18),
                  
                  // Habit Type (Points) Section
                  _buildHabitTypeSection(context, isDark),
                  const SizedBox(height: 18),
                  
                  // Tags Section
                  _buildTagsSection(context, isDark),
                  const SizedBox(height: 18),
                  
                  // Reminder Section
                  _buildReminderSection(context, isDark),
                  const SizedBox(height: 18),

                  // Goal/Milestone Section (Accordion - Optional)
                  _buildExpandableSection(
                    context: context,
                    isDark: isDark,
                    title: 'Goal / Milestone',
                    icon: Icons.emoji_events_rounded,
                    isExpanded: _showGoalSection,
                    onToggle: () => setState(() => _showGoalSection = !_showGoalSection),
                    badge: _goalType != null ? '✓' : null,
                    child: _buildGoalSection(isDark),
                  ),
                  const SizedBox(height: 18),

                  // Status Section (Accordion - Optional)
                  _buildExpandableSection(
                    context: context,
                    isDark: isDark,
                    title: 'Habit Status',
                    icon: Icons.flag_rounded,
                    isExpanded: _showStatusSection,
                    onToggle: () => setState(() => _showStatusSection = !_showStatusSection),
                    badge: _habitStatus != 'active' ? _getStatusEmoji(_habitStatus) : null,
                    child: _buildStatusSection(isDark),
                  ),
                  const SizedBox(height: 18),

                  // Notes Section (Accordion)
                  _buildExpandableSection(
                    context: context,
                    isDark: isDark,
                    title: 'Notes',
                    icon: Icons.sticky_note_2_rounded,
                    isExpanded: _showNotesSection,
                    onToggle: () => setState(() => _showNotesSection = !_showNotesSection),
                    child: _buildNotesField(isDark),
                  ),
                  
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                color: isDark ? Colors.white : Colors.black87,
                size: 20,
              ),
            ),
          ),
          const Spacer(),
          Text(
            widget.habit == null ? 'New Habit' : 'Edit Habit',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _saveHabit,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFCDAF56), Color(0xFFB8982E)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_rounded, color: Colors.black87, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Save',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleInput(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D3139) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF3E4148) : Colors.grey.shade200,
        ),
      ),
      child: TextField(
        controller: _titleController,
        focusNode: _titleFocusNode,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          hintText: 'What habit to build?',
          hintStyle: TextStyle(
            color: isDark ? Colors.white38 : Colors.grey.shade400,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 16, right: 12),
            child: Icon(Icons.edit_rounded, color: Color(0xFFCDAF56), size: 24),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        ),
        textCapitalization: TextCapitalization.sentences,
      ),
    );
  }

  Widget _buildIconSelection(BuildContext context, bool isDark) {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.selectionClick();
        final icon = await showDialog<IconData>(
          context: context,
          builder: (context) => IconPickerWidget(
            selectedIcon: _selectedIcon,
            isDark: isDark,
          ),
        );
        if (icon != null) {
          setState(() => _selectedIcon = icon);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D3139) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF3E4148) : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _selectedColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_selectedIcon, color: _selectedColor, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'Icon',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white38 : Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _buildColorSelection(BuildContext context, bool isDark) {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.selectionClick();
        final color = await showDialog<Color>(
          context: context,
          builder: (context) => ColorPickerWidget(
            selectedColor: _selectedColor,
            isDark: isDark,
          ),
        );
        if (color != null) {
          setState(() => _selectedColor = color);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D3139) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF3E4148) : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _selectedColor,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Color',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white38 : Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  void _addChecklistItem() {
    if (_subtaskController.text.trim().isNotEmpty) {
      HapticFeedback.lightImpact();
      setState(() {
        _checklist.add(_subtaskController.text.trim());
        _subtaskController.clear();
      });
    }
  }

  Widget _buildSpecialHabitToggle(bool isDark) {
    const accentGold = Color(0xFFCDAF56);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _isSpecial = !_isSpecial);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D3139) : Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _isSpecial
                ? accentGold
                : (isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.08)),
            width: _isSpecial ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              _isSpecial ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 18,
              color: _isSpecial ? accentGold : (isDark ? Colors.white54 : Colors.black45),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Special Habit',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
            Switch.adaptive(
              value: _isSpecial,
              onChanged: (value) {
                HapticFeedback.selectionClick();
                setState(() => _isSpecial = value);
              },
              activeColor: accentGold,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMotivationInput(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ModernSectionHeader(
          icon: Icons.auto_awesome_rounded,
          title: "The 'Why' Factor",
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2D3139) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF3E4148) : Colors.grey.shade200,
            ),
          ),
          child: TextField(
            controller: _motivationController,
            maxLength: 75,
            maxLines: 1,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
              fontStyle: FontStyle.italic,
            ),
            decoration: InputDecoration(
              hintText: "E.g., To be healthy for my family",
              hintStyle: TextStyle(
                color: isDark ? Colors.white38 : Colors.grey.shade400,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
              prefixIcon: Icon(
                Icons.format_quote_rounded,
                color: const Color(0xFFCDAF56).withOpacity(0.7),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              counterStyle: TextStyle(
                color: isDark ? Colors.white38 : Colors.grey.shade500,
                fontSize: 10,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletionTypeSection(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ModernSectionHeader(icon: Icons.track_changes_rounded, title: 'Tracking Method', isDark: isDark),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _TypeChip(
                label: 'Yes/No',
                icon: Icons.check_circle_outline,
                isSelected: _completionType == 'yesNo',
                color: Colors.green,
                onTap: () => setState(() => _completionType = 'yesNo'),
                isDark: isDark,
              ),
              const SizedBox(width: 10),
              _TypeChip(
                label: 'Numeric',
                icon: Icons.numbers_rounded,
                isSelected: _completionType == 'numeric',
                color: Colors.blue,
                onTap: () => setState(() => _completionType = 'numeric'),
                isDark: isDark,
              ),
              const SizedBox(width: 10),
              _TypeChip(
                label: 'Timer',
                icon: Icons.timer_outlined,
                isSelected: _completionType == 'timer',
                color: Colors.purple,
                onTap: () => setState(() => _completionType = 'timer'),
                isDark: isDark,
              ),
              const SizedBox(width: 10),
              _TypeChip(
                label: 'Quit',
                icon: Icons.smoke_free_rounded,
                isSelected: _completionType == 'quit',
                color: Colors.red,
                onTap: () => setState(() => _completionType = 'quit'),
                isDark: isDark,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildTypeConfig(isDark),
      ],
    );
  }

  Widget _buildTypeConfig(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D3139) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF3E4148) : Colors.grey.shade200,
        ),
      ),
      child: _buildTypeSpecificFields(isDark),
    );
  }

  Widget _buildTypeSpecificFields(bool isDark) {
    if (_completionType == 'yesNo') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildNumberInput(
            label: 'Done Points',
            hint: 'Default: 10',
            value: _customYesPoints?.toString(),
            onChanged: (v) => _customYesPoints = int.tryParse(v),
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _buildNumberInput(
            label: 'Not Done Points',
            hint: 'Default: -10',
            value: _customNoPoints?.toString(),
            onChanged: (v) => _customNoPoints = int.tryParse(v),
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _buildNumberInput(
            label: 'Postpone Points',
            hint: 'Default: -5',
            value: _customPostponePoints?.toString(),
            onChanged: (v) => _customPostponePoints = int.tryParse(v),
            isDark: isDark,
          ),
        ],
      );
    } else if (_completionType == 'numeric') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildNumberInput(
            label: 'Target Value',
            hint: 'e.g. 8',
            value: _targetValue?.toString(),
            onChanged: (v) => _targetValue = double.tryParse(v),
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _buildUnitSelector(isDark),
          const SizedBox(height: 12),
          _buildCalculationSelector(isDark),
        ],
      );
    } else if (_completionType == 'timer') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildNumberInput(
            label: 'Target Duration',
            hint: 'e.g. 30',
            value: _targetDurationValue?.toString(),
            onChanged: (v) => _targetDurationValue = int.tryParse(v),
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _buildTimeUnitSelector(isDark),
          const SizedBox(height: 12),
          _buildTimerModeSelector(isDark),
          if (_timerType == 'target') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Overtime Bonus', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.grey.shade600)),
                      Switch.adaptive(
                        value: _allowOvertimeBonus,
                        activeColor: const Color(0xFFCDAF56),
                        onChanged: (v) => setState(() => _allowOvertimeBonus = v),
                      ),
                    ],
                  ),
                ),
                if (_allowOvertimeBonus)
                  Expanded(
                    child: _buildNumberInput(
                      label: 'Bonus / Min',
                      hint: 'e.g. 0.1',
                      value: _bonusPerMinute?.toString(),
                      onChanged: (v) => _bonusPerMinute = double.tryParse(v),
                      isDark: isDark,
                    ),
                  ),
              ],
            ),
          ],
          if (_timerType == 'minimum') ...[
            const SizedBox(height: 12),
            _buildNumberInput(
              label: 'Bonus / Min',
              hint: 'e.g. 0.1',
              value: _bonusPerMinute?.toString(),
              onChanged: (v) => _bonusPerMinute = double.tryParse(v),
              isDark: isDark,
            ),
          ],
        ],
      );
    } else if (_completionType == 'quit') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Action Selector (What are you quitting?)
          Text('What are you quitting?', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.grey.shade600)),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _quitActions.map((action) {
                final isSelected = _quitActionName == action['name'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _quitActionName = action['name']),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.red.withOpacity(0.15) : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isSelected ? Colors.red : Colors.transparent, width: 2),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(action['icon'] as IconData, size: 18, color: isSelected ? Colors.red : (isDark ? Colors.white54 : Colors.grey)),
                          const SizedBox(width: 6),
                          Text(action['name'], style: TextStyle(fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal, color: isSelected ? Colors.red : (isDark ? Colors.white70 : Colors.black54))),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _quitActions.firstWhere((a) => a['name'] == _quitActionName)['examples'] as String,
            style: TextStyle(fontSize: 11, color: isDark ? Colors.white24 : Colors.black26, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 16),
          
          // Substance field (What exactly?)
          _buildTextInput(
            label: 'What exactly? (Optional)',
            hint: 'e.g. Alcohol, Cigarettes, Junk Food',
            value: _quitSubstance,
            onChanged: (v) => setState(() => _quitSubstance = v),
            isDark: isDark,
          ),
          const SizedBox(height: 16),
          
          // Unit selector (How to measure slips)
          _buildUnitSelector(isDark, label: 'How do you measure slips?'),
          const SizedBox(height: 16),
          
          // Daily reward
          _buildNumberInput(
            label: 'Daily Reward Points',
            hint: 'Points for resisting each day',
            value: _dailyReward?.toString(),
            onChanged: (v) => _dailyReward = int.tryParse(v),
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          
          // Slip penalty type
          Text('Slip Penalty Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.grey.shade600)),
          const SizedBox(height: 6),
          Row(
            children: [
              _SimpleChip(label: 'Fixed', isSelected: _slipCalculation == 'fixed', onTap: () => setState(() => _slipCalculation = 'fixed'), isDark: isDark),
              const SizedBox(width: 8),
              _SimpleChip(label: 'Per Unit', isSelected: _slipCalculation == 'perUnit', onTap: () => setState(() => _slipCalculation = 'perUnit'), isDark: isDark),
            ],
          ),
          const SizedBox(height: 12),
          if (_slipCalculation == 'fixed')
            _buildNumberInput(
              label: 'Slip Penalty (Fixed)',
              hint: 'e.g. -20',
              value: _slipPenalty?.toString(),
              onChanged: (v) => _slipPenalty = int.tryParse(v),
              isDark: isDark,
            )
          else
            _buildNumberInput(
              label: 'Penalty Per Unit',
              hint: 'e.g. -5',
              value: _penaltyPerUnit?.toString(),
              onChanged: (v) => _penaltyPerUnit = int.tryParse(v),
              isDark: isDark,
            ),
          const SizedBox(height: 12),
          _buildNumberInput(
            label: 'Streak Protection (Slips allowed)',
            hint: '0 = immediate break',
            value: _streakProtection?.toString(),
            onChanged: (v) => _streakProtection = int.tryParse(v),
            isDark: isDark,
          ),
          const SizedBox(height: 16),

          // Cost tracking (optional)
          Text('Cost Tracking (Optional)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.grey.shade600)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Track money saved when you resist',
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38),
                ),
              ),
              Switch.adaptive(
                value: _enableCostTracking,
                activeColor: const Color(0xFF4CAF50),
                onChanged: (v) => setState(() => _enableCostTracking = v),
              ),
            ],
          ),
          if (_enableCostTracking) ...[
            const SizedBox(height: 8),
            Text('Currency',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.grey.shade600)),
            const SizedBox(height: 6),
            Row(
              children: [
                _SimpleChip(
                    label: '\$',
                    isSelected: _currencyType == 'usd',
                    onTap: () => setState(() => _currencyType = 'usd'),
                    isDark: isDark),
                const SizedBox(width: 8),
                _SimpleChip(
                    label: '£',
                    isSelected: _currencyType == 'gbp',
                    onTap: () => setState(() => _currencyType = 'gbp'),
                    isDark: isDark),
                const SizedBox(width: 8),
                _SimpleChip(
                    label: 'Custom',
                    isSelected: _currencyType == 'custom',
                    onTap: () => setState(() => _currencyType = 'custom'),
                    isDark: isDark),
              ],
            ),
            if (_currencyType == 'custom') ...[
              const SizedBox(height: 10),
              _buildTextInput(
                label: 'Custom Currency',
                hint: 'e.g. USD, AED, \$',
                value: _customCurrency,
                onChanged: (v) => setState(() => _customCurrency = v),
                isDark: isDark,
              ),
            ],
            const SizedBox(height: 10),
            _buildNumberInput(
              label: 'Cost per slip',
              hint: 'e.g. ${_selectedCurrencySymbol()} 7.50',
              value: _costPerUnit?.toString(),
              onChanged: (v) => _costPerUnit = double.tryParse(v),
              isDark: isDark,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Temptation Tracking', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.grey.shade600)),
                    Switch.adaptive(
                      value: _enableTemptationTracking,
                      activeColor: const Color(0xFFCDAF56),
                      onChanged: (v) => setState(() => _enableTemptationTracking = v),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Habit Active', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.grey.shade600)),
                    Switch.adaptive(
                      value: _quitHabitActive,
                      activeColor: Colors.green,
                      onChanged: (v) => setState(() => _quitHabitActive = v),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Hide quit habit from main dashboard
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hide bad habit on dashboard',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                      ),
                    ),
                    Switch.adaptive(
                      value: _hideQuitHabit,
                      activeColor: const Color(0xFF9C27B0),
                      onChanged: (v) => setState(() => _hideQuitHabit = v),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  String _selectedCurrencySymbol() {
    switch (_currencyType) {
      case 'gbp':
        return '£';
      case 'custom':
        return _customCurrency.trim();
      case 'usd':
      default:
        return '\$';
    }
  }

  Widget _buildNumberInput({
    required String label,
    required String hint,
    required String? value,
    required Function(String) onChanged,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white54 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: TextEditingController(text: value)..selection = TextSelection.fromPosition(TextPosition(offset: value?.length ?? 0)),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: onChanged,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade400),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFCDAF56))),
          ),
        ),
      ],
    );
  }

  Widget _buildNumberInputWithController({
    required String label,
    required String hint,
    required TextEditingController controller,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white54 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade400),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFCDAF56))),
          ),
        ),
      ],
    );
  }

  Widget _buildTextInput({
    required String label,
    required String hint,
    required String value,
    required Function(String) onChanged,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white54 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: TextEditingController(text: value)..selection = TextSelection.fromPosition(TextPosition(offset: value.length)),
          onChanged: onChanged,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade400),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFCDAF56))),
          ),
        ),
      ],
    );
  }

  Widget _buildUnitSelector(bool isDark, {String label = 'Unit'}) {
    final unitsAsync = ref.watch(habitUnitNotifierProvider);
    return unitsAsync.when(
      data: (units) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.grey.shade600)),
          const SizedBox(height: 6),
          DropdownButton<String>(
            // Defensive: DropdownButton requires the value to match exactly one item.
            // Older habits may store `habit.unit` as a label/symbol (e.g. "Pages"/"pg") rather than a unit id.
            // Also, data resets can make a previously-stored id no longer exist.
            value: _resolveUnitDropdownValue(units),
            isExpanded: true,
            hint: const Text('Select unit'),
            dropdownColor: isDark ? const Color(0xFF2D3139) : Colors.white,
            items: units.map((u) => DropdownMenuItem(value: u.id, child: Text(u.name))).toList(),
            onChanged: (v) => setState(() => _selectedUnitId = v),
          ),
        ],
      ),
      loading: () => const CircularProgressIndicator(),
      error: (_, __) => const Text('Error loading units'),
    );
  }

  /// Returns a safe dropdown value:
  /// - null if nothing selected / invalid
  /// - an existing unit id if selected
  /// - tries to map legacy stored labels/symbols to a unit id (and upgrades state)
  String? _resolveUnitDropdownValue(List<HabitUnit> units) {
    final raw = (_selectedUnitId ?? '').trim();
    if (raw.isEmpty) return null;

    // Already an id in the list.
    for (final u in units) {
      if (u.id == raw) return raw;
    }

    // Try legacy mapping by name/plural/symbol (case-insensitive).
    final lower = raw.toLowerCase();
    HabitUnit? match;
    for (final u in units) {
      if (u.name.toLowerCase() == lower ||
          u.pluralName.toLowerCase() == lower ||
          u.symbol.toLowerCase() == lower) {
        match = u;
        break;
      }
    }

    if (match != null) {
      // Upgrade the in-memory selection to the real id after this frame.
      // This avoids setState during build and prevents the dropdown assertion.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_selectedUnitId != match!.id) {
          setState(() => _selectedUnitId = match!.id);
        }
      });
      return match.id;
    }

    // Unknown value -> show hint instead of crashing.
    return null;
  }

  Widget _buildCalculationSelector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Calculation', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.grey.shade600)),
        const SizedBox(height: 6),
        Row(
          children: [
            _SimpleChip(label: 'Proportional', isSelected: _pointCalculation == 'proportional', onTap: () => setState(() => _pointCalculation = 'proportional'), isDark: isDark),
            const SizedBox(width: 8),
            _SimpleChip(label: 'Threshold', isSelected: _pointCalculation == 'threshold', onTap: () => setState(() => _pointCalculation = 'threshold'), isDark: isDark),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeUnitSelector(bool isDark) {
    return Row(
      children: [
        _SimpleChip(label: 'Hrs', isSelected: _timeUnit == 'hour', onTap: () => setState(() => _timeUnit = 'hour'), isDark: isDark),
        const SizedBox(width: 8),
        _SimpleChip(label: 'Min', isSelected: _timeUnit == 'minute', onTap: () => setState(() => _timeUnit = 'minute'), isDark: isDark),
        const SizedBox(width: 8),
        _SimpleChip(label: 'Sec', isSelected: _timeUnit == 'second', onTap: () => setState(() => _timeUnit = 'second'), isDark: isDark),
      ],
    );
  }

  Widget _buildTimerModeSelector(bool isDark) {
     return Row(
      children: [
        _SimpleChip(label: 'Target', isSelected: _timerType == 'target', onTap: () => setState(() => _timerType = 'target'), isDark: isDark),
        const SizedBox(width: 8),
        _SimpleChip(label: 'Minimum', isSelected: _timerType == 'minimum', onTap: () => setState(() => _timerType = 'minimum'), isDark: isDark),
      ],
    );
  }

  Widget _buildFrequencySection(BuildContext context, bool isDark) {
    // Calculate frequency preview text
    String summary = '';
    String nextDue = '';
    
    if (_frequencyType == 'daily') {
      summary = 'Every single day';
      nextDue = 'Every day starting today';
    } else if (_frequencyType == 'weekly') {
      if (_weekDays.isEmpty) {
        summary = 'Weekly (No days selected)';
      } else {
        final dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
        summary = 'Every ${_weekDays.map((d) => dayNames[d]).join(', ')}';
      }
    } else if (_frequencyType == 'custom') {
      final times = int.tryParse(_frequencyTimesController.text) ?? 1;
      final period = _frequencyPeriod[0].toUpperCase() + _frequencyPeriod.substring(1);
      summary = '$times time${times > 1 ? 's' : ''} per $period';
      nextDue = 'Resets every $period';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ModernSectionHeader(icon: Icons.repeat_rounded, title: 'Frequency', isDark: isDark),
        const SizedBox(height: 12),
        Row(
          children: [
            _FrequencyChip(label: 'Daily', isSelected: _frequencyType == 'daily', onTap: () => setState(() => _frequencyType = 'daily'), isDark: isDark),
            const SizedBox(width: 10),
            _FrequencyChip(label: 'Weekly', isSelected: _frequencyType == 'weekly', onTap: () => setState(() => _frequencyType = 'weekly'), isDark: isDark),
            const SizedBox(width: 10),
            _FrequencyChip(label: 'Custom', isSelected: _frequencyType == 'custom', onTap: () => setState(() => _frequencyType = 'custom'), isDark: isDark),
          ],
        ),
        if (_frequencyType == 'weekly') ...[
          const SizedBox(height: 16),
          _buildWeekDaySelector(isDark),
        ],
        if (_frequencyType == 'custom') ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2D3139) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF3E4148) : Colors.grey.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildNumberInputWithController(
                        label: 'Times',
                        hint: '1',
                        controller: _frequencyTimesController,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Per', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.grey.shade600)),
                          const SizedBox(height: 6),
                          DropdownButton<String>(
                            value: _frequencyPeriod,
                            isExpanded: true,
                            dropdownColor: isDark ? const Color(0xFF2D3139) : Colors.white,
                            items: ['day', 'week', 'month', 'year'].map((p) => DropdownMenuItem(
                              value: p,
                              child: Text(p[0].toUpperCase() + p.substring(1)),
                            )).toList(),
                            onChanged: (v) => setState(() => _frequencyPeriod = v!),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        
        // Frequency Preview Summary Box
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFCDAF56).withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFCDAF56).withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: const Color(0xFFCDAF56).withOpacity(0.7), size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    if (nextDue.isNotEmpty)
                      Text(
                        nextDue,
                        style: TextStyle(
                          color: isDark ? Colors.white38 : Colors.grey.shade500,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build the Start Date section - when the habit officially begins
  Widget _buildStartDateSection(BuildContext context, bool isDark) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDateOnly = DateTime(_startDate.year, _startDate.month, _startDate.day);
    final isToday = startDateOnly == today;
    final isFuture = startDateOnly.isAfter(today);
    
    String statusText;
    Color statusColor;
    IconData statusIcon;
    
    if (isToday) {
      statusText = 'Starts Today';
      statusColor = const Color(0xFF4CAF50);
      statusIcon = Icons.check_circle_rounded;
    } else if (isFuture) {
      final daysUntil = startDateOnly.difference(today).inDays;
      statusText = 'Starts in $daysUntil day${daysUntil > 1 ? 's' : ''}';
      statusColor = const Color(0xFFFFB347);
      statusIcon = Icons.schedule_rounded;
    } else {
      final daysAgo = today.difference(startDateOnly).inDays;
      statusText = 'Started $daysAgo day${daysAgo > 1 ? 's' : ''} ago';
      statusColor = const Color(0xFF64B5F6);
      statusIcon = Icons.history_rounded;
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ModernSectionHeader(
          icon: Icons.event_available_rounded,
          title: 'Start Date',
          isDark: isDark,
        ),
        const SizedBox(height: 8),
        Text(
          'When does this habit officially begin?',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white38 : Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 12),
        ModernPickerTile(
          icon: Icons.calendar_month_rounded,
          label: 'Start Date',
          value: DateFormat('EEEE, MMMM d, yyyy').format(_startDate),
          onTap: () => _selectStartDate(context),
          isDark: isDark,
          color: const Color(0xFF4ECDC4),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(statusIcon, color: statusColor, size: 14),
            const SizedBox(width: 6),
            Text(
              statusText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: statusColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickStartDateButtons(BuildContext context, bool isDark) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final startDateOnly = DateTime(_startDate.year, _startDate.month, _startDate.day);
    final isToday = _isSameDay(startDateOnly, todayDate);
    final isTomorrow = _isSameDay(startDateOnly, todayDate.add(const Duration(days: 1)));
    final isCustom = !isToday && !isTomorrow;

    return Row(
      children: [
        Expanded(
          child: QuickDateChip(
            label: 'Today',
            icon: Icons.today_rounded,
            isSelected: isToday,
            onTap: () => _setStartDate(0),
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: QuickDateChip(
            label: 'Tomorrow',
            icon: Icons.wb_sunny_rounded,
            isSelected: isTomorrow,
            onTap: () => _setStartDate(1),
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: QuickDateChip(
            label: 'Custom',
            icon: Icons.edit_calendar_rounded,
            isSelected: isCustom,
            onTap: () => _selectStartDate(context),
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _setStartDate(int daysFromNow) {
    final now = DateTime.now();
    final target = now.add(Duration(days: daysFromNow));
    setState(() => _startDate = DateTime(
          target.year,
          target.month,
          target.day,
          _startDate.hour,
          _startDate.minute,
        ));
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'When does this habit start?',
    );
    if (picked != null) {
      setState(() => _startDate = DateTime(
            picked.year,
            picked.month,
            picked.day,
            _startDate.hour,
            _startDate.minute,
          ));
    }
  }

  Widget _buildEndConditionSection(BuildContext context, bool isDark) {
    return Column(
      children: [
        _buildEndConditionOption('never', 'Never End', Icons.all_inclusive_rounded, isDark),
        const SizedBox(height: 8),
        _buildEndConditionOption('on_date', 'On specific date', Icons.calendar_today_rounded, isDark),
        const SizedBox(height: 8),
        _buildEndConditionOption('after_occurrences', 'After X times', Icons.numbers_rounded, isDark),
        
        if (_endCondition == 'on_date') ...[
          const SizedBox(height: 16),
          ModernPickerTile(
            icon: Icons.event_rounded,
            label: 'End Date',
            value: _endDate != null
                ? DateFormat('MMM d, yyyy').format(_endDate!)
                : 'Select end date',
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _endDate ?? DateTime.now().add(const Duration(days: 30)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
              );
              if (picked != null) setState(() => _endDate = picked);
            },
            isDark: isDark,
            color: const Color(0xFF4ECDC4),
          ),
        ],
        
        if (_endCondition == 'after_occurrences') ...[
          const SizedBox(height: 16),
          _buildNumberInput(
            label: 'Occurrences',
            hint: 'e.g. 30',
            value: _endOccurrences?.toString(),
            onChanged: (v) => _endOccurrences = int.tryParse(v),
            isDark: isDark,
          ),
        ],
      ],
    );
  }

  Widget _buildEndConditionOption(String value, String title, IconData icon, bool isDark) {
    final isSelected = _endCondition == value;
    return GestureDetector(
      onTap: () => setState(() => _endCondition = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFCDAF56).withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? const Color(0xFFCDAF56) : Colors.transparent),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? const Color(0xFFCDAF56) : Colors.grey, size: 18),
            const SizedBox(width: 12),
            Text(title, style: TextStyle(color: isSelected ? const Color(0xFFCDAF56) : (isDark ? Colors.white70 : Colors.black54), fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
            const Spacer(),
            if (isSelected) const Icon(Icons.check_rounded, color: Color(0xFFCDAF56), size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekDaySelector(bool isDark) {
    final days = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (index) {
        final isSelected = _weekDays.contains(index);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) _weekDays.remove(index);
              else _weekDays.add(index);
            });
          },
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFCDAF56) : (isDark ? const Color(0xFF2D3139) : Colors.white),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isSelected ? const Color(0xFFCDAF56) : (isDark ? const Color(0xFF3E4148) : Colors.grey.shade200)),
            ),
            child: Center(
              child: Text(days[index], style: TextStyle(color: isSelected ? Colors.black87 : (isDark ? Colors.white70 : Colors.black54), fontWeight: FontWeight.bold)),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildCategorySection(BuildContext context, bool isDark) {
    final categoriesAsync = ref.watch(habitCategoryNotifierProvider);
    return categoriesAsync.when(
      data: (categories) => Wrap(
        spacing: 10,
        runSpacing: 10,
        children: categories.map((c) => ModernChip(
          iconData: c.icon,
          label: c.name,
          color: c.color,
          isSelected: _selectedCategoryId == c.id,
          onTap: () => setState(() => _selectedCategoryId = (_selectedCategoryId == c.id ? null : c.id)),
          isDark: isDark,
        )).toList(),
      ),
      loading: () => const CircularProgressIndicator(),
      error: (_, __) => const Text('Error loading categories'),
    );
  }

  Widget _buildHabitTypeSection(BuildContext context, bool isDark) {
    final typesAsync = ref.watch(habitTypeNotifierProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ModernSectionHeader(icon: Icons.signal_cellular_alt_rounded, title: 'Habit Strength', isDark: isDark),
        const SizedBox(height: 12),
        typesAsync.when(
          data: (types) => Wrap(
            spacing: 10,
            runSpacing: 10,
            children: types.map((t) => ModernChip(
              emoji: '⚡',
              label: t.name,
              color: const Color(0xFFCDAF56),
              isSelected: _selectedHabitTypeId == t.id,
              onTap: () => setState(() => _selectedHabitTypeId = (_selectedHabitTypeId == t.id ? null : t.id)),
              isDark: isDark,
            )).toList(),
          ),
          loading: () => const CircularProgressIndicator(),
          error: (_, __) => const Text('Error loading types'),
        ),
      ],
    );
  }

  Widget _buildTagsSection(BuildContext context, bool isDark) {
    final availableTags = ref.watch(habitTagNotifierProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ModernSectionHeader(icon: Icons.label_rounded, title: 'Tags', isDark: isDark),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: [
            ...availableTags.map((tag) {
               final isSelected = _selectedTags.contains(tag);
               return _SimpleChip(
                 label: tag,
                 isSelected: isSelected,
                 onTap: () => setState(() => isSelected ? _selectedTags.remove(tag) : _selectedTags.add(tag)),
                 isDark: isDark,
               );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildHabitTimeSection(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ModernSectionHeader(icon: Icons.schedule_rounded, title: 'Habit Time', isDark: isDark),
            const Spacer(),
            Switch.adaptive(
              value: _hasSpecificTime,
              activeColor: const Color(0xFFCDAF56),
              onChanged: (v) => setState(() => _hasSpecificTime = v),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (!_hasSpecificTime)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2D3139).withOpacity(0.5) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF3E4148) : Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.all_inclusive_rounded, color: const Color(0xFFCDAF56).withOpacity(0.7), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'All-day habit • Log anytime',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (_hasSpecificTime) ...[
          Text(
            'Set the specific time for this habit',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white38 : Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 8),
          ModernPickerTile(
            icon: Icons.access_time_rounded,
            label: 'Time',
            value: _habitTime!.format(context),
            onTap: () async {
              final picked = await showTimePicker(context: context, initialTime: _habitTime!);
              if (picked != null) setState(() => _habitTime = picked);
            },
            isDark: isDark,
            color: const Color(0xFFFFB347),
          ),
        ],
      ],
    );
  }

  Widget _buildReminderSection(BuildContext context, bool isDark) {
    final reminderOptions = <String>[
      'At habit time',
      '5 min before',
      '15 min before',
      '30 min before',
      '1 hour before',
      '1 day before',
    ];
    final selectedDuration = _normalizeReminderDuration(_reminderDuration);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ModernSectionHeader(icon: Icons.notifications_active_rounded, title: 'Reminder', isDark: isDark),
            const Spacer(),
            Switch.adaptive(
              value: _reminderEnabled,
              activeColor: const Color(0xFFCDAF56),
              onChanged: (v) => setState(() => _reminderEnabled = v),
            ),
          ],
        ),
        if (_reminderEnabled && !_hasSpecificTime)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Reminder will be based on 9:00 AM (default time)',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        if (_reminderEnabled) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2D3139) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'When should the reminder fire?',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: reminderOptions.contains(selectedDuration)
                      ? selectedDuration
                      : reminderOptions.first,
                  dropdownColor: isDark ? const Color(0xFF2D3139) : Colors.white,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withOpacity(0.04)
                        : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: (isDark ? Colors.white : Colors.black)
                            .withOpacity(0.08),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: (isDark ? Colors.white : Colors.black)
                            .withOpacity(0.08),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: Color(0xFFCDAF56),
                      ),
                    ),
                  ),
                  items: reminderOptions
                      .map(
                        (option) => DropdownMenuItem<String>(
                          value: option,
                          child: Text(option),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _reminderDuration = value);
                  },
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _normalizeReminderDuration(String rawDuration) {
    final normalized = rawDuration.trim().toLowerCase();
    if (normalized == 'at task time' ||
        normalized == 'on time' ||
        normalized == 'at_time' ||
        normalized == 'at time' ||
        normalized == 'at start time' ||
        normalized == 'at the start time' ||
        normalized == 'start time' ||
        normalized == 'at start') {
      return 'At habit time';
    }
    return rawDuration;
  }

  String _getStatusEmoji(String status) {
    switch (status) {
      case 'built':
        return '✓';
      case 'paused':
        return '⏸';
      case 'failed':
        return '✕';
      case 'completed':
        return '🏆';
      default:
        return '▶';
    }
  }

  Widget _buildStatusSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Track where you are in your habit journey',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white38 : Colors.grey.shade600,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 16),
        
        // Status Selection
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _StatusChip(
              label: 'Active',
              subtitle: 'Working on it',
              icon: Icons.play_circle_filled_rounded,
              color: const Color(0xFFCDAF56),
              isSelected: _habitStatus == 'active',
              onTap: () => setState(() {
                _habitStatus = 'active';
                _pausedUntil = null;
              }),
              isDark: isDark,
            ),
            _StatusChip(
              label: 'Built',
              subtitle: 'Automatic now',
              icon: Icons.verified_rounded,
              color: Colors.green,
              isSelected: _habitStatus == 'built',
              onTap: () => setState(() {
                _habitStatus = 'built';
                _pausedUntil = null;
              }),
              isDark: isDark,
            ),
            _StatusChip(
              label: 'Paused',
              subtitle: 'On hold',
              icon: Icons.pause_circle_filled_rounded,
              color: Colors.orange,
              isSelected: _habitStatus == 'paused',
              onTap: () => setState(() => _habitStatus = 'paused'),
              isDark: isDark,
            ),
            _StatusChip(
              label: 'Failed',
              subtitle: 'Gave up',
              icon: Icons.cancel_rounded,
              color: Colors.red,
              isSelected: _habitStatus == 'failed',
              onTap: () => setState(() {
                _habitStatus = 'failed';
                _pausedUntil = null;
              }),
              isDark: isDark,
            ),
            _StatusChip(
              label: 'Completed',
              subtitle: 'Goal reached',
              icon: Icons.check_circle_rounded,
              color: Colors.blue,
              isSelected: _habitStatus == 'completed',
              onTap: () => setState(() {
                _habitStatus = 'completed';
                _pausedUntil = null;
              }),
              isDark: isDark,
            ),
          ],
        ),
        
        // Pause Duration Picker (appears when paused is selected)
        if (_habitStatus == 'paused') ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.orange.withOpacity(0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 16,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Resume Date (Optional)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _pausedUntil ?? DateTime.now().add(const Duration(days: 7)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() => _pausedUntil = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black.withOpacity(0.2) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.white12 : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 18, color: Colors.orange),
                        const SizedBox(width: 12),
                        Text(
                          _pausedUntil != null
                              ? DateFormat('MMM d, y').format(_pausedUntil!)
                              : 'No auto-resume',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const Spacer(),
                        if (_pausedUntil != null)
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => setState(() => _pausedUntil = null),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGoalSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Set an optional goal to stay motivated',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white38 : Colors.grey.shade600,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 16),
        
        // Goal Type Selection
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _GoalTypeChip(
              label: 'Streak Goal',
              subtitle: 'Build consistency',
              icon: Icons.local_fire_department_rounded,
              isSelected: _goalType == 'streak',
              onTap: () => setState(() {
                if (_goalType == 'streak') {
                  _goalType = null;
                  _goalTarget = null;
                } else {
                  _goalType = 'streak';
                  _goalTarget = 30;
                }
              }),
              isDark: isDark,
            ),
            _GoalTypeChip(
              label: 'Count Goal',
              subtitle: 'Total completions',
              icon: Icons.numbers_rounded,
              isSelected: _goalType == 'count',
              onTap: () => setState(() {
                if (_goalType == 'count') {
                  _goalType = null;
                  _goalTarget = null;
                } else {
                  _goalType = 'count';
                  _goalTarget = 100;
                }
              }),
              isDark: isDark,
            ),
            _GoalTypeChip(
              label: 'Duration Goal',
              subtitle: 'Track for time',
              icon: Icons.calendar_today_rounded,
              isSelected: _goalType == 'duration',
              onTap: () => setState(() {
                if (_goalType == 'duration') {
                  _goalType = null;
                  _goalTarget = null;
                } else {
                  _goalType = 'duration';
                  _goalTarget = 90; // Start with 3 months
                }
              }),
              isDark: isDark,
            ),
          ],
        ),
        
        // Goal Target Input (appears when goal type is selected)
        if (_goalType != null) ...[
          const SizedBox(height: 20),
          _buildGoalTargetSelector(isDark),
        ],
      ],
    );
  }

  String _getGoalHint() {
    switch (_goalType) {
      case 'streak':
        return '30';
      case 'count':
        return '100';
      case 'duration':
        return '180';
      default:
        return '';
    }
  }

  String _getGoalUnit() {
    switch (_goalType) {
      case 'streak':
        return 'days';
      case 'count':
        return 'times';
      case 'duration':
        return 'days';
      default:
        return '';
    }
  }

  /// Build interactive goal target selector with presets and stepper
  Widget _buildGoalTargetSelector(bool isDark) {
    // Get presets based on goal type
    final presets = _getGoalPresets();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFCDAF56).withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFCDAF56).withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFCDAF56).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.flag_rounded,
                  size: 18,
                  color: const Color(0xFFCDAF56),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Set Your Target',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Current value display with stepper
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFCDAF56).withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Decrease button
                _buildStepperButton(
                  icon: Icons.remove_rounded,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      final step = _getStepSize();
                      _goalTarget = ((_goalTarget ?? 0) - step).clamp(1, 9999);
                    });
                  },
                  onLongPress: () {
                    HapticFeedback.mediumImpact();
                    setState(() {
                      final bigStep = _getStepSize() * 5;
                      _goalTarget = ((_goalTarget ?? 0) - bigStep).clamp(1, 9999);
                    });
                  },
                  isDark: isDark,
                ),
                
                // Value display
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showCustomValueDialog(isDark),
                    child: Column(
                      children: [
                        Text(
                          _goalTarget?.toString() ?? '0',
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFCDAF56),
                            letterSpacing: -1,
                          ),
                        ),
                        Text(
                          _getGoalUnit(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white54 : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getFormattedDuration(),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white38 : Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Increase button
                _buildStepperButton(
                  icon: Icons.add_rounded,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      final step = _getStepSize();
                      _goalTarget = ((_goalTarget ?? 0) + step).clamp(1, 9999);
                    });
                  },
                  onLongPress: () {
                    HapticFeedback.mediumImpact();
                    setState(() {
                      final bigStep = _getStepSize() * 5;
                      _goalTarget = ((_goalTarget ?? 0) + bigStep).clamp(1, 9999);
                    });
                  },
                  isDark: isDark,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Quick presets
          Text(
            'Quick Select',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 10),
          
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: presets.map((preset) {
              final isSelected = _goalTarget == preset['value'];
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _goalTarget = preset['value'] as int;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? const Color(0xFFCDAF56)
                        : (isDark ? Colors.white.withOpacity(0.08) : Colors.grey[100]),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected 
                          ? const Color(0xFFCDAF56)
                          : (isDark ? Colors.white.withOpacity(0.1) : Colors.grey[300]!),
                    ),
                  ),
                  child: Text(
                    preset['label'] as String,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected 
                          ? Colors.white 
                          : (isDark ? Colors.white70 : Colors.grey[700]),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          
          const SizedBox(height: 12),
          
          // Tap to edit hint
          Center(
            child: TextButton.icon(
              onPressed: () => _showCustomValueDialog(isDark),
              icon: Icon(Icons.edit_rounded, size: 16, color: const Color(0xFFCDAF56)),
              label: Text(
                'Enter custom value',
                style: TextStyle(
                  fontSize: 13,
                  color: const Color(0xFFCDAF56),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepperButton({
    required IconData icon,
    required VoidCallback onTap,
    required VoidCallback onLongPress,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFFCDAF56).withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFCDAF56).withOpacity(0.3),
          ),
        ),
        child: Icon(
          icon,
          color: const Color(0xFFCDAF56),
          size: 28,
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getGoalPresets() {
    switch (_goalType) {
      case 'streak':
        return [
          {'label': '7 days', 'value': 7},
          {'label': '21 days', 'value': 21},
          {'label': '30 days', 'value': 30},
          {'label': '66 days', 'value': 66},
          {'label': '90 days', 'value': 90},
          {'label': '100 days', 'value': 100},
          {'label': '365 days', 'value': 365},
        ];
      case 'count':
        return [
          {'label': '10', 'value': 10},
          {'label': '25', 'value': 25},
          {'label': '50', 'value': 50},
          {'label': '100', 'value': 100},
          {'label': '250', 'value': 250},
          {'label': '500', 'value': 500},
          {'label': '1000', 'value': 1000},
        ];
      case 'duration':
        return [
          {'label': '1 month', 'value': 30},
          {'label': '3 months', 'value': 90},
          {'label': '6 months', 'value': 180},
          {'label': '1 year', 'value': 365},
          {'label': '2 years', 'value': 730},
          {'label': '3 years', 'value': 1095},
          {'label': '5 years', 'value': 1825},
        ];
      default:
        return [];
    }
  }

  int _getStepSize() {
    switch (_goalType) {
      case 'streak':
        return 1;
      case 'count':
        return 5;
      case 'duration':
        // Smart step based on current value
        final current = _goalTarget ?? 0;
        if (current < 30) return 1;
        if (current < 90) return 7;
        if (current < 365) return 30;
        return 30;
      default:
        return 1;
    }
  }

  String _getFormattedDuration() {
    if (_goalType != 'duration' && _goalType != 'streak') return '';
    
    final days = _goalTarget ?? 0;
    if (days == 0) return '';
    
    if (days < 7) return '$days day${days > 1 ? 's' : ''}';
    if (days < 30) {
      final weeks = days ~/ 7;
      final remainingDays = days % 7;
      if (remainingDays == 0) return '$weeks week${weeks > 1 ? 's' : ''}';
      return '$weeks week${weeks > 1 ? 's' : ''}, $remainingDays day${remainingDays > 1 ? 's' : ''}';
    }
    if (days < 365) {
      final months = days ~/ 30;
      final remainingDays = days % 30;
      if (remainingDays == 0) return '~$months month${months > 1 ? 's' : ''}';
      return '~$months month${months > 1 ? 's' : ''}';
    }
    
    final years = days ~/ 365;
    final remainingMonths = (days % 365) ~/ 30;
    if (remainingMonths == 0) return '$years year${years > 1 ? 's' : ''}';
    return '$years year${years > 1 ? 's' : ''}, $remainingMonths month${remainingMonths > 1 ? 's' : ''}';
  }

  Future<void> _showCustomValueDialog(bool isDark) async {
    final controller = TextEditingController(text: _goalTarget?.toString() ?? '');
    
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF2D3139) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Enter Target Value',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFCDAF56),
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: TextStyle(
                  color: isDark ? Colors.white24 : Colors.grey[400],
                ),
                suffixText: _getGoalUnit(),
                suffixStyle: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white54 : Colors.grey[600],
                ),
                filled: true,
                fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: const Color(0xFFCDAF56), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _goalType == 'duration' 
                  ? 'Enter number of days (1-9999)'
                  : 'Enter your target (1-9999)',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null && value > 0 && value <= 9999) {
                Navigator.pop(context, value);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Please enter a valid number (1-9999)'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCDAF56),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Set'),
          ),
        ],
      ),
    );
    
    if (result != null) {
      setState(() {
        _goalTarget = result;
      });
    }
  }

  Widget _buildExpandableSection({
    required BuildContext context,
    required bool isDark,
    required String title,
    required IconData icon,
    required bool isExpanded,
    required VoidCallback onToggle,
    required Widget child,
    String? badge,
  }) {
    return ModernExpandableSection(
      isDark: isDark,
      title: title,
      icon: icon,
      isExpanded: isExpanded,
      onToggle: onToggle,
      badge: badge,
      child: child,
    );
  }

  Widget _buildChecklistSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Input field for checklist items
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _subtaskController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Add an item (e.g. Drink 1 glass)...',
                  hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade400),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
                  focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFCDAF56))),
                ),
                onSubmitted: (_) => _addChecklistItem(),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _addChecklistItem,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFCDAF56),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add_rounded, color: Colors.black87, size: 20),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // List of added items
        if (_checklist.isNotEmpty)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _checklist.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(Icons.drag_indicator_rounded, color: isDark ? Colors.white24 : Colors.black12, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _checklist[index],
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _checklist.removeAt(index));
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close_rounded, color: Colors.red.shade400, size: 16),
                      ),
                    ),
                  ],
                ),
              );
            },
          )
        else
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  Icon(Icons.checklist_rtl_rounded, color: isDark ? Colors.white10 : Colors.black12, size: 48),
                  const SizedBox(height: 8),
                  Text(
                    'No items added to your checklist yet.',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white24 : Colors.black26,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDescriptionField(bool isDark) {
    return TextField(
      controller: _descriptionController,
      maxLines: 2,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        hintText: 'Short description...',
        hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade400),
        filled: true,
        fillColor: isDark ? const Color(0xFF2D3139) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF3E4148) : Colors.grey.shade200,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF3E4148) : Colors.grey.shade200,
          ),
        ),
      ),
    );
  }

  Widget _buildNotesField(bool isDark) {
    return TextField(
      controller: _notesController,
      maxLines: 3,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        hintText: 'Notes...',
        hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade400),
        filled: true,
        fillColor: isDark ? const Color(0xFF2D3139) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF3E4148) : Colors.grey.shade200,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF3E4148) : Colors.grey.shade200,
          ),
        ),
      ),
    );
  }
}

// ===================== HELPER WIDGETS =====================

// Status Chip Widget
class _StatusChip extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _StatusChip({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.15)
              : (isDark ? const Color(0xFF2D3139) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? color
                : (isDark ? const Color(0xFF3E4148) : Colors.grey.shade200),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? color
                  : (isDark ? Colors.white54 : Colors.grey.shade600),
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected
                    ? color
                    : (isDark ? Colors.white : Colors.black87),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white38 : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Goal Type Chip Widget
class _GoalTypeChip extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _GoalTypeChip({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFCDAF56).withOpacity(0.15)
              : (isDark ? const Color(0xFF2D3139) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFCDAF56)
                : (isDark ? const Color(0xFF3E4148) : Colors.grey.shade200),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? const Color(0xFFCDAF56)
                  : (isDark ? Colors.white54 : Colors.grey.shade600),
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected
                    ? const Color(0xFFCDAF56)
                    : (isDark ? Colors.white : Colors.black87),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white38 : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;
  final bool isDark;

  const _TypeChip({required this.label, required this.icon, required this.isSelected, required this.color, required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : (isDark ? const Color(0xFF2D3139) : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? color : (isDark ? const Color(0xFF3E4148) : Colors.grey.shade200), width: isSelected ? 2 : 1),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isSelected ? color : (isDark ? Colors.white54 : Colors.grey.shade500)),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500, color: isSelected ? color : (isDark ? Colors.white70 : Colors.grey.shade600))),
          ],
        ),
      ),
    );
  }
}

class _FrequencyChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _FrequencyChip({required this.label, required this.isSelected, required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFCDAF56).withOpacity(0.15) : (isDark ? const Color(0xFF2D3139) : Colors.white),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isSelected ? const Color(0xFFCDAF56) : (isDark ? const Color(0xFF3E4148) : Colors.grey.shade200), width: isSelected ? 2 : 1),
          ),
          child: Center(
            child: Text(label, style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500, color: isSelected ? const Color(0xFFCDAF56) : (isDark ? Colors.white70 : Colors.grey.shade600))),
          ),
        ),
      ),
    );
  }
}

class _SimpleChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _SimpleChip({required this.label, required this.isSelected, required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFCDAF56).withOpacity(0.2) : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? const Color(0xFFCDAF56) : Colors.transparent),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal, color: isSelected ? const Color(0xFFCDAF56) : (isDark ? Colors.white70 : Colors.black54))),
      ),
    );
  }
}

