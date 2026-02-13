// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'debt.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DebtAdapter extends TypeAdapter<Debt> {
  @override
  final int typeId = 26;

  @override
  Debt read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Debt(
      id: fields[0] as String?,
      name: fields[1] as String,
      description: fields[2] as String?,
      categoryId: fields[3] as String,
      originalAmount: fields[4] == null ? 0.0 : fields[4] as double,
      currentBalance: fields[5] == null ? 0.0 : fields[5] as double?,
      interestRate: fields[6] as double?,
      creditorName: fields[7] as String?,
      dueDate: fields[8] as DateTime?,
      minimumPayment: fields[9] as double?,
      currency: fields[10] == null ? 'ETB' : fields[10] as String,
      status: fields[11] == null ? 'active' : fields[11] as String,
      createdAt: fields[12] as DateTime?,
      updatedAt: fields[13] as DateTime?,
      paidOffDate: fields[14] as DateTime?,
      notes: fields[15] as String?,
      accountId: fields[16] as String?,
      iconCodePoint: fields[17] as int?,
      iconFontFamily: fields[18] as String?,
      iconFontPackage: fields[19] as String?,
      colorValue: fields[20] as int?,
      reminderEnabled: fields[21] == null ? false : fields[21] as bool,
      reminderDaysBefore: fields[22] == null ? 3 : fields[22] as int,
      paymentLogJson: (fields[23] as List?)?.cast<String>(),
      direction: fields[24] == null ? 'owed' : fields[24] as String,
      transactionId: fields[25] as String?,
      remindersJson: fields[26] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Debt obj) {
    writer
      ..writeByte(27)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.categoryId)
      ..writeByte(4)
      ..write(obj.originalAmount)
      ..writeByte(5)
      ..write(obj.currentBalance)
      ..writeByte(6)
      ..write(obj.interestRate)
      ..writeByte(7)
      ..write(obj.creditorName)
      ..writeByte(8)
      ..write(obj.dueDate)
      ..writeByte(9)
      ..write(obj.minimumPayment)
      ..writeByte(10)
      ..write(obj.currency)
      ..writeByte(11)
      ..write(obj.status)
      ..writeByte(12)
      ..write(obj.createdAt)
      ..writeByte(13)
      ..write(obj.updatedAt)
      ..writeByte(14)
      ..write(obj.paidOffDate)
      ..writeByte(15)
      ..write(obj.notes)
      ..writeByte(16)
      ..write(obj.accountId)
      ..writeByte(17)
      ..write(obj.iconCodePoint)
      ..writeByte(18)
      ..write(obj.iconFontFamily)
      ..writeByte(19)
      ..write(obj.iconFontPackage)
      ..writeByte(20)
      ..write(obj.colorValue)
      ..writeByte(21)
      ..write(obj.reminderEnabled)
      ..writeByte(22)
      ..write(obj.reminderDaysBefore)
      ..writeByte(23)
      ..write(obj.paymentLogJson)
      ..writeByte(24)
      ..write(obj.direction)
      ..writeByte(25)
      ..write(obj.transactionId)
      ..writeByte(26)
      ..write(obj.remindersJson);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DebtAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
