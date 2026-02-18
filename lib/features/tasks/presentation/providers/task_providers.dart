import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../data/models/task.dart';
import '../../../../data/models/subtask.dart';
import '../../../../data/repositories/task_repository.dart';
import '../../../../core/services/recurrence_engine.dart';
import '../../../../core/models/recurrence_rule.dart';
import '../../../../core/services/reminder_manager.dart';

/// Singleton provider for TaskRepository instance (cached)
final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository();
});

/// Provider for all tasks (FutureProvider for initial load)
final taskListProvider = FutureProvider<List<Task>>((ref) async {
  final repository = ref.watch(taskRepositoryProvider);
  return repository.getAllTasks();
});

/// StateNotifier for managing task list state
/// Optimized: Updates state in-memory first, then persists to DB
class TaskNotifier extends StateNotifier<AsyncValue<List<Task>>> {
  final TaskRepository repository;
  final ReminderManager _reminderManager = ReminderManager();

  TaskNotifier(this.repository) : super(const AsyncValue.loading()) {
    loadTasks();
  }

  /// Load all tasks from database
  Future<void> loadTasks() async {
    state = const AsyncValue.loading();
    try {
      final tasks = await repository.getAllTasks();
      state = AsyncValue.data(tasks);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Add a new task - optimized: update state immediately
  ///
  /// Professional Recurring Task Strategy (Rolling Window):
  /// - For 'never' ending: Create occurrences for next 14 days (planning window)
  /// - For 'after_occurrences': Create min(occurrences, 30) upfront
  /// - For 'on_date': Create occurrences within next 30 days or until end date
  ///
  /// This allows planning ahead while preventing endless scroll (365 instances).
  /// More occurrences are auto-generated as tasks are completed.
  static const int _planningWindowDays = 30; // 30-day default planning window

  Future<void> addTask(Task task) async {
    try {
      final List<Task> tasksToAdd = [];

      // Check if this is a recurring task
      if (task.hasRecurrence && task.recurrence != null) {
        // Generate a group ID for all recurring instances
        final recurrenceGroupId = const Uuid().v4();
        final recurrence = task.recurrence!;

        // Use task's due date as the start date for recurrence calculation
        final startDate = DateTime(
          task.dueDate.year,
          task.dueDate.month,
          task.dueDate.day,
          task.dueTimeHour ?? 0,
          task.dueTimeMinute ?? 0,
        );

        // Create a recurrence rule with the task's due date as start
        final adjustedRecurrence = RecurrenceRule(
          type: recurrence.type,
          interval: recurrence.interval,
          daysOfWeek: recurrence.daysOfWeek,
          daysOfMonth: recurrence.daysOfMonth,
          dayOfYear: recurrence.dayOfYear,
          startDate: startDate,
          endCondition: recurrence.endCondition,
          endDate: recurrence.endDate,
          unit: recurrence.unit,
          occurrences: recurrence.occurrences,
          skipWeekends: recurrence.skipWeekends,
        );

        // Calculate end of planning window
        final planningWindowEnd = DateTime.now().add(
          Duration(days: _planningWindowDays),
        );

        // ROLLING WINDOW APPROACH: Generate occurrences for planning window
        int maxOccurrences;
        if (recurrence.endCondition == 'after_occurrences' &&
            recurrence.occurrences != null) {
          // For specific count: generate min(count, 30)
          maxOccurrences = recurrence.occurrences!.clamp(1, 30);
        } else if (recurrence.endCondition == 'on_date' &&
            recurrence.endDate != null) {
          // For end date: generate up to end date or 30 days, whichever is less
          final daysDifference = recurrence.endDate!
              .difference(startDate)
              .inDays;
          final daysToGenerate = daysDifference.clamp(1, 30);
          maxOccurrences = ((daysToGenerate / recurrence.interval) + 1)
              .ceil()
              .clamp(1, 30);
        } else {
          // "Never" - Generate occurrences within the planning window (14 days)
          // This allows users to see and plan for upcoming 2 weeks
          // More are auto-generated when tasks are completed
          final daysToGenerate = planningWindowEnd
              .difference(startDate)
              .inDays
              .clamp(1, _planningWindowDays);
          maxOccurrences = ((daysToGenerate / recurrence.interval) + 1)
              .ceil()
              .clamp(1, 20);
        }

        // Generate occurrence dates (limited for performance)
        final occurrenceDates = RecurrenceEngine.generateNextOccurrences(
          adjustedRecurrence,
          startDate,
          maxOccurrences: maxOccurrences,
        );

        // Validate - ensure no duplicate dates
        final seenDates = <String>{};
        final uniqueOccurrences = occurrenceDates.where((date) {
          final key = '${date.year}-${date.month}-${date.day}';
          if (seenDates.contains(key)) return false;
          seenDates.add(key);
          return true;
        }).toList();

        // Create task instances (limited count for performance)
        for (int i = 0; i < uniqueOccurrences.length; i++) {
          final occurrenceDate = uniqueOccurrences[i];

          final recurringTask = Task(
            id: i == 0 ? task.id : const Uuid().v4(),
            title: task.title,
            description: task.description,
            dueDate: occurrenceDate,
            dueTime: task.dueTime,
            priority: task.priority,
            categoryId: task.categoryId,
            taskTypeId: task.taskTypeId,
            subtasks: task.subtasks,
            recurrenceRule: adjustedRecurrence.toJson(),
            status: 'pending',
            pointsEarned: 0,
            remindersJson: task.remindersJson,
            notes: task.notes,
            iconCodePoint: task.iconCodePoint,
            iconFontFamily: task.iconFontFamily,
            iconFontPackage: task.iconFontPackage,
            tags: task.tags,
            recurrenceGroupId: recurrenceGroupId,
            recurrenceIndex: i,
            taskKind: TaskKind.recurring, // Explicitly set taskKind
          );

          tasksToAdd.add(recurringTask);
        }
      } else {
        // Not a recurring task, just add it
        tasksToAdd.add(task);
      }

      // Update state immediately for instant UI response
      state.whenData((tasks) {
        state = AsyncValue.data([...tasks, ...tasksToAdd]);
      });

      // Persist all tasks to database
      for (final taskToAdd in tasksToAdd) {
        await repository.createTask(taskToAdd);
        await _reminderManager.scheduleRemindersForTask(taskToAdd);
      }
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadTasks();
    }
  }

  /// Update an existing task - optimized: update state immediately
  /// For recurring tasks: regenerates the entire series if recurrence details change
  Future<void> updateTask(Task task) async {
    try {
      // Check if this is a recurring task that needs series regeneration
      bool needsSeriesRegeneration = false;
      Task? originalTask;

      state.whenData((tasks) {
        originalTask = tasks.firstWhere(
          (t) => t.id == task.id,
          orElse: () => task,
        );

        // Check if recurrence-related fields changed
        if (task.recurrenceGroupId != null && originalTask != null) {
          // Trigger regeneration if ANY of these change:
          // 1. Due date changed
          // 2. Recurrence rule changed
          // 3. Due time changed (affects all occurrences)
          needsSeriesRegeneration =
              task.dueDate != originalTask!.dueDate ||
              task.dueTimeHour != originalTask!.dueTimeHour ||
              task.dueTimeMinute != originalTask!.dueTimeMinute ||
              task.recurrenceRule != originalTask!.recurrenceRule;
        }
      });

      if (needsSeriesRegeneration && task.recurrenceGroupId != null) {
        // Regenerate entire recurrence series
        await _regenerateRecurrenceSeries(task);
      } else {
        // Normal update (non-recurring task or no recurrence changes)
        state.whenData((tasks) {
          final updatedTasks = tasks
              .map((t) => t.id == task.id ? task : t)
              .toList();
          state = AsyncValue.data(updatedTasks);
        });
        await repository.updateTask(task);
        await _reminderManager.rescheduleRemindersForTask(task);
      }
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadTasks(); // Reload on error
    }
  }

  /// Regenerate entire recurrence series when a recurring task is edited
  /// This ensures all future occurrences reflect the updated task properties
  Future<void> _regenerateRecurrenceSeries(Task editedTask) async {
    try {
      List<Task> tasksToDelete = [];
      List<Task> tasksToCreate = [];
      final tasks = state.valueOrNull;
      if (tasks == null) {
        return;
      }

      // 1. Find all tasks in the recurrence group
      final groupTasks = tasks
          .where((t) => t.recurrenceGroupId == editedTask.recurrenceGroupId)
          .toList();

      // 2. Sort by recurrence index to maintain order
      groupTasks.sort((a, b) => a.recurrenceIndex.compareTo(b.recurrenceIndex));

      // 3. Find the index of the edited task
      final editedIndex = groupTasks.indexWhere((t) => t.id == editedTask.id);
      if (editedIndex == -1) return;

      // 4. Identify all future instances (including current) to delete
      tasksToDelete = groupTasks
          .where((t) => t.recurrenceIndex >= editedTask.recurrenceIndex)
          .toList();

      // 5. Regenerate future instances based on new parameters
      if (editedTask.recurrence != null) {
        // Create a complete DateTime with date and time for accurate recurrence calculation
        final startDateTime = DateTime(
          editedTask.dueDate.year,
          editedTask.dueDate.month,
          editedTask.dueDate.day,
          editedTask.dueTimeHour ?? 0,
          editedTask.dueTimeMinute ?? 0,
        );

        // Update recurrence rule with new start date/time
        final updatedRecurrence = RecurrenceRule(
          type: editedTask.recurrence!.type,
          interval: editedTask.recurrence!.interval,
          daysOfWeek: editedTask.recurrence!.daysOfWeek,
          daysOfMonth: editedTask.recurrence!.daysOfMonth,
          dayOfYear: editedTask.recurrence!.dayOfYear,
          startDate: startDateTime, // Use complete date+time as new start
          endCondition: editedTask.recurrence!.endCondition,
          endDate: editedTask.recurrence!.endDate,
          unit: editedTask.recurrence!.unit,
          occurrences: editedTask.recurrence!.occurrences,
          skipWeekends: editedTask.recurrence!.skipWeekends,
        );

        // 6. Calculate remaining occurrences to generate
        int remainingOccurrences;
        if (editedTask.recurrence!.endCondition == 'after_occurrences' &&
            editedTask.recurrence!.occurrences != null) {
          // Calculate how many occurrences are left in the series
          final totalOccurrences = editedTask.recurrence!.occurrences!;
          final completedOccurrences = editedTask.recurrenceIndex;
          remainingOccurrences = (totalOccurrences - completedOccurrences)
              .clamp(1, 365);
        } else if (editedTask.recurrence!.endCondition == 'on_date' &&
            editedTask.recurrence!.endDate != null) {
          // Calculate occurrences until end date
          final daysDifference = editedTask.recurrence!.endDate!
              .difference(startDateTime)
              .inDays;
          remainingOccurrences =
              ((daysDifference / updatedRecurrence.interval) + 10).ceil().clamp(
                1,
                365,
              );
        } else {
          // "Never" - generate reasonable amount
          remainingOccurrences = 365;
        }

        // 7. Generate new occurrence dates starting from edited date
        final occurrenceDates = RecurrenceEngine.generateNextOccurrences(
          updatedRecurrence,
          startDateTime,
          maxOccurrences: remainingOccurrences,
        );

        // 8. Create new task instances for each occurrence
        for (int i = 0; i < occurrenceDates.length; i++) {
          final occurrenceDate = occurrenceDates[i];
          final newIndex = editedTask.recurrenceIndex + i;

          final newTask = Task(
            id: i == 0
                ? editedTask.id
                : const Uuid()
                      .v4(), // Keep edited task's ID for first occurrence
            title: editedTask.title,
            description: editedTask.description,
            dueDate: occurrenceDate,
            dueTime: editedTask.dueTime, // Preserve time
            priority: editedTask.priority,
            categoryId: editedTask.categoryId,
            taskTypeId: editedTask.taskTypeId,
            subtasks: editedTask.subtasks,
            recurrenceRule: updatedRecurrence.toJson(), // Store updated rule
            status: i == 0 && editedTask.status != 'pending'
                ? editedTask.status
                : 'pending', // Preserve status of edited task
            pointsEarned: i == 0
                ? editedTask.pointsEarned
                : 0, // Preserve points of edited task
            remindersJson: editedTask.remindersJson,
            notes: editedTask.notes,
            iconCodePoint: editedTask.iconCodePoint,
            iconFontFamily: editedTask.iconFontFamily,
            iconFontPackage: editedTask.iconFontPackage,
            tags: editedTask.tags,
            recurrenceGroupId: editedTask.recurrenceGroupId, // Same group
            recurrenceIndex: newIndex, // Sequential index
            createdAt: i == 0 ? editedTask.createdAt : DateTime.now(),
            completedAt: i == 0 ? editedTask.completedAt : null,
            taskKind: TaskKind.recurring, // Explicitly set taskKind
          );

          tasksToCreate.add(newTask);
        }
      }

      // 9. Update state: remove old future tasks, add regenerated tasks
      final remainingTasks = tasks
          .where((t) => !tasksToDelete.any((del) => del.id == t.id))
          .toList();
      final updatedTasks = [...remainingTasks, ...tasksToCreate];
      state = AsyncValue.data(updatedTasks);

      // 10. Persist all changes to database
      // First delete old future instances
      for (final task in tasksToDelete) {
        await _reminderManager.handleTaskDeleted(task.id);
        await repository.deleteTask(task.id);
      }

      // Then create/update new instances
      for (int i = 0; i < tasksToCreate.length; i++) {
        final task = tasksToCreate[i];
        if (i == 0) {
          // First task is an update of the edited task
          await repository.updateTask(task);
        } else {
          // Rest are new tasks
          await repository.createTask(task);
        }
        // Schedule reminders for all tasks
        await _reminderManager.scheduleRemindersForTask(task);
      }
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadTasks(); // Reload on error to ensure consistency
    }
  }

  /// Delete a task - with smart handling for postponed tasks
  ///
  /// For postponed tasks: Reverts to previous date instead of deleting
  /// For single tasks: Deletes just that task
  /// For recurring tasks: Only deletes this specific instance
  ///
  /// [forceDelete] - If true, skip the smart revert logic and delete anyway
  Future<void> deleteTask(String id, {bool forceDelete = false}) async {
    try {
      Task? taskToCheck;

      state.whenData((tasks) {
        try {
          taskToCheck = tasks.firstWhere((t) => t.id == id);
        } catch (_) {
          taskToCheck = null;
        }
      });

      // Smart delete: If task was postponed and not force-deleting, revert instead
      if (!forceDelete &&
          taskToCheck != null &&
          taskToCheck!.postponeCount > 0) {
        // Revert to previous date instead of deleting
        await undoLastPostpone(id);
        return;
      }

      // Update state immediately
      state.whenData((tasks) {
        final updatedTasks = tasks.where((t) => t.id != id).toList();
        state = AsyncValue.data(updatedTasks);
      });
      // Cancel all reminders for deleted task before removing entity data.
      await _reminderManager.handleTaskDeleted(id);
      // Persist to database
      await repository.deleteTask(id);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadTasks(); // Reload on error
    }
  }

  /// Force delete a task (skip smart postpone revert)
  Future<void> forceDeleteTask(String id) async {
    await deleteTask(id, forceDelete: true);
  }

  /// Delete an entire recurring task series
  /// Deletes ALL tasks in the recurrence group (past, present, and future)
  Future<void> deleteRecurringSeries(String recurrenceGroupId) async {
    try {
      List<String> idsToDelete = [];

      // Find all tasks in the recurrence group
      state.whenData((tasks) {
        idsToDelete = tasks
            .where((t) => t.recurrenceGroupId == recurrenceGroupId)
            .map((t) => t.id)
            .toList();

        // Update state immediately - remove all tasks in the series
        final updatedTasks = tasks
            .where((t) => t.recurrenceGroupId != recurrenceGroupId)
            .toList();
        state = AsyncValue.data(updatedTasks);
      });

      // Persist deletions to database
      for (final taskId in idsToDelete) {
        await _reminderManager.handleTaskDeleted(taskId);
        await repository.deleteTask(taskId);
      }
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadTasks(); // Reload on error
    }
  }

  /// Delete an entire routine series
  /// Deletes ALL tasks in the routine group (past, present, and future instances)
  /// Returns the number of tasks deleted
  Future<int> deleteRoutineSeries(String routineGroupId) async {
    try {
      List<String> idsToDelete = [];

      // Find all tasks in the routine group
      state.whenData((tasks) {
        // Include the original routine task (where id == routineGroupId)
        // AND all instances (where routineGroupId == routineGroupId)
        idsToDelete = tasks
            .where(
              (t) =>
                  t.id == routineGroupId || t.routineGroupId == routineGroupId,
            )
            .map((t) => t.id)
            .toList();

        // Update state immediately - remove all tasks in the routine series
        final updatedTasks = tasks
            .where(
              (t) =>
                  t.id != routineGroupId && t.routineGroupId != routineGroupId,
            )
            .toList();
        state = AsyncValue.data(updatedTasks);
      });

      // Persist deletions to database
      for (final taskId in idsToDelete) {
        await _reminderManager.handleTaskDeleted(taskId);
        await repository.deleteTask(taskId);
      }

      return idsToDelete.length;
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadTasks(); // Reload on error
      return 0;
    }
  }

  /// Clean up excessive future recurring task instances
  ///
  /// This is a one-time cleanup for databases that have 365+ instances
  /// per recurring task from the old implementation.
  ///
  /// Strategy:
  /// - For each recurrence group, keep only:
  ///   - All completed/postponed/not_done instances (for history)
  ///   - The NEXT pending instance (for current action)
  /// - Delete all other future pending instances
  ///
  /// Returns the number of tasks deleted
  Future<int> cleanupExcessiveRecurringTasks() async {
    try {
      int deletedCount = 0;
      List<String> idsToDelete = [];

      state.whenData((tasks) {
        // Group tasks by recurrence group ID
        final Map<String, List<Task>> recurrenceGroups = {};

        for (final task in tasks) {
          if (task.recurrenceGroupId != null) {
            recurrenceGroups
                .putIfAbsent(task.recurrenceGroupId!, () => [])
                .add(task);
          }
        }

        // Process each recurrence group
        for (final entry in recurrenceGroups.entries) {
          final groupTasks = entry.value;

          // Sort by due date
          groupTasks.sort((a, b) => a.dueDate.compareTo(b.dueDate));

          // Find pending tasks
          final pendingTasks = groupTasks
              .where((t) => t.status == 'pending')
              .toList();

          // If more than 1 pending task, delete all but the first (earliest)
          if (pendingTasks.length > 1) {
            // Keep the first pending task, delete the rest
            for (int i = 1; i < pendingTasks.length; i++) {
              idsToDelete.add(pendingTasks[i].id);
            }
          }
        }

        // Update state - remove tasks to be deleted
        if (idsToDelete.isNotEmpty) {
          final updatedTasks = tasks
              .where((t) => !idsToDelete.contains(t.id))
              .toList();
          state = AsyncValue.data(updatedTasks);
        }
      });

      // Persist deletions to database
      for (final taskId in idsToDelete) {
        await _reminderManager.handleTaskDeleted(taskId);
        await repository.deleteTask(taskId);
        deletedCount++;
      }

      return deletedCount;
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadTasks();
      return 0;
    }
  }

  /// Complete a task - optimized: update state immediately
  ///
  /// For recurring tasks (Rolling Window approach):
  /// - Checks if planning window (14 days) still has pending occurrences
  /// - If the window needs more occurrences, generates them
  /// - This ensures users can always plan 2 weeks ahead
  Future<void> completeTask(String id, {int? points}) async {
    try {
      Task? updatedTask;
      List<Task> newRecurringTasks = [];

      state.whenData((tasks) {
        final task = tasks.firstWhere(
          (t) => t.id == id,
          orElse: () => throw Exception('Task not found'),
        );
        updatedTask = task.copyWith(
          status: 'completed',
          completedAt: DateTime.now(),
          pointsEarned: points ?? task.pointsEarned,
        );

        // For recurring tasks: maintain the rolling window
        if (task.hasRecurrence &&
            task.recurrence != null &&
            task.recurrenceGroupId != null) {
          final recurrence = task.recurrence!;
          final planningWindowEnd = DateTime.now().add(
            Duration(days: _planningWindowDays),
          );

          // Find all pending tasks in this group
          final pendingInGroup = tasks
              .where(
                (t) =>
                    t.recurrenceGroupId == task.recurrenceGroupId &&
                    t.id != task.id &&
                    t.status == 'pending',
              )
              .toList();

          // Find the latest pending task's due date
          DateTime? latestPendingDate;
          int highestIndex = task.recurrenceIndex;
          if (pendingInGroup.isNotEmpty) {
            pendingInGroup.sort((a, b) => b.dueDate.compareTo(a.dueDate));
            latestPendingDate = pendingInGroup.first.dueDate;
            highestIndex = pendingInGroup
                .map((t) => t.recurrenceIndex)
                .reduce((a, b) => a > b ? a : b);
          }

          // If the latest pending is before the planning window end, generate more
          if (latestPendingDate == null ||
              latestPendingDate.isBefore(planningWindowEnd)) {
            // Calculate how many more occurrences to generate
            final baseDate =
                latestPendingDate ??
                DateTime(
                  task.dueDate.year,
                  task.dueDate.month,
                  task.dueDate.day,
                  task.dueTimeHour ?? 0,
                  task.dueTimeMinute ?? 0,
                );

            // Generate occurrences to fill the planning window
            final occurrences = RecurrenceEngine.generateNextOccurrences(
              recurrence,
              baseDate.add(const Duration(days: 1)),
              maxOccurrences: 10, // Generate up to 10 more at a time
            );

            int currentIndex = highestIndex;
            for (final occurrenceDate in occurrences) {
              // Stop if past planning window
              if (occurrenceDate.isAfter(planningWindowEnd)) break;

              // Check end conditions
              if (recurrence.hasEnded(occurrenceDate)) break;

              // For 'after_occurrences', check count
              if (recurrence.endCondition == 'after_occurrences' &&
                  recurrence.occurrences != null) {
                final totalCount =
                    tasks
                        .where(
                          (t) => t.recurrenceGroupId == task.recurrenceGroupId,
                        )
                        .length +
                    newRecurringTasks.length;
                if (totalCount >= recurrence.occurrences!) break;
              }

              currentIndex++;

              // Preserve the original time
              final nextDateTime = DateTime(
                occurrenceDate.year,
                occurrenceDate.month,
                occurrenceDate.day,
                task.dueTimeHour ?? occurrenceDate.hour,
                task.dueTimeMinute ?? occurrenceDate.minute,
              );

              // Check if this date already exists in pending
              final alreadyExists = pendingInGroup.any(
                (t) =>
                    t.dueDate.year == nextDateTime.year &&
                    t.dueDate.month == nextDateTime.month &&
                    t.dueDate.day == nextDateTime.day,
              );

              if (!alreadyExists) {
                newRecurringTasks.add(
                  Task(
                    id: const Uuid().v4(),
                    title: task.title,
                    description: task.description,
                    dueDate: nextDateTime,
                    dueTime: task.dueTime,
                    priority: task.priority,
                    categoryId: task.categoryId,
                    taskTypeId: task.taskTypeId,
                    subtasks: task.subtasks
                        ?.map(
                          (s) => Subtask(title: s.title, isCompleted: false),
                        )
                        .toList(),
                    recurrenceRule: task.recurrenceRule,
                    status: 'pending',
                    pointsEarned: 0,
                    remindersJson: task.remindersJson,
                    notes: task.notes,
                    iconCodePoint: task.iconCodePoint,
                    iconFontFamily: task.iconFontFamily,
                    iconFontPackage: task.iconFontPackage,
                    tags: task.tags,
                    recurrenceGroupId: task.recurrenceGroupId,
                    recurrenceIndex: currentIndex,
                    taskKind: TaskKind.recurring, // Explicitly set taskKind
                  ),
                );
              }
            }
          }
        }

        final updatedTasks = tasks
            .map((t) => t.id == id ? updatedTask! : t)
            .toList();
        updatedTasks.addAll(newRecurringTasks);
        state = AsyncValue.data(updatedTasks);
      });

      if (updatedTask != null) {
        await repository.updateTask(updatedTask!);
        await _reminderManager.handleTaskCompleted(updatedTask!);
      }
      for (final newTask in newRecurringTasks) {
        await repository.createTask(newTask);
        await _reminderManager.scheduleRemindersForTask(newTask);
      }
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadTasks();
    }
  }

  /// Mark task as not done - optimized: update state immediately
  ///
  /// Sets status to 'not_done' so it shows correctly in reports.
  /// The notDoneReason is stored for analytics and reporting.
  Future<void> markNotDone(String id, String reason) async {
    try {
      Task? updatedTask;
      state.whenData((tasks) {
        final task = tasks.firstWhere(
          (t) => t.id == id,
          orElse: () => throw Exception('Task not found'),
        );
        updatedTask = task.copyWith(
          status:
              'not_done', // IMPORTANT: Must be 'not_done' for reports to work!
          notDoneReason: reason,
        );
        final updatedTasks = tasks
            .map((t) => t.id == id ? updatedTask! : t)
            .toList();
        state = AsyncValue.data(updatedTasks);
      });
      if (updatedTask != null) {
        await repository.updateTask(updatedTask!);
      }
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadTasks(); // Reload on error
    }
  }

  /// Postpone a task - MOVE the task to a new date (single task, with history)
  ///
  /// CORRECT APPROACH: One task moves between dates, history tracks all postpones
  ///
  /// Flow:
  /// 1. Capture current due date BEFORE any changes
  /// 2. Record the postpone in history (including penalty applied)
  /// 3. Update the task's due date to the new date
  /// 4. Apply penalty to cumulativePostponePenalty
  /// 5. Keep status as 'pending' (task is NOT archived)
  /// 6. Increment postpone count
  ///
  /// PENALTY TRACKING:
  /// - Each postpone applies a penalty (e.g., -5 from TaskType.penaltyPostpone)
  /// - Penalty is tracked in cumulativePostponePenalty
  /// - Each history entry stores the penalty applied for that postpone
  /// - When task is completed: netPoints = rewardOnDone + cumulativePostponePenalty
  /// - Example: 5 postpones @ -5 each = -25 cumulative
  ///            + 10 completion reward = -15 net points
  ///
  /// For RECURRING tasks:
  /// - The task maintains its recurrenceGroupId and recurrenceIndex
  /// - It just appears on a different date temporarily
  /// - When completed, normal recurring logic applies
  /// - The "postponed to non-recurring day" is tracked in history
  ///
  /// Returns the updated task (same ID, just moved)
  ///
  /// [penalty] - The penalty to apply (should be negative, e.g., -5)
  ///             If not provided, defaults to -5
  Future<Task?> postponeTask(
    String id,
    DateTime newDate,
    String reason, {
    int penalty = -5,
  }) async {
    try {
      Task? updatedTask;

      state.whenData((tasks) {
        final task = tasks.firstWhere(
          (t) => t.id == id,
          orElse: () => throw Exception('Task not found'),
        );

        // IMPORTANT: Capture the OLD date BEFORE any modifications
        final oldDueDate = DateTime(
          task.dueDate.year,
          task.dueDate.month,
          task.dueDate.day,
          task.dueTimeHour ?? 0,
          task.dueTimeMinute ?? 0,
        );
        final oldDueDateOnly = DateTime(
          task.dueDate.year,
          task.dueDate.month,
          task.dueDate.day,
        );

        // Ensure penalty is negative (defensive)
        final effectivePenalty = penalty > 0 ? -penalty : penalty;

        // Build postpone history entry with full context (including penalty)
        final historyEntry = {
          'from': oldDueDateOnly.toIso8601String(),
          'fromTime': task.dueTime != null
              ? '${task.dueTimeHour!.toString().padLeft(2, '0')}:${task.dueTimeMinute!.toString().padLeft(2, '0')}'
              : null,
          'to': newDate.toIso8601String(),
          'reason': reason,
          'postponedAt': DateTime.now().toIso8601String(),
          // Track penalty applied for this postpone (for undo)
          'penaltyApplied': effectivePenalty,
          // Track if this was a recurring task postponed to non-recurring day
          'wasRecurring': task.taskKind == TaskKind.recurring,
          'recurrenceGroupId': task.recurrenceGroupId,
          'recurrenceIndex': task.recurrenceIndex,
        };

        // Parse existing history or create new
        List<Map<String, dynamic>> history = [];
        if (task.postponeHistory != null && task.postponeHistory!.isNotEmpty) {
          try {
            history = List<Map<String, dynamic>>.from(
              jsonDecode(task.postponeHistory!),
            );
          } catch (_) {
            history = [];
          }
        }
        history.add(historyEntry);

        // Check if this is the first postpone (to set originalDueDate)
        final isFirstPostpone =
            task.originalDueDate == null && task.postponeCount == 0;

        // NOW update the task with new values
        if (isFirstPostpone) {
          task.originalDueDate = oldDueDateOnly; // The FIRST ever due date
        }
        task.dueDate = newDate;
        task.postponeCount = task.postponeCount + 1;
        task.postponeHistory = jsonEncode(history);
        task.postponeReason = reason;
        task.postponedAt = DateTime.now();

        // PENALTY TRACKING: Add this postpone's penalty to cumulative total
        task.cumulativePostponePenalty =
            task.cumulativePostponePenalty + effectivePenalty;

        // Status stays 'pending' - task is NOT archived, just moved

        updatedTask = task;

        // Update state immediately
        final updatedTasks = tasks.map((t) => t.id == id ? task : t).toList();
        state = AsyncValue.data(updatedTasks);
      });

      if (updatedTask == null) return null;

      // Persist to database
      await repository.updateTask(updatedTask!);
      // Reschedule reminders for the new date
      await _reminderManager.rescheduleRemindersForTask(updatedTask!);

      return updatedTask;
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadTasks();
      return null;
    }
  }

  /// Undo the last postpone - restore the task to its previous date
  ///
  /// This pops the last entry from postpone history and restores the due date.
  /// Also restores the penalty that was applied for that postpone.
  /// If this was the only postpone, clears originalDueDate and resets cumulative penalty.
  ///
  /// PENALTY RESTORATION:
  /// - Reads the 'penaltyApplied' from the popped history entry
  /// - Subtracts it from cumulativePostponePenalty (since penalty is negative,
  ///   subtracting removes its effect)
  /// - Example: cumulative = -15, popped penalty = -5 → new cumulative = -15 - (-5) = -10
  Future<bool> undoLastPostpone(String id) async {
    try {
      Task? updatedTask;

      state.whenData((tasks) {
        final task = tasks.firstWhere(
          (t) => t.id == id,
          orElse: () => throw Exception('Task not found'),
        );

        // Check if there's postpone history to undo
        if (task.postponeHistory == null || task.postponeHistory!.isEmpty) {
          return; // Nothing to undo
        }

        // Parse history
        List<Map<String, dynamic>> history = [];
        try {
          history = List<Map<String, dynamic>>.from(
            jsonDecode(task.postponeHistory!),
          );
        } catch (_) {
          return; // Invalid history
        }

        if (history.isEmpty) return;

        // Pop the last postpone entry
        final lastPostpone = history.removeLast();
        final previousDate = DateTime.parse(lastPostpone['from'] as String);

        // Get the penalty that was applied for this postpone (default -5 for legacy entries)
        final penaltyApplied =
            (lastPostpone['penaltyApplied'] as num?)?.toInt() ?? -5;

        // Restore the task to previous date
        task.dueDate = previousDate;
        task.postponeCount = (task.postponeCount - 1).clamp(0, 999999);
        task.postponeHistory = history.isEmpty ? null : jsonEncode(history);

        // PENALTY RESTORATION: Remove the penalty that was applied for this postpone
        // penaltyApplied is negative (e.g., -5), so subtracting removes its effect
        task.cumulativePostponePenalty =
            task.cumulativePostponePenalty - penaltyApplied;

        // If no more postpones, clear the postpone tracking fields
        if (history.isEmpty) {
          task.originalDueDate = null;
          task.postponeReason = null;
          task.postponedAt = null;
          // Ensure cumulative penalty is 0 when all postpones are undone
          task.cumulativePostponePenalty = 0;
        } else {
          // Update to show the previous postpone info
          final prevPostpone = history.last;
          task.postponeReason = prevPostpone['reason'] as String?;
        }

        updatedTask = task;
        final updatedTasks = tasks.map((t) => t.id == id ? task : t).toList();
        state = AsyncValue.data(updatedTasks);
      });

      if (updatedTask != null) {
        await repository.updateTask(updatedTask!);
        await _reminderManager.rescheduleRemindersForTask(updatedTask!);
        return true;
      }

      return false;
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadTasks();
      return false;
    }
  }

  /// Clean up orphaned tasks from old postpone system
  ///
  /// The old system created new tasks for each postpone, leaving
  /// "archived" tasks with status='postponed'. This method:
  /// 1. Finds all tasks with parentTaskId (created from postpones)
  /// 2. Finds their "original" tasks (status='postponed')
  /// 3. Migrates history to the active task
  /// 4. Deletes the orphaned archived tasks
  ///
  /// Returns number of tasks cleaned up
  Future<int> cleanupOrphanedPostponeTasks() async {
    try {
      int cleanedUp = 0;
      List<String> tasksToDelete = [];
      List<Task> tasksToUpdate = [];

      state.whenData((tasks) {
        // Find all "new" tasks (ones created from postpones - have parentTaskId)
        final newTasks = tasks.where((t) => t.parentTaskId != null).toList();

        for (final newTask in newTasks) {
          // Find the original archived task
          final originalTask = tasks.firstWhere(
            (t) => t.id == newTask.parentTaskId,
            orElse: () =>
                Task(title: '', dueDate: DateTime.now()), // placeholder
          );

          if (originalTask.id == newTask.parentTaskId &&
              originalTask.status == 'postponed') {
            // Found the pair - migrate and clean up
            // The "new" task already has the correct history, just clear parentTaskId
            newTask.parentTaskId = null;
            newTask.rootTaskId = null;
            tasksToUpdate.add(newTask);

            // Mark the archived original for deletion
            tasksToDelete.add(originalTask.id);
            cleanedUp++;
          }
        }

        // Update state
        if (tasksToDelete.isNotEmpty || tasksToUpdate.isNotEmpty) {
          var updatedTasks = tasks
              .where((t) => !tasksToDelete.contains(t.id))
              .toList();
          for (final updated in tasksToUpdate) {
            updatedTasks = updatedTasks
                .map((t) => t.id == updated.id ? updated : t)
                .toList();
          }
          state = AsyncValue.data(updatedTasks);
        }
      });

      // Persist changes
      for (final taskId in tasksToDelete) {
        await _reminderManager.handleTaskDeleted(taskId);
        await repository.deleteTask(taskId);
      }
      for (final task in tasksToUpdate) {
        await repository.updateTask(task);
      }

      return cleanedUp;
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadTasks();
      return 0;
    }
  }

  // ==================== ROBUST UNDO SYSTEM ====================
  //
  // Professional undo handling for all task types:
  // - Regular tasks: Reset status, points, completedAt, subtasks
  // - Recurring tasks: Reset + cleanup auto-generated future tasks
  // - Routine tasks: Reset + routineStatus, routineProgressStartDate
  // - Postponed tasks: Delete new task, restore original to pending
  //
  // Each action (done, skip, postpone) has specific undo behavior

  /// Undo a completed task - comprehensive reset for all task types
  ///
  /// What gets reset:
  /// - status → 'pending'
  /// - completedAt → null
  /// - pointsEarned → 0
  /// - notDoneReason → null (if was not_done)
  /// - All subtasks → uncompleted
  /// - For routine tasks: routineStatus → 'planned'
  /// - For recurring tasks: Cleans up any auto-generated future occurrences
  ///   that were created when this task was completed
  Future<void> undoTaskComplete(String id) async {
    try {
      Task? originalTask;
      Task? updatedTask;
      List<String> tasksToDeleteIds = [];

      state.whenData((tasks) {
        originalTask = tasks.firstWhere(
          (t) => t.id == id,
          orElse: () => throw Exception('Task not found'),
        );
        final task = originalTask!;

        // 1. Reset all subtasks to uncompleted
        List<Subtask>? resetSubtasks;
        if (task.subtasks != null && task.subtasks!.isNotEmpty) {
          resetSubtasks = task.subtasks!
              .map(
                (s) => Subtask(
                  id: s.id,
                  title: s.title,
                  isCompleted: false, // Reset to uncompleted
                ),
              )
              .toList();
        }

        // 2. Reset all status fields directly (copyWith doesn't null values)
        task.status = 'pending';
        task.completedAt = null;
        task.pointsEarned = 0;
        task.notDoneReason = null;
        task.reflection = null;

        // 3. Reset subtasks
        if (resetSubtasks != null) {
          task.subtasks = resetSubtasks;
        }

        // 4. For ROUTINE tasks: reset routine-specific fields
        if (task.taskKind == TaskKind.routine || task.isRoutineTask) {
          task.routineStatus = 'planned';
          // Keep routineProgressStartDate so countdown continues from where it was
        }

        // 5. For RECURRING tasks: identify auto-generated future tasks to delete
        // When a recurring task is completed, we may have auto-generated new
        // occurrences. We need to clean these up on undo.
        if (task.taskKind == TaskKind.recurring &&
            task.recurrenceGroupId != null) {
          // Find tasks in this group that were created AFTER this task was completed
          // and are still pending (auto-generated ones)
          if (originalTask!.completedAt != null) {
            final completedTime = originalTask!.completedAt!;
            final pendingFutureInGroup = tasks
                .where(
                  (t) =>
                      t.recurrenceGroupId == task.recurrenceGroupId &&
                      t.id != task.id &&
                      t.status == 'pending' &&
                      t.createdAt.isAfter(
                        completedTime.subtract(const Duration(seconds: 5)),
                      ), // Small buffer
                )
                .toList();

            // Only delete if they're auto-generated (recurrenceIndex > originalTask's)
            for (final futureTask in pendingFutureInGroup) {
              if (futureTask.recurrenceIndex > task.recurrenceIndex) {
                tasksToDeleteIds.add(futureTask.id);
              }
            }
          }
        }

        updatedTask = task;

        // Update state: update this task, remove auto-generated ones
        var updatedTasks = tasks.map((t) => t.id == id ? task : t).toList();
        if (tasksToDeleteIds.isNotEmpty) {
          updatedTasks = updatedTasks
              .where((t) => !tasksToDeleteIds.contains(t.id))
              .toList();
        }
        state = AsyncValue.data(updatedTasks);
      });

      // Persist changes
      if (updatedTask != null) {
        await repository.updateTask(updatedTask!);
        // Re-schedule reminders since task is pending again
        await _reminderManager.scheduleRemindersForTask(updatedTask!);
      }

      // Delete auto-generated recurring tasks
      for (final taskId in tasksToDeleteIds) {
        await _reminderManager.handleTaskDeleted(taskId);
        await repository.deleteTask(taskId);
      }
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadTasks();
    }
  }

  /// Undo a skipped/not_done task - reset to pending
  ///
  /// What gets reset:
  /// - status → 'pending'
  /// - notDoneReason → null
  /// - pointsEarned → 0 (removes any penalty)
  /// - For routine tasks: routineStatus → 'planned'
  Future<void> undoTaskSkip(String id) async {
    try {
      Task? updatedTask;

      state.whenData((tasks) {
        final task = tasks.firstWhere(
          (t) => t.id == id,
          orElse: () => throw Exception('Task not found'),
        );

        // Reset skip-related fields
        task.status = 'pending';
        task.notDoneReason = null;
        task.pointsEarned = 0;

        // For routine tasks: reset routine status
        if (task.taskKind == TaskKind.routine || task.isRoutineTask) {
          task.routineStatus = 'planned';
        }

        updatedTask = task;
        final updatedTasks = tasks.map((t) => t.id == id ? task : t).toList();
        state = AsyncValue.data(updatedTasks);
      });

      if (updatedTask != null) {
        await repository.updateTask(updatedTask!);
        await _reminderManager.scheduleRemindersForTask(updatedTask!);
      }
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadTasks();
    }
  }

  /// Undo a postponed task - uses new "move" model
  ///
  /// NEW APPROACH: Since postpone now moves the task (doesn't create new),
  /// undo just restores the previous date from history.
  ///
  /// For LEGACY tasks (from old system with parentTaskId):
  /// - Handles the old approach for backward compatibility
  /// - Cleans up the orphaned archived task
  Future<bool> undoPostpone(String taskId) async {
    try {
      Task? task;

      state.whenData((tasks) {
        task = tasks.firstWhere(
          (t) => t.id == taskId,
          orElse: () => throw Exception('Task not found'),
        );
      });

      if (task == null) return false;

      // Check if this is a LEGACY task from old system
      if (task!.parentTaskId != null) {
        // Old system: this task was created from a postpone
        // Find and restore the original, delete this one
        return await _undoLegacyPostpone(taskId);
      }

      // NEW system: task has postponeHistory, just restore previous date
      if (task!.postponeCount > 0 ||
          (task!.postponeHistory != null &&
              task!.postponeHistory!.isNotEmpty)) {
        return await undoLastPostpone(taskId);
      }

      // No postpone to undo
      return false;
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadTasks();
      return false;
    }
  }

  /// Handle undo for legacy postpone system (tasks with parentTaskId)
  Future<bool> _undoLegacyPostpone(String newTaskId) async {
    try {
      Task? originalTask;
      String? originalTaskId;

      state.whenData((tasks) {
        final taskToUndo = tasks.firstWhere((t) => t.id == newTaskId);
        originalTaskId = taskToUndo.parentTaskId;

        if (originalTaskId != null) {
          try {
            originalTask = tasks.firstWhere((t) => t.id == originalTaskId);
          } catch (_) {
            // Original not found - just clear the parentTaskId on this task
            originalTask = null;
          }
        }
      });

      if (originalTask != null) {
        // Restore the original task
        originalTask!.status = 'pending';
        originalTask!.postponedTo = null;
        originalTask!.postponeReason = null;
        originalTask!.postponedAt = null;

        // Update state: restore original, remove new task
        state.whenData((tasks) {
          final updatedTasks = tasks
              .where((t) => t.id != newTaskId)
              .map((t) => t.id == originalTaskId ? originalTask! : t)
              .toList();
          state = AsyncValue.data(updatedTasks);
        });

        // Persist changes
        await repository.updateTask(originalTask!);
        await _reminderManager.handleTaskDeleted(newTaskId);
        await repository.deleteTask(newTaskId);
        await _reminderManager.scheduleRemindersForTask(originalTask!);

        return true;
      } else {
        // Original not found - just clear parentTaskId and use undoLastPostpone
        state.whenData((tasks) {
          final task = tasks.firstWhere((t) => t.id == newTaskId);
          task.parentTaskId = null;
          task.rootTaskId = null;
          final updatedTasks = tasks
              .map((t) => t.id == newTaskId ? task : t)
              .toList();
          state = AsyncValue.data(updatedTasks);
        });

        return await undoLastPostpone(newTaskId);
      }
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadTasks();
      return false;
    }
  }

  /// Smart undo method - routes to the appropriate specific undo method
  ///
  /// Determines what kind of undo is needed based on task state:
  /// - 'completed' → undoTaskComplete
  /// - 'not_done' → undoTaskSkip
  /// - Has postponeHistory → undoLastPostpone
  /// - Legacy with parentTaskId → undoPostpone (backward compatibility)
  Future<void> undoTask(String id) async {
    try {
      Task? task;

      state.whenData((tasks) {
        task = tasks.firstWhere(
          (t) => t.id == id,
          orElse: () => throw Exception('Task not found'),
        );
      });

      if (task == null) return;

      // Route to appropriate undo method based on status
      switch (task!.status) {
        case 'completed':
          await undoTaskComplete(id);
          break;
        case 'not_done':
          await undoTaskSkip(id);
          break;
        case 'postponed':
          // Legacy: This is an archived task from old system
          // Try to find and activate it by clearing postpone status
          await _resetPostponedOriginal(id);
          break;
        default:
          // Check if task has postpone history (new system)
          if (task!.postponeCount > 0 ||
              (task!.postponeHistory != null &&
                  task!.postponeHistory!.isNotEmpty)) {
            await undoLastPostpone(id);
          }
          // Check if this task was created from a postpone (legacy system)
          else if (task!.parentTaskId != null) {
            await undoPostpone(id);
          } else {
            // Generic reset for any other state
            await _genericUndoReset(id);
          }
      }
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadTasks();
    }
  }

  /// Reset a postponed original task (legacy system cleanup)
  Future<void> _resetPostponedOriginal(String id) async {
    try {
      Task? updatedTask;

      state.whenData((tasks) {
        final task = tasks.firstWhere(
          (t) => t.id == id,
          orElse: () => throw Exception('Task not found'),
        );

        task.status = 'pending';
        task.postponedTo = null;
        task.postponeReason = null;
        task.postponedAt = null;

        updatedTask = task;
        final updatedTasks = tasks.map((t) => t.id == id ? task : t).toList();
        state = AsyncValue.data(updatedTasks);
      });

      if (updatedTask != null) {
        await repository.updateTask(updatedTask!);
        await _reminderManager.scheduleRemindersForTask(updatedTask!);
      }
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadTasks();
    }
  }

  /// Generic reset for tasks in unknown states
  Future<void> _genericUndoReset(String id) async {
    try {
      Task? updatedTask;

      state.whenData((tasks) {
        final task = tasks.firstWhere(
          (t) => t.id == id,
          orElse: () => throw Exception('Task not found'),
        );

        // Reset all state-related fields
        task.status = 'pending';
        task.completedAt = null;
        task.pointsEarned = 0;
        task.notDoneReason = null;
        task.postponeReason = null;
        task.postponedAt = null;
        task.postponedTo = null;
        task.reflection = null;

        // Reset routine fields if applicable
        if (task.taskKind == TaskKind.routine || task.isRoutineTask) {
          task.routineStatus = 'planned';
        }

        // Reset subtasks
        if (task.subtasks != null) {
          task.subtasks = task.subtasks!
              .map((s) => Subtask(id: s.id, title: s.title, isCompleted: false))
              .toList();
        }

        // Restore original due date if it was postponed
        if (task.originalDueDate != null) {
          task.dueDate = task.originalDueDate!;
          task.originalDueDate = null;
        }

        updatedTask = task;
        final updatedTasks = tasks.map((t) => t.id == id ? task : t).toList();
        state = AsyncValue.data(updatedTasks);
      });

      if (updatedTask != null) {
        await repository.updateTask(updatedTask!);
        await _reminderManager.scheduleRemindersForTask(updatedTask!);
      }
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadTasks();
    }
  }

  /// Get info about what will be undone for a task
  /// Useful for showing confirmation dialogs with details
  Map<String, dynamic> getUndoInfo(String id) {
    Map<String, dynamic> info = {
      'canUndo': false,
      'undoType': 'none',
      'description': '',
      'willDeleteTasks': 0,
      'willRestorePoints': 0,
      'previousDate': null,
      'postponeCount': 0,
    };

    state.whenData((tasks) {
      try {
        final task = tasks.firstWhere((t) => t.id == id);
        info['canUndo'] = true;
        info['willRestorePoints'] =
            -task.pointsEarned; // Negative because we're reverting
        info['postponeCount'] = task.postponeCount;

        switch (task.status) {
          case 'completed':
            info['undoType'] = 'complete';
            info['description'] =
                'Reset task to pending, remove ${task.pointsEarned} points';

            // Count auto-generated recurring tasks
            if (task.recurrenceGroupId != null && task.completedAt != null) {
              final autoGenerated = tasks
                  .where(
                    (t) =>
                        t.recurrenceGroupId == task.recurrenceGroupId &&
                        t.id != task.id &&
                        t.status == 'pending' &&
                        t.recurrenceIndex > task.recurrenceIndex,
                  )
                  .length;
              info['willDeleteTasks'] = autoGenerated;
              if (autoGenerated > 0) {
                info['description'] +=
                    ', delete $autoGenerated auto-generated occurrence(s)';
              }
            }
            break;

          case 'not_done':
            info['undoType'] = 'skip';
            info['description'] = 'Reset task to pending, remove penalty';
            break;

          case 'postponed':
            // Legacy: archived task from old system
            info['undoType'] = 'postpone_legacy';
            info['description'] = 'Restore this archived task to pending';
            break;

          default:
            // Check if task has postpone history (new system)
            if (task.postponeCount > 0 ||
                (task.postponeHistory != null &&
                    task.postponeHistory!.isNotEmpty)) {
              info['undoType'] = 'postpone';

              // Parse history to get previous date
              try {
                if (task.postponeHistory != null) {
                  final history = List<Map<String, dynamic>>.from(
                    jsonDecode(task.postponeHistory!),
                  );
                  if (history.isNotEmpty) {
                    final lastPostpone = history.last;
                    final previousDate = DateTime.parse(
                      lastPostpone['from'] as String,
                    );
                    info['previousDate'] = previousDate;
                    info['description'] =
                        'Restore task to ${_formatDate(previousDate)}';
                  }
                }
              } catch (_) {
                info['description'] = 'Restore task to previous date';
              }
            }
            // Legacy: task created from postpone (has parentTaskId)
            else if (task.parentTaskId != null) {
              info['undoType'] = 'postpone_legacy_new';
              info['description'] = 'Delete this task, restore original';
              info['willDeleteTasks'] = 1;
            } else {
              info['undoType'] = 'generic';
              info['description'] = 'Reset task to pending';
            }
        }
      } catch (_) {
        info['canUndo'] = false;
        info['description'] = 'Task not found';
      }
    });

    return info;
  }

  /// Helper to format date for display
  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

/// Provider for TaskNotifier
final taskNotifierProvider =
    StateNotifierProvider<TaskNotifier, AsyncValue<List<Task>>>((ref) {
      final repository = ref.watch(taskRepositoryProvider);
      return TaskNotifier(repository);
    });

/// Provider for tasks filtered by date - uses taskNotifierProvider for instant updates
final tasksForDateProvider = Provider.family<AsyncValue<List<Task>>, DateTime>((
  ref,
  date,
) {
  final allTasksAsync = ref.watch(taskNotifierProvider);
  return allTasksAsync.whenData((tasks) {
    return tasks.where((task) {
      final taskDate = DateTime(
        task.dueDate.year,
        task.dueDate.month,
        task.dueDate.day,
      );
      final targetDate = DateTime(date.year, date.month, date.day);
      return taskDate == targetDate;
    }).toList();
  });
});

/// Provider for task statistics
final taskStatisticsProvider = FutureProvider<Map<String, int>>((ref) async {
  final repository = ref.watch(taskRepositoryProvider);
  return repository.getTaskStatistics();
});

/// Provider for overdue tasks
final overdueTasksProvider = FutureProvider<List<Task>>((ref) async {
  final repository = ref.watch(taskRepositoryProvider);
  return repository.getOverdueTasks();
});

/// Provider for completed tasks
final completedTasksProvider = FutureProvider<List<Task>>((ref) async {
  final repository = ref.watch(taskRepositoryProvider);
  return repository.getTasksByStatus('completed');
});

/// Provider for search results - uses taskNotifierProvider for instant updates
final taskSearchProvider = Provider.family<AsyncValue<List<Task>>, String>((
  ref,
  query,
) {
  final allTasksAsync = ref.watch(taskNotifierProvider);
  return allTasksAsync.whenData((tasks) {
    if (query.isEmpty) {
      return tasks;
    }
    final lowerQuery = query.toLowerCase();
    return tasks.where((task) {
      final matchesTitle = task.title.toLowerCase().contains(lowerQuery);
      final matchesDescription =
          task.description?.toLowerCase().contains(lowerQuery) ?? false;
      final matchesNotes =
          task.notes?.toLowerCase().contains(lowerQuery) ?? false;
      final matchesSubtasks =
          task.subtasks?.any(
            (s) => s.title.toLowerCase().contains(lowerQuery),
          ) ??
          false;
      final matchesTags =
          task.tags?.any((t) => t.toLowerCase().contains(lowerQuery)) ?? false;

      return matchesTitle ||
          matchesDescription ||
          matchesNotes ||
          matchesSubtasks ||
          matchesTags;
    }).toList();
  });
});

/// Provider for getting the postpone chain (all related tasks by rootTaskId)
/// Returns tasks sorted by creation date (oldest first) to show the chain history
final taskChainProvider = Provider.family<AsyncValue<List<Task>>, String>((
  ref,
  taskId,
) {
  final allTasksAsync = ref.watch(taskNotifierProvider);
  return allTasksAsync.whenData((tasks) {
    // First find the task to get its rootTaskId
    final task = tasks.firstWhere(
      (t) => t.id == taskId,
      orElse: () => throw Exception('Task not found'),
    );

    // Get the chain root ID (either the task's rootTaskId or the task itself is the root)
    final chainRootId = task.rootTaskId ?? task.id;

    // Find all tasks in the chain
    final chainTasks = tasks.where((t) {
      // Include if: task is the root, or task has this rootTaskId
      return t.id == chainRootId || t.rootTaskId == chainRootId;
    }).toList();

    // Sort by creation date (oldest first to show history in order)
    chainTasks.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return chainTasks;
  });
});

/// Provider for getting a task by ID
final taskByIdProvider = Provider.family<AsyncValue<Task?>, String>((
  ref,
  taskId,
) {
  final allTasksAsync = ref.watch(taskNotifierProvider);
  return allTasksAsync.whenData((tasks) {
    try {
      return tasks.firstWhere((t) => t.id == taskId);
    } catch (_) {
      return null;
    }
  });
});

/// Provider for tasks that were originally scheduled on a date but postponed away
/// Returns tasks whose originalDueDate or postponeHistory shows they were on this date
final tasksPostponedFromDateProvider =
    Provider.family<AsyncValue<List<Task>>, DateTime>((ref, date) {
      final allTasksAsync = ref.watch(taskNotifierProvider);
      return allTasksAsync.whenData((tasks) {
        final targetDate = DateTime(date.year, date.month, date.day);

        return tasks.where((task) {
          // Skip if task is currently on this date (not postponed FROM here)
          final taskDate = DateTime(
            task.dueDate.year,
            task.dueDate.month,
            task.dueDate.day,
          );
          if (taskDate == targetDate) return false;

          // Check if originalDueDate matches
          if (task.originalDueDate != null) {
            final origDate = DateTime(
              task.originalDueDate!.year,
              task.originalDueDate!.month,
              task.originalDueDate!.day,
            );
            if (origDate == targetDate) return true;
          }

          // Check postpone history for any "from" date matching
          if (task.postponeHistory != null &&
              task.postponeHistory!.isNotEmpty) {
            try {
              final history = List<Map<String, dynamic>>.from(
                jsonDecode(task.postponeHistory!),
              );
              for (final entry in history) {
                final fromDateStr = entry['from'] as String?;
                if (fromDateStr != null) {
                  final fromDate = DateTime.parse(fromDateStr);
                  final fromDateOnly = DateTime(
                    fromDate.year,
                    fromDate.month,
                    fromDate.day,
                  );
                  if (fromDateOnly == targetDate) return true;
                }
              }
            } catch (_) {
              // Invalid history
            }
          }

          return false;
        }).toList();
      });
    });

/// Provider for getting postpone history as a parsed list
/// Returns list of {from, to, reason, postponedAt} entries
final postponeHistoryProvider =
    Provider.family<List<Map<String, dynamic>>, String>((ref, taskId) {
      final taskAsync = ref.watch(taskByIdProvider(taskId));
      return taskAsync.whenOrNull(
            data: (task) {
              if (task == null ||
                  task.postponeHistory == null ||
                  task.postponeHistory!.isEmpty) {
                return <Map<String, dynamic>>[];
              }
              try {
                return List<Map<String, dynamic>>.from(
                  jsonDecode(task.postponeHistory!),
                );
              } catch (_) {
                return <Map<String, dynamic>>[];
              }
            },
          ) ??
          [];
    });

/// Provider for counting how many times a task has been postponed in its chain
/// Returns the total count of postponed tasks in the chain
final postponeCountProvider = Provider.family<AsyncValue<int>, String>((
  ref,
  taskId,
) {
  final allTasksAsync = ref.watch(taskNotifierProvider);
  return allTasksAsync.whenData((tasks) {
    try {
      final task = tasks.firstWhere((t) => t.id == taskId);

      // NEW: Use postponeCount directly (new system)
      if (task.postponeCount > 0) {
        return task.postponeCount;
      }

      // LEGACY: Count tasks in chain with status='postponed' (old system)
      final chainRootId = task.rootTaskId ?? task.id;
      final chainTasks = tasks.where((t) {
        return t.id == chainRootId || t.rootTaskId == chainRootId;
      }).toList();

      final postponeCount = chainTasks
          .where((t) => t.status == 'postponed')
          .length;

      return postponeCount;
    } catch (_) {
      return 0;
    }
  });
});

/// Provider for getting all tasks in a recurrence group
/// Returns tasks sorted by due date (earliest first)
final recurrenceGroupProvider = Provider.family<AsyncValue<List<Task>>, String>(
  (ref, recurrenceGroupId) {
    final allTasksAsync = ref.watch(taskNotifierProvider);
    return allTasksAsync.whenData((tasks) {
      final groupTasks = tasks
          .where((t) => t.recurrenceGroupId == recurrenceGroupId)
          .toList();
      // Sort by due date
      groupTasks.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      return groupTasks;
    });
  },
);

/// Provider for getting recurrence group statistics
/// Returns {total: X, completed: Y, pending: Z}
final recurrenceGroupStatsProvider =
    Provider.family<AsyncValue<Map<String, int>>, String>((
      ref,
      recurrenceGroupId,
    ) {
      final groupAsync = ref.watch(recurrenceGroupProvider(recurrenceGroupId));
      return groupAsync.whenData((tasks) {
        final total = tasks.length;
        final completed = tasks.where((t) => t.status == 'completed').length;
        final pending = tasks.where((t) => t.status == 'pending').length;
        final notDone = tasks.where((t) => t.status == 'not_done').length;
        final postponed = tasks.where((t) => t.status == 'postponed').length;

        return {
          'total': total,
          'completed': completed,
          'pending': pending,
          'not_done': notDone,
          'postponed': postponed,
        };
      });
    });

/// Provider for "All Tasks" view with smart recurring task handling
///
/// Professional behavior:
/// - For non-recurring tasks: show all
/// - For recurring tasks: show only the NEXT PENDING occurrence per group
/// - For routine tasks: show only the NEXT PENDING occurrence per routine group
/// - Completed/Postponed/Not Done tasks: show all (for history)
///
/// Uses the explicit taskKind field to properly identify task types
/// This prevents endless scroll of recurring/routine task instances
final smartTaskListProvider = Provider<AsyncValue<List<Task>>>((ref) {
  final allTasksAsync = ref.watch(taskNotifierProvider);

  return allTasksAsync.whenData((allTasks) {
    final List<Task> result = [];
    final Set<String> processedRecurrenceGroups = {};
    final Set<String> processedRoutineGroups = {};

    // Sort all tasks by due date first
    final sortedTasks = List<Task>.from(allTasks)
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    for (final task in sortedTasks) {
      // Use explicit taskKind field for reliable identification
      final kind = task.taskKind;

      // Handle ROUTINE tasks
      if (kind == TaskKind.routine) {
        // Get the routine group ID
        final routineId =
            task.routineGroupId ?? (task.isRoutine ? task.id : null);

        if (routineId != null) {
          // For completed/not_done routines: show all (for history)
          if (task.status != 'pending') {
            result.add(task);
            continue;
          }

          // For pending routine tasks: only show the FIRST (next) pending one per group
          if (!processedRoutineGroups.contains(routineId)) {
            // Find the earliest pending task in this routine group
            final pendingInGroup = sortedTasks
                .where(
                  (t) =>
                      t.taskKind == TaskKind.routine &&
                      (t.routineGroupId ?? (t.isRoutine ? t.id : null)) ==
                          routineId &&
                      t.status == 'pending',
                )
                .toList();

            if (pendingInGroup.isNotEmpty) {
              result.add(pendingInGroup.first);
              processedRoutineGroups.add(routineId);
            }
          }
          // Skip other pending tasks in the same routine group
          continue;
        }
      }

      // Handle RECURRING tasks
      if (kind == TaskKind.recurring || task.recurrenceGroupId != null) {
        final groupId = task.recurrenceGroupId;

        if (groupId != null) {
          // For completed/postponed/not_done: always show (for history)
          if (task.status != 'pending') {
            result.add(task);
            continue;
          }

          // For pending recurring tasks: only show the FIRST (next) pending one per group
          if (!processedRecurrenceGroups.contains(groupId)) {
            final pendingInGroup = sortedTasks
                .where(
                  (t) =>
                      t.recurrenceGroupId == groupId && t.status == 'pending',
                )
                .toList();

            if (pendingInGroup.isNotEmpty) {
              result.add(pendingInGroup.first);
              processedRecurrenceGroups.add(groupId);
            }
          }
          continue;
        }
      }

      // Normal tasks: always include
      result.add(task);
    }

    return result;
  });
});

/// Provider for counting pending occurrences in a recurrence group
/// Useful for showing "3 more upcoming" badge
final pendingRecurrenceCountProvider = Provider.family<AsyncValue<int>, String>(
  (ref, recurrenceGroupId) {
    final allTasksAsync = ref.watch(taskNotifierProvider);
    return allTasksAsync.whenData((tasks) {
      return tasks
          .where(
            (t) =>
                t.recurrenceGroupId == recurrenceGroupId &&
                t.status == 'pending',
          )
          .length;
    });
  },
);

/// Provider for getting all tasks in a routine group (for routine history)
/// Returns tasks sorted by due date (most recent first for history view)
final routineGroupProvider = Provider.family<AsyncValue<List<Task>>, String>((
  ref,
  routineGroupId,
) {
  final allTasksAsync = ref.watch(taskNotifierProvider);
  return allTasksAsync.whenData((tasks) {
    final routineTasks = tasks
        .where(
          (t) =>
              t.routineGroupId == routineGroupId ||
              (t.isRoutine && t.id == routineGroupId),
        )
        .toList();
    // Sort by due date (most recent first for history)
    routineTasks.sort((a, b) => b.dueDate.compareTo(a.dueDate));
    return routineTasks;
  });
});

/// Provider for getting routine statistics
/// Returns comprehensive data for robust countdown/countup calculations
final routineStatsProvider =
    Provider.family<AsyncValue<Map<String, dynamic>>, String>((
      ref,
      routineGroupId,
    ) {
      final groupAsync = ref.watch(routineGroupProvider(routineGroupId));
      return groupAsync.whenData((tasks) {
        final total = tasks.length;
        final completed = tasks.where((t) => t.status == 'completed').length;
        final now = DateTime.now();
        final upcoming = tasks
            .where((t) => t.status == 'pending' && t.dueDate.isAfter(now))
            .length;

        // Get completed tasks with valid completedAt dates
        final completedTasks = tasks
            .where((t) => t.status == 'completed' && t.completedAt != null)
            .toList();

        // Calculate average interval between completions
        double averageInterval = 0;
        if (completedTasks.length >= 2) {
          // Sort by completedAt ascending (oldest first)
          completedTasks.sort(
            (a, b) => a.completedAt!.compareTo(b.completedAt!),
          );
          int totalDays = 0;
          for (int i = 1; i < completedTasks.length; i++) {
            totalDays += completedTasks[i].completedAt!
                .difference(completedTasks[i - 1].completedAt!)
                .inDays;
          }
          averageInterval = totalDays / (completedTasks.length - 1);
        }

        // Get last completed DateTime (the most recent completion)
        DateTime? lastCompletedAt;
        if (completedTasks.isNotEmpty) {
          // Sort by completedAt descending (newest first)
          completedTasks.sort(
            (a, b) => b.completedAt!.compareTo(a.completedAt!),
          );
          lastCompletedAt = completedTasks.first.completedAt;
        }

        // Get next scheduled task with full DateTime (including time if set)
        DateTime? nextScheduledDateTime;
        Task? nextTask;
        final pendingTasks = tasks.where((t) => t.status == 'pending').toList();
        if (pendingTasks.isNotEmpty) {
          // Sort by due date ascending (earliest first)
          pendingTasks.sort((a, b) => a.dueDate.compareTo(b.dueDate));
          nextTask = pendingTasks.first;

          // Build full DateTime with time if available
          final dueDate = nextTask.dueDate;
          if (nextTask.dueTime != null) {
            nextScheduledDateTime = DateTime(
              dueDate.year,
              dueDate.month,
              dueDate.day,
              nextTask.dueTime!.hour,
              nextTask.dueTime!.minute,
            );
          } else {
            nextScheduledDateTime = DateTime(
              dueDate.year,
              dueDate.month,
              dueDate.day,
            );
          }
        }

        return {
          'total': total,
          'completed': completed,
          'upcoming': upcoming,
          'averageInterval': averageInterval,
          'lastCompletedAt':
              lastCompletedAt, // Full DateTime when last completed
          'nextScheduledDateTime':
              nextScheduledDateTime, // Full DateTime with time
          'nextTask': nextTask, // The actual next task object
          'hasTime':
              nextTask?.dueTime !=
              null, // Whether next task has a specific time
        };
      });
    });

/// Provider for getting all routine tasks (template tasks that are marked as routines)
/// Returns all unique routines for display in a routines list
final allRoutinesProvider = Provider<AsyncValue<List<Task>>>((ref) {
  final allTasksAsync = ref.watch(taskNotifierProvider);
  return allTasksAsync.whenData((tasks) {
    final Map<String, Task> uniqueRoutines = {};

    for (final task in tasks) {
      if (task.isRoutineTask) {
        final groupId = task.effectiveRoutineGroupId;
        // Keep the most recent pending task, or the most recently completed
        if (!uniqueRoutines.containsKey(groupId)) {
          uniqueRoutines[groupId] = task;
        } else {
          final existing = uniqueRoutines[groupId]!;
          // Prefer pending over completed
          if (task.status == 'pending' && existing.status != 'pending') {
            uniqueRoutines[groupId] = task;
          } else if (task.status == existing.status) {
            // Same status: prefer the one with later due date
            if (task.dueDate.isAfter(existing.dueDate)) {
              uniqueRoutines[groupId] = task;
            }
          }
        }
      }
    }

    // Sort by title
    final result = uniqueRoutines.values.toList()
      ..sort((a, b) => a.title.compareTo(b.title));

    return result;
  });
});
