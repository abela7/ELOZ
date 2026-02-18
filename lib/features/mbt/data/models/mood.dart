import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import 'mood_polarity.dart';

/// User-defined mood configuration.
class Mood extends HiveObject {
  static const Object _unset = Object();

  Mood({
    String? id,
    required this.name,
    required this.iconCodePoint,
    this.iconFontFamily = 'MaterialIcons',
    this.iconFontPackage,
    this.emojiCodePoint,
    required this.colorValue,
    required this.pointValue,
    required this.reasonRequired,
    required this.polarity,
    this.isActive = true,
    DateTime? createdAt,
    this.updatedAt,
    this.deletedAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  final String id;
  final String name;
  final int iconCodePoint;
  final String? iconFontFamily;
  final String? iconFontPackage;
  /// Unicode code point for emoji (e.g. 0x1F600 = 😀). Null = show icon only.
  final int? emojiCodePoint;
  final int colorValue;
  final int pointValue;
  final bool reasonRequired;
  final String polarity;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;
  bool get isGood => polarity == MoodPolarity.good;
  bool get isBad => polarity == MoodPolarity.bad;

  IconData get icon => IconData(
    iconCodePoint,
    fontFamily: iconFontFamily ?? 'MaterialIcons',
    fontPackage: iconFontPackage,
  );

  /// Emoji character for display. Empty string if no emoji set.
  String get emojiCharacter =>
      emojiCodePoint != null ? String.fromCharCode(emojiCodePoint!) : '';

  Mood copyWith({
    String? id,
    String? name,
    int? iconCodePoint,
    Object? iconFontFamily = _unset,
    Object? iconFontPackage = _unset,
    Object? emojiCodePoint = _unset,
    int? colorValue,
    int? pointValue,
    bool? reasonRequired,
    String? polarity,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? deletedAt = _unset,
  }) {
    return Mood(
      id: id ?? this.id,
      name: name ?? this.name,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      iconFontFamily: iconFontFamily == _unset
          ? this.iconFontFamily
          : iconFontFamily as String?,
      iconFontPackage: iconFontPackage == _unset
          ? this.iconFontPackage
          : iconFontPackage as String?,
      emojiCodePoint: emojiCodePoint == _unset
          ? this.emojiCodePoint
          : emojiCodePoint as int?,
      colorValue: colorValue ?? this.colorValue,
      pointValue: pointValue ?? this.pointValue,
      reasonRequired: reasonRequired ?? this.reasonRequired,
      polarity: polarity ?? this.polarity,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt == _unset ? this.deletedAt : deletedAt as DateTime?,
    );
  }
}

class MoodAdapter extends TypeAdapter<Mood> {
  @override
  final int typeId = 60;

  @override
  Mood read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return Mood(
      id: fields[0] as String?,
      name: fields[1] as String? ?? '',
      iconCodePoint: fields[2] as int? ?? Icons.mood_rounded.codePoint,
      iconFontFamily: fields[3] as String?,
      iconFontPackage: fields[4] as String?,
      emojiCodePoint: fields[13] as int?,
      colorValue: fields[5] as int? ?? Colors.blue.toARGB32(),
      pointValue: fields[6] as int? ?? 0,
      reasonRequired: fields[7] as bool? ?? false,
      polarity: fields[8] as String? ?? MoodPolarity.good,
      isActive: fields[9] as bool? ?? true,
      createdAt: fields[10] as DateTime?,
      updatedAt: fields[11] as DateTime?,
      deletedAt: fields[12] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Mood obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.iconCodePoint)
      ..writeByte(3)
      ..write(obj.iconFontFamily)
      ..writeByte(4)
      ..write(obj.iconFontPackage)
      ..writeByte(13)
      ..write(obj.emojiCodePoint)
      ..writeByte(5)
      ..write(obj.colorValue)
      ..writeByte(6)
      ..write(obj.pointValue)
      ..writeByte(7)
      ..write(obj.reasonRequired)
      ..writeByte(8)
      ..write(obj.polarity)
      ..writeByte(9)
      ..write(obj.isActive)
      ..writeByte(10)
      ..write(obj.createdAt)
      ..writeByte(11)
      ..write(obj.updatedAt)
      ..writeByte(12)
      ..write(obj.deletedAt);
  }
}
