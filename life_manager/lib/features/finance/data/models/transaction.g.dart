// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TransactionAdapter extends TypeAdapter<Transaction> {
  @override
  final int typeId = 20;

  @override
  Transaction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Transaction(
      id: fields[0] as String?,
      title: fields[1] as String,
      description: fields[2] as String?,
      amount: fields[3] == null ? 0.0 : fields[3] as double,
      type: fields[4] == null ? 'expense' : fields[4] as String,
      categoryId: fields[5] as String?,
      accountId: fields[6] as String?,
      toAccountId: fields[7] as String?,
      transactionDate: fields[8] as DateTime,
      createdAt: fields[11] as DateTime?,
      updatedAt: fields[12] as DateTime?,
      notes: fields[13] as String?,
      tags: (fields[14] as List?)?.cast<String>(),
      receiptPath: fields[15] as String?,
      paymentMethod: fields[16] as String?,
      currency: fields[17] as String?,
      isRecurring: fields[18] == null ? false : fields[18] as bool,
      recurrenceRule: fields[19] as String?,
      recurringGroupId: fields[20] as String?,
      location: fields[21] as String?,
      contactPerson: fields[22] as String?,
      isSplit: fields[23] == null ? false : fields[23] as bool,
      splitData: fields[24] as String?,
      iconCodePoint: fields[25] as int?,
      iconFontFamily: fields[26] as String?,
      iconFontPackage: fields[27] as String?,
      needsReview: fields[28] == null ? false : fields[28] as bool,
      isCleared: fields[29] == null ? false : fields[29] as bool,
      clearedDate: fields[30] as DateTime?,
      isBalanceAdjustment: fields[31] == null ? false : fields[31] as bool,
      billId: fields[32] as String?,
      debtId: fields[33] as String?,
    )
      ..transactionTimeHour = fields[9] as int?
      ..transactionTimeMinute = fields[10] as int?;
  }

  @override
  void write(BinaryWriter writer, Transaction obj) {
    writer
      ..writeByte(34)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
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
      ..write(obj.transactionDate)
      ..writeByte(9)
      ..write(obj.transactionTimeHour)
      ..writeByte(10)
      ..write(obj.transactionTimeMinute)
      ..writeByte(11)
      ..write(obj.createdAt)
      ..writeByte(12)
      ..write(obj.updatedAt)
      ..writeByte(13)
      ..write(obj.notes)
      ..writeByte(14)
      ..write(obj.tags)
      ..writeByte(15)
      ..write(obj.receiptPath)
      ..writeByte(16)
      ..write(obj.paymentMethod)
      ..writeByte(17)
      ..write(obj.currency)
      ..writeByte(18)
      ..write(obj.isRecurring)
      ..writeByte(19)
      ..write(obj.recurrenceRule)
      ..writeByte(20)
      ..write(obj.recurringGroupId)
      ..writeByte(21)
      ..write(obj.location)
      ..writeByte(22)
      ..write(obj.contactPerson)
      ..writeByte(23)
      ..write(obj.isSplit)
      ..writeByte(24)
      ..write(obj.splitData)
      ..writeByte(25)
      ..write(obj.iconCodePoint)
      ..writeByte(26)
      ..write(obj.iconFontFamily)
      ..writeByte(27)
      ..write(obj.iconFontPackage)
      ..writeByte(28)
      ..write(obj.needsReview)
      ..writeByte(29)
      ..write(obj.isCleared)
      ..writeByte(30)
      ..write(obj.clearedDate)
      ..writeByte(31)
      ..write(obj.isBalanceAdjustment)
      ..writeByte(32)
      ..write(obj.billId)
      ..writeByte(33)
      ..write(obj.debtId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
