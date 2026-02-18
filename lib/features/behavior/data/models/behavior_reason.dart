import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import 'behavior_type.dart';

/// Reusable reason that can be assigned to many behavior logs.
class BehaviorReason extends HiveObject {
  static const Object _unset = Object();

  BehaviorReason({
    String? id,
    required this.name,
    required this.type,
    this.isActive = true,
    DateTime? createdAt,
    this.updatedAt,
    this.deletedAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  final String id;
  final String name;
  final String type;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;
  bool get isGood => type == BehaviorType.good;
  bool get isBad => type == BehaviorType.bad;

  BehaviorReason copyWith({
    String? id,
    String? name,
    String? type,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? deletedAt = _unset,
  }) {
    return BehaviorReason(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt == _unset ? this.deletedAt : deletedAt as DateTime?,
    );
  }
}

class BehaviorReasonAdapter extends TypeAdapter<BehaviorReason> {
  @override
  final int typeId = 64;

  @override
  BehaviorReason read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return BehaviorReason(
      id: fields[0] as String?,
      name: fields[1] as String? ?? '',
      type: fields[2] as String? ?? BehaviorType.good,
      isActive: fields[3] as bool? ?? true,
      createdAt: fields[4] as DateTime?,
      updatedAt: fields[5] as DateTime?,
      deletedAt: fields[6] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, BehaviorReason obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.isActive)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.updatedAt)
      ..writeByte(6)
      ..write(obj.deletedAt);
  }
}
