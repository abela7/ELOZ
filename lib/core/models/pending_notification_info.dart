import 'notification_settings.dart';

/// Detailed information about a pending notification for diagnostics
/// 
/// This model captures the full "journey" of a notification:
/// - Schedule: When it was created and when it will fire
/// - Quiet Hours: Whether it's blocked or allowed at fire time
/// - Channel: Which notification channel it uses
/// - Build: The final notification content
class PendingNotificationInfo {
  /// Notification ID
  final int id;
  
  /// Type: 'task', 'habit', or 'simple_reminder'
  final String type;
  
  /// Entity ID (task ID, habit ID, etc.)
  final String entityId;
  
  /// Notification title
  final String title;
  
  /// Notification body
  final String body;
  
  /// Raw payload
  final String? payload;
  
  /// Reminder type from payload (e.g., 'at_time', 'before')
  final String? reminderType;
  
  /// Reminder value (e.g., 5 for "5 minutes before")
  final int? reminderValue;
  
  /// Reminder unit (e.g., 'minutes', 'hours')
  final String? reminderUnit;
  
  // === SCHEDULE STAGE ===
  
  /// When this notification was scheduled (task creation/update time)
  /// Note: We can't retrieve this from Android, so it may be null
  final DateTime? scheduledAt;
  
  /// When the notification will fire
  /// Note: Android doesn't expose this directly for zoned scheduled notifications
  final DateTime? willFireAt;
  
  // === QUIET HOURS STAGE ===
  
  /// Whether notification time falls within quiet hours
  final bool isInQuietHours;
  
  /// Whether the notification will be blocked by quiet hours
  final bool willBeBlockedByQuietHours;
  
  /// Reason for quiet hours status
  final String quietHoursStatus;
  
  // === CHANNEL STAGE ===
  
  /// The channel key that will be used
  final String channelKey;
  
  /// Human-readable channel name
  final String channelName;
  
  /// Priority of the task/notification
  final String? priority;
  
  /// Whether this is a special task
  final bool isSpecial;
  
  // === BUILD STAGE ===
  
  /// Sound that will play
  final String soundKey;
  
  /// Human-readable sound name
  final String soundName;
  
  /// Vibration pattern that will be used
  final String vibrationPattern;
  
  /// Audio stream used for playback (notification/alarm/ring/media)
  final String audioStream;

  /// Whether alarm mode is enabled for this notification
  final bool useAlarmMode;
  
  /// Whether full-screen intent will be used
  final bool useFullScreenIntent;
  
  /// Additional metadata
  final Map<String, dynamic> metadata;

  PendingNotificationInfo({
    required this.id,
    required this.type,
    required this.entityId,
    required this.title,
    required this.body,
    this.payload,
    this.reminderType,
    this.reminderValue,
    this.reminderUnit,
    this.scheduledAt,
    this.willFireAt,
    this.isInQuietHours = false,
    this.willBeBlockedByQuietHours = false,
    this.quietHoursStatus = 'Unknown',
    this.channelKey = 'task_reminders',
    this.channelName = 'Task Reminders',
    this.priority,
    this.isSpecial = false,
    this.soundKey = 'default',
    this.soundName = 'Default',
    this.vibrationPattern = 'default',
    this.audioStream = 'notification',
    this.useAlarmMode = false,
    this.useFullScreenIntent = false,
    this.metadata = const {},
  });

  static Map<String, dynamic> _parsePayload(String? payload) {
    // Parse payload: format is "type|entityId|reminderType|value|unit"
    // or "type|entityId|reminderType|customMs|ms"
    String type = 'unknown';
    String entityId = '';
    String? reminderType;
    int? reminderValue;
    String? reminderUnit;

    if (payload != null && payload.isNotEmpty) {
      final parts = payload.split('|');
      if (parts.length >= 2) {
        type = parts[0]; // 'task', 'habit', 'simple_reminder'
        entityId = parts[1];
      }
      if (parts.length >= 3) {
        reminderType = parts[2];
      }
      if (parts.length >= 5) {
        reminderValue = int.tryParse(parts[3]);
        reminderUnit = parts[4];
      }
    }

    return {
      'type': type,
      'entityId': entityId,
      'reminderType': reminderType,
      'reminderValue': reminderValue,
      'reminderUnit': reminderUnit,
    };
  }

  /// Parse payload to extract reminder info
  static PendingNotificationInfo fromPendingRequest({
    required int id,
    required String? title,
    required String? body,
    required String? payload,
    required bool quietHoursEnabled,
    required bool isCurrentlyInQuietHours,
    required bool allowUrgentDuringQuietHours,
    required String defaultChannel,
    required String defaultSound,
    required String defaultVibration,
    required bool alarmModeEnabled,
    String? audioStream,
    DateTime? scheduledTime,
    bool? isQuietAtScheduledTime,
    String? taskPriority,
    bool? taskIsSpecial,
    DateTime? taskDueDateTime,
  }) {
    final parsed = _parsePayload(payload);
    final type = parsed['type'] as String;
    final entityId = parsed['entityId'] as String;
    final reminderType = parsed['reminderType'] as String?;
    final reminderValue = parsed['reminderValue'] as int?;
    final reminderUnit = parsed['reminderUnit'] as String?;
    
    // Determine if this is a special task
    final isSpecial = taskIsSpecial ?? false;
    final priority = taskPriority ?? 'Medium';
    
    // Determine channel
    final isHabit = type == 'habit';
    String channelKey;
    if (isSpecial) {
      channelKey = isHabit ? 'habit_urgent_reminders' : 'urgent_reminders';
    } else if (priority == 'High') {
      channelKey = isHabit ? 'habit_urgent_reminders' : 'urgent_reminders';
    } else {
      channelKey = defaultChannel;
    }
    
    final channelName = _getChannelDisplayName(channelKey);
    
    // Calculate when notification will fire (if we have task due time and reminder info)
    DateTime? willFireAt = scheduledTime;
    if (willFireAt == null && taskDueDateTime != null && reminderType != null) {
      willFireAt = _calculateReminderTime(
        taskDueDateTime, 
        reminderType, 
        reminderValue ?? 0, 
        reminderUnit ?? 'minutes',
      );
    }

    final quietAtScheduled = isQuietAtScheduledTime ?? isCurrentlyInQuietHours;

    // Determine quiet hours status
    bool willBeBlocked = false;
    String quietStatus;
    
    if (!quietHoursEnabled) {
      quietStatus = '✅ Quiet hours disabled';
    } else if (quietAtScheduled) {
      if (isSpecial && allowUrgentDuringQuietHours) {
        quietStatus = isHabit
            ? '⚠️ In quiet hours, but special habits allowed'
            : '⚠️ In quiet hours, but special tasks allowed';
      } else if ((channelKey == 'urgent_reminders' ||
              channelKey == 'habit_urgent_reminders') &&
          allowUrgentDuringQuietHours) {
        quietStatus = '⚠️ In quiet hours, but urgent allowed';
      } else {
        quietStatus = '🚫 Will be blocked by quiet hours';
        willBeBlocked = true;
      }
    } else {
      quietStatus = '✅ Not in quiet hours';
    }
    
    // Determine sound
    String soundKey;
    if (isSpecial) {
      soundKey = 'alarm'; // Special notifications use alarm sound
    } else if (channelKey == 'urgent_reminders' || channelKey == 'habit_urgent_reminders') {
      soundKey = 'alarm';
    } else {
      soundKey = defaultSound;
    }
    
    final soundName = _getSoundDisplayName(soundKey);
    final effectiveAudioStream = audioStream ?? 'notification';
    
    // Determine alarm mode
    final useAlarmMode = isSpecial || 
        (alarmModeEnabled && priority == 'High');
    
    return PendingNotificationInfo(
      id: id,
      type: type,
      entityId: entityId,
      title: title ?? 'Untitled',
      body: body ?? '',
      payload: payload,
      reminderType: reminderType,
      reminderValue: reminderValue,
      reminderUnit: reminderUnit,
      willFireAt: willFireAt,
      isInQuietHours: quietAtScheduled,
      willBeBlockedByQuietHours: willBeBlocked,
      quietHoursStatus: quietStatus,
      channelKey: channelKey,
      channelName: channelName,
      priority: priority,
      isSpecial: isSpecial,
      soundKey: soundKey,
      soundName: soundName,
      vibrationPattern: defaultVibration,
      audioStream: effectiveAudioStream,
      useAlarmMode: useAlarmMode,
      useFullScreenIntent: isSpecial && useAlarmMode,
    );
  }

  /// Build info from a tracked native alarm entry
  static PendingNotificationInfo fromTrackedAlarmEntry({
    required Map<String, dynamic> entry,
    required NotificationSettings settings,
  }) {
    final payload = entry['payload'] as String?;
    final parsed = _parsePayload(payload);
    final type = (entry['type'] as String?) ?? (parsed['type'] as String);
    final entityId = (entry['entityId'] as String?) ?? (parsed['entityId'] as String);
    final reminderType = parsed['reminderType'] as String?;
    final reminderValue = parsed['reminderValue'] as int?;
    final reminderUnit = parsed['reminderUnit'] as String?;

    final channelKey = (entry['channelKey'] as String?) ?? settings.defaultChannel;
    final soundKey = (entry['soundKey'] as String?) ?? settings.taskRemindersSound;
    final vibrationPattern = (entry['vibrationPattern'] as String?) ?? settings.defaultVibrationPattern;
    final audioStream = (entry['audioStream'] as String?) ?? settings.notificationAudioStream;

    final scheduledMs = entry['scheduledTimeMs'] as int?;
    final willFireAt = scheduledMs != null ? DateTime.fromMillisecondsSinceEpoch(scheduledMs) : null;
    final isQuietAtScheduled = willFireAt != null ? settings.isInQuietHoursAt(willFireAt) : settings.isInQuietHours();

    final isSpecial = entry['isSpecial'] == true;
    final priority = entry['priority'] as String? ?? 'Medium';
    final useAlarmMode = entry['useAlarmMode'] == true;
    final useFullScreen = entry['showFullscreen'] == true;

    // Quiet hours status (same rules as _scheduleNotification)
    bool willBeBlocked = false;
    String quietStatus;
    if (!settings.quietHoursEnabled) {
      quietStatus = '✅ Quiet hours disabled';
    } else if (isQuietAtScheduled) {
      final isUrgent =
          channelKey == 'urgent_reminders' || channelKey == 'habit_urgent_reminders';
      if (isSpecial) {
        if (!settings.allowUrgentDuringQuietHours) {
          quietStatus = '🚫 Will be blocked by quiet hours';
          willBeBlocked = true;
        } else {
          quietStatus = '⚠️ In quiet hours, but special allowed';
        }
      } else {
        if (!isUrgent || !settings.allowUrgentDuringQuietHours) {
          quietStatus = '🚫 Will be blocked by quiet hours';
          willBeBlocked = true;
        } else {
          quietStatus = '⚠️ In quiet hours, but urgent allowed';
        }
      }
    } else {
      quietStatus = '✅ Not in quiet hours';
    }

    return PendingNotificationInfo(
      id: entry['id'] as int? ?? 0,
      type: type,
      entityId: entityId,
      title: (entry['title'] as String?) ?? 'Untitled',
      body: (entry['body'] as String?) ?? '',
      payload: payload,
      reminderType: reminderType,
      reminderValue: reminderValue,
      reminderUnit: reminderUnit,
      willFireAt: willFireAt,
      isInQuietHours: isQuietAtScheduled,
      willBeBlockedByQuietHours: willBeBlocked,
      quietHoursStatus: quietStatus,
      channelKey: channelKey,
      channelName: _getChannelDisplayName(channelKey),
      priority: priority,
      isSpecial: isSpecial,
      soundKey: soundKey,
      soundName: _getSoundDisplayName(soundKey),
      vibrationPattern: vibrationPattern,
      audioStream: audioStream,
      useAlarmMode: useAlarmMode,
      useFullScreenIntent: useFullScreen,
      metadata: {
        'audioStream': entry['audioStream'],
        'oneShot': entry['oneShot'],
        'trackedSource': 'native_alarm',
      },
    );
  }
  
  static String _getChannelDisplayName(String channelKey) {
    // Use the actual method from NotificationSettings
    return NotificationSettings.getChannelDisplayName(channelKey);
  }
  
  static String _getSoundDisplayName(String soundKey) {
    // Use the actual method from NotificationSettings
    return NotificationSettings.getSoundDisplayName(soundKey);
  }
  
  static DateTime? _calculateReminderTime(
    DateTime taskDueDateTime,
    String reminderType,
    int value,
    String unit,
  ) {
    switch (reminderType) {
      case 'at_time':
        return taskDueDateTime;
      case 'before':
        switch (unit) {
          case 'minutes':
            return taskDueDateTime.subtract(Duration(minutes: value));
          case 'hours':
            return taskDueDateTime.subtract(Duration(hours: value));
          case 'days':
            return taskDueDateTime.subtract(Duration(days: value));
          case 'weeks':
            return taskDueDateTime.subtract(Duration(days: value * 7));
          default:
            return taskDueDateTime;
        }
      case 'after':
        switch (unit) {
          case 'minutes':
            return taskDueDateTime.add(Duration(minutes: value));
          case 'hours':
            return taskDueDateTime.add(Duration(hours: value));
          case 'days':
            return taskDueDateTime.add(Duration(days: value));
          case 'weeks':
            return taskDueDateTime.add(Duration(days: value * 7));
          default:
            return taskDueDateTime;
        }
      case 'custom':
        // For custom, the value is milliseconds since epoch
        if (unit == 'ms' && value > 0) {
          return DateTime.fromMillisecondsSinceEpoch(value);
        }
        return null;
      default:
        return null;
    }
  }
  
  /// Get human-readable reminder description
  String getReminderDescription() {
    if (reminderType == null) return 'Unknown';
    
    switch (reminderType) {
      case 'at_time':
        return 'At task time';
      case 'before':
        if (reminderValue == null || reminderUnit == null) return 'Before task';
        final unitLabel = reminderValue == 1 
            ? reminderUnit!.substring(0, reminderUnit!.length - 1)
            : reminderUnit;
        return '$reminderValue $unitLabel before';
      case 'after':
        if (reminderValue == null || reminderUnit == null) return 'After task';
        final unitLabel = reminderValue == 1 
            ? reminderUnit!.substring(0, reminderUnit!.length - 1)
            : reminderUnit;
        return '$reminderValue $unitLabel after';
      case 'custom':
        if (willFireAt != null) {
          return 'Custom: ${_formatDateTime(willFireAt!)}';
        }
        return 'Custom time';
      default:
        return reminderType!;
    }
  }
  
  static String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = dt.difference(now);
    
    if (diff.isNegative) {
      return 'Past due';
    }
    
    if (diff.inMinutes < 60) {
      return 'In ${diff.inMinutes}m';
    } else if (diff.inHours < 24) {
      return 'In ${diff.inHours}h ${diff.inMinutes % 60}m';
    } else {
      return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
  }
  
  /// Get status color for this notification
  int get statusColor {
    if (willBeBlockedByQuietHours) {
      return 0xFFEF5350; // Red - will be blocked
    }
    if (isSpecial) {
      return 0xFFFFB74D; // Orange - special task
    }
    if (priority == 'High') {
      return 0xFFE53935; // Red - high priority
    }
    return 0xFF4CAF50; // Green - normal
  }
  
  /// Get a short status summary
  String get statusSummary {
    if (willBeBlockedByQuietHours) {
      return '🚫 Blocked';
    }
    if (isSpecial) {
      return '⭐ Special';
    }
    if (priority == 'High') {
      return '🔴 High';
    }
    return '✅ Ready';
  }
}
