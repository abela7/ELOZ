// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'temptation_log.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TemptationLogAdapter extends TypeAdapter<TemptationLog> {
  @override
  final int typeId = 17;

  @override
  TemptationLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TemptationLog(
      id: fields[0] as String?,
      habitId: fields[1] as String,
      occurredAt: fields[2] as DateTime,
      count: fields[3] as int,
      reasonId: fields[4] as String?,
      reasonText: fields[5] as String?,
      customNote: fields[6] as String?,
      intensityIndex: fields[7] as int,
      didResist: fields[8] as bool,
      location: fields[9] as String?,
      createdAt: fields[10] as DateTime?,
      iconCodePoint: fields[11] as int?,
      colorValue: fields[12] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, TemptationLog obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.habitId)
      ..writeByte(2)
      ..write(obj.occurredAt)
      ..writeByte(3)
      ..write(obj.count)
      ..writeByte(4)
      ..write(obj.reasonId)
      ..writeByte(5)
      ..write(obj.reasonText)
      ..writeByte(6)
      ..write(obj.customNote)
      ..writeByte(7)
      ..write(obj.intensityIndex)
      ..writeByte(8)
      ..write(obj.didResist)
      ..writeByte(9)
      ..write(obj.location)
      ..writeByte(10)
      ..write(obj.createdAt)
      ..writeByte(11)
      ..write(obj.iconCodePoint)
      ..writeByte(12)
      ..write(obj.colorValue);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TemptationLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
