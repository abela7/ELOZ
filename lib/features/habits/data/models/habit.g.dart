// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'habit.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HabitAdapter extends TypeAdapter<Habit> {
  @override
  final int typeId = 10;

  @override
  Habit read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Habit(
      id: fields[0] as String?,
      title: fields[1] as String,
      description: fields[2] as String?,
      iconCodePoint: fields[3] as int?,
      iconFontFamily: fields[4] as String?,
      iconFontPackage: fields[5] as String?,
      colorValue: fields[6] as int?,
      categoryId: fields[7] as String?,
      frequencyType: fields[8] as String,
      weekDays: (fields[9] as List?)?.cast<int>(),
      targetCount: fields[10] as int,
      customIntervalDays: fields[11] as int?,
      currentStreak: fields[12] as int,
      bestStreak: fields[13] as int,
      totalCompletions: fields[14] as int,
      reminderMinutes: fields[15] as int?,
      reminderEnabled: fields[16] as bool,
      notes: fields[17] as String?,
      isGoodHabit: fields[18] as bool,
      isArchived: fields[19] as bool,
      isSpecial: fields[76] as bool,
      createdAt: fields[20] as DateTime?,
      archivedAt: fields[21] as DateTime?,
      lastCompletedAt: fields[22] as DateTime?,
      startDate: fields[23] as DateTime?,
      endDate: fields[24] as DateTime?,
      sortOrder: fields[25] as int,
      tags: (fields[26] as List?)?.cast<String>(),
      notDoneReason: fields[27] as String?,
      postponeReason: fields[28] as String?,
      habitTypeId: fields[29] as String?,
      pointsEarned: fields[30] as int,
      completionType: fields[31] as String,
      customYesPoints: fields[32] as int?,
      customNoPoints: fields[33] as int?,
      customPostponePoints: fields[34] as int?,
      targetValue: fields[35] as double?,
      unit: fields[36] as String?,
      customUnitName: fields[37] as String?,
      targetDurationMinutes: fields[38] as int?,
      pointCalculation: fields[39] as String?,
      thresholdPercent: fields[40] as double?,
      pointsPerUnit: fields[41] as int?,
      timerType: fields[42] as String?,
      bonusPerMinute: fields[43] as double?,
      allowOvertimeBonus: fields[44] as bool?,
      timeUnit: fields[45] as String?,
      dailyReward: fields[46] as int?,
      slipPenalty: fields[47] as int?,
      slipCalculation: fields[48] as String?,
      penaltyPerUnit: fields[49] as int?,
      streakProtection: fields[50] as int?,
      currentSlipCount: fields[51] as int?,
      costPerUnit: fields[52] as double?,
      costTrackingEnabled: fields[80] as bool?,
      currencySymbol: fields[81] as String?,
      enableTemptationTracking: fields[53] as bool?,
      moneySaved: fields[54] as double?,
      unitsAvoided: fields[55] as int?,
      quitHabitActive: fields[56] as bool?,
      quitCompletedDate: fields[57] as DateTime?,
      frequencyPeriod: fields[58] as String?,
      endCondition: fields[59] as String?,
      endOccurrences: fields[60] as int?,
      checklist: (fields[61] as List?)?.cast<Subtask>(),
      quitActionName: fields[62] as String?,
      quitSubstance: fields[63] as String?,
      hideQuitHabit: fields[79] as bool?,
      recurrenceRuleJson: fields[64] as String?,
      reminderDuration: fields[65] as String?,
      motivation: fields[66] as String?,
      hasSpecificTime: fields[67] as bool,
      habitTimeMinutes: fields[68] as int?,
      goalType: fields[69] as String?,
      goalTarget: fields[70] as int?,
      goalStartDate: fields[71] as DateTime?,
      goalCompletedDate: fields[72] as DateTime?,
      habitStatus: fields[73] as String,
      statusChangedDate: fields[74] as DateTime?,
      pausedUntil: fields[75] as DateTime?,
      snoozedUntil: fields[77] as DateTime?,
      snoozeHistory: fields[78] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Habit obj) {
    writer
      ..writeByte(82)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.iconCodePoint)
      ..writeByte(4)
      ..write(obj.iconFontFamily)
      ..writeByte(5)
      ..write(obj.iconFontPackage)
      ..writeByte(6)
      ..write(obj.colorValue)
      ..writeByte(7)
      ..write(obj.categoryId)
      ..writeByte(8)
      ..write(obj.frequencyType)
      ..writeByte(9)
      ..write(obj.weekDays)
      ..writeByte(10)
      ..write(obj.targetCount)
      ..writeByte(11)
      ..write(obj.customIntervalDays)
      ..writeByte(12)
      ..write(obj.currentStreak)
      ..writeByte(13)
      ..write(obj.bestStreak)
      ..writeByte(14)
      ..write(obj.totalCompletions)
      ..writeByte(15)
      ..write(obj.reminderMinutes)
      ..writeByte(16)
      ..write(obj.reminderEnabled)
      ..writeByte(17)
      ..write(obj.notes)
      ..writeByte(18)
      ..write(obj.isGoodHabit)
      ..writeByte(19)
      ..write(obj.isArchived)
      ..writeByte(76)
      ..write(obj.isSpecial)
      ..writeByte(20)
      ..write(obj.createdAt)
      ..writeByte(21)
      ..write(obj.archivedAt)
      ..writeByte(22)
      ..write(obj.lastCompletedAt)
      ..writeByte(23)
      ..write(obj.startDate)
      ..writeByte(24)
      ..write(obj.endDate)
      ..writeByte(25)
      ..write(obj.sortOrder)
      ..writeByte(26)
      ..write(obj.tags)
      ..writeByte(27)
      ..write(obj.notDoneReason)
      ..writeByte(28)
      ..write(obj.postponeReason)
      ..writeByte(29)
      ..write(obj.habitTypeId)
      ..writeByte(30)
      ..write(obj.pointsEarned)
      ..writeByte(31)
      ..write(obj.completionType)
      ..writeByte(32)
      ..write(obj.customYesPoints)
      ..writeByte(33)
      ..write(obj.customNoPoints)
      ..writeByte(34)
      ..write(obj.customPostponePoints)
      ..writeByte(35)
      ..write(obj.targetValue)
      ..writeByte(36)
      ..write(obj.unit)
      ..writeByte(37)
      ..write(obj.customUnitName)
      ..writeByte(38)
      ..write(obj.targetDurationMinutes)
      ..writeByte(39)
      ..write(obj.pointCalculation)
      ..writeByte(40)
      ..write(obj.thresholdPercent)
      ..writeByte(41)
      ..write(obj.pointsPerUnit)
      ..writeByte(42)
      ..write(obj.timerType)
      ..writeByte(43)
      ..write(obj.bonusPerMinute)
      ..writeByte(44)
      ..write(obj.allowOvertimeBonus)
      ..writeByte(45)
      ..write(obj.timeUnit)
      ..writeByte(46)
      ..write(obj.dailyReward)
      ..writeByte(47)
      ..write(obj.slipPenalty)
      ..writeByte(48)
      ..write(obj.slipCalculation)
      ..writeByte(49)
      ..write(obj.penaltyPerUnit)
      ..writeByte(50)
      ..write(obj.streakProtection)
      ..writeByte(51)
      ..write(obj.currentSlipCount)
      ..writeByte(52)
      ..write(obj.costPerUnit)
      ..writeByte(80)
      ..write(obj.costTrackingEnabled)
      ..writeByte(81)
      ..write(obj.currencySymbol)
      ..writeByte(53)
      ..write(obj.enableTemptationTracking)
      ..writeByte(54)
      ..write(obj.moneySaved)
      ..writeByte(55)
      ..write(obj.unitsAvoided)
      ..writeByte(56)
      ..write(obj.quitHabitActive)
      ..writeByte(57)
      ..write(obj.quitCompletedDate)
      ..writeByte(58)
      ..write(obj.frequencyPeriod)
      ..writeByte(59)
      ..write(obj.endCondition)
      ..writeByte(60)
      ..write(obj.endOccurrences)
      ..writeByte(61)
      ..write(obj.checklist)
      ..writeByte(62)
      ..write(obj.quitActionName)
      ..writeByte(63)
      ..write(obj.quitSubstance)
      ..writeByte(79)
      ..write(obj.hideQuitHabit)
      ..writeByte(64)
      ..write(obj.recurrenceRuleJson)
      ..writeByte(65)
      ..write(obj.reminderDuration)
      ..writeByte(66)
      ..write(obj.motivation)
      ..writeByte(67)
      ..write(obj.hasSpecificTime)
      ..writeByte(68)
      ..write(obj.habitTimeMinutes)
      ..writeByte(69)
      ..write(obj.goalType)
      ..writeByte(70)
      ..write(obj.goalTarget)
      ..writeByte(71)
      ..write(obj.goalStartDate)
      ..writeByte(72)
      ..write(obj.goalCompletedDate)
      ..writeByte(73)
      ..write(obj.habitStatus)
      ..writeByte(74)
      ..write(obj.statusChangedDate)
      ..writeByte(75)
      ..write(obj.pausedUntil)
      ..writeByte(77)
      ..write(obj.snoozedUntil)
      ..writeByte(78)
      ..write(obj.snoozeHistory);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HabitAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
