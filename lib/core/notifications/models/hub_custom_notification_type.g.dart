// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hub_custom_notification_type.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HubCustomNotificationTypeAdapter
    extends TypeAdapter<HubCustomNotificationType> {
  @override
  final int typeId = 40;

  @override
  HubCustomNotificationType read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HubCustomNotificationType(
      id: fields[0] as String,
      displayName: fields[1] as String,
      moduleId: fields[2] as String,
      sectionId: fields[3] as String?,
      iconCodePoint: fields[4] as int,
      iconFontFamily: fields[5] as String,
      iconFontPackage: fields[6] as String?,
      colorValue: fields[7] as int,
      deliveryConfigJson: (fields[8] as Map).cast<String, dynamic>(),
      createdAt: fields[9] as DateTime,
      updatedAt: fields[10] as DateTime,
      isUserCreated: fields[11] as bool,
      overridesAdapterTypeId: fields[12] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, HubCustomNotificationType obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.displayName)
      ..writeByte(2)
      ..write(obj.moduleId)
      ..writeByte(3)
      ..write(obj.sectionId)
      ..writeByte(4)
      ..write(obj.iconCodePoint)
      ..writeByte(5)
      ..write(obj.iconFontFamily)
      ..writeByte(6)
      ..write(obj.iconFontPackage)
      ..writeByte(7)
      ..write(obj.colorValue)
      ..writeByte(8)
      ..write(obj.deliveryConfigJson)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.updatedAt)
      ..writeByte(11)
      ..write(obj.isUserCreated)
      ..writeByte(12)
      ..write(obj.overridesAdapterTypeId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HubCustomNotificationTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
