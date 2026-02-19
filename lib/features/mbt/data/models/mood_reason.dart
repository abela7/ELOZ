import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import 'mood_emoji_options.dart';
import 'mood_polarity.dart';

/// Reusable reason that can be linked to moods of matching polarity.
class MoodReason extends HiveObject {
  static const Object _unset = Object();

  static const int _defaultIconCodePoint = 0xe3a5; // Icons.lightbulb_outline
  static const int _defaultColorValue = 0xFFCDAF56;

  MoodReason({
    String? id,
    required this.name,
    required this.type,
    this.isActive = true,
    this.iconCodePoint = _defaultIconCodePoint,
    this.colorValue = _defaultColorValue,
    this.emojiCodePoint,
    DateTime? createdAt,
    this.updatedAt,
    this.deletedAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  final String id;
  final String name;
  final String type;
  final bool isActive;
  final int iconCodePoint;
  final int colorValue;
  /// Unicode code point for emoji (e.g. 0x1F496). Null = show icon only.
  final int? emojiCodePoint;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;
  bool get isGood => type == MoodPolarity.good;
  bool get isBad => type == MoodPolarity.bad;

  IconData get icon => IconData(
    iconCodePoint,
    fontFamily: 'MaterialIcons',
  );

  String get emojiCharacter =>
      emojiCodePoint != null ? emojiFromCodePoint(emojiCodePoint!) : '';

  MoodReason copyWith({
    String? id,
    String? name,
    String? type,
    bool? isActive,
    int? iconCodePoint,
    int? colorValue,
    Object? emojiCodePoint = _unset,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? deletedAt = _unset,
  }) {
    return MoodReason(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      isActive: isActive ?? this.isActive,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
      emojiCodePoint: emojiCodePoint == _unset
          ? this.emojiCodePoint
          : emojiCodePoint as int?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt == _unset ? this.deletedAt : deletedAt as DateTime?,
    );
  }
}

class MoodReasonAdapter extends TypeAdapter<MoodReason> {
  @override
  final int typeId = 61;

  @override
  MoodReason read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return MoodReason(
      id: fields[0] as String?,
      name: fields[1] as String? ?? '',
      type: fields[2] as String? ?? MoodPolarity.good,
      isActive: fields[3] as bool? ?? true,
      iconCodePoint: fields[7] as int? ?? MoodReason._defaultIconCodePoint,
      colorValue: fields[8] as int? ?? MoodReason._defaultColorValue,
      emojiCodePoint: fields[9] as int?,
      createdAt: fields[4] as DateTime?,
      updatedAt: fields[5] as DateTime?,
      deletedAt: fields[6] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, MoodReason obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.isActive)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.updatedAt)
      ..writeByte(6)
      ..write(obj.deletedAt)
      ..writeByte(7)
      ..write(obj.iconCodePoint)
      ..writeByte(8)
      ..write(obj.colorValue)
      ..writeByte(9)
      ..write(obj.emojiCodePoint);
  }
}
