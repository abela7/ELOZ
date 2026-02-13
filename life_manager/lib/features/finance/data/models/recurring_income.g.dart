// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recurring_income.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RecurringIncomeAdapter extends TypeAdapter<RecurringIncome> {
  @override
  final int typeId = 35;

  @override
  RecurringIncome read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RecurringIncome(
      id: fields[0] as String?,
      title: fields[1] as String,
      description: fields[2] as String?,
      amount: fields[3] == null ? 0.0 : fields[3] as double,
      currency: fields[4] == null ? 'ETB' : fields[4] as String,
      categoryId: fields[5] as String,
      accountId: fields[6] as String?,
      startDate: fields[7] as DateTime,
      endDate: fields[8] as DateTime?,
      frequency: fields[9] == null ? 'monthly' : fields[9] as String,
      dayOfMonth: fields[10] == null ? 1 : fields[10] as int,
      dayOfWeek: fields[11] == null ? 1 : fields[11] as int,
      isActive: fields[12] == null ? true : fields[12] as bool,
      createdAt: fields[13] as DateTime?,
      updatedAt: fields[14] as DateTime?,
      notes: fields[15] as String?,
      iconCodePoint: fields[16] as int?,
      iconFontFamily: fields[17] as String?,
      iconFontPackage: fields[18] as String?,
      colorValue: fields[19] as int?,
      autoCreateTransaction: fields[20] as bool,
      notifyOnDue: fields[21] as bool,
      notifyDaysBefore: fields[22] as int,
      lastGeneratedDate: fields[23] as DateTime?,
      payerName: fields[24] as String?,
      taxCategory: fields[25] as String?,
      isGuaranteed: fields[26] as bool,
      reminderEnabled: fields[27] as bool? ?? true,
      remindersJson: fields[28] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, RecurringIncome obj) {
    writer
      ..writeByte(29)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.amount)
      ..writeByte(4)
      ..write(obj.currency)
      ..writeByte(5)
      ..write(obj.categoryId)
      ..writeByte(6)
      ..write(obj.accountId)
      ..writeByte(7)
      ..write(obj.startDate)
      ..writeByte(8)
      ..write(obj.endDate)
      ..writeByte(9)
      ..write(obj.frequency)
      ..writeByte(10)
      ..write(obj.dayOfMonth)
      ..writeByte(11)
      ..write(obj.dayOfWeek)
      ..writeByte(12)
      ..write(obj.isActive)
      ..writeByte(13)
      ..write(obj.createdAt)
      ..writeByte(14)
      ..write(obj.updatedAt)
      ..writeByte(15)
      ..write(obj.notes)
      ..writeByte(16)
      ..write(obj.iconCodePoint)
      ..writeByte(17)
      ..write(obj.iconFontFamily)
      ..writeByte(18)
      ..write(obj.iconFontPackage)
      ..writeByte(19)
      ..write(obj.colorValue)
      ..writeByte(20)
      ..write(obj.autoCreateTransaction)
      ..writeByte(21)
      ..write(obj.notifyOnDue)
      ..writeByte(22)
      ..write(obj.notifyDaysBefore)
      ..writeByte(23)
      ..write(obj.lastGeneratedDate)
      ..writeByte(24)
      ..write(obj.payerName)
      ..writeByte(25)
      ..write(obj.taxCategory)
      ..writeByte(26)
      ..write(obj.isGuaranteed)
      ..writeByte(27)
      ..write(obj.reminderEnabled)
      ..writeByte(28)
      ..write(obj.remindersJson);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecurringIncomeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
