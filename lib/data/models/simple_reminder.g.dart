// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'simple_reminder.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SimpleReminderAdapter extends TypeAdapter<SimpleReminder> {
  @override
  final int typeId = 6;

  @override
  SimpleReminder read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SimpleReminder(
      id: fields[0] as String?,
      title: fields[1] as String,
      scheduledAt: fields[2] as DateTime,
      createdAt: fields[3] as DateTime?,
      status: fields[4] as String,
      timerMode: fields[5] as String,
      counterStartedAt: fields[6] as DateTime?,
      description: fields[7] as String?,
      iconCodePoint: fields[8] as int?,
      iconFontFamily: fields[9] as String?,
      iconFontPackage: fields[10] as String?,
      colorValue: fields[11] as int?,
      notificationId: fields[12] as int?,
      completedAt: fields[13] as DateTime?,
      isPinned: fields[14] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, SimpleReminder obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.scheduledAt)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.status)
      ..writeByte(5)
      ..write(obj.timerMode)
      ..writeByte(6)
      ..write(obj.counterStartedAt)
      ..writeByte(7)
      ..write(obj.description)
      ..writeByte(8)
      ..write(obj.iconCodePoint)
      ..writeByte(9)
      ..write(obj.iconFontFamily)
      ..writeByte(10)
      ..write(obj.iconFontPackage)
      ..writeByte(11)
      ..write(obj.colorValue)
      ..writeByte(12)
      ..write(obj.notificationId)
      ..writeByte(13)
      ..write(obj.completedAt)
      ..writeByte(14)
      ..write(obj.isPinned);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SimpleReminderAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
