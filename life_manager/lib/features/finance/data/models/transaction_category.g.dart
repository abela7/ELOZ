// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction_category.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TransactionCategoryAdapter extends TypeAdapter<TransactionCategory> {
  @override
  final int typeId = 21;

  @override
  TransactionCategory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TransactionCategory(
      id: fields[0] as String?,
      name: fields[1] as String,
      description: fields[2] as String?,
      iconCodePoint: fields[3] as int?,
      iconFontFamily: fields[4] as String?,
      iconFontPackage: fields[5] as String?,
      colorValue: fields[6] == null ? 4291669846 : fields[6] as int?,
      type: fields[7] == null ? 'expense' : fields[7] as String,
      isSystemCategory: fields[8] == null ? false : fields[8] as bool,
      createdAt: fields[9] as DateTime?,
      sortOrder: fields[10] == null ? 0 : fields[10] as int,
      parentCategoryId: fields[11] as String?,
      monthlyBudget: fields[12] as double?,
      isActive: fields[13] == null ? true : fields[13] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, TransactionCategory obj) {
    writer
      ..writeByte(14)
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
      ..write(obj.type)
      ..writeByte(8)
      ..write(obj.isSystemCategory)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.sortOrder)
      ..writeByte(11)
      ..write(obj.parentCategoryId)
      ..writeByte(12)
      ..write(obj.monthlyBudget)
      ..writeByte(13)
      ..write(obj.isActive);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
