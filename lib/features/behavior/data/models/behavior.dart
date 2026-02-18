import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import 'behavior_type.dart';

/// User-defined behavior configuration.
class Behavior extends HiveObject {
  static const Object _unset = Object();

  Behavior({
    String? id,
    required this.name,
    required this.type,
    required this.iconCodePoint,
    this.iconFontFamily = 'MaterialIcons',
    this.iconFontPackage,
    required this.colorValue,
    this.reasonRequired = false,
    this.isActive = true,
    DateTime? createdAt,
    this.updatedAt,
    this.deletedAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  final String id;
  final String name;
  final String type;
  final int iconCodePoint;
  final String? iconFontFamily;
  final String? iconFontPackage;
  final int colorValue;
  final bool reasonRequired;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;
  bool get isGood => type == BehaviorType.good;
  bool get isBad => type == BehaviorType.bad;

  IconData get icon => IconData(
    iconCodePoint,
    fontFamily: iconFontFamily ?? 'MaterialIcons',
    fontPackage: iconFontPackage,
  );

  Behavior copyWith({
    String? id,
    String? name,
    String? type,
    int? iconCodePoint,
    Object? iconFontFamily = _unset,
    Object? iconFontPackage = _unset,
    int? colorValue,
    bool? reasonRequired,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? deletedAt = _unset,
  }) {
    return Behavior(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      iconFontFamily: iconFontFamily == _unset
          ? this.iconFontFamily
          : iconFontFamily as String?,
      iconFontPackage: iconFontPackage == _unset
          ? this.iconFontPackage
          : iconFontPackage as String?,
      colorValue: colorValue ?? this.colorValue,
      reasonRequired: reasonRequired ?? this.reasonRequired,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt == _unset ? this.deletedAt : deletedAt as DateTime?,
    );
  }
}

class BehaviorAdapter extends TypeAdapter<Behavior> {
  @override
  final int typeId = 63;

  @override
  Behavior read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return Behavior(
      id: fields[0] as String?,
      name: fields[1] as String? ?? '',
      type: fields[2] as String? ?? BehaviorType.good,
      iconCodePoint: fields[3] as int? ?? Icons.track_changes_rounded.codePoint,
      iconFontFamily: fields[4] as String?,
      iconFontPackage: fields[5] as String?,
      colorValue: fields[6] as int? ?? Colors.blue.toARGB32(),
      reasonRequired: fields[7] as bool? ?? false,
      isActive: fields[8] as bool? ?? true,
      createdAt: fields[9] as DateTime?,
      updatedAt: fields[10] as DateTime?,
      deletedAt: fields[11] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Behavior obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.iconCodePoint)
      ..writeByte(4)
      ..write(obj.iconFontFamily)
      ..writeByte(5)
      ..write(obj.iconFontPackage)
      ..writeByte(6)
      ..write(obj.colorValue)
      ..writeByte(7)
      ..write(obj.reasonRequired)
      ..writeByte(8)
      ..write(obj.isActive)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.updatedAt)
      ..writeByte(11)
      ..write(obj.deletedAt);
  }
}
