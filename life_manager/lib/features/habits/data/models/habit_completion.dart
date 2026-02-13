import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'habit_completion.g.dart';

/// Represents a single completion of a habit
/// Used for tracking history, calculating streaks, and analytics
@HiveType(typeId: 11)
class HabitCompletion extends HiveObject {
  @HiveField(0)
  String id;

  /// Reference to the habit this completion belongs to
  @HiveField(1)
  String habitId;

  /// Date of completion (time stripped, just the date)
  @HiveField(2)
  DateTime completedDate;

  /// Actual time of completion
  @HiveField(3)
  DateTime completedAt;

  /// Number of times completed on this date (for habits with targetCount > 1)
  @HiveField(4)
  int count;

  /// Optional note for this completion
  @HiveField(5)
  String? note;

  /// Whether this was marked as skipped (valid skip, not a miss)
  @HiveField(6)
  bool isSkipped;

  /// Reason for skipping (if skipped)
  @HiveField(7)
  String? skipReason;

  /// For Yes/No type: Whether answer was YES (true) or NO (false)
  @HiveField(8)
  bool? answer;

  /// For Yes/No type: Whether it was postponed
  @HiveField(9)
  bool isPostponed;

  /// For Numeric type: Actual value achieved
  @HiveField(10)
  double? actualValue;

  /// For Timer type: Actual duration in minutes
  @HiveField(11)
  int? actualDurationMinutes;

  /// Points earned for this specific completion
  @HiveField(12)
  int pointsEarned;

  HabitCompletion({
    String? id,
    required this.habitId,
    required this.completedDate,
    DateTime? completedAt,
    this.count = 1,
    this.note,
    this.isSkipped = false,
    this.skipReason,
    this.answer,
    this.isPostponed = false,
    this.actualValue,
    this.actualDurationMinutes,
    this.pointsEarned = 0,
  })  : id = id ?? const Uuid().v4(),
        completedAt = completedAt ?? DateTime.now();

  /// Create a completion for today with YES answer
  factory HabitCompletion.yes({
    required String habitId,
    int pointsEarned = 0,
    String? note,
  }) {
    final now = DateTime.now();
    return HabitCompletion(
      habitId: habitId,
      completedDate: DateTime(now.year, now.month, now.day),
      completedAt: now,
      count: 1,
      note: note,
      answer: true,
      pointsEarned: pointsEarned,
    );
  }

  /// Create a completion for today with NO answer
  factory HabitCompletion.no({
    required String habitId,
    int pointsEarned = 0,
    String? note,
  }) {
    final now = DateTime.now();
    return HabitCompletion(
      habitId: habitId,
      completedDate: DateTime(now.year, now.month, now.day),
      completedAt: now,
      count: 0,
      note: note,
      answer: false,
      pointsEarned: pointsEarned,
    );
  }

  /// Create a postponed entry
  factory HabitCompletion.postponed({
    required String habitId,
    int pointsEarned = 0,
    String? note,
  }) {
    final now = DateTime.now();
    return HabitCompletion(
      habitId: habitId,
      completedDate: DateTime(now.year, now.month, now.day),
      completedAt: now,
      count: 0,
      note: note,
      isPostponed: true,
      pointsEarned: pointsEarned,
    );
  }

  /// Create a numeric completion entry
  factory HabitCompletion.numeric({
    required String habitId,
    required DateTime date,
    required double actualValue,
    int pointsEarned = 0,
    String? note,
  }) {
    return HabitCompletion(
      habitId: habitId,
      completedDate: DateTime(date.year, date.month, date.day),
      completedAt: DateTime.now(),
      count: 1,
      note: note,
      actualValue: actualValue,
      pointsEarned: pointsEarned,
    );
  }

  /// Create a timer completion entry
  factory HabitCompletion.timer({
    required String habitId,
    required DateTime date,
    required int actualDurationMinutes,
    int pointsEarned = 0,
    String? note,
  }) {
    return HabitCompletion(
      habitId: habitId,
      completedDate: DateTime(date.year, date.month, date.day),
      completedAt: DateTime.now(),
      count: 1,
      note: note,
      actualDurationMinutes: actualDurationMinutes,
      pointsEarned: pointsEarned,
    );
  }

  /// Create a completion for today
  factory HabitCompletion.today({
    required String habitId,
    int count = 1,
    String? note,
  }) {
    final now = DateTime.now();
    return HabitCompletion(
      habitId: habitId,
      completedDate: DateTime(now.year, now.month, now.day),
      completedAt: now,
      count: count,
      note: note,
    );
  }

  /// Create a skipped entry
  factory HabitCompletion.skipped({
    required String habitId,
    required DateTime date,
    String? reason,
  }) {
    return HabitCompletion(
      habitId: habitId,
      completedDate: DateTime(date.year, date.month, date.day),
      completedAt: DateTime.now(),
      count: 0,
      isSkipped: true,
      skipReason: reason,
    );
  }

  /// Check if this completion is for a specific date
  bool isForDate(DateTime date) {
    return completedDate.year == date.year &&
        completedDate.month == date.month &&
        completedDate.day == date.day;
  }

  /// Create a copy with updated fields
  HabitCompletion copyWith({
    String? id,
    String? habitId,
    DateTime? completedDate,
    DateTime? completedAt,
    int? count,
    String? note,
    bool? isSkipped,
    String? skipReason,
    bool? answer,
    bool? isPostponed,
    double? actualValue,
    int? actualDurationMinutes,
    int? pointsEarned,
  }) {
    return HabitCompletion(
      id: id ?? this.id,
      habitId: habitId ?? this.habitId,
      completedDate: completedDate ?? this.completedDate,
      completedAt: completedAt ?? this.completedAt,
      count: count ?? this.count,
      note: note ?? this.note,
      isSkipped: isSkipped ?? this.isSkipped,
      skipReason: skipReason ?? this.skipReason,
      answer: answer ?? this.answer,
      isPostponed: isPostponed ?? this.isPostponed,
      actualValue: actualValue ?? this.actualValue,
      actualDurationMinutes: actualDurationMinutes ?? this.actualDurationMinutes,
      pointsEarned: pointsEarned ?? this.pointsEarned,
    );
  }

  /// Get human-readable completion status
  String get statusDescription {
    if (isSkipped) return 'Skipped';
    if (isPostponed) return 'Postponed';
    if (answer != null) {
      return answer! ? 'Yes' : 'No';
    }
    if (actualValue != null) return 'Value: $actualValue';
    if (actualDurationMinutes != null) {
      final hours = actualDurationMinutes! ~/ 60;
      final mins = actualDurationMinutes! % 60;
      return hours > 0 ? '${hours}h ${mins}m' : '${mins}m';
    }
    return count > 0 ? 'Completed' : 'Not done';
  }
}
