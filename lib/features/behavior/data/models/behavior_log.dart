import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

/// One behavior occurrence log entry.
class BehaviorLog extends HiveObject {
  static const Object _unset = Object();

  BehaviorLog({
    String? id,
    required this.behaviorId,
    required this.occurredAt,
    String? dateKey,
    this.durationMinutes,
    this.intensity,
    this.note,
    DateTime? createdAt,
    this.updatedAt,
  }) : id = id ?? const Uuid().v4(),
       dateKey = dateKey ?? deriveDateKey(occurredAt),
       createdAt = createdAt ?? DateTime.now();

  final String id;
  final String behaviorId;
  final DateTime occurredAt;
  final String dateKey;
  final int? durationMinutes;
  final int? intensity;
  final String? note;
  final DateTime createdAt;
  final DateTime? updatedAt;

  BehaviorLog copyWith({
    String? id,
    String? behaviorId,
    DateTime? occurredAt,
    String? dateKey,
    Object? durationMinutes = _unset,
    Object? intensity = _unset,
    Object? note = _unset,
    DateTime? createdAt,
    Object? updatedAt = _unset,
  }) {
    final nextOccurredAt = occurredAt ?? this.occurredAt;
    return BehaviorLog(
      id: id ?? this.id,
      behaviorId: behaviorId ?? this.behaviorId,
      occurredAt: nextOccurredAt,
      dateKey: dateKey ?? deriveDateKey(nextOccurredAt),
      durationMinutes: durationMinutes == _unset
          ? this.durationMinutes
          : durationMinutes as int?,
      intensity: intensity == _unset ? this.intensity : intensity as int?,
      note: note == _unset ? this.note : note as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt == _unset ? this.updatedAt : updatedAt as DateTime?,
    );
  }

  static String deriveDateKey(DateTime value) {
    final local = value.toLocal();
    final yyyy = local.year.toString().padLeft(4, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return '$yyyy$mm$dd';
  }
}

class BehaviorLogAdapter extends TypeAdapter<BehaviorLog> {
  @override
  final int typeId = 65;

  @override
  BehaviorLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    final occurredAt = fields[2] as DateTime? ?? DateTime.now();
    return BehaviorLog(
      id: fields[0] as String?,
      behaviorId: fields[1] as String? ?? '',
      occurredAt: occurredAt,
      dateKey: fields[3] as String? ?? BehaviorLog.deriveDateKey(occurredAt),
      durationMinutes: fields[4] as int?,
      intensity: fields[5] as int?,
      note: fields[6] as String?,
      createdAt: fields[7] as DateTime?,
      updatedAt: fields[8] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, BehaviorLog obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.behaviorId)
      ..writeByte(2)
      ..write(obj.occurredAt)
      ..writeByte(3)
      ..write(obj.dateKey)
      ..writeByte(4)
      ..write(obj.durationMinutes)
      ..writeByte(5)
      ..write(obj.intensity)
      ..writeByte(6)
      ..write(obj.note)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.updatedAt);
  }
}
