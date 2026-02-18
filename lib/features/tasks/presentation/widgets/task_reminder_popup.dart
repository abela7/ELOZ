import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/color_schemes.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/reminder_manager.dart';
import '../../../../core/providers/notification_settings_provider.dart';
import '../../../../data/models/task.dart';
import '../../../../data/models/subtask.dart';
import '../../../../data/models/category.dart';
import '../../../../data/repositories/task_repository.dart';
import '../../../../routing/app_router.dart';
import '../providers/task_providers.dart';
import '../providers/task_type_providers.dart';
import '../providers/category_providers.dart';
import '../providers/task_reason_providers.dart';

/// Modern Task Reminder Popup - Clean, minimal design
/// 
/// Features:
/// - Elegant glassmorphism design
/// - Quick action buttons
/// - Snooze with user preference support
/// - Interactive subtasks
/// - Smooth animations
class TaskReminderPopup extends ConsumerStatefulWidget {
  final Task task;
  final VoidCallback? onDismiss;

  const TaskReminderPopup({
    super.key,
    required this.task,
    this.onDismiss,
  });

  /// Show the reminder popup as an overlay
  static void show(BuildContext context, Task task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      barrierColor: Colors.black54,
      builder: (context) => TaskReminderPopup(task: task),
    );
  }

  @override
  ConsumerState<TaskReminderPopup> createState() => _TaskReminderPopupState();
}

class _TaskReminderPopupState extends ConsumerState<TaskReminderPopup>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  bool _isProcessing = false;
  late Task _task; // Mutable copy for subtask updates

  @override
  void initState() {
    super.initState();
    _task = widget.task;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // App theme colors (gold accent)
  static const _goldPrimary = Color(0xFFCDAF56);
  static const _goldLight = Color(0xFFE8D48A);
  static const _goldDark = Color(0xFFB89B3E);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = ref.watch(notificationSettingsProvider);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final hasSubtasks = _task.subtasks != null && _task.subtasks!.isNotEmpty;
    final isSpecial = _task.isSpecial;

    // Watch category for icon color only
    final categoryAsync = _task.categoryId != null
        ? ref.watch(categoryByIdProvider(_task.categoryId!))
        : const AsyncValue<Category?>.data(null);
    
    // Icon color based on category/priority (only for the icon)
    final Category? category = categoryAsync.valueOrNull;
    final iconColor = category != null 
        ? Color(category.colorValue) 
        : _getPriorityColor(_task.priority);
    
    // App theme color - always use gold for UI elements
    const themeColor = _goldPrimary;
    const themeColorLight = _goldLight;
    const themeColorDark = _goldDark;

    // Background colors
    final bgColor = isSpecial
        ? (isDark ? const Color(0xFF1B1F26) : const Color(0xFFFFFEF9))
        : (isDark ? const Color(0xFF1C2026) : Colors.white);
    
    final cardGradientColors = isSpecial
        ? (isDark
            ? [const Color(0xFF252B35), const Color(0xFF1F252E), const Color(0xFF1A1F27)]
            : [const Color(0xFFFFFEF9), const Color(0xFFFFF9EC), const Color(0xFFFFFEF9)])
        : null;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value * 300),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: child,
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomPadding),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: BoxDecoration(
          color: isSpecial ? null : bgColor,
          gradient: isSpecial && cardGradientColors != null
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: cardGradientColors,
                )
              : null,
          borderRadius: BorderRadius.circular(28),
          border: isSpecial
              ? Border.all(color: _goldPrimary.withOpacity(isDark ? 0.5 : 0.4), width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: isSpecial 
                  ? _goldPrimary.withOpacity(isDark ? 0.2 : 0.15)
                  : Colors.black.withOpacity(0.25),
              blurRadius: isSpecial ? 20 : 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background icon - star for special, task icon for normal
            // Uses icon color for task theming, gold for special
            Positioned(
              right: -30,
              bottom: 40,
              child: ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    (isSpecial ? themeColor : iconColor).withOpacity(isDark ? 0.12 : 0.08),
                    (isSpecial ? themeColorLight : iconColor).withOpacity(isDark ? 0.06 : 0.04),
                  ],
                ).createShader(bounds),
                child: Icon(
                  isSpecial ? Icons.star_rounded : (_task.icon ?? Icons.task_alt_rounded),
                  size: 140,
                  color: Colors.white,
                ),
              ),
            ),
            
            // Main content
            SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isSpecial
                            ? _goldPrimary.withOpacity(0.4)
                            : (isDark ? Colors.white24 : Colors.black12),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Task content
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Special badge for special tasks
                        if (isSpecial) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _goldPrimary.withOpacity(0.25),
                                  _goldDark.withOpacity(0.12),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _goldPrimary.withOpacity(0.4),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  size: 14,
                                  color: _goldPrimary,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'SPECIAL',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: _goldPrimary,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Task icon and title row
                        Row(
                          children: [
                            // Task icon - uses category/priority color for theming
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: iconColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                _task.icon ?? Icons.task_alt_rounded,
                                color: iconColor,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Title and due time
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _task.title,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white : const Color(0xFF1A1C1E),
                                      height: 1.2,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (_task.dueTime != null) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.schedule_rounded,
                                          size: 14,
                                          color: _goldPrimary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _formatTime(_task.dueTime!),
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: _goldPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Description
                        if (_task.description != null && _task.description!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            _task.description!,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white60 : const Color(0xFF6E6E6E),
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],

                        // Interactive Subtasks
                        if (hasSubtasks) ...[
                          const SizedBox(height: 16),
                          _buildSubtasksList(isDark),
                        ],
                      ],
                    ),
                  ),

                  // Divider
                  Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
                  ),

                  // Action buttons - all use app theme colors
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Column(
                      children: [
                        // Primary row: Done + Quick Snooze
                        Row(
                          children: [
                            // Done button - green for success
                            Expanded(
                              flex: 3,
                              child: _ModernButton(
                                icon: Icons.check_rounded,
                                label: 'Done',
                                color: const Color(0xFF4CAF50),
                                isPrimary: true,
                                isLoading: _isProcessing,
                                onTap: _handleDone,
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Quick snooze - blue
                            Expanded(
                              flex: 2,
                              child: _ModernButton(
                                icon: Icons.snooze_rounded,
                                label: '${settings.defaultSnoozeDuration}m',
                                color: const Color(0xFF5C9CE6),
                                isPrimary: true,
                                onTap: () => _handleQuickSnooze(settings.defaultSnoozeDuration),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Secondary row: More, Not Done, Postpone
                        Row(
                          children: [
                            // More snooze options - blue
                            Expanded(
                              child: _ModernButton(
                                icon: Icons.more_time_rounded,
                                label: 'More',
                                color: const Color(0xFF5C9CE6),
                                isSmall: true,
                                onTap: _handleSnoozeOptions,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Not Done - red
                            Expanded(
                              child: _ModernButton(
                                icon: Icons.close_rounded,
                                label: 'Not Done',
                                color: const Color(0xFFE57373),
                                isSmall: true,
                                onTap: _handleNotDone,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Postpone - orange
                            Expanded(
                              child: _ModernButton(
                                icon: Icons.event_rounded,
                                label: 'Postpone',
                                color: const Color(0xFFFFB347),
                                isSmall: true,
                                onTap: _handlePostpone,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Dismiss option
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: isDark ? Colors.white38 : Colors.black38,
                        ),
                        child: const Text(
                          'Dismiss',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
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

  /// Build interactive subtasks list
  Widget _buildSubtasksList(bool isDark) {
    final subtasks = _task.subtasks!;
    final completed = subtasks.where((s) => s.isCompleted).length;
    final total = subtasks.length;
    final progress = total > 0 ? completed / total : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with progress
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                const Icon(
                  Icons.checklist_rounded,
                  size: 18,
                  color: _goldPrimary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Subtasks',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _goldPrimary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$completed / $total',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _goldPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Progress bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: isDark ? Colors.white12 : Colors.black12,
                valueColor: const AlwaysStoppedAnimation(_goldPrimary),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Subtask items
          ...subtasks.asMap().entries.map((entry) {
            final index = entry.key;
            final subtask = entry.value;
            return _buildSubtaskItem(subtask, index, isDark);
          }),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// Build individual subtask item with tap to toggle
  Widget _buildSubtaskItem(Subtask subtask, int index, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _toggleSubtask(index),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              // Animated checkbox - uses app gold color
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: subtask.isCompleted 
                      ? _goldPrimary 
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: subtask.isCompleted 
                        ? _goldPrimary 
                        : (isDark ? Colors.white30 : Colors.black26),
                    width: 2,
                  ),
                ),
                child: subtask.isCompleted
                    ? const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: Colors.white,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              // Subtask title
              Expanded(
                child: Text(
                  subtask.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: subtask.isCompleted
                        ? (isDark ? Colors.white38 : Colors.black38)
                        : (isDark ? Colors.white : Colors.black87),
                    decoration: subtask.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Toggle subtask completion
  Future<void> _toggleSubtask(int index) async {
    if (_task.subtasks == null || index >= _task.subtasks!.length) return;

    HapticFeedback.lightImpact();

    // Update local state immediately
    setState(() {
      _task.subtasks![index].isCompleted = !_task.subtasks![index].isCompleted;
    });

    // Persist to database
    try {
      await _task.save();
      // Notify task providers to refresh
      ref.read(taskNotifierProvider.notifier).loadTasks();
    } catch (e) {
      debugPrint('Error saving subtask: $e');
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Color _getPriorityColor(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'high':
        return const Color(0xFFE53935);
      case 'medium':
        return const Color(0xFFFFB347);
      case 'low':
        return const Color(0xFF66BB6A);
      default:
        return AppColorSchemes.primaryGold;
    }
  }

  void _handleDone() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    try {
      await ref.read(taskNotifierProvider.notifier).completeTask(widget.task.id);
      await ReminderManager().cancelRemindersForTask(widget.task.id);

      if (mounted) {
        Navigator.pop(context);
        _showSuccessSnackbar('Task completed!', const Color(0xFF4CAF50));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showErrorSnackbar('Failed to complete task');
      }
    }
  }

  void _handleQuickSnooze(int minutes) async {
    HapticFeedback.lightImpact();
    // Do the work first (while context is valid), then close the popup.
    await _persistSnoozeToTask(minutes, source: 'popup_quick');

    await NotificationService().snoozeNotification(
      taskId: widget.task.id,
      title: widget.task.title,
      body: widget.task.description ?? '',
      payload: 'task|${widget.task.id}|snooze|$minutes|minutes',
      customDurationMinutes: minutes,
      priority: widget.task.priority,
    );

    // Close popup and show feedback in the underlying scaffold.
    if (mounted) Navigator.pop(context);
    _showSuccessSnackbar('Snoozed for $minutes minutes', const Color(0xFF5C9CE6));
  }

  void _handleSnoozeOptions() async {
    HapticFeedback.lightImpact();
    final settings = ref.read(notificationSettingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final minutes = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _ModernSnoozeSheet(
        options: settings.snoozeOptions,
        defaultOption: settings.defaultSnoozeDuration,
        isDark: isDark,
      ),
    );

    if (minutes == null) return;
    if (!mounted) return;

    // Persist snooze state + history so Task Details reflects it immediately.
    await _persistSnoozeToTask(minutes, source: 'popup_options');

    await NotificationService().snoozeNotification(
      taskId: widget.task.id,
      title: widget.task.title,
      body: widget.task.description ?? '',
      payload: 'task|${widget.task.id}|snooze|$minutes|minutes',
      customDurationMinutes: minutes,
      priority: widget.task.priority,
    );

    // Close popup and show feedback in the underlying scaffold.
    if (mounted) Navigator.pop(context);
    _showSuccessSnackbar('Snoozed for ${_formatDuration(minutes)}', const Color(0xFF5C9CE6));
  }

  Future<void> _persistSnoozeToTask(int minutes, {required String source}) async {
    try {
      final snoozedUntil = DateTime.now().add(Duration(minutes: minutes));

      // Build history list (append-only).
      List<Map<String, dynamic>> history = [];
      final rawHistory = (_task.snoozeHistory ?? '').trim();
      if (rawHistory.isNotEmpty) {
        try {
          history = List<Map<String, dynamic>>.from(jsonDecode(rawHistory));
        } catch (_) {
          history = [];
        }
      }

      history.add({
        'at': DateTime.now().toIso8601String(),
        'minutes': minutes,
        'until': snoozedUntil.toIso8601String(),
        'source': source,
      });

      final updatedTask = _task.copyWith(
        snoozedUntil: snoozedUntil,
        snoozeHistory: jsonEncode(history),
      );

      // IMPORTANT: `copyWith` returns a new object that is not attached to a Hive box,
      // so `.save()` would throw. Persist by updating the box via repository.
      await TaskRepository().updateTask(updatedTask);

      // Refresh task list providers so details screen sees the new values.
      ref.read(taskNotifierProvider.notifier).loadTasks();

      // Keep local snapshot coherent (only matters if popup stays open).
      if (mounted) {
        setState(() => _task = updatedTask);
      }
    } catch (e) {
      debugPrint('⚠️ TaskReminderPopup: Failed to persist snooze: $e');
    }
  }

  void _handleNotDone() async {
    HapticFeedback.lightImpact();
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Show reason sheet first (without closing popup yet)
    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _NotDoneReasonSheet(
        taskTitle: _task.title,
        isDark: isDark,
      ),
    );

    if (reason != null && mounted) {
      Navigator.pop(context); // Close popup after reason is selected
      
      try {
        await ref.read(taskNotifierProvider.notifier).markNotDone(_task.id, reason);
        await ReminderManager().cancelRemindersForTask(_task.id);
        _showSuccessSnackbar('Task marked as not done', const Color(0xFFE57373));
      } catch (e) {
        _showErrorSnackbar('Failed to update task');
      }
    }
  }

  void _handlePostpone() async {
    HapticFeedback.lightImpact();
    Navigator.pop(context);

    final newDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColorSchemes.primaryGold,
            ),
          ),
          child: child!,
        );
      },
    );

    if (newDate != null && mounted) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      // Use postpone reasons from settings (no hardcoded options)
      final reason = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => _PostponeReasonSheet(isDark: isDark),
      );

      if (reason != null && mounted) {
        int penalty = -5;
        if (widget.task.taskTypeId != null) {
          try {
            final taskType = await ref.read(taskTypeByIdProvider(widget.task.taskTypeId!).future);
            if (taskType != null) penalty = taskType.penaltyPostpone;
          } catch (_) {}
        }

        await ref.read(taskNotifierProvider.notifier).postponeTask(
          widget.task.id,
          newDate,
          reason,
          penalty: penalty,
        );
        await ReminderManager().cancelRemindersForTask(widget.task.id);
        _showSuccessSnackbar('Task moved to ${_formatDate(newDate)}', const Color(0xFFFFB347));
      }
    }
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) return '$hours hr';
    return '$hours hr $mins min';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = date.difference(DateTime(now.year, now.month, now.day)).inDays;
    if (diff == 1) return 'tomorrow';
    if (diff < 7) return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][date.weekday - 1];
    return '${date.month}/${date.day}';
  }

  void _showSuccessSnackbar(String message, Color color) {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return;
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return;
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

/// Modern action button with clean design
class _ModernButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isPrimary;
  final bool isLoading;
  final bool isSmall;
  final VoidCallback onTap;

  const _ModernButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isPrimary = false,
    this.isLoading = false,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Material(
        color: isPrimary ? color : color.withOpacity(isDark ? 0.12 : 0.08),
        child: InkWell(
          onTap: isLoading ? null : onTap,
          child: Container(
            padding: EdgeInsets.symmetric(
              vertical: isSmall ? 14 : 16, 
              horizontal: 4
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(isPrimary ? Colors.white : color),
                    ),
                  )
                else
                  Icon(
                    icon,
                    color: isPrimary ? Colors.white : color,
                    size: isSmall ? 17 : 19,
                  ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: isSmall ? 12 : 13,
                      fontWeight: FontWeight.w800,
                      color: isPrimary ? Colors.white : color,
                      letterSpacing: 0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Modern snooze options sheet
class _ModernSnoozeSheet extends StatelessWidget {
  final List<int> options;
  final int defaultOption;
  final bool isDark;

  const _ModernSnoozeSheet({
    required this.options,
    required this.defaultOption,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
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
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5C9CE6).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.snooze_rounded,
                    color: Color(0xFF5C9CE6),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  'Snooze for...',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1A1C1E),
                  ),
                ),
              ],
            ),
          ),

          // Scrollable options
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Options
                  ...options.map((minutes) {
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
                        color: isDefault ? const Color(0xFF5C9CE6) : (isDark ? Colors.white54 : Colors.black45),
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
                            color: const Color(0xFF5C9CE6).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Default',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF5C9CE6),
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

          // Custom duration
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                final customMinutes = await _showCustomSnoozeDialog(context);
                if (customMinutes != null && context.mounted) {
                  Navigator.pop(context, customMinutes);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                child: Row(
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      color: isDark ? Colors.white54 : Colors.black45,
                      size: 22,
                    ),
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
                    Icon(
                      Icons.chevron_right_rounded,
                      color: isDark ? Colors.white24 : Colors.black26,
                      size: 22,
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

          SafeArea(
            top: false,
            child: const SizedBox(height: 8),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '$minutes minutes';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) return '$hours ${hours == 1 ? 'hour' : 'hours'}';
    return '$hours hr $mins min';
  }

  Future<int?> _showCustomSnoozeDialog(BuildContext context) async {
    // NOTE: Controllers must live in a StatefulWidget and be disposed there.
    // Disposing them here can race with the bottom-sheet closing animation and
    // cause a brief red error screen ("TextEditingController used after disposed").
    return await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CustomSnoozeSheet(isDark: isDark),
    );
  }
}

class _CustomSnoozeSheet extends StatefulWidget {
  final bool isDark;
  const _CustomSnoozeSheet({required this.isDark});

  @override
  State<_CustomSnoozeSheet> createState() => _CustomSnoozeSheetState();
}

class _CustomSnoozeSheetState extends State<_CustomSnoozeSheet> {
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
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
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
                    style: const TextStyle(
                      color: Color(0xFFE57373),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
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
                          backgroundColor: const Color(0xFF5C9CE6),
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

/// Modern reason selection sheet
class _ModernReasonSheet extends StatelessWidget {
  final String title;
  final List<String> options;
  final bool isDark;

  const _ModernReasonSheet({
    required this.title,
    required this.options,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2026) : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColorSchemes.primaryGold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.help_outline_rounded,
                    color: AppColorSchemes.primaryGold,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1A1C1E),
                  ),
                ),
              ],
            ),
          ),

          // Options
          ...options.map((option) => Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.pop(context, option),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        option,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : const Color(0xFF1A1C1E),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: isDark ? Colors.white24 : Colors.black26,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          )),

          SafeArea(
            top: false,
            child: const SizedBox(height: 8),
          ),
        ],
      ),
    );
  }
}

/// Not Done reason sheet - fetches reasons from settings (notDoneReasonsProvider)
/// NO hardcoded reasons - all managed in Task Settings for proper reporting.
class _NotDoneReasonSheet extends ConsumerStatefulWidget {
  final String taskTitle;
  final bool isDark;

  const _NotDoneReasonSheet({
    required this.taskTitle,
    required this.isDark,
  });

  @override
  ConsumerState<_NotDoneReasonSheet> createState() => _NotDoneReasonSheetState();
}

class _NotDoneReasonSheetState extends ConsumerState<_NotDoneReasonSheet> {
  final TextEditingController _customReasonController = TextEditingController();
  bool _showCustomInput = false;

  @override
  void dispose() {
    _customReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final reasonsAsync = ref.watch(notDoneReasonsProvider);

    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomPadding),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1C2026) : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            decoration: BoxDecoration(
              color: const Color(0xFFE57373).withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE57373).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.assignment_late_rounded,
                        color: Color(0xFFE57373),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Why not done?',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: widget.isDark ? Colors.white : const Color(0xFF1A1C1E),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.taskTitle,
                            style: TextStyle(
                              fontSize: 13,
                              color: widget.isDark ? Colors.white54 : Colors.black45,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Reason options from settings (Not Done reasons only)
          if (!_showCustomInput) ...[
            reasonsAsync.when(
              data: (reasons) {
                if (reasons.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(Icons.info_outline, 
                            color: widget.isDark ? Colors.white38 : Colors.black38, 
                            size: 32),
                        const SizedBox(height: 12),
                        Text(
                          'No "Not Done" reasons configured.\nGo to Task Settings to add reasons.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: widget.isDark ? Colors.white54 : Colors.black45,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildReasonOption(
                          icon: Icons.edit_rounded,
                          text: 'Enter custom reason...',
                          color: AppColorSchemes.primaryGold,
                          onTap: () => setState(() => _showCustomInput = true),
                        ),
                      ],
                    ),
                  );
                }
                
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...reasons.map((reason) => _buildReasonOption(
                      icon: reason.icon ?? Icons.note_rounded,
                      text: reason.text,
                      color: const Color(0xFFE57373),
                    )),
                    _buildReasonOption(
                      icon: Icons.edit_rounded,
                      text: 'Other reason...',
                      color: AppColorSchemes.primaryGold,
                      onTap: () => setState(() => _showCustomInput = true),
                    ),
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: Color(0xFFE57373)),
              ),
              error: (_, __) => Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 32),
                    const SizedBox(height: 12),
                    Text('Error loading reasons',
                        style: TextStyle(color: widget.isDark ? Colors.white54 : Colors.black45)),
                    const SizedBox(height: 16),
                    _buildReasonOption(
                      icon: Icons.edit_rounded,
                      text: 'Enter custom reason...',
                      color: AppColorSchemes.primaryGold,
                      onTap: () => setState(() => _showCustomInput = true),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Custom reason input
          if (_showCustomInput) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _customReasonController,
                    autofocus: true,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Enter your reason...',
                      hintStyle: TextStyle(
                        color: widget.isDark ? Colors.white38 : Colors.black38,
                      ),
                      filled: true,
                      fillColor: widget.isDark 
                          ? Colors.white.withOpacity(0.05) 
                          : Colors.black.withOpacity(0.03),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    style: TextStyle(
                      color: widget.isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => setState(() => _showCustomInput = false),
                          child: Text(
                            'Back',
                            style: TextStyle(
                              color: widget.isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            final reason = _customReasonController.text.trim();
                            if (reason.isNotEmpty) {
                              Navigator.pop(context, reason);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE57373),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Submit',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          SafeArea(
            top: false,
            child: const SizedBox(height: 8),
          ),
        ],
      ),
    );
  }

  Widget _buildReasonOption({
    required IconData icon,
    required String text,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? () => Navigator.pop(context, text),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: widget.isDark ? Colors.white : const Color(0xFF1A1C1E),
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: widget.isDark ? Colors.white24 : Colors.black26,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Postpone reason sheet - fetches reasons from settings (postponeReasonsProvider)
/// NO hardcoded reasons - all managed in Task Settings for proper reporting.
class _PostponeReasonSheet extends ConsumerStatefulWidget {
  final bool isDark;

  const _PostponeReasonSheet({required this.isDark});

  @override
  ConsumerState<_PostponeReasonSheet> createState() => _PostponeReasonSheetState();
}

class _PostponeReasonSheetState extends ConsumerState<_PostponeReasonSheet> {
  final TextEditingController _customReasonController = TextEditingController();
  bool _showCustomInput = false;

  @override
  void dispose() {
    _customReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final reasonsAsync = ref.watch(postponeReasonsProvider);

    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomPadding),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1C2026) : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            decoration: BoxDecoration(
              color: AppColorSchemes.primaryGold.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColorSchemes.primaryGold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.event_available_rounded,
                    color: AppColorSchemes.primaryGold,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  'Why postpone?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: widget.isDark ? Colors.white : const Color(0xFF1A1C1E),
                  ),
                ),
              ],
            ),
          ),

          // Reason options from settings (Postpone reasons only)
          if (!_showCustomInput) ...[
            reasonsAsync.when(
              data: (reasons) {
                if (reasons.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(Icons.info_outline, 
                            color: widget.isDark ? Colors.white38 : Colors.black38, 
                            size: 32),
                        const SizedBox(height: 12),
                        Text(
                          'No "Postpone" reasons configured.\nGo to Task Settings to add reasons.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: widget.isDark ? Colors.white54 : Colors.black45,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildReasonOption(
                          icon: Icons.edit_rounded,
                          text: 'Enter custom reason...',
                          color: AppColorSchemes.primaryGold,
                          onTap: () => setState(() => _showCustomInput = true),
                        ),
                      ],
                    ),
                  );
                }
                
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...reasons.map((reason) => _buildReasonOption(
                      icon: reason.icon ?? Icons.event_available_rounded,
                      text: reason.text,
                      color: AppColorSchemes.primaryGold,
                    )),
                    _buildReasonOption(
                      icon: Icons.edit_rounded,
                      text: 'Other reason...',
                      color: AppColorSchemes.primaryGold,
                      onTap: () => setState(() => _showCustomInput = true),
                    ),
                  ],
                );
              },
              loading: () => Padding(
                padding: const EdgeInsets.all(24),
                child: CircularProgressIndicator(color: AppColorSchemes.primaryGold),
              ),
              error: (_, __) => Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 32),
                    const SizedBox(height: 12),
                    Text('Error loading reasons',
                        style: TextStyle(color: widget.isDark ? Colors.white54 : Colors.black45)),
                    const SizedBox(height: 16),
                    _buildReasonOption(
                      icon: Icons.edit_rounded,
                      text: 'Enter custom reason...',
                      color: AppColorSchemes.primaryGold,
                      onTap: () => setState(() => _showCustomInput = true),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Custom reason input
          if (_showCustomInput) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _customReasonController,
                    autofocus: true,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Enter your reason...',
                      hintStyle: TextStyle(
                        color: widget.isDark ? Colors.white38 : Colors.black38,
                      ),
                      filled: true,
                      fillColor: widget.isDark 
                          ? Colors.white.withOpacity(0.05) 
                          : Colors.black.withOpacity(0.03),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    style: TextStyle(
                      color: widget.isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => setState(() => _showCustomInput = false),
                          child: Text(
                            'Back',
                            style: TextStyle(
                              color: widget.isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            final reason = _customReasonController.text.trim();
                            if (reason.isNotEmpty) {
                              Navigator.pop(context, reason);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColorSchemes.primaryGold,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Submit',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          SafeArea(
            top: false,
            child: const SizedBox(height: 8),
          ),
        ],
      ),
    );
  }

  Widget _buildReasonOption({
    required IconData icon,
    required String text,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? () => Navigator.pop(context, text),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: widget.isDark ? Colors.white : const Color(0xFF1A1C1E),
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: widget.isDark ? Colors.white24 : Colors.black26,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
