import 'dart:convert';
import 'package:uuid/uuid.dart';

/// A single reminder for a bill/subscription payment.
///
/// Defines WHEN to notify (timing relative to due date), WHAT notification type
/// to use (Hub type ID), and CONDITIONS for when to fire (always, once, etc.).
class BillReminder {
  /// Unique identifier for this reminder (used in notification IDs)
  final String id;

  /// When to fire: 'before', 'on_due', 'after_due'
  final String timing;

  /// Offset value (e.g., 2 for "2 days before")
  final int value;

  /// Unit: 'days', 'weeks', 'months', 'hours'
  final String unit;

  /// Time of day to fire (0-23)
  final int hour;

  /// Minute of the hour (0-59)
  final int minute;

  /// Hub notification type ID (e.g., 'finance_bill_upcoming')
  final String typeId;

  /// Condition: 'always', 'once', 'if_unpaid', 'if_overdue'
  final String condition;

  /// Custom title template (null = auto-generate)
  /// Variables: {billName}, {amount}, {dueDate}, {daysLeft}, {category}
  final String? titleTemplate;

  /// Custom body template (null = auto-generate)
  final String? bodyTemplate;

  /// Whether this reminder is enabled
  final bool enabled;

  const BillReminder({
    required this.id,
    required this.timing,
    this.value = 0,
    this.unit = 'days',
    this.hour = 9,
    this.minute = 0,
    required this.typeId,
    this.condition = 'always',
    this.titleTemplate,
    this.bodyTemplate,
    this.enabled = true,
  });

  /// Stable fingerprint for notification ID generation
  String get fingerprint => '$timing:$value:$unit:$hour:$minute:$id';

  /// Human-readable description
  String get description {
    final timeStr =
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

    switch (timing) {
      case 'before':
        return '$value $unit before at $timeStr';
      case 'on_due':
        return 'On due date at $timeStr';
      case 'after_due':
        return '$value $unit after due at $timeStr';
      default:
        return 'Unknown timing';
    }
  }

  /// Calculate fire time from due date (bill, debt, or lending)
  DateTime calculateFireTime(DateTime dueDate) {
    DateTime fireDate;

    int daysOffset(int v, String u) {
      switch (u) {
        case 'hours':
          return 0; // handled separately
        case 'weeks':
          return v * 7;
        case 'months':
          return v * 30;
        default:
          return v;
      }
    }

    switch (timing) {
      case 'before':
        if (unit == 'hours') {
          fireDate = dueDate.subtract(Duration(hours: value));
        } else {
          fireDate = dueDate.subtract(Duration(days: daysOffset(value, unit)));
        }
        break;
      case 'on_due':
        fireDate = dueDate;
        break;
      case 'after_due':
        if (unit == 'hours') {
          fireDate = dueDate.add(Duration(hours: value));
        } else {
          fireDate = dueDate.add(Duration(days: daysOffset(value, unit)));
        }
        break;
      default:
        fireDate = dueDate;
    }

    // Apply time of day
    return DateTime(fireDate.year, fireDate.month, fireDate.day, hour, minute);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Factory Presets
  // ══════════════════════════════════════════════════════════════════════════

  /// 3 days before at 9:00 AM
  factory BillReminder.threeDaysBefore({
    required String typeId,
    String condition = 'always',
  }) {
    return BillReminder(
      id: const Uuid().v4(),
      timing: 'before',
      value: 3,
      unit: 'days',
      hour: 9,
      minute: 0,
      typeId: typeId,
      condition: condition,
    );
  }

  /// 1 day before at 9:00 AM
  factory BillReminder.oneDayBefore({
    required String typeId,
    String condition = 'always',
  }) {
    return BillReminder(
      id: const Uuid().v4(),
      timing: 'before',
      value: 1,
      unit: 'days',
      hour: 9,
      minute: 0,
      typeId: typeId,
      condition: condition,
    );
  }

  /// On due date at 9:00 AM
  factory BillReminder.onDueDate({
    required String typeId,
    String condition = 'if_unpaid',
  }) {
    return BillReminder(
      id: const Uuid().v4(),
      timing: 'on_due',
      value: 0,
      unit: 'days',
      hour: 9,
      minute: 0,
      typeId: typeId,
      condition: condition,
    );
  }

  /// 1 day after (overdue) at 10:00 AM
  factory BillReminder.oneDayOverdue({
    required String typeId,
    String condition = 'if_overdue',
  }) {
    return BillReminder(
      id: const Uuid().v4(),
      timing: 'after_due',
      value: 1,
      unit: 'days',
      hour: 10,
      minute: 0,
      typeId: typeId,
      condition: condition,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // JSON Serialization
  // ══════════════════════════════════════════════════════════════════════════

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timing': timing,
      'value': value,
      'unit': unit,
      'hour': hour,
      'minute': minute,
      'typeId': typeId,
      'condition': condition,
      if (titleTemplate != null) 'titleTemplate': titleTemplate,
      if (bodyTemplate != null) 'bodyTemplate': bodyTemplate,
      'enabled': enabled,
    };
  }

  factory BillReminder.fromJson(Map<String, dynamic> json) {
    return BillReminder(
      id: json['id'] as String? ?? const Uuid().v4(),
      timing: json['timing'] as String? ?? 'before',
      value: json['value'] as int? ?? 0,
      unit: json['unit'] as String? ?? 'days',
      hour: json['hour'] as int? ?? 9,
      minute: json['minute'] as int? ?? 0,
      typeId: json['typeId'] as String? ?? 'finance_bill_upcoming',
      condition: json['condition'] as String? ?? 'always',
      titleTemplate: json['titleTemplate'] as String?,
      bodyTemplate: json['bodyTemplate'] as String?,
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  /// Encode a list of reminders to JSON string
  static String encodeList(List<BillReminder> reminders) {
    return jsonEncode(reminders.map((r) => r.toJson()).toList());
  }

  /// Decode JSON string to list of reminders
  static List<BillReminder> decodeList(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) return [];

    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is List) {
        return decoded
            .map((item) => BillReminder.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Copy & Equality
  // ══════════════════════════════════════════════════════════════════════════

  BillReminder copyWith({
    String? id,
    String? timing,
    int? value,
    String? unit,
    int? hour,
    int? minute,
    String? typeId,
    String? condition,
    String? titleTemplate,
    String? bodyTemplate,
    bool? enabled,
    bool clearTitleTemplate = false,
    bool clearBodyTemplate = false,
  }) {
    return BillReminder(
      id: id ?? this.id,
      timing: timing ?? this.timing,
      value: value ?? this.value,
      unit: unit ?? this.unit,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      typeId: typeId ?? this.typeId,
      condition: condition ?? this.condition,
      titleTemplate: clearTitleTemplate
          ? null
          : (titleTemplate ?? this.titleTemplate),
      bodyTemplate: clearBodyTemplate
          ? null
          : (bodyTemplate ?? this.bodyTemplate),
      enabled: enabled ?? this.enabled,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BillReminder &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'BillReminder($description, type: $typeId, condition: $condition)';
}
