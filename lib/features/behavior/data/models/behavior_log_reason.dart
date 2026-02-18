import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

/// Join table row assigning one reason to one behavior log.
class BehaviorLogReason extends HiveObject {
  BehaviorLogReason({
    String? id,
    required this.behaviorLogId,
    required this.reasonId,
    DateTime? createdAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  final String id;
  final String behaviorLogId;
  final String reasonId;
  final DateTime createdAt;
}

class BehaviorLogReasonAdapter extends TypeAdapter<BehaviorLogReason> {
  @override
  final int typeId = 66;

  @override
  BehaviorLogReason read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return BehaviorLogReason(
      id: fields[0] as String?,
      behaviorLogId: fields[1] as String? ?? '',
      reasonId: fields[2] as String? ?? '',
      createdAt: fields[3] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, BehaviorLogReason obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.behaviorLogId)
      ..writeByte(2)
      ..write(obj.reasonId)
      ..writeByte(3)
      ..write(obj.createdAt);
  }
}
