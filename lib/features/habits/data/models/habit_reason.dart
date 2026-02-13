import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'habit_reason.g.dart';

/// Reason types for habits
enum HabitReasonType {
  notDone,    // 0: Reason for not completing a good habit
  postpone,   // 1: Reason for postponing a habit
  slip,       // 2: Reason for slipping on a quit habit (did the bad thing)
  temptation, // 3: Reason for feeling tempted (but resisted)
}

/// HabitReason model with Hive persistence
/// Represents pre-made reasons for Not Done and Postpone actions
@HiveType(typeId: 12)
class HabitReason extends HiveObject {
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

  @HiveField(7)
  int? colorValue; // Color value for the reason

  @HiveField(8)
  bool isActive; // Whether the reason is active (shown in dialogs)

  @HiveField(9)
  bool isDefault; // Whether this is a built-in default reason

  HabitReason({
    String? id,
    required this.text,
    int? iconCodePoint,
    String? iconFontFamily,
    String? iconFontPackage,
    required this.typeIndex,
    DateTime? createdAt,
    IconData? icon,
    int? colorValue,
    this.isActive = true,
    this.isDefault = false,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        iconCodePoint = iconCodePoint ?? icon?.codePoint ?? Icons.note_rounded.codePoint,
        iconFontFamily = iconFontFamily ?? icon?.fontFamily ?? 'MaterialIcons',
        iconFontPackage = iconFontPackage ?? icon?.fontPackage,
        colorValue = colorValue ?? const Color(0xFFFFB347).value;

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

  /// Get Color from stored value
  Color get color => colorValue != null ? Color(colorValue!) : const Color(0xFFFFB347);

  /// Set Color by storing value
  set color(Color value) {
    colorValue = value.value;
  }

  /// Get reason type from index
  HabitReasonType get type {
    switch (typeIndex) {
      case 0:
        return HabitReasonType.notDone;
      case 1:
        return HabitReasonType.postpone;
      case 2:
        return HabitReasonType.slip;
      case 3:
        return HabitReasonType.temptation;
      default:
        return HabitReasonType.notDone;
    }
  }

  /// Check if this is a quit habit reason (slip or temptation)
  bool get isQuitReason => type == HabitReasonType.slip || type == HabitReasonType.temptation;

  /// Get type display name
  String get typeName {
    switch (type) {
      case HabitReasonType.notDone:
        return 'Not Done';
      case HabitReasonType.postpone:
        return 'Postpone';
      case HabitReasonType.slip:
        return 'Slip';
      case HabitReasonType.temptation:
        return 'Temptation';
    }
  }

  /// Create default "Not Done" reasons (skip reasons for good habits)
  static List<HabitReason> getDefaultNotDoneReasons() {
    return [
      HabitReason(text: 'Too tired', typeIndex: 0, icon: Icons.bedtime_rounded, colorValue: const Color(0xFFFF6B6B).value, isDefault: true),
      HabitReason(text: 'No time', typeIndex: 0, icon: Icons.schedule_rounded, colorValue: const Color(0xFFFFA726).value, isDefault: true),
      HabitReason(text: 'Feeling sick', typeIndex: 0, icon: Icons.sick_rounded, colorValue: const Color(0xFFEF5350).value, isDefault: true),
      HabitReason(text: 'Traveling', typeIndex: 0, icon: Icons.flight_rounded, colorValue: const Color(0xFF42A5F5).value, isDefault: true),
      HabitReason(text: 'Bad weather', typeIndex: 0, icon: Icons.thunderstorm_rounded, colorValue: const Color(0xFF78909C).value, isDefault: true),
      HabitReason(text: 'Unexpected event', typeIndex: 0, icon: Icons.event_busy_rounded, colorValue: const Color(0xFFAB47BC).value, isDefault: true),
      HabitReason(text: 'Lost motivation', typeIndex: 0, icon: Icons.trending_down_rounded, colorValue: const Color(0xFF8D6E63).value, isDefault: true),
      HabitReason(text: 'Forgot', typeIndex: 0, icon: Icons.lightbulb_outline_rounded, colorValue: const Color(0xFFFFD54F).value, isDefault: true),
      HabitReason(text: 'Not in the mood', typeIndex: 0, icon: Icons.sentiment_dissatisfied_rounded, colorValue: const Color(0xFF9575CD).value, isDefault: true),
      HabitReason(text: 'Emergency', typeIndex: 0, icon: Icons.emergency_rounded, colorValue: const Color(0xFFE53935).value, isDefault: true),
    ];
  }

  /// Create default "Postpone" reasons
  static List<HabitReason> getDefaultPostponeReasons() {
    return [
      HabitReason(text: 'Will do later today', typeIndex: 1, icon: Icons.schedule_rounded, colorValue: const Color(0xFFFFB74D).value, isDefault: true),
      HabitReason(text: 'Tomorrow morning', typeIndex: 1, icon: Icons.wb_sunny_rounded, colorValue: const Color(0xFFFFD54F).value, isDefault: true),
      HabitReason(text: 'This evening', typeIndex: 1, icon: Icons.nights_stay_rounded, colorValue: const Color(0xFF9575CD).value, isDefault: true),
      HabitReason(text: 'After work', typeIndex: 1, icon: Icons.work_off_rounded, colorValue: const Color(0xFF5C6BC0).value, isDefault: true),
      HabitReason(text: 'This weekend', typeIndex: 1, icon: Icons.weekend_rounded, colorValue: const Color(0xFF66BB6A).value, isDefault: true),
      HabitReason(text: 'Need more energy', typeIndex: 1, icon: Icons.battery_charging_full_rounded, colorValue: const Color(0xFF4CAF50).value, isDefault: true),
    ];
  }

  /// Create default slip reasons (for quit bad habits - when user slipped)
  static List<HabitReason> getDefaultSlipReasons() {
    return [
      HabitReason(text: 'Peer pressure', typeIndex: 2, icon: Icons.people_outline, colorValue: const Color(0xFF42A5F5).value, isDefault: true),
      HabitReason(text: 'Stress', typeIndex: 2, icon: Icons.psychology_outlined, colorValue: const Color(0xFFEF5350).value, isDefault: true),
      HabitReason(text: 'Boredom', typeIndex: 2, icon: Icons.hourglass_empty, colorValue: const Color(0xFF78909C).value, isDefault: true),
      HabitReason(text: 'Social event', typeIndex: 2, icon: Icons.celebration_outlined, colorValue: const Color(0xFF66BB6A).value, isDefault: true),
      HabitReason(text: 'Bad day', typeIndex: 2, icon: Icons.cloud_outlined, colorValue: const Color(0xFF9575CD).value, isDefault: true),
      HabitReason(text: 'Forgot my goal', typeIndex: 2, icon: Icons.lightbulb_outline, colorValue: const Color(0xFFFFD54F).value, isDefault: true),
      HabitReason(text: 'Gave in to craving', typeIndex: 2, icon: Icons.favorite_outline, colorValue: const Color(0xFFFF6B6B).value, isDefault: true),
    ];
  }

  /// Create default temptation reasons (shared with slip)
  static List<HabitReason> getDefaultTemptationReasons() {
    return [
      HabitReason(text: 'Saw someone else doing it', typeIndex: 3, icon: Icons.visibility_outlined, colorValue: const Color(0xFF5C6BC0).value, isDefault: true),
      HabitReason(text: 'Stress trigger', typeIndex: 3, icon: Icons.psychology_outlined, colorValue: const Color(0xFFEF5350).value, isDefault: true),
      HabitReason(text: 'Boredom', typeIndex: 3, icon: Icons.hourglass_empty, colorValue: const Color(0xFF78909C).value, isDefault: true),
      HabitReason(text: 'Social situation', typeIndex: 3, icon: Icons.groups_outlined, colorValue: const Color(0xFF29B6F6).value, isDefault: true),
      HabitReason(text: 'Emotional moment', typeIndex: 3, icon: Icons.sentiment_dissatisfied_outlined, colorValue: const Color(0xFF9575CD).value, isDefault: true),
      HabitReason(text: 'Habitual trigger', typeIndex: 3, icon: Icons.repeat, colorValue: const Color(0xFFAB47BC).value, isDefault: true),
      HabitReason(text: 'Available nearby', typeIndex: 3, icon: Icons.location_on_outlined, colorValue: const Color(0xFF26A69A).value, isDefault: true),
    ];
  }

  /// Create a copy with updated fields
  HabitReason copyWith({
    String? id,
    String? text,
    int? iconCodePoint,
    String? iconFontFamily,
    String? iconFontPackage,
    int? typeIndex,
    DateTime? createdAt,
    IconData? icon,
    int? colorValue,
    bool? isActive,
    bool? isDefault,
  }) {
    return HabitReason(
      id: id ?? this.id,
      text: text ?? this.text,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      iconFontFamily: iconFontFamily ?? this.iconFontFamily,
      iconFontPackage: iconFontPackage ?? this.iconFontPackage,
      typeIndex: typeIndex ?? this.typeIndex,
      createdAt: createdAt ?? this.createdAt,
      icon: icon,
      colorValue: colorValue ?? this.colorValue,
      isActive: isActive ?? this.isActive,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}
