// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'unit_category.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UnitCategoryAdapter extends TypeAdapter<UnitCategory> {
  @override
  final int typeId = 16;

  @override
  UnitCategory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UnitCategory(
      id: fields[0] as String?,
      name: fields[1] as String,
      iconCodePoint: fields[2] as int,
      iconFontFamily: fields[3] as String?,
      iconFontPackage: fields[4] as String?,
      colorValue: fields[5] as int,
      isDefault: fields[6] as bool,
      sortOrder: fields[7] as int,
      createdAt: fields[8] as DateTime?,
      updatedAt: fields[9] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, UnitCategory obj) {
    writer
      ..writeByte(10)
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
      ..write(obj.isDefault)
      ..writeByte(7)
      ..write(obj.sortOrder)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnitCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
