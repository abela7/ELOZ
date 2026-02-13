// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'budget.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BudgetAdapter extends TypeAdapter<Budget> {
  @override
  final int typeId = 22;

  @override
  Budget read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Budget(
      id: fields[0] as String?,
      name: fields[1] as String,
      description: fields[2] as String?,
      amount: fields[3] == null ? 0.0 : fields[3] as double,
      period: fields[4] == null ? 'monthly' : fields[4] as String,
      categoryId: fields[5] as String?,
      startDate: fields[6] as DateTime?,
      endDate: fields[7] as DateTime?,
      isActive: fields[8] == null ? true : fields[8] as bool,
      createdAt: fields[9] as DateTime?,
      currentSpent: fields[10] == null ? 0.0 : fields[10] as double,
      alertEnabled: fields[11] == null ? true : fields[11] as bool,
      alertThreshold: fields[12] == null ? 80.0 : fields[12] as double,
      carryOver: fields[13] == null ? false : fields[13] as bool,
      excludedCategoryIds: (fields[14] as List?)?.cast<String>(),
      currency: fields[15] == null ? 'ETB' : fields[15] as String,
      accountId: fields[16] as String?,
      periodSpan: fields[17] == null ? 1 : fields[17] as int,
      endCondition: fields[18] == null ? 'indefinite' : fields[18] as String,
      endTransactionCount: fields[19] as int?,
      endSpentAmount: fields[20] as double?,
      matchedTransactionCount: fields[21] == null ? 0 : fields[21] as int,
      lifetimeSpent: fields[22] == null ? 0.0 : fields[22] as double,
      isPaused: fields[23] == null ? false : fields[23] as bool,
      isStopped: fields[24] == null ? false : fields[24] as bool,
      stoppedAt: fields[25] as DateTime?,
      endedAt: fields[26] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Budget obj) {
    writer
      ..writeByte(27)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.amount)
      ..writeByte(4)
      ..write(obj.period)
      ..writeByte(5)
      ..write(obj.categoryId)
      ..writeByte(6)
      ..write(obj.startDate)
      ..writeByte(7)
      ..write(obj.endDate)
      ..writeByte(8)
      ..write(obj.isActive)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.currentSpent)
      ..writeByte(11)
      ..write(obj.alertEnabled)
      ..writeByte(12)
      ..write(obj.alertThreshold)
      ..writeByte(13)
      ..write(obj.carryOver)
      ..writeByte(14)
      ..write(obj.excludedCategoryIds)
      ..writeByte(15)
      ..write(obj.currency)
      ..writeByte(16)
      ..write(obj.accountId)
      ..writeByte(17)
      ..write(obj.periodSpan)
      ..writeByte(18)
      ..write(obj.endCondition)
      ..writeByte(19)
      ..write(obj.endTransactionCount)
      ..writeByte(20)
      ..write(obj.endSpentAmount)
      ..writeByte(21)
      ..write(obj.matchedTransactionCount)
      ..writeByte(22)
      ..write(obj.lifetimeSpent)
      ..writeByte(23)
      ..write(obj.isPaused)
      ..writeByte(24)
      ..write(obj.isStopped)
      ..writeByte(25)
      ..write(obj.stoppedAt)
      ..writeByte(26)
      ..write(obj.endedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BudgetAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
