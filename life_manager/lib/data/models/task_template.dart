import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'task_template.g.dart';

/// TaskTemplate model with Hive persistence
/// Represents a reusable task template that can be used to quickly create tasks
@HiveType(typeId: 5)
class TaskTemplate extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String? description;

  @HiveField(3)
  String? categoryId;

  @HiveField(4)
  String priority; // 'Low', 'Medium', 'High'

  @HiveField(5)
  int? iconCodePoint;

  @HiveField(6)
  String? iconFontFamily;

  @HiveField(7)
  String? iconFontPackage;

  @HiveField(8)
  int? defaultDurationMinutes; // Default estimated duration

  @HiveField(9)
  String? defaultRemindersJson; // JSON list of Reminder maps (legacy strings also supported for migration)

  @HiveField(10)
  List<String>? defaultSubtasks; // Pre-defined subtask titles

  @HiveField(11)
  List<String>? tags;

  @HiveField(12)
  String? notes;

  @HiveField(13)
  int usageCount; // How many times this template was used

  @HiveField(14)
  DateTime? lastUsedAt; // When was this template last used

  @HiveField(15)
  DateTime createdAt;

  @HiveField(16)
  DateTime? updatedAt;

  @HiveField(17)
  String? taskTypeId; // Reference to task type for points system

  @HiveField(18)
  int? defaultTimeHour; // Default time hour (0-23)

  @HiveField(19)
  int? defaultTimeMinute; // Default time minute (0-59)

  @HiveField(20)
  List<DateTime>? usageHistory; // List of all usage timestamps for timeline

  TaskTemplate({
    String? id,
    required this.title,
    this.description,
    this.categoryId,
    this.priority = 'Medium',
    this.iconCodePoint,
    this.iconFontFamily,
    this.iconFontPackage,
    this.defaultDurationMinutes,
    this.defaultRemindersJson,
    this.defaultSubtasks,
    this.tags,
    this.notes,
    this.usageCount = 0,
    this.lastUsedAt,
    DateTime? createdAt,
    this.updatedAt,
    this.taskTypeId,
    this.defaultTimeHour,
    this.defaultTimeMinute,
    this.usageHistory,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  /// Get IconData from stored values
  IconData? get icon {
    if (iconCodePoint == null) return null;
    return IconData(
      iconCodePoint!,
      fontFamily: iconFontFamily ?? 'MaterialIcons',
      fontPackage: iconFontPackage,
    );
  }

  /// Set icon from IconData
  void setIcon(IconData? icon) {
    if (icon == null) {
      iconCodePoint = null;
      iconFontFamily = null;
      iconFontPackage = null;
    } else {
      iconCodePoint = icon.codePoint;
      iconFontFamily = icon.fontFamily;
      iconFontPackage = icon.fontPackage;
    }
  }

  /// Get default time as TimeOfDay
  TimeOfDay? get defaultTime {
    if (defaultTimeHour == null || defaultTimeMinute == null) return null;
    return TimeOfDay(hour: defaultTimeHour!, minute: defaultTimeMinute!);
  }

  /// Set default time from TimeOfDay
  void setDefaultTime(TimeOfDay? time) {
    if (time == null) {
      defaultTimeHour = null;
      defaultTimeMinute = null;
    } else {
      defaultTimeHour = time.hour;
      defaultTimeMinute = time.minute;
    }
  }

  /// Record that this template was used
  void recordUsage() {
    final now = DateTime.now();
    usageCount++;
    lastUsedAt = now;
    usageHistory = [...(usageHistory ?? []), now];
  }

  /// Get human-readable "time ago" string for last used
  String get lastUsedAgo {
    if (lastUsedAt == null) return 'Never used';

    final now = DateTime.now();
    final difference = now.difference(lastUsedAt!);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes} min ago';
      }
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks week${weeks == 1 ? '' : 's'} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months == 1 ? '' : 's'} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years year${years == 1 ? '' : 's'} ago';
    }
  }

  /// Create a copy with updated fields
  TaskTemplate copyWith({
    String? id,
    String? title,
    String? description,
    String? categoryId,
    String? priority,
    int? iconCodePoint,
    String? iconFontFamily,
    String? iconFontPackage,
    int? defaultDurationMinutes,
    String? defaultRemindersJson,
    List<String>? defaultSubtasks,
    List<String>? tags,
    String? notes,
    int? usageCount,
    DateTime? lastUsedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? taskTypeId,
    int? defaultTimeHour,
    int? defaultTimeMinute,
    List<DateTime>? usageHistory,
  }) {
    return TaskTemplate(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      priority: priority ?? this.priority,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      iconFontFamily: iconFontFamily ?? this.iconFontFamily,
      iconFontPackage: iconFontPackage ?? this.iconFontPackage,
      defaultDurationMinutes: defaultDurationMinutes ?? this.defaultDurationMinutes,
      defaultRemindersJson: defaultRemindersJson ?? this.defaultRemindersJson,
      defaultSubtasks: defaultSubtasks ?? this.defaultSubtasks,
      tags: tags ?? this.tags,
      notes: notes ?? this.notes,
      usageCount: usageCount ?? this.usageCount,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      taskTypeId: taskTypeId ?? this.taskTypeId,
      defaultTimeHour: defaultTimeHour ?? this.defaultTimeHour,
      defaultTimeMinute: defaultTimeMinute ?? this.defaultTimeMinute,
      usageHistory: usageHistory ?? this.usageHistory,
    );
  }
}
