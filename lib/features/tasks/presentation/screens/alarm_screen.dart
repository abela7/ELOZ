import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/color_schemes.dart';
import '../../../../core/services/alarm_service.dart';
import '../../../../core/services/reminder_manager.dart';
import '../../../../core/providers/notification_settings_provider.dart';
import '../../../../core/notifications/models/notification_hub_modules.dart';
import '../../../../data/models/task.dart';
import '../../../../data/models/subtask.dart';
import '../../../../core/models/reminder.dart';
import '../../../../data/repositories/task_repository.dart';
import '../../../../features/habits/data/models/habit.dart';
import '../../../../features/habits/data/models/habit_notification_settings.dart';
import '../../../../features/habits/data/repositories/habit_repository.dart';
import '../../../../features/habits/presentation/providers/habit_providers.dart';
import '../../../../features/habits/presentation/widgets/skip_reason_dialog.dart';
import '../../../../routing/app_router.dart';
import '../providers/task_providers.dart';
import '../providers/task_type_providers.dart';
import '../providers/task_reason_providers.dart';

/// Platform channel for system-level operations
const _systemChannel = MethodChannel('com.eloz.life_manager/system');

/// Modern full-screen alarm screen for special task reminders.
/// 
/// This screen provides the SAME functionality as TaskReminderPopup but in
/// a full-screen alarm UI that:
/// - Completely immersive - hides all system UI and app navigation
/// - Rings like an alarm (bypasses silent mode)
/// - Shows task details and interactive subtasks
/// 
/// Features (when taskId is provided):
/// - Done: Mark task as complete with points and cancel reminders
/// - Snooze: Quick snooze with configurable duration from settings
/// - More: Show additional snooze duration options
/// - Not Done: Mark task as not done with reason tracking
/// - Postpone: Reschedule task to another date
/// - Dismiss: Just close the alarm without any action
/// 
/// When taskId is NOT provided (test alarms, fallback), only basic
/// Done/Snooze buttons are shown with simplified behavior.
class AlarmScreen extends ConsumerStatefulWidget {
  final String title;
  final String body;
  final String? taskId;
  final int? alarmId;
  final int? iconCodePoint;
  final String? iconFontFamily;
  final String? iconFontPackage;
  final VoidCallback? onDismiss;
  /// Optional callback for legacy snooze handling (used by test alarm in settings)
  /// When provided, the simple snooze button will call this instead of the full snooze flow
  final VoidCallback? onSnooze;

  const AlarmScreen({
    super.key,
    required this.title,
    required this.body,
    this.taskId,
    this.alarmId,
    this.iconCodePoint,
    this.iconFontFamily,
    this.iconFontPackage,
    this.onDismiss,
    this.onSnooze,
  });

  /// Show alarm screen as a full-screen overlay that covers everything
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String body,
    String? taskId,
    int? alarmId,
    int? iconCodePoint,
    String? iconFontFamily,
    String? iconFontPackage,
    VoidCallback? onDismiss,
    VoidCallback? onSnooze,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: true,
        barrierDismissible: false,
        pageBuilder: (context, animation, secondaryAnimation) => AlarmScreen(
          title: title,
          body: body,
          taskId: taskId,
          alarmId: alarmId,
          iconCodePoint: iconCodePoint,
          iconFontFamily: iconFontFamily,
          iconFontPackage: iconFontPackage,
          onDismiss: onDismiss,
          onSnooze: onSnooze,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  @override
  ConsumerState<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends ConsumerState<AlarmScreen> with TickerProviderStateMixin {
  late AnimationController _glowController;
  late AnimationController _scaleController;
  late Animation<double> _glowAnimation;
  late Animation<double> _scaleAnimation;
  
  /// The loaded task (null if taskId not provided or loading failed)
  Task? _task;

  /// The loaded habit (null if this alarm is for a task or loading failed)
  Habit? _habit;
  
  /// Whether task data is being loaded
  bool _isLoading = true;
  
  /// Whether an action is being processed (prevents double-taps)
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    
    // Complete immersive full screen - hide everything
    _enterFullScreen();
    
    // Load task data if taskId is provided
    _loadTask();
    
    // Subtle glow animation for the icon
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    
    _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    
    // Scale animation for icon
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }
  
  /// Load task or habit data from repository
  /// 
  /// This tries (in order):
  /// 1) Direct taskId (if provided)
  /// 2) Resolve by alarmId using module-aware ID ranges
  /// 3) Fallback legacy scan (task first, then habit) if range is unknown
  /// 
  /// NOTE: We avoid touching the alarm system itself; this is a safe, UI-only
  /// lookup to restore full functionality (Done/Not Done/Postpone/Skip/etc).
  Future<void> _loadTask() async {
    try {
      Task? task;
      Habit? habit;
      
      if (widget.taskId != null) {
        task = await TaskRepository().getTaskById(widget.taskId!);
      }

      // If no explicit taskId provided, resolve by alarmId.
      // Notification IDs now live in module-specific ranges:
      // task: 1..99999, habit: 100000..199999.
      if (task == null && widget.alarmId != null) {
        final alarmId = widget.alarmId!;
        final inferredModule = _moduleIdForAlarmId(alarmId);

        if (inferredModule == NotificationHubModuleIds.task) {
          task = await _findTaskByAlarmId(alarmId);
        } else if (inferredModule == NotificationHubModuleIds.habit) {
          habit = await _findHabitByAlarmId(alarmId);
        } else {
          // Legacy fallback (pre-range IDs): best-effort scan.
          task = await _findTaskByAlarmId(alarmId);
          if (task == null) {
            habit = await _findHabitByAlarmId(alarmId);
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _task = task;
          _habit = habit;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('⚠️ AlarmScreen: Failed to load task/habit: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Find the task that owns the given alarmId
  /// 
  /// Alarm IDs for task reminders are generated from:
  ///   taskId + reminder fingerprint
  /// 
  /// This method reconstructs those IDs to find the matching task.
  /// Keep the ID algorithm in sync with NotificationService._generateNotificationId.
  Future<Task?> _findTaskByAlarmId(int alarmId) async {
    final tasks = await TaskRepository().getAllTasks();
    
    for (final task in tasks) {
      final reminders = task.reminders;
      if (reminders.isEmpty) continue;
      
      for (final reminder in reminders) {
        final candidateId = _notificationIdFor(task.id, reminder);
        if (candidateId == alarmId) {
          return task;
        }
      }
    }
    
    return null;
  }

  /// Find the habit that owns the given alarmId
  ///
  /// Habit alarm IDs include a date component:
  ///   habitId + reminder fingerprint + YYYYMMDD
  ///
  /// We try all rolling-window dates (today + 14 days) to find a match.
  Future<Habit?> _findHabitByAlarmId(int alarmId) async {
    final habits = await HabitRepository().getAllHabits();

    // We need to test multiple dates because habit IDs include the date
    final now = DateTime.now();
    final dates = List.generate(15, (i) => DateTime(now.year, now.month, now.day).add(Duration(days: i)));

    for (final habit in habits) {
      if (!habit.reminderEnabled) continue;

      final reminders = _parseHabitReminders(habit.reminderDuration);
      if (reminders.isEmpty) continue;

      for (final reminder in reminders) {
        for (final date in dates) {
          if (!habit.isDueOn(date)) continue;
          final candidateId = _notificationIdForHabit(habit.id, reminder, date);
          if (candidateId == alarmId) {
            return habit;
          }
        }
      }
    }

    return null;
  }

  /// Parse reminder duration string to Reminder objects (mirrors HabitReminderService)
  List<Reminder> _parseHabitReminders(String? reminderDuration) {
    if (reminderDuration == null || reminderDuration.isEmpty) return [];

    final normalized = reminderDuration.trim();
    if (normalized.isEmpty) return [];

    // New format: JSON list
    if (normalized.startsWith('[')) {
      try {
        return Reminder.decodeList(normalized).where((r) => r.enabled).toList();
      } catch (_) {
        return [];
      }
    }

    if (normalized.toLowerCase() == 'no reminder') return [];

    if (normalized.contains('5 min before') || normalized.contains('5 minutes before')) {
      return [Reminder.fiveMinutesBefore()];
    }
    if (normalized.contains('15 min before') || normalized.contains('15 minutes before')) {
      return [Reminder.fifteenMinutesBefore()];
    }
    if (normalized.contains('30 min before') || normalized.contains('30 minutes before')) {
      return [Reminder.thirtyMinutesBefore()];
    }
    if (normalized.contains('1 hour before') || normalized.contains('1 hr before')) {
      return [Reminder.oneHourBefore()];
    }
    if (normalized.contains('1 day before')) {
      return [Reminder.oneDayBefore()];
    }
    if (normalized.toLowerCase() == 'at task time' ||
        normalized.toLowerCase() == 'at habit time' ||
        normalized.toLowerCase() == 'on time') {
      return [Reminder.atTaskTime()];
    }
    if (normalized.startsWith('Custom:')) {
      return _parseCustomReminder(normalized);
    }

    return [Reminder.fiveMinutesBefore()];
  }

  List<Reminder> _parseCustomReminder(String reminderString) {
    final reminders = <Reminder>[];
    final customPart = reminderString.substring(8).trim();
    final hourMatch = RegExp(r'(\\d+)\\s*h').firstMatch(customPart);
    final minuteMatch = RegExp(r'(\\d+)\\s*m').firstMatch(customPart);

    if (hourMatch != null || minuteMatch != null) {
      int totalMinutes = 0;
      if (hourMatch != null) {
        totalMinutes += int.parse(hourMatch.group(1)!) * 60;
      }
      if (minuteMatch != null) {
        totalMinutes += int.parse(minuteMatch.group(1)!);
      }
      if (totalMinutes > 0) {
        reminders.add(Reminder(
          type: 'before',
          value: totalMinutes,
          unit: 'minutes',
        ));
      }
    }

    return reminders.isNotEmpty ? reminders : [Reminder.fiveMinutesBefore()];
  }

  /// Generate notification ID for a habit (includes date component)
  /// IMPORTANT: Keep this in sync with NotificationService._generateNotificationId.
  int _notificationIdForHabit(String habitId, Reminder reminder, DateTime date) {
    final customMs = reminder.customDateTime?.millisecondsSinceEpoch;
    final base = customMs != null
        ? '$habitId-${reminder.type}-custom-$customMs'
        : '$habitId-${reminder.type}-${reminder.value}-${reminder.unit}';
    final dateKey = '${date.year.toString().padLeft(4, '0')}'
        '${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}';
    final combined = '$base-$dateKey';
    return _mapHashToModuleRange(
      combined.hashCode.abs(),
      NotificationHubModuleIds.habit,
    );
  }

  /// Replicates NotificationService._generateNotificationId
  /// IMPORTANT: Keep this in sync with NotificationService implementation.
  int _notificationIdFor(String taskId, Reminder reminder) {
    final customMs = reminder.customDateTime?.millisecondsSinceEpoch;
    final combined = customMs != null
        ? '$taskId-${reminder.type}-custom-$customMs'
        : '$taskId-${reminder.type}-${reminder.value}-${reminder.unit}';
    return _mapHashToModuleRange(
      combined.hashCode.abs(),
      NotificationHubModuleIds.task,
    );
  }

  /// Keep module inference aligned with NotificationHubIdRanges.
  String? _moduleIdForAlarmId(int alarmId) {
    if (alarmId >= NotificationHubIdRanges.taskStart &&
        alarmId <= NotificationHubIdRanges.taskEnd) {
      return NotificationHubModuleIds.task;
    }
    if (alarmId >= NotificationHubIdRanges.habitStart &&
        alarmId <= NotificationHubIdRanges.habitEnd) {
      return NotificationHubModuleIds.habit;
    }
    return null;
  }

  /// Keep hash->ID mapping aligned with NotificationService._generateNotificationId.
  int _mapHashToModuleRange(int hash, String moduleId) {
    late final int rangeStart;
    late final int rangeSize;

    if (moduleId == NotificationHubModuleIds.habit) {
      rangeStart = NotificationHubIdRanges.habitStart;
      rangeSize =
          NotificationHubIdRanges.habitEnd - NotificationHubIdRanges.habitStart + 1;
    } else {
      rangeStart = NotificationHubIdRanges.taskStart;
      rangeSize =
          NotificationHubIdRanges.taskEnd - NotificationHubIdRanges.taskStart + 1;
    }

    return rangeStart + (hash % rangeSize);
  }

  void _enterFullScreen() {
    // Hide status bar, navigation bar, and set to immersive sticky
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [], // Hide all system overlays
    );
    // Also set the system UI overlay style
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
    );
  }

  void _exitFullScreen() {
    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    _scaleController.dispose();
    _exitFullScreen();
    super.dispose();
  }
  
  /// Stop the alarm sound/vibration
  Future<void> _stopAlarm() async {
    if (widget.alarmId != null) {
      await AlarmService().stopRinging(widget.alarmId!);
    }
  }
  
  /// Close the alarm screen securely
  /// If the device is locked, finish the app entirely to return to lock screen
  /// This prevents unauthorized access to the app from the lock screen
  Future<void> _closeSecurely() async {
    try {
      // Check if device is locked
      final isLocked = await _systemChannel.invokeMethod<bool>('isDeviceLocked') ?? false;
      
      if (isLocked) {
        // Device is locked - finish the app to return to lock screen
        // This prevents unauthorized access to the app
        await _systemChannel.invokeMethod('finishIfLocked');
        
        // Also pop just in case finishIfLocked doesn't work on some devices
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
        // Device is unlocked - just close the alarm screen normally
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      // Fallback: just pop the screen
      debugPrint('Error checking lock state: $e');
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  /// Whether this alarm is for a habit (not a task).
  bool get _isHabitAlarm => _habit != null;

  /// Whether we have a loaded entity (task or habit).
  bool get _hasEntity => _task != null || _habit != null;

  /// Effective title from the loaded entity.
  String get _entityTitle => _task?.title ?? _habit?.title ?? widget.title;

  /// Effective description from the loaded entity.
  String get _entityDescription =>
      _task?.description ?? _habit?.description ?? widget.body;

  IconData get _taskIcon {
    // Use task icon if available
    if (_task?.iconCodePoint != null) {
      return IconData(
        _task!.iconCodePoint!,
        fontFamily: _task!.iconFontFamily ?? 'MaterialIcons',
        fontPackage: _task!.iconFontPackage,
      );
    }
    // Use habit icon if available
    if (_habit?.iconCodePoint != null) {
      return IconData(
        _habit!.iconCodePoint!,
        fontFamily: _habit!.iconFontFamily ?? 'MaterialIcons',
        fontPackage: _habit!.iconFontPackage,
      );
    }
    // Fall back to provided icon
    if (widget.iconCodePoint != null) {
      return IconData(
        widget.iconCodePoint!,
        fontFamily: widget.iconFontFamily ?? 'MaterialIcons',
        fontPackage: widget.iconFontPackage,
      );
    }
    // Default fallback icon
    return Icons.notifications_active_rounded;
  }

  // ============================================================================
  // ACTION HANDLERS
  // ============================================================================

  /// Handle Done button - Mark task as complete
  /// 
  /// This mirrors TaskReminderPopup._handleDone():
  /// - Marks task as completed with points
  /// - Cancels all remaining reminders
  /// - Clears alarm data
  Future<void> _handleDone() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();
    
    await _stopAlarm();

    final isFallbackAlarm = (widget.alarmId ?? 0) <= 0 && widget.taskId == null;
    if (!_hasEntity && !isFallbackAlarm) {
      debugPrint(
        '⚠️ AlarmScreen: Done tapped but no linked task/habit found for alarmId=${widget.alarmId}',
      );
      if (mounted) {
        setState(() => _isProcessing = false);
        _showErrorSnackbar('Could not find linked task/habit');
      }
      return;
    }

    try {
      if (_habit != null) {
        // Guard: don't double-complete if habit was already done today
        final repository = HabitRepository();
        final today = DateTime.now();
        final todayCompletions = await repository.getCompletionsForDate(_habit!.id, today);
        final alreadyCompleted = todayCompletions.any((c) => !c.isSkipped && c.count > 0);

        if (!alreadyCompleted) {
          // Use the provider — handles correct points for every habit type
          // (yesNo, numeric, timer, quit), checks isActiveOn, sets proper
          // answer/actualValue fields, updates stats, and refreshes UI state.
          await ref.read(habitNotifierProvider.notifier)
              .completeHabitForDate(_habit!.id, today);

          await ReminderManager().cancelRemindersForHabit(_habit!.id);
          debugPrint('✅ AlarmScreen: Habit "${_habit!.title}" marked complete!');
        }
      } else if (_task != null) {
        // Mark task as complete using the task notifier
        await ref.read(taskNotifierProvider.notifier).completeTask(_task!.id);
        
        // Cancel all remaining reminders for this task
        await ReminderManager().cancelRemindersForTask(_task!.id);
        
        debugPrint('✅ AlarmScreen: Task "${_task!.title}" marked complete!');
      }
      
      widget.onDismiss?.call();
      await _closeSecurely();
      final label = _isHabitAlarm ? 'Habit' : 'Task';
      _showSuccessSnackbar('$label completed! 🎉', const Color(0xFF4CAF50));
    } catch (e) {
      debugPrint('⚠️ AlarmScreen: Error completing: $e');
      if (mounted) {
        setState(() => _isProcessing = false);
        _showErrorSnackbar('Failed to complete');
      }
    }
  }
  
  /// Handle quick snooze with default duration from settings
  /// 
  /// This mirrors TaskReminderPopup._handleQuickSnooze():
  /// - Persists snooze state to task
  /// - Reschedules alarm
  /// 
  /// If [widget.onSnooze] is provided (legacy test alarm flow), 
  /// it will be called instead of the full snooze flow.
  Future<void> _handleQuickSnooze(int minutes) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    HapticFeedback.lightImpact();
    
    await _stopAlarm();
    
    // Legacy callback for test alarms from settings screen
    if (widget.onSnooze != null) {
      widget.onSnooze!.call();
      await _closeSecurely();
      return;
    }

    final isFallbackAlarm = (widget.alarmId ?? 0) <= 0 && widget.taskId == null;
    if (!_hasEntity && !isFallbackAlarm) {
      debugPrint(
        '⚠️ AlarmScreen: Snooze tapped but no linked task/habit found for alarmId=${widget.alarmId}',
      );
      if (mounted) {
        setState(() => _isProcessing = false);
        _showErrorSnackbar('Could not find linked task/habit');
      }
      return;
    }
    
    try {
      // Persist snooze state to task/habit if available
      if (_habit != null) {
        await _persistSnoozeToHabit(minutes, source: 'alarm_quick');
      } else if (_task != null) {
        await _persistSnoozeToTask(minutes, source: 'alarm_quick');
      }
      
      // Reschedule the alarm
      final snoozeTime = DateTime.now().add(Duration(minutes: minutes));
      final snoozeCount = _snoozeCountForToday();
      final snoozedBody = _buildSnoozedBody(
        snoozedUntil: snoozeTime,
        snoozeCount: snoozeCount,
      );
      final snoozePayload = _buildSnoozePayload(
        minutes: minutes,
        snoozeCount: snoozeCount,
      );

      // Use habit settings if this is a habit alarm
      String soundId;
      String vibrationPatternId;
      bool showFullscreen;
      if (_isHabitAlarm) {
        final habitSettings = await _loadHabitSettings();
        soundId = habitSettings.specialHabitSound;
        vibrationPatternId = habitSettings.specialHabitVibrationPattern;
        showFullscreen = habitSettings.specialHabitAlarmMode;
      } else {
        final settings = ref.read(notificationSettingsProvider);
        soundId = settings.specialTaskSound;
        vibrationPatternId = settings.specialTaskVibrationPattern;
        showFullscreen = settings.specialTaskAlarmMode;
      }
      
      await AlarmService().scheduleSpecialTaskAlarm(
        id: widget.alarmId ?? DateTime.now().millisecondsSinceEpoch % 2147483647,
        title: _entityTitle,
        body: snoozedBody,
        scheduledTime: snoozeTime,
        soundId: soundId,
        vibrationPatternId: vibrationPatternId,
        showFullscreen: showFullscreen,
        payload: snoozePayload,
        iconCodePoint: _habit?.iconCodePoint ?? _task?.iconCodePoint ?? widget.iconCodePoint,
        iconFontFamily: _habit?.iconFontFamily ?? _task?.iconFontFamily ?? widget.iconFontFamily,
        iconFontPackage: _habit?.iconFontPackage ?? _task?.iconFontPackage ?? widget.iconFontPackage,
      );
      
      debugPrint('⏰ AlarmScreen: Snoozed for $minutes minutes');
      
      widget.onDismiss?.call();
      await _closeSecurely();
      _showSuccessSnackbar('Snoozed for $minutes minutes', const Color(0xFF5C9CE6));
    } catch (e) {
      debugPrint('⚠️ AlarmScreen: Error snoozing: $e');
      if (mounted) {
        setState(() => _isProcessing = false);
        _showErrorSnackbar('Failed to snooze');
      }
    }
  }
  
  /// Show snooze options sheet
  /// 
  /// This mirrors TaskReminderPopup._handleSnoozeOptions()
  Future<void> _handleSnoozeOptions() async {
    HapticFeedback.lightImpact();

    List<int> options;
    int defaultOption;
    if (_isHabitAlarm) {
      final habitSettings = await _loadHabitSettings();
      options = habitSettings.snoozeOptions;
      defaultOption = habitSettings.defaultSnoozeDuration;
    } else {
      final settings = ref.read(notificationSettingsProvider);
      options = settings.snoozeOptions;
      defaultOption = settings.defaultSnoozeDuration;
    }
    
    final minutes = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _AlarmSnoozeSheet(
        options: options,
        defaultOption: defaultOption,
      ),
    );
    
    if (minutes != null && mounted) {
      await _handleQuickSnooze(minutes);
    }
  }
  
  /// Handle Not Done button
  /// 
  /// EXACTLY mirrors TaskReminderPopup._handleNotDone():
  /// 1. Show reason selection sheet
  /// 2. Mark task as not done with reason via provider
  /// 3. Cancel notifications
  Future<void> _handleNotDone() async {
    if (_task == null) return;
    HapticFeedback.lightImpact();
    
    // Show reason sheet (same as TaskReminderPopup)
    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _AlarmNotDoneReasonSheet(
        taskTitle: _task!.title,
      ),
    );
    
    // If user selected a reason, mark task as not done
    if (reason != null && mounted) {
      setState(() => _isProcessing = true);
      
      // Stop the alarm first
      await _stopAlarm();
      
      try {
        // EXACT same call as TaskReminderPopup - use the provider directly
        await ref.read(taskNotifierProvider.notifier).markNotDone(_task!.id, reason);
        await ReminderManager().cancelRemindersForTask(_task!.id);
        
        debugPrint('❌ AlarmScreen: Task "${_task!.title}" marked as not done with reason: $reason');
        
        widget.onDismiss?.call();
        await _closeSecurely();
        _showSuccessSnackbar('Task marked as not done', const Color(0xFFE57373));
      } catch (e) {
        debugPrint('⚠️ AlarmScreen: Error marking not done: $e');
        if (mounted) {
          setState(() => _isProcessing = false);
          _showErrorSnackbar('Failed to update task');
        }
      }
    }
  }
  
  /// Handle Postpone button
  /// 
  /// This mirrors TaskReminderPopup._handlePostpone():
  /// - Shows date picker
  /// - Shows reason selection
  /// - Postpones task to new date
  Future<void> _handlePostpone() async {
    if (_task == null) return;
    HapticFeedback.lightImpact();
    
    // Show date picker
    final newDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColorSchemes.primaryGold,
              surface: Color(0xFF1C2026),
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (newDate != null && mounted) {
      // Show reason sheet (from settings - postponeReasonsProvider)
      final reason = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => const _AlarmPostponeReasonSheet(),
      );
      
      if (reason != null && mounted) {
        setState(() => _isProcessing = true);
        
        await _stopAlarm();
        
        try {
          // Get penalty from task type if available
          int penalty = -5;
          if (_task!.taskTypeId != null) {
            try {
              final taskType = await ref.read(taskTypeByIdProvider(_task!.taskTypeId!).future);
              if (taskType != null) penalty = taskType.penaltyPostpone;
            } catch (_) {}
          }
          
          await ref.read(taskNotifierProvider.notifier).postponeTask(
            _task!.id,
            newDate,
            reason,
            penalty: penalty,
          );
          await ReminderManager().cancelRemindersForTask(_task!.id);
          
          debugPrint('📅 AlarmScreen: Task postponed to $newDate');
          
          widget.onDismiss?.call();
          await _closeSecurely();
          _showSuccessSnackbar('Task moved to ${_formatDate(newDate)}', const Color(0xFFFFB347));
        } catch (e) {
          debugPrint('⚠️ AlarmScreen: Error postponing: $e');
          if (mounted) {
            setState(() => _isProcessing = false);
            _showErrorSnackbar('Failed to postpone task');
          }
        }
      }
    }
  }
  
  /// Handle Dismiss - just close without any action
  Future<void> _handleDismiss() async {
    HapticFeedback.lightImpact();
    await _stopAlarm();
    widget.onDismiss?.call();
    await _closeSecurely();
  }
  
  /// Persist snooze state to task (for snooze history tracking)
  Future<void> _persistSnoozeToTask(int minutes, {required String source}) async {
    if (_task == null) return;
    
    try {
      final snoozedUntil = DateTime.now().add(Duration(minutes: minutes));
      
      // Build history list (append-only)
      List<Map<String, dynamic>> history = [];
      final rawHistory = (_task!.snoozeHistory ?? '').trim();
      if (rawHistory.isNotEmpty) {
        try {
          history = List<Map<String, dynamic>>.from(jsonDecode(rawHistory));
        } catch (_) {
          history = [];
        }
      }
      
      final now = DateTime.now();
      final occurrenceDate = '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';

      history.add({
        'at': now.toIso8601String(),
        'minutes': minutes,
        'until': snoozedUntil.toIso8601String(),
        'occurrenceDate': occurrenceDate,
        'source': source,
        'alarmId': widget.alarmId,
      });
      
      final updatedTask = _task!.copyWith(
        snoozedUntil: snoozedUntil,
        snoozeHistory: jsonEncode(history),
      );
      
      await TaskRepository().updateTask(updatedTask);
      
      // Refresh task list providers
      ref.read(taskNotifierProvider.notifier).loadTasks();
      
      // Update local state
      if (mounted) {
        setState(() => _task = updatedTask);
      }
      
      debugPrint('⏰ AlarmScreen: Snooze persisted to task (history=${history.length})');
    } catch (e) {
      debugPrint('⚠️ AlarmScreen: Failed to persist snooze: $e');
    }
  }

  /// Persist snooze state to habit (for snooze history tracking)
  Future<void> _persistSnoozeToHabit(int minutes, {required String source}) async {
    if (_habit == null) return;

    try {
      final snoozedUntil = DateTime.now().add(Duration(minutes: minutes));

      List<Map<String, dynamic>> history = [];
      final rawHistory = (_habit!.snoozeHistory ?? '').trim();
      if (rawHistory.isNotEmpty) {
        try {
          history = List<Map<String, dynamic>>.from(jsonDecode(rawHistory));
        } catch (_) {
          history = [];
        }
      }

      final now = DateTime.now();
      final occurrenceDate = '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';

      history.add({
        'at': now.toIso8601String(),
        'minutes': minutes,
        'until': snoozedUntil.toIso8601String(),
        'occurrenceDate': occurrenceDate,
        'source': source,
        'alarmId': widget.alarmId,
      });

      final updatedHabit = _habit!.copyWith(
        snoozedUntil: snoozedUntil,
        snoozeHistory: jsonEncode(history),
      );

      await HabitRepository().updateHabit(updatedHabit);
      ref.read(habitNotifierProvider.notifier).loadHabits();

      if (mounted) {
        setState(() => _habit = updatedHabit);
      }

      debugPrint('⏰ AlarmScreen: Snooze persisted to habit (history=${history.length})');
    } catch (e) {
      debugPrint('⚠️ AlarmScreen: Failed to persist snooze to habit: $e');
    }
  }

  int _snoozeCountForToday() {
    final raw = ((_habit?.snoozeHistory) ?? (_task?.snoozeHistory) ?? '').trim();
    if (raw.isEmpty) return 0;

    final now = DateTime.now();
    final todayKey = '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return 0;

      var count = 0;
      for (final entry in decoded) {
        if (entry is! Map) continue;
        final map = Map<String, dynamic>.from(entry);

        final occurrenceDate = map['occurrenceDate'] as String?;
        if (occurrenceDate != null && occurrenceDate == todayKey) {
          count++;
          continue;
        }

        final at = map['at'] as String?;
        if (at == null || at.isEmpty) continue;
        final dt = DateTime.tryParse(at);
        if (dt == null) continue;
        if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
          count++;
        }
      }
      return count;
    } catch (_) {
      return 0;
    }
  }

  String _buildSnoozedBody({
    required DateTime snoozedUntil,
    required int snoozeCount,
  }) {
    final hh = snoozedUntil.hour.toString().padLeft(2, '0');
    final mm = snoozedUntil.minute.toString().padLeft(2, '0');
    return '(Snoozed) $snoozeCount - $hh:$mm';
  }

  String _buildSnoozePayload({
    required int minutes,
    required int snoozeCount,
  }) {
    if (_habit != null) {
      return 'habit|${_habit!.id}|snooze|$minutes|minutes|snoozeCount:$snoozeCount';
    }
    if (_task != null) {
      return 'task|${_task!.id}|snooze|$minutes|minutes|snoozeCount:$snoozeCount';
    }
    return '';
  }

  /// Load habit notification settings
  Future<HabitNotificationSettings> _loadHabitSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(habitNotificationSettingsKey);
    if (jsonString != null) {
      return HabitNotificationSettings.fromJsonString(jsonString);
    }
    return HabitNotificationSettings.defaults;
  }

  /// Handle Skip action for habits (habit-only action)
  ///
  /// Mirrors HabitReminderPopup._handleSkip():
  /// 1. Show skip reason dialog so the user can explain why
  /// 2. Route through habitNotifierProvider.skipHabitForDate —
  ///    handles noPoints deduction for yesNo habits, isActiveOn guard,
  ///    proper addCompletionWithPoints, stats update, and UI refresh.
  /// 3. Cancel remaining reminders for the day
  Future<void> _handleSkipHabit() async {
    if (_isProcessing || _habit == null) return;
    HapticFeedback.lightImpact();

    // Ask the user for a reason (same dialog the popup uses)
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reason = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (context) => SkipReasonDialog(
        isDark: isDark,
        habitName: _habit!.title,
      ),
    );

    // User cancelled the dialog — do nothing
    if (reason == null || !mounted) return;

    setState(() => _isProcessing = true);
    await _stopAlarm();

    try {
      // Use the provider — handles noPoints deduction for yesNo habits,
      // isActiveOn guard, proper stats/streak update, and UI state refresh.
      await ref.read(habitNotifierProvider.notifier)
          .skipHabitForDate(_habit!.id, DateTime.now(), reason: reason);

      await ReminderManager().cancelRemindersForHabit(_habit!.id);

      debugPrint('⏭️ AlarmScreen: Habit "${_habit!.title}" skipped!');

      widget.onDismiss?.call();
      await _closeSecurely();
      _showSuccessSnackbar('Habit skipped', const Color(0xFFFFB347));
    } catch (e) {
      debugPrint('⚠️ AlarmScreen: Error skipping habit: $e');
      if (mounted) {
        setState(() => _isProcessing = false);
        _showErrorSnackbar('Failed to skip habit');
      }
    }
  }
  
  /// Toggle subtask completion
  Future<void> _toggleSubtask(int index) async {
    if (_task?.subtasks == null || index >= _task!.subtasks!.length) return;
    
    HapticFeedback.lightImpact();
    
    // Update local state immediately
    setState(() {
      _task!.subtasks![index].isCompleted = !_task!.subtasks![index].isCompleted;
    });
    
    // Persist to database
    try {
      await _task!.save();
      ref.read(taskNotifierProvider.notifier).loadTasks();
    } catch (e) {
      debugPrint('⚠️ AlarmScreen: Error saving subtask: $e');
    }
  }
  
  // ============================================================================
  // HELPER METHODS
  // ============================================================================
  
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

  // ============================================================================
  // BUILD METHODS
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(notificationSettingsProvider);
    final hasTask = _hasEntity; // true if task OR habit loaded
    final hasSubtasks = _task?.subtasks != null && _task!.subtasks!.isNotEmpty;
    
    return PopScope(
      canPop: false, // Prevent back button from closing
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0F),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF151520),
                Color(0xFF0A0A0F),
                Color(0xFF0A0A0F),
              ],
            ),
          ),
          child: Stack(
            children: [
              // Animated glow effect behind icon
              Positioned(
                top: MediaQuery.of(context).size.height * 0.08,
                left: 0,
                right: 0,
                child: AnimatedBuilder(
                  animation: _glowAnimation,
                  builder: (context, child) {
                    return Center(
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColorSchemes.primaryGold.withOpacity(_glowAnimation.value * 0.5),
                              blurRadius: 80,
                              spreadRadius: 20,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              // Main content - scrollable
              SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    top: 20,
                    bottom: MediaQuery.of(context).padding.bottom + 20,
                    left: 24,
                    right: 24,
                  ),
                  child: Column(
                    children: [
                      // Task Icon with golden outline (indicates special task)
                      AnimatedBuilder(
                        animation: _scaleAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _scaleAnimation.value,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF1A1A25),
                                border: Border.all(
                                  color: AppColorSchemes.primaryGold,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColorSchemes.primaryGold.withOpacity(0.3),
                                    blurRadius: 30,
                                    spreadRadius: 5,
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.5),
                                    blurRadius: 15,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Icon(
                                _taskIcon,
                                size: 56,
                                color: AppColorSchemes.primaryGold,
                              ),
                            ),
                          );
                        },
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Special Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColorSchemes.primaryGold.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColorSchemes.primaryGold.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: AppColorSchemes.primaryGold,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isHabitAlarm ? 'SPECIAL HABIT' : 'SPECIAL TASK',
                              style: TextStyle(
                                color: AppColorSchemes.primaryGold,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Task/Habit Title
                      Text(
                        _entityTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          height: 1.2,
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Task/Habit Body/Description
                      if (_entityDescription.isNotEmpty)
                        Text(
                          _entityDescription,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            height: 1.4,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),

                      // Habit "Why" factor (motivation), if available
                      if (_habit?.motivation != null &&
                          _habit!.motivation!.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          '"${_habit!.motivation!.trim()}"',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      
                      const SizedBox(height: 24),
                      
                      // Current Time Display
                      _buildTimeDisplay(),
                      
                      const SizedBox(height: 24),
                      
                      // Interactive Subtasks (if task loaded and has subtasks)
                      if (hasSubtasks) ...[
                        _buildSubtasksList(),
                        const SizedBox(height: 24),
                      ],
                      
                      // Action Buttons
                      _buildActionButtons(settings, hasTask),
                      
                      const SizedBox(height: 16),
                      
                      // Dismiss option
                      TextButton(
                        onPressed: _handleDismiss,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white38,
                        ),
                        child: const Text(
                          'Dismiss',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Loading overlay
              if (_isLoading)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(AppColorSchemes.primaryGold),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeDisplay() {
    final now = DateTime.now();
    final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '$hour:$minute',
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 56,
                fontWeight: FontWeight.w100,
                letterSpacing: -3,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              period,
              style: TextStyle(
                color: Colors.white.withOpacity(0.35),
                fontSize: 22,
                fontWeight: FontWeight.w300,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _formatDateDisplay(),
          style: TextStyle(
            color: Colors.white.withOpacity(0.25),
            fontSize: 13,
            fontWeight: FontWeight.w400,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  String _formatDateDisplay() {
    final now = DateTime.now();
    final days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    final months = ['January', 'February', 'March', 'April', 'May', 'June', 
                    'July', 'August', 'September', 'October', 'November', 'December'];
    return '${days[now.weekday % 7]}, ${months[now.month - 1]} ${now.day}';
  }
  
  /// Build interactive subtasks list
  Widget _buildSubtasksList() {
    if (_task?.subtasks == null) return const SizedBox.shrink();
    
    final subtasks = _task!.subtasks!;
    final completed = subtasks.where((s) => s.isCompleted).length;
    final total = subtasks.length;
    final progress = total > 0 ? completed / total : 0.0;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with progress
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Icon(
                  Icons.checklist_rounded,
                  size: 18,
                  color: AppColorSchemes.primaryGold,
                ),
                const SizedBox(width: 8),
                Text(
                  'Subtasks',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColorSchemes.primaryGold.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$completed / $total',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColorSchemes.primaryGold,
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
                backgroundColor: Colors.white.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation(AppColorSchemes.primaryGold),
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Subtask items (max 5 shown)
          ...subtasks.take(5).toList().asMap().entries.map((entry) {
            return _buildSubtaskItem(entry.value, entry.key);
          }),
          
          if (subtasks.length > 5)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(
                '+${subtasks.length - 5} more',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.4),
                ),
              ),
            ),
          
          const SizedBox(height: 8),
        ],
      ),
    );
  }
  
  Widget _buildSubtaskItem(Subtask subtask, int index) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _toggleSubtask(index),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              // Animated checkbox
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: subtask.isCompleted 
                      ? AppColorSchemes.primaryGold 
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: subtask.isCompleted 
                        ? AppColorSchemes.primaryGold 
                        : Colors.white.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: subtask.isCompleted
                    ? const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: Colors.black,
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
                        ? Colors.white.withOpacity(0.4)
                        : Colors.white.withOpacity(0.9),
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

  /// Build action buttons
  /// 
  /// For TASKS (hasTask = true, !_isHabitAlarm):
  /// - Done + Quick Snooze (primary row)
  /// - More + Not Done + Postpone (secondary row)
  ///
  /// For HABITS (_isHabitAlarm = true):
  /// - Done + Quick Snooze (primary row)
  /// - More + Skip (secondary row)
  /// 
  /// When entity is NOT loaded, shows simplified buttons:
  /// - Done + Snooze (like original AlarmScreen)
  Widget _buildActionButtons(dynamic settings, bool hasTask) {
    // Quick snooze defaults to 5 minutes for special task/habit alarms
    const int quickSnoozeDuration = 5;
    
    if (!hasTask) {
      // Simplified buttons when entity not loaded
      return Row(
        children: [
          // Done Button
          Expanded(
            child: _AlarmButton(
              label: 'Done',
              icon: Icons.check_rounded,
              color: const Color(0xFF4CAF50),
              isPrimary: true,
              isLoading: _isProcessing,
              onTap: _handleDone,
            ),
          ),
          const SizedBox(width: 12),
          // Snooze Button - 5 min quick snooze
          Expanded(
            child: _AlarmButton(
              label: '${quickSnoozeDuration}m',
              icon: Icons.snooze_rounded,
              color: const Color(0xFF5C9CE6),
              isPrimary: true,
              onTap: () => _handleQuickSnooze(quickSnoozeDuration),
            ),
          ),
        ],
      );
    }

    // ── Habit-specific buttons ──
    if (_isHabitAlarm) {
      return Column(
        children: [
          // Primary row: Done + Quick Snooze
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _AlarmButton(
                  icon: Icons.check_rounded,
                  label: 'Done',
                  color: const Color(0xFF4CAF50),
                  isPrimary: true,
                  isLoading: _isProcessing,
                  onTap: _handleDone,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _AlarmButton(
                  icon: Icons.snooze_rounded,
                  label: '${quickSnoozeDuration}m',
                  color: const Color(0xFF5C9CE6),
                  isPrimary: true,
                  onTap: () => _handleQuickSnooze(quickSnoozeDuration),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Secondary row: More + Skip
          Row(
            children: [
              Expanded(
                child: _AlarmButton(
                  icon: Icons.more_time_rounded,
                  label: 'More',
                  color: const Color(0xFF5C9CE6),
                  isSmall: true,
                  onTap: _handleSnoozeOptions,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AlarmButton(
                  icon: Icons.skip_next_rounded,
                  label: 'Skip',
                  color: const Color(0xFFFFB347),
                  isSmall: true,
                  onTap: _handleSkipHabit,
                ),
              ),
            ],
          ),
        ],
      );
    }
    
    // ── Task-specific buttons ──
    return Column(
      children: [
        // Primary row: Done + Quick Snooze
        Row(
          children: [
            // Done button - green for success
            Expanded(
              flex: 3,
              child: _AlarmButton(
                icon: Icons.check_rounded,
                label: 'Done',
                color: const Color(0xFF4CAF50),
                isPrimary: true,
                isLoading: _isProcessing,
                onTap: _handleDone,
              ),
            ),
            const SizedBox(width: 12),
            // Quick snooze - 5 min default for special tasks
            Expanded(
              flex: 2,
              child: _AlarmButton(
                icon: Icons.snooze_rounded,
                label: '${quickSnoozeDuration}m',
                color: const Color(0xFF5C9CE6),
                isPrimary: true,
                onTap: () => _handleQuickSnooze(quickSnoozeDuration),
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
              child: _AlarmButton(
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
              child: _AlarmButton(
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
              child: _AlarmButton(
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
    );
  }
}

// =============================================================================
// ALARM BUTTON WIDGET
// =============================================================================

/// Modern action button for alarm screen
/// 
/// Styled for dark background with glow effects
class _AlarmButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isPrimary;
  final bool isLoading;
  final bool isSmall;
  final VoidCallback onTap;

  const _AlarmButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isPrimary = false,
    this.isLoading = false,
    this.isSmall = false,
  });

  @override
  State<_AlarmButton> createState() => _AlarmButtonState();
}

class _AlarmButtonState extends State<_AlarmButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        if (!widget.isLoading) widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: widget.isSmall ? 52 : 60,
        transform: Matrix4.identity()..scale(_isPressed ? 0.96 : 1.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: widget.isPrimary 
              ? widget.color 
              : widget.color.withOpacity(0.15),
          border: widget.isPrimary 
              ? null 
              : Border.all(
                  color: widget.color.withOpacity(0.3),
                  width: 1,
                ),
          boxShadow: widget.isPrimary 
              ? [
                  BoxShadow(
                    color: widget.color.withOpacity(_isPressed ? 0.2 : 0.4),
                    blurRadius: _isPressed ? 8 : 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.isLoading)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(
                    widget.isPrimary ? Colors.white : widget.color,
                  ),
                ),
              )
            else
              Icon(
                widget.icon,
                size: widget.isSmall ? 18 : 22,
                color: widget.isPrimary 
                    ? Colors.white 
                    : widget.color,
              ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                widget.label,
                style: TextStyle(
                  color: widget.isPrimary 
                      ? Colors.white 
                      : widget.color,
                  fontSize: widget.isSmall ? 13 : 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// SNOOZE OPTIONS SHEET
// =============================================================================

/// Snooze options sheet for alarm screen
/// 
/// Dark themed to match alarm screen aesthetic
/// Snooze options sheet for alarm screen with extended options
/// 
/// Includes:
/// - Quick options: 1, 3, 5, 10, 15, 30, 60 minutes
/// - Custom duration picker for any amount
/// - Dark themed to match alarm screen aesthetic
class _AlarmSnoozeSheet extends StatefulWidget {
  final List<int> options;
  final int defaultOption;

  const _AlarmSnoozeSheet({
    required this.options,
    required this.defaultOption,
  });

  @override
  State<_AlarmSnoozeSheet> createState() => _AlarmSnoozeSheetState();
}

class _AlarmSnoozeSheetState extends State<_AlarmSnoozeSheet> {
  bool _showCustomInput = false;
  final TextEditingController _customController = TextEditingController();
  String? _errorText;
  
  // Extended snooze options - always include these for special task alarms
  // User's settings options are merged with these defaults
  static const List<int> _extendedOptions = [1, 3, 5, 10, 15, 30, 60];
  
  List<int> get _allOptions {
    // Merge user settings options with extended options, remove duplicates, sort
    final Set<int> merged = {..._extendedOptions, ...widget.options};
    final sorted = merged.toList()..sort();
    return sorted;
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomPadding),
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.85, // Max 85% of screen height
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2026),
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
                    color: const Color(0xFF5C9CE6).withOpacity(0.2),
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
                  _showCustomInput ? 'Custom snooze' : 'Snooze for...',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Scrollable content area
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_showCustomInput) ...[
            // Preset Options
            ..._allOptions.map((minutes) {
              final isDefault = minutes == widget.defaultOption;
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.pop(context, minutes),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Row(
                      children: [
                        Icon(
                          isDefault ? Icons.timer_rounded : Icons.timer_outlined,
                          color: isDefault 
                              ? const Color(0xFF5C9CE6) 
                              : Colors.white54,
                          size: 22,
                        ),
                        const SizedBox(width: 14),
                        Text(
                          _formatDuration(minutes),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isDefault ? FontWeight.w700 : FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            
            // Custom option
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _showCustomInput = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.edit_rounded,
                        color: AppColorSchemes.primaryGold,
                        size: 22,
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Custom...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColorSchemes.primaryGold,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white24,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ] else ...[
            // Custom input mode
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter minutes (1-999)',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white54,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _customController,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Minutes',
                      hintStyle: TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.08),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      suffixText: 'min',
                      suffixStyle: TextStyle(color: Colors.white54, fontSize: 16),
                    ),
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _errorText!,
                      style: const TextStyle(
                        color: Color(0xFFE57373),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => setState(() {
                            _showCustomInput = false;
                            _errorText = null;
                            _customController.clear();
                          }),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white54,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Back', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _submitCustom,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5C9CE6),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('Snooze', style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
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
  
  void _submitCustom() {
    final text = _customController.text.trim();
    final minutes = int.tryParse(text);
    
    if (minutes == null || minutes < 1) {
      setState(() => _errorText = 'Please enter a valid number (1 or more)');
      return;
    }
    
    if (minutes > 999) {
      setState(() => _errorText = 'Maximum is 999 minutes');
      return;
    }
    
    Navigator.pop(context, minutes);
  }

  String _formatDuration(int minutes) {
    if (minutes == 1) return '1 minute';
    if (minutes < 60) return '$minutes minutes';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) return '$hours ${hours == 1 ? 'hour' : 'hours'}';
    return '$hours hr $mins min';
  }
}

// =============================================================================
// NOT DONE REASON SHEET
// =============================================================================

/// Not Done reason selection sheet for alarm screen
/// 
/// Fetches reasons from settings (notDoneReasonsProvider) - NO hardcoded reasons!
/// All reasons are managed in Task Settings for proper reporting.
class _AlarmNotDoneReasonSheet extends ConsumerStatefulWidget {
  final String taskTitle;

  const _AlarmNotDoneReasonSheet({
    required this.taskTitle,
  });

  @override
  ConsumerState<_AlarmNotDoneReasonSheet> createState() => _AlarmNotDoneReasonSheetState();
}

class _AlarmNotDoneReasonSheetState extends ConsumerState<_AlarmNotDoneReasonSheet> {
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
        color: const Color(0xFF1C2026),
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
                        color: const Color(0xFFE57373).withOpacity(0.2),
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
                          const Text(
                            'Why not done?',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.taskTitle,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white54,
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
                // If no reasons configured, show message to set them up
                if (reasons.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(Icons.info_outline, color: Colors.white38, size: 32),
                        const SizedBox(height: 12),
                        Text(
                          'No "Not Done" reasons configured.\nGo to Task Settings to add reasons.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white54,
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
                
                // Show reasons from settings
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...reasons.map((reason) => _buildReasonOption(
                      icon: reason.icon ?? Icons.note_rounded,
                      text: reason.text,
                      color: const Color(0xFFE57373), // Red theme for Not Done
                    )),
                    
                    // Custom reason option
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
                    Text(
                      'Error loading reasons',
                      style: TextStyle(color: Colors.white54),
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
                      hintStyle: TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => setState(() => _showCustomInput = false),
                          child: Text(
                            'Back',
                            style: TextStyle(color: Colors.white54),
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
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white24,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// POSTPONE REASON SHEET
// =============================================================================

/// Postpone reason selection sheet for alarm screen
/// 
/// Fetches reasons from settings (postponeReasonsProvider) - NO hardcoded reasons!
/// All reasons are managed in Task Settings for proper reporting.
class _AlarmPostponeReasonSheet extends ConsumerStatefulWidget {
  const _AlarmPostponeReasonSheet();

  @override
  ConsumerState<_AlarmPostponeReasonSheet> createState() => _AlarmPostponeReasonSheetState();
}

class _AlarmPostponeReasonSheetState extends ConsumerState<_AlarmPostponeReasonSheet> {
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
        color: const Color(0xFF1C2026),
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
                    color: AppColorSchemes.primaryGold.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.event_available_rounded,
                    color: AppColorSchemes.primaryGold,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                const Text(
                  'Why postpone?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Reason options from settings (Postpone reasons only)
          if (!_showCustomInput) ...[
            reasonsAsync.when(
              data: (reasons) {
                // If no reasons configured, show message
                if (reasons.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(Icons.info_outline, color: Colors.white38, size: 32),
                        const SizedBox(height: 12),
                        Text(
                          'No "Postpone" reasons configured.\nGo to Task Settings to add reasons.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white54,
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
                
                // Show reasons from settings
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...reasons.map((reason) => _buildReasonOption(
                      icon: reason.icon ?? Icons.event_available_rounded,
                      text: reason.text,
                      color: AppColorSchemes.primaryGold, // Gold theme for Postpone
                    )),
                    
                    // Custom reason option
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
                    Text(
                      'Error loading reasons',
                      style: TextStyle(color: Colors.white54),
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
                      hintStyle: TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => setState(() => _showCustomInput = false),
                          child: Text(
                            'Back',
                            style: TextStyle(color: Colors.white54),
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
                          child: const Text('Submit', style: TextStyle(fontWeight: FontWeight.w800)),
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
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white24,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
