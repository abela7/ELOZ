import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/notification_settings_provider.dart';
import '../../../../core/models/notification_settings.dart';
import '../../../../core/models/reminder.dart';
import 'task_settings_provider.dart';

/// State class for Add Task form
class AddTaskFormState {
  final String? title;
  final String? description;
  final DateTime? dueDate;
  final DateTime? dueTime;
  final String priority;
  final String? categoryId; // Store category ID, not name
  final String? taskTypeId; // Store task type ID, not name
  final List<Reminder> reminders;
  final String? notes;
  final List<String> subtasks;
  final bool isRoutine; // Is this a routine task? (e.g., haircut, dentist)
  final String routineStatus; // Routine status: 'planned', 'done', 'skipped'
  final bool isRoutineActive; // Is this routine active or paused?
  final DateTime? routineDoneDate; // Actual completion date (for Done status)
  final DateTime? routineDoneTime; // Actual completion time (for Done status)
  final String? routineSkipReason; // Reason for skipping (for Skipped status)
  final bool isSpecial; // Is this a special/starred task?

  AddTaskFormState({
    this.title,
    this.description,
    this.dueDate,
    this.dueTime,
    this.priority = 'Medium',
    this.categoryId,
    this.taskTypeId,
    this.reminders = const [],
    this.notes,
    this.subtasks = const [],
    this.isRoutine = false,
    this.routineStatus = 'planned',
    this.isRoutineActive = true,
    this.routineDoneDate,
    this.routineDoneTime,
    this.routineSkipReason,
    this.isSpecial = false,
  });

  AddTaskFormState copyWith({
    String? title,
    String? description,
    DateTime? dueDate,
    DateTime? dueTime,
    String? priority,
    String? categoryId,
    String? taskTypeId,
    List<Reminder>? reminders,
    String? notes,
    List<String>? subtasks,
    bool? isRoutine,
    String? routineStatus,
    bool? isRoutineActive,
    DateTime? routineDoneDate,
    DateTime? routineDoneTime,
    String? routineSkipReason,
    bool? isSpecial,
  }) {
    return AddTaskFormState(
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      dueTime: dueTime ?? this.dueTime,
      priority: priority ?? this.priority,
      categoryId: categoryId ?? this.categoryId,
      taskTypeId: taskTypeId ?? this.taskTypeId,
      reminders: reminders ?? this.reminders,
      notes: notes ?? this.notes,
      subtasks: subtasks ?? this.subtasks,
      isRoutine: isRoutine ?? this.isRoutine,
      routineStatus: routineStatus ?? this.routineStatus,
      isRoutineActive: isRoutineActive ?? this.isRoutineActive,
      routineDoneDate: routineDoneDate ?? this.routineDoneDate,
      routineDoneTime: routineDoneTime ?? this.routineDoneTime,
      routineSkipReason: routineSkipReason ?? this.routineSkipReason,
      isSpecial: isSpecial ?? this.isSpecial,
    );
  }
}

/// StateNotifier for Add Task form
class AddTaskFormNotifier extends StateNotifier<AddTaskFormState> {
  final Ref ref;

  AddTaskFormNotifier(this.ref) : super(AddTaskFormState()) {
    _initializeWithDefaults();
  }

  void _initializeWithDefaults() {
    // Use notification settings for reminder defaults
    final notificationSettings = ref.read(notificationSettingsProvider);
    final defaultReminders = _convertReminderDefaults(notificationSettings.defaultTaskReminderTime);
    
    // Use task settings for priority and category defaults
    final taskSettings = ref.read(taskSettingsProvider);

    state = AddTaskFormState(
      priority: taskSettings.defaultPriority,
      categoryId: taskSettings.defaultCategoryId,
      reminders: defaultReminders,
    );
  }
  
  /// Convert notification settings reminder format to default reminder list.
  List<Reminder> _convertReminderDefaults(String notifSettingsFormat) {
    switch (notifSettingsFormat) {
      case 'none':
        return const [];
      case 'at_time':
        return [Reminder.atTaskTime()];
      case '5_min':
        return [Reminder.fiveMinutesBefore()];
      case '15_min':
        return [Reminder.fifteenMinutesBefore()];
      case '30_min':
        return [Reminder.thirtyMinutesBefore()];
      case '1_hour':
        return [Reminder.oneHourBefore()];
      case '1_day':
        return [Reminder.oneDayBefore()];
      default:
        return const [];
    }
  }

  void setTitle(String title) {
    state = state.copyWith(title: title);
  }

  void setDescription(String description) {
    state = state.copyWith(description: description);
  }

  void setDueDate(DateTime date) {
    state = state.copyWith(dueDate: date);
  }

  void setDueTime(DateTime time) {
    state = state.copyWith(dueTime: time);
  }

  void setPriority(String priority) {
    state = state.copyWith(priority: priority);
  }

  void setCategoryId(String? categoryId) {
    state = state.copyWith(categoryId: categoryId);
  }

  void setTaskTypeId(String? taskTypeId) {
    state = state.copyWith(taskTypeId: taskTypeId);
  }

  void setReminders(List<Reminder> reminders) {
    state = state.copyWith(reminders: reminders);
  }

  void addReminder(Reminder reminder) {
    state = state.copyWith(reminders: [...state.reminders, reminder]);
  }

  void removeReminderAt(int index) {
    final updated = List<Reminder>.from(state.reminders);
    if (index < 0 || index >= updated.length) return;
    updated.removeAt(index);
    state = state.copyWith(reminders: updated);
  }

  void setNotes(String notes) {
    state = state.copyWith(notes: notes);
  }

  void setIsRoutine(bool isRoutine) {
    state = state.copyWith(isRoutine: isRoutine);
  }

  void setRoutineStatus(String routineStatus) {
    state = state.copyWith(routineStatus: routineStatus);
  }

  void setIsRoutineActive(bool isRoutineActive) {
    state = state.copyWith(isRoutineActive: isRoutineActive);
  }

  void setRoutineDoneDate(DateTime date) {
    state = state.copyWith(routineDoneDate: date);
  }

  void setRoutineDoneTime(DateTime time) {
    state = state.copyWith(routineDoneTime: time);
  }

  void setRoutineSkipReason(String? reason) {
    state = state.copyWith(routineSkipReason: reason);
  }

  void setIsSpecial(bool isSpecial) {
    state = state.copyWith(isSpecial: isSpecial);
  }

  void addSubtask(String subtask) {
    state = state.copyWith(
      subtasks: [...state.subtasks, subtask],
    );
  }

  void removeSubtask(int index) {
    final subtasks = List<String>.from(state.subtasks);
    subtasks.removeAt(index);
    state = state.copyWith(subtasks: subtasks);
  }

  void reset() {
    _initializeWithDefaults();
  }
}

/// Provider for Add Task form state
final addTaskFormProvider = StateNotifierProvider<AddTaskFormNotifier, AddTaskFormState>(
  (ref) => AddTaskFormNotifier(ref),
);

