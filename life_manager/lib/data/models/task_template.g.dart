// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_template.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TaskTemplateAdapter extends TypeAdapter<TaskTemplate> {
  @override
  final int typeId = 5;

  @override
  TaskTemplate read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TaskTemplate(
      id: fields[0] as String?,
      title: fields[1] as String,
      description: fields[2] as String?,
      categoryId: fields[3] as String?,
      priority: fields[4] as String,
      iconCodePoint: fields[5] as int?,
      iconFontFamily: fields[6] as String?,
      iconFontPackage: fields[7] as String?,
      defaultDurationMinutes: fields[8] as int?,
      defaultRemindersJson: fields[9] as String?,
      defaultSubtasks: (fields[10] as List?)?.cast<String>(),
      tags: (fields[11] as List?)?.cast<String>(),
      notes: fields[12] as String?,
      usageCount: fields[13] as int,
      lastUsedAt: fields[14] as DateTime?,
      createdAt: fields[15] as DateTime?,
      updatedAt: fields[16] as DateTime?,
      taskTypeId: fields[17] as String?,
      defaultTimeHour: fields[18] as int?,
      defaultTimeMinute: fields[19] as int?,
      usageHistory: (fields[20] as List?)?.cast<DateTime>(),
    );
  }

  @override
  void write(BinaryWriter writer, TaskTemplate obj) {
    writer
      ..writeByte(21)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.categoryId)
      ..writeByte(4)
      ..write(obj.priority)
      ..writeByte(5)
      ..write(obj.iconCodePoint)
      ..writeByte(6)
      ..write(obj.iconFontFamily)
      ..writeByte(7)
      ..write(obj.iconFontPackage)
      ..writeByte(8)
      ..write(obj.defaultDurationMinutes)
      ..writeByte(9)
      ..write(obj.defaultRemindersJson)
      ..writeByte(10)
      ..write(obj.defaultSubtasks)
      ..writeByte(11)
      ..write(obj.tags)
      ..writeByte(12)
      ..write(obj.notes)
      ..writeByte(13)
      ..write(obj.usageCount)
      ..writeByte(14)
      ..write(obj.lastUsedAt)
      ..writeByte(15)
      ..write(obj.createdAt)
      ..writeByte(16)
      ..write(obj.updatedAt)
      ..writeByte(17)
      ..write(obj.taskTypeId)
      ..writeByte(18)
      ..write(obj.defaultTimeHour)
      ..writeByte(19)
      ..write(obj.defaultTimeMinute)
      ..writeByte(20)
      ..write(obj.usageHistory);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskTemplateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
