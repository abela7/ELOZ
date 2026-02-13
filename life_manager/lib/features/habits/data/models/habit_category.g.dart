// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'habit_category.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HabitCategoryAdapter extends TypeAdapter<HabitCategory> {
  @override
  final int typeId = 18;

  @override
  HabitCategory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HabitCategory(
      id: fields[0] as String?,
      name: fields[1] as String,
      iconCodePoint: fields[2] as int,
      iconFontFamily: fields[3] as String?,
      iconFontPackage: fields[4] as String?,
      colorValue: fields[5] as int,
      createdAt: fields[6] as DateTime?,
      updatedAt: fields[7] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, HabitCategory obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.iconCodePoint)
      ..writeByte(3)
      ..write(obj.iconFontFamily)
      ..writeByte(4)
      ..write(obj.iconFontPackage)
      ..writeByte(5)
      ..write(obj.colorValue)
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
      other is HabitCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
