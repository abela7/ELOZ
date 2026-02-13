// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sleep_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SleepRecordAdapter extends TypeAdapter<SleepRecord> {
  @override
  final int typeId = 50;

  @override
  SleepRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SleepRecord(
      id: fields[0] as String?,
      bedTime: fields[1] as DateTime,
      wakeTime: fields[2] as DateTime,
      createdAt: fields[3] as DateTime?,
      updatedAt: fields[4] as DateTime?,
      quality: fields[5] as String,
      sleepScore: fields[6] as int?,
      notes: fields[7] as String?,
      tags: (fields[8] as List?)?.cast<String>(),
      fellAsleepMinutes: fields[9] as int?,
      timesAwake: fields[10] as int?,
      minutesAwake: fields[11] as int?,
      mood: fields[12] as String?,
      hadDreams: fields[13] as bool?,
      hadNightmares: fields[14] as bool?,
      dreamNotes: fields[15] as String?,
      factorsBeforeSleep: (fields[16] as List?)?.cast<String>(),
      sleepEnvironment: fields[17] as String?,
      roomTemperature: fields[18] as double?,
      isNap: fields[19] as bool? ?? false,
      sleepLocationId: fields[20] as String?,
      heartRateAvg: fields[21] as int?,
      heartRateMin: fields[22] as int?,
      heartRateMax: fields[23] as int?,
      deepSleepHours: fields[24] as double?,
      lightSleepHours: fields[25] as double?,
      remSleepHours: fields[26] as double?,
      snoringMinutes: fields[27] as int?,
      syncedFromDevice: fields[28] as bool? ?? false,
      deviceName: fields[29] as String?,
      rawDeviceData: (fields[30] as Map?)?.cast<String, dynamic>(),
      schemaVersion: fields[31] as int,
      scoredGoalId: fields[32] as String?,
      scoredGoalName: fields[33] as String?,
      scoredGoalTargetHours: fields[34] as double?,
      scoredDurationDifferenceMinutes: fields[35] as int?,
      scoredDurationScore: fields[36] as int?,
      scoredConsistencyScore: fields[37] as int?,
      scoredGrade: fields[38] as String?,
      scoredGoalMet: fields[39] as bool?,
      usedManualGoalOverride: fields[40] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, SleepRecord obj) {
    writer
      ..writeByte(41)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.bedTime)
      ..writeByte(2)
      ..write(obj.wakeTime)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.updatedAt)
      ..writeByte(5)
      ..write(obj.quality)
      ..writeByte(6)
      ..write(obj.sleepScore)
      ..writeByte(7)
      ..write(obj.notes)
      ..writeByte(8)
      ..write(obj.tags)
      ..writeByte(9)
      ..write(obj.fellAsleepMinutes)
      ..writeByte(10)
      ..write(obj.timesAwake)
      ..writeByte(11)
      ..write(obj.minutesAwake)
      ..writeByte(12)
      ..write(obj.mood)
      ..writeByte(13)
      ..write(obj.hadDreams)
      ..writeByte(14)
      ..write(obj.hadNightmares)
      ..writeByte(15)
      ..write(obj.dreamNotes)
      ..writeByte(16)
      ..write(obj.factorsBeforeSleep)
      ..writeByte(17)
      ..write(obj.sleepEnvironment)
      ..writeByte(18)
      ..write(obj.roomTemperature)
      ..writeByte(19)
      ..write(obj.isNap)
      ..writeByte(20)
      ..write(obj.sleepLocationId)
      ..writeByte(21)
      ..write(obj.heartRateAvg)
      ..writeByte(22)
      ..write(obj.heartRateMin)
      ..writeByte(23)
      ..write(obj.heartRateMax)
      ..writeByte(24)
      ..write(obj.deepSleepHours)
      ..writeByte(25)
      ..write(obj.lightSleepHours)
      ..writeByte(26)
      ..write(obj.remSleepHours)
      ..writeByte(27)
      ..write(obj.snoringMinutes)
      ..writeByte(28)
      ..write(obj.syncedFromDevice)
      ..writeByte(29)
      ..write(obj.deviceName)
      ..writeByte(30)
      ..write(obj.rawDeviceData)
      ..writeByte(31)
      ..write(obj.schemaVersion)
      ..writeByte(32)
      ..write(obj.scoredGoalId)
      ..writeByte(33)
      ..write(obj.scoredGoalName)
      ..writeByte(34)
      ..write(obj.scoredGoalTargetHours)
      ..writeByte(35)
      ..write(obj.scoredDurationDifferenceMinutes)
      ..writeByte(36)
      ..write(obj.scoredDurationScore)
      ..writeByte(37)
      ..write(obj.scoredConsistencyScore)
      ..writeByte(38)
      ..write(obj.scoredGrade)
      ..writeByte(39)
      ..write(obj.scoredGoalMet)
      ..writeByte(40)
      ..write(obj.usedManualGoalOverride);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SleepRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
