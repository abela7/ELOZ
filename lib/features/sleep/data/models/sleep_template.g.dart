// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sleep_template.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SleepTemplateAdapter extends TypeAdapter<SleepTemplate> {
  @override
  final int typeId = 53;

  @override
  SleepTemplate read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SleepTemplate(
      id: fields[0] as String?,
      name: fields[1] as String,
      bedHour: fields[2] as int,
      bedMinute: fields[3] as int,
      wakeHour: fields[4] as int,
      wakeMinute: fields[5] as int,
      isNap: fields[6] as bool,
      createdAt: fields[7] as DateTime?,
      updatedAt: fields[8] as DateTime?,
      isDefault: fields[9] as bool,
      schemaVersion: fields[10] as int,
    );
  }

  @override
  void write(BinaryWriter writer, SleepTemplate obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.bedHour)
      ..writeByte(3)
      ..write(obj.bedMinute)
      ..writeByte(4)
      ..write(obj.wakeHour)
      ..writeByte(5)
      ..write(obj.wakeMinute)
      ..writeByte(6)
      ..write(obj.isNap)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.updatedAt)
      ..writeByte(9)
      ..write(obj.isDefault)
      ..writeByte(10)
      ..write(obj.schemaVersion);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SleepTemplateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
