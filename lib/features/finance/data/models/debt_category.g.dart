// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'debt_category.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DebtCategoryAdapter extends TypeAdapter<DebtCategory> {
  @override
  final int typeId = 25;

  @override
  DebtCategory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DebtCategory(
      id: fields[0] as String?,
      name: fields[1] as String,
      description: fields[2] as String?,
      iconCodePoint: fields[3] as int?,
      iconFontFamily: fields[4] as String?,
      iconFontPackage: fields[5] as String?,
      colorValue: fields[6] == null ? 4294901760 : fields[6] as int?,
      createdAt: fields[7] as DateTime?,
      isActive: fields[8] == null ? true : fields[8] as bool,
      sortOrder: fields[9] == null ? 0 : fields[9] as int,
    );
  }

  @override
  void write(BinaryWriter writer, DebtCategory obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.iconCodePoint)
      ..writeByte(4)
      ..write(obj.iconFontFamily)
      ..writeByte(5)
      ..write(obj.iconFontPackage)
      ..writeByte(6)
      ..write(obj.colorValue)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.isActive)
      ..writeByte(9)
      ..write(obj.sortOrder);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DebtCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
