import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';

import '../../../core/notifications/notifications.dart';
import '../../../core/services/notification_service.dart';
import '../../../routing/app_router.dart';
import '../data/models/habit_completion.dart';
import '../data/repositories/habit_repository.dart';
import '../presentation/widgets/habit_reminder_popup.dart';

class HabitNotificationAdapter implements MiniAppNotificationAdapter {
  final HabitRepository _habitRepository;

  HabitNotificationAdapter({HabitRepository? habitRepository})
    : _habitRepository = habitRepository ?? HabitRepository();

  @override
  List<HubNotificationSection> get sections => const <HubNotificationSection>[];

  @override
  NotificationHubModule get module => NotificationHubModule(
    moduleId: NotificationHubModuleIds.habit,
    displayName: 'Habit Manager',
    description: 'Habit streak reminders and completion nudges',
    idRangeStart: NotificationHubIdRanges.habitStart,
    idRangeEnd: NotificationHubIdRanges.habitEnd,
    iconCodePoint: Icons.auto_awesome_rounded.codePoint,
    colorValue: Colors.deepPurple.toARGB32(),
  );

  @override
  List<HubNotificationType> get customNotificationTypes =>
      const <HubNotificationType>[];

  @override
  Future<void> onNotificationTapped(NotificationHubPayload payload) async {
    final habit = await _habitRepository.getHabitById(payload.entityId);
    if (habit == null) {
      return;
    }

    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) {
      return;
    }

    void showPopup() {
      HabitReminderPopup.show(context, habit);
    }

    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      showPopup();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => showPopup());
    }
  }

  @override
  Future<bool> onNotificationAction({
    required String actionId,
    required NotificationHubPayload payload,
    int? notificationId,
  }) async {
    final habitId = payload.entityId;
    final habit = await _habitRepository.getHabitById(habitId);
    if (habit == null) return false;

    switch (actionId) {
      case 'mark_done':
        final today = DateTime.now();
        final todayCompletions =
            await _habitRepository.getCompletionsForDate(habitId, today);
        final alreadyCompleted =
            todayCompletions.any((c) => !c.isSkipped && c.count > 0);
        if (alreadyCompleted) return true;
        final points = habit.isQuitHabit
            ? (habit.dailyReward ?? habit.customYesPoints ?? 10)
            : (habit.customYesPoints ?? 10);
        final completion = HabitCompletion(
          habitId: habitId,
          completedDate: DateTime(today.year, today.month, today.day),
          completedAt: today,
          count: 1,
          answer: true,
          pointsEarned: points,
        );
        await _habitRepository.addCompletionWithPoints(
          completion,
          pointsDelta: points,
          updateMoneySaved: habit.isQuitHabit,
          updateUnitsAvoided: habit.isQuitHabit,
        );
        await NotificationService().cancelAllHabitReminders(habitId);
        await NotificationHub().cancelForEntity(
          moduleId: NotificationHubModuleIds.habit,
          entityId: habitId,
        );
        return true;
      case 'skip':
        final today = DateTime.now();
        final completion = HabitCompletion(
          habitId: habitId,
          completedDate: DateTime(today.year, today.month, today.day),
          completedAt: today,
          count: 0,
          isSkipped: true,
          skipReason: 'Skipped from notification',
          answer: false,
          pointsEarned: 0,
        );
        await _habitRepository.addCompletion(completion);
        await NotificationService().cancelAllHabitReminders(habitId);
        await NotificationHub().cancelForEntity(
          moduleId: NotificationHubModuleIds.habit,
          entityId: habitId,
        );
        return true;
      case 'view':
      case 'open':
        onNotificationTapped(payload);
        return true;
      default:
        return false;
    }
  }

  @override
  Future<void> onNotificationDeleted(NotificationHubPayload payload) async {
    // Habit notifications use a different pipeline; platform cancel is sufficient.
  }

  @override
  Future<Map<String, String>> resolveVariablesForEntity(
    String entityId,
    String section,
  ) async {
    final habit = await _habitRepository.getHabitById(entityId);
    if (habit == null) return {};
    final timeStr = habit.reminderMinutes != null
        ? DateFormat('h:mm a').format(
            DateTime(2000, 1, 1,
                habit.reminderMinutes! ~/ 60, habit.reminderMinutes! % 60),
          )
        : '';
    return {
      '{title}': habit.title,
      '{category}': '',
      '{description}': habit.description ?? '',
      '{streak}': '${habit.currentStreak}',
      '{best_streak}': '${habit.bestStreak}',
      '{total}': '${habit.totalCompletions}',
      '{time}': timeStr,
      '{frequency}': habit.frequencyDescription,
      '{goal}': habit.goalDescription ?? '',
    };
  }
}
