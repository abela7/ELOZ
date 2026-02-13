// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TaskAdapter extends TypeAdapter<Task> {
  @override
  final int typeId = 0;

  @override
  Task read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Task(
      id: fields[0] as String?,
      title: fields[1] as String,
      description: fields[2] as String?,
      dueDate: fields[3] as DateTime,
      priority: fields[5] as String,
      categoryId: fields[6] as String?,
      taskTypeId: fields[7] as String?,
      subtasks: (fields[30] as List?)?.cast<Subtask>(),
      subtaskCompletion: (fields[9] as Map?)?.cast<String, bool>(),
      recurrenceRule: fields[10] as String?,
      status: fields[11] as String,
      pointsEarned: fields[12] as int,
      remindersJson: fields[13] as String?,
      notes: fields[14] as String?,
      createdAt: fields[15] as DateTime?,
      completedAt: fields[16] as DateTime?,
      postponedTo: fields[17] as DateTime?,
      postponeReason: fields[18] as String?,
      notDoneReason: fields[19] as String?,
      reflection: fields[21] as String?,
      originalDueDate: fields[22] as DateTime?,
      parentTaskId: fields[23] as String?,
      rootTaskId: fields[24] as String?,
      postponedAt: fields[25] as DateTime?,
      iconCodePoint: fields[26] as int?,
      iconFontFamily: fields[27] as String?,
      iconFontPackage: fields[28] as String?,
      tags: (fields[29] as List?)?.cast<String>(),
      postponeCount: fields[31] as int,
      postponeHistory: fields[32] as String?,
      recurrenceGroupId: fields[33] as String?,
      recurrenceIndex: fields[34] as int,
      isRoutine: fields[35] as bool,
      routineGroupId: fields[36] as String?,
      routineStatus: fields[37] as String,
      isRoutineActive: fields[38] as bool,
      routineProgressStartDate: fields[39] as DateTime?,
      taskKind: fields[40] as String?,
      cumulativePostponePenalty: fields[41] as int,
      isSpecial: fields[42] as bool,
      snoozedUntil: fields[43] as DateTime?,
      snoozeHistory: fields[44] as String?,
      counterEnabled: fields[45] as bool?,
    )
      ..dueTimeHour = fields[4] as int?
      ..dueTimeMinute = fields[20] as int?;
  }

  @override
  void write(BinaryWriter writer, Task obj) {
    writer
      ..writeByte(45)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.dueDate)
      ..writeByte(4)
      ..write(obj.dueTimeHour)
      ..writeByte(20)
      ..write(obj.dueTimeMinute)
      ..writeByte(5)
      ..write(obj.priority)
      ..writeByte(6)
      ..write(obj.categoryId)
      ..writeByte(7)
      ..write(obj.taskTypeId)
      ..writeByte(30)
      ..write(obj.subtasks)
      ..writeByte(9)
      ..write(obj.subtaskCompletion)
      ..writeByte(10)
      ..write(obj.recurrenceRule)
      ..writeByte(11)
      ..write(obj.status)
      ..writeByte(12)
      ..write(obj.pointsEarned)
      ..writeByte(13)
      ..write(obj.remindersJson)
      ..writeByte(14)
      ..write(obj.notes)
      ..writeByte(15)
      ..write(obj.createdAt)
      ..writeByte(16)
      ..write(obj.completedAt)
      ..writeByte(17)
      ..write(obj.postponedTo)
      ..writeByte(18)
      ..write(obj.postponeReason)
      ..writeByte(19)
      ..write(obj.notDoneReason)
      ..writeByte(21)
      ..write(obj.reflection)
      ..writeByte(22)
      ..write(obj.originalDueDate)
      ..writeByte(23)
      ..write(obj.parentTaskId)
      ..writeByte(24)
      ..write(obj.rootTaskId)
      ..writeByte(25)
      ..write(obj.postponedAt)
      ..writeByte(26)
      ..write(obj.iconCodePoint)
      ..writeByte(27)
      ..write(obj.iconFontFamily)
      ..writeByte(28)
      ..write(obj.iconFontPackage)
      ..writeByte(29)
      ..write(obj.tags)
      ..writeByte(31)
      ..write(obj.postponeCount)
      ..writeByte(32)
      ..write(obj.postponeHistory)
      ..writeByte(33)
      ..write(obj.recurrenceGroupId)
      ..writeByte(34)
      ..write(obj.recurrenceIndex)
      ..writeByte(35)
      ..write(obj.isRoutine)
      ..writeByte(36)
      ..write(obj.routineGroupId)
      ..writeByte(37)
      ..write(obj.routineStatus)
      ..writeByte(38)
      ..write(obj.isRoutineActive)
      ..writeByte(39)
      ..write(obj.routineProgressStartDate)
      ..writeByte(40)
      ..write(obj.taskKind)
      ..writeByte(41)
      ..write(obj.cumulativePostponePenalty)
      ..writeByte(42)
      ..write(obj.isSpecial)
      ..writeByte(43)
      ..write(obj.snoozedUntil)
      ..writeByte(44)
      ..write(obj.snoozeHistory)
      ..writeByte(45)
      ..write(obj.counterEnabled);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
