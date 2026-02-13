// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction_template.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TransactionTemplateAdapter extends TypeAdapter<TransactionTemplate> {
  @override
  final int typeId = 27;

  @override
  TransactionTemplate read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TransactionTemplate(
      id: fields[0] as String?,
      name: fields[1] as String,
      transactionTitle: fields[2] as String,
      amount: fields[3] == null ? 0.0 : fields[3] as double,
      type: fields[4] == null ? 'expense' : fields[4] as String,
      categoryId: fields[5] as String?,
      accountId: fields[6] as String?,
      toAccountId: fields[7] as String?,
      description: fields[8] as String?,
      createdAt: fields[9] as DateTime?,
      isRecurring: fields[13] as bool,
      recurrenceRule: fields[14] as String?,
    )
      ..iconCodePoint = fields[10] as int?
      ..iconFontFamily = fields[11] as String?
      ..iconFontPackage = fields[12] as String?;
  }

  @override
  void write(BinaryWriter writer, TransactionTemplate obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.transactionTitle)
      ..writeByte(3)
      ..write(obj.amount)
      ..writeByte(4)
      ..write(obj.type)
      ..writeByte(5)
      ..write(obj.categoryId)
      ..writeByte(6)
      ..write(obj.accountId)
      ..writeByte(7)
      ..write(obj.toAccountId)
      ..writeByte(8)
      ..write(obj.description)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.iconCodePoint)
      ..writeByte(11)
      ..write(obj.iconFontFamily)
      ..writeByte(12)
      ..write(obj.iconFontPackage)
      ..writeByte(13)
      ..write(obj.isRecurring)
      ..writeByte(14)
      ..write(obj.recurrenceRule);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionTemplateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
