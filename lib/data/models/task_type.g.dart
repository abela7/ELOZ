// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_type.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TaskTypeAdapter extends TypeAdapter<TaskType> {
  @override
  final int typeId = 1;

  @override
  TaskType read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TaskType(
      id: fields[0] as String?,
      name: fields[1] as String,
      basePoints: fields[2] as int,
      rewardOnDone: fields[3] as int,
      penaltyNotDone: fields[4] as int,
      penaltyPostpone: fields[5] as int,
      createdAt: fields[6] as DateTime?,
      updatedAt: fields[7] as DateTime?,
      iconCode: fields[8] as int?,
      colorValue: fields[9] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, TaskType obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.basePoints)
      ..writeByte(3)
      ..write(obj.rewardOnDone)
      ..writeByte(4)
      ..write(obj.penaltyNotDone)
      ..writeByte(5)
      ..write(obj.penaltyPostpone)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.updatedAt)
      ..writeByte(8)
      ..write(obj.iconCode)
      ..writeByte(9)
      ..write(obj.colorValue);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
