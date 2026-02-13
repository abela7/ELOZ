import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:confetti/confetti.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/models/reminder.dart';
import '../../../../core/providers/notification_settings_provider.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../data/models/task.dart';
import '../../../../data/models/subtask.dart';
import '../../../../data/models/task_type.dart';
import '../../../../data/models/task_reason.dart';
import '../../../../data/repositories/task_repository.dart';
import '../../../../routing/app_router.dart';
import '../providers/task_providers.dart';
import '../providers/task_type_providers.dart';
import '../providers/category_providers.dart';
import '../providers/task_reason_providers.dart';
import '../screens/edit_task_screen.dart';
import '../screens/routine_statistics_screen.dart';

/// Task Detail Modal Bottom Sheet
/// Modern design with accordion sections and beautiful animations
class TaskDetailModal {
  /// Shows the task detail modal bottom sheet
  static void show(
    BuildContext context, {
    Task? task,
    String? title,
    String? description,
    DateTime? dueDate,
    String? priority,
    Color? priorityColor,
    String? category,
    List<Map<String, dynamic>>? subtasks,
    int points = 5,
    VoidCallback? onTaskUpdated,
  }) {
    final taskObj = task ?? (title != null && dueDate != null
        ? Task(
            title: title,
            description: description,
            dueDate: dueDate,
            priority: priority ?? 'Medium',
            categoryId: category,
          )
        : null);

    if (taskObj == null) {
      throw ArgumentError('Either task or title+dueDate must be provided');
    }

    // Use netPoints for display (includes cumulative postpone penalty)
    // Tasks without a taskTypeId have NO points (simple tasks)
    // Only tasks with a taskTypeId earn points from that type's reward
    int displayPoints = taskObj.pointsEarned;
    // For pending tasks with postpone penalties, show the potential net points
    // This helps user understand the impact of postponing
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: false, // We handle drag ourselves with DraggableScrollableSheet
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
            return _TaskDetailContent(
              task: taskObj,
              displayPoints: displayPoints,
              onTaskUpdated: onTaskUpdated,
              scrollController: scrollController,
            );
          },
        );
      },
    );
  }

  static Color getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return const Color(0xFFFF6B6B);
      case 'medium':
        return const Color(0xFFFFB347);
      case 'low':
        return const Color(0xFF66BB6A);
      default:
        return Colors.grey;
    }
  }
}

class _TaskDetailContent extends ConsumerStatefulWidget {
  final Task task;
  final int displayPoints;
  final VoidCallback? onTaskUpdated;
  final ScrollController? scrollController;

  const _TaskDetailContent({
    required this.task,
    required this.displayPoints,
    this.onTaskUpdated,
    this.scrollController,
  });

  @override
  ConsumerState<_TaskDetailContent> createState() => _TaskDetailContentState();
}

class _TaskDetailContentState extends ConsumerState<_TaskDetailContent>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _effectController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late ConfettiController _confettiController;
  bool _showSuccess = false;
  bool _showNotDone = false;
  
  // Points to display during animation (calculated before animation starts)
  int _animationPoints = 0;
  int _animationPenalty = 0;
  
  // Accordion expansion states
  bool _detailsExpanded = false;
  bool _counterExpanded = false;
  bool _subtasksExpanded = true;
  bool _notesExpanded = false;
  bool _recurrenceExpanded = false;
  bool _routineHistoryExpanded = false;
  bool _postponeHistoryExpanded = false;
  bool _snoozeHistoryExpanded = false;
  
  // Counter snapshot (calculated only when opened)
  String? _counterTextCache;
  bool _counterIsOverdue = false;

  Future<void> _showSnoozePickerAndSchedule({required String source}) async {
    final settings = ref.read(notificationSettingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final minutes = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TaskDetailSnoozeSheet(
        options: settings.snoozeOptions,
        defaultOption: settings.defaultSnoozeDuration,
        isDark: isDark,
      ),
    );
    if (minutes == null) return;

    // Persist as "manual snooze" + schedule a new one-off snooze notification.
    final now = DateTime.now();
    final snoozedUntil = now.add(Duration(minutes: minutes));

    // Append snooze history
    List<Map<String, dynamic>> history = [];
    final rawHistory = (widget.task.snoozeHistory ?? '').trim();
    if (rawHistory.isNotEmpty) {
      try {
        history = List<Map<String, dynamic>>.from(jsonDecode(rawHistory));
      } catch (_) {
        history = [];
      }
    }
    history.add({
      'at': now.toIso8601String(),
      'minutes': minutes,
      'until': snoozedUntil.toIso8601String(),
      'source': source,
    });

    final updatedTask = widget.task.copyWith(
      snoozedUntil: snoozedUntil,
      snoozeHistory: jsonEncode(history),
    );

    // IMPORTANT: Use repository to persist without rescheduling all reminders.
    await TaskRepository().updateTask(updatedTask);
    ref.read(taskNotifierProvider.notifier).loadTasks();

    await NotificationService().snoozeNotification(
      taskId: updatedTask.id,
      title: updatedTask.title,
      body: updatedTask.description ?? '',
      payload: 'task|${updatedTask.id}|manual_snooze|$minutes|minutes|snoozeCount:0',
      customDurationMinutes: minutes,
      priority: updatedTask.priority,
    );

    // Close task details (optional) and show feedback globally.
    if (mounted) Navigator.pop(context);
    final ctx = rootNavigatorKey.currentContext;
    if (ctx != null) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text('Snoozed until ${DateFormat('hh:mm a').format(snoozedUntil)}'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: const Color(0xFF42A5F5),
        ),
      );
    }
  }

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
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _effectController, curve: Curves.easeIn),
    );

  }

  @override
  void dispose() {
    _pulseController.dispose();
    _effectController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _toggleCounter(Task task) {
    final shouldExpand = !_counterExpanded;
    if (!shouldExpand) {
      setState(() => _counterExpanded = false);
      return;
    }

    final now = DateTime.now();
    final dueDateTime = _getTaskDueDateTime(task);
    final isOverdue = (task.status == 'pending' || task.status == 'postponed') && dueDateTime.isBefore(now);
    final counterText = _formatTaskCounter(task, referenceTime: now);

    setState(() {
      _counterExpanded = true;
      _counterIsOverdue = isOverdue;
      _counterTextCache = counterText;
    });
  }

  void _handleDone() async {
    HapticFeedback.mediumImpact();
    
    // GUARD: Prevent double-completion
    if (widget.task.status == 'completed') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_rounded, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Text('Task is already completed'),
            ],
          ),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    
    if (widget.task.subtasks != null && widget.task.subtasks!.isNotEmpty) {
      final allCompleted = widget.task.subtasks!.every((s) => s.isCompleted);
      if (!allCompleted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please complete all subtasks first'),
            backgroundColor: const Color(0xFFFFB347),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        setState(() => _subtasksExpanded = true);
        return;
      }
    }
    
    final container = ProviderScope.containerOf(context);
    final notifier = container.read(taskNotifierProvider.notifier);
    
    // Calculate points BEFORE showing animation so we can display correct value
    int points = 0;
    if (widget.task.taskTypeId != null) {
      final taskTypeAsync = await container.read(taskTypeByIdProvider(widget.task.taskTypeId!).future);
      if (taskTypeAsync != null) {
        points = taskTypeAsync.rewardOnDone;
      }
    }
    
    // Set animation points and show animation
    setState(() {
      _animationPoints = points;
      _showSuccess = true;
    });
    _effectController.forward();
    _confettiController.play();
    
    await Future.delayed(const Duration(milliseconds: 1500));
    
    if (!mounted) return;
    
    final updatedTask = widget.task.copyWith(
      status: 'completed',
      completedAt: DateTime.now(),
      pointsEarned: points,
    );
    
    await notifier.updateTask(updatedTask);
    
    await Future.delayed(const Duration(milliseconds: 800));
    
    if (!mounted) return;
    Navigator.of(context).pop();
    
    // Build completion message - show points only if task has a task type
    final hasPoints = points > 0;
    final message = hasPoints 
        ? 'Well done! +$points points 🎉' 
        : 'Well done! 🎉';
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.celebration, color: Colors.white),
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
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    widget.onTaskUpdated?.call();
    
    // If this is a routine task, prompt to plan the next occurrence
    if (widget.task.isRoutineTask && mounted) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        _showPlanNextRoutineModal(context, updatedTask, widget.onTaskUpdated);
      }
    }
  }

  void _handleUndo() async {
    HapticFeedback.mediumImpact();
    
    final container = ProviderScope.containerOf(context);
    final notifier = container.read(taskNotifierProvider.notifier);
    
    // Get undo info for smart messaging
    final undoInfo = notifier.getUndoInfo(widget.task.id);
    final undoType = undoInfo['undoType'] as String;
    final willDeleteTasks = undoInfo['willDeleteTasks'] as int;
    
    // Use the robust undo system based on task status and type
    switch (widget.task.status) {
      case 'completed':
        await notifier.undoTaskComplete(widget.task.id);
        break;
      case 'not_done':
        await notifier.undoTaskSkip(widget.task.id);
        break;
      case 'postponed':
        // Legacy: archived task from old system
        await notifier.undoTask(widget.task.id);
        break;
      default:
        // Smart undo based on task state
        await notifier.undoTask(widget.task.id);
    }
    
    if (!mounted) return;
    Navigator.of(context).pop();
    
    // Build smart message based on what was undone
    String message = 'Task status reset to Pending';
    final hasPenalty = widget.task.cumulativePostponePenalty < 0;
    final penaltyInfo = hasPenalty ? ' (Postpone penalty: ${widget.task.cumulativePostponePenalty} pts)' : '';
    
    if (undoType == 'complete' && willDeleteTasks > 0) {
      message = 'Task reset. $willDeleteTasks auto-generated occurrence(s) removed.$penaltyInfo';
    } else if (undoType == 'complete') {
      message = 'Completion undone. Points reverted.$penaltyInfo';
    } else if (undoType == 'skip') {
      message = 'Skip removed. Penalty reverted.$penaltyInfo';
    } else if (undoType == 'postpone') {
      // New postpone system - task moved back to previous date
      message = 'Postpone undone. Task restored to previous date. Penalty restored.';
    } else if (undoType == 'postpone_legacy_new' || undoType == 'postpone_legacy') {
      message = 'Postpone undone. Original task restored.';
    } else if (widget.task.isRoutineTask) {
      message = 'Routine reset to planned.$penaltyInfo';
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.undo_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF64748B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    widget.onTaskUpdated?.call();
  }

  void _handleNotDone() async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _NotDoneModal(task: widget.task),
    );

    if (reason != null && mounted) {
      HapticFeedback.mediumImpact();
      
      final container = ProviderScope.containerOf(context);
      final notifier = container.read(taskNotifierProvider.notifier);
      
      // Calculate actual penalty from TaskType (not hardcoded -5)
      int penalty = 0;
      if (widget.task.taskTypeId != null) {
        final taskTypeAsync = await container.read(taskTypeByIdProvider(widget.task.taskTypeId!).future);
        if (taskTypeAsync != null) {
          penalty = taskTypeAsync.penaltyNotDone; // This should be negative
          // Ensure it's negative
          if (penalty > 0) penalty = -penalty;
        }
      }
      
      // Set animation penalty and show animation
      setState(() {
        _animationPenalty = penalty;
        _showNotDone = true;
        _showSuccess = false;
      });
      _effectController.forward();

      await Future.delayed(const Duration(milliseconds: 1500));

      if (!mounted) return;

      final updatedTask = widget.task.copyWith(
        status: 'not_done',
        notDoneReason: reason,
        pointsEarned: penalty,
      );

      await notifier.updateTask(updatedTask);

      await Future.delayed(const Duration(milliseconds: 800));

      if (!mounted) return;
      Navigator.of(context).pop();
      
      final penaltyText = penalty != 0 ? ' ($penalty points)' : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.cancel_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Task marked as Not Done$penaltyText',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFFF6B6B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      widget.onTaskUpdated?.call();
    }
  }

  Future<void> _toggleSubtask(int index) async {
    // LOGICAL LOCK: Prevent subtask changes on completed/not_done tasks
    if (widget.task.status == 'completed' || widget.task.status == 'not_done') {
      HapticFeedback.heavyImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.lock_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Subtasks are locked after task is completed'),
                ),
              ],
            ),
            backgroundColor: Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    
    HapticFeedback.lightImpact();
    if (widget.task.subtasks == null || index >= widget.task.subtasks!.length) {
      return;
    }

    // --- ENHANCED REACTIVITY: Optimistic UI Update ---
    // 1. Update local state immediately for zero lag
    setState(() {
      widget.task.subtasks![index].isCompleted = !widget.task.subtasks![index].isCompleted;
    });

    // 2. Fire-and-forget DB update in background
    widget.task.save();

    // 3. Trigger external refresh
    widget.onTaskUpdated?.call();
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final priorityColor = TaskDetailModal.getPriorityColor(task.priority);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSpecial = task.isSpecial;
    const accentGold = Color(0xFFCDAF56);
    
    // Premium special-task tint (match app dark palette; keep gold as accent)
    final bgColor = isSpecial 
        ? (isDark ? const Color(0xFF1B1F26) : const Color(0xFFFCFAF5))
        : (isDark ? const Color(0xFF1E2228) : const Color(0xFFF8F9FA));
    final cardColor = isSpecial
        ? (isDark ? const Color(0xFF232831) : const Color(0xFFFFFDF8))
        : (isDark ? const Color(0xFF252A31) : Colors.white);
    final textColor = isDark ? Colors.white : const Color(0xFF1A1C1E);
    final subtextColor = isDark ? Colors.white.withOpacity(0.7) : const Color(0xFF44474E);
    final iconColor = isDark ? Colors.white.withOpacity(0.5) : const Color(0xFF74777F);
    final dividerColor = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05);
    
    final taskTypeAsync = task.taskTypeId != null 
        ? ref.watch(taskTypeByIdProvider(task.taskTypeId!))
        : const AsyncValue<TaskType?>.data(null);

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (didPop) return;
      },
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity! > 500) {
            _handleDone();
          } else if (details.primaryVelocity! < -500) {
            _showPostponeModal(context, task, widget.onTaskUpdated);
          }
        },
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: isSpecial 
                ? Border.all(color: accentGold.withOpacity(0.3), width: 1.5)
                : null,
            boxShadow: !isDark ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ] : null,
          ),
          child: Stack(
            children: [
              // Main Content - using scrollController from DraggableScrollableSheet
              SingleChildScrollView(
                controller: widget.scrollController,
                physics: const ClampingScrollPhysics(),
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 160,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag Handle - Pull down to close
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    
                    // Close button row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: Icon(Icons.close_rounded, color: iconColor),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),

                    // Header with Icon and Title
                    _buildHeader(task, priorityColor, isDark, cardColor, textColor, subtextColor),

                        const SizedBox(height: 16),

                  // Quick Info Pills (always visible)
                  _buildQuickInfo(task, isDark, taskTypeAsync),

                  const SizedBox(height: 20),

                  // Accordion Sections
                  _buildAccordionSection(
                    title: 'Details',
                    icon: Icons.info_outline_rounded,
                    isExpanded: _detailsExpanded,
                    onTap: () => setState(() => _detailsExpanded = !_detailsExpanded),
                    child: _buildDetailsContent(task, textColor, iconColor),
                    isDark: isDark,
                    cardColor: cardColor,
                    textColor: textColor,
                  ),

                  if (!task.isRoutineTask && task.counterEnabled)
                    _buildAccordionSection(
                      title: 'Counter',
                      icon: Icons.timer_outlined,
                      isExpanded: _counterExpanded,
                      onTap: () => _toggleCounter(task),
                      child: _counterExpanded
                          ? _buildCounterContent(task, isDark, textColor)
                          : const SizedBox.shrink(),
                      accentColor: task.isOverdue ? const Color(0xFFFF6B6B) : const Color(0xFFCDAF56),
                      isDark: isDark,
                      cardColor: cardColor,
                      textColor: textColor,
                    ),

                  if (task.subtasks != null && task.subtasks!.isNotEmpty)
                    _buildAccordionSection(
                      title: 'Subtasks (${task.subtasks!.where((s) => s.isCompleted).length}/${task.subtasks!.length})',
                      icon: Icons.checklist_rounded,
                      isExpanded: _subtasksExpanded,
                      onTap: () => setState(() => _subtasksExpanded = !_subtasksExpanded),
                      child: _buildSubtasksContent(textColor, subtextColor, isDark),
                      accentColor: const Color(0xFFCDAF56),
                      isDark: isDark,
                      cardColor: cardColor,
                      textColor: textColor,
                    ),

                  if (task.notes != null || task.reflection != null)
                    _buildAccordionSection(
                      title: 'Notes & Reflection',
                      icon: Icons.note_alt_outlined,
                      isExpanded: _notesExpanded,
                      onTap: () => setState(() => _notesExpanded = !_notesExpanded),
                      child: _buildNotesContent(task, textColor, subtextColor),
                      isDark: isDark,
                      cardColor: cardColor,
                      textColor: textColor,
                    ),

                  // Recurrence Accordion (if task has recurrence)
                  if (task.hasRecurrence && task.recurrence != null)
                    _buildAccordionSection(
                      title: 'Recurrence',
                      icon: Icons.repeat_rounded,
                      isExpanded: _recurrenceExpanded,
                      onTap: () => setState(() => _recurrenceExpanded = !_recurrenceExpanded),
                      child: _buildRecurrenceContent(task, textColor, subtextColor, iconColor, isDark),
                      accentColor: const Color(0xFFCDAF56),
                      isDark: isDark,
                      cardColor: cardColor,
                      textColor: textColor,
                    ),

                  // Routine History Accordion (if task is a routine)
                  if (task.isRoutineTask)
                    _buildAccordionSection(
                      title: 'Routine History',
                      icon: Icons.history_rounded,
                      isExpanded: _routineHistoryExpanded,
                      onTap: () => setState(() => _routineHistoryExpanded = !_routineHistoryExpanded),
                      child: _buildRoutineHistoryContent(task, textColor, subtextColor, iconColor, isDark),
                      accentColor: const Color(0xFFCDAF56),
                      isDark: isDark,
                      cardColor: cardColor,
                      textColor: textColor,
                    ),

                  // Postpone History Accordion (if task has been postponed)
                  if (task.postponeCount > 0 || (task.postponeHistory != null && task.postponeHistory!.isNotEmpty))
                    _buildAccordionSection(
                      title: 'Postpone History (${task.postponeCount}x)',
                      icon: Icons.schedule_send_rounded,
                      isExpanded: _postponeHistoryExpanded,
                      onTap: () => setState(() => _postponeHistoryExpanded = !_postponeHistoryExpanded),
                      child: _buildPostponeHistoryContent(task, textColor, subtextColor, iconColor, isDark),
                      accentColor: const Color(0xFFFFB347),
                      isDark: isDark,
                      cardColor: cardColor,
                      textColor: textColor,
                    ),

                  // Snooze history: only show if there *is* history or the task is currently snoozed
                  if (task.isSnoozed || task.snoozeHistoryEntries.isNotEmpty)
                    _buildAccordionSection(
                      title: 'Snooze (${task.snoozeHistoryEntries.length}x)',
                      icon: Icons.snooze_rounded,
                      isExpanded: _snoozeHistoryExpanded,
                      onTap: () => setState(() => _snoozeHistoryExpanded = !_snoozeHistoryExpanded),
                      child: _buildSnoozeHistoryContent(task, textColor, subtextColor, iconColor, isDark),
                      accentColor: const Color(0xFF42A5F5),
                      isDark: isDark,
                      cardColor: cardColor,
                      textColor: textColor,
                    ),

                  const SizedBox(height: 24),

                  // Action Buttons (Moved from floating stack to bottom of list)
                  _buildActionButtons(isDark, bgColor, cardColor),

                  const SizedBox(height: 40),
                ],
              ),
            ),

            // Success Overlay
            if (_showSuccess)
              _buildSuccessOverlay(),

            // Not Done Overlay
            if (_showNotDone)
              _buildNotDoneOverlay(),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildHeader(Task task, Color priorityColor, bool isDark, Color cardColor, Color textColor, Color subtextColor) {
    final isSpecial = task.isSpecial;
    const accentGold = Color(0xFFCDAF56);
    final effectiveAccent = isSpecial ? accentGold : priorityColor;
    
    // For special tasks, use a premium design
    if (isSpecial) {
      return _buildSpecialTaskHeader(task, isDark, textColor, subtextColor);
    }
    
    // Regular task header
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
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
                task.icon ?? Icons.task_alt_rounded,
                size: 140,
                color: effectiveAccent,
              ),
            ),
          ),
          
          // Main Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Icon + Badges + Menu
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main Icon
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: effectiveAccent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        task.icon ?? Icons.task_alt_rounded,
                        color: effectiveAccent,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Status Badges
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (task.status == 'completed')
                            _buildStatusBadge('Completed', Icons.check_circle_rounded, const Color(0xFF4CAF50)),
                          if (task.status == 'not_done')
                            _buildStatusBadge('Not Done', Icons.cancel_rounded, const Color(0xFFFF6B6B)),
                          if (task.status == 'postponed')
                            _buildStatusBadge('Postponed', Icons.schedule_rounded, const Color(0xFFFFB347)),
                          if (task.isSnoozed)
                            _buildStatusBadge('Snoozed', Icons.snooze_rounded, const Color(0xFF42A5F5)),
                        ],
                      ),
                    ),
                    _buildMenuButton(),
                  ],
                ),
                const SizedBox(height: 16),
                // Title
                Text(
                  task.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    height: 1.2,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                // Due Date/Time
                _buildDueDateChip(task),
                // Description
                if (task.description != null && task.description!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    task.description!,
                    style: TextStyle(
                      color: subtextColor,
                      fontSize: 14,
                      height: 1.5,
                    ),
                    maxLines: 3,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatusBadge(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDueDateChip(Task task) {
    final color = task.isOverdue ? const Color(0xFFFF6B6B) : const Color(0xFFCDAF56);
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.schedule_rounded, size: 15, color: color),
              const SizedBox(width: 7),
              Text(
                _formatDueDate(task),
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
        if (task.isSnoozed && task.snoozedUntil != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF42A5F5).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF42A5F5).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.snooze_rounded, size: 15, color: Color(0xFF42A5F5)),
                const SizedBox(width: 7),
                Text(
                  'Until ${DateFormat('hh:mm a').format(task.snoozedUntil!)}',
                  style: const TextStyle(
                    color: Color(0xFF42A5F5),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
  
  /// Premium Special Task Header - Elegant & Luxurious Design
  Widget _buildSpecialTaskHeader(Task task, bool isDark, Color textColor, Color subtextColor) {
    const goldPrimary = Color(0xFFCDAF56);
    const goldLight = Color(0xFFE8D48A);
    const goldDark = Color(0xFFB89B3E);
    
    // Premium color palette (dark uses app's charcoal; gold stays as accent)
    final cardGradientColors = isDark
        ? [const Color(0xFF252B35), const Color(0xFF1F252E), const Color(0xFF1A1F27)]
        : [const Color(0xFFFFFEF9), const Color(0xFFFFF9EC), const Color(0xFFFFFEF9)];
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Stack(
        children: [
          // Main card
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: cardGradientColors,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                width: 1.5,
                color: goldPrimary.withOpacity(isDark ? 0.45 : 0.4),
              ),
            ),
            child: Stack(
              children: [
                // Background star with gradient
                Positioned(
                  right: -25,
                  bottom: -25,
                  child: ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        goldPrimary.withOpacity(isDark ? 0.15 : 0.1),
                        goldLight.withOpacity(isDark ? 0.08 : 0.05),
                      ],
                    ).createShader(bounds),
                    child: const Icon(
                      Icons.star_rounded,
                      size: 150,
                      color: Colors.white,
                    ),
                  ),
                ),
                
                // Main content
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Premium Icon Container
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  goldPrimary.withOpacity(0.25),
                                  goldDark.withOpacity(0.12),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: goldPrimary.withOpacity(0.35),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: goldPrimary.withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Icon(
                              task.icon ?? Icons.task_alt_rounded,
                              color: goldPrimary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          
                          // Premium Special Badge
                          Expanded(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                // Elegant Special Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        goldPrimary.withOpacity(0.3),
                                        goldDark.withOpacity(0.15),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: goldPrimary.withOpacity(0.5),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: goldPrimary.withOpacity(0.15),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ShaderMask(
                                        shaderCallback: (bounds) => const LinearGradient(
                                          colors: [goldLight, goldPrimary],
                                        ).createShader(bounds),
                                        child: const Icon(
                                          Icons.star_rounded,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'SPECIAL',
                                        style: TextStyle(
                                          color: goldPrimary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Status badge if applicable
                                if (task.status == 'completed')
                                  _buildStatusBadge('Completed', Icons.check_circle_rounded, const Color(0xFF4CAF50)),
                                if (task.status == 'not_done')
                                  _buildStatusBadge('Not Done', Icons.cancel_rounded, const Color(0xFFFF6B6B)),
                                if (task.status == 'postponed')
                                  _buildStatusBadge('Postponed', Icons.schedule_rounded, const Color(0xFFFFB347)),
                              ],
                            ),
                          ),
                          
                          // Menu button
                          _buildMenuButton(),
                        ],
                      ),
                      
                      const SizedBox(height: 18),
                      
                      // Title with elegant styling
                      Text(
                        task.title,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF1A1814),
                          height: 1.2,
                          letterSpacing: -0.5,
                        ),
                      ),
                      
                      const SizedBox(height: 14),
                      
                      // Premium due date chip
                      _buildSpecialDueDateChip(task, isDark),
                      
                      // Description
                      if (task.description != null && task.description!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          task.description!,
                          style: TextStyle(
                            color: subtextColor,
                            fontSize: 14,
                            height: 1.5,
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSpecialDueDateChip(Task task, bool isDark) {
    const goldPrimary = Color(0xFFCDAF56);
    const goldLight = Color(0xFFE8D48A);
    final isOverdue = task.isOverdue;
    final chipColor = isOverdue ? const Color(0xFFFF6B6B) : goldPrimary;
    
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            gradient: isOverdue ? null : LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                goldPrimary.withOpacity(0.18),
                goldLight.withOpacity(0.08),
              ],
            ),
            color: isOverdue ? const Color(0xFFFF6B6B).withOpacity(0.12) : null,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: chipColor.withOpacity(0.4),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 15,
                color: chipColor,
              ),
              const SizedBox(width: 8),
              Text(
                _formatDueDate(task),
                style: TextStyle(
                  color: chipColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
        if (task.isSnoozed && task.snoozedUntil != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF42A5F5).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF42A5F5).withOpacity(0.4),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.snooze_rounded, size: 15, color: Color(0xFF42A5F5)),
                const SizedBox(width: 8),
                Text(
                  'Until ${DateFormat('hh:mm a').format(task.snoozedUntil!)}',
                  style: const TextStyle(
                    color: Color(0xFF42A5F5),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMenuButton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canSnooze = widget.task.status == 'pending' && widget.task.isOverdue;
    return PopupMenuButton<String>(
      icon: Container(
        padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
                              border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08),
                                    ),
                                  ),
                                  child: Icon(
          Icons.more_horiz_rounded,
          color: isDark ? Colors.white.withOpacity(0.9) : Colors.black.withOpacity(0.7),
          size: 20,
        ),
      ),
      color: isDark ? const Color(0xFF252A31) : Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08)),
      ),
      elevation: 8,
      onSelected: (value) async {
        if (value == 'edit') {
          Navigator.of(context).pop();
          final result = await context.pushNamed('edit-task', extra: widget.task);
          if (result == true) {
            widget.onTaskUpdated?.call();
          }
        } else if (value == 'snooze') {
          if (!canSnooze) return;
          await _showSnoozePickerAndSchedule(source: 'task_menu');
        } else if (value == 'delete') {
          _showDeleteConfirmation(context);
        } else if (value == 'toggle_special') {
          await _toggleSpecial(context);
        }
      },
      itemBuilder: (context) => [
        if (canSnooze)
          PopupMenuItem(
            value: 'snooze',
            child: Row(
              children: [
                const Icon(Icons.snooze_rounded, color: Color(0xFF42A5F5), size: 18),
                const SizedBox(width: 12),
                Text(
                  'Snooze…',
                  style: TextStyle(
                    color: isDark ? Colors.white.withOpacity(0.9) : Colors.black.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        PopupMenuItem(
          value: 'toggle_special',
          child: Row(
            children: [
              Icon(
                widget.task.isSpecial ? Icons.star_rounded : Icons.star_outline_rounded, 
                color: const Color(0xFFCDAF56), 
                size: 18
              ),
              const SizedBox(width: 12),
              Text(
                widget.task.isSpecial ? 'Unstar Task' : 'Star Task', 
                style: TextStyle(color: isDark ? Colors.white.withOpacity(0.9) : Colors.black.withOpacity(0.8), fontSize: 14)
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'edit',
          child: Row(
                                  children: [
              Icon(Icons.edit_rounded, color: isDark ? Colors.white.withOpacity(0.9) : Colors.black.withOpacity(0.7), size: 18),
              const SizedBox(width: 12),
              Text('Edit', style: TextStyle(color: isDark ? Colors.white.withOpacity(0.9) : Colors.black.withOpacity(0.8), fontSize: 14)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
                                    child: Row(
                                      children: [
              Icon(Icons.delete_rounded, color: Colors.red.withOpacity(0.9), size: 18),
              const SizedBox(width: 12),
              Text('Delete', style: TextStyle(color: Colors.red.withOpacity(0.9), fontSize: 14)),
                                      ],
                                    ),
                                  ),
                                ],
    );
  }

  Widget _buildQuickInfo(Task task, bool isDark, AsyncValue<TaskType?> taskTypeAsync) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          // Priority
          _buildInfoChip(
            icon: Icons.flag_rounded,
            label: task.priority,
            color: TaskDetailModal.getPriorityColor(task.priority),
            small: true,
            isDark: isDark,
          ),
          // Category
          if (task.categoryId != null)
            Consumer(
              builder: (context, ref, _) {
                final categoryAsync = ref.watch(categoryByIdProvider(task.categoryId!));
                return categoryAsync.when(
                  data: (category) => category != null
                      ? _buildInfoChip(
                          icon: category.icon ?? Icons.folder_rounded,
                          label: category.name,
                          color: Color(category.colorValue),
                          small: true,
                          isDark: isDark,
                        )
                      : const SizedBox.shrink(),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                );
              },
            ),
          // Points - Simplified display showing only net points
          ...taskTypeAsync.when(
            data: (taskType) {
              final bool isPending = task.status == 'pending' || task.status == 'overdue';
              final int baseReward = isPending 
                  ? (taskType?.rewardOnDone ?? 0) 
                  : (task.pointsEarned > 0 ? task.pointsEarned : (taskType?.rewardOnDone ?? 0));
              
              final int penalty = task.cumulativePostponePenalty;
              final int netPoints = baseReward + penalty;
              
              if (baseReward > 0 || penalty != 0) {
                return [
                  _buildInfoChip(
                    icon: netPoints >= 0 ? Icons.stars_rounded : Icons.trending_down_rounded,
                    label: '${netPoints >= 0 ? '+' : ''}$netPoints net',
                    color: netPoints >= 0 ? const Color(0xFFCDAF56) : const Color(0xFFFF6B6B),
                    small: true,
                    isDark: isDark,
                  ),
                ];
              }
              return [];
            },
            loading: () => [],
            error: (_, __) => [],
          ),
          // Postpone Count Badge (if task has been postponed)
          if (task.postponeCount > 0)
            _buildInfoChip(
              icon: Icons.replay_rounded,
              label: '${task.postponeCount}x Postponed',
              color: const Color(0xFFFFB347),
              small: true,
              isDark: isDark,
            ),
          // Status Badge for postponed tasks
          if (task.status == 'postponed')
            _buildInfoChip(
              icon: Icons.schedule_send_rounded,
              label: 'Postponed',
              color: const Color(0xFFFFB347),
              small: true,
              isDark: isDark,
            ),
          // Routine Badge
          if (task.isRoutineTask)
            _buildInfoChip(
              icon: Icons.loop_rounded,
              label: 'Routine',
              color: const Color(0xFFCDAF56),
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
            ? [
                color.withOpacity(0.15),
                color.withOpacity(0.05),
              ]
            : [
                color.withOpacity(0.12),
                color.withOpacity(0.04),
              ],
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
          Icon(icon, size: small ? 12 : 14, color: isDark ? color : color.withOpacity(0.9)),
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

  Widget _buildAccordionSection({
    required String title,
    required IconData icon,
    required bool isExpanded,
    required VoidCallback onTap,
    required Widget child,
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
            color: isExpanded ? accentColor.withOpacity(0.35) : (isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.08)),
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
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
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
                        border: Border.all(
                          color: accentColor.withOpacity(0.3),
                        ),
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
                          color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(8),
                        ),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                          color: isDark ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.5),
                          size: 20,
                        ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            // Content
                AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
                  secondChild: Padding(
                padding: const EdgeInsets.only(left: 18, right: 18, bottom: 18, top: 4),
                child: child,
              ),
              crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
              sizeCurve: Curves.easeInOut,
                                        ),
                                      ],
                                    ),
                                  ),
    );
  }

  Widget _buildDetailsContent(Task task, Color textColor, Color iconColor) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('hh:mm a');
    
    return Column(
      children: [
                        _buildDetailRow(
                          icon: Icons.calendar_today_rounded,
                          label: 'Due Date',
          value: dateFormat.format(task.dueDate),
          textColor: textColor,
          iconColor: iconColor,
                        ),
        if (task.dueTime != null)
                          _buildDetailRow(
                            icon: Icons.access_time_rounded,
                            label: 'Due Time',
            value: timeFormat.format(DateTime(2000, 1, 1, task.dueTime!.hour, task.dueTime!.minute)),
            textColor: textColor,
            iconColor: iconColor,
          ),
        if (!task.isRoutineTask && task.counterEnabled)
          _buildDetailRow(
            icon: Icons.timer_outlined,
            label: task.status == 'completed'
                ? 'Completed'
                : (task.status == 'not_done' ? 'Not Done' : 'Time Left'),
            value: _counterTextCache ?? 'Open Counter',
            valueColor: _counterTextCache == null
                ? null
                : (task.status == 'completed'
                    ? const Color(0xFF4CAF50)
                    : (task.status == 'not_done'
                        ? const Color(0xFFFF6B6B)
                        : (_counterIsOverdue ? const Color(0xFFFF6B6B) : null))),
            textColor: textColor,
            iconColor: iconColor,
          ),
        _buildDetailRow(
          icon: Icons.event_rounded,
          label: 'Created',
          value: dateFormat.format(task.createdAt),
          textColor: textColor,
          iconColor: iconColor,
        ),
        if (task.taskTypeId != null)
          Consumer(
            builder: (context, ref, _) {
              final typeAsync = ref.watch(taskTypeByIdProvider(task.taskTypeId!));
              return typeAsync.when(
                data: (type) => type != null
                    ? _buildDetailRow(
                        icon: type.iconCode != null
                            ? IconData(type.iconCode!, fontFamily: 'MaterialIcons')
                            : Icons.layers_rounded,
                        label: 'Task Level',
                        value: type.name,
                        textColor: textColor,
                        iconColor: type.colorValue != null ? Color(type.colorValue!) : iconColor,
                      )
                    : const SizedBox.shrink(),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              );
            },
          ),
        if (task.tags != null && task.tags!.isNotEmpty)
          _buildDetailRow(
            icon: Icons.tag_rounded,
            label: 'Tags',
            value: task.tags!.join(', '),
            textColor: textColor,
            iconColor: iconColor,
          ),
        if ((task.remindersJson ?? '').trim().isNotEmpty)
          _buildDetailRow(
            icon: Icons.notifications_rounded,
            label: 'Reminders',
            value: () {
              final raw = (task.remindersJson ?? '').trim();
              if (raw.isEmpty) return 'No reminders';
              if (raw.startsWith('[')) {
                try {
                  final reminders = Reminder.decodeList(raw);
                  if (reminders.isEmpty) return 'No reminders';
                  return reminders.map((r) => r.getDescription()).join(', ');
                } catch (_) {
                  return 'Invalid reminders';
                }
              }
              // Legacy single reminder string
              return raw;
            }(),
            textColor: textColor,
            iconColor: iconColor,
          ),
        if (task.hasRecurrence)
                          _buildDetailRow(
                            icon: Icons.repeat_rounded,
                            label: 'Repeats',
            value: task.recurrence!.type.toString().split('.').last.toUpperCase(),
            textColor: textColor,
            iconColor: iconColor,
          ),
        if (task.status == 'completed' && task.completedAt != null)
          _buildDetailRow(
            icon: Icons.check_circle_rounded,
            label: 'Completed',
            value: dateFormat.format(task.completedAt!),
            valueColor: const Color(0xFF4CAF50),
            textColor: textColor,
            iconColor: iconColor,
          ),
        // Postpone information for postponed tasks
        if (task.status == 'postponed') ...[
          _buildDetailRow(
            icon: Icons.schedule_send_rounded,
            label: 'Postponed To',
            value: task.postponedTo != null ? dateFormat.format(task.postponedTo!) : 'Unknown',
            valueColor: const Color(0xFFFFB347),
            textColor: textColor,
            iconColor: iconColor,
          ),
          if (task.postponeReason != null && task.postponeReason!.isNotEmpty)
            _buildDetailRow(
              icon: Icons.info_outline_rounded,
              label: 'Reason',
              value: task.postponeReason!,
              valueColor: const Color(0xFFFFB347),
              textColor: textColor,
              iconColor: iconColor,
            ),
          if (task.postponedAt != null)
            _buildDetailRow(
              icon: Icons.history_rounded,
              label: 'Postponed On',
              value: dateFormat.format(task.postponedAt!),
              textColor: textColor,
              iconColor: iconColor,
            ),
        ],
        // For tasks that were created from postponement (have parentTaskId)
        if (task.postponeCount > 0) ...[
          _buildDetailRow(
            icon: Icons.replay_rounded,
            label: 'Times Postponed',
            value: '${task.postponeCount}x',
            valueColor: const Color(0xFFFFB347),
            textColor: textColor,
            iconColor: iconColor,
          ),
          if (task.originalDueDate != null)
            _buildDetailRow(
              icon: Icons.event_busy_rounded,
              label: 'Originally Due',
              value: dateFormat.format(task.originalDueDate!),
              valueColor: const Color(0xFFFF6B6B),
              textColor: textColor,
              iconColor: iconColor,
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
          // Fixed width icon container
          SizedBox(
            width: 24,
            child: Icon(icon, size: 18, color: iconColor.withOpacity(0.8)),
          ),
          const SizedBox(width: 16),
          
          // Fixed width label
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
          
          // Value takes remaining space
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

  DateTime _getTaskDueDateTime(Task task) {
    if (task.postponedTo != null) {
      return task.postponedTo!;
    }
    final hour = task.dueTime?.hour ?? 23;
    final minute = task.dueTime?.minute ?? 59;
    return DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day, hour, minute);
  }

  Map<String, int> _calculateTimeBreakdown(DateTime from, DateTime to) {
    DateTime start = from;
    DateTime end = to;
    if (end.isBefore(start)) {
      final temp = start;
      start = end;
      end = temp;
    }

    int years = end.year - start.year;
    int months = end.month - start.month;
    int days = end.day - start.day;
    int hours = end.hour - start.hour;
    int minutes = end.minute - start.minute;

    if (minutes < 0) {
      minutes += 60;
      hours -= 1;
    }
    if (hours < 0) {
      hours += 24;
      days -= 1;
    }
    if (days < 0) {
      final lastDayOfPrevMonth = DateTime(end.year, end.month, 0).day;
      days += lastDayOfPrevMonth;
      months -= 1;
    }
    if (months < 0) {
      months += 12;
      years -= 1;
    }

    return {
      'years': years,
      'months': months,
      'days': days,
      'hours': hours,
      'minutes': minutes,
    };
  }

  String _formatCounterUnit(int value, String singular, {String? plural}) {
    if (value == 1) return '$value $singular';
    return '$value ${plural ?? '${singular}s'}';
  }

  String _formatStatusDateLabel(String prefix, DateTime dateTime) {
    final dateLabel = DateFormat('MMM dd, yyyy').format(dateTime);
    final timeLabel = DateFormat('hh:mm a').format(dateTime);
    return '$prefix $dateLabel · $timeLabel';
  }

  String _formatCounterParts(String prefix, List<String> parts) {
    return '$prefix ${parts.join(' ')}';
  }

  String _formatTaskCounter(Task task, {DateTime? referenceTime}) {
    final now = referenceTime ?? DateTime.now();
    final dueDateTime = _getTaskDueDateTime(task);
    if (task.status == 'completed') {
      final completedAt = task.completedAt ?? dueDateTime;
      return _formatStatusDateLabel('Completed on', completedAt);
    }
    if (task.status == 'not_done') {
      return _formatStatusDateLabel('Was due', dueDateTime);
    }
    final isOverdue = dueDateTime.isBefore(now);
    final breakdown = _calculateTimeBreakdown(now, dueDateTime);

    final years = breakdown['years'] ?? 0;
    final months = breakdown['months'] ?? 0;
    final days = breakdown['days'] ?? 0;
    final hours = breakdown['hours'] ?? 0;
    final minutes = breakdown['minutes'] ?? 0;

    if (years == 0 && months == 0 && days == 0 && hours == 0 && minutes == 0) {
      return isOverdue ? 'Overdue' : 'Now';
    }

    final prefix = isOverdue ? 'Overdue by' : 'In';
    if (years > 0) {
      final parts = [_formatCounterUnit(years, 'year')];
      if (months > 0) parts.add(_formatCounterUnit(months, 'month'));
      return _formatCounterParts(prefix, parts);
    }
    if (months > 0) {
      final parts = [_formatCounterUnit(months, 'month')];
      if (days > 0) parts.add(_formatCounterUnit(days, 'day'));
      return _formatCounterParts(prefix, parts);
    }
    if (days > 0) {
      final parts = [_formatCounterUnit(days, 'day')];
      if (hours > 0) parts.add(_formatCounterUnit(hours, 'hr', plural: 'hrs'));
      return _formatCounterParts(prefix, parts);
    }
    if (hours > 0) {
      final parts = [_formatCounterUnit(hours, 'hr', plural: 'hrs')];
      if (minutes > 0) parts.add(_formatCounterUnit(minutes, 'min', plural: 'mins'));
      return _formatCounterParts(prefix, parts);
    }
    return '$prefix ${_formatCounterUnit(minutes, 'min', plural: 'mins')}';
  }

  Widget _buildCounterContent(Task task, bool isDark, Color textColor) {
    final dueDateTime = _getTaskDueDateTime(task);
    final isCompleted = task.status == 'completed';
    final isNotDone = task.status == 'not_done';
    final isPostponed = task.status == 'postponed';
    final isOverdue = _counterIsOverdue;
    final counterText = isCompleted
        ? 'Completed'
        : (isNotDone ? 'Not done' : (_counterTextCache ?? 'Open Counter'));
    final dateLabel = DateFormat('MMM dd, yyyy').format(dueDateTime);
    final showTime = task.dueTime != null || task.postponedTo != null;
    final timeLabel = showTime ? DateFormat('hh:mm a').format(dueDateTime) : 'All day';
    final accent = task.isSpecial
        ? const Color(0xFFCDAF56)
        : isOverdue
            ? const Color(0xFFFF6B6B)
            : TaskDetailModal.getPriorityColor(task.priority);
    final infoText = isCompleted
        ? _formatStatusDateLabel('Completed on', task.completedAt ?? dueDateTime)
        : (isNotDone
            ? 'Was due $dateLabel · $timeLabel'
            : (isPostponed ? 'New due $dateLabel · $timeLabel' : '$dateLabel · $timeLabel'));
    final infoIcon = isCompleted
        ? Icons.check_circle_rounded
        : (isNotDone ? Icons.cancel_rounded : Icons.event_rounded);
    final infoColor = isCompleted
        ? const Color(0xFF4CAF50)
        : (isNotDone ? const Color(0xFFFF6B6B) : accent.withOpacity(0.8));

    final gradient = isDark
        ? [const Color(0xFF1C222B), const Color(0xFF232A34)]
        : [const Color(0xFFFFFEF9), const Color(0xFFF7F2E8)];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accent.withOpacity(isDark ? 0.45 : 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(isDark ? 0.18 : 0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accent.withOpacity(isDark ? 0.18 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.timer_outlined,
                  color: accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  counterText,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isCompleted
                ? 'Task completed'
                : (isNotDone ? 'Marked as not done' : (isOverdue ? 'Time overdue' : 'Time left until due')),
            style: TextStyle(
              color: textColor.withOpacity(0.65),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(infoIcon, size: 14, color: infoColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  infoText,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor.withOpacity(0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubtasksContent(Color textColor, Color subtextColor, bool isDark) {
    final subtasks = widget.task.subtasks!;
    final progress = widget.task.subtaskProgress;
    
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
                    backgroundColor: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress == 1.0 ? const Color(0xFF4CAF50) : const Color(0xFFCDAF56),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  color: progress == 1.0 ? const Color(0xFF4CAF50) : const Color(0xFFCDAF56),
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
          return _buildSubtaskItem(subtask, index, textColor, subtextColor, isDark);
              }),
            ],
    );
  }

  Widget _buildSubtaskItem(Subtask subtask, int index, Color textColor, Color subtextColor, bool isDark) {
    // Check if subtasks are locked (task is completed or not_done)
    final isLocked = widget.task.status == 'completed' || widget.task.status == 'not_done';
    
    return InkWell(
      onTap: () => _toggleSubtask(index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            // Checkbox with lock indicator for completed tasks
            Stack(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: subtask.isCompleted
                        ? (isLocked ? Colors.grey : const Color(0xFFCDAF56))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: subtask.isCompleted
                          ? (isLocked ? Colors.grey : const Color(0xFFCDAF56))
                          : (isDark ? Colors.white.withOpacity(0.4) : Colors.black.withOpacity(0.2)),
                      width: 2,
                    ),
                  ),
                  child: subtask.isCompleted
                      ? Icon(Icons.check_rounded, size: 16, color: isLocked ? Colors.white70 : Colors.black87)
                      : null,
                ),
                // Lock badge for locked tasks
                if (isLocked)
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2D3139) : Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock_rounded,
                        size: 10,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
              ],
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
                  decoration: subtask.isCompleted ? TextDecoration.lineThrough : null,
                ),
                    ),
                  ),
              ],
            ),
      ),
    );
  }

  Widget _buildNotesContent(Task task, Color textColor, Color subtextColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (task.notes != null && task.notes!.isNotEmpty) ...[
          Text(
            'Notes',
            style: TextStyle(
              color: subtextColor.withOpacity(0.8),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            task.notes!,
            style: TextStyle(
              color: textColor.withOpacity(0.85),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
        if (task.notes != null && task.reflection != null)
          const SizedBox(height: 16),
        if (task.reflection != null && task.reflection!.isNotEmpty) ...[
          Text(
            'Reflection',
            style: TextStyle(
              color: subtextColor.withOpacity(0.8),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.2)),
            ),
            width: double.infinity,
            child: _buildReflectionRichText(task.reflection!, textColor),
          ),
        ],
      ],
    );
  }

  Widget _buildReflectionRichText(String text, Color textColor) {
    final spans = <InlineSpan>[];
    final regex = RegExp(r'\[([^\]]+)\]');
    int lastMatchEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: TextStyle(
            color: textColor.withOpacity(0.85),
            fontSize: 14,
            height: 1.5,
            fontStyle: FontStyle.italic,
          ),
        ));
      }

      final taskName = match.group(1)!;
      spans.add(TextSpan(
        text: taskName,
        style: const TextStyle(
          color: Colors.blue,
          fontSize: 14,
          height: 1.5,
          fontWeight: FontWeight.bold,
          fontStyle: FontStyle.normal, // Keep name non-italic for contrast
        ),
      ));

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: TextStyle(
          color: textColor.withOpacity(0.85),
          fontSize: 14,
          height: 1.5,
          fontStyle: FontStyle.italic,
        ),
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  Widget _buildRecurrenceContent(Task task, Color textColor, Color subtextColor, Color iconColor, bool isDark) {
    final recurrence = task.recurrence!;
    final dateFormat = DateFormat('MMM dd, yyyy');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Frequency
        _buildDetailRow(
          icon: Icons.repeat_rounded,
          label: 'Frequency',
          value: recurrence.getDescription(),
          valueColor: const Color(0xFFCDAF56),
          textColor: textColor,
          iconColor: iconColor,
        ),
        // Start Date
        _buildDetailRow(
          icon: Icons.play_arrow_rounded,
          label: 'Start Date',
          value: dateFormat.format(recurrence.startDate),
          textColor: textColor,
          iconColor: iconColor,
        ),
        
        // Dynamic: Recurrence Count & Next Due Date
        if (task.recurrenceGroupId != null)
          Consumer(
            builder: (context, ref, _) {
              final groupAsync = ref.watch(recurrenceGroupProvider(task.recurrenceGroupId!));
              
              return groupAsync.when(
                data: (tasks) {
                  // Find current task and next task
                  // Sort by due date to be safe
                  tasks.sort((a, b) => a.dueDate.compareTo(b.dueDate));
                  
                  final currentIndex = tasks.indexWhere((t) => t.id == task.id);
                  final nextTask = (currentIndex != -1 && currentIndex + 1 < tasks.length) 
                      ? tasks[currentIndex + 1] 
                      : null;
                  
                  // Calculate count (1-based)
                  final currentCount = currentIndex != -1 ? currentIndex + 1 : task.recurrenceIndex + 1;
                  
                  return Column(
                    children: [
                      _buildDetailRow(
                        icon: Icons.numbers_rounded,
                        label: 'Occurrence',
                        value: '#$currentCount',
                        textColor: textColor,
                        iconColor: iconColor,
                      ),
                      if (nextTask != null)
                        _buildDetailRow(
                          icon: Icons.event_repeat_rounded,
                          label: 'Next Due',
                          value: dateFormat.format(nextTask.dueDate),
                          textColor: textColor,
                          iconColor: iconColor,
                        ),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              );
            },
          ),
          
        // End Condition
        if (recurrence.endCondition == 'on_date' && recurrence.endDate != null)
          _buildDetailRow(
            icon: Icons.stop_rounded,
            label: 'End Date',
            value: dateFormat.format(recurrence.endDate!),
            textColor: textColor,
            iconColor: iconColor,
          ),
        if (recurrence.endCondition == 'after_occurrences' && recurrence.occurrences != null)
          _buildDetailRow(
            icon: Icons.format_list_numbered_rounded,
            label: 'Occurrences',
            value: '${recurrence.occurrences} times',
            textColor: textColor,
            iconColor: iconColor,
          ),
        if (recurrence.endCondition == 'never')
          _buildDetailRow(
            icon: Icons.all_inclusive_rounded,
            label: 'End Date',
            value: 'Never',
            textColor: textColor,
            iconColor: iconColor,
          ),
        // Days of Week (for weekly)
        if (recurrence.type == 'weekly' && recurrence.daysOfWeek != null && recurrence.daysOfWeek!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Days of Week',
            style: TextStyle(
              color: subtextColor.withOpacity(0.8),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                .asMap()
                .entries
                .map((entry) {
              final isSelected = recurrence.daysOfWeek!.contains(entry.key);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFCDAF56).withOpacity(0.15)
                      : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03)),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFFCDAF56).withOpacity(0.5)
                        : (isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
                  ),
                ),
                child: Text(
                  entry.value,
                  style: TextStyle(
                    color: isSelected
                        ? const Color(0xFFCDAF56)
                        : (isDark ? Colors.white.withOpacity(0.6) : Colors.black.withOpacity(0.5)),
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
        // Skip Weekends
        if (recurrence.skipWeekends)
          _buildDetailRow(
            icon: Icons.weekend_rounded,
            label: 'Skip Weekends',
            value: 'Yes',
            textColor: textColor,
            iconColor: iconColor,
          ),
        // Recurrence Index (position in series) - just show occurrence number
        if (task.recurrenceGroupId != null) ...[
          const SizedBox(height: 12),
          _buildDetailRow(
            icon: Icons.repeat_rounded,
            label: 'Occurrence',
            value: '#${task.recurrenceIndex + 1}',
            textColor: textColor,
            iconColor: const Color(0xFFCDAF56),
            valueColor: const Color(0xFFCDAF56),
          ),
        ],
      ],
    );
  }

  Widget _buildSnoozeHistoryContent(Task task, Color textColor, Color subtextColor, Color iconColor, bool isDark) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('hh:mm a');

    final history = task.snoozeHistoryEntries;
    if (history.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task.isSnoozed && task.snoozedUntil != null
                  ? 'Task is currently snoozed until ${timeFormat.format(task.snoozedUntil!)}'
                  : 'No snooze history available',
              style: TextStyle(color: subtextColor),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _showSnoozePickerAndSchedule(source: 'task_detail_section'),
                icon: const Icon(Icons.add_alarm_rounded, size: 18),
                label: const Text('Add snooze'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF42A5F5),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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

          final label = minutes == null ? 'Snoozed' : 'Snoozed for $minutes min';
          final untilLabel = until == null ? null : 'Until ${timeFormat.format(until)}';
          final atLabel = at == null ? null : '${dateFormat.format(at)} • ${timeFormat.format(at)}';

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
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
                  child: const Icon(Icons.snooze_rounded, color: Color(0xFF42A5F5), size: 18),
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
            onPressed: () => _showSnoozePickerAndSchedule(source: 'task_detail_section'),
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

  Widget _buildPostponeHistoryContent(Task task, Color textColor, Color subtextColor, Color iconColor, bool isDark) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('hh:mm a');
    
    // Parse postpone history
    List<Map<String, dynamic>> history = [];
    if (task.postponeHistory != null && task.postponeHistory!.isNotEmpty) {
      try {
        history = List<Map<String, dynamic>>.from(jsonDecode(task.postponeHistory!));
      } catch (_) {
        history = [];
      }
    }
    
    if (history.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No postpone history available',
          style: TextStyle(color: subtextColor),
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Original Date Card
        if (task.originalDueDate != null)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark 
                  ? const Color(0xFFCDAF56).withOpacity(0.1) 
                  : const Color(0xFFCDAF56).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFCDAF56).withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCDAF56).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.event_note_rounded,
                    color: Color(0xFFCDAF56),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Original Due Date',
                        style: TextStyle(
                          color: subtextColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateFormat.format(task.originalDueDate!),
                        style: TextStyle(
                          color: const Color(0xFFCDAF56),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        
        // Timeline
        Text(
          'POSTPONE TIMELINE',
          style: TextStyle(
            color: subtextColor,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        
        // Timeline entries
        ...history.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isLast = index == history.length - 1;
          
          final fromDateStr = item['from'] as String?;
          final toDateStr = item['to'] as String?;
          final reason = item['reason'] as String? ?? 'No reason';
          final postponedAtStr = item['postponedAt'] as String?;
          final penaltyApplied = (item['penaltyApplied'] as num?)?.toInt() ?? -5;
          
          DateTime? fromDate;
          DateTime? toDate;
          DateTime? postponedAt;
          
          try {
            if (fromDateStr != null) fromDate = DateTime.parse(fromDateStr);
            if (toDateStr != null) toDate = DateTime.parse(toDateStr);
            if (postponedAtStr != null) postponedAt = DateTime.parse(postponedAtStr);
          } catch (_) {}
          
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline indicator
              Column(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isLast 
                          ? const Color(0xFFFFB347) 
                          : const Color(0xFFFFB347).withOpacity(0.3),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFFB347),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: isLast ? Colors.black : const Color(0xFFFFB347),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 60,
                      color: const Color(0xFFFFB347).withOpacity(0.3),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Container(
                  margin: EdgeInsets.only(bottom: isLast ? 0 : 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark 
                        ? Colors.white.withOpacity(0.03) 
                        : Colors.black.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark 
                          ? Colors.white.withOpacity(0.06) 
                          : Colors.black.withOpacity(0.04),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (fromDate != null) ...[
                            Text(
                              dateFormat.format(fromDate),
                              style: TextStyle(
                                color: subtextColor,
                                fontSize: 12,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 14,
                              color: const Color(0xFFFFB347),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (toDate != null)
                            Text(
                              dateFormat.format(toDate),
                              style: TextStyle(
                                color: textColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              reason,
                              style: TextStyle(
                                color: subtextColor,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                          // Show penalty applied for this postpone
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6B6B).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$penaltyApplied pts',
                              style: const TextStyle(
                                color: Color(0xFFFF6B6B),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (postponedAt != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Postponed on ${dateFormat.format(postponedAt)} at ${timeFormat.format(postponedAt)}',
                          style: TextStyle(
                            color: subtextColor.withOpacity(0.6),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
        
        // Points Breakdown Section
        if (task.cumulativePostponePenalty < 0 || task.status == 'completed' || task.status == 'not_done') ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark 
                  ? Colors.white.withOpacity(0.03) 
                  : Colors.black.withOpacity(0.02),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark 
                    ? Colors.white.withOpacity(0.08) 
                    : Colors.black.withOpacity(0.06),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section Header
                Text(
                  'POINTS BREAKDOWN',
                  style: TextStyle(
                    color: subtextColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Postpone Penalty Row (if any)
                if (task.cumulativePostponePenalty < 0)
                  _buildPointsRow(
                    icon: Icons.replay_rounded,
                    label: 'Postpone Penalty (${task.postponeCount}x)',
                    points: task.cumulativePostponePenalty,
                    color: const Color(0xFFFF6B6B),
                    textColor: textColor,
                    subtextColor: subtextColor,
                  ),
                
                // Final Action Row (if completed or not done)
                if (task.status == 'completed')
                  _buildPointsRow(
                    icon: Icons.check_circle_rounded,
                    label: 'Completed',
                    points: task.pointsEarned,
                    color: Colors.green,
                    textColor: textColor,
                    subtextColor: subtextColor,
                  ),
                if (task.status == 'not_done')
                  _buildPointsRow(
                    icon: Icons.cancel_rounded,
                    label: 'Not Done',
                    points: task.pointsEarned,
                    color: const Color(0xFFFF6B6B),
                    textColor: textColor,
                    subtextColor: subtextColor,
                  ),
                
                // Divider before total
                if ((task.cumulativePostponePenalty < 0) && (task.status == 'completed' || task.status == 'not_done')) ...[
                  const SizedBox(height: 8),
                  Divider(color: subtextColor.withOpacity(0.2)),
                  const SizedBox(height: 8),
                  
                  // Total Row
                  _buildPointsRow(
                    icon: Icons.summarize_rounded,
                    label: 'NET TOTAL',
                    points: task.netPoints,
                    color: task.netPoints >= 0 ? Colors.green : const Color(0xFFFF6B6B),
                    textColor: textColor,
                    subtextColor: subtextColor,
                    isBold: true,
                  ),
                ],
                
                // For pending tasks with penalties, show what they could earn
                if (task.status == 'pending' && task.cumulativePostponePenalty < 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCDAF56).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: const Color(0xFFCDAF56),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Complete to earn +${widget.displayPoints} pts (Net: ${widget.displayPoints + task.cumulativePostponePenalty})',
                            style: TextStyle(
                              color: subtextColor,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        
        // Current status
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark 
                ? Colors.green.withOpacity(0.1) 
                : Colors.green.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.green.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.event_available_rounded,
                  color: Colors.green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Due Date',
                      style: TextStyle(
                        color: subtextColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateFormat.format(task.dueDate),
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              // Undo last postpone button
              if (task.postponeCount > 0)
                IconButton(
                  onPressed: () => _handleUndoLastPostpone(),
                  icon: Icon(
                    Icons.undo_rounded,
                    color: Colors.green,
                  ),
                  tooltip: 'Undo last postpone',
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Helper widget for building a points row in the breakdown
  Widget _buildPointsRow({
    required IconData icon,
    required String label,
    required int points,
    required Color color,
    required Color textColor,
    required Color subtextColor,
    bool isBold = false,
  }) {
    final pointsText = points >= 0 ? '+$points' : '$points';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: isBold ? textColor : subtextColor,
                  fontSize: isBold ? 14 : 13,
                  fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$pointsText pts',
              style: TextStyle(
                color: color,
                fontSize: isBold ? 14 : 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleUndoLastPostpone() async {
    HapticFeedback.mediumImpact();
    
    final container = ProviderScope.containerOf(context);
    final notifier = container.read(taskNotifierProvider.notifier);
    
    // Capture the current penalty before undo to show what was restored
    final penaltyBefore = widget.task.cumulativePostponePenalty;
    final postponeCountBefore = widget.task.postponeCount;
    
    final success = await notifier.undoLastPostpone(widget.task.id);
    
    if (!mounted) return;
    
    if (success) {
      // Calculate penalty that was restored (difference)
      // Since we pop the last postpone, the penalty increases (becomes less negative)
      final penaltyRestored = penaltyBefore - (penaltyBefore - (penaltyBefore ~/ postponeCountBefore));
      final newPenalty = penaltyBefore - penaltyRestored;
      
      String message = 'Postpone undone. Task restored to previous date.';
      if (postponeCountBefore == 1) {
        message = 'Postpone undone. All penalties cleared!';
      } else {
        message = 'Postpone ${postponeCountBefore} undone. Penalty now: $newPenalty pts';
      }
      
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.undo_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: const Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      widget.onTaskUpdated?.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not undo postpone'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Widget _buildRoutineHistoryContent(Task task, Color textColor, Color subtextColor, Color iconColor, bool isDark) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final routineGroupId = task.effectiveRoutineGroupId;
    
    return Consumer(
      builder: (context, ref, _) {
        final routineStatsAsync = ref.watch(routineStatsProvider(routineGroupId));
        final routineGroupAsync = ref.watch(routineGroupProvider(routineGroupId));
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats Section
            routineStatsAsync.when(
              data: (stats) {
                final completed = stats['completed'] as int;
                final lastCompletedAt = stats['lastCompletedAt'] as DateTime?;
                final nextScheduledDateTime = stats['nextScheduledDateTime'] as DateTime?;
                final nextTask = stats['nextTask'] as Task?;
                final avgInterval = stats['averageInterval'] as double;
                final hasTime = stats['hasTime'] as bool? ?? false;
                
                return Column(
                  children: [
                    // Countdown Card (if next scheduled)
                    // FIXED: Use nextTask for consistent progress calculation
                    if (nextScheduledDateTime != null && nextTask != null)
                      _buildRoutineCountdownCard(
                        context,
                        nextTask,
                        nextScheduledDateTime,
                        hasTime,
                        isDark,
                      ),
                    
                    // Days Since Last Card (if no next but has last)
                    if (nextScheduledDateTime == null && lastCompletedAt != null)
                      _buildDaysSinceCard(context, lastCompletedAt, isDark),
                    
                    const SizedBox(height: 10),
                    
                    // Summary Stats Row - Compact
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCDAF56).withOpacity(isDark ? 0.08 : 0.04),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFCDAF56).withOpacity(0.15),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildRoutineStat('Completed', completed.toString(), isDark),
                          Container(
                            width: 1,
                            height: 24,
                            color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.06),
                          ),
                          _buildRoutineStat(
                            'Avg Interval', 
                            avgInterval > 0 
                                ? _formatIntervalCompact(avgInterval) 
                                : '-',
                            isDark,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Text('Error loading stats'),
            ),
            
            const SizedBox(height: 12),
            
            // History Timeline
            Text(
              'History',
              style: TextStyle(
                color: subtextColor.withOpacity(0.7),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            
            routineGroupAsync.when(
              data: (tasks) {
                if (tasks.isEmpty) {
                  return Text(
                    'No history yet',
                    style: TextStyle(color: subtextColor, fontSize: 13),
                  );
                }
                
                // Show up to 5 most recent (sorted newest first in provider)
                final historyTasks = tasks.take(5).toList();
                
                return Column(
                  children: historyTasks.asMap().entries.map((entry) {
                    final index = entry.key;
                    final historyTask = entry.value;
                    final isLast = index == historyTasks.length - 1;
                    
                    return _buildHistoryItem(historyTask, dateFormat, isDark, isLast);
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Text('Error loading history'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRoutineStat(String label, String value, bool isDark) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFFCDAF56),
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white.withOpacity(0.5) : Colors.black.withOpacity(0.45),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Countdown Card - Shows time remaining until next routine
  /// Supports hours/minutes when < 24 hours, and proper date calculations
  /// 
  /// IMPORTANT: Uses the nextTask's routineProgress getter for consistent
  /// progress calculation across all UI components.
  Widget _buildRoutineCountdownCard(
    BuildContext context,
    Task nextTask,
    DateTime nextScheduledDateTime,
    bool hasTime,
    bool isDark,
  ) {
    final now = DateTime.now();
    
    // Calculate exact time difference
    final difference = nextScheduledDateTime.difference(now);
    final totalMinutes = difference.inMinutes;
    final totalHours = difference.inHours;
    final totalDays = difference.inDays;
    
    // Check if overdue
    final isOverdue = difference.isNegative;
    final absDifference = isOverdue ? now.difference(nextScheduledDateTime) : difference;
    
    // FIXED: Use the Task's routineProgress getter for consistent progress
    // This ensures the same progress is shown everywhere:
    // - Routines page
    // - Task detail modal
    // - Statistics/Timeline page  
    // - Countdown popup
    final progress = nextTask.routineProgress.clamp(0.0, 1.0);
    
    // Check if this task was postponed
    final isPostponed = nextTask.postponeCount > 0;
    
    // Determine urgency color and label
    Color progressColor;
    String urgencyLabel;
    IconData urgencyIcon;
    
    if (isOverdue) {
      progressColor = const Color(0xFFFF6B6B);
      urgencyLabel = 'Overdue!';
      urgencyIcon = Icons.warning_rounded;
    } else if (totalMinutes <= 0) {
      progressColor = const Color(0xFFFF6B6B);
      urgencyLabel = "It's time!";
      urgencyIcon = Icons.alarm_on_rounded;
    } else if (totalHours < 1) {
      progressColor = const Color(0xFFFF6B6B);
      urgencyLabel = 'Less than an hour';
      urgencyIcon = Icons.alarm_rounded;
    } else if (totalHours < 24) {
      progressColor = const Color(0xFFFFB347);
      urgencyLabel = isPostponed ? 'Rescheduled - Today' : 'Today';
      urgencyIcon = isPostponed ? Icons.update_rounded : Icons.notifications_active_rounded;
    } else if (totalDays <= 3) {
      progressColor = const Color(0xFFFFB347);
      urgencyLabel = isPostponed ? 'Rescheduled - Coming soon' : 'Coming up soon';
      urgencyIcon = isPostponed ? Icons.update_rounded : Icons.notifications_active_rounded;
    } else if (totalDays <= 7) {
      progressColor = const Color(0xFFCDAF56);
      urgencyLabel = isPostponed ? 'Rescheduled - This week' : 'This week';
      urgencyIcon = isPostponed ? Icons.update_rounded : Icons.schedule_rounded;
    } else {
      progressColor = const Color(0xFFCDAF56);
      urgencyLabel = isPostponed ? 'Rescheduled' : 'Scheduled';
      urgencyIcon = isPostponed ? Icons.update_rounded : Icons.event_rounded;
    }
    
    // Format countdown text based on time remaining
    // Use the Duration directly to avoid triple-counting bug
    final countdownText = _formatCountdownFromDuration(
      difference: absDifference,
      isOverdue: isOverdue,
    );
    
    // Format date display
    String dateDisplay = DateFormat('EEEE, MMM d, yyyy').format(nextScheduledDateTime);
    if (hasTime) {
      dateDisplay += ' at ${DateFormat('h:mm a').format(nextScheduledDateTime)}';
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            progressColor.withOpacity(isDark ? 0.15 : 0.08),
            progressColor.withOpacity(isDark ? 0.05 : 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: progressColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Compact Header with Countdown
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: progressColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(urgencyIcon, color: progressColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      urgencyLabel,
                      style: TextStyle(
                        color: progressColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      dateDisplay,
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black45,
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Compact Countdown Display
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isOverdue ? Icons.timer_off_rounded : Icons.timer_rounded,
                      color: progressColor,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      countdownText,
                      style: TextStyle(
                        color: progressColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 10),
          
          // Progress Bar - Compact
          Row(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark 
                            ? Colors.white.withOpacity(0.1) 
                            : Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    LayoutBuilder(
                      builder: (context, constraints) => AnimatedContainer(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                        height: 4,
                        width: constraints.maxWidth * progress,
                        decoration: BoxDecoration(
                          color: progressColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  color: progressColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Days Since Card - Shows how long since last completion
  /// Compact modern design
  Widget _buildDaysSinceCard(
    BuildContext context,
    DateTime lastCompletedAt,
    bool isDark,
  ) {
    final now = DateTime.now();
    
    // Calculate exact time difference from completion
    final difference = now.difference(lastCompletedAt);
    final totalMinutes = difference.inMinutes;
    final totalHours = difference.inHours;
    final totalDays = difference.inDays;
    
    // Color based on duration
    Color accentColor;
    String message;
    
    if (totalMinutes < 60) {
      accentColor = const Color(0xFF4CAF50);
      message = 'Just completed!';
    } else if (totalHours < 24) {
      accentColor = const Color(0xFF4CAF50);
      message = 'Completed today';
    } else if (totalDays <= 7) {
      accentColor = const Color(0xFF4CAF50);
      message = 'Recently done';
    } else if (totalDays <= 30) {
      accentColor = const Color(0xFFCDAF56);
      message = 'A while ago';
    } else if (totalDays <= 90) {
      accentColor = const Color(0xFFFFB347);
      message = 'Time to plan next?';
    } else {
      accentColor = const Color(0xFFFF6B6B);
      message = 'It\'s been a while!';
    }
    
    // Format time since text with precision
    // Pass the actual Duration to avoid triple-counting
    final timeSinceText = _formatDurationFromDifference(difference);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withOpacity(isDark ? 0.15 : 0.08),
            accentColor.withOpacity(isDark ? 0.05 : 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accentColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Compact Header with Time Display
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.history_rounded, color: accentColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message,
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      DateFormat('MMM d, yyyy · h:mm a').format(lastCompletedAt),
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black45,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              // Compact Time Display
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule_rounded, color: accentColor, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '$timeSinceText ago',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 10),
          
          // Plan Next Button - Compact
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showPlanNextRoutineModal(context, widget.task, widget.onTaskUpdated),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFCDAF56).withOpacity(isDark ? 0.15 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFCDAF56).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.event_repeat_rounded, color: const Color(0xFFCDAF56), size: 16),
                    const SizedBox(width: 8),
                    const Text(
                      'Plan Next Routine',
                      style: TextStyle(
                        color: Color(0xFFCDAF56),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, color: const Color(0xFFCDAF56), size: 14),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Countdown formatter from Duration - correctly calculates time
  String _formatCountdownFromDuration({
    required Duration difference,
    required bool isOverdue,
  }) {
    final totalMinutes = difference.inMinutes.abs();
    final totalHours = difference.inHours.abs();
    final totalDays = difference.inDays.abs();
    
    final suffix = isOverdue ? ' overdue' : '';
    
    // Under 1 minute
    if (totalMinutes <= 0) return isOverdue ? 'Overdue!' : 'Now!';
    
    // Under 1 hour - show minutes
    if (totalHours < 1) {
      return '${totalMinutes}m$suffix';
    }
    
    // Under 24 hours - show hours and remaining minutes
    if (totalHours < 24) {
      final remainingMinutes = totalMinutes % 60;
      if (remainingMinutes == 0) {
        return '${totalHours}h$suffix';
      }
      return '${totalHours}h ${remainingMinutes}m$suffix';
    }
    
    // Under 7 days - show days and remaining hours
    if (totalDays < 7) {
      final remainingHours = totalHours % 24;
      if (remainingHours == 0) {
        return '${totalDays}d$suffix';
      }
      return '${totalDays}d ${remainingHours}h$suffix';
    }
    
    // Weeks (7-29 days)
    if (totalDays < 30) {
      final weeks = totalDays ~/ 7;
      final remainingDays = totalDays % 7;
      if (remainingDays == 0) {
        return '${weeks}w$suffix';
      }
      return '${weeks}w ${remainingDays}d$suffix';
    }
    
    // Months (30-364 days)
    if (totalDays < 365) {
      final months = totalDays ~/ 30;
      return '${months}mo$suffix';
    }
    
    // Years (365+ days)
    final years = totalDays ~/ 365;
    return '${years}y$suffix';
  }

  /// Smart duration formatter from Duration object
  /// Correctly calculates time components without double-counting
  String _formatDurationFromDifference(Duration difference) {
    final totalMinutes = difference.inMinutes.abs();
    
    // Just now (under 1 minute)
    if (totalMinutes <= 0) return 'Just now';
    
    // Under 1 hour - show exact minutes
    if (totalMinutes < 60) {
      return '${totalMinutes}m';
    }
    
    // Under 24 hours - show hours and minutes
    final totalHours = difference.inHours.abs();
    final remainingMinutes = totalMinutes % 60;
    
    if (totalHours < 24) {
      if (remainingMinutes == 0) {
        return '${totalHours}h';
      }
      return '${totalHours}h ${remainingMinutes}m';
    }
    
    // Calculate days and remaining hours correctly
    final totalDays = difference.inDays.abs();
    final remainingHours = totalHours % 24;
    
    // Under 7 days - show days and hours
    if (totalDays < 7) {
      if (remainingHours == 0) {
        return '${totalDays}d';
      }
      return '${totalDays}d ${remainingHours}h';
    }
    
    // Weeks (7-29 days) - show weeks and days
    if (totalDays < 30) {
      final weeks = totalDays ~/ 7;
      final remainingDays = totalDays % 7;
      if (remainingDays == 0) {
        return '${weeks}w';
      }
      return '${weeks}w ${remainingDays}d';
    }
    
    // Months (30-364 days) - show months and weeks
    if (totalDays < 365) {
      final months = totalDays ~/ 30;
      final remainingDays = totalDays % 30;
      final remainingWeeks = remainingDays ~/ 7;
      if (remainingWeeks == 0) {
        return '${months}mo';
      }
      return '${months}mo ${remainingWeeks}w';
    }
    
    // Years (365+ days) - show years and months
    final years = totalDays ~/ 365;
    final remainingDays = totalDays % 365;
    final remainingMonths = remainingDays ~/ 30;
    if (remainingMonths == 0) {
      return '${years}y';
    }
    return '${years}y ${remainingMonths}mo';
  }

  /// Format interval compactly
  String _formatIntervalCompact(double avgDays) {
    final days = avgDays.round();
    if (days == 0) return '-';
    if (days < 7) return '~${days}d';
    if (days < 30) return '~${(days / 7).round()}w';
    if (days < 365) return '~${(days / 30).round()}mo';
    return '~${(days / 365).round()}y';
  }

  Widget _buildHistoryItem(Task historyTask, DateFormat dateFormat, bool isDark, bool isLast) {
    Color statusColor;
    IconData statusIcon;
    String statusText;
    String? statusBadge;
    
    // Check if task is postponed (pending with postpone count > 0)
    final isPostponed = historyTask.status == 'pending' && historyTask.postponeCount > 0;
    
    switch (historyTask.status) {
      case 'completed':
        statusColor = const Color(0xFF4CAF50);
        statusIcon = Icons.check_circle_rounded;
        statusText = historyTask.completedAt != null 
            ? dateFormat.format(historyTask.completedAt!) 
            : dateFormat.format(historyTask.dueDate);
        statusBadge = 'Done';
        break;
      case 'pending':
        if (isPostponed) {
          // Postponed task - show with different styling
          statusColor = const Color(0xFFFFB347);
          statusIcon = Icons.update_rounded;
          statusText = 'Rescheduled: ${dateFormat.format(historyTask.dueDate)}';
          statusBadge = 'Postponed';
        } else {
          statusColor = const Color(0xFFCDAF56);
          statusIcon = Icons.schedule_rounded;
          statusText = 'Scheduled: ${dateFormat.format(historyTask.dueDate)}';
          statusBadge = 'Upcoming';
        }
        break;
      case 'not_done':
        statusColor = const Color(0xFFFF6B6B);
        statusIcon = Icons.cancel_rounded;
        statusText = dateFormat.format(historyTask.dueDate);
        statusBadge = 'Skipped';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.circle;
        statusText = dateFormat.format(historyTask.dueDate);
    }
    
    // Check if this is a routine task that can be edited
    final canEditTime = historyTask.isRoutineTask && historyTask.status != 'pending';
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline Dot and Line
        Column(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            if (!isLast)
              Container(
                width: 1.5,
                height: 24,
                color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
              ),
          ],
        ),
        const SizedBox(width: 10),
        
        // Content
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 4),
            child: Row(
              children: [
                Icon(statusIcon, size: 14, color: statusColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: isDark ? Colors.white.withOpacity(0.8) : Colors.black.withOpacity(0.75),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                // Edit button for completed/skipped routines
                if (canEditTime)
                  GestureDetector(
                    onTap: () => _showEditRoutineTimeModal(context, historyTask),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(
                        Icons.edit_rounded,
                        size: 12,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ),
                // Status badge
                if (statusBadge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      statusBadge,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Shows a modal to edit the completion time of a routine task
  void _showEditRoutineTimeModal(BuildContext context, Task historyTask) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditRoutineTimeModal(
        task: historyTask,
        onTimeUpdated: () {
          widget.onTaskUpdated?.call();
          setState(() {});
        },
      ),
    );
  }

  Widget _buildActionButtons(bool isDark, Color bgColor, Color cardColor) {
    final bool isPending = widget.task.status == 'pending' || widget.task.status == 'overdue';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
          width: 1.5,
        ),
      ),
      child: isPending
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Done Button (with pulse animation)
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: _ActionButton(
                        icon: Icons.check_rounded,
                        label: 'Done',
                        color: const Color(0xFF4CAF50),
                        onTap: _handleDone,
                        isPrimary: true,
                      ),
                    );
                  },
                ),
                // Not Done Button
                _ActionButton(
                  icon: Icons.close_rounded,
                  label: 'Not Done',
                  color: const Color(0xFFFF6B6B),
                  onTap: _handleNotDone,
                ),
                // Postpone Button
                _ActionButton(
                  icon: Icons.schedule_rounded,
                  label: 'Postpone',
                  color: const Color(0xFFFFB347),
                  onTap: () => _showPostponeModal(context, widget.task, widget.onTaskUpdated),
                ),
                // Statistics button for routine tasks (pending)
                if (widget.task.isRoutineTask)
                  _ActionButton(
                    icon: Icons.insights_rounded,
                    label: 'Stats',
                    color: const Color(0xFF00BCD4),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RoutineStatisticsScreen(routineTask: widget.task),
                        ),
                      );
                    },
                  ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Plan Next button for completed routine tasks
                if (widget.task.isRoutineTask)
                  _ActionButton(
                    icon: Icons.add_circle_outline_rounded,
                    label: 'Plan Next',
                    color: const Color(0xFFCDAF56),
                    onTap: () => _showPlanNextRoutineModal(context, widget.task, widget.onTaskUpdated),
                    isPrimary: true,
                  ),
                // Statistics button for routine tasks
                if (widget.task.isRoutineTask)
                  _ActionButton(
                    icon: Icons.insights_rounded,
                    label: 'Statistics',
                    color: const Color(0xFF00BCD4),
                    onTap: () {
                      Navigator.pop(context); // Close modal
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RoutineStatisticsScreen(routineTask: widget.task),
                        ),
                      );
                    },
                  ),
                _ActionButton(
                  icon: Icons.undo_rounded,
                  label: 'Undo',
                  color: const Color(0xFF64748B),
                  onTap: _handleUndo,
                  isPrimary: !widget.task.isRoutineTask, // Only primary if not routine
                ),
              ],
            ),
    );
  }
            
  Widget _buildSuccessOverlay() {
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
                                duration: Duration(milliseconds: 500 + (index * 50)),
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

                            // 2. Celebration Emoji (The "Imojy")
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: const Duration(milliseconds: 800),
                              curve: Curves.elasticOut,
                              builder: (context, value, child) {
                                return Transform.scale(
                                  scale: value,
                                  child: Text(
                                    '🚀', // High-energy success emoji
                                    style: TextStyle(fontSize: 64, shadows: [
                                      Shadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 20,
                                        offset: const Offset(0, 10),
                                      ),
                                    ]),
                                  ),
                                );
                              },
                            ),

                            // 3. Lottie Celebration Layer
                            SizedBox(
                              width: 180, // Reduced slightly to avoid overflow
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
                          'Completed! 🎉',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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
                        if (_animationPoints > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.2)),
                            ),
                            child: Text(
                              '+$_animationPoints points earned',
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

  Widget _buildNotDoneOverlay() {
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
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Lottie Layer
                        SizedBox(
                          width: 180,
                          height: 180,
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
                      'Marked as Not Done',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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
                    if (_animationPenalty != 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: Text(
                          '$_animationPenalty points penalty',
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
        ),
      ),
    );
  }


  String _formatDueDate(Task task) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDate = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
    final difference = taskDate.difference(today).inDays;
    
    String dateStr;
    if (difference == 0) {
      dateStr = 'Today';
    } else if (difference == 1) {
      dateStr = 'Tomorrow';
    } else if (difference == -1) {
      dateStr = 'Yesterday';
    } else if (difference < 0) {
      dateStr = '${-difference}d ago';
    } else {
      dateStr = DateFormat('MMM dd').format(task.dueDate);
    }
    
    if (task.dueTime != null) {
      final hour = task.dueTime!.hour;
      final minute = task.dueTime!.minute;
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      dateStr += ' · ${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
    }
    
    return dateStr;
  }

  Future<void> _toggleSpecial(BuildContext context) async {
    final container = ProviderScope.containerOf(context);
    final updatedTask = widget.task.copyWith(isSpecial: !widget.task.isSpecial);
    
    await container.read(taskNotifierProvider.notifier).updateTask(updatedTask);
    widget.onTaskUpdated?.call();
    
    if (context.mounted) {
      Navigator.of(context).pop();
      AppSnackbar.showInfo(
        context,
        updatedTask.isSpecial ? 'Task starred! It will appear at the top.' : 'Task unstarred.',
      );
    }
  }

  void _showDeleteConfirmation(BuildContext context) {
    // Check task types using explicit taskKind field
    final bool isRecurring = widget.task.taskKind == TaskKind.recurring || 
                              widget.task.recurrenceGroupId != null || 
                              widget.task.hasRecurrence;
    final bool isRoutine = widget.task.taskKind == TaskKind.routine || 
                            widget.task.isRoutineTask;
    
    if (isRoutine) {
      // Show routine task delete dialog with options
      _showRoutineDeleteSheet(context);
    } else if (isRecurring) {
      // Show recurring task delete dialog with options
      _showRecurringDeleteSheet(context);
    } else {
      // Show normal delete dialog for normal tasks
      _showNormalDeleteSheet(context);
    }
  }

  /// Get routine instance count for display
  int _getRoutineInstanceCount() {
    final container = ProviderScope.containerOf(context);
    final tasksAsync = container.read(taskNotifierProvider);
    int count = 0;
    tasksAsync.whenData((tasks) {
      final groupId = widget.task.effectiveRoutineGroupId;
      count = tasks.where((t) => 
        t.id == groupId || t.routineGroupId == groupId
      ).length;
    });
    return count;
  }

  /// Get recurring task count for display
  int _getRecurringInstanceCount() {
    final container = ProviderScope.containerOf(context);
    final tasksAsync = container.read(taskNotifierProvider);
    int count = 0;
    tasksAsync.whenData((tasks) {
      if (widget.task.recurrenceGroupId != null) {
        count = tasks.where((t) => 
          t.recurrenceGroupId == widget.task.recurrenceGroupId
        ).length;
      }
    });
    return count;
  }

  void _showRoutineDeleteSheet(BuildContext context) {
    final instanceCount = _getRoutineInstanceCount();
    final dateFormat = DateFormat('MMM d, yyyy');
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2D3139) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Header with icon
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.red.withValues(alpha: 0.15),
                          Colors.red.withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.loop_rounded, color: Colors.red, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Delete Routine',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.task.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Task info card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        _buildInfoItem(
                          icon: Icons.calendar_today_rounded,
                          label: 'Date',
                          value: dateFormat.format(widget.task.dueDate),
                          isDark: isDark,
                        ),
                        Container(
                          width: 1,
                          height: 30,
                          color: isDark ? Colors.white12 : Colors.grey.shade300,
                        ),
                        _buildInfoItem(
                          icon: Icons.layers_rounded,
                          label: 'Instances',
                          value: instanceCount.toString(),
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Option 1: Delete this instance only
                  _buildDeleteOption(
                    context: sheetContext,
                    isDark: isDark,
                    icon: Icons.event_rounded,
                    iconColor: const Color(0xFFCDAF56),
                    title: 'Delete this occurrence',
                    subtitle: 'Remove only this routine instance',
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      Navigator.of(context).pop();
                      final container = ProviderScope.containerOf(context);
                      await container.read(taskNotifierProvider.notifier).deleteTask(widget.task.id);
                      if (context.mounted) {
                        AppSnackbar.showInfo(context, 'Routine occurrence deleted');
                      }
                      widget.onTaskUpdated?.call();
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  // Option 2: Delete entire routine series
                  _buildDeleteOption(
                    context: sheetContext,
                    isDark: isDark,
                    icon: Icons.delete_forever_rounded,
                    iconColor: Colors.red,
                    title: 'Delete entire routine',
                    subtitle: 'Remove all $instanceCount instances permanently',
                    isDangerous: true,
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      // Show confirmation for dangerous action
                      final confirmed = await _showDangerConfirmation(
                        context,
                        title: 'Delete All Routine Instances?',
                        message: 'This will permanently delete all $instanceCount instances of this routine including all history. This cannot be undone.',
                      );
                      if (confirmed == true && context.mounted) {
                        Navigator.of(context).pop();
                        final container = ProviderScope.containerOf(context);
                        final routineGroupId = widget.task.effectiveRoutineGroupId;
                        final deletedCount = await container.read(taskNotifierProvider.notifier).deleteRoutineSeries(routineGroupId);
                        if (context.mounted) {
                          AppSnackbar.showError(context, 'Routine deleted ($deletedCount instances removed)');
                        }
                        widget.onTaskUpdated?.call();
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Cancel button
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white54 : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showRecurringDeleteSheet(BuildContext context) {
    final instanceCount = _getRecurringInstanceCount();
    final dateFormat = DateFormat('MMM d, yyyy');
    final recurrenceDesc = widget.task.recurrence?.getDescription() ?? 'Recurring';
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2D3139) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Header with icon
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.red.withValues(alpha: 0.15),
                          Colors.red.withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.repeat_rounded, color: Colors.red, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Delete Recurring Task',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.task.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Task info card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        _buildInfoItem(
                          icon: Icons.repeat_rounded,
                          label: 'Pattern',
                          value: recurrenceDesc,
                          isDark: isDark,
                          flex: 2,
                        ),
                        Container(
                          width: 1,
                          height: 30,
                          color: isDark ? Colors.white12 : Colors.grey.shade300,
                        ),
                        _buildInfoItem(
                          icon: Icons.layers_rounded,
                          label: 'Tasks',
                          value: instanceCount > 0 ? instanceCount.toString() : '1',
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Option 1: Delete this occurrence only
                  _buildDeleteOption(
                    context: sheetContext,
                    isDark: isDark,
                    icon: Icons.event_rounded,
                    iconColor: const Color(0xFFCDAF56),
                    title: 'Delete this occurrence',
                    subtitle: 'Remove only ${dateFormat.format(widget.task.dueDate)}',
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      Navigator.of(context).pop();
                      final container = ProviderScope.containerOf(context);
                      await container.read(taskNotifierProvider.notifier).deleteTask(widget.task.id);
                      if (context.mounted) {
                        AppSnackbar.showInfo(context, 'Task occurrence deleted');
                      }
                      widget.onTaskUpdated?.call();
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  // Option 2: Delete entire series
                  _buildDeleteOption(
                    context: sheetContext,
                    isDark: isDark,
                    icon: Icons.delete_forever_rounded,
                    iconColor: Colors.red,
                    title: 'Delete all occurrences',
                    subtitle: 'Remove entire recurring series${instanceCount > 0 ? ' ($instanceCount tasks)' : ''}',
                    isDangerous: true,
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      // Show confirmation for dangerous action
                      final confirmed = await _showDangerConfirmation(
                        context,
                        title: 'Delete Entire Series?',
                        message: 'This will permanently delete all occurrences of this recurring task. This cannot be undone.',
                      );
                      if (confirmed == true && context.mounted) {
                        Navigator.of(context).pop();
                        final container = ProviderScope.containerOf(context);
                        if (widget.task.recurrenceGroupId != null) {
                          await container.read(taskNotifierProvider.notifier).deleteRecurringSeries(widget.task.recurrenceGroupId!);
                          if (context.mounted) {
                            AppSnackbar.showError(context, 'Recurring series deleted');
                          }
                        } else {
                          await container.read(taskNotifierProvider.notifier).deleteTask(widget.task.id);
                          if (context.mounted) {
                            AppSnackbar.showInfo(context, 'Task deleted');
                          }
                        }
                        widget.onTaskUpdated?.call();
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Cancel button
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white54 : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showNormalDeleteSheet(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2D3139) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Header with icon
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.red.withValues(alpha: 0.15),
                          Colors.red.withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            widget.task.icon ?? Icons.task_rounded,
                            color: Colors.red,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Delete Task',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.task.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Warning message
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: isDark ? 0.15 : 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'This action cannot be undone.',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white70 : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Task info
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 16, color: isDark ? Colors.white38 : Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        dateFormat.format(widget.task.dueDate),
                        style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.grey.shade600),
                      ),
                      if (widget.task.priority == 'High') ...[
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'High Priority',
                            style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.of(sheetContext).pop();
                            Navigator.of(context).pop();
                            final container = ProviderScope.containerOf(context);
                            await container.read(taskNotifierProvider.notifier).deleteTask(widget.task.id);
                            if (context.mounted) {
                              AppSnackbar.showInfo(context, 'Task deleted');
                            }
                            widget.onTaskUpdated?.call();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.delete_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('Delete', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
    int flex = 1,
  }) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          children: [
            Icon(icon, size: 16, color: isDark ? Colors.white38 : Colors.grey),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.grey),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteOption({
    required BuildContext context,
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDangerous = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDangerous
                ? Colors.red.withValues(alpha: isDark ? 0.1 : 0.05)
                : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDangerous
                  ? Colors.red.withValues(alpha: 0.4)
                  : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDangerous ? Colors.red : (isDark ? Colors.white : Colors.black87),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? Colors.white24 : Colors.grey.shade400,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _showDangerConfirmation(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF2D3139) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.warning_rounded, color: Colors.red, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.grey.shade700,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: const Text('Delete Permanently', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }

  static void _showPostponeModal(BuildContext context, Task task, VoidCallback? onTaskUpdated) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PostponeModal(task: task, onTaskUpdated: onTaskUpdated),
    );
  }

  /// Shows the Plan Next Routine modal - public for external access
  static void showPlanNextRoutineModal(BuildContext context, Task task, VoidCallback? onTaskUpdated) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PlanNextRoutineModal(task: task, onTaskUpdated: onTaskUpdated),
    );
  }
  
  // Keep private version for internal use
  static void _showPlanNextRoutineModal(BuildContext context, Task task, VoidCallback? onTaskUpdated) {
    showPlanNextRoutineModal(context, task, onTaskUpdated);
  }
}

// Action Button Widget
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isPrimary;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4), // Space for outer outline
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withOpacity(0.4),
                width: 2.5,
              ),
            ),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskDetailSnoozeSheet extends StatelessWidget {
  final List<int> options;
  final int defaultOption;
  final bool isDark;

  const _TaskDetailSnoozeSheet({
    required this.options,
    required this.defaultOption,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final unique = options.toSet().toList()..sort();

    return Container(
      margin: const EdgeInsets.all(16),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2026) : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF42A5F5).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.snooze_rounded, color: Color(0xFF42A5F5), size: 22),
                ),
                const SizedBox(width: 14),
                Text(
                  'Snooze for…',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1A1C1E),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...unique.map((minutes) {
                    final isDefault = minutes == defaultOption;
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.pop(context, minutes),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          child: Row(
                            children: [
                              Icon(
                                isDefault ? Icons.timer_rounded : Icons.timer_outlined,
                                color: isDefault ? const Color(0xFF42A5F5) : (isDark ? Colors.white54 : Colors.black45),
                                size: 22,
                              ),
                              const SizedBox(width: 14),
                              Text(
                                _formatDuration(minutes),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: isDefault ? FontWeight.w700 : FontWeight.w500,
                                  color: isDark ? Colors.white : const Color(0xFF1A1C1E),
                                ),
                              ),
                              if (isDefault) ...[
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF42A5F5).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Default',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF42A5F5),
                                    ),
                                  ),
                                ),
                              ],
                              const Spacer(),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: isDark ? Colors.white24 : Colors.black26,
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        final minutes = await showModalBottomSheet<int>(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => _TaskDetailCustomSnoozeSheet(isDark: isDark),
                        );
                        if (minutes != null && context.mounted) {
                          Navigator.pop(context, minutes);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        child: Row(
                          children: [
                            Icon(Icons.tune_rounded, color: isDark ? Colors.white54 : Colors.black45, size: 22),
                            const SizedBox(width: 14),
                            Text(
                              'Custom…',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF1A1C1E),
                              ),
                            ),
                            const Spacer(),
                            Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white24 : Colors.black26, size: 22),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SafeArea(top: false, child: SizedBox(height: 8)),
        ],
      ),
    );
  }

  static String _formatDuration(int minutes) {
    if (minutes < 60) return '$minutes minutes';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) return '$hours ${hours == 1 ? 'hour' : 'hours'}';
    return '$hours hr $mins min';
  }
}

class _TaskDetailCustomSnoozeSheet extends StatefulWidget {
  final bool isDark;
  const _TaskDetailCustomSnoozeSheet({required this.isDark});

  @override
  State<_TaskDetailCustomSnoozeSheet> createState() => _TaskDetailCustomSnoozeSheetState();
}

class _TaskDetailCustomSnoozeSheetState extends State<_TaskDetailCustomSnoozeSheet> {
  late final TextEditingController _hoursController;
  late final TextEditingController _minutesController;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _hoursController = TextEditingController();
    _minutesController = TextEditingController();
  }

  @override
  void dispose() {
    _hoursController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bg = isDark ? const Color(0xFF1C2026) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1C1E);
    final subText = isDark ? Colors.white70 : Colors.black54;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(24),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Custom snooze',
                  style: TextStyle(color: textColor, fontWeight: FontWeight.w800, fontSize: 20),
                ),
                const SizedBox(height: 10),
                Text(
                  'Enter hours/minutes. Example: 1 hour 30 minutes.',
                  style: TextStyle(color: subText, fontSize: 13),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _hoursController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: 'Hours',
                          filled: true,
                          fillColor: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        style: TextStyle(color: textColor),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _minutesController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: 'Minutes',
                          filled: true,
                          fillColor: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        style: TextStyle(color: textColor),
                      ),
                    ),
                  ],
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _errorText!,
                    style: const TextStyle(color: Color(0xFFE57373), fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: subText,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF42A5F5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          final h = int.tryParse(_hoursController.text.trim()) ?? 0;
                          final m = int.tryParse(_minutesController.text.trim()) ?? 0;
                          final total = (h * 60) + m;

                          if (total <= 0) {
                            setState(() => _errorText = 'Please enter a duration greater than 0.');
                            return;
                          }
                          if (total > 24 * 60) {
                            setState(() => _errorText = 'Max allowed is 24 hours.');
                            return;
                          }
                          Navigator.pop(context, total);
                        },
                        child: const Text('Set snooze', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Postpone Modal
class _PostponeModal extends ConsumerStatefulWidget {
  final Task task;
  final VoidCallback? onTaskUpdated;

  const _PostponeModal({required this.task, this.onTaskUpdated});

  @override
  ConsumerState<_PostponeModal> createState() => _PostponeModalState();
}

class _PostponeModalState extends ConsumerState<_PostponeModal> {
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = TimeOfDay.now();
  String? _selectedReason;

  @override
  Widget build(BuildContext context) {
    final reasonsAsync = ref.watch(postponeReasonsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E2228) : const Color(0xFFF8F9FA);
    final cardColor = isDark ? const Color(0xFF252A31) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1C1E);
    final subtextColor = isDark ? Colors.white.withOpacity(0.7) : const Color(0xFF44474E);
    
            return Container(
              decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: isDark ? [] : [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
                padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 24,
        right: 24,
        top: 20,
                ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
                              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.3) : Colors.black.withOpacity(0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Postpone Task',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 20),
          // Date Picker
          _buildDateTimePicker(
            icon: Icons.calendar_today_rounded,
            label: 'New Date',
            value: DateFormat('MMM dd, yyyy').format(_selectedDate),
            isDark: isDark,
            cardColor: cardColor,
            textColor: textColor,
            subtextColor: subtextColor,
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (date != null) setState(() => _selectedDate = date);
            },
          ),
          const SizedBox(height: 12),
          // Time Picker
          _buildDateTimePicker(
            icon: Icons.access_time_rounded,
            label: 'New Time',
            value: _selectedTime.format(context),
            isDark: isDark,
            cardColor: cardColor,
            textColor: textColor,
            subtextColor: subtextColor,
            onTap: () async {
              final time = await showTimePicker(
                context: context,
                initialTime: _selectedTime,
              );
              if (time != null) setState(() => _selectedTime = time);
            },
          ),
          const SizedBox(height: 20),
          // Reasons
          Text(
            'Reason (optional)',
            style: TextStyle(color: subtextColor, fontSize: 13),
          ),
          const SizedBox(height: 8),
          reasonsAsync.when(
            data: (reasons) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: reasons.map((reason) {
                final isSelected = _selectedReason == reason.id;
                final accentColor = const Color(0xFFCDAF56);
                              return GestureDetector(
                  onTap: () => setState(() => _selectedReason = isSelected ? null : reason.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                      color: isSelected
                          ? accentColor.withOpacity(0.15)
                          : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03)),
                      borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSelected
                            ? accentColor
                            : (isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.08)),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                        if (reason.iconCodePoint != null)
                          Icon(
                            IconData(
                              reason.iconCodePoint!,
                              fontFamily: reason.iconFontFamily ?? 'MaterialIcons',
                              fontPackage: reason.iconFontPackage,
                            ),
                            size: 16,
                            color: isSelected ? accentColor : (isDark ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.6)),
                          ),
                        if (reason.iconCodePoint != null) const SizedBox(width: 6),
                                      Text(
                                        reason.text,
                                        style: TextStyle(
                            color: isSelected ? accentColor : (isDark ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.7)),
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
            loading: () => const CircularProgressIndicator(),
            error: (_, __) => const Text('Error loading reasons'),
          ),
                      const SizedBox(height: 24),
          // Action Button
          SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
              onPressed: () async {
                                    final container = ProviderScope.containerOf(context);
                                    final notifier = container.read(taskNotifierProvider.notifier);
                final reasons = container.read(postponeReasonsProvider).asData?.value ?? [];
                final selectedReasonText = _selectedReason != null 
                    ? (reasons.firstWhere((r) => r.id == _selectedReason, orElse: () => TaskReason(text: _selectedReason!, typeIndex: 1)).text)
                    : 'No reason provided';
                
                // Get the postpone penalty from task type
                int penalty = -5; // Default penalty
                if (widget.task.taskTypeId != null) {
                  try {
                    final taskTypeAsync = await container.read(taskTypeByIdProvider(widget.task.taskTypeId!).future);
                    if (taskTypeAsync != null) {
                      penalty = taskTypeAsync.penaltyPostpone;
                    }
                  } catch (_) {
                    // Use default penalty if task type not found
                  }
                }
                
                // Create the new date with time
                final newDateTime = DateTime(
                  _selectedDate.year,
                  _selectedDate.month,
                  _selectedDate.day,
                  _selectedTime.hour,
                  _selectedTime.minute,
                );
                
                // Use the robust postponeTask method with penalty tracking
                await notifier.postponeTask(
                  widget.task.id,
                  newDateTime,
                  selectedReasonText,
                  penalty: penalty,
                );
                                    
                                    if (context.mounted) {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                  widget.onTaskUpdated?.call();
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB347),
                              foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
              ),
              child: const Text('Postpone', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
      ),
    );
  }

  Widget _buildDateTimePicker({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
    required bool isDark,
    required Color cardColor,
    required Color textColor,
    required Color subtextColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFCDAF56), size: 20),
            const SizedBox(width: 12),
            Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Text(label, style: TextStyle(color: subtextColor, fontSize: 11)),
                Text(value, style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Plan Next Routine Modal
class _PlanNextRoutineModal extends ConsumerStatefulWidget {
  final Task task;
  final VoidCallback? onTaskUpdated;

  const _PlanNextRoutineModal({required this.task, this.onTaskUpdated});

  @override
  ConsumerState<_PlanNextRoutineModal> createState() => _PlanNextRoutineModalState();
}

class _PlanNextRoutineModalState extends ConsumerState<_PlanNextRoutineModal> {
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 14)); // Default to 2 weeks
  TimeOfDay _selectedTime = TimeOfDay.now();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E2228) : const Color(0xFFF8F9FA);
    final cardColor = isDark ? const Color(0xFF252A31) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1C1E);
    final subtextColor = isDark ? Colors.white.withOpacity(0.7) : const Color(0xFF44474E);
    
    // Get the last completed date from the routine group for accurate progress start
    // Use widget.task.completedAt if it's set (just completed), otherwise get from stats
    final routineStatsAsync = ref.watch(routineStatsProvider(widget.task.effectiveRoutineGroupId));
    final statsLastCompletedAt = routineStatsAsync.valueOrNull?['lastCompletedAt'] as DateTime?;
    // Prefer the passed task's completedAt (in case it was just completed), fallback to stats
    final lastCompletedAt = widget.task.completedAt ?? statsLastCompletedAt;
    
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: isDark ? [] : [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 24,
        right: 24,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.3) : Colors.black.withOpacity(0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Header with Icon
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFCDAF56).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.loop_rounded,
                  color: Color(0xFFCDAF56),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Plan Next ${widget.task.title}?',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'This is a routine task. Schedule the next one?',
                      style: TextStyle(color: subtextColor, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Quick Date Buttons
          Text(
            'Quick Pick',
            style: TextStyle(color: subtextColor, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildQuickDateChip('1 Week', 7, isDark),
              _buildQuickDateChip('2 Weeks', 14, isDark),
              _buildQuickDateChip('1 Month', 30, isDark),
              _buildQuickDateChip('3 Months', 90, isDark),
            ],
          ),
          const SizedBox(height: 20),
          
          // Date Picker
          _buildDateTimePicker(
            icon: Icons.calendar_today_rounded,
            label: 'Next Date',
            value: DateFormat('MMM dd, yyyy').format(_selectedDate),
            isDark: isDark,
            cardColor: cardColor,
            textColor: textColor,
            subtextColor: subtextColor,
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 730)),
              );
              if (date != null) setState(() => _selectedDate = date);
            },
          ),
          const SizedBox(height: 12),
          
          // Time Picker
          _buildDateTimePicker(
            icon: Icons.access_time_rounded,
            label: 'Time',
            value: _selectedTime.format(context),
            isDark: isDark,
            cardColor: cardColor,
            textColor: textColor,
            subtextColor: subtextColor,
            onTap: () async {
              final time = await showTimePicker(
                context: context,
                initialTime: _selectedTime,
              );
              if (time != null) setState(() => _selectedTime = time);
            },
          ),
          const SizedBox(height: 24),
          
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: subtextColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.1)),
                  ),
                  child: const Text('Skip'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () async {
                    final container = ProviderScope.containerOf(context);
                    final notifier = container.read(taskNotifierProvider.notifier);
                    
                    // Create the next routine instance
                    // FIXED: Use lastCompletedAt (from task or stats) as progressStartDate
                    // so progress starts from when the previous routine was completed
                    // This ensures consistent progress calculation everywhere
                    final nextTask = widget.task.createNextRoutineInstance(
                      newDueDate: _selectedDate,
                      newDueTime: _selectedTime,
                      progressStartDate: lastCompletedAt ?? DateTime.now(),
                    );
                    
                    await notifier.addTask(nextTask);
                    
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.loop_rounded, color: Colors.white),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Next "${widget.task.title}" scheduled for ${DateFormat('MMM dd').format(_selectedDate)}',
                                  maxLines: 2,
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
                      widget.onTaskUpdated?.call();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCDAF56),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_rounded, size: 18),
                      SizedBox(width: 6),
                      Text('Plan Next', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickDateChip(String label, int days, bool isDark) {
    final targetDate = DateTime.now().add(Duration(days: days));
    final isSelected = _selectedDate.day == targetDate.day &&
        _selectedDate.month == targetDate.month &&
        _selectedDate.year == targetDate.year;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedDate = targetDate),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFCDAF56).withOpacity(0.15)
              : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFCDAF56)
                : (isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.08)),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? const Color(0xFFCDAF56)
                : (isDark ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.7)),
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildDateTimePicker({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
    required bool isDark,
    required Color cardColor,
    required Color textColor,
    required Color subtextColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFCDAF56), size: 20),
            const SizedBox(width: 12),
            Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Text(label, style: TextStyle(color: subtextColor, fontSize: 11)),
                Text(value, style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Not Done Modal
class _NotDoneModal extends ConsumerStatefulWidget {
  final Task task;
  final VoidCallback? onTaskUpdated;

  const _NotDoneModal({required this.task, this.onTaskUpdated});

  @override
  ConsumerState<_NotDoneModal> createState() => _NotDoneModalState();
}

class _NotDoneModalState extends ConsumerState<_NotDoneModal>
    with TickerProviderStateMixin {
  String? _selectedReason;
  late AnimationController _effectController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  bool _showEffect = false;

  @override
  void initState() {
    super.initState();
    _effectController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _effectController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _effectController, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _effectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reasonsAsync = ref.watch(notDoneReasonsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E2228) : const Color(0xFFF8F9FA);
    final textColor = isDark ? Colors.white : const Color(0xFF1A1C1E);
    final subtextColor = isDark ? Colors.white.withOpacity(0.7) : const Color(0xFF44474E);
    
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 24,
        right: 24,
        top: 20,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: isDark ? [] : [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.3) : Colors.black.withOpacity(0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Mark as Not Done',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This will affect your points. Select a reason:',
            style: TextStyle(color: subtextColor, fontSize: 13),
          ),
          const SizedBox(height: 20),
          // Reasons
          reasonsAsync.when(
            data: (reasons) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: reasons.map((reason) {
                final isSelected = _selectedReason == reason.id;
                final accentColor = const Color(0xFFFF6B6B);
                return GestureDetector(
                  onTap: () => setState(() => _selectedReason = isSelected ? null : reason.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? accentColor.withOpacity(0.15)
                          : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03)),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? accentColor
                            : (isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.08)),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (reason.iconCodePoint != null)
                          Icon(
                            IconData(
                              reason.iconCodePoint!,
                              fontFamily: reason.iconFontFamily ?? 'MaterialIcons',
                              fontPackage: reason.iconFontPackage,
                            ),
                            size: 16,
                            color: isSelected ? accentColor : (isDark ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.6)),
                          ),
                        if (reason.iconCodePoint != null) const SizedBox(width: 6),
                        Text(
                          reason.text,
                          style: TextStyle(
                            color: isSelected ? accentColor : (isDark ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.7)),
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            loading: () => const CircularProgressIndicator(),
            error: (_, __) => const Text('Error loading reasons'),
          ),
          const SizedBox(height: 24),
          // Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedReason == null
                  ? null
                  : () {
                      final reasons = ref.read(notDoneReasonsProvider).asData?.value ?? [];
                      final selectedReasonText = reasons.isNotEmpty 
                          ? (reasons.firstWhere((r) => r.id == _selectedReason, orElse: () => TaskReason(text: _selectedReason!, typeIndex: 0)).text)
                          : _selectedReason;
                      
                      Navigator.of(context).pop(selectedReasonText);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B6B),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFFF6B6B).withOpacity(0.3),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Confirm', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Modal for editing the completion time of a routine task
class _EditRoutineTimeModal extends ConsumerStatefulWidget {
  final Task task;
  final VoidCallback? onTimeUpdated;

  const _EditRoutineTimeModal({
    required this.task,
    this.onTimeUpdated,
  });

  @override
  ConsumerState<_EditRoutineTimeModal> createState() => _EditRoutineTimeModalState();
}

class _EditRoutineTimeModalState extends ConsumerState<_EditRoutineTimeModal> {
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  String _selectedStatus = 'done';

  @override
  void initState() {
    super.initState();
    // Initialize with current completion date/time or due date
    final initialDate = widget.task.completedAt ?? widget.task.dueDate;
    _selectedDate = initialDate;
    _selectedTime = TimeOfDay.fromDateTime(initialDate);
    
    // Set status based on current task status
    switch (widget.task.status) {
      case 'completed':
        _selectedStatus = 'done';
        break;
      case 'not_done':
        _selectedStatus = 'skipped';
        break;
      default:
        _selectedStatus = 'done';
    }
  }

  Future<void> _selectDate() async {
    HapticFeedback.selectionClick();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    HapticFeedback.selectionClick();
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _saveChanges() async {
    HapticFeedback.mediumImpact();
    
    final newDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    // Determine new status
    final newStatus = _selectedStatus == 'done' ? 'completed' : 'not_done';
    
    // Update the task
    final updatedTask = widget.task.copyWith(
      completedAt: newDateTime,
      dueDate: _selectedDate,
      status: newStatus,
      routineStatus: _selectedStatus,
    );

    await ref.read(taskNotifierProvider.notifier).updateTask(updatedTask);
    
    widget.onTimeUpdated?.call();
    
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E2228) : const Color(0xFFF8F9FA);
    final cardColor = isDark ? const Color(0xFF2D3139) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.white70 : Colors.grey.shade600;
    final dateFormat = DateFormat('EEE, MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24,
        right: 24,
        top: 20,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white30 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFCDAF56).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.edit_calendar_rounded,
                  color: Color(0xFFCDAF56),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Edit Routine Record',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    Text(
                      widget.task.title,
                      style: TextStyle(
                        fontSize: 13,
                        color: subtextColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Status Selection
          Text(
            'Status',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: subtextColor,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildStatusChip(
                label: 'Done',
                icon: Icons.check_circle_rounded,
                color: const Color(0xFF4CAF50),
                isSelected: _selectedStatus == 'done',
                onTap: () => setState(() => _selectedStatus = 'done'),
                isDark: isDark,
              ),
              const SizedBox(width: 10),
              _buildStatusChip(
                label: 'Skipped',
                icon: Icons.skip_next_rounded,
                color: const Color(0xFFFF6B6B),
                isSelected: _selectedStatus == 'skipped',
                onTap: () => setState(() => _selectedStatus = 'skipped'),
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Date Selection
          Text(
            'Date & Time',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: subtextColor,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Date Picker
              Expanded(
                child: GestureDetector(
                  onTap: _selectDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.white12 : Colors.grey.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          color: const Color(0xFFCDAF56),
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            dateFormat.format(_selectedDate),
                            style: TextStyle(
                              color: textColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_drop_down_rounded,
                          color: subtextColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Time Picker
              GestureDetector(
                onTap: _selectTime,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.grey.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        color: const Color(0xFFCDAF56),
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        timeFormat.format(DateTime(2024, 1, 1, _selectedTime.hour, _selectedTime.minute)),
                        style: TextStyle(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.arrow_drop_down_rounded,
                        color: subtextColor,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Quick Date Picks
          Text(
            'Quick Date',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: subtextColor,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickDateChip('Today', DateTime.now(), isDark),
                const SizedBox(width: 8),
                _buildQuickDateChip('Yesterday', DateTime.now().subtract(const Duration(days: 1)), isDark),
                const SizedBox(width: 8),
                _buildQuickDateChip('2 Days Ago', DateTime.now().subtract(const Duration(days: 2)), isDark),
                const SizedBox(width: 8),
                _buildQuickDateChip('1 Week Ago', DateTime.now().subtract(const Duration(days: 7)), isDark),
                const SizedBox(width: 8),
                _buildQuickDateChip('2 Weeks Ago', DateTime.now().subtract(const Duration(days: 14)), isDark),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: subtextColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCDAF56),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_rounded, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Save Changes',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip({
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected 
                ? color.withOpacity(0.2) 
                : (isDark ? const Color(0xFF2D3139) : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? color : (isDark ? Colors.white54 : Colors.grey),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? color : (isDark ? Colors.white54 : Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickDateChip(String label, DateTime date, bool isDark) {
    final isSelected = _selectedDate.year == date.year &&
        _selectedDate.month == date.month &&
        _selectedDate.day == date.day;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedDate = date);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? const Color(0xFFCDAF56).withOpacity(0.2) 
              : (isDark ? const Color(0xFF2D3139) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFFCDAF56) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected 
                ? const Color(0xFFCDAF56) 
                : (isDark ? Colors.white70 : Colors.grey.shade700),
          ),
        ),
      ),
    );
  }
}
