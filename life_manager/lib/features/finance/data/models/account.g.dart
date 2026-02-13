// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AccountAdapter extends TypeAdapter<Account> {
  @override
  final int typeId = 23;

  @override
  Account read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Account(
      id: fields[0] as String?,
      name: fields[1] as String,
      description: fields[2] as String?,
      type: fields[3] as String,
      balance: fields[4] == null ? 0.0 : fields[4] as double,
      currency: fields[5] == null ? 'ETB' : fields[5] as String,
      iconCodePoint: fields[6] as int?,
      iconFontFamily: fields[7] as String?,
      iconFontPackage: fields[8] as String?,
      colorValue: fields[9] == null ? 4283215696 : fields[9] as int?,
      createdAt: fields[10] as DateTime?,
      isActive: fields[11] == null ? true : fields[11] as bool,
      includeInTotal: fields[12] == null ? true : fields[12] as bool,
      sortOrder: fields[13] == null ? 0 : fields[13] as int,
      bankName: fields[14] as String?,
      accountNumber: fields[15] as String?,
      creditLimit: fields[16] as double?,
      notes: fields[17] as String?,
      lastSyncDate: fields[18] as DateTime?,
      isDefault: fields[19] == null ? false : fields[19] as bool,
      initialBalance: fields[20] == null ? 0.0 : fields[20] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, Account obj) {
    writer
      ..writeByte(21)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.balance)
      ..writeByte(5)
      ..write(obj.currency)
      ..writeByte(6)
      ..write(obj.iconCodePoint)
      ..writeByte(7)
      ..write(obj.iconFontFamily)
      ..writeByte(8)
      ..write(obj.iconFontPackage)
      ..writeByte(9)
      ..write(obj.colorValue)
      ..writeByte(10)
      ..write(obj.createdAt)
      ..writeByte(11)
      ..write(obj.isActive)
      ..writeByte(12)
      ..write(obj.includeInTotal)
      ..writeByte(13)
      ..write(obj.sortOrder)
      ..writeByte(14)
      ..write(obj.bankName)
      ..writeByte(15)
      ..write(obj.accountNumber)
      ..writeByte(16)
      ..write(obj.creditLimit)
      ..writeByte(17)
      ..write(obj.notes)
      ..writeByte(18)
      ..write(obj.lastSyncDate)
      ..writeByte(19)
      ..write(obj.isDefault)
      ..writeByte(20)
      ..write(obj.initialBalance);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccountAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
