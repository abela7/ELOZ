// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bill_category.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BillCategoryAdapter extends TypeAdapter<BillCategory> {
  @override
  final int typeId = 28;

  @override
  BillCategory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BillCategory(
      id: fields[0] as String?,
      name: fields[1] as String,
      isActive: fields[6] == null ? true : fields[6] as bool,
      sortOrder: fields[7] == null ? 0 : fields[7] as int,
      createdAt: fields[8] as DateTime?,
    )
      ..iconCodePoint = fields[2] as int?
      ..iconFontFamily = fields[3] as String?
      ..iconFontPackage = fields[4] as String?
      ..colorValue = fields[5] == null ? 4291669846 : fields[5] as int;
  }

  @override
  void write(BinaryWriter writer, BillCategory obj) {
    writer
      ..writeByte(9)
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
      ..write(obj.isActive)
      ..writeByte(7)
      ..write(obj.sortOrder)
      ..writeByte(8)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BillCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
