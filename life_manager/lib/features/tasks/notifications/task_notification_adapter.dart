import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';

import '../../../core/notifications/notifications.dart';
import '../../../core/services/notification_service.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../routing/app_router.dart';
import '../presentation/widgets/task_reminder_popup.dart';

class TaskNotificationAdapter implements MiniAppNotificationAdapter {
  final TaskRepository _taskRepository;

  TaskNotificationAdapter({TaskRepository? taskRepository})
    : _taskRepository = taskRepository ?? TaskRepository();

  @override
  List<HubNotificationSection> get sections => const <HubNotificationSection>[];

  @override
  NotificationHubModule get module => NotificationHubModule(
    moduleId: NotificationHubModuleIds.task,
    displayName: 'Task Manager',
    description: 'Task reminders and due date alerts',
    idRangeStart: NotificationHubIdRanges.taskStart,
    idRangeEnd: NotificationHubIdRanges.taskEnd,
    iconCodePoint: Icons.task_alt_rounded.codePoint,
    colorValue: Colors.blue.toARGB32(),
  );

  @override
  List<HubNotificationType> get customNotificationTypes =>
      const <HubNotificationType>[];

  @override
  Future<void> onNotificationTapped(NotificationHubPayload payload) async {
    final task = await _taskRepository.getTaskById(payload.entityId);
    if (task == null) {
      return;
    }

    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) {
      return;
    }

    void showPopup() {
      TaskReminderPopup.show(context, task);
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
    final taskId = payload.entityId;
    final task = await _taskRepository.getTaskById(taskId);
    if (task == null) return false;

    switch (actionId) {
      case 'mark_done':
        if (task.status == 'completed') return true;
        final points = task.pointsEarned > 0 ? task.pointsEarned : 10;
        final updated = task.copyWith(
          status: 'completed',
          completedAt: DateTime.now(),
          pointsEarned: points,
        );
        await _taskRepository.updateTask(updated);
        await NotificationService().cancelAllTaskReminders(taskId);
        await NotificationHub().cancelForEntity(
          moduleId: NotificationHubModuleIds.task,
          entityId: taskId,
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
    // Task notifications use a different pipeline; platform cancel is sufficient.
  }

  @override
  Future<Map<String, String>> resolveVariablesForEntity(
    String entityId,
    String section,
  ) async {
    final task = await _taskRepository.getTaskById(entityId);
    if (task == null) return {};
    final dueDateTime = DateTime(
      task.dueDate.year,
      task.dueDate.month,
      task.dueDate.day,
      task.dueTimeHour ?? 9,
      task.dueTimeMinute ?? 0,
    );
    return {
      '{title}': task.title,
      '{category}': '',
      '{description}': task.description ?? '',
      '{due_time}': DateFormat('h:mm a, MMM d').format(dueDateTime),
      '{progress}': '${(task.subtaskProgress * 100).toInt()}',
      '{priority}': task.priority,
    };
  }
}
