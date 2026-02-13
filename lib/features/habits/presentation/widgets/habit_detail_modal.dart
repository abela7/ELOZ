import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:confetti/confetti.dart';
import '../../../../core/widgets/duration_entry_sheet.dart';
import '../../../../core/widgets/numeric_entry_sheet.dart';
import '../../../../core/models/notification_settings.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../routing/app_router.dart';
import '../../data/models/habit.dart';
import '../../data/models/habit_completion.dart';
import '../../data/models/habit_notification_settings.dart';
import '../../data/models/habit_reason.dart';
import '../../data/repositories/habit_repository.dart';
import '../../providers/habit_notification_settings_provider.dart';
import '../../data/models/habit_unit.dart';
import '../../../../data/models/subtask.dart';
import '../providers/habit_reason_providers.dart';
import '../providers/habit_category_providers.dart';
import '../providers/habit_providers.dart';
import '../providers/habit_unit_providers.dart';
import '../screens/create_habit_screen.dart';
import '../screens/habit_statistics_screen.dart';
import 'habit_score_card.dart';
import 'skip_reason_dialog.dart';
import 'log_temptation_modal.dart';
import 'habit_timer_modal.dart';
import '../providers/temptation_log_providers.dart';

part 'habit_detail_modal_actions.dart';

/// Opens the same slip tracking flow used by Habit Detail -> Skip for quit habits.
Future<void> showHabitSlipTrackingModal(
  BuildContext context, {
  required Habit habit,
  DateTime? selectedDate,
  VoidCallback? onHabitUpdated,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _SlipTrackingModal(
      habit: habit,
      onHabitUpdated: onHabitUpdated,
      selectedDate: selectedDate,
    ),
  );
}

/// Habit Detail Modal - Full-featured bottom sheet
/// Adapted from Task Detail Modal with habit-specific features
class HabitDetailModal extends ConsumerStatefulWidget {
  static void show(
    BuildContext context, {
    required Habit habit,
    DateTime? selectedDate,
    VoidCallback? onHabitUpdated,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: false, // Handled by DraggableScrollableSheet
      useSafeArea: true,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          snap: true,
          snapSizes: const [0.4, 0.7, 0.9],
          builder: (context, scrollController) {
            return HabitDetailModal(
              habit: habit,
              selectedDate: selectedDate,
              onHabitUpdated: onHabitUpdated,
              scrollController: scrollController,
            );
          },
        );
      },
    );
  }

  final Habit habit;
  final DateTime? selectedDate;
  final VoidCallback? onHabitUpdated;
  final ScrollController? scrollController;

  const HabitDetailModal({
    super.key,
    required this.habit,
    this.selectedDate,
    this.onHabitUpdated,
    this.scrollController,
  });

  @override
  ConsumerState<HabitDetailModal> createState() => _HabitDetailModalState();
}

class _HabitDetailModalState extends ConsumerState<HabitDetailModal>
    with TickerProviderStateMixin {
  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  late AnimationController _pulseController;
  late AnimationController _effectController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late ConfettiController _confettiController;
  bool _showSuccess = false;
  bool _showSkip = false;
  bool _showPostpone = false;
  int _skipPoints = 0;
  int _postponePoints = 0;

  // Accordion expansion states
  bool _detailsExpanded = false;
  bool _goalExpanded = true;
  bool _subtasksExpanded = true;
  bool _notesExpanded = false;
  bool _statsExpanded = false;
  bool _temptationsExpanded = false;
  bool _snoozeHistoryExpanded = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _effectController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _effectController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _effectController, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _effectController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  String? _getDateRestrictionMessage(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final startDateOnly = DateTime(
      widget.habit.startDate.year,
      widget.habit.startDate.month,
      widget.habit.startDate.day,
    );
    if (dateOnly.isBefore(startDateOnly)) {
      return 'This habit starts on ${DateFormat('MMM d, yyyy').format(widget.habit.startDate)}. Cannot log for earlier dates.';
    }

    if (widget.habit.endCondition == 'on_date' &&
        widget.habit.endDate != null) {
      final endDateOnly = DateTime(
        widget.habit.endDate!.year,
        widget.habit.endDate!.month,
        widget.habit.endDate!.day,
      );
      if (dateOnly.isAfter(endDateOnly)) {
        return 'This habit ended on ${DateFormat('MMM d, yyyy').format(widget.habit.endDate!)}.';
      }
    }

    if (widget.habit.hasReachedEndOccurrences) {
      final occurrences = widget.habit.endOccurrences ?? 0;
      return 'This habit reached its target of $occurrences completions.';
    }

    return null;
  }

  /// Show error message when date is not valid for this habit
  void _showDateRestrictionError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.block_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[400],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _formatPoints(int points) {
    if (points == 0) return '';
    final sign = points > 0 ? '+' : '';
    return '$sign$points points';
  }

  HabitUnit? _tryResolveUnitById(
    String? unitId, {
    List<HabitUnit>? unitsOverride,
  }) {
    final id = (unitId ?? '').trim();
    if (id.isEmpty) return null;
    final units =
        unitsOverride ??
        ref
            .read(habitUnitNotifierProvider)
            .maybeWhen(data: (v) => v, orElse: () => null);
    if (units == null) return null;
    try {
      return units.firstWhere((u) => u.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Formats numeric value using HabitUnit lookup when `habit.unit` stores a unit id.
  /// Falls back safely (never shows UUIDs to the user).
  String _formatNumericValueForDisplay(
    Habit habit,
    double value, {
    List<HabitUnit>? units,
  }) {
    final custom = (habit.customUnitName ?? '').trim();
    if (custom.isNotEmpty) {
      // Uses the user-entered custom name.
      return habit.formatNumericValue(value);
    }

    final resolvedUnit = _tryResolveUnitById(habit.unit, unitsOverride: units);
    if (resolvedUnit != null) {
      return resolvedUnit.format(value);
    }

    final raw = (habit.unit ?? '').trim();
    final looksLikeId = raw.isNotEmpty && _uuidRegex.hasMatch(raw);
    if (looksLikeId || raw.isEmpty) {
      // Don't leak internal ids into UI.
      final hasFraction = value.truncateToDouble() != value;
      return value.toStringAsFixed(hasFraction ? 1 : 0);
    }

    // Legacy fallback if `unit` was stored as a label rather than an id.
    final hasFraction = value.truncateToDouble() != value;
    final formatted = value.toStringAsFixed(hasFraction ? 1 : 0);
    return '$formatted $raw';
  }

  /// Unit label for input fields (prefer plural display name).
  String _numericUnitLabelForInput(Habit habit) {
    final custom = (habit.customUnitName ?? '').trim();
    if (custom.isNotEmpty) return custom;
    final resolvedUnit = _tryResolveUnitById(habit.unit);
    if (resolvedUnit != null) return resolvedUnit.pluralName;
    final raw = (habit.unit ?? '').trim();
    final looksLikeId = raw.isNotEmpty && _uuidRegex.hasMatch(raw);
    return looksLikeId ? '' : raw;
  }

  Future<double?> _showNumericInputDialog() async {
    final unitLabel = _numericUnitLabelForInput(widget.habit);
    final target = widget.habit.targetValue;
    return NumericEntrySheet.show(
      context,
      title: 'Log ${widget.habit.title}',
      subtitle: widget.habit.title,
      unitLabel: unitLabel,
      targetValue: target,
      accentColor: widget.habit.color,
      pointsForValue: (v) => widget.habit.calculateNumericPoints(v),
    );
  }

  Future<int?> _showTimerInputDialog() async {
    final hoursController = TextEditingController();
    final minutesController = TextEditingController();
    final targetMinutes = widget.habit.targetDurationMinutes;
    String? errorText;

    final result = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('Log ${widget.habit.title}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (targetMinutes != null)
                  Text(
                    'Target: ${widget.habit.formatDuration(targetMinutes, compact: true)}',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).textTheme.bodySmall?.color?.withOpacity(0.7),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: hoursController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: false,
                        ),
                        decoration: const InputDecoration(labelText: 'Hours'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: minutesController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: false,
                        ),
                        decoration: const InputDecoration(labelText: 'Minutes'),
                      ),
                    ),
                  ],
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorText!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final hoursRaw = hoursController.text.trim();
                  final minutesRaw = minutesController.text.trim();
                  final hours = hoursRaw.isEmpty ? 0 : int.tryParse(hoursRaw);
                  final minutes = minutesRaw.isEmpty
                      ? 0
                      : int.tryParse(minutesRaw);

                  if (hours == null ||
                      minutes == null ||
                      hours < 0 ||
                      minutes < 0) {
                    setDialogState(
                      () => errorText = 'Enter valid hours and minutes',
                    );
                    return;
                  }

                  final totalMinutes = (hours * 60) + minutes;
                  if (totalMinutes <= 0) {
                    setDialogState(
                      () => errorText = 'Duration must be greater than 0',
                    );
                    return;
                  }

                  Navigator.pop(context, totalMinutes);
                },
                child: const Text('Log'),
              ),
            ],
          );
        },
      ),
    );

    hoursController.dispose();
    minutesController.dispose();
    return result;
  }

  void _handleDone() async {
    HapticFeedback.mediumImpact();
    // Capture before any navigation pops; using `context` after pop can crash.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final date = widget.selectedDate ?? DateTime.now();

    // CRITICAL: Prevent actions on dates before habit was created!
    final restrictionMessage = _getDateRestrictionMessage(date);
    if (restrictionMessage != null) {
      _showDateRestrictionError(restrictionMessage);
      return;
    }

    // Check if subtasks need to be completed first
    if (widget.habit.hasSubtasks && !widget.habit.isChecklistFullyCompleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please complete all subtasks first'),
          backgroundColor: const Color(0xFFFFB347),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      setState(() => _subtasksExpanded = true);
      return;
    }

    double? actualValue;
    int? actualDurationMinutes;
    if (widget.habit.isNumeric) {
      actualValue = await _showNumericInputDialog();
      if (actualValue == null) return;
    } else if (widget.habit.isTimer) {
      // Prefer the proper timer interface; keep manual log as fallback.
      actualDurationMinutes = await HabitTimerModal.show(
        context,
        habit: widget.habit,
      );
      // If user doesn't want to run a timer, allow a clean manual duration entry.
      actualDurationMinutes ??= await DurationEntrySheet.show(
        context,
        title: 'Log duration',
        subtitle: widget.habit.title,
        targetMinutes: widget.habit.targetDurationMinutes,
        initialUnit: widget.habit.effectiveTimeUnit,
        accentColor: widget.habit.color,
        pointsForMinutes: (m) => widget.habit.calculateTimerPoints(m).round(),
      );
      if (actualDurationMinutes == null) return;
    }

    final notifier = ref.read(habitNotifierProvider.notifier);
    final points = widget.habit.isTimer && actualDurationMinutes != null
        ? widget.habit.calculateTimerPoints(actualDurationMinutes).round()
        : widget.habit.isNumeric && actualValue != null
        ? widget.habit.calculateNumericPoints(actualValue)
        : widget.habit.isQuitHabit
        ? (widget.habit.dailyReward ?? widget.habit.customYesPoints ?? 0)
        : await notifier.getYesPointsForHabit(widget.habit);

    setState(() {
      _showSuccess = true;
      _showSkip = false;
      _showPostpone = false;
    });
    _effectController.forward();
    _confettiController.play();

    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    await notifier.completeHabitForDate(
      widget.habit.id,
      date,
      actualValue: actualValue,
      actualDurationMinutes: actualDurationMinutes,
    );

    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;
    navigator.pop();

    final pointsText = _formatPoints(points);
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.celebration, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                pointsText.isEmpty
                    ? 'Habit completed for ${DateFormat('MMM d').format(date)}! ðŸŽ‰'
                    : 'Habit completed for ${DateFormat('MMM d').format(date)}! $pointsText ðŸŽ‰',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    widget.onHabitUpdated?.call();
  }

  /// Handle logging a temptation for quit habits
  void _handleLogTemptation() {
    HapticFeedback.mediumImpact();
    final date = widget.selectedDate ?? DateTime.now();

    // CRITICAL: Prevent actions on dates before habit was created!
    final restrictionMessage = _getDateRestrictionMessage(date);
    if (restrictionMessage != null) {
      _showDateRestrictionError(restrictionMessage);
      return;
    }

    LogTemptationModal.show(
      context,
      habit: widget.habit,
      habitId: widget.habit.id,
      habitTitle: widget.habit.title,
      defaultDate:
          widget.selectedDate ?? DateTime.now(), // Use the selected date!
      onLogged: () {
        widget.onHabitUpdated?.call();
      },
    );
  }

  void _handleSkip() async {
    HapticFeedback.mediumImpact();
    // Capture before pop; `context` becomes invalid after closing the modal.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final date = widget.selectedDate ?? DateTime.now();

    // CRITICAL: Prevent actions on dates before habit was created!
    final restrictionMessage = _getDateRestrictionMessage(date);
    if (restrictionMessage != null) {
      _showDateRestrictionError(restrictionMessage);
      return;
    }

    // For quit habits, show slip tracking modal instead
    if (widget.habit.isQuitHabit) {
      _showSlipModal();
      return;
    }

    // Show skip reason dialog
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String? reason = await showDialog<String>(
      context: context,
      builder: (context) =>
          SkipReasonDialog(isDark: isDark, habitName: widget.habit.title),
    );

    // User cancelled
    if (reason == null || !mounted) return;

    final points = widget.habit.completionType == 'yesNo'
        ? await ref
              .read(habitNotifierProvider.notifier)
              .getNoPointsForHabit(widget.habit)
        : 0;

    setState(() {
      _showSkip = true;
      _showSuccess = false;
      _showPostpone = false;
      _skipPoints = points;
    });
    _effectController.forward();

    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    await ref
        .read(habitNotifierProvider.notifier)
        .skipHabitForDate(widget.habit.id, date, reason: reason);

    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;
    navigator.pop();

    final pointsText = _formatPoints(points);
    final skipMessage = pointsText.isEmpty
        ? 'Skipped: $reason'
        : 'Skipped: $reason â€¢ $pointsText';
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.skip_next_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                skipMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFFFB347),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    widget.onHabitUpdated?.call();
  }

  void _handlePostpone() async {
    HapticFeedback.mediumImpact();
    // Capture before pop; `context` becomes invalid after closing the modal.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final date = widget.selectedDate ?? DateTime.now();

    final restrictionMessage = _getDateRestrictionMessage(date);
    if (restrictionMessage != null) {
      _showDateRestrictionError(restrictionMessage);
      return;
    }

    if (widget.habit.isQuitHabit || widget.habit.completionType != 'yesNo') {
      return;
    }

    final points = await ref
        .read(habitNotifierProvider.notifier)
        .getPostponePointsForHabit(widget.habit);

    setState(() {
      _showPostpone = true;
      _showSuccess = false;
      _showSkip = false;
      _postponePoints = points;
    });
    _effectController.forward();

    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    await ref
        .read(habitNotifierProvider.notifier)
        .postponeHabitForDate(widget.habit.id, date);

    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;
    navigator.pop();

    final pointsText = _formatPoints(points);
    final message = pointsText.isEmpty
        ? 'Postponed for ${DateFormat('MMM d').format(date)}'
        : 'Postponed for ${DateFormat('MMM d').format(date)} â€¢ $pointsText';

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.schedule_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFFFB347),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    widget.onHabitUpdated?.call();
  }

  Future<void> _toggleSpecial() async {
    HapticFeedback.selectionClick();
    setState(() {
      widget.habit.isSpecial = !widget.habit.isSpecial;
    });
    await ref.read(habitNotifierProvider.notifier).updateHabit(widget.habit);
    widget.onHabitUpdated?.call();
  }

  void _handleUndo() async {
    HapticFeedback.mediumImpact();
    // Capture before pop; `context` becomes invalid after closing the modal.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final date = widget.selectedDate ?? DateTime.now();

    await ref
        .read(habitNotifierProvider.notifier)
        .uncompleteHabitForDate(widget.habit.id, date);

    if (!mounted) return;
    navigator.pop();

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.undo_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Action undone for ${DateFormat('MMM d').format(date)}.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFCDAF56),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    widget.onHabitUpdated?.call();
  }

  Future<void> _toggleSubtask(int index) async {
    HapticFeedback.lightImpact();
    if (widget.habit.checklist == null ||
        index >= widget.habit.checklist!.length) {
      return;
    }

    // --- ENHANCED REACTIVITY: Optimistic UI Update ---
    // 1. Create updated checklist locally
    final updatedChecklist = List<Subtask>.from(widget.habit.checklist!);
    updatedChecklist[index] = updatedChecklist[index].copyWith(
      isCompleted: !updatedChecklist[index].isCompleted,
    );

    // 2. Update state IMMEDIATELY for zero-lag UI
    setState(() {
      widget.habit.checklist = updatedChecklist;
    });

    // 3. Fire-and-forget DB update in background (don't await)
    ref.read(habitNotifierProvider.notifier).updateHabit(widget.habit);

    // 4. Trigger external refresh
    widget.onHabitUpdated?.call();
  }

  void _showSlipModal() {
    showHabitSlipTrackingModal(
      context,
      habit: widget.habit,
      selectedDate: widget.selectedDate,
      onHabitUpdated: widget.onHabitUpdated,
    );
  }

  @override
  Widget build(BuildContext context) {
    final habit = widget.habit;
    final themeColor = habit.color;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E2228) : const Color(0xFFF8F9FA);
    final cardColor = isDark ? const Color(0xFF252A31) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1C1E);
    final subtextColor = isDark
        ? Colors.white.withOpacity(0.7)
        : const Color(0xFF44474E);
    final iconColor = isDark
        ? Colors.white.withOpacity(0.5)
        : const Color(0xFF74777F);

    final selectedDate = widget.selectedDate ?? DateTime.now();
    final selectedDateOnly = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final snoozeHistoryForDate = habit.snoozeHistoryEntriesForDate(
      selectedDate,
    );
    final activeSnoozeUntilForDate = habit.activeSnoozedUntilForDate(
      selectedDate,
    );
    final dayStatusesAsync = ref.watch(
      habitStatusesOnDateProvider(selectedDateOnly),
    );
    final dayStatus = dayStatusesAsync.maybeWhen(
      data: (statuses) => statuses[habit.id] ?? HabitDayStatus.empty,
      orElse: () => HabitDayStatus.empty,
    );
    final isCompleted = dayStatus.isCompleted;
    final isSkipped = dayStatus.isSkipped;
    final isPostponed = dayStatus.isPostponed;

    final shouldWatchValueCompletions = habit.isNumeric || habit.isTimer;
    final numericCompletionAsync = shouldWatchValueCompletions
        ? ref.watch(
            habitCompletionsProvider((
              habitId: habit.id,
              startDate: selectedDateOnly,
              endDate: selectedDateOnly,
            )),
          )
        : const AsyncValue<List<HabitCompletion>>.data(<HabitCompletion>[]);
    final isActioned = isCompleted || isSkipped || isPostponed;
    final double? numericActualValue = numericCompletionAsync.maybeWhen(
      data: (completions) {
        for (final completion in completions) {
          final value = completion.actualValue;
          if (value != null) return value;
        }
        return null;
      },
      orElse: () => null,
    );
    final int? timerActualMinutes = numericCompletionAsync.maybeWhen(
      data: (completions) {
        for (final completion in completions) {
          final minutes = completion.actualDurationMinutes;
          if (minutes != null) return minutes;
        }
        return null;
      },
      orElse: () => null,
    );

    return PopScope(
      canPop: true,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
        ),
        child: Stack(
          children: [
            // Main Content
            SingleChildScrollView(
              controller: widget.scrollController,
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 160,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag Handle & Close Button
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.3)
                            : Colors.black.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),

                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16, top: 0),
                      child: IconButton(
                        icon: Icon(Icons.close_rounded, color: iconColor),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),

                  // Header with Icon and Title
                  _buildHeader(
                    habit,
                    themeColor,
                    isDark,
                    cardColor,
                    textColor,
                    subtextColor,
                    isCompleted,
                    isSkipped,
                    isPostponed,
                    numericActualValue,
                    timerActualMinutes,
                  ),

                  if (activeSnoozeUntilForDate != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF42A5F5).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF42A5F5).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.snooze_rounded,
                              size: 16,
                              color: Color(0xFF42A5F5),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Snoozed until ${DateFormat('hh:mm a').format(activeSnoozeUntilForDate)}',
                              style: const TextStyle(
                                color: Color(0xFF42A5F5),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Quick Info Pills
                  _buildQuickInfo(habit, isDark),

                  const SizedBox(height: 20),

                  if (habit.hasGoal)
                    _buildAccordionSection(
                      title: 'Goal & Milestones',
                      icon: Icons.emoji_events_rounded,
                      isExpanded: _goalExpanded,
                      onTap: () =>
                          setState(() => _goalExpanded = !_goalExpanded),
                      childBuilder: (_) =>
                          _buildGoalProgressContent(habit, isDark, textColor),
                      accentColor:
                          (habit.shouldCelebrateGoal() || habit.isGoalAchieved)
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFCDAF56),
                      isDark: isDark,
                      cardColor: cardColor,
                      textColor: textColor,
                    ),

                  // Accordion Sections
                  _buildAccordionSection(
                    title: 'Details',
                    icon: Icons.info_outline_rounded,
                    isExpanded: _detailsExpanded,
                    onTap: () =>
                        setState(() => _detailsExpanded = !_detailsExpanded),
                    childBuilder: (_) =>
                        _buildDetailsContent(habit, textColor, iconColor),
                    isDark: isDark,
                    cardColor: cardColor,
                    textColor: textColor,
                  ),

                  if (habit.hasSubtasks)
                    _buildAccordionSection(
                      title:
                          'Checklist (${habit.checklist!.where((s) => s.isCompleted).length}/${habit.checklist!.length})',
                      icon: Icons.checklist_rounded,
                      isExpanded: _subtasksExpanded,
                      onTap: () => setState(
                        () => _subtasksExpanded = !_subtasksExpanded,
                      ),
                      childBuilder: (_) => _buildSubtasksContent(
                        textColor,
                        subtextColor,
                        isDark,
                      ),
                      accentColor: const Color(0xFFCDAF56),
                      isDark: isDark,
                      cardColor: cardColor,
                      textColor: textColor,
                    ),

                  if (habit.notes != null && habit.notes!.isNotEmpty)
                    _buildAccordionSection(
                      title: 'Additional Notes',
                      icon: Icons.note_alt_outlined,
                      isExpanded: _notesExpanded,
                      onTap: () =>
                          setState(() => _notesExpanded = !_notesExpanded),
                      childBuilder: (_) =>
                          _buildNotesContent(habit, textColor, subtextColor),
                      isDark: isDark,
                      cardColor: cardColor,
                      textColor: textColor,
                    ),

                  // Temptation History - only for quit habits
                  if (habit.isQuitHabit)
                    _buildAccordionSection(
                      title: 'Temptation History',
                      icon: Icons.psychology_rounded,
                      isExpanded: _temptationsExpanded,
                      onTap: () => setState(
                        () => _temptationsExpanded = !_temptationsExpanded,
                      ),
                      childBuilder: (_) =>
                          _buildTemptationHistoryContent(habit, isDark),
                      accentColor: const Color(0xFF9C27B0),
                      isDark: isDark,
                      cardColor: cardColor,
                      textColor: textColor,
                    ),

                  // Snooze History (current occurrence only)
                  if (activeSnoozeUntilForDate != null ||
                      snoozeHistoryForDate.isNotEmpty)
                    _buildAccordionSection(
                      title: 'Snooze (${snoozeHistoryForDate.length}x)',
                      icon: Icons.snooze_rounded,
                      isExpanded: _snoozeHistoryExpanded,
                      onTap: () => setState(
                        () => _snoozeHistoryExpanded = !_snoozeHistoryExpanded,
                      ),
                      childBuilder: (_) => _buildSnoozeHistoryContent(
                        habit,
                        snoozeHistoryForDate,
                        activeSnoozeUntilForDate,
                        textColor,
                        subtextColor,
                        iconColor,
                        isDark,
                      ),
                      accentColor: const Color(0xFF42A5F5),
                      isDark: isDark,
                      cardColor: cardColor,
                      textColor: textColor,
                    ),

                  const SizedBox(height: 24),

                  // Action Buttons (Moved from floating stack to bottom of list)
                  _buildActionButtons(isDark, bgColor, cardColor, isActioned),

                  const SizedBox(height: 40),
                ],
              ),
            ),

            // Success Overlay
            if (_showSuccess) _buildSuccessOverlay(habit),

            // Skip Overlay
            if (_showSkip) _buildSkipOverlay(habit),

            // Postpone Overlay
            if (_showPostpone) _buildPostponeOverlay(habit),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    Habit habit,
    Color themeColor,
    bool isDark,
    Color cardColor,
    Color textColor,
    Color subtextColor,
    bool isCompleted,
    bool isSkipped,
    bool isPostponed,
    double? numericActualValue,
    int? timerActualMinutes,
  ) {
    const accentGold = Color(0xFFCDAF56);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(24),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: habit.isSpecial
              ? accentGold.withOpacity(isDark ? 0.35 : 0.25)
              : (isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.06)),
          width: 1,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background Icon
          Positioned(
            right: -15,
            bottom: -15,
            child: Opacity(
              opacity: 0.06,
              child: Icon(
                habit.icon ?? Icons.auto_awesome_rounded,
                size: 140,
                color: themeColor,
              ),
            ),
          ),

          // Main Content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: themeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: themeColor.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      habit.icon ?? Icons.auto_awesome_rounded,
                      color: themeColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (isCompleted)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF4CAF50).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 12,
                                  color: Color(0xFF4CAF50),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Completed',
                                  style: TextStyle(
                                    color: Color(0xFF4CAF50),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (isPostponed)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFB347).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFFFB347).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.schedule_rounded,
                                  size: 12,
                                  color: Color(0xFFFFB347),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Postponed',
                                  style: TextStyle(
                                    color: Color(0xFFFFB347),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (isSkipped)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFB347).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFFFB347).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.skip_next_rounded,
                                  size: 12,
                                  color: Color(0xFFFFB347),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Skipped',
                                  style: TextStyle(
                                    color: Color(0xFFFFB347),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (habit.isSpecial)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: accentGold.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: accentGold.withOpacity(0.35),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 12,
                                  color: accentGold,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'SPECIAL',
                                  style: TextStyle(
                                    color: accentGold,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Menu Button
                  _buildMenuButton(),
                ],
              ),
              const SizedBox(height: 16),
              // Title
              Text(
                habit.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: textColor,
                  height: 1.2,
                  letterSpacing: -0.5,
                ),
              ),

              // Motivation (The Why) - Small, elegant font
              if (habit.motivation != null && habit.motivation!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      width: 2,
                      height: 14,
                      decoration: BoxDecoration(
                        color: themeColor.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        habit.motivation!,
                        style: TextStyle(
                          color: subtextColor.withOpacity(0.8),
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              if (habit.isNumeric && habit.targetValue != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.straighten_rounded,
                      size: 14,
                      color: subtextColor.withOpacity(0.7),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Target: ${_formatNumericValueForDisplay(habit, habit.targetValue!)}',
                        style: TextStyle(
                          color: subtextColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (numericActualValue != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        size: 14,
                        color: subtextColor.withOpacity(0.7),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Logged: ${_formatNumericValueForDisplay(habit, numericActualValue)}',
                          style: TextStyle(
                            color: subtextColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],

              if (habit.isTimer && habit.targetDurationMinutes != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.timer_rounded,
                      size: 14,
                      color: subtextColor.withOpacity(0.7),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Target: ${habit.formatDuration(habit.targetDurationMinutes!, compact: true)}',
                      style: TextStyle(
                        color: subtextColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (timerActualMinutes != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        size: 14,
                        color: subtextColor.withOpacity(0.7),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Logged: ${habit.formatDuration(timerActualMinutes, compact: true)}',
                        style: TextStyle(
                          color: subtextColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],

              const SizedBox(height: 12),

              // Status Badge
              if (habit.habitStatus != 'active') ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: habit.statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: habit.statusColor.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        habit.statusIcon,
                        size: 14,
                        color: habit.statusColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        habit.statusDisplayName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: habit.statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // Frequency & Description
              Row(
                children: [
                  Icon(
                    Icons.repeat_rounded,
                    size: 14,
                    color: subtextColor.withOpacity(0.7),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    habit.frequencyDescription,
                    style: TextStyle(
                      color: subtextColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              // Habit Description (Full text in header)
              if (habit.description != null &&
                  habit.description!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  habit.description!,
                  style: TextStyle(
                    color: textColor.withOpacity(0.7),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuButton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopupMenuButton<String>(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.12)
                : Colors.black.withOpacity(0.08),
          ),
        ),
        child: Icon(
          Icons.more_horiz_rounded,
          color: isDark
              ? Colors.white.withOpacity(0.9)
              : Colors.black.withOpacity(0.7),
          size: 20,
        ),
      ),
      color: isDark ? const Color(0xFF252A31) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark
              ? Colors.white.withOpacity(0.12)
              : Colors.black.withOpacity(0.08),
        ),
      ),
      elevation: 8,
      onSelected: (value) async {
        if (value == 'special') {
          await _toggleSpecial();
        } else if (value == 'edit') {
          // Capture navigator before closing the modal to avoid using
          // a disposed BuildContext after pop.
          final navigator = Navigator.of(context);
          navigator.pop();
          final result = await navigator.push(
            MaterialPageRoute(
              builder: (context) => CreateHabitScreen(habit: widget.habit),
            ),
          );
          if (result == true) {
            widget.onHabitUpdated?.call();
          }
        } else if (value == 'delete') {
          _showDeleteConfirmation(context);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'special',
          child: Row(
            children: [
              Icon(
                widget.habit.isSpecial
                    ? Icons.star_outline_rounded
                    : Icons.star_rounded,
                color: const Color(0xFFCDAF56),
                size: 18,
              ),
              const SizedBox(width: 12),
              Text(
                widget.habit.isSpecial ? 'Unstar' : 'Star',
                style: TextStyle(
                  color: isDark
                      ? Colors.white.withOpacity(0.9)
                      : Colors.black.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(
                Icons.edit_rounded,
                color: isDark
                    ? Colors.white.withOpacity(0.9)
                    : Colors.black.withOpacity(0.7),
                size: 18,
              ),
              const SizedBox(width: 12),
              Text(
                'Edit',
                style: TextStyle(
                  color: isDark
                      ? Colors.white.withOpacity(0.9)
                      : Colors.black.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(
                Icons.delete_rounded,
                color: Colors.red.withOpacity(0.9),
                size: 18,
              ),
              const SizedBox(width: 12),
              Text(
                'Delete',
                style: TextStyle(
                  color: Colors.red.withOpacity(0.9),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickInfo(Habit habit, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          // Streak
          _buildInfoChip(
            icon: Icons.local_fire_department_rounded,
            label: '${habit.currentStreak} day streak',
            color: habit.currentStreak > 0
                ? const Color(0xFFFF6B6B)
                : Colors.grey,
            small: true,
            isDark: isDark,
          ),
          // Total Completions
          _buildInfoChip(
            icon: Icons.check_circle_rounded,
            label: '${habit.totalCompletions} times',
            color: const Color(0xFF4CAF50),
            small: true,
            isDark: isDark,
          ),
          // Points
          _buildInfoChip(
            icon: Icons.diamond_rounded,
            label: '+${habit.pointsEarned > 0 ? habit.pointsEarned : 10}',
            color: const Color(0xFFCDAF56),
            small: true,
            isDark: isDark,
          ),
          // Habit Time
          if (habit.hasSpecificTime && habit.habitTime != null)
            _buildInfoChip(
              icon: Icons.schedule_rounded,
              label: habit.habitTime!.format(context),
              color: habit.color,
              small: true,
              isDark: isDark,
            ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
    bool small = false,
    required bool isDark,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 10,
        vertical: small ? 4 : 6,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [color.withOpacity(0.15), color.withOpacity(0.05)]
              : [color.withOpacity(0.12), color.withOpacity(0.04)],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? color.withOpacity(0.25) : color.withOpacity(0.35),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: small ? 12 : 14,
            color: isDark ? color : color.withOpacity(0.9),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: isDark ? color : color.withOpacity(0.9),
              fontSize: small ? 9 : 11,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalProgressContent(Habit habit, bool isDark, Color textColor) {
    final target = habit.goalTargetSafe ?? 0;
    final current = habit.goalCurrentValue;
    final progressPct = habit.goalProgress;
    final nextMilestone = habit.nextGoalMilestone;
    final isAchieved = habit.shouldCelebrateGoal() || habit.isGoalAchieved;
    final progressColor = isAchieved
        ? const Color(0xFF4CAF50)
        : const Color(0xFFCDAF56);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progressPct / 100,
              backgroundColor: isDark
                  ? Colors.black.withOpacity(0.2)
                  : Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              minHeight: 12,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '$current / $target ${habit.goalUnitLabel}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
              Text(
                '${progressPct.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: progressColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Milestones',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (int i = 0; i < habit.goalMilestones.length; i++) ...[
                Expanded(
                  child: _buildGoalMilestoneChip(
                    milestone: habit.goalMilestones[i],
                    progressPct: progressPct,
                    isDark: isDark,
                    accentColor: progressColor,
                  ),
                ),
                if (i != habit.goalMilestones.length - 1)
                  const SizedBox(width: 6),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.04)
                  : Colors.black.withOpacity(0.03),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  nextMilestone == null
                      ? Icons.verified_rounded
                      : Icons.flag_rounded,
                  size: 14,
                  color: nextMilestone == null
                      ? const Color(0xFF4CAF50)
                      : progressColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    nextMilestone == null
                        ? 'All milestones completed.'
                        : 'Next milestone: $nextMilestone%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isAchieved) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.celebration_rounded,
                    color: Colors.green,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Goal achieved. Keep the momentum going.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
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

  Widget _buildGoalMilestoneChip({
    required int milestone,
    required double progressPct,
    required bool isDark,
    required Color accentColor,
  }) {
    final reached = progressPct >= milestone;
    final chipColor = reached ? const Color(0xFF4CAF50) : accentColor;

    return Container(
      height: 36,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: reached
            ? const Color(0xFF4CAF50).withOpacity(0.12)
            : chipColor.withOpacity(isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: reached
              ? const Color(0xFF4CAF50).withOpacity(0.3)
              : chipColor.withOpacity(0.28),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            reached ? Icons.check_circle_rounded : Icons.flag_rounded,
            size: 12,
            color: reached ? const Color(0xFF4CAF50) : chipColor,
          ),
          const SizedBox(width: 4),
          Text(
            '$milestone%',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: reached ? const Color(0xFF4CAF50) : chipColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccordionSection({
    required String title,
    required IconData icon,
    required bool isExpanded,
    required VoidCallback onTap,
    required WidgetBuilder childBuilder,
    Color accentColor = const Color(0xFF6B7280),
    required bool isDark,
    required Color cardColor,
    required Color textColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isExpanded
                ? accentColor.withOpacity(0.35)
                : (isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.08)),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            // Header
            InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            accentColor.withOpacity(0.2),
                            accentColor.withOpacity(0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: accentColor.withOpacity(0.3)),
                      ),
                      child: Icon(icon, color: accentColor, size: 18),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.06)
                              : Colors.black.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: isDark
                              ? Colors.white.withOpacity(0.7)
                              : Colors.black.withOpacity(0.5),
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Build content only when expanded to avoid unnecessary layout/paint work.
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: isExpanded
                  ? Padding(
                      padding: const EdgeInsets.only(
                        left: 18,
                        right: 18,
                        bottom: 18,
                        top: 4,
                      ),
                      child: childBuilder(context),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsContent(Habit habit, Color textColor, Color iconColor) {
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Column(
      children: [
        _buildDetailRow(
          icon: Icons.event_rounded,
          label: 'Created',
          value: dateFormat.format(habit.createdAt),
          textColor: textColor,
          iconColor: iconColor,
        ),
        if (habit.categoryId != null)
          Consumer(
            builder: (context, ref, _) {
              final categoryAsync = ref.watch(
                habitCategoryByIdProvider(habit.categoryId!),
              );
              return categoryAsync.when(
                data: (category) => _buildDetailRow(
                  icon: category?.icon ?? Icons.category_rounded,
                  label: 'Category',
                  value: category?.name ?? 'None',
                  textColor: textColor,
                  iconColor: iconColor,
                ),
                loading: () => _buildDetailRow(
                  icon: Icons.category_rounded,
                  label: 'Category',
                  value: 'Loading...',
                  textColor: textColor,
                  iconColor: iconColor,
                ),
                error: (_, __) => _buildDetailRow(
                  icon: Icons.category_rounded,
                  label: 'Category',
                  value: 'Error',
                  textColor: textColor,
                  iconColor: iconColor,
                ),
              );
            },
          ),
        if (habit.tags != null && habit.tags!.isNotEmpty)
          _buildDetailRow(
            icon: Icons.tag_rounded,
            label: 'Tags',
            value: habit.tags!.join(', '),
            textColor: textColor,
            iconColor: iconColor,
          ),
        if (habit.reminderEnabled &&
            habit.reminderDuration != null &&
            habit.hasSpecificTime)
          _buildDetailRow(
            icon: Icons.notifications_rounded,
            label: 'Reminder',
            value: habit.reminderDuration!,
            textColor: textColor,
            iconColor: iconColor,
          ),
        _buildDetailRow(
          icon: Icons.repeat_rounded,
          label: 'Frequency',
          value: habit.frequencyDescription,
          textColor: textColor,
          iconColor: iconColor,
        ),
        if (habit.hasRecurrence)
          _buildDetailRow(
            icon: Icons.schedule_rounded,
            label: 'Next Due',
            value: habit.nextDueDate != null
                ? dateFormat.format(habit.nextDueDate!)
                : 'N/A',
            textColor: textColor,
            iconColor: iconColor,
          ),
        if (habit.isQuitHabit) ...[
          _buildDetailRow(
            icon: Icons.block_rounded,
            label: 'Quitting',
            value:
                '${habit.quitActionName ?? 'Bad habit'} ${habit.quitSubstance ?? ''}',
            textColor: textColor,
            iconColor: iconColor,
          ),
          if (habit.dailyReward != null)
            _buildDetailRow(
              icon: Icons.savings_rounded,
              label: 'Daily Reward',
              value: '+${habit.dailyReward} points',
              textColor: textColor,
              iconColor: iconColor,
              valueColor: const Color(0xFF4CAF50),
            ),
        ],
      ],
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    required Color textColor,
    required Color iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Fixed width icon container for perfect alignment
          SizedBox(
            width: 24,
            child: Icon(icon, size: 18, color: iconColor.withOpacity(0.8)),
          ),
          const SizedBox(width: 16),

          // 2. Fixed width label for a clean "table" look
          SizedBox(
            width: 85,
            child: Text(
              label,
              style: TextStyle(
                color: iconColor.withOpacity(0.7),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // 3. Value takes remaining space, aligned to the left for better readability
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.left,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                color: valueColor ?? textColor.withOpacity(0.95),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtasksContent(
    Color textColor,
    Color subtextColor,
    bool isDark,
  ) {
    final subtasks = widget.habit.checklist!;
    final completed = subtasks.where((s) => s.isCompleted).length;
    final total = subtasks.length;
    final progress = total > 0 ? completed / total : 0.0;

    return Column(
      children: [
        // Progress Bar
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.05),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress == 1.0
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFCDAF56),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  color: progress == 1.0
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFCDAF56),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        // Subtask List
        ...subtasks.asMap().entries.map((entry) {
          final index = entry.key;
          final subtask = entry.value;
          return _buildSubtaskItem(
            subtask,
            index,
            textColor,
            subtextColor,
            isDark,
          );
        }),
      ],
    );
  }

  Widget _buildSubtaskItem(
    Subtask subtask,
    int index,
    Color textColor,
    Color subtextColor,
    bool isDark,
  ) {
    return InkWell(
      onTap: () => _toggleSubtask(index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: subtask.isCompleted
                    ? const Color(0xFFCDAF56)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: subtask.isCompleted
                      ? const Color(0xFFCDAF56)
                      : (isDark
                            ? Colors.white.withOpacity(0.4)
                            : Colors.black.withOpacity(0.2)),
                  width: 2,
                ),
              ),
              child: subtask.isCompleted
                  ? const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: Colors.black87,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                subtask.title,
                style: TextStyle(
                  color: subtask.isCompleted
                      ? subtextColor.withOpacity(0.6)
                      : textColor.withOpacity(0.9),
                  fontSize: 14,
                  decoration: subtask.isCompleted
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSnoozeHistoryContent(
    Habit habit,
    List<Map<String, dynamic>> history,
    DateTime? activeSnoozeUntil,
    Color textColor,
    Color subtextColor,
    Color iconColor,
    bool isDark,
  ) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('hh:mm a');

    if (history.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              activeSnoozeUntil != null
                  ? 'Habit is currently snoozed until ${timeFormat.format(activeSnoozeUntil)}'
                  : 'No snooze history for this day',
              style: TextStyle(color: subtextColor),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _showSnoozePickerAndSchedule(
                  source: 'habit_detail_section',
                ),
                icon: const Icon(Icons.add_alarm_rounded, size: 18),
                label: const Text('Add snooze'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF42A5F5),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final entries = history.reversed.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SNOOZE TIMELINE',
          style: TextStyle(
            color: subtextColor,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        ...entries.map((item) {
          final minutes = (item['minutes'] as num?)?.toInt();
          final untilStr = item['until'] as String?;
          final atStr = item['at'] as String?;

          DateTime? until;
          DateTime? at;
          try {
            if (untilStr != null) until = DateTime.parse(untilStr);
            if (atStr != null) at = DateTime.parse(atStr);
          } catch (_) {}

          final label = minutes == null
              ? 'Snoozed'
              : 'Snoozed for $minutes min';
          final untilLabel = until == null
              ? null
              : 'Until ${timeFormat.format(until)}';
          final atLabel = at == null
              ? null
              : '${dateFormat.format(at)} â€¢ ${timeFormat.format(at)}';

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.03)
                  : Colors.black.withOpacity(0.02),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.06)
                    : Colors.black.withOpacity(0.04),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF42A5F5).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.snooze_rounded,
                    color: Color(0xFF42A5F5),
                    size: 18,
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
                          color: textColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (untilLabel != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          untilLabel,
                          style: const TextStyle(
                            color: Color(0xFF42A5F5),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (atLabel != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          atLabel,
                          style: TextStyle(
                            color: subtextColor.withOpacity(0.7),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 2),
          child: TextButton.icon(
            onPressed: () =>
                _showSnoozePickerAndSchedule(source: 'habit_detail_timeline'),
            icon: const Icon(Icons.add_alarm_rounded, size: 18),
            label: const Text('Add snooze'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF42A5F5),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showSnoozePickerAndSchedule({required String source}) async {
    final habitSettings = ref.read(habitNotificationSettingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final minutes = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => HabitDetailSnoozeSheet(
        options: habitSettings.snoozeOptions,
        defaultOption: habitSettings.defaultSnoozeDuration,
        isDark: isDark,
      ),
    );
    if (minutes == null) return;

    // Persist as "manual snooze" + schedule a new one-off snooze notification.
    final now = DateTime.now();
    final snoozedUntil = now.add(Duration(minutes: minutes));

    // Append snooze history
    List<Map<String, dynamic>> history = [];
    final rawHistory = (widget.habit.snoozeHistory ?? '').trim();
    if (rawHistory.isNotEmpty) {
      try {
        history = List<Map<String, dynamic>>.from(jsonDecode(rawHistory));
      } catch (_) {
        history = [];
      }
    }
    final occurrenceDate =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';

    history.add({
      'at': now.toIso8601String(),
      'minutes': minutes,
      'until': snoozedUntil.toIso8601String(),
      'occurrenceDate': occurrenceDate,
      'source': source,
    });

    final updatedHabit = widget.habit.copyWith(
      snoozedUntil: snoozedUntil,
      snoozeHistory: jsonEncode(history),
    );

    // IMPORTANT: Use repository to persist without rescheduling all reminders.
    await HabitRepository().updateHabit(updatedHabit);
    ref.read(habitNotifierProvider.notifier).loadHabits();

    // Schedule snooze notification
    final settings = _mapHabitToNotificationSettings(habitSettings);
    await NotificationService().snoozeNotification(
      taskId: updatedHabit.id,
      title: updatedHabit.title,
      body: updatedHabit.description ?? 'Time for your habit!',
      payload:
          'habit|${updatedHabit.id}|manual_snooze|$minutes|minutes|snoozeCount:0',
      customDurationMinutes: minutes,
      settingsOverride: settings,
      notificationKindLabel: 'Habit',
      channelKeyOverride: habitSettings.defaultChannel,
    );

    // Close habit details (optional) and show feedback globally.
    if (mounted) Navigator.pop(context);
    final ctx = rootNavigatorKey.currentContext;
    if (ctx != null) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(
            'Snoozed until ${DateFormat('hh:mm a').format(snoozedUntil)}',
          ),
          backgroundColor: const Color(0xFF42A5F5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  NotificationSettings _mapHabitToNotificationSettings(
    HabitNotificationSettings h,
  ) {
    return NotificationSettings(
      notificationsEnabled: h.notificationsEnabled,
      soundEnabled: h.soundEnabled,
      vibrationEnabled: h.vibrationEnabled,
      ledEnabled: h.ledEnabled,
      taskRemindersEnabled: h.habitRemindersEnabled,
      urgentRemindersEnabled: h.urgentRemindersEnabled,
      silentRemindersEnabled: h.silentRemindersEnabled,
      defaultSound: h.defaultSound,
      taskRemindersSound: h.habitRemindersSound,
      urgentRemindersSound: h.urgentRemindersSound,
      defaultVibrationPattern: h.defaultVibrationPattern,
      defaultChannel: h.defaultChannel,
      notificationAudioStream: h.notificationAudioStream,
      alwaysUseAlarmForSpecialTasks: h.alwaysUseAlarmForSpecialHabits,
      specialTaskSound: h.specialHabitSound,
      specialTaskVibrationPattern: h.specialHabitVibrationPattern,
      specialTaskAlarmMode: h.specialHabitAlarmMode,
      allowUrgentDuringQuietHours: h.allowSpecialDuringQuietHours,
      quietHoursEnabled: h.quietHoursEnabled,
      quietHoursStart: h.quietHoursStart,
      quietHoursEnd: h.quietHoursEnd,
      quietHoursDays: h.quietHoursDays,
      showOnLockScreen: h.showOnLockScreen,
      wakeScreen: h.wakeScreen,
      persistentNotifications: h.persistentNotifications,
      groupNotifications: h.groupNotifications,
      notificationTimeout: h.notificationTimeout,
      defaultSnoozeDuration: h.defaultSnoozeDuration,
      snoozeOptions: h.snoozeOptions,
      maxSnoozeCount: h.maxSnoozeCount,
      smartSnooze: h.smartSnooze,
    );
  }

  Widget _buildNotesContent(Habit habit, Color textColor, Color subtextColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (habit.notes != null && habit.notes!.isNotEmpty) ...[
          Text(
            habit.notes!,
            style: TextStyle(
              color: textColor.withOpacity(0.85),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTemptationHistoryContent(Habit habit, bool isDark) {
    final logsAsync = ref.watch(habitTemptationLogsProvider(habit.id));

    return logsAsync.when(
      data: (logs) {
        final selectedDate = widget.selectedDate ?? DateTime.now();
        final selectedDateOnly = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
        );
        final todayOnly = DateTime(
          DateTime.now().year,
          DateTime.now().month,
          DateTime.now().day,
        );

        final logsForSelectedDay = logs.where((log) {
          final logDate = DateTime(
            log.occurredAt.year,
            log.occurredAt.month,
            log.occurredAt.day,
          );
          return logDate == selectedDateOnly;
        }).toList();

        final recentLogs = logsForSelectedDay.take(5).toList();
        final selectedDayCount = logsForSelectedDay.fold<int>(
          0,
          (sum, log) => sum + log.count,
        );
        final selectedDayLabel = selectedDateOnly == todayOnly
            ? 'Today'
            : DateFormat('MMM d').format(selectedDateOnly);

        if (logsForSelectedDay.isEmpty) {
          return Column(
            children: [
              Icon(
                Icons.sentiment_satisfied_alt_rounded,
                size: 40,
                color: const Color(0xFF4CAF50).withOpacity(0.7),
              ),
              const SizedBox(height: 12),
              Text(
                'No temptations logged on $selectedDayLabel',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Keep going strong! ðŸ’ª',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white54 : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _handleLogTemptation,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Log a temptation'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF9C27B0),
                  side: const BorderSide(color: Color(0xFF9C27B0)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats row
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9C27B0).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$selectedDayCount',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1E1E1E),
                          ),
                        ),
                        Text(
                          selectedDayLabel,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB347).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${logsForSelectedDay.length}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1E1E1E),
                          ),
                        ),
                        Text(
                          'Day Logs',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Recent logs
            Text(
              'Recent Temptations',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 10),
            ...recentLogs.map(
              (log) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.05)
                      : log.intensityColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: log.intensityColor.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: log.intensityColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        log.intensityIcon,
                        color: log.intensityColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            log.reasonText ?? 'Temptation logged',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E1E1E),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            children: [
                              Text(
                                '${log.formattedDate} â€¢ ${log.formattedTime}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.grey[600],
                                ),
                              ),
                              if (log.count > 1) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF9C27B0,
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Ã—${log.count}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF9C27B0),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),
            // Add button
            Center(
              child: TextButton.icon(
                onPressed: _handleLogTemptation,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Log Temptation'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF9C27B0),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const Text('Error loading temptation history'),
    );
  }

  Widget _buildStatsContent(
    Habit habit,
    Color textColor,
    Color subtextColor,
    Color iconColor,
  ) {
    return Column(
      children: [
        // Habit Score Card - Comprehensive scoring
        HabitScoreCard(habitId: habit.id, showBreakdown: true, compact: false),
        const SizedBox(height: 16),

        // Basic stats
        _buildDetailRow(
          icon: Icons.local_fire_department_rounded,
          label: 'Current Streak',
          value: '${habit.currentStreak} days',
          textColor: textColor,
          iconColor: iconColor,
          valueColor: habit.currentStreak > 0 ? const Color(0xFFFF6B6B) : null,
        ),
        _buildDetailRow(
          icon: Icons.whatshot_rounded,
          label: 'Best Streak',
          value: '${habit.bestStreak} days',
          textColor: textColor,
          iconColor: iconColor,
          valueColor: const Color(0xFFFFB347),
        ),
        _buildDetailRow(
          icon: Icons.check_circle_rounded,
          label: 'Total Completions',
          value: '${habit.totalCompletions}',
          textColor: textColor,
          iconColor: iconColor,
          valueColor: const Color(0xFF4CAF50),
        ),
        if (habit.isQuitHabit) ...[
          if (habit.currentSlipCount != null)
            _buildDetailRow(
              icon: Icons.trending_down_rounded,
              label: 'Total Slips',
              value: '${habit.currentSlipCount}',
              textColor: textColor,
              iconColor: iconColor,
              valueColor: Colors.red,
            ),
          if (habit.streakProtection != null)
            _buildDetailRow(
              icon: Icons.shield_rounded,
              label: 'Slip Shields',
              value: '${habit.streakProtection}',
              textColor: textColor,
              iconColor: iconColor,
              valueColor: const Color(0xFFCDAF56),
            ),
        ],
      ],
    );
  }

  Widget _buildActionButtons(
    bool isDark,
    Color bgColor,
    Color cardColor,
    bool isActioned,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.05),
          width: 1.5,
        ),
      ),
      child: !isActioned
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Done button (non-quit habits only)
                if (!widget.habit.isQuitHabit)
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: _ActionButton(
                          icon: Icons.check_rounded,
                          label: 'Done',
                          color: const Color(0xFF4CAF50), // Bright Task Green
                          onTap: _handleDone,
                          isPrimary: true,
                        ),
                      );
                    },
                  ),
                // Temptation Button (only for quit habits)
                if (widget.habit.isQuitHabit)
                  _ActionButton(
                    icon: Icons.psychology_rounded,
                    label: 'Tempted',
                    color: const Color(0xFF9C27B0), // Purple for temptation
                    onTap: _handleLogTemptation,
                  ),
                // Skip Button (or Slip for quit habits)
                _ActionButton(
                  icon: widget.habit.isQuitHabit
                      ? Icons.close_rounded
                      : Icons.skip_next_rounded,
                  label: widget.habit.isQuitHabit ? 'Slip' : 'Skip',
                  color: const Color(0xFFFF6B6B), // Bright Task Red
                  onTap: _handleSkip,
                ),
                if (!widget.habit.isQuitHabit &&
                    widget.habit.completionType == 'yesNo')
                  _ActionButton(
                    icon: Icons.schedule_rounded,
                    label: 'Postpone',
                    color: const Color(0xFFFFB347),
                    onTap: _handlePostpone,
                  ),
                // Stats Button
                _ActionButton(
                  icon: Icons.auto_graph_rounded,
                  label: 'Stats',
                  color: const Color(0xFFFFB347), // Bright Task Orange
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            HabitStatisticsScreen(habitId: widget.habit.id),
                      ),
                    );
                  },
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ActionButton(
                  icon: Icons.undo_rounded,
                  label: 'Undo',
                  color: const Color(0xFF64748B),
                  onTap: _handleUndo,
                  isPrimary: true,
                ),
                _ActionButton(
                  icon: Icons.auto_graph_rounded,
                  label: 'Stats',
                  color: const Color(0xFFFFB347), // Bright Task Orange
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            HabitStatisticsScreen(habitId: widget.habit.id),
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }

  Widget _buildSuccessOverlay(Habit habit) {
    return Positioned.fill(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50).withOpacity(0.4),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Stack(
            children: [
              // Confetti
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirection: math.pi / 2,
                  blastDirectionality: BlastDirectionality.explosive,
                  emissionFrequency: 0.05,
                  numberOfParticles: 20,
                  gravity: 0.3,
                  colors: const [
                    Color(0xFFCDAF56),
                    Colors.white,
                    Color(0xFFFFB347),
                    Color(0xFFFF6B6B),
                    Color(0xFF4CAF50),
                  ],
                ),
              ),
              // Content
              Center(
                child: SingleChildScrollView(
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Multi-layered animation stack
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            // 1. Radial Burst Particles
                            ...List.generate(8, (index) {
                              final angle = (index * 45) * (math.pi / 180);
                              return TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0.0, end: 1.0),
                                duration: Duration(
                                  milliseconds: 500 + (index * 50),
                                ),
                                builder: (context, value, child) {
                                  return Transform.translate(
                                    offset: Offset(
                                      math.cos(angle) * 80 * value,
                                      math.sin(angle) * 80 * value,
                                    ),
                                    child: Opacity(
                                      opacity: (1 - value).clamp(0.0, 1.0),
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            }),

                            // 2. Celebration Emoji
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: const Duration(milliseconds: 800),
                              curve: Curves.elasticOut,
                              builder: (context, value, child) {
                                return Transform.scale(
                                  scale: value,
                                  child: Text(
                                    'ðŸš€',
                                    style: TextStyle(
                                      fontSize: 64,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withOpacity(0.3),
                                          blurRadius: 20,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),

                            // 3. Lottie Celebration Layer
                            SizedBox(
                              width: 180,
                              height: 180,
                              child: Lottie.asset(
                                'assets/animations/Celebration.json',
                                repeat: false,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Completed! ðŸŽ‰',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 1.2,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.4),
                                    blurRadius: 15,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                            ),
                          ),
                          child: Text(
                            '+${habit.customYesPoints ?? 10} points earned',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildSkipOverlay(Habit habit) {
    final pointsText = _formatPoints(_skipPoints);
    final pointsMessage = pointsText.isEmpty ? 'No points change' : pointsText;
    return Positioned.fill(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B6B).withOpacity(0.4),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Center(
            child: SingleChildScrollView(
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Multi-layered animation stack
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // 1. Radial Burst Particles (Sad colors)
                        ...List.generate(8, (index) {
                          final angle = (index * 45) * (math.pi / 180);
                          return TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: Duration(
                              milliseconds: 600 + (index * 60),
                            ),
                            builder: (context, value, child) {
                              return Transform.translate(
                                offset: Offset(
                                  math.cos(angle) * 70 * value,
                                  math.sin(angle) * 70 * value,
                                ),
                                child: Opacity(
                                  opacity: (1 - value).clamp(0.0, 1.0),
                                  child: Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.8),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        }),

                        // 2. Sad Emoji
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 900),
                          curve: Curves.elasticOut,
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: Text(
                                'ðŸ˜”',
                                style: TextStyle(
                                  fontSize: 56,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 15,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                        // 3. Lottie Frown Layer
                        SizedBox(
                          width: 170,
                          height: 170,
                          child: Lottie.asset(
                            'assets/animations/big-frown.json',
                            repeat: false,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Skipped',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1.2,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      child: Text(
                        pointsMessage,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPostponeOverlay(Habit habit) {
    final pointsText = _formatPoints(_postponePoints);
    final pointsMessage = pointsText.isEmpty ? 'No points change' : pointsText;

    return Positioned.fill(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFFB347).withOpacity(0.35),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Center(
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'â°',
                    style: TextStyle(
                      fontSize: 56,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Postponed',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1.2,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Text(
                      pointsMessage,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF3D4251),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Habit?',
          style: Theme.of(
            dialogContext,
          ).textTheme.titleLarge?.copyWith(color: Colors.white),
        ),
        content: Text(
          'This action cannot be undone.',
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pop();
              await ref
                  .read(habitNotifierProvider.notifier)
                  .deleteHabit(widget.habit.id);
              widget.onHabitUpdated?.call();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
