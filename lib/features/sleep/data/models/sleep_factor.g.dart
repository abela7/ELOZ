// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sleep_factor.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SleepFactorAdapter extends TypeAdapter<SleepFactor> {
  @override
  final int typeId = 52;

  @override
  SleepFactor read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SleepFactor(
      id: fields[0] as String?,
      name: fields[1] as String,
      description: fields[2] as String?,
      iconCodePoint: fields[3] as int,
      colorValue: fields[4] as int,
      isDefault: fields[5] as bool,
      createdAt: fields[6] as DateTime?,
      schemaVersion: (fields[7] as int?) ?? 1,
      // v1 records do not have factorTypeValue, so default to "bad".
      factorTypeValue: (fields[8] as String?) ?? 'bad',
    );
  }

  @override
  void write(BinaryWriter writer, SleepFactor obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.iconCodePoint)
      ..writeByte(4)
      ..write(obj.colorValue)
      ..writeByte(5)
      ..write(obj.isDefault)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.schemaVersion)
      ..writeByte(8)
      ..write(obj.factorTypeValue);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SleepFactorAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
