import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/task.dart';
import '../../data/repositories/task_repository.dart';
import '../../features/habits/data/models/habit.dart';
import '../../features/habits/data/models/habit_notification_settings.dart';
import '../../features/habits/data/repositories/habit_repository.dart';
import '../../features/habits/presentation/widgets/habit_reminder_popup.dart';
import '../../features/tasks/presentation/widgets/task_reminder_popup.dart';
import '../../routing/app_router.dart';
import '../notifications/models/notification_hub_modules.dart';
import '../notifications/models/notification_hub_payload.dart';
import '../notifications/notification_hub.dart';
import '../notifications/services/notification_activity_logger.dart';
import '../notifications/services/notification_flow_trace.dart';
import '../notifications/services/notification_module_policy.dart';
import '../models/notification_settings.dart';
import 'notification_service.dart';

/// Notification Handler - Handles notification actions and shows popups
///
/// Supports:
/// - Tap to open task/habit detail
/// - Mark Done action
/// - Snooze action with configurable duration from user settings
class NotificationHandler {
  static final NotificationHandler _instance = NotificationHandler._internal();
  factory NotificationHandler() => _instance;
  NotificationHandler._internal();

  static const MethodChannel _systemChannel = MethodChannel(
    'com.eloz.life_manager/system',
  );
  static const String _pendingPayloadKey = 'pending_notification_payload';
  static const String _pendingActionKey = 'pending_notification_action';
  static const String _pendingIdKey = 'pending_notification_id';
  static const String _pendingStoredAtKey =
      'pending_notification_stored_at_ms_v1';
  static const String _processedDeferredSignaturesKey =
      'processed_deferred_notification_signatures_v1';
  static const Duration _deferredReplayTtl = Duration(hours: 24);
  static const Duration _maxDeferredAge = Duration(hours: 6);

  /// Load notification settings from SharedPreferences
  Future<NotificationSettings> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('notification_settings');
    if (jsonString != null) {
      return NotificationSettings.fromJsonString(jsonString);
    }
    return NotificationSettings.defaults;
  }

  Future<HabitNotificationSettings> _loadHabitSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(habitNotificationSettingsKey);
    if (jsonString != null) {
      return HabitNotificationSettings.fromJsonString(jsonString);
    }
    return HabitNotificationSettings.defaults;
  }

  NotificationSettings _mapHabitToNotificationSettings(
    HabitNotificationSettings habitSettings,
  ) {
    return NotificationSettings(
      notificationsEnabled: habitSettings.notificationsEnabled,
      soundEnabled: habitSettings.soundEnabled,
      vibrationEnabled: habitSettings.vibrationEnabled,
      ledEnabled: habitSettings.ledEnabled,
      taskRemindersEnabled: habitSettings.habitRemindersEnabled,
      urgentRemindersEnabled: habitSettings.urgentRemindersEnabled,
      silentRemindersEnabled: habitSettings.silentRemindersEnabled,
      defaultSound: habitSettings.defaultSound,
      taskRemindersSound: habitSettings.habitRemindersSound,
      urgentRemindersSound: habitSettings.urgentRemindersSound,
      defaultVibrationPattern: habitSettings.defaultVibrationPattern,
      defaultChannel: habitSettings.defaultChannel,
      notificationAudioStream: habitSettings.notificationAudioStream,
      alwaysUseAlarmForSpecialTasks:
          habitSettings.alwaysUseAlarmForSpecialHabits,
      specialTaskSound: habitSettings.specialHabitSound,
      specialTaskVibrationPattern: habitSettings.specialHabitVibrationPattern,
      specialTaskAlarmMode: habitSettings.specialHabitAlarmMode,
      allowUrgentDuringQuietHours: habitSettings.allowSpecialDuringQuietHours,
      quietHoursEnabled: habitSettings.quietHoursEnabled,
      quietHoursStart: habitSettings.quietHoursStart,
      quietHoursEnd: habitSettings.quietHoursEnd,
      quietHoursDays: habitSettings.quietHoursDays,
      showOnLockScreen: habitSettings.showOnLockScreen,
      wakeScreen: habitSettings.wakeScreen,
      persistentNotifications: habitSettings.persistentNotifications,
      groupNotifications: habitSettings.groupNotifications,
      notificationTimeout: habitSettings.notificationTimeout,
      defaultSnoozeDuration: habitSettings.defaultSnoozeDuration,
      snoozeOptions: habitSettings.snoozeOptions,
      maxSnoozeCount: habitSettings.maxSnoozeCount,
      smartSnooze: habitSettings.smartSnooze,
    );
  }

  Future<bool> _isDeviceLocked() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _systemChannel.invokeMethod<bool>('isDeviceLocked') ?? false;
    } catch (e) {
      debugPrint(
        'NotificationHandler: WARNING: Failed to check device lock state: $e',
      );
      return false;
    }
  }

  Future<void> _storePending({
    required String payload,
    String? actionId,
    int? notificationId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingPayloadKey, payload);
      await prefs.setString(_pendingActionKey, actionId ?? '');
      if (notificationId != null) {
        await prefs.setInt(_pendingIdKey, notificationId);
      } else {
        await prefs.remove(_pendingIdKey);
      }
      await prefs.setInt(
        _pendingStoredAtKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      debugPrint(
        'NotificationHandler: WARNING: Failed to store pending payload: $e',
      );
    }
  }

  Future<Map<String, dynamic>?> _takePending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Sync with any native writes (e.g., Alarm/Media/Ring notification taps).
      try {
        await prefs.reload();
      } catch (_) {
        // Best-effort; proceed with cached values if reload fails.
      }
      final payload = prefs.getString(_pendingPayloadKey);
      if (payload == null || payload.isEmpty) return null;
      await prefs.remove(_pendingPayloadKey);
      final actionId = prefs.getString(_pendingActionKey) ?? '';
      final notificationId = prefs.getInt(_pendingIdKey);
      final storedAtMs = prefs.getInt(_pendingStoredAtKey);
      await prefs.remove(_pendingActionKey);
      await prefs.remove(_pendingIdKey);
      await prefs.remove(_pendingStoredAtKey);
      return {
        'payload': payload,
        'actionId': actionId,
        'notificationId': notificationId,
        'storedAtMs': storedAtMs,
      };
    } catch (e) {
      debugPrint(
        'NotificationHandler: WARNING: Failed to read pending payload: $e',
      );
      return null;
    }
  }

  /// Call this on app resume to continue a deferred notification tap
  Future<void> processPendingTapIfUnlocked() async {
    final pending = await _takePending();
    if (pending == null) return;

    final isLocked = await _isDeviceLocked();
    if (isLocked) {
      // Still locked -> keep it pending.
      await _storePending(
        payload: pending['payload'] as String,
        actionId: pending['actionId'] as String?,
        notificationId: pending['notificationId'] as int?,
      );
      return;
    }

    final payload = pending['payload'] as String;
    final actionId = (pending['actionId'] as String?) ?? '';
    final notificationId = pending['notificationId'] as int?;
    final storedAtMs = pending['storedAtMs'] as int?;
    final parsed = NotificationHubPayload.tryParse(payload);

    if (parsed != null) {
      final policy = await NotificationModulePolicy.read(parsed.moduleId);
      if (!policy.enabled) {
        NotificationFlowTrace.log(
          event: 'deferred_skip',
          sourceFlow: 'deferred_unlock',
          moduleId: parsed.moduleId,
          entityId: parsed.entityId,
          reason: policy.reason,
        );
        return;
      }
      final exists = await _entityStillExists(parsed.moduleId, parsed.entityId);
      if (!exists) {
        NotificationFlowTrace.log(
          event: 'deferred_skip',
          sourceFlow: 'deferred_unlock',
          moduleId: parsed.moduleId,
          entityId: parsed.entityId,
          reason: 'entity_deleted',
        );
        return;
      }
    }

    if (storedAtMs != null) {
      final ageMs = DateTime.now().millisecondsSinceEpoch - storedAtMs;
      if (ageMs > _maxDeferredAge.inMilliseconds) {
        NotificationFlowTrace.log(
          event: 'deferred_skip',
          sourceFlow: 'deferred_unlock',
          moduleId: parsed?.moduleId,
          entityId: parsed?.entityId,
          reason: 'deferred_stale',
          details: <String, dynamic>{'ageMs': ageMs},
        );
        return;
      }
    }

    final stillActive = await _isPendingNotificationStillActive(
      payload: payload,
      notificationId: notificationId,
    );
    if (!stillActive) {
      NotificationFlowTrace.log(
        event: 'deferred_skip',
        sourceFlow: 'deferred_unlock',
        moduleId: parsed?.moduleId,
        entityId: parsed?.entityId,
        reason: 'notification_inactive',
      );
      return;
    }

    final signature = _deferredSignature(payload, actionId, notificationId);
    if (await _isDeferredReplay(signature)) {
      NotificationFlowTrace.log(
        event: 'deferred_skip',
        sourceFlow: 'deferred_unlock',
        moduleId: parsed?.moduleId,
        entityId: parsed?.entityId,
        reason: 'replay_detected',
        notificationId: notificationId,
      );
      return;
    }
    await _markDeferredProcessed(signature);

    debugPrint(
      'NotificationHandler: Device unlocked, resuming deferred notification tap/action',
    );
    if (actionId.isNotEmpty) {
      await _handleNotificationAction(actionId, payload, notificationId);
    } else {
      await _handleNotificationTap(payload, notificationId: notificationId);
    }
  }

  /// Handle when a notification response is received (tap or action)
  void handleNotificationResponse(NotificationResponse response) async {
    final payload = response.payload;
    if (payload == null) return;

    debugPrint(
      'NotificationHandler: Handling notification with payload: $payload',
    );
    debugPrint('   Action ID: ${response.actionId}');
    debugPrint('   Notification ID: ${response.id}');

    final isLocked = await _isDeviceLocked();

    // Action button press.
    if (response.actionId != null && response.actionId!.isNotEmpty) {
      if (isLocked) {
        NotificationFlowTrace.log(
          event: 'deferred_store',
          sourceFlow: 'locked_response',
          reason: 'device_locked_action',
          notificationId: response.id,
        );
        await _storePending(
          payload: payload,
          actionId: response.actionId,
          notificationId: response.id,
        );
        return;
      }
      await _handleNotificationAction(response.actionId!, payload, response.id);
      return;
    }

    // Tap on body.
    if (isLocked) {
      NotificationFlowTrace.log(
        event: 'deferred_store',
        sourceFlow: 'locked_response',
        reason: 'device_locked_tap',
        notificationId: response.id,
      );
      await _storePending(payload: payload, notificationId: response.id);
      return;
    }

    await _handleNotificationTap(payload, notificationId: response.id);
  }

  /// Handle notification action (Mark Done, Snooze, View, etc.)
  ///
  /// All actions are routed through the Notification Hub when the payload
  /// parses as a hub payload (moduleId|entityId|...). This ensures a single,
  /// robust routing path for all modules (Finance, Task, Habit, Sleep, etc.).
  Future<void> _handleNotificationAction(
    String actionId,
    String payload,
    int? notificationId,
  ) async {
    debugPrint('NotificationHandler: Processing action "$actionId"');

    final parsed = NotificationHubPayload.tryParse(payload);
    if (parsed == null) {
      debugPrint('NotificationHandler: WARNING: Invalid payload format');
      return;
    }

    final moduleId = parsed.moduleId;
    final entityId = parsed.entityId;
    final policy = await NotificationModulePolicy.read(moduleId);
    if (!policy.enabled) {
      NotificationFlowTrace.log(
        event: 'notification_action_skip',
        sourceFlow: 'notification_action',
        moduleId: moduleId,
        entityId: entityId,
        reason: policy.reason,
        notificationId: notificationId,
      );
      return;
    }
    final exists = await _entityStillExists(moduleId, entityId);
    if (!exists) {
      NotificationFlowTrace.log(
        event: 'notification_action_skip',
        sourceFlow: 'notification_action',
        moduleId: moduleId,
        entityId: entityId,
        reason: 'entity_deleted',
        notificationId: notificationId,
      );
      return;
    }

    // â”€â”€ Snooze â”€â”€
    if (actionId == 'snooze' || actionId.startsWith('snooze_')) {
      int? minutes;
      if (actionId.startsWith('snooze_')) {
        minutes = int.tryParse(actionId.substring('snooze_'.length));
      }
      // Task/habit: use legacy handler for snooze state persistence (snoozedUntil, snoozeHistory)
      if (moduleId == 'task' || moduleId == 'habit') {
        await _handleSnooze(
          moduleId,
          entityId,
          payload,
          notificationId,
          overrideMinutes: minutes,
        );
      } else {
        final snoozed = await NotificationHub().snooze(
          payload: payload,
          title: 'Snoozed Reminder',
          body: '',
          notificationId: notificationId,
          customDurationMinutes: minutes,
        );
        if (snoozed) {
          debugPrint(
            'NotificationHandler: Hub notification snoozed for module "$moduleId"',
          );
        } else {
          debugPrint(
            'NotificationHandler: WARNING: Hub snooze failed for module "$moduleId"',
          );
        }
      }
      return;
    }

    // â”€â”€ All other actions: route through Hub to module adapter â”€â”€
    final handledByHub = await NotificationHub().handleNotificationAction(
      actionId: actionId,
      payload: payload,
      notificationId: notificationId,
    );
    if (!handledByHub) {
      debugPrint(
        'NotificationHandler: WARNING: No hub adapter handled "$actionId" for module "$moduleId"',
      );
    }
  }

  /// Handle Snooze action from notification button
  /// Uses the default snooze duration from user settings
  Future<void> _handleSnooze(
    String type,
    String id,
    String payload,
    int? notificationId, {
    int? overrideMinutes,
  }) async {
    debugPrint('NotificationHandler: Snoozing $type $id from notification');

    try {
      HabitNotificationSettings? habitSettings;
      NotificationSettings settings;
      if (type == 'habit') {
        habitSettings = await _loadHabitSettings();
        settings = _mapHabitToNotificationSettings(habitSettings);
      } else {
        settings = await _loadSettings();
      }

      final snoozeDuration = overrideMinutes ?? settings.defaultSnoozeDuration;
      final snoozedUntil = DateTime.now().add(
        Duration(minutes: snoozeDuration),
      );

      debugPrint(
        'NotificationHandler: Using snooze duration from settings: $snoozeDuration minutes',
      );

      String title = 'Reminder';
      String body = '';
      String? priority;

      if (type == 'habit') {
        final repository = HabitRepository();
        final habit = await repository.getHabitById(id);
        if (habit != null) {
          title = habit.title;
          body = habit.description ?? 'Time for your habit!';

          // Persist snooze state + history for professional UX (visible on Habit Details).
          int nextSnoozeCount = 1;
          final match = RegExp(r'snoozeCount:(\d+)').firstMatch(payload);
          if (match != null) {
            nextSnoozeCount = int.parse(match.group(1)!) + 1;
          }

          List<Map<String, dynamic>> history = [];
          final rawHistory = (habit.snoozeHistory ?? '').trim();
          if (rawHistory.isNotEmpty) {
            try {
              history = List<Map<String, dynamic>>.from(jsonDecode(rawHistory));
            } catch (_) {
              history = [];
            }
          }

          final now = DateTime.now();
          final occurrenceDate =
              '${now.year.toString().padLeft(4, '0')}-'
              '${now.month.toString().padLeft(2, '0')}-'
              '${now.day.toString().padLeft(2, '0')}';

          history.add({
            'at': now.toIso8601String(),
            'minutes': snoozeDuration,
            'until': snoozedUntil.toIso8601String(),
            'occurrenceDate': occurrenceDate,
            'count': nextSnoozeCount,
            'source': 'notification',
            'notificationId': notificationId,
            'payload': payload,
          });

          final updatedHabit = habit.copyWith(
            snoozedUntil: snoozedUntil,
            snoozeHistory: jsonEncode(history),
          );
          await repository.updateHabit(updatedHabit);
          debugPrint(
            'NotificationHandler: Habit snoozedUntil saved: $snoozedUntil (history=${history.length})',
          );
        }
      } else {
        final repository = TaskRepository();
        try {
          final task = await repository.getTaskById(id);
          if (task == null) {
            debugPrint(
              'NotificationHandler: WARNING: Task not found for snooze',
            );
          } else {
            title = task.title;
            body = task.description ?? '';
            priority = task.priority;

            // Persist snooze state + history for professional UX (visible on Task Details).
            int nextSnoozeCount = 1;
            final match = RegExp(r'snoozeCount:(\d+)').firstMatch(payload);
            if (match != null) {
              nextSnoozeCount = int.parse(match.group(1)!) + 1;
            }

            List<Map<String, dynamic>> history = [];
            final rawHistory = (task.snoozeHistory ?? '').trim();
            if (rawHistory.isNotEmpty) {
              try {
                history = List<Map<String, dynamic>>.from(
                  jsonDecode(rawHistory),
                );
              } catch (_) {
                history = [];
              }
            }

            history.add({
              'at': DateTime.now().toIso8601String(),
              'minutes': snoozeDuration,
              'until': snoozedUntil.toIso8601String(),
              'count': nextSnoozeCount,
              'source': 'notification',
              'notificationId': notificationId,
              'payload': payload,
            });

            final updatedTask = task.copyWith(
              snoozedUntil: snoozedUntil,
              snoozeHistory: jsonEncode(history),
            );
            await repository.updateTask(updatedTask);
            debugPrint(
              'NotificationHandler: Task snoozedUntil saved: $snoozedUntil (history=${history.length})',
            );
          }
        } catch (e) {
          debugPrint(
            'NotificationHandler: WARNING: Failed to persist snooze state: $e',
          );
        }
      }

      // Schedule snoozed notification with user's default duration
      await NotificationService().snoozeNotification(
        taskId: id,
        title: title,
        body: body,
        payload: payload,
        customDurationMinutes: snoozeDuration,
        priority: priority,
        originalNotificationId: notificationId,
        settingsOverride: settings,
        notificationKindLabel: type == 'habit' ? 'Habit' : 'Task',
        channelKeyOverride: habitSettings?.defaultChannel,
      );

      // Inform the Hub about the snooze so it appears in the history log.
      unawaited(
        NotificationActivityLogger().logSnoozed(
          moduleId: type, // 'task' or 'habit'
          entityId: id,
          title: title,
          body: body,
          payload: payload,
          snoozeDurationMinutes: snoozeDuration,
        ),
      );

      debugPrint('NotificationHandler: Snoozed for $snoozeDuration minutes');
    } catch (e, stack) {
      debugPrint('NotificationHandler: WARNING: Error snoozing: $e');
      debugPrint('   Stack: $stack');
    }
  }

  /// Handle notification tap - show popup
  Future<void> _handleNotificationTap(
    String payload, {
    int? notificationId,
  }) async {
    final parsed = NotificationHubPayload.tryParse(payload);
    final handledByHub = await NotificationHub().handleNotificationTap(
      payload,
      notificationId: notificationId,
    );
    if (handledByHub) {
      return;
    }

    if (parsed != null) {
      final policy = await NotificationModulePolicy.read(parsed.moduleId);
      if (!policy.enabled) {
        NotificationFlowTrace.log(
          event: 'notification_tap_skip',
          sourceFlow: 'notification_tap',
          moduleId: parsed.moduleId,
          entityId: parsed.entityId,
          reason: policy.reason,
          notificationId: notificationId,
        );
        return;
      }

      final exists = await _entityStillExists(parsed.moduleId, parsed.entityId);
      if (!exists) {
        NotificationFlowTrace.log(
          event: 'notification_tap_skip',
          sourceFlow: 'notification_tap',
          moduleId: parsed.moduleId,
          entityId: parsed.entityId,
          reason: 'entity_deleted',
          notificationId: notificationId,
        );
        return;
      }

      if (parsed.moduleId != NotificationHubModuleIds.task &&
          parsed.moduleId != NotificationHubModuleIds.habit) {
        return;
      }
    }

    // Legacy fallback when no adapter handled tap for task/habit payloads.
    final parts = payload.split('|');
    final type = parsed?.moduleId ?? (parts.isNotEmpty ? parts.first : '');
    final id = parsed?.entityId ?? (parts.length > 1 ? parts[1] : '');
    if (type.isEmpty || id.isEmpty) return;

    try {
      if (type == 'habit') {
        final habit = await _getHabitById(id);
        if (habit != null) {
          unawaited(
            NotificationActivityLogger().logTapped(
              moduleId: 'habit',
              entityId: id,
              title: habit.title,
              body: '',
            ),
          );
          _showHabitReminderPopup(habit);
        }
      } else if (type == 'task') {
        final task = await _getTaskById(id);
        if (task != null) {
          unawaited(
            NotificationActivityLogger().logTapped(
              moduleId: 'task',
              entityId: id,
              title: task.title,
              body: '',
            ),
          );
          _showReminderPopup(task);
        }
      }
    } catch (e) {
      debugPrint('NotificationHandler: Error getting $type: $e');
    }
  }

  String _deferredSignature(
    String payload,
    String actionId,
    int? notificationId,
  ) {
    return '$payload|action:$actionId|id:${notificationId ?? -1}';
  }

  Future<Map<String, int>> _loadProcessedDeferredSignatures() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = (prefs.getString(_processedDeferredSignaturesKey) ?? '').trim();
    if (raw.isEmpty) return <String, int>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return <String, int>{};
      final map = <String, int>{};
      decoded.forEach((k, v) {
        if (k.isEmpty) return;
        if (v is int) {
          map[k] = v;
        } else if (v is num) {
          map[k] = v.toInt();
        }
      });
      return map;
    } catch (_) {
      return <String, int>{};
    }
  }

  Future<void> _saveProcessedDeferredSignatures(Map<String, int> map) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_processedDeferredSignaturesKey, jsonEncode(map));
  }

  Future<bool> _isDeferredReplay(String signature) async {
    final map = await _loadProcessedDeferredSignatures();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final ttlMs = _deferredReplayTtl.inMilliseconds;
    map.removeWhere((_, ts) => nowMs - ts > ttlMs);
    await _saveProcessedDeferredSignatures(map);
    return map.containsKey(signature);
  }

  Future<void> _markDeferredProcessed(String signature) async {
    final map = await _loadProcessedDeferredSignatures();
    map[signature] = DateTime.now().millisecondsSinceEpoch;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final ttlMs = _deferredReplayTtl.inMilliseconds;
    map.removeWhere((_, ts) => nowMs - ts > ttlMs);
    await _saveProcessedDeferredSignatures(map);
  }

  Future<bool> _entityStillExists(String moduleId, String entityId) async {
    if (entityId.isEmpty) return false;
    if (moduleId == NotificationHubModuleIds.task) {
      return (await TaskRepository().getTaskById(entityId)) != null;
    }
    if (moduleId == NotificationHubModuleIds.habit) {
      return (await HabitRepository().getHabitById(entityId)) != null;
    }
    // Other modules use adapter-level validation.
    return true;
  }

  Future<bool> _isPendingNotificationStillActive({
    required String payload,
    int? notificationId,
  }) async {
    final pending = await NotificationService()
        .getDetailedPendingNotifications();
    for (final info in pending) {
      if (notificationId != null && info.id == notificationId) return true;
      if ((info.payload ?? '') == payload) return true;
    }
    return false;
  }

  /// Get task by ID from repository
  Future<Task?> _getTaskById(String taskId) async {
    final repository = TaskRepository();
    return await repository.getTaskById(taskId);
  }

  /// Get habit by ID from repository
  Future<Habit?> _getHabitById(String habitId) async {
    final repository = HabitRepository();
    return await repository.getHabitById(habitId);
  }

  /// Show the reminder popup for a task
  void _showReminderPopup(Task task) {
    // We need a context to show the popup.
    // If the app just launched, we might need to wait a tiny bit for the navigator to be ready.
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) {
      debugPrint(
        'NotificationHandler: WARNING: No context available yet, retrying...',
      );
      Future.delayed(
        const Duration(milliseconds: 500),
        () => _showReminderPopup(task),
      );
      return;
    }

    void showPopup() {
      debugPrint(
        'NotificationHandler: Showing reminder popup for "${task.title}"',
      );
      TaskReminderPopup.show(context, task);
    }

    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      showPopup();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => showPopup());
    }
  }

  /// Show the reminder popup for a habit
  void _showHabitReminderPopup(Habit habit) {
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) {
      Future.delayed(
        const Duration(milliseconds: 500),
        () => _showHabitReminderPopup(habit),
      );
      return;
    }

    void showPopup() {
      debugPrint(
        'NotificationHandler: Showing habit reminder popup for "${habit.title}"',
      );
      HabitReminderPopup.show(context, habit);
    }

    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      showPopup();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => showPopup());
    }
  }

  /// Show popup directly (for testing or when notification fires in foreground)
  void showPopupForTask(Task task) {
    _showReminderPopup(task);
  }

  /// Show popup directly for habit
  void showPopupForHabit(Habit habit) {
    _showHabitReminderPopup(habit);
  }
}
