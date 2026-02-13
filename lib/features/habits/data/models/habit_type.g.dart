// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'habit_type.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HabitTypeAdapter extends TypeAdapter<HabitType> {
  @override
  final int typeId = 13;

  @override
  HabitType read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HabitType(
      id: fields[0] as String?,
      name: fields[1] as String,
      basePoints: fields[2] as int,
      rewardOnDone: fields[3] as int,
      penaltyNotDone: fields[4] as int,
      penaltyPostpone: fields[5] as int,
      createdAt: fields[6] as DateTime?,
      updatedAt: fields[7] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, HabitType obj) {
    writer
      ..writeByte(8)
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
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HabitTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
