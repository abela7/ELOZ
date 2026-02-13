import 'dart:convert';

/// Modern reminder model with flexible timing options
/// 
/// Supports:
/// - Before task: minutes, hours, days, or weeks before
/// - At task time: exactly when task is due
/// - After task: for follow-ups or post-task reminders
/// - Custom: specific date and time
class Reminder {
  /// Type of reminder: 'before', 'at_time', 'after', 'custom'
  final String type;

  /// Time value (e.g., 5 for "5 minutes", 2 for "2 hours")
  final int value;

  /// Unit: 'minutes', 'hours', 'days', 'weeks'
  final String unit;

  /// Custom date/time for 'custom' type reminders
  final DateTime? customDateTime;

  /// Whether reminder is enabled
  final bool enabled;

  /// Sound/vibration settings
  final String soundType; // 'default', 'silent', 'urgent'

  /// Snooze duration in minutes (for when user snoozes)
  final int snoozeDuration;

  Reminder({
    required this.type,
    this.value = 0,
    this.unit = 'minutes',
    this.customDateTime,
    this.enabled = true,
    this.soundType = 'default',
    this.snoozeDuration = 10,
  });

  /// Stable identifier for this reminder's scheduling meaning.
  /// Useful for notification IDs and de-duping.
  String get fingerprint {
    final customMs = customDateTime?.millisecondsSinceEpoch;
    if (customMs != null) return '$type:custom:$customMs';
    return '$type:$value:$unit';
  }

  /// Quick factory constructors for common reminder patterns
  
  /// 5 minutes before
  factory Reminder.fiveMinutesBefore() {
    return Reminder(
      type: 'before',
      value: 5,
      unit: 'minutes',
    );
  }

  /// 15 minutes before
  factory Reminder.fifteenMinutesBefore() {
    return Reminder(
      type: 'before',
      value: 15,
      unit: 'minutes',
    );
  }

  /// 30 minutes before
  factory Reminder.thirtyMinutesBefore() {
    return Reminder(
      type: 'before',
      value: 30,
      unit: 'minutes',
    );
  }

  /// 1 hour before
  factory Reminder.oneHourBefore() {
    return Reminder(
      type: 'before',
      value: 1,
      unit: 'hours',
    );
  }

  /// 1 day before (at 9 AM)
  factory Reminder.oneDayBefore() {
    return Reminder(
      type: 'before',
      value: 1,
      unit: 'days',
    );
  }

  /// At task time
  factory Reminder.atTaskTime() {
    return Reminder(
      type: 'at_time',
      value: 0,
      unit: 'minutes',
    );
  }

  /// Custom reminder with specific date/time
  factory Reminder.custom(DateTime dateTime) {
    return Reminder(
      type: 'custom',
      value: 0,
      unit: 'minutes',
      customDateTime: dateTime,
    );
  }

  /// Calculate when the reminder should fire based on task due date/time
  DateTime? calculateReminderTime(DateTime taskDueDate) {
    switch (type) {
      case 'before':
        return _calculateBeforeTime(taskDueDate);
      case 'at_time':
        return taskDueDate;
      case 'after':
        return _calculateAfterTime(taskDueDate);
      case 'custom':
        return customDateTime;
      default:
        return null;
    }
  }

  DateTime _calculateBeforeTime(DateTime taskDueDate) {
    switch (unit) {
      case 'minutes':
        return taskDueDate.subtract(Duration(minutes: value));
      case 'hours':
        return taskDueDate.subtract(Duration(hours: value));
      case 'days':
        // Align with regular task notifications: keep the task's time-of-day.
        final reminderDate = taskDueDate.subtract(Duration(days: value));
        return DateTime(
          reminderDate.year,
          reminderDate.month,
          reminderDate.day,
          taskDueDate.hour,
          taskDueDate.minute,
        );
      case 'weeks':
        // Align with regular task notifications: keep the task's time-of-day.
        final reminderDate = taskDueDate.subtract(Duration(days: value * 7));
        return DateTime(
          reminderDate.year,
          reminderDate.month,
          reminderDate.day,
          taskDueDate.hour,
          taskDueDate.minute,
        );
      default:
        return taskDueDate;
    }
  }

  DateTime _calculateAfterTime(DateTime taskDueDate) {
    switch (unit) {
      case 'minutes':
        return taskDueDate.add(Duration(minutes: value));
      case 'hours':
        return taskDueDate.add(Duration(hours: value));
      case 'days':
        return taskDueDate.add(Duration(days: value));
      case 'weeks':
        return taskDueDate.add(Duration(days: value * 7));
      default:
        return taskDueDate;
    }
  }

  /// Get human-readable description
  String getDescription() {
    switch (type) {
      case 'before':
        return _getBeforeDescription();
      case 'at_time':
        return 'At task time';
      case 'after':
        return _getAfterDescription();
      case 'custom':
        if (customDateTime != null) {
          return 'Custom: ${_formatDateTime(customDateTime!)}';
        }
        return 'Custom';
      default:
        return 'Unknown';
    }
  }

  String _getBeforeDescription() {
    if (value == 0) return 'At task time';
    
    final unitLabel = value == 1 
        ? unit.substring(0, unit.length - 1) // Remove 's' for singular
        : unit;
    
    return '$value $unitLabel before';
  }

  String _getAfterDescription() {
    if (value == 0) return 'At task time';
    
    final unitLabel = value == 1 
        ? unit.substring(0, unit.length - 1) // Remove 's' for singular
        : unit;
    
    return '$value $unitLabel after';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month}/${dateTime.day} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// Convert to JSON string for storage
  String toJson() {
    return jsonEncode(toMap());
  }

  /// Create from JSON string
  factory Reminder.fromJson(String jsonString) {
    final map = jsonDecode(jsonString) as Map<String, dynamic>;
    return Reminder.fromMap(map);
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'value': value,
      'unit': unit,
      'customDateTime': customDateTime?.toIso8601String(),
      'enabled': enabled,
      'soundType': soundType,
      'snoozeDuration': snoozeDuration,
    };
  }

  factory Reminder.fromMap(Map<String, dynamic> map) {
    return Reminder(
      type: map['type'] as String,
      value: map['value'] as int? ?? 0,
      unit: map['unit'] as String? ?? 'minutes',
      customDateTime: map['customDateTime'] != null
          ? DateTime.parse(map['customDateTime'] as String)
          : null,
      enabled: map['enabled'] as bool? ?? true,
      soundType: map['soundType'] as String? ?? 'default',
      snoozeDuration: map['snoozeDuration'] as int? ?? 10,
    );
  }

  static String encodeList(List<Reminder> reminders) {
    return jsonEncode(reminders.map((r) => r.toMap()).toList());
  }

  static List<Reminder> decodeList(String jsonString) {
    final decoded = jsonDecode(jsonString);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((m) => Reminder.fromMap(m.cast<String, dynamic>()))
        .toList();
  }

  /// Copy with method for updates
  Reminder copyWith({
    String? type,
    int? value,
    String? unit,
    DateTime? customDateTime,
    bool? enabled,
    String? soundType,
    int? snoozeDuration,
  }) {
    return Reminder(
      type: type ?? this.type,
      value: value ?? this.value,
      unit: unit ?? this.unit,
      customDateTime: customDateTime ?? this.customDateTime,
      enabled: enabled ?? this.enabled,
      soundType: soundType ?? this.soundType,
      snoozeDuration: snoozeDuration ?? this.snoozeDuration,
    );
  }

  @override
  String toString() => getDescription();
}

