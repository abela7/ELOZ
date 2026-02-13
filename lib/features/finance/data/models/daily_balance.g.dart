// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_balance.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DailyBalanceAdapter extends TypeAdapter<DailyBalance> {
  @override
  final int typeId = 24;

  @override
  DailyBalance read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DailyBalance(
      id: fields[0] as String?,
      date: fields[1] as DateTime? ?? DateTime.now(),
      currency: fields[2] as String? ?? 'USD',
      totalBalance: fields[3] as double,
      createdAt: fields[4] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, DailyBalance obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.currency)
      ..writeByte(3)
      ..write(obj.totalBalance)
      ..writeByte(4)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyBalanceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
