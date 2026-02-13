import 'package:flutter/material.dart';

import 'universal_notification.dart';

/// A variable placeholder that can be used in title/body templates.
///
/// Example: `{billName}` with description "Name of the bill", example "Netflix".
class NotificationTemplateVariable {
  final String key;
  final String description;
  final String example;

  const NotificationTemplateVariable({
    required this.key,
    required this.description,
    required this.example,
  });
}

/// An action button the module supports for notifications.
///
/// Each action has an ID (used for routing), a label (what user sees),
/// and whether it navigates to a screen or performs an action directly.
class NotificationCreatorAction {
  final String actionId;
  final String label;
  final int? iconCodePoint;
  final String? iconFontFamily;
  final String? iconFontPackage;
  final bool navigates;
  final bool performsAction;

  const NotificationCreatorAction({
    required this.actionId,
    required this.label,
    this.iconCodePoint,
    this.iconFontFamily,
    this.iconFontPackage,
    this.navigates = true,
    this.performsAction = false,
  });

  UniversalNotificationAction toUniversalAction() {
    return UniversalNotificationAction(
      actionId: actionId,
      label: label,
      iconCodePoint: iconCodePoint,
      iconFontFamily: iconFontFamily,
      iconFontPackage: iconFontPackage,
      showsUserInterface: navigates,
      cancelNotification: true,
    );
  }
}

/// Condition option for when a notification should fire.
class NotificationCreatorCondition {
  final String id;
  final String label;
  final String? description;

  const NotificationCreatorCondition({
    required this.id,
    required this.label,
    this.description,
  });
}

/// A notification "kind" - what type of reminder (e.g. Due today, Before due, Overdue).
///
/// When the Creator shows a kind selector (e.g. for bills), each option
/// applies its [defaults] when selected.
class NotificationCreatorKind {
  final String id;
  final String label;
  final String? description;
  final NotificationCreatorDefaults defaults;

  const NotificationCreatorKind({
    required this.id,
    required this.label,
    this.description,
    required this.defaults,
  });
}

/// Suggested default values for the Universal Creator.
class NotificationCreatorDefaults {
  final String titleTemplate;
  final String bodyTemplate;
  final int? iconCodePoint;
  final String? iconFontFamily;
  final String? iconFontPackage;
  final int? colorValue;
  final List<NotificationCreatorAction> actions;
  final bool actionsEnabled;
  final String typeId;
  final String timing;
  final int timingValue;
  final String timingUnit;
  final int hour;
  final int minute;
  final String condition;

  const NotificationCreatorDefaults({
    required this.titleTemplate,
    required this.bodyTemplate,
    this.iconCodePoint,
    this.iconFontFamily,
    this.iconFontPackage,
    this.colorValue,
    this.actions = const [],
    this.actionsEnabled = false,
    required this.typeId,
    this.timing = 'before',
    this.timingValue = 1,
    this.timingUnit = 'days',
    this.hour = 9,
    this.minute = 0,
    this.condition = 'always',
  });
}

/// Context passed by a mini app when opening the Universal Notification Creator.
///
/// The Creator uses this to pre-fill the wizard and show only relevant
/// variables, actions, and conditions for the current notification type.
///
/// When [notificationKinds] is non-empty and creating new (not editing), the
/// Creator shows a "What kind of reminder?" step first. Each kind applies
/// its defaults when selected.
class NotificationCreatorContext {
  final String moduleId;
  final String section;
  final String entityId;
  final String entityName;
  final List<NotificationTemplateVariable> variables;
  final List<NotificationCreatorAction> availableActions;
  final NotificationCreatorDefaults defaults;
  final List<NotificationCreatorCondition> conditions;
  final IconData? entityIcon;
  final int? entityIconColor;

  /// Optional: when set, Creator shows "kind" step first (e.g. Due today,
  /// Reminder before, Overdue). Only used when creating new, not editing.
  final List<NotificationCreatorKind>? notificationKinds;

  /// When true, timing and time-of-day are fixed by the module (e.g. Wind-Down:
  /// X min before bedtime per day from schedule). Creator shows a read-only
  /// summary instead of editable chips and time picker.
  final bool suppressTimingEdits;

  /// When [suppressTimingEdits] is true, optional pre-computed text showing
  /// calculated fire times per day (e.g. "Mon 9:30 PM, Tue 10:00 PM").
  final String? timingSummaryText;

  const NotificationCreatorContext({
    required this.moduleId,
    required this.section,
    required this.entityId,
    required this.entityName,
    required this.variables,
    required this.availableActions,
    required this.defaults,
    required this.conditions,
    this.entityIcon,
    this.entityIconColor,
    this.notificationKinds,
    this.suppressTimingEdits = false,
    this.timingSummaryText,
  });
}

/// Resolver: given an entity ID, returns current variable values.
///
/// Each module implements this to provide live data when the Hub
/// schedules or previews a notification.
typedef NotificationVariableResolver = Future<Map<String, String>> Function(
  String entityId,
);
