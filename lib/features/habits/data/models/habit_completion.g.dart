// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'habit_completion.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HabitCompletionAdapter extends TypeAdapter<HabitCompletion> {
  @override
  final int typeId = 11;

  @override
  HabitCompletion read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HabitCompletion(
      id: fields[0] as String?,
      habitId: fields[1] as String,
      completedDate: fields[2] as DateTime,
      completedAt: fields[3] as DateTime?,
      count: fields[4] as int,
      note: fields[5] as String?,
      isSkipped: fields[6] as bool,
      skipReason: fields[7] as String?,
      answer: fields[8] as bool?,
      isPostponed: fields[9] as bool,
      actualValue: fields[10] as double?,
      actualDurationMinutes: fields[11] as int?,
      pointsEarned: fields[12] as int,
    );
  }

  @override
  void write(BinaryWriter writer, HabitCompletion obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.habitId)
      ..writeByte(2)
      ..write(obj.completedDate)
      ..writeByte(3)
      ..write(obj.completedAt)
      ..writeByte(4)
      ..write(obj.count)
      ..writeByte(5)
      ..write(obj.note)
      ..writeByte(6)
      ..write(obj.isSkipped)
      ..writeByte(7)
      ..write(obj.skipReason)
      ..writeByte(8)
      ..write(obj.answer)
      ..writeByte(9)
      ..write(obj.isPostponed)
      ..writeByte(10)
      ..write(obj.actualValue)
      ..writeByte(11)
      ..write(obj.actualDurationMinutes)
      ..writeByte(12)
      ..write(obj.pointsEarned);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HabitCompletionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
