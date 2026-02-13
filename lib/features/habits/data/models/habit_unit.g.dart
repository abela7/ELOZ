// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'habit_unit.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HabitUnitAdapter extends TypeAdapter<HabitUnit> {
  @override
  final int typeId = 15;

  @override
  HabitUnit read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HabitUnit(
      id: fields[0] as String?,
      name: fields[1] as String,
      symbol: fields[2] as String,
      pluralName: fields[3] as String?,
      categoryId: fields[4] as String,
      isDefault: fields[5] as bool,
      iconCodePoint: fields[6] as int?,
      iconFontFamily: fields[7] as String?,
      iconFontPackage: fields[8] as String?,
      createdAt: fields[9] as DateTime?,
      updatedAt: fields[10] as DateTime?,
      conversionFactor: fields[11] as double,
      baseUnitId: fields[12] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, HabitUnit obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.symbol)
      ..writeByte(3)
      ..write(obj.pluralName)
      ..writeByte(4)
      ..write(obj.categoryId)
      ..writeByte(5)
      ..write(obj.isDefault)
      ..writeByte(6)
      ..write(obj.iconCodePoint)
      ..writeByte(7)
      ..write(obj.iconFontFamily)
      ..writeByte(8)
      ..write(obj.iconFontPackage)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.updatedAt)
      ..writeByte(11)
      ..write(obj.conversionFactor)
      ..writeByte(12)
      ..write(obj.baseUnitId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HabitUnitAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
