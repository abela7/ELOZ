// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'universal_notification.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UniversalNotificationAdapter extends TypeAdapter<UniversalNotification> {
  @override
  final int typeId = 41;

  @override
  UniversalNotification read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UniversalNotification(
      id: fields[0] as String?,
      moduleId: fields[1] as String,
      section: fields[2] as String,
      entityId: fields[3] as String,
      entityName: fields[4] as String,
      titleTemplate: fields[5] as String,
      bodyTemplate: fields[6] as String,
      iconCodePoint: fields[7] as int?,
      iconFontFamily: fields[8] as String?,
      iconFontPackage: fields[9] as String?,
      colorValue: fields[10] as int?,
      actionsJson: fields[11] as String? ?? '[]',
      typeId: fields[12] as String,
      timing: fields[13] as String? ?? 'before',
      timingValue: fields[14] as int? ?? 1,
      timingUnit: fields[15] as String? ?? 'days',
      hour: fields[16] as int? ?? 9,
      minute: fields[17] as int? ?? 0,
      condition: fields[18] as String? ?? 'always',
      enabled: fields[19] as bool? ?? true,
      actionsEnabled: (fields[22] as bool?) ?? true,
      createdAt: fields[20] as DateTime?,
      updatedAt: fields[21] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, UniversalNotification obj) {
    writer
      ..writeByte(23)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.moduleId)
      ..writeByte(2)
      ..write(obj.section)
      ..writeByte(3)
      ..write(obj.entityId)
      ..writeByte(4)
      ..write(obj.entityName)
      ..writeByte(5)
      ..write(obj.titleTemplate)
      ..writeByte(6)
      ..write(obj.bodyTemplate)
      ..writeByte(7)
      ..write(obj.iconCodePoint)
      ..writeByte(8)
      ..write(obj.iconFontFamily)
      ..writeByte(9)
      ..write(obj.iconFontPackage)
      ..writeByte(10)
      ..write(obj.colorValue)
      ..writeByte(11)
      ..write(obj.actionsJson)
      ..writeByte(12)
      ..write(obj.typeId)
      ..writeByte(13)
      ..write(obj.timing)
      ..writeByte(14)
      ..write(obj.timingValue)
      ..writeByte(15)
      ..write(obj.timingUnit)
      ..writeByte(16)
      ..write(obj.hour)
      ..writeByte(17)
      ..write(obj.minute)
      ..writeByte(18)
      ..write(obj.condition)
      ..writeByte(19)
      ..write(obj.enabled)
      ..writeByte(22)
      ..write(obj.actionsEnabled)
      ..writeByte(20)
      ..write(obj.createdAt)
      ..writeByte(21)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UniversalNotificationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
