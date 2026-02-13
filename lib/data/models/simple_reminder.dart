import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'simple_reminder.g.dart';

/// Timer mode for reminders
class ReminderTimerMode {
  static const String none = 'none';
  static const String countdown = 'countdown';
  static const String countup = 'countup';
}

/// Reminder status
class ReminderStatus {
  static const String pending = 'pending';
  static const String done = 'done';
}

/// Simple Reminder model with Hive persistence
/// Lightweight reminders for quick notes like "call someone back"
/// Auto-expires 24 hours after scheduledAt
@HiveType(typeId: 6)
class SimpleReminder extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  DateTime scheduledAt;

  @HiveField(3)
  DateTime createdAt;

  @HiveField(4)
  String status; // 'pending', 'done'

  @HiveField(5)
  String timerMode; // 'none', 'countdown', 'countup'

  @HiveField(6)
  DateTime? counterStartedAt; // When count-up was started

  @HiveField(7)
  String? description;

  @HiveField(8)
  int? iconCodePoint;

  @HiveField(9)
  String? iconFontFamily;

  @HiveField(10)
  String? iconFontPackage;

  @HiveField(11)
  int? colorValue;

  @HiveField(12)
  int notificationId;

  @HiveField(13)
  DateTime? completedAt;

  @HiveField(14)
  bool isPinned;

  SimpleReminder({
    String? id,
    required this.title,
    required this.scheduledAt,
    DateTime? createdAt,
    this.status = 'pending',
    this.timerMode = 'none',
    this.counterStartedAt,
    this.description,
    this.iconCodePoint,
    this.iconFontFamily,
    this.iconFontPackage,
    this.colorValue,
    int? notificationId,
    this.completedAt,
    this.isPinned = false,
    IconData? icon,
    Color? color,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        notificationId = notificationId ?? DateTime.now().millisecondsSinceEpoch % 2147483647 {
    // Set icon fields from IconData if provided
    if (icon != null) {
      this.iconCodePoint = icon.codePoint;
      this.iconFontFamily = icon.fontFamily;
      this.iconFontPackage = icon.fontPackage;
    }
    // Set color value from Color if provided
    if (color != null) {
      this.colorValue = color.value;
    }
  }

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
  Color? get color {
    if (colorValue == null) return null;
    return Color(colorValue!);
  }

  /// Set Color by storing value
  set color(Color? value) {
    colorValue = value?.value;
  }

  /// Check if reminder is expired (24 hours after scheduledAt)
  bool get isExpired {
    final expiryTime = scheduledAt.add(const Duration(hours: 24));
    return DateTime.now().isAfter(expiryTime);
  }

  /// Check if reminder is done
  bool get isDone => status == ReminderStatus.done;

  /// Check if reminder is pending
  bool get isPending => status == ReminderStatus.pending;

  /// Check if reminder time has passed
  bool get isOverdue {
    if (isDone) return false;
    return DateTime.now().isAfter(scheduledAt);
  }

  /// Check if countdown mode is active
  bool get isCountdown => timerMode == ReminderTimerMode.countdown;

  /// Check if count-up mode is active
  bool get isCountup => timerMode == ReminderTimerMode.countup;

  /// Get relative time string for countdown
  /// Returns "in X min", "in X hr", etc.
  String getCountdownText() {
    final now = DateTime.now();
    final diff = scheduledAt.difference(now);
    
    if (diff.isNegative) {
      // Time has passed
      final elapsed = now.difference(scheduledAt);
      return _formatElapsedTime(elapsed, prefix: '', suffix: ' ago');
    }
    
    return _formatElapsedTime(diff, prefix: 'in ', suffix: '');
  }

  /// Get relative time string for count-up
  /// Returns "X min ago", "X hr ago", etc.
  String getCountupText() {
    final startTime = counterStartedAt ?? scheduledAt;
    final now = DateTime.now();
    final elapsed = now.difference(startTime);
    
    if (elapsed.isNegative) {
      return 'starting soon';
    }
    
    return _formatElapsedTime(elapsed, prefix: '', suffix: ' ago');
  }

  /// Format elapsed duration into human-readable string
  String _formatElapsedTime(Duration duration, {String prefix = '', String suffix = ''}) {
    final totalMinutes = duration.inMinutes;
    final totalHours = duration.inHours;
    final totalDays = duration.inDays;
    
    if (totalDays > 0) {
      return '$prefix${totalDays}d$suffix';
    } else if (totalHours > 0) {
      final mins = totalMinutes % 60;
      if (mins > 0) {
        return '$prefix${totalHours}h ${mins}m$suffix';
      }
      return '$prefix${totalHours}h$suffix';
    } else if (totalMinutes > 0) {
      return '$prefix${totalMinutes}m$suffix';
    } else {
      final seconds = duration.inSeconds;
      if (seconds > 0) {
        return '$prefix${seconds}s$suffix';
      }
      return '${prefix}now$suffix'.trim();
    }
  }

  /// Get the timer display text based on mode
  String getTimerText() {
    switch (timerMode) {
      case ReminderTimerMode.countdown:
        return getCountdownText();
      case ReminderTimerMode.countup:
        return getCountupText();
      default:
        return '';
    }
  }

  /// Create a copy with updated fields
  SimpleReminder copyWith({
    String? id,
    String? title,
    DateTime? scheduledAt,
    DateTime? createdAt,
    String? status,
    String? timerMode,
    DateTime? counterStartedAt,
    String? description,
    int? iconCodePoint,
    String? iconFontFamily,
    String? iconFontPackage,
    int? colorValue,
    int? notificationId,
    DateTime? completedAt,
    bool? isPinned,
  }) {
    return SimpleReminder(
      id: id ?? this.id,
      title: title ?? this.title,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      timerMode: timerMode ?? this.timerMode,
      counterStartedAt: counterStartedAt ?? this.counterStartedAt,
      description: description ?? this.description,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      iconFontFamily: iconFontFamily ?? this.iconFontFamily,
      iconFontPackage: iconFontPackage ?? this.iconFontPackage,
      colorValue: colorValue ?? this.colorValue,
      notificationId: notificationId ?? this.notificationId,
      completedAt: completedAt ?? this.completedAt,
      isPinned: isPinned ?? this.isPinned,
    );
  }
}
