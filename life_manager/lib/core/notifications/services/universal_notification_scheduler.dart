import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/repositories/task_repository.dart';
import '../../../features/finance/data/models/bill.dart';
import '../../../features/finance/data/repositories/bill_repository.dart';
import '../../../features/finance/data/repositories/debt_repository.dart';
import '../../../features/finance/data/repositories/recurring_income_repository.dart';
import '../../../features/habits/data/repositories/habit_repository.dart';
import '../../../features/sleep/data/services/wind_down_schedule_service.dart';
import '../models/notification_hub_schedule_request.dart';
import '../models/notification_hub_schedule_result.dart';
import '../models/universal_notification.dart';
import '../notification_hub.dart';
import '../notifications.dart';
import 'universal_notification_repository.dart';

/// Schedules Universal Notifications with the OS.
///
/// Reads definitions from [UniversalNotificationRepository], computes fire times
/// from entity due dates + timing, resolves variables via adapters, and calls
/// [NotificationHub.schedule]. Ensures reminders actually fire on the device.
class UniversalNotificationScheduler {
  final UniversalNotificationRepository _repo;
  final NotificationHub _hub;

  UniversalNotificationScheduler({
    UniversalNotificationRepository? repo,
    NotificationHub? hub,
  })  : _repo = repo ?? UniversalNotificationRepository(),
        _hub = hub ?? NotificationHub();

  /// Syncs all universal notifications to the OS scheduler.
  Future<void> syncAll() async {
    await _hub.initialize();
    await _repo.init();
    final all = await _repo.getAll();
    for (final n in all) {
      if (!n.enabled) {
        await _cancelForNotification(n);
        continue;
      }
      await _scheduleOne(n);
    }
  }

  /// Syncs notifications for a single entity (e.g. after save/delete).
  ///
  /// Returns [NotificationHubScheduleResult.ok] if all enabled notifications
  /// were scheduled, or a failed result with [failureReason] for user feedback.
  Future<NotificationHubScheduleResult> syncForEntity(String entityId) async {
    await _hub.initialize();
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
    return lastFailure ?? (anyScheduled ? NotificationHubScheduleResult.ok : _noDueDateResult);
  }

  static final NotificationHubScheduleResult _noDueDateResult =
      NotificationHubScheduleResult.failed(
    'Could not compute due date. Check the bill, task, or habit has a valid due.',
  );

  /// Cancels the OS notification for a universal notification.
  /// Call before deleting from repo.
  Future<void> cancelForNotification(UniversalNotification n) async {
    await _cancelForNotification(n);
  }

  /// Cancels the OS notification for a universal notification (by its id).
  Future<void> _cancelForNotification(UniversalNotification n) async {
    final id = _notificationIdFor(n);
    await _hub.cancelByNotificationId(notificationId: id);
  }

  int _notificationIdFor(UniversalNotification n) {
    return n.id.hashCode & 0x7FFFFFFF;
  }

  /// Returns null if skipped (no due, past, empty title); otherwise hub result.
  Future<NotificationHubScheduleResult?> _scheduleOne(UniversalNotification n) async {
    // Respect module/section enabled state – don't schedule when disabled.
    if (n.moduleId == 'sleep') {
      if (n.section == 'winddown') {
        final enabled = await WindDownScheduleService().getEnabled();
        if (!enabled) {
          await _cancelForNotification(n);
          if (kDebugMode) {
            debugPrint(
              'UniversalNotificationScheduler: wind-down disabled – cancel and skip ${n.entityId}',
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
              'UniversalNotificationScheduler: sleep reminders disabled – cancel and skip ${n.entityId}',
            );
          }
          return null;
        }
      }
    }

    final due = await _getDueDateForEntity(n.moduleId, n.section, n.entityId, n);
    if (due == null) {
      // Entity may have been deleted/completed; proactively cancel any stale
      // previously scheduled OS alarm for this universal notification id.
      await _cancelForNotification(n);
      if (kDebugMode) {
        debugPrint(
          'UniversalNotificationScheduler: no due date for ${n.moduleId}/${n.section}/${n.entityId} – skip',
        );
      }
      return _noDueDateResult;
    }

    final scheduledAt = _computeScheduledAt(n, due);
    if (scheduledAt.isBefore(
        DateTime.now().subtract(const Duration(seconds: 10)))) {
      if (kDebugMode) {
        debugPrint(
          'UniversalNotificationScheduler: scheduledAt $scheduledAt in past – skip',
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
      return NotificationHubScheduleResult.failed('Title is empty after resolving.');
    }

    // Use configured actions only when actionsEnabled; otherwise no action buttons
    final actionButtons = n.actionsEnabled
        ? n.actions
            .map((a) => HubNotificationAction(
                  actionId: a.actionId,
                  label: a.label,
                  showsUserInterface: a.showsUserInterface,
                  cancelNotification: a.cancelNotification,
                ))
            .toList()
        : <HubNotificationAction>[];

    // Default icon when none selected (notifications_rounded = 0xe7f4)
    const defaultIconCodePoint = 0xe7f4;
    const defaultIconFontFamily = 'MaterialIcons';

    // nek12 Layer 3: alarmClock for critical reminders (wind-down) – better OEM reliability
    final useAlarmClock =
        n.moduleId == 'sleep' && n.section == 'winddown';

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
      },
      actionButtons: actionButtons,
      useAlarmClockScheduleMode: useAlarmClock,
    );

    final result = await _hub.schedule(request);
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
    final targetTime = DateTime(
      due.year,
      due.month,
      due.day,
      n.hour,
      n.minute,
    );

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
      default:
        return null;
    }
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
      // Wind-down: Mon–Sun week. Include creation day when it matches the
      // weekday (e.g. add on Fri → schedule Fri today). Only advance to next
      // week when the reminder time has already passed.
      var due = _nextOccurrenceOfWeekday(today, weekday);
      var scheduledAt = _computeScheduledAt(n, due);
      const maxWeeks = 8;
      var weeksChecked = 0;
      while (
          scheduledAt.isBefore(now.subtract(const Duration(minutes: 1))) &&
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
      if (scheduledAt.isAfter(
        now.subtract(const Duration(seconds: 10)),
      )) {
        return day;
      }
    }
    return null;
  }

  MiniAppNotificationAdapter? _getAdapter(String moduleId) {
    return _hub.adapterFor(moduleId);
  }

  /// Fallback when bill.nextDueDate is null – compute from startDate/frequency.
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
        final start = DateTime(bill.startDate.year, bill.startDate.month, bill.startDate.day);
        return start.isBefore(today) ? today.add(const Duration(days: 1)) : start;
    }
  }
}
