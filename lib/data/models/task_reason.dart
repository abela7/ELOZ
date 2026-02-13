import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'task_reason.g.dart';

/// Reason types for tasks
enum ReasonType {
  notDone,
  postpone,
}

/// TaskReason model with Hive persistence
/// Represents pre-made reasons for Not Done and Postpone actions
@HiveType(typeId: 3)
class TaskReason extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String text;

  @HiveField(2)
  int? iconCodePoint; // Icon code point for reason icon (IconData.codePoint)

  @HiveField(3)
  String? iconFontFamily; // Icon font family (defaults to MaterialIcons)

  @HiveField(4)
  String? iconFontPackage; // Icon font package (if any)

  @HiveField(5)
  int typeIndex; // 0 = notDone, 1 = postpone

  @HiveField(6)
  DateTime createdAt;

  TaskReason({
    String? id,
    required this.text,
    int? iconCodePoint,
    String? iconFontFamily,
    String? iconFontPackage,
    required this.typeIndex,
    DateTime? createdAt,
    IconData? icon,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        iconCodePoint = iconCodePoint ?? icon?.codePoint ?? Icons.note_rounded.codePoint,
        iconFontFamily = iconFontFamily ?? icon?.fontFamily ?? 'MaterialIcons',
        iconFontPackage = iconFontPackage ?? icon?.fontPackage;

  /// Get IconData from stored code point
  IconData? get icon {
    if (iconCodePoint == null) return null;
    return IconData(
      iconCodePoint!,
      fontFamily: iconFontFamily ?? 'MaterialIcons',
      fontPackage: iconFontPackage,
    );
  }

  /// Set IconData by storing code point
  set icon(IconData? value) {
    iconCodePoint = value?.codePoint;
    iconFontFamily = value?.fontFamily;
    iconFontPackage = value?.fontPackage;
  }

  /// Get reason type from index
  ReasonType get type => typeIndex == 0 ? ReasonType.notDone : ReasonType.postpone;

  /// Create a copy with updated fields
  TaskReason copyWith({
    String? id,
    String? text,
    int? iconCodePoint,
    String? iconFontFamily,
    String? iconFontPackage,
    int? typeIndex,
    DateTime? createdAt,
    IconData? icon,
  }) {
    return TaskReason(
      id: id ?? this.id,
      text: text ?? this.text,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      iconFontFamily: iconFontFamily ?? this.iconFontFamily,
      iconFontPackage: iconFontPackage ?? this.iconFontPackage,
      typeIndex: typeIndex ?? this.typeIndex,
      createdAt: createdAt ?? this.createdAt,
      icon: icon,
    );
  }
}

