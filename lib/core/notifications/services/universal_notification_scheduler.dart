import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/repositories/task_repository.dart';
import '../../../features/finance/data/models/bill.dart';
import '../../../features/finance/data/repositories/bill_repository.dart';
import '../../../features/finance/data/repositories/debt_repository.dart';
import '../../../features/finance/data/repositories/recurring_income_repository.dart';
import '../../../features/habits/data/repositories/habit_repository.dart';
import '../../../features/mbt/notifications/mbt_notification_contract.dart';
import '../../../features/behavior/notifications/behavior_notification_contract.dart';
import '../../../features/sleep/data/services/wind_down_schedule_service.dart';
import '../models/notification_hub_schedule_result.dart';
import '../notifications.dart';
import 'notification_flow_trace.dart';
import 'notification_module_policy.dart';

class UniversalNotificationSyncResult {
  final int processed;
  final int scheduled;
  final int cancelled;
  final int skipped;
  final int failed;
  final int durationMs;

  const UniversalNotificationSyncResult({
    this.processed = 0,
    this.scheduled = 0,
    this.cancelled = 0,
    this.skipped = 0,
    this.failed = 0,
    this.durationMs = 0,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'processed': processed,
      'scheduled': scheduled,
      'cancelled': cancelled,
      'skipped': skipped,
      'failed': failed,
      'durationMs': durationMs,
    };
  }
}

/// Schedules Universal Notifications with the OS.
///
/// Reads definitions from [UniversalNotificationRepository], computes fire times
/// from entity due dates + timing, resolves variables via adapters, and calls
/// [NotificationHub.schedule]. Ensures reminders actually fire on the device.
class UniversalNotificationScheduler {
  final UniversalNotificationRepository _repo;
  final NotificationHub _hub;
  final Future<void> Function()? _hubInitializerOverride;
  final Future<NotificationModulePolicyDecision> Function(String moduleId)?
  _policyReaderOverride;
  final Future<NotificationHubScheduleResult> Function(
    NotificationHubScheduleRequest request,
  )?
  _hubScheduleOverride;
  final Future<void> Function({
    required int notificationId,
    String? entityId,
    String? payload,
    String? title,
    Map<String, dynamic>? metadata,
  })?
  _hubCancelOverride;
  final int Function({
    required String moduleId,
    required String entityId,
    required String reminderType,
    required int reminderValue,
    required String reminderUnit,
  })?
  _idGeneratorOverride;

  static UniversalNotificationSyncResult? _lastSyncSummary;
  static DateTime? _lastSyncCompletedAt;

  UniversalNotificationScheduler({
    UniversalNotificationRepository? repo,
    NotificationHub? hub,
    Future<void> Function()? hubInitializerOverride,
    Future<NotificationModulePolicyDecision> Function(String moduleId)?
    policyReaderOverride,
    Future<NotificationHubScheduleResult> Function(
      NotificationHubScheduleRequest request,
    )?
    hubScheduleOverride,
    Future<void> Function({
      required int notificationId,
      String? entityId,
      String? payload,
      String? title,
      Map<String, dynamic>? metadata,
    })?
    hubCancelOverride,
    int Function({
      required String moduleId,
      required String entityId,
      required String reminderType,
      required int reminderValue,
      required String reminderUnit,
    })?
    idGeneratorOverride,
  }) : _repo = repo ?? UniversalNotificationRepository(),
       _hub = hub ?? NotificationHub(),
       _hubInitializerOverride = hubInitializerOverride,
       _policyReaderOverride = policyReaderOverride,
       _hubScheduleOverride = hubScheduleOverride,
       _hubCancelOverride = hubCancelOverride,
       _idGeneratorOverride = idGeneratorOverride;

  static UniversalNotificationSyncResult? get lastSyncSummary =>
      _lastSyncSummary;

  static DateTime? get lastSyncCompletedAt => _lastSyncCompletedAt;

  /// Syncs all universal notifications to the OS scheduler.
  Future<void> syncAll() async {
    await syncAllWithMetrics();
  }

  /// Syncs all universal notifications and returns aggregate counters.
  Future<UniversalNotificationSyncResult> syncAllWithMetrics() async {
    final stopwatch = Stopwatch()..start();
    if (_hubInitializerOverride != null) {
      await _hubInitializerOverride();
    } else {
      await _hub.initialize();
    }
    await _repo.init();
    final all = await _repo.getAll();
    var processed = 0;
    var scheduled = 0;
    var cancelled = 0;
    var skipped = 0;
    var failed = 0;

    for (final n in all) {
      processed++;
      if (!n.enabled) {
        await _cancelForNotification(n);
        cancelled++;
        skipped++;
        continue;
      }
      final result = await _scheduleOne(n);
      if (result == null) {
        skipped++;
        continue;
      }
      if (result.success) {
        scheduled++;
      } else {
        failed++;
      }
    }

    stopwatch.stop();
    final summary = UniversalNotificationSyncResult(
      processed: processed,
      scheduled: scheduled,
      cancelled: cancelled,
      skipped: skipped,
      failed: failed,
      durationMs: stopwatch.elapsedMilliseconds,
    );

    NotificationFlowTrace.log(
      event: 'universal_sync_summary',
      sourceFlow: 'universal_sync',
      details: summary.toMap(),
    );
    _lastSyncSummary = summary;
    _lastSyncCompletedAt = DateTime.now();
    return summary;
  }

  /// Syncs notifications for a single entity (e.g. after save/delete).
  ///
  /// Returns [NotificationHubScheduleResult.ok] if all enabled notifications
  /// were scheduled, or a failed result with [failureReason] for user feedback.
  Future<NotificationHubScheduleResult> syncForEntity(String entityId) async {
    if (_hubInitializerOverride != null) {
      await _hubInitializerOverride();
    } else {
      await _hub.initialize();
    }
    await _repo.init();
    final list = await _repo.getByEntity(entityId);
    for (final n in list) {
      await _cancelForNotification(n);
    }
    NotificationHubScheduleResult? lastFailure;
    var anyScheduled = false;
    for (final n in list) {
      if (!n.enabled) continue;
      final result = await _scheduleOne(n);
      if (result != null) {
        if (result.success) {
          anyScheduled = true;
        } else {
          lastFailure = result;
        }
      }
    }
    return lastFailure ??
        (anyScheduled ? NotificationHubScheduleResult.ok : _noDueDateResult);
  }

  static final NotificationHubScheduleResult
  _noDueDateResult = NotificationHubScheduleResult.failed(
    'Could not compute due date. Check the bill, task, or habit has a valid due.',
  );

  /// Cancels the OS notification for a universal notification.
  /// Call before deleting from repo.
  Future<void> cancelForNotification(UniversalNotification n) async {
    await _cancelForNotification(n);
  }

  /// Cancels the OS notification for a universal notification (by its id).
  /// Passes payload, title, and reason for correct History display.
  Future<void> _cancelForNotification(UniversalNotification n) async {
    final id = _notificationIdFor(n);
    final payload = _buildPayloadForLogging(n);
    final title = _displayNameForLogging(n);
    final reason = _cancelReasonForLogging(n);
    if (_hubCancelOverride != null) {
      await _hubCancelOverride(
        notificationId: id,
        entityId: n.entityId,
        payload: payload,
        title: title,
        metadata: reason != null ? {'reason': reason} : null,
      );
      return;
    }
    await _hub.cancelByNotificationId(
      notificationId: id,
      entityId: n.entityId,
      payload: payload,
      title: title,
      metadata: reason != null ? {'reason': reason} : null,
    );
  }

  /// Builds a minimal Hub payload so History shows correct From/Section.
  static String _buildPayloadForLogging(UniversalNotification n) {
    final section = n.section.isNotEmpty ? 'section:${n.section}' : '';
    final parts = [n.moduleId, n.entityId, 'at_time', '0', 'minutes'];
    if (section.isNotEmpty) parts.add(section);
    return parts.join('|');
  }

  /// Human-readable name for History (e.g. "Wind-down reminder (Monday)").
  static String _displayNameForLogging(UniversalNotification n) {
    if (n.entityName.isNotEmpty) return n.entityName;
    if (n.moduleId == 'sleep' && n.section == 'winddown') {
      final day = _weekdayFromEntityId(n.entityId);
      return day != null ? 'Wind-down reminder ($day)' : 'Wind-down reminder';
    }
    if (n.moduleId == 'sleep' && n.section == 'bedtime') {
      return 'Bedtime reminder';
    }
    if (n.moduleId == 'sleep' && n.section == 'wakeup') {
      return 'Wake-up reminder';
    }
    if (n.moduleId == 'task') return 'Task reminder';
    if (n.moduleId == 'habit') return 'Habit reminder';
    if (n.moduleId == NotificationHubModuleIds.mbtMood) {
      return 'Daily mood check-in';
    }
    if (n.moduleId == NotificationHubModuleIds.behavior) {
      return 'Behavior reminder';
    }
    return '${n.section.isNotEmpty ? n.section : n.moduleId} reminder';
  }

  static String? _weekdayFromEntityId(String entityId) {
    const map = {
      'sleep_winddown_mon': 'Monday',
      'sleep_winddown_tue': 'Tuesday',
      'sleep_winddown_wed': 'Wednesday',
      'sleep_winddown_thu': 'Thursday',
      'sleep_winddown_fri': 'Friday',
      'sleep_winddown_sat': 'Saturday',
      'sleep_winddown_sun': 'Sunday',
    };
    return map[entityId];
  }

  /// Reason for cancellation (shown in History).
  static String? _cancelReasonForLogging(UniversalNotification n) {
    if (n.moduleId == 'sleep' && n.section == 'winddown') {
      return 'Wind-down disabled or schedule changed';
    }
    if (n.moduleId == 'sleep') {
      return 'Sleep reminders disabled or schedule changed';
    }
    return 'Cancelled during sync';
  }

  int _notificationIdFor(UniversalNotification n) {
    // Keep IDs deterministic inside the module's reserved Hub range.
    final id = _idGeneratorOverride != null
        ? _idGeneratorOverride(
            moduleId: n.moduleId,
            entityId: '${n.entityId}|${n.id}',
            reminderType: n.timing,
            reminderValue: n.timingValue,
            reminderUnit: n.timingUnit,
          )
        : _hub.generateNotificationId(
            moduleId: n.moduleId,
            entityId: '${n.entityId}|${n.id}',
            reminderType: n.timing,
            reminderValue: n.timingValue,
            reminderUnit: n.timingUnit,
          );
    if (kDebugMode && !_isInModuleRange(n.moduleId, id)) {
      debugPrint(
        'UniversalNotificationScheduler: id out of module range '
        '(module=${n.moduleId}, id=$id)',
      );
      NotificationFlowTrace.log(
        event: 'universal_id_out_of_range',
        sourceFlow: 'universal_sync',
        moduleId: n.moduleId,
        entityId: n.entityId,
        notificationId: id,
      );
    }
    return id;
  }

  bool _isInModuleRange(String moduleId, int notificationId) {
    if (moduleId == NotificationHubModuleIds.task) {
      return notificationId >= NotificationHubIdRanges.taskStart &&
          notificationId <= NotificationHubIdRanges.taskEnd;
    }
    if (moduleId == NotificationHubModuleIds.habit) {
      return notificationId >= NotificationHubIdRanges.habitStart &&
          notificationId <= NotificationHubIdRanges.habitEnd;
    }
    if (moduleId == NotificationHubModuleIds.finance) {
      return notificationId >= NotificationHubIdRanges.financeStart &&
          notificationId <= NotificationHubIdRanges.financeEnd;
    }
    if (moduleId == NotificationHubModuleIds.sleep) {
      return notificationId >= NotificationHubIdRanges.sleepStart &&
          notificationId <= NotificationHubIdRanges.sleepEnd;
    }
    if (moduleId == NotificationHubModuleIds.mbtMood) {
      return notificationId >= NotificationHubIdRanges.mbtMoodStart &&
          notificationId <= NotificationHubIdRanges.mbtMoodEnd;
    }
    if (moduleId == NotificationHubModuleIds.behavior) {
      return notificationId >= NotificationHubIdRanges.behaviorStart &&
          notificationId <= NotificationHubIdRanges.behaviorEnd;
    }
    return true;
  }

  /// Returns null if skipped (no due, past, empty title); otherwise hub result.
  Future<NotificationHubScheduleResult?> _scheduleOne(
    UniversalNotification n,
  ) async {
    final policy = _policyReaderOverride != null
        ? await _policyReaderOverride(n.moduleId)
        : await NotificationModulePolicy.read(n.moduleId);
    if (!policy.enabled) {
      await _cancelForNotification(n);
      if (kDebugMode) {
        debugPrint(
          'UniversalNotificationScheduler: module policy blocked '
          '${n.moduleId}/${n.section}/${n.entityId} (${policy.reason})',
        );
      }
      NotificationFlowTrace.log(
        event: 'universal_schedule_skipped',
        sourceFlow: 'universal_sync',
        moduleId: n.moduleId,
        entityId: n.entityId,
        reason: policy.reason,
      );
      return null;
    }

    // Respect module/section enabled state â€“ don't schedule when disabled.
    if (n.moduleId == 'sleep') {
      if (n.section == 'winddown') {
        final enabled = await WindDownScheduleService().getEnabled();
        if (!enabled) {
          await _cancelForNotification(n);
          if (kDebugMode) {
            debugPrint(
              'UniversalNotificationScheduler: wind-down disabled â€“ cancel and skip ${n.entityId}',
            );
          }
          return null;
        }
      } else if (n.section == 'bedtime' || n.section == 'wakeup') {
        final prefs = await SharedPreferences.getInstance();
        final remindersEnabled =
            prefs.getBool('sleep_enable_reminders') ?? true;
        if (!remindersEnabled) {
          await _cancelForNotification(n);
          if (kDebugMode) {
            debugPrint(
              'UniversalNotificationScheduler: sleep reminders disabled â€“ cancel and skip ${n.entityId}',
            );
          }
          return null;
        }
      }
    }

    final due = await _getDueDateForEntity(
      n.moduleId,
      n.section,
      n.entityId,
      n,
    );
    if (due == null) {
      await _cancelForNotification(n);
      if (kDebugMode) {
        debugPrint(
          'UniversalNotificationScheduler: no due date for ${n.moduleId}/${n.section}/${n.entityId} â€“ skip',
        );
      }
      return _noDueDateResult;
    }

    final scheduledAt = _computeScheduledAt(n, due);
    if (scheduledAt.isBefore(
      DateTime.now().subtract(const Duration(seconds: 10)),
    )) {
      await _cancelForNotification(n);
      if (kDebugMode) {
        debugPrint(
          'UniversalNotificationScheduler: scheduledAt $scheduledAt in past - cancel and skip',
        );
      }
      return NotificationHubScheduleResult.failed(
        'Reminder time is in the past. Choose a future time.',
      );
    }

    final adapter = _getAdapter(n.moduleId);
    final variables = adapter != null
        ? await adapter.resolveVariablesForEntity(n.entityId, n.section)
        : <String, String>{};

    final title = _resolveTemplate(n.titleTemplate, variables);
    final body = _resolveTemplate(n.bodyTemplate, variables);

    if (title.isEmpty) {
      await _cancelForNotification(n);
      if (kDebugMode) {
        debugPrint(
          'UniversalNotificationScheduler: empty title for ${n.id} after template resolution - cancel and skip',
        );
      }
      return NotificationHubScheduleResult.failed(
        'Title is empty after resolving.',
      );
    }

    // Use configured actions only when actionsEnabled; otherwise no action buttons
    final actionButtons = n.actionsEnabled
        ? n.actions
              .map(
                (a) => HubNotificationAction(
                  actionId: a.actionId,
                  label: a.label,
                  showsUserInterface: a.showsUserInterface,
                  cancelNotification: a.cancelNotification,
                ),
              )
              .toList()
        : <HubNotificationAction>[];

    // Default icon when none selected (notifications_rounded = 0xe7f4)
    const defaultIconCodePoint = 0xe7f4;
    const defaultIconFontFamily = 'MaterialIcons';

    // nek12 Layer 3: alarmClock for critical reminders (wind-down) â€“ better OEM reliability
    final useAlarmClock = n.moduleId == 'sleep' && n.section == 'winddown';

    final request = NotificationHubScheduleRequest(
      moduleId: n.moduleId,
      entityId: n.entityId,
      title: title,
      body: body,
      scheduledAt: scheduledAt,
      type: n.typeId,
      notificationId: _notificationIdFor(n),
      iconCodePoint: n.iconCodePoint ?? defaultIconCodePoint,
      iconFontFamily: n.iconFontFamily ?? defaultIconFontFamily,
      iconFontPackage: n.iconFontPackage,
      colorValue: n.colorValue,
      extras: {
        'universalId': n.id,
        'section': n.section,
        'condition': n.condition,
        'sourceFlow': 'universal_sync',
      },
      actionButtons: actionButtons,
      useAlarmClockScheduleMode: useAlarmClock,
    );

    final result = _hubScheduleOverride != null
        ? await _hubScheduleOverride(request)
        : await _hub.schedule(request);
    if (kDebugMode) {
      if (result.success) {
        debugPrint(
          'UniversalNotificationScheduler: scheduled ${n.id} for $scheduledAt',
        );
      } else {
        debugPrint(
          'UniversalNotificationScheduler: hub.schedule failed for ${n.id}: ${result.failureReason}',
        );
      }
    }
    return result;
  }

  DateTime _computeScheduledAt(UniversalNotification n, DateTime due) {
    final targetTime = DateTime(due.year, due.month, due.day, n.hour, n.minute);

    switch (n.timing) {
      case 'before':
        final delta = _durationFrom(n.timingValue, n.timingUnit);
        return targetTime.subtract(delta);
      case 'on_due':
        return targetTime;
      case 'after_due':
        final delta = _durationFrom(n.timingValue, n.timingUnit);
        return targetTime.add(delta);
      default:
        return targetTime;
    }
  }

  Duration _durationFrom(int value, String unit) {
    switch (unit) {
      case 'days':
        return Duration(days: value);
      case 'hours':
        return Duration(hours: value);
      case 'minutes':
        return Duration(minutes: value);
      case 'weeks':
        return Duration(days: value * 7);
      default:
        return Duration(days: value);
    }
  }

  String _resolveTemplate(String template, Map<String, String> variables) {
    var result = template;
    for (final e in variables.entries) {
      result = result.replaceAll(e.key, e.value);
    }
    return result;
  }

  Future<DateTime?> _getDueDateForEntity(
    String moduleId,
    String section,
    String entityId,
    UniversalNotification n,
  ) async {
    switch (moduleId) {
      case 'finance':
        return _getFinanceDueDate(section, entityId);
      case 'task':
        return _getTaskDueDate(entityId);
      case 'habit':
        return _getHabitDueDate(entityId, n);
      case 'sleep':
        return _getSleepDueDate(section, entityId, n);
      case NotificationHubModuleIds.mbtMood:
        return _getMbtMoodDueDate(section, entityId, n);
      case NotificationHubModuleIds.behavior:
        return _getBehaviorDueDate(section, entityId, n);
      default:
        return null;
    }
  }

  DateTime? _getMbtMoodDueDate(
    String section,
    String entityId,
    UniversalNotification n,
  ) {
    if (section != MbtNotificationContract.sectionMoodCheckin ||
        entityId != MbtNotificationContract.entityMoodDailyCheckin) {
      return null;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayScheduledAt = _computeScheduledAt(n, today);
    if (todayScheduledAt.isAfter(now.subtract(const Duration(seconds: 10)))) {
      return today;
    }
    return today.add(const Duration(days: 1));
  }

  DateTime? _getBehaviorDueDate(
    String section,
    String entityId,
    UniversalNotification n,
  ) {
    if (section != BehaviorNotificationContract.sectionDailyReminder) {
      return null;
    }
    final weekday = BehaviorNotificationContract.weekdayFromEntity(entityId);
    if (weekday == null) {
      return null;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var due = _nextOccurrenceOfWeekday(today, weekday);
    var scheduledAt = _computeScheduledAt(n, due);
    const maxWeeks = 8;
    var weeksChecked = 0;
    while (scheduledAt.isBefore(now.subtract(const Duration(minutes: 1))) &&
        weeksChecked < maxWeeks) {
      due = due.add(const Duration(days: 7));
      scheduledAt = _computeScheduledAt(n, due);
      weeksChecked++;
    }
    return weeksChecked < maxWeeks ? due : null;
  }

  Future<DateTime?> _getSleepDueDate(
    String section,
    String entityId,
    UniversalNotification n,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (section == 'winddown') {
      final weekday = _weekdayFromWindDownEntityId(entityId);
      if (weekday == null) return null;
      // Wind-down: Monâ€“Sun week. Include creation day when it matches the
      // weekday (e.g. add on Fri â†’ schedule Fri today). Only advance to next
      // week when the reminder time has already passed.
      var due = _nextOccurrenceOfWeekday(today, weekday);
      var scheduledAt = _computeScheduledAt(n, due);
      const maxWeeks = 8;
      var weeksChecked = 0;
      while (scheduledAt.isBefore(now.subtract(const Duration(minutes: 1))) &&
          weeksChecked < maxWeeks) {
        due = due.add(const Duration(days: 7));
        scheduledAt = _computeScheduledAt(n, due);
        weeksChecked++;
      }
      return weeksChecked < maxWeeks ? due : null;
    }

    final targetToday = DateTime(
      today.year,
      today.month,
      today.day,
      n.hour,
      n.minute,
    );
    if (targetToday.isAfter(now)) {
      return today;
    }
    return today.add(const Duration(days: 1));
  }

  int? _weekdayFromWindDownEntityId(String entityId) {
    const map = {
      'sleep_winddown_mon': 1,
      'sleep_winddown_tue': 2,
      'sleep_winddown_wed': 3,
      'sleep_winddown_thu': 4,
      'sleep_winddown_fri': 5,
      'sleep_winddown_sat': 6,
      'sleep_winddown_sun': 7,
    };
    return map[entityId];
  }

  DateTime _nextOccurrenceOfWeekday(DateTime today, int targetWeekday) {
    final daysUntil = (targetWeekday - today.weekday) % 7;
    if (daysUntil == 0) return today;
    return today.add(Duration(days: daysUntil));
  }

  Future<DateTime?> _getFinanceDueDate(String section, String entityId) async {
    if (section == 'bills') {
      final bill = await BillRepository().getBillById(entityId);
      if (bill == null) return null;
      return bill.nextDueDate ?? _computeBillNextDueFallback(bill);
    }
    if (section == 'debts' || section == 'lending') {
      final debt = await DebtRepository().getDebtById(entityId);
      return debt?.dueDate;
    }
    if (section == 'recurring_income') {
      final repo = RecurringIncomeRepository();
      await repo.init();
      final income = repo.getById(entityId);
      return income?.nextOccurrenceAfter(DateTime.now());
    }
    return null;
  }

  Future<DateTime?> _getTaskDueDate(String entityId) async {
    final task = await TaskRepository().getTaskById(entityId);
    if (task == null) return null;
    if (task.status != 'pending') return null;
    return DateTime(
      task.dueDate.year,
      task.dueDate.month,
      task.dueDate.day,
      task.dueTimeHour ?? 9,
      task.dueTimeMinute ?? 0,
    );
  }

  Future<DateTime?> _getHabitDueDate(
    String entityId,
    UniversalNotification n,
  ) async {
    final habit = await HabitRepository().getHabitById(entityId);
    if (habit == null) return null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Find the next due occurrence where the computed schedule time is not
    // already in the past. This avoids repeatedly returning "today" when the
    // configured time has already elapsed.
    for (var i = 0; i < 60; i++) {
      final day = today.add(Duration(days: i));
      if (!habit.isDueOn(day)) {
        continue;
      }
      final scheduledAt = _computeScheduledAt(n, day);
      if (scheduledAt.isAfter(now.subtract(const Duration(seconds: 10)))) {
        return day;
      }
    }
    return null;
  }

  MiniAppNotificationAdapter? _getAdapter(String moduleId) {
    return _hub.adapterFor(moduleId);
  }

  /// Fallback when bill.nextDueDate is null â€“ compute from startDate/frequency.
  DateTime? _computeBillNextDueFallback(Bill bill) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (bill.frequency) {
      case 'daily':
        return today.add(const Duration(days: 1));
      case 'weekly':
        return today.add(const Duration(days: 7));
      case 'monthly':
        final dueDay = bill.dueDay ?? bill.startDate.day;
        final lastThisMonth = DateTime(now.year, now.month + 1, 0).day;
        final day = dueDay.clamp(1, lastThisMonth);
        var next = DateTime(now.year, now.month, day);
        if (next.isBefore(today)) {
          final lastNextMonth = DateTime(now.year, now.month + 2, 0).day;
          final d = dueDay.clamp(1, lastNextMonth);
          next = DateTime(now.year, now.month + 1, d);
        }
        return next;
      case 'yearly':
        var next = DateTime(
          now.year,
          bill.startDate.month,
          bill.startDate.day.clamp(1, 28),
        );
        if (next.isBefore(today)) {
          next = DateTime(
            now.year + 1,
            bill.startDate.month,
            bill.startDate.day.clamp(1, 28),
          );
        }
        return next;
      case 'custom':
        if (bill.recurrence != null) {
          final next = bill.recurrence!.getNextOccurrence(today);
          return next ?? today.add(const Duration(days: 1));
        }
        return today.add(const Duration(days: 1));
      default:
        final start = DateTime(
          bill.startDate.year,
          bill.startDate.month,
          bill.startDate.day,
        );
        return start.isBefore(today)
            ? today.add(const Duration(days: 1))
            : start;
    }
  }
}
