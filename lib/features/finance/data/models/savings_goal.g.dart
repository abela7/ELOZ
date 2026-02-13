// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'savings_goal.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SavingsGoalAdapter extends TypeAdapter<SavingsGoal> {
  @override
  final int typeId = 30;

  @override
  SavingsGoal read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SavingsGoal(
      id: fields[0] as String?,
      name: fields[1] as String,
      description: fields[2] as String?,
      targetAmount: fields[3] == null ? 0.0 : fields[3] as double,
      savedAmount: fields[4] == null ? 0.0 : fields[4] as double,
      currency: fields[5] == null ? 'ETB' : fields[5] as String,
      startDate: fields[6] as DateTime?,
      targetDate: fields[7] as DateTime,
      status: fields[8] == null ? 'active' : fields[8] as String,
      createdAt: fields[9] as DateTime?,
      updatedAt: fields[10] as DateTime?,
      closedAt: fields[11] as DateTime?,
      accountId: fields[12] as String?,
      iconCodePoint: fields[13] as int?,
      iconFontFamily: fields[14] as String?,
      iconFontPackage: fields[15] as String?,
      colorValue: fields[16] == null ? 4291669846 : fields[16] as int?,
      contributionLogJson: (fields[17] as List?)?.cast<String>(),
      failureReason: fields[18] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, SavingsGoal obj) {
    writer
      ..writeByte(19)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.targetAmount)
      ..writeByte(4)
      ..write(obj.savedAmount)
      ..writeByte(5)
      ..write(obj.currency)
      ..writeByte(6)
      ..write(obj.startDate)
      ..writeByte(7)
      ..write(obj.targetDate)
      ..writeByte(8)
      ..write(obj.status)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.updatedAt)
      ..writeByte(11)
      ..write(obj.closedAt)
      ..writeByte(12)
      ..write(obj.accountId)
      ..writeByte(13)
      ..write(obj.iconCodePoint)
      ..writeByte(14)
      ..write(obj.iconFontFamily)
      ..writeByte(15)
      ..write(obj.iconFontPackage)
      ..writeByte(16)
      ..write(obj.colorValue)
      ..writeByte(17)
      ..write(obj.contributionLogJson)
      ..writeByte(18)
      ..write(obj.failureReason);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavingsGoalAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
