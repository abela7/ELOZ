import 'package:flutter/material.dart';

import '../../../core/notifications/models/notification_creator_context.dart';
import '../data/models/wind_down_schedule.dart';
import 'sleep_notification_contract.dart';

String _formatTimeOfDay(TimeOfDay t) {
  final h = t.hour;
  final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  final m = t.minute.toString().padLeft(2, '0');
  final ampm = h < 12 ? 'AM' : 'PM';
  return '$hour12:$m $ampm';
}

TimeOfDay _subtractMinutes(TimeOfDay t, int minutes) {
  var totalMins = t.hour * 60 + t.minute - minutes;
  if (totalMins < 0) totalMins += 24 * 60;
  final h = (totalMins ~/ 60) % 24;
  final m = totalMins % 60;
  return TimeOfDay(hour: h, minute: m);
}

/// Builds [NotificationCreatorContext] for Sleep module.
///
/// Used when opening the Universal Notification Creator from sleep settings
/// for bedtime and wake-up reminders.
class SleepNotificationCreatorContext {
  static const _bedtimeVariables = [
    NotificationTemplateVariable(
      key: '{goalName}',
      description: 'Sleep goal name',
      example: '8 hours',
    ),
    NotificationTemplateVariable(
      key: '{bedtime}',
      description: 'Target bedtime',
      example: '10:30 PM',
    ),
    NotificationTemplateVariable(
      key: '{duration}',
      description: 'Target duration',
      example: '8h',
    ),
  ];

  static const _wakeupVariables = [
    NotificationTemplateVariable(
      key: '{goalName}',
      description: 'Sleep goal name',
      example: '8 hours',
    ),
    NotificationTemplateVariable(
      key: '{wakeTime}',
      description: 'Target wake time',
      example: '6:30 AM',
    ),
    NotificationTemplateVariable(
      key: '{duration}',
      description: 'Target duration',
      example: '8h',
    ),
  ];

  static const _sleepConditions = [
    NotificationCreatorCondition(
      id: 'always',
      label: 'Always',
      description: 'Notify every day',
    ),
  ];

  static const _windDownVariables = [
    NotificationTemplateVariable(
      key: '{bedtime}',
      description: 'Your bedtime for that day',
      example: '10:30 PM',
    ),
    NotificationTemplateVariable(
      key: '{goalName}',
      description: 'Sleep goal name',
      example: '8 hours',
    ),
    NotificationTemplateVariable(
      key: '{duration}',
      description: 'Target duration',
      example: '8h',
    ),
  ];

  /// Context for a bedtime reminder.
  static NotificationCreatorContext forBedtime({
    required String goalId,
    required String goalName,
  }) {
    return NotificationCreatorContext(
      moduleId: SleepNotificationContract.moduleId,
      section: SleepNotificationContract.sectionBedtime,
      entityId: goalId,
      entityName: goalName,
      variables: _bedtimeVariables,
      availableActions: [
        NotificationCreatorAction(
          actionId: 'go_to_sleep',
          label: 'Go to Sleep',
          iconCodePoint: Icons.nightlight_round.codePoint,
          iconFontFamily: 'MaterialIcons',
          navigates: true,
        ),
        NotificationCreatorAction(
          actionId: 'snooze',
          label: 'Snooze',
          iconCodePoint: Icons.snooze_rounded.codePoint,
          iconFontFamily: 'MaterialIcons',
          performsAction: true,
          navigates: false,
        ),
        NotificationCreatorAction(
          actionId: 'dismiss',
          label: 'Dismiss',
          iconCodePoint: Icons.close_rounded.codePoint,
          iconFontFamily: 'MaterialIcons',
          performsAction: true,
          navigates: false,
        ),
      ],
      defaults: NotificationCreatorDefaults(
        titleTemplate: 'Bedtime Reminder',
        bodyTemplate: '{goalName} - target {bedtime}',
        typeId: 'regular',
        timing: 'before',
        timingValue: 15,
        timingUnit: 'minutes',
        hour: 22,
        minute: 0,
        condition: 'always',
        actionsEnabled: true,
        actions: [
          NotificationCreatorAction(
            actionId: 'go_to_sleep',
            label: 'Go to Sleep',
            iconCodePoint: Icons.nightlight_round.codePoint,
            iconFontFamily: 'MaterialIcons',
            navigates: true,
          ),
          NotificationCreatorAction(
            actionId: 'snooze',
            label: 'Snooze',
            iconCodePoint: Icons.snooze_rounded.codePoint,
            iconFontFamily: 'MaterialIcons',
            performsAction: true,
            navigates: false,
          ),
        ],
      ),
      conditions: _sleepConditions,
    );
  }

  /// Context for a wake-up reminder.
  static NotificationCreatorContext forWakeUp({
    required String goalId,
    required String goalName,
  }) {
    return NotificationCreatorContext(
      moduleId: SleepNotificationContract.moduleId,
      section: SleepNotificationContract.sectionWakeup,
      entityId: goalId,
      entityName: goalName,
      variables: _wakeupVariables,
      availableActions: [
        NotificationCreatorAction(
          actionId: 'view',
          label: 'View',
          iconCodePoint: Icons.visibility_rounded.codePoint,
          iconFontFamily: 'MaterialIcons',
          navigates: true,
        ),
        NotificationCreatorAction(
          actionId: 'dismiss',
          label: 'Dismiss',
          iconCodePoint: Icons.close_rounded.codePoint,
          iconFontFamily: 'MaterialIcons',
          performsAction: true,
          navigates: false,
        ),
      ],
      defaults: NotificationCreatorDefaults(
        titleTemplate: 'Wake Up Reminder',
        bodyTemplate: 'Target wake: {wakeTime} ({duration})',
        typeId: 'regular',
        timing: 'on_due',
        timingValue: 0,
        timingUnit: 'minutes',
        hour: 6,
        minute: 30,
        condition: 'always',
        actionsEnabled: true,
        actions: [
          NotificationCreatorAction(
            actionId: 'view',
            label: 'View',
            iconCodePoint: Icons.visibility_rounded.codePoint,
            iconFontFamily: 'MaterialIcons',
            navigates: true,
          ),
          NotificationCreatorAction(
            actionId: 'dismiss',
            label: 'Dismiss',
            iconCodePoint: Icons.close_rounded.codePoint,
            iconFontFamily: 'MaterialIcons',
            performsAction: true,
            navigates: false,
          ),
        ],
      ),
      conditions: _sleepConditions,
    );
  }

  static const _weekdayShort = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];

  /// Context for a wind-down reminder.
  /// Timing and time come from Wind-Down schedule; user cannot edit them here.
  ///
  /// Uses [reminderOffsetMinutes] for "X minutes before bedtime".
  /// When [bedtimesByWeekday] is provided, builds [timingSummaryText] with
  /// calculated fire times per day.
  static NotificationCreatorContext forWindDown({
    required int reminderOffsetMinutes,
    Map<int, TimeOfDay?>? bedtimesByWeekday,
  }) {
    String? timingSummaryText;
    if (bedtimesByWeekday != null && bedtimesByWeekday.isNotEmpty) {
      final parts = <String>[];
      for (int w = 1; w <= 7; w++) {
        final bed = bedtimesByWeekday[w];
        if (bed == null) continue;
        final fireTime = _subtractMinutes(bed, reminderOffsetMinutes);
        parts.add('${_weekdayShort[w - 1]} ${_formatTimeOfDay(fireTime)}');
      }
      timingSummaryText =
          parts.isEmpty ? null : parts.join(', ');
    }

    const names = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    return NotificationCreatorContext(
      moduleId: SleepNotificationContract.moduleId,
      section: SleepNotificationContract.sectionWinddown,
      entityId: SleepWindDownPayload.entityIdForWeekday(1),
      entityName: 'Wind Down ${names[0]}',
      variables: _windDownVariables,
      availableActions: [
        NotificationCreatorAction(
          actionId: 'go_to_sleep',
          label: 'Go to Sleep',
          iconCodePoint: Icons.bedtime_rounded.codePoint,
          iconFontFamily: 'MaterialIcons',
          navigates: true,
        ),
        NotificationCreatorAction(
          actionId: 'dismiss',
          label: 'Dismiss',
          iconCodePoint: Icons.close_rounded.codePoint,
          iconFontFamily: 'MaterialIcons',
          performsAction: true,
          navigates: false,
        ),
      ],
      defaults: NotificationCreatorDefaults(
        titleTemplate: 'Wind Down',
        bodyTemplate:
            'Time to prepare for sleep. About $reminderOffsetMinutes min until bedtime.',
        typeId: 'regular',
        timing: 'before',
        timingValue: reminderOffsetMinutes,
        timingUnit: 'minutes',
        hour: 22,
        minute: 0,
        condition: 'always',
        actionsEnabled: true,
        actions: [
          NotificationCreatorAction(
            actionId: 'go_to_sleep',
            label: 'Go to Sleep',
            iconCodePoint: Icons.bedtime_rounded.codePoint,
            iconFontFamily: 'MaterialIcons',
            navigates: true,
          ),
          NotificationCreatorAction(
            actionId: 'dismiss',
            label: 'Dismiss',
            iconCodePoint: Icons.close_rounded.codePoint,
            iconFontFamily: 'MaterialIcons',
            performsAction: true,
            navigates: false,
          ),
        ],
      ),
      conditions: _sleepConditions,
      suppressTimingEdits: true,
      timingSummaryText: timingSummaryText,
    );
  }
}
