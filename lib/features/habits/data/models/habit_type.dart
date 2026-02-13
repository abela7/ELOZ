import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'habit_type.g.dart';

/// Habit Type model with Hive persistence
/// Defines point values for different types of habits
@HiveType(typeId: 13)
class HabitType extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  int basePoints; // Base points for this habit type

  @HiveField(3)
  int rewardOnDone; // Points earned when habit is completed

  @HiveField(4)
  int penaltyNotDone; // Points lost when habit is not done (negative)

  @HiveField(5)
  int penaltyPostpone; // Points lost when habit is postponed (negative)

  @HiveField(6)
  DateTime createdAt;

  @HiveField(7)
  DateTime? updatedAt;

  HabitType({
    String? id,
    required this.name,
    required this.basePoints,
    required this.rewardOnDone,
    required this.penaltyNotDone,
    required this.penaltyPostpone,
    DateTime? createdAt,
    this.updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  /// Create a copy of this habit type with updated fields
  HabitType copyWith({
    String? id,
    String? name,
    int? basePoints,
    int? rewardOnDone,
    int? penaltyNotDone,
    int? penaltyPostpone,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HabitType(
      id: id ?? this.id,
      name: name ?? this.name,
      basePoints: basePoints ?? this.basePoints,
      rewardOnDone: rewardOnDone ?? this.rewardOnDone,
      penaltyNotDone: penaltyNotDone ?? this.penaltyNotDone,
      penaltyPostpone: penaltyPostpone ?? this.penaltyPostpone,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
