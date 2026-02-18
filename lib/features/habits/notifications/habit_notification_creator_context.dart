import 'package:flutter/material.dart';

import '../../../core/notifications/models/notification_creator_context.dart';
import '../../../core/notifications/models/notification_hub_modules.dart';

/// Builds [NotificationCreatorContext] for Habit module.
///
/// Used when opening the Universal Notification Creator from create habit
/// screen.
class HabitNotificationCreatorContext {
  static const _habitVariables = [
    NotificationTemplateVariable(
      key: '{title}',
      description: 'Habit name',
      example: 'Morning Run',
    ),
    NotificationTemplateVariable(
      key: '{category}',
      description: 'Habit category',
      example: 'Fitness',
    ),
    NotificationTemplateVariable(
      key: '{description}',
      description: 'Habit description',
      example: '30 min run',
    ),
    NotificationTemplateVariable(
      key: '{streak}',
      description: 'Current streak count',
      example: '5',
    ),
    NotificationTemplateVariable(
      key: '{best_streak}',
      description: 'Best streak ever',
      example: '12',
    ),
    NotificationTemplateVariable(
      key: '{total}',
      description: 'Total completions',
      example: '45',
    ),
    NotificationTemplateVariable(
      key: '{time}',
      description: 'Reminder time',
      example: '7:00 AM',
    ),
    NotificationTemplateVariable(
      key: '{frequency}',
      description: 'Frequency (daily, weekly, etc.)',
      example: 'Daily',
    ),
    NotificationTemplateVariable(
      key: '{goal}',
      description: 'Goal description',
      example: '30 min',
    ),
  ];

  static const _habitConditions = [
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

  /// Context for a habit reminder.
  static NotificationCreatorContext forHabit({
    required String habitId,
    required String habitTitle,
  }) {
    return NotificationCreatorContext(
      moduleId: NotificationHubModuleIds.habit,
      section: 'habits',
      entityId: habitId,
      entityName: habitTitle,
      variables: _habitVariables,
      availableActions: [
        NotificationCreatorAction(
          actionId: 'mark_done',
          label: 'Done',
          iconCodePoint: Icons.check_circle_rounded.codePoint,
          iconFontFamily: 'MaterialIcons',
          performsAction: true,
          navigates: false,
        ),
        NotificationCreatorAction(
          actionId: 'skip',
          label: 'Skip',
          iconCodePoint: Icons.skip_next_rounded.codePoint,
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
      ],
      defaults: NotificationCreatorDefaults(
        titleTemplate: 'Time for {title}',
        bodyTemplate: 'Keep your streak! ({streak} days)',
        typeId: 'regular',
        timing: 'on_due',
        timingValue: 0,
        timingUnit: 'minutes',
        hour: 9,
        minute: 0,
        condition: 'always',
        actionsEnabled: true,
        actions: [
          NotificationCreatorAction(
            actionId: 'mark_done',
            label: 'Done',
            iconCodePoint: Icons.check_circle_rounded.codePoint,
            iconFontFamily: 'MaterialIcons',
            performsAction: true,
            navigates: false,
          ),
          NotificationCreatorAction(
            actionId: 'skip',
            label: 'Skip',
            iconCodePoint: Icons.skip_next_rounded.codePoint,
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
        ],
      ),
      conditions: _habitConditions,
    );
  }
}
