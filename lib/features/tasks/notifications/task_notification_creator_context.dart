import 'package:flutter/material.dart';

import '../../../core/notifications/models/notification_creator_context.dart';
import '../../../core/notifications/models/notification_hub_modules.dart';

/// Builds [NotificationCreatorContext] for Task module.
///
/// Used when opening the Universal Notification Creator from add/edit task
/// screens.
class TaskNotificationCreatorContext {
  static const _taskVariables = [
    NotificationTemplateVariable(
      key: '{title}',
      description: 'Task title',
      example: 'Morning meeting',
    ),
    NotificationTemplateVariable(
      key: '{category}',
      description: 'Task category',
      example: 'Work',
    ),
    NotificationTemplateVariable(
      key: '{description}',
      description: 'Task description',
      example: 'Prepare slides',
    ),
    NotificationTemplateVariable(
      key: '{due_time}',
      description: 'Due date/time (formatted)',
      example: '10:00 AM, Feb 12',
    ),
    NotificationTemplateVariable(
      key: '{progress}',
      description: 'Progress percentage',
      example: '50',
    ),
    NotificationTemplateVariable(
      key: '{priority}',
      description: 'Priority level',
      example: 'High',
    ),
  ];

  static const _taskConditions = [
    NotificationCreatorCondition(
      id: 'always',
      label: 'Always',
      description: 'Notify every time',
    ),
    NotificationCreatorCondition(
      id: 'once',
      label: 'Once',
      description: 'Only the first time',
    ),
  ];

  /// Context for a task reminder.
  static NotificationCreatorContext forTask({
    required String taskId,
    required String taskTitle,
  }) {
    return NotificationCreatorContext(
      moduleId: NotificationHubModuleIds.task,
      section: 'tasks',
      entityId: taskId,
      entityName: taskTitle,
      variables: _taskVariables,
      availableActions: [
        NotificationCreatorAction(
          actionId: 'mark_done',
          label: 'Mark Done',
          iconCodePoint: Icons.check_circle_rounded.codePoint,
          iconFontFamily: 'MaterialIcons',
          performsAction: true,
          navigates: false,
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
          actionId: 'view',
          label: 'View',
          iconCodePoint: Icons.visibility_rounded.codePoint,
          iconFontFamily: 'MaterialIcons',
          navigates: true,
        ),
      ],
      defaults: NotificationCreatorDefaults(
        titleTemplate: '{title}',
        bodyTemplate: 'Due {due_time}',
        typeId: 'regular',
        timing: 'before',
        timingValue: 15,
        timingUnit: 'minutes',
        hour: 9,
        minute: 0,
        condition: 'always',
        actionsEnabled: true,
        actions: [
          NotificationCreatorAction(
            actionId: 'mark_done',
            label: 'Mark Done',
            iconCodePoint: Icons.check_circle_rounded.codePoint,
            iconFontFamily: 'MaterialIcons',
            performsAction: true,
            navigates: false,
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
            actionId: 'view',
            label: 'View',
            iconCodePoint: Icons.visibility_rounded.codePoint,
            iconFontFamily: 'MaterialIcons',
            navigates: true,
          ),
        ],
      ),
      conditions: _taskConditions,
    );
  }

  /// Context for a task template reminder.
  static NotificationCreatorContext forTemplate({
    required String templateId,
    required String templateTitle,
  }) {
    return NotificationCreatorContext(
      moduleId: NotificationHubModuleIds.task,
      section: 'templates',
      entityId: templateId,
      entityName: templateTitle,
      variables: _taskVariables,
      availableActions: [
        NotificationCreatorAction(
          actionId: 'mark_done',
          label: 'Mark Done',
          iconCodePoint: Icons.check_circle_rounded.codePoint,
          iconFontFamily: 'MaterialIcons',
          performsAction: true,
          navigates: false,
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
          actionId: 'view',
          label: 'View',
          iconCodePoint: Icons.visibility_rounded.codePoint,
          iconFontFamily: 'MaterialIcons',
          navigates: true,
        ),
      ],
      defaults: NotificationCreatorDefaults(
        titleTemplate: '{title}',
        bodyTemplate: 'Due {due_time}',
        typeId: 'regular',
        timing: 'before',
        timingValue: 15,
        timingUnit: 'minutes',
        hour: 9,
        minute: 0,
        condition: 'always',
        actionsEnabled: true,
        actions: [
          NotificationCreatorAction(
            actionId: 'mark_done',
            label: 'Mark Done',
            iconCodePoint: Icons.check_circle_rounded.codePoint,
            iconFontFamily: 'MaterialIcons',
            performsAction: true,
            navigates: false,
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
            actionId: 'view',
            label: 'View',
            iconCodePoint: Icons.visibility_rounded.codePoint,
            iconFontFamily: 'MaterialIcons',
            navigates: true,
          ),
        ],
      ),
      conditions: _taskConditions,
    );
  }
}
