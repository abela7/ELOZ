// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_reason.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TaskReasonAdapter extends TypeAdapter<TaskReason> {
  @override
  final int typeId = 3;

  @override
  TaskReason read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TaskReason(
      id: fields[0] as String?,
      text: fields[1] as String,
      iconCodePoint: fields[2] as int?,
      iconFontFamily: fields[3] as String?,
      iconFontPackage: fields[4] as String?,
      typeIndex: fields[5] as int,
      createdAt: fields[6] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, TaskReason obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.text)
      ..writeByte(2)
      ..write(obj.iconCodePoint)
      ..writeByte(3)
      ..write(obj.iconFontFamily)
      ..writeByte(4)
      ..write(obj.iconFontPackage)
      ..writeByte(5)
      ..write(obj.typeIndex)
      ..writeByte(6)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskReasonAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
