// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'habit_reason.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HabitReasonAdapter extends TypeAdapter<HabitReason> {
  @override
  final int typeId = 12;

  @override
  HabitReason read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HabitReason(
      id: fields[0] as String?,
      text: fields[1] as String,
      iconCodePoint: fields[2] as int?,
      iconFontFamily: fields[3] as String?,
      iconFontPackage: fields[4] as String?,
      typeIndex: fields[5] as int,
      createdAt: fields[6] as DateTime?,
      colorValue: fields[7] as int?,
      isActive: fields[8] as bool,
      isDefault: fields[9] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, HabitReason obj) {
    writer
      ..writeByte(10)
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
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.colorValue)
      ..writeByte(8)
      ..write(obj.isActive)
      ..writeByte(9)
      ..write(obj.isDefault);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HabitReasonAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
