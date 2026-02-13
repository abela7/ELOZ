// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'completion_type_config.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CompletionTypeConfigAdapter extends TypeAdapter<CompletionTypeConfig> {
  @override
  final int typeId = 14;

  @override
  CompletionTypeConfig read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CompletionTypeConfig(
      id: fields[0] as String?,
      typeId: fields[1] as String,
      name: fields[2] as String,
      isEnabled: fields[3] as bool,
      defaultYesPoints: fields[4] as int?,
      defaultNoPoints: fields[5] as int?,
      defaultPostponePoints: fields[6] as int?,
      defaultCalculationMethod: fields[7] as String?,
      defaultThresholdPercent: fields[8] as double?,
      defaultPointsPerMinute: fields[9] as int?,
      defaultTimerType: fields[14] as String?,
      defaultBonusPerMinute: fields[15] as double?,
      defaultTargetMinutes: fields[16] as int?,
      allowOvertimeBonus: fields[17] as bool?,
      defaultDailyReward: fields[10] as int?,
      defaultSlipPenalty: fields[11] as int?,
      defaultSlipCalculation: fields[18] as String?,
      defaultPenaltyPerUnit: fields[19] as int?,
      defaultStreakProtection: fields[20] as int?,
      defaultCostPerUnit: fields[21] as double?,
      enableTemptationTracking: fields[22] as bool?,
      defaultHideQuitHabit: fields[23] as bool?,
      createdAt: fields[12] as DateTime?,
      updatedAt: fields[13] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, CompletionTypeConfig obj) {
    writer
      ..writeByte(24)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.typeId)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.isEnabled)
      ..writeByte(4)
      ..write(obj.defaultYesPoints)
      ..writeByte(5)
      ..write(obj.defaultNoPoints)
      ..writeByte(6)
      ..write(obj.defaultPostponePoints)
      ..writeByte(7)
      ..write(obj.defaultCalculationMethod)
      ..writeByte(8)
      ..write(obj.defaultThresholdPercent)
      ..writeByte(9)
      ..write(obj.defaultPointsPerMinute)
      ..writeByte(14)
      ..write(obj.defaultTimerType)
      ..writeByte(15)
      ..write(obj.defaultBonusPerMinute)
      ..writeByte(16)
      ..write(obj.defaultTargetMinutes)
      ..writeByte(17)
      ..write(obj.allowOvertimeBonus)
      ..writeByte(10)
      ..write(obj.defaultDailyReward)
      ..writeByte(11)
      ..write(obj.defaultSlipPenalty)
      ..writeByte(18)
      ..write(obj.defaultSlipCalculation)
      ..writeByte(19)
      ..write(obj.defaultPenaltyPerUnit)
      ..writeByte(20)
      ..write(obj.defaultStreakProtection)
      ..writeByte(21)
      ..write(obj.defaultCostPerUnit)
      ..writeByte(22)
      ..write(obj.enableTemptationTracking)
      ..writeByte(23)
      ..write(obj.defaultHideQuitHabit)
      ..writeByte(12)
      ..write(obj.createdAt)
      ..writeByte(13)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompletionTypeConfigAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
