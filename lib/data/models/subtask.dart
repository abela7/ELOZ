import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'subtask.g.dart';

@HiveType(typeId: 4)
class Subtask extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  bool isCompleted;

  Subtask({
    String? id,
    required this.title,
    this.isCompleted = false,
  }) : id = id ?? const Uuid().v4();

  Subtask copyWith({
    String? id,
    String? title,
    bool? isCompleted,
  }) {
    return Subtask(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
