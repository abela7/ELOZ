// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bill.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BillAdapter extends TypeAdapter<Bill> {
  @override
  final int typeId = 29;

  @override
  Bill read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Bill(
      id: fields[0] as String?,
      name: fields[1] as String,
      description: fields[2] as String?,
      categoryId: fields[3] as String,
      accountId: fields[4] as String?,
      type: fields[5] == null ? 'bill' : fields[5] as String,
      amountType: fields[6] == null ? 'fixed' : fields[6] as String,
      defaultAmount: fields[7] == null ? 0.0 : fields[7] as double,
      currency: fields[8] == null ? 'ETB' : fields[8] as String,
      frequency: fields[9] == null ? 'monthly' : fields[9] as String,
      recurrenceRule: fields[10] as String?,
      dueDay: fields[11] as int?,
      nextDueDate: fields[12] as DateTime?,
      lastPaidDate: fields[13] as DateTime?,
      lastPaidAmount: fields[14] as double?,
      isActive: fields[15] == null ? true : fields[15] as bool,
      autoPayEnabled: fields[16] == null ? false : fields[16] as bool,
      reminderEnabled: fields[17] == null ? true : fields[17] as bool,
      reminderDaysBefore: fields[18] == null ? 3 : fields[18] as int,
      createdAt: fields[23] as DateTime?,
      notes: fields[24] as String?,
      providerName: fields[25] as String?,
      paymentLink: fields[26] as String?,
      startDate: fields[27] as DateTime?,
      endCondition: fields[28] == null ? 'indefinite' : fields[28] as String,
      endOccurrences: fields[29] as int?,
      endAmount: fields[30] as double?,
      endDate: fields[31] as DateTime?,
      occurrenceCount: fields[32] == null ? 0 : fields[32] as int,
      totalPaidAmount: fields[33] == null ? 0.0 : fields[33] as double,
      remindersJson: fields[34] as String?,
    )
      ..iconCodePoint = fields[19] as int?
      ..iconFontFamily = fields[20] as String?
      ..iconFontPackage = fields[21] as String?
      ..colorValue = fields[22] == null ? 4291669846 : fields[22] as int;
  }

  @override
  void write(BinaryWriter writer, Bill obj) {
    writer
      ..writeByte(35)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.categoryId)
      ..writeByte(4)
      ..write(obj.accountId)
      ..writeByte(5)
      ..write(obj.type)
      ..writeByte(6)
      ..write(obj.amountType)
      ..writeByte(7)
      ..write(obj.defaultAmount)
      ..writeByte(8)
      ..write(obj.currency)
      ..writeByte(9)
      ..write(obj.frequency)
      ..writeByte(10)
      ..write(obj.recurrenceRule)
      ..writeByte(11)
      ..write(obj.dueDay)
      ..writeByte(12)
      ..write(obj.nextDueDate)
      ..writeByte(13)
      ..write(obj.lastPaidDate)
      ..writeByte(14)
      ..write(obj.lastPaidAmount)
      ..writeByte(15)
      ..write(obj.isActive)
      ..writeByte(16)
      ..write(obj.autoPayEnabled)
      ..writeByte(17)
      ..write(obj.reminderEnabled)
      ..writeByte(18)
      ..write(obj.reminderDaysBefore)
      ..writeByte(19)
      ..write(obj.iconCodePoint)
      ..writeByte(20)
      ..write(obj.iconFontFamily)
      ..writeByte(21)
      ..write(obj.iconFontPackage)
      ..writeByte(22)
      ..write(obj.colorValue)
      ..writeByte(23)
      ..write(obj.createdAt)
      ..writeByte(24)
      ..write(obj.notes)
      ..writeByte(25)
      ..write(obj.providerName)
      ..writeByte(26)
      ..write(obj.paymentLink)
      ..writeByte(27)
      ..write(obj.startDate)
      ..writeByte(28)
      ..write(obj.endCondition)
      ..writeByte(29)
      ..write(obj.endOccurrences)
      ..writeByte(30)
      ..write(obj.endAmount)
      ..writeByte(31)
      ..write(obj.endDate)
      ..writeByte(32)
      ..write(obj.occurrenceCount)
      ..writeByte(33)
      ..write(obj.totalPaidAmount)
      ..writeByte(34)
      ..write(obj.remindersJson);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BillAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
