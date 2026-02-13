import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'universal_notification.g.dart';

/// Action button definition for a universal notification.
class UniversalNotificationAction {
  final String actionId;
  final String label;
  final int? iconCodePoint;
  final String? iconFontFamily;
  final String? iconFontPackage;
  final bool showsUserInterface;
  final bool cancelNotification;

  const UniversalNotificationAction({
    required this.actionId,
    required this.label,
    this.iconCodePoint,
    this.iconFontFamily,
    this.iconFontPackage,
    this.showsUserInterface = false,
    this.cancelNotification = true,
  });

  Map<String, dynamic> toJson() => {
        'actionId': actionId,
        'label': label,
        if (iconCodePoint != null) 'iconCodePoint': iconCodePoint,
        if (iconFontFamily != null) 'iconFontFamily': iconFontFamily,
        if (iconFontPackage != null) 'iconFontPackage': iconFontPackage,
        'showsUserInterface': showsUserInterface,
        'cancelNotification': cancelNotification,
      };

  factory UniversalNotificationAction.fromJson(Map<String, dynamic> json) {
    return UniversalNotificationAction(
      actionId: json['actionId'] as String,
      label: json['label'] as String,
      iconCodePoint: json['iconCodePoint'] as int?,
      iconFontFamily: json['iconFontFamily'] as String?,
      iconFontPackage: json['iconFontPackage'] as String?,
      showsUserInterface: json['showsUserInterface'] as bool? ?? false,
      cancelNotification: json['cancelNotification'] as bool? ?? true,
    );
  }

  UniversalNotificationAction copyWith({
    String? actionId,
    String? label,
    int? iconCodePoint,
    String? iconFontFamily,
    String? iconFontPackage,
    bool? showsUserInterface,
    bool? cancelNotification,
  }) {
    return UniversalNotificationAction(
      actionId: actionId ?? this.actionId,
      label: label ?? this.label,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      iconFontFamily: iconFontFamily ?? this.iconFontFamily,
      iconFontPackage: iconFontPackage ?? this.iconFontPackage,
      showsUserInterface: showsUserInterface ?? this.showsUserInterface,
      cancelNotification: cancelNotification ?? this.cancelNotification,
    );
  }
}

/// A single universal notification created via the Universal Notification Creator.
///
/// Stored in a single Hive box owned by the Notification Hub.
/// Replaces scattered reminder storage (bill.remindersJson, task reminders,
/// habit reminders, sleep prefs) with one unified format.
@HiveType(typeId: 41)
class UniversalNotification extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String moduleId;

  @HiveField(2)
  String section;

  @HiveField(3)
  String entityId;

  @HiveField(4)
  String entityName;

  @HiveField(5)
  String titleTemplate;

  @HiveField(6)
  String bodyTemplate;

  @HiveField(7)
  int? iconCodePoint;

  @HiveField(8)
  String? iconFontFamily;

  @HiveField(9)
  String? iconFontPackage;

  @HiveField(10)
  int? colorValue;

  @HiveField(11)
  String actionsJson;

  @HiveField(12)
  String typeId;

  @HiveField(13)
  String timing;

  @HiveField(14)
  int timingValue;

  @HiveField(15)
  String timingUnit;

  @HiveField(16)
  int hour;

  @HiveField(17)
  int minute;

  @HiveField(18)
  String condition;

  @HiveField(19)
  bool enabled;

  @HiveField(20)
  DateTime createdAt;

  @HiveField(21)
  DateTime updatedAt;

  @HiveField(22)
  bool actionsEnabled;

  UniversalNotification({
    String? id,
    required this.moduleId,
    required this.section,
    required this.entityId,
    required this.entityName,
    required this.titleTemplate,
    required this.bodyTemplate,
    this.iconCodePoint,
    this.iconFontFamily,
    this.iconFontPackage,
    this.colorValue,
    this.actionsJson = '[]',
    required this.typeId,
    this.timing = 'before',
    this.timingValue = 1,
    this.timingUnit = 'days',
    this.hour = 9,
    this.minute = 0,
    this.condition = 'always',
    this.enabled = true,
    this.actionsEnabled = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  List<UniversalNotificationAction>? _cachedActions;
  String? _cachedActionsJson;

  List<UniversalNotificationAction> get actions {
    if (actionsJson.isEmpty) return [];
    if (_cachedActions != null && _cachedActionsJson == actionsJson) {
      return _cachedActions!;
    }
    try {
      final decoded = jsonDecode(actionsJson);
      if (decoded is List) {
        _cachedActions = decoded
            .map((e) => UniversalNotificationAction.fromJson(
                e as Map<String, dynamic>))
            .toList();
        _cachedActionsJson = actionsJson;
        return _cachedActions!;
      }
    } catch (_) {}
    _cachedActions = [];
    _cachedActionsJson = actionsJson;
    return _cachedActions!;
  }

  set actions(List<UniversalNotificationAction> value) {
    final newJson = jsonEncode(value.map((a) => a.toJson()).toList());
    actionsJson = newJson;
    _cachedActions = value;
    _cachedActionsJson = newJson;
  }

  /// Human-readable description of timing (e.g., "3 days before at 09:00")
  String get timingDescription {
    final timeStr =
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    switch (timing) {
      case 'before':
        return '$timingValue $timingUnit before at $timeStr';
      case 'on_due':
        return 'On due date at $timeStr';
      case 'after_due':
        return '$timingValue $timingUnit after at $timeStr';
      default:
        return 'At $timeStr';
    }
  }

  UniversalNotification copyWith({
    String? id,
    String? moduleId,
    String? section,
    String? entityId,
    String? entityName,
    String? titleTemplate,
    String? bodyTemplate,
    int? iconCodePoint,
    String? iconFontFamily,
    String? iconFontPackage,
    int? colorValue,
    String? actionsJson,
    String? typeId,
    String? timing,
    int? timingValue,
    String? timingUnit,
    int? hour,
    int? minute,
    String? condition,
    bool? enabled,
    bool? actionsEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UniversalNotification(
      id: id ?? this.id,
      moduleId: moduleId ?? this.moduleId,
      section: section ?? this.section,
      entityId: entityId ?? this.entityId,
      entityName: entityName ?? this.entityName,
      titleTemplate: titleTemplate ?? this.titleTemplate,
      bodyTemplate: bodyTemplate ?? this.bodyTemplate,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      iconFontFamily: iconFontFamily ?? this.iconFontFamily,
      iconFontPackage: iconFontPackage ?? this.iconFontPackage,
      colorValue: colorValue ?? this.colorValue,
      actionsJson: actionsJson ?? this.actionsJson,
      typeId: typeId ?? this.typeId,
      timing: timing ?? this.timing,
      timingValue: timingValue ?? this.timingValue,
      timingUnit: timingUnit ?? this.timingUnit,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      condition: condition ?? this.condition,
      enabled: enabled ?? this.enabled,
      actionsEnabled: actionsEnabled ?? this.actionsEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'moduleId': moduleId,
        'section': section,
        'entityId': entityId,
        'entityName': entityName,
        'titleTemplate': titleTemplate,
        'bodyTemplate': bodyTemplate,
        'iconCodePoint': iconCodePoint,
        'iconFontFamily': iconFontFamily,
        'iconFontPackage': iconFontPackage,
        'colorValue': colorValue,
        'actionsJson': actionsJson,
        'typeId': typeId,
        'timing': timing,
        'timingValue': timingValue,
        'timingUnit': timingUnit,
        'hour': hour,
        'minute': minute,
        'condition': condition,
        'enabled': enabled,
        'actionsEnabled': actionsEnabled,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory UniversalNotification.fromJson(Map<String, dynamic> json) {
    return UniversalNotification(
      id: json['id'] as String?,
      moduleId: json['moduleId'] as String,
      section: json['section'] as String,
      entityId: json['entityId'] as String,
      entityName: json['entityName'] as String,
      titleTemplate: json['titleTemplate'] as String,
      bodyTemplate: json['bodyTemplate'] as String,
      iconCodePoint: json['iconCodePoint'] as int?,
      iconFontFamily: json['iconFontFamily'] as String?,
      iconFontPackage: json['iconFontPackage'] as String?,
      colorValue: json['colorValue'] as int?,
      actionsJson: json['actionsJson'] as String? ?? '[]',
      typeId: json['typeId'] as String,
      timing: json['timing'] as String? ?? 'before',
      timingValue: json['timingValue'] as int? ?? 1,
      timingUnit: json['timingUnit'] as String? ?? 'days',
      hour: json['hour'] as int? ?? 9,
      minute: json['minute'] as int? ?? 0,
      condition: json['condition'] as String? ?? 'always',
      enabled: json['enabled'] as bool? ?? true,
      actionsEnabled: json['actionsEnabled'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }
}
