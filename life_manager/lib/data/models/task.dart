import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import '../../core/models/recurrence_rule.dart';
import '../../core/models/reminder.dart';
import 'subtask.dart';

part 'task.g.dart';

/// Task kind constants
class TaskKind {
  static const String normal = 'normal';
  static const String recurring = 'recurring';
  static const String routine = 'routine';
}

/// Helper to determine task kind based on task properties
String _determineTaskKind({
  required bool isRoutine,
  String? routineGroupId,
  String? recurrenceRule,
  String? recurrenceGroupId,
}) {
  // Routine tasks take priority
  if (isRoutine || routineGroupId != null) {
    return TaskKind.routine;
  }
  // Check for recurring
  if (recurrenceRule != null || recurrenceGroupId != null) {
    return TaskKind.recurring;
  }
  // Default to normal
  return TaskKind.normal;
}

/// Task model with Hive persistence
/// Represents a single task in the task management system
@HiveType(typeId: 0)
class Task extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String? description;

  @HiveField(3)
  DateTime dueDate;

  @HiveField(4)
  int? dueTimeHour; // Hour component of due time

  @HiveField(20)
  int? dueTimeMinute; // Minute component of due time

  @HiveField(5)
  String priority; // 'Low', 'Medium', 'High'

  @HiveField(6)
  String? categoryId; // Reference to category from settings

  @HiveField(7)
  String? taskTypeId; // Reference to task type for points system

  @HiveField(30)
  List<Subtask>? subtasks; // List of subtask objects

  @HiveField(9)
  @Deprecated('Use subtasks instead')
  Map<String, bool>? subtaskCompletion; // Legacy field

  @HiveField(10)
  String? recurrenceRule; // JSON string for recurrence pattern

  @HiveField(11)
  String status; // 'pending', 'completed', 'overdue', 'postponed'

  @HiveField(12)
  int pointsEarned; // Points earned/lost for this task

  @HiveField(13)
  String? remindersJson; // JSON list of Reminder maps (legacy strings also supported for migration)

  @HiveField(14)
  String? notes; // Additional notes

  @HiveField(15)
  DateTime createdAt;

  @HiveField(16)
  DateTime? completedAt;

  @HiveField(17)
  DateTime? postponedTo; // New due date if postponed

  @HiveField(18)
  String? postponeReason; // Reason for postponing

  @HiveField(19)
  String? notDoneReason; // Reason for not completing

  @HiveField(21)
  String? reflection; // Reflection text when task is completed

  @HiveField(22)
  DateTime? originalDueDate; // Original due date before postponing (to track "Was due" date)

  @HiveField(23)
  String? parentTaskId; // ID of the task this was postponed from (for chain tracking)

  @HiveField(24)
  String? rootTaskId; // ID of the very first task in the chain (for grouping all related tasks)

  @HiveField(25)
  DateTime? postponedAt; // When this task was marked as postponed

  @HiveField(26)
  int? iconCodePoint; // Icon code point for task icon (IconData.codePoint)
  
  @HiveField(27)
  String? iconFontFamily; // Icon font family (defaults to MaterialIcons)
  
  @HiveField(28)
  String? iconFontPackage; // Icon font package (if any)

  @HiveField(29)
  List<String>? tags; // List of tag strings

  @HiveField(31)
  int postponeCount; // Number of times this task has been postponed

  @HiveField(32)
  String? postponeHistory; // JSON string of postpone history [{date, reason, from, to}]

  @HiveField(33)
  String? recurrenceGroupId; // ID to group recurring task instances together

  @HiveField(34)
  int recurrenceIndex; // Index of this task in the recurrence series (0, 1, 2, ...)

  @HiveField(35)
  bool isRoutine; // Is this a routine-type task? (like haircut, dentist, etc.)

  @HiveField(36)
  String? routineGroupId; // Groups all instances of the same routine together

  @HiveField(37)
  String routineStatus; // Routine-specific status: 'planned', 'done', 'skipped'

  @HiveField(38)
  bool isRoutineActive; // Is this routine currently active (vs archived/paused)?

  @HiveField(39)
  DateTime? routineProgressStartDate; // When the countdown progress starts for routine tasks

  /// Task kind: 'normal', 'recurring', 'routine'
  /// This is the explicit identifier for task type to properly filter and group tasks
  @HiveField(40)
  String taskKind;

  /// Cumulative penalty points from all postpones
  /// This is tracked separately from pointsEarned so we can properly calculate net points
  /// Example: 5 postpones with -5 penalty each = -25 cumulativePostponePenalty
  /// When task is completed with +10 reward, net = 10 + (-25) = -15
  @HiveField(41)
  int cumulativePostponePenalty;

  /// Special/Starred task - pinned to top for priority focus
  @HiveField(42)
  bool isSpecial;

  /// Snooze tracking - when the task is snoozed until
  @HiveField(43)
  DateTime? snoozedUntil;

  /// Snooze history (JSON string): [{at, minutes, until, source, notificationId}]
  @HiveField(44)
  String? snoozeHistory;

  /// Counter section visibility for non-routine tasks
  @HiveField(45)
  bool counterEnabled;

  Task({
    String? id,
    required this.title,
    this.description,
    required this.dueDate,
    TimeOfDay? dueTime,
    this.priority = 'Medium',
    this.categoryId,
    this.taskTypeId,
    this.subtasks,
    this.subtaskCompletion,
    String? recurrenceRule,
    this.status = 'pending',
    this.pointsEarned = 0,
    this.remindersJson,
    this.notes,
    DateTime? createdAt,
    this.completedAt,
    this.postponedTo,
    this.postponeReason,
    this.notDoneReason,
    this.reflection,
    this.originalDueDate,
    this.parentTaskId,
    this.rootTaskId,
    this.postponedAt,
    this.iconCodePoint,
    this.iconFontFamily,
    this.iconFontPackage,
    this.tags,
    this.postponeCount = 0,
    this.postponeHistory,
    this.recurrenceGroupId,
    this.recurrenceIndex = 0,
    this.isRoutine = false,
    this.routineGroupId,
    this.routineStatus = 'planned',
    this.isRoutineActive = true,
    this.routineProgressStartDate,
    String? taskKind,
    this.cumulativePostponePenalty = 0,
    this.isSpecial = false,
    this.snoozedUntil,
    this.snoozeHistory,
    bool? counterEnabled,
    IconData? icon,
    RecurrenceRule? recurrence,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        dueTimeHour = dueTime?.hour,
        dueTimeMinute = dueTime?.minute,
        recurrenceRule = recurrence?.toJson() ?? recurrenceRule,
        counterEnabled = counterEnabled ?? true,
        // Auto-determine taskKind if not provided
        taskKind = taskKind ?? _determineTaskKind(
          isRoutine: isRoutine,
          routineGroupId: routineGroupId,
          recurrenceRule: recurrence?.toJson() ?? recurrenceRule,
          recurrenceGroupId: recurrenceGroupId,
        ) {
    // Set icon fields from IconData if provided
    if (icon != null) {
      this.iconCodePoint = icon.codePoint;
      this.iconFontFamily = icon.fontFamily;
      this.iconFontPackage = icon.fontPackage;
    }
  }

  /// Get TimeOfDay from stored hour/minute
  TimeOfDay? get dueTime {
    if (dueTimeHour == null || dueTimeMinute == null) return null;
    return TimeOfDay(hour: dueTimeHour!, minute: dueTimeMinute!);
  }

  /// Set TimeOfDay by storing hour/minute
  set dueTime(TimeOfDay? value) {
    dueTimeHour = value?.hour;
    dueTimeMinute = value?.minute;
  }

  /// Get IconData from stored code point
  IconData? get icon {
    if (iconCodePoint == null) return null;
    return IconData(
      iconCodePoint!,
      fontFamily: iconFontFamily ?? 'MaterialIcons',
      fontPackage: iconFontPackage,
    );
  }

  /// Set IconData by storing code point
  set icon(IconData? value) {
    iconCodePoint = value?.codePoint;
    iconFontFamily = value?.fontFamily;
    iconFontPackage = value?.fontPackage;
  }

  /// Create a copy of this task with updated fields
  Task copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? dueDate,
    TimeOfDay? dueTime,
    String? priority,
    String? categoryId,
    String? taskTypeId,
    List<Subtask>? subtasks,
    Map<String, bool>? subtaskCompletion,
    String? recurrenceRule,
    String? status,
    int? pointsEarned,
    String? remindersJson,
    String? notes,
    DateTime? createdAt,
    DateTime? completedAt,
    DateTime? postponedTo,
    String? postponeReason,
    String? notDoneReason,
    String? reflection,
    DateTime? originalDueDate,
    String? parentTaskId,
    String? rootTaskId,
    DateTime? postponedAt,
    int? iconCodePoint,
    String? iconFontFamily,
    String? iconFontPackage,
    List<String>? tags,
    int? postponeCount,
    String? postponeHistory,
    String? recurrenceGroupId,
    int? recurrenceIndex,
    bool? isRoutine,
    String? routineGroupId,
    String? routineStatus,
    bool? isRoutineActive,
    DateTime? routineProgressStartDate,
    String? taskKind,
    int? cumulativePostponePenalty,
    bool? isSpecial,
    DateTime? snoozedUntil,
    String? snoozeHistory,
    bool? counterEnabled,
    RecurrenceRule? recurrence,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      dueTime: dueTime ?? this.dueTime,
      priority: priority ?? this.priority,
      categoryId: categoryId ?? this.categoryId,
      taskTypeId: taskTypeId ?? this.taskTypeId,
      subtasks: subtasks ?? this.subtasks,
      subtaskCompletion: subtaskCompletion ?? this.subtaskCompletion,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      status: status ?? this.status,
      pointsEarned: pointsEarned ?? this.pointsEarned,
      remindersJson: remindersJson ?? this.remindersJson,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      postponedTo: postponedTo ?? this.postponedTo,
      postponeReason: postponeReason ?? this.postponeReason,
      notDoneReason: notDoneReason ?? this.notDoneReason,
      reflection: reflection ?? this.reflection,
      originalDueDate: originalDueDate ?? this.originalDueDate,
      parentTaskId: parentTaskId ?? this.parentTaskId,
      rootTaskId: rootTaskId ?? this.rootTaskId,
      postponedAt: postponedAt ?? this.postponedAt,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      iconFontFamily: iconFontFamily ?? this.iconFontFamily,
      iconFontPackage: iconFontPackage ?? this.iconFontPackage,
      tags: tags ?? this.tags,
      postponeCount: postponeCount ?? this.postponeCount,
      postponeHistory: postponeHistory ?? this.postponeHistory,
      recurrenceGroupId: recurrenceGroupId ?? this.recurrenceGroupId,
      recurrenceIndex: recurrenceIndex ?? this.recurrenceIndex,
      isRoutine: isRoutine ?? this.isRoutine,
      routineGroupId: routineGroupId ?? this.routineGroupId,
      routineStatus: routineStatus ?? this.routineStatus,
      isRoutineActive: isRoutineActive ?? this.isRoutineActive,
      routineProgressStartDate: routineProgressStartDate ?? this.routineProgressStartDate,
      taskKind: taskKind ?? this.taskKind,
      cumulativePostponePenalty: cumulativePostponePenalty ?? this.cumulativePostponePenalty,
      isSpecial: isSpecial ?? this.isSpecial,
      snoozedUntil: snoozedUntil ?? this.snoozedUntil,
      snoozeHistory: snoozeHistory ?? this.snoozeHistory,
      counterEnabled: counterEnabled ?? this.counterEnabled,
      recurrence: recurrence ?? this.recurrence,
    );
  }

  /// Get the net points for this task (considering postpone penalties)
  /// Net = pointsEarned + cumulativePostponePenalty (penalty is negative)
  int get netPoints => pointsEarned + cumulativePostponePenalty;

  /// Parsed reminders for this task.
  /// 
  /// - If `remindersJson` is a JSON list, it is decoded.
  /// - If it's legacy text (e.g., '5 min before'), parsing is handled by ReminderManager (migration path).
  ///   We return empty here to avoid coupling models to services.
  List<Reminder> get reminders {
    final raw = (remindersJson ?? '').trim();
    if (raw.isEmpty) return const [];
    if (raw.startsWith('[')) {
      try {
        return Reminder.decodeList(raw);
      } catch (_) {
        return const [];
      }
    }
    // Legacy string: leave parsing to ReminderManager to keep model layer clean.
    return const [];
  }

  /// Check if task is currently snoozed
  bool get isSnoozed {
    if (snoozedUntil == null) return false;
    return snoozedUntil!.isAfter(DateTime.now());
  }

  /// Parsed snooze history entries (most-recent last).
  List<Map<String, dynamic>> get snoozeHistoryEntries {
    final raw = (snoozeHistory ?? '').trim();
    if (raw.isEmpty) return const [];
    try {
      return List<Map<String, dynamic>>.from(jsonDecode(raw));
    } catch (_) {
      return const [];
    }
  }

  /// Check if task is overdue
  bool get isOverdue {
    // Completed, postponed, or marked as not done tasks are not considered overdue
    if (status == 'completed' || status == 'postponed' || status == 'not_done') return false;
    
    final now = DateTime.now();
    final taskDateTime = DateTime(
      dueDate.year,
      dueDate.month,
      dueDate.day,
      dueTimeHour ?? 23,
      dueTimeMinute ?? 59,
    );
    return taskDateTime.isBefore(now);
  }

  /// Get completion percentage of subtasks
  double get subtaskProgress {
    if (subtasks == null || subtasks!.isEmpty) return 0.0;
    
    final completed = subtasks!.where((s) => s.isCompleted).length;
    return completed / subtasks!.length;
  }

  /// Get RecurrenceRule from stored JSON string
  RecurrenceRule? get recurrence {
    if (recurrenceRule == null || recurrenceRule!.isEmpty) return null;
    try {
      return RecurrenceRule.fromJson(recurrenceRule!);
    } catch (e) {
      // If parsing fails, return null (backward compatibility)
      return null;
    }
  }

  /// Set RecurrenceRule by storing JSON string
  set recurrence(RecurrenceRule? value) {
    recurrenceRule = value?.toJson();
  }

  /// Check if task has recurrence
  bool get hasRecurrence => recurrence != null;

  /// Check if this is a routine task (either template or instance)
  bool get isRoutineTask => isRoutine || routineGroupId != null;

  /// Get the routine group ID for this task
  /// Returns the task's own ID if it's the first routine, otherwise returns routineGroupId
  String get effectiveRoutineGroupId => routineGroupId ?? id;

  /// Create a new routine instance from this task with a new due date
  /// Used when "Plan Next" is triggered after completing a routine
  Task createNextRoutineInstance({
    required DateTime newDueDate,
    TimeOfDay? newDueTime,
    String? routineStatus,
    DateTime? progressStartDate,
  }) {
    return Task(
      title: title,
      description: description,
      dueDate: newDueDate,
      dueTime: newDueTime ?? dueTime,
      priority: priority,
      categoryId: categoryId,
      taskTypeId: taskTypeId,
      iconCodePoint: iconCodePoint,
      iconFontFamily: iconFontFamily,
      iconFontPackage: iconFontPackage,
      tags: tags != null ? List<String>.from(tags!) : null,
      remindersJson: remindersJson,
      notes: notes,
      isRoutine: true,
      routineGroupId: effectiveRoutineGroupId, // Link to the same routine group
      routineStatus: routineStatus ?? 'planned',
      isRoutineActive: isRoutineActive,
      status: 'pending',
      routineProgressStartDate: progressStartDate ?? DateTime.now(), // Start countdown from now
      taskKind: TaskKind.routine, // Explicitly mark as routine
    );
  }

  /// Check if this routine is active
  bool get isActiveRoutine => isRoutine && isRoutineActive;

  /// Get the effective progress start date for routine countdown
  /// Returns routineProgressStartDate if set, otherwise falls back to createdAt
  DateTime get effectiveProgressStartDate => routineProgressStartDate ?? createdAt;

  /// Calculate routine progress percentage (0.0 to 1.0+)
  /// Returns how much of the time has elapsed from start to due date
  /// > 1.0 means overdue
  double get routineProgress {
    final now = DateTime.now();
    final start = effectiveProgressStartDate;
    final end = DateTime(
      dueDate.year,
      dueDate.month,
      dueDate.day,
      dueTimeHour ?? 23,
      dueTimeMinute ?? 59,
    );
    
    final totalDuration = end.difference(start);
    if (totalDuration.inSeconds <= 0) return 1.0; // Already at or past due
    
    final elapsed = now.difference(start);
    return elapsed.inSeconds / totalDuration.inSeconds;
  }
}


