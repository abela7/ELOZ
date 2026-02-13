import 'package:flutter/material.dart';
import 'dart:convert';

/// Comprehensive notification settings for the application.
class NotificationSettings {
  // Permission states
  final bool hasNotificationPermission;
  final bool hasExactAlarmPermission;
  final bool hasFullScreenIntentPermission;
  final bool hasOverlayPermission;
  final bool hasBatteryOptimizationExemption;

  // General settings
  final bool notificationsEnabled;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final bool ledEnabled;
  
  // Specific channel settings
  final bool taskRemindersEnabled;
  final bool urgentRemindersEnabled;
  final bool silentRemindersEnabled;
  
  // Sounds
  final String defaultSound;
  final String taskRemindersSound;
  final String urgentRemindersSound;
  final String defaultVibrationPattern;
  final String defaultChannel;
  final String notificationAudioStream; // notification, alarm, ring, media
  
  // Alarm Mode (Legacy settings required by other parts of the app)
  final bool alarmModeEnabled;
  final bool alarmModeForHighPriority;
  final bool bypassDoNotDisturb;

  // Special Task Alerts
  final bool alwaysUseAlarmForSpecialTasks;
  final String specialTaskSound;
  final String specialTaskVibrationPattern;
  final bool specialTaskAlarmMode;
  final bool allowUrgentDuringQuietHours;

  // Quiet Hours
  final bool quietHoursEnabled;
  final int quietHoursStart; // Minutes from midnight
  final int quietHoursEnd;   // Minutes from midnight
  final List<int> quietHoursDays; // 1-7 (Mon-Sun)

  // Behavior & Display
  final bool showOnLockScreen;
  final bool wakeScreen;
  final bool persistentNotifications;
  final bool showProgressInNotification;
  final bool showCategoryInNotification;
  final bool autoExpandNotifications;
  final bool groupNotifications;
  final int notificationTimeout;
  
  // Notification Templates
  final String taskTitleTemplate;
  final String taskBodyTemplate;
  final String specialTaskTitleTemplate;
  final String specialTaskBodyTemplate;

  // Automatic Reminders
  final String defaultTaskReminderTime;
  final bool autoReminderForHighPriority;
  final bool autoReminderForDueToday;
  final bool useCriticalChannelForHighPriority;
  final bool useCriticalChannelForSpecial;

  // Snooze Settings
  final int defaultSnoozeDuration;
  final List<int> snoozeOptions;
  final int maxSnoozeCount;
  final bool smartSnooze;

  // Early Morning Reminders
  final bool earlyMorningReminderEnabled;
  final int earlyMorningReminderHour;

  const NotificationSettings({
    this.hasNotificationPermission = false,
    this.hasExactAlarmPermission = false,
    this.hasFullScreenIntentPermission = false,
    this.hasOverlayPermission = false,
    this.hasBatteryOptimizationExemption = false,
    this.notificationsEnabled = true,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.ledEnabled = true,
    this.taskRemindersEnabled = true,
    this.urgentRemindersEnabled = true,
    this.silentRemindersEnabled = false,
    this.defaultSound = 'default',
    this.taskRemindersSound = 'default',
    // Default to using the same tone as "Notification Tone".
    // Users can explicitly switch this to "Alarm" if they want a different sound.
    this.urgentRemindersSound = 'default',
    this.defaultVibrationPattern = 'default',
    this.defaultChannel = 'task_reminders',
    this.notificationAudioStream = 'notification',
    this.alarmModeEnabled = false,
    this.alarmModeForHighPriority = false,
    this.bypassDoNotDisturb = false,
    this.alwaysUseAlarmForSpecialTasks = true,
    this.specialTaskSound = 'alarm',
    this.specialTaskVibrationPattern = 'default',
    this.specialTaskAlarmMode = true,
    this.allowUrgentDuringQuietHours = true,
    this.quietHoursEnabled = false,
    this.quietHoursStart = 1380, // 11:00 PM
    this.quietHoursEnd = 420,    // 7:00 AM
    this.quietHoursDays = const [],
    this.showOnLockScreen = true,
    this.wakeScreen = true,
    this.persistentNotifications = false,
    this.showProgressInNotification = true,
    this.showCategoryInNotification = true,
    this.autoExpandNotifications = true,
    this.groupNotifications = false,
    this.notificationTimeout = 0,
    this.taskTitleTemplate = '{title}',
    // Default regular-task template:
    // - Show description (instead of due time)
    // - If subtasks exist, show them as lines under the description
    this.taskBodyTemplate = '{description}\n{subtasks}',
    this.specialTaskTitleTemplate = '⭐ {title}',
    this.specialTaskBodyTemplate = '{category} • {due_time}',
    this.defaultTaskReminderTime = 'at_time',
    this.autoReminderForHighPriority = false,
    this.autoReminderForDueToday = false,
    this.useCriticalChannelForHighPriority = false,
    this.useCriticalChannelForSpecial = true,
    this.defaultSnoozeDuration = 10,
    this.snoozeOptions = const [5, 10, 15, 30],
    this.maxSnoozeCount = 3,
    this.smartSnooze = false,
    this.earlyMorningReminderEnabled = false,
    this.earlyMorningReminderHour = 7,
  });

  static const NotificationSettings defaults = NotificationSettings();

  factory NotificationSettings.fromJsonString(String jsonString) {
    try {
      final Map<String, dynamic> json = jsonDecode(jsonString);
      return NotificationSettings.fromJson(json);
    } catch (e) {
      return defaults;
    }
  }

  String toJsonString() => jsonEncode(toJson());

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      hasNotificationPermission: json['hasNotificationPermission'] as bool? ?? false,
      hasExactAlarmPermission: json['hasExactAlarmPermission'] as bool? ?? false,
      hasFullScreenIntentPermission: json['hasFullScreenIntentPermission'] as bool? ?? false,
      hasOverlayPermission: json['hasOverlayPermission'] as bool? ?? false,
      hasBatteryOptimizationExemption: json['hasBatteryOptimizationExemption'] as bool? ?? false,
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      soundEnabled: json['soundEnabled'] as bool? ?? true,
      vibrationEnabled: json['vibrationEnabled'] as bool? ?? true,
      ledEnabled: json['ledEnabled'] as bool? ?? true,
      taskRemindersEnabled: json['taskRemindersEnabled'] as bool? ?? true,
      urgentRemindersEnabled: json['urgentRemindersEnabled'] as bool? ?? true,
      silentRemindersEnabled: json['silentRemindersEnabled'] as bool? ?? false,
      defaultSound: json['defaultSound'] as String? ?? 'default',
      taskRemindersSound: json['taskRemindersSound'] as String? ?? 'default',
      urgentRemindersSound: json['urgentRemindersSound'] as String? ?? 'default',
      defaultVibrationPattern: json['defaultVibrationPattern'] as String? ?? 'default',
      defaultChannel: json['defaultChannel'] as String? ?? 'task_reminders',
      notificationAudioStream: json['notificationAudioStream'] as String? ?? 'notification',
      alarmModeEnabled: json['alarmModeEnabled'] as bool? ?? false,
      alarmModeForHighPriority: json['alarmModeForHighPriority'] as bool? ?? false,
      bypassDoNotDisturb: json['bypassDoNotDisturb'] as bool? ?? false,
      alwaysUseAlarmForSpecialTasks: json['alwaysUseAlarmForSpecialTasks'] as bool? ?? true,
      specialTaskSound: json['specialTaskSound'] as String? ?? 'alarm',
      specialTaskVibrationPattern: json['specialTaskVibrationPattern'] as String? ?? 'default',
      specialTaskAlarmMode: json['specialTaskAlarmMode'] as bool? ?? true,
      allowUrgentDuringQuietHours: json['allowUrgentDuringQuietHours'] as bool? ?? true,
      quietHoursEnabled: json['quietHoursEnabled'] as bool? ?? false,
      quietHoursStart: json['quietHoursStart'] as int? ?? 1380,
      quietHoursEnd: json['quietHoursEnd'] as int? ?? 420,
      quietHoursDays: (json['quietHoursDays'] as List<dynamic>?)?.map((e) => e as int).toList() ?? const [],
      showOnLockScreen: json['showOnLockScreen'] as bool? ?? true,
      wakeScreen: json['wakeScreen'] as bool? ?? true,
      persistentNotifications: json['persistentNotifications'] as bool? ?? false,
      showProgressInNotification: json['showProgressInNotification'] as bool? ?? true,
      showCategoryInNotification: json['showCategoryInNotification'] as bool? ?? true,
      autoExpandNotifications: json['autoExpandNotifications'] as bool? ?? true,
      groupNotifications: json['groupNotifications'] as bool? ?? false,
      notificationTimeout: json['notificationTimeout'] as int? ?? 0,
      taskTitleTemplate: json['taskTitleTemplate'] as String? ?? '{title}',
      taskBodyTemplate: json['taskBodyTemplate'] as String? ?? '{description}\n{subtasks}',
      specialTaskTitleTemplate: json['specialTaskTitleTemplate'] as String? ?? '⭐ {title}',
      specialTaskBodyTemplate: json['specialTaskBodyTemplate'] as String? ?? '{due_time}',
      defaultTaskReminderTime: json['defaultTaskReminderTime'] as String? ?? 'at_time',
      autoReminderForHighPriority: json['autoReminderForHighPriority'] as bool? ?? false,
      autoReminderForDueToday: json['autoReminderForDueToday'] as bool? ?? false,
      useCriticalChannelForHighPriority: json['useCriticalChannelForHighPriority'] as bool? ?? false,
      useCriticalChannelForSpecial: json['useCriticalChannelForSpecial'] as bool? ?? true,
      defaultSnoozeDuration: json['defaultSnoozeDuration'] as int? ?? 10,
      snoozeOptions: (json['snoozeOptions'] as List<dynamic>?)?.map((e) => e as int).toList() ?? const [5, 10, 15, 30],
      maxSnoozeCount: json['maxSnoozeCount'] as int? ?? 3,
      smartSnooze: json['smartSnooze'] as bool? ?? false,
      earlyMorningReminderEnabled: json['earlyMorningReminderEnabled'] as bool? ?? false,
      earlyMorningReminderHour: json['earlyMorningReminderHour'] as int? ?? 7,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hasNotificationPermission': hasNotificationPermission,
      'hasExactAlarmPermission': hasExactAlarmPermission,
      'hasFullScreenIntentPermission': hasFullScreenIntentPermission,
      'hasOverlayPermission': hasOverlayPermission,
      'hasBatteryOptimizationExemption': hasBatteryOptimizationExemption,
      'notificationsEnabled': notificationsEnabled,
      'soundEnabled': soundEnabled,
      'vibrationEnabled': vibrationEnabled,
      'ledEnabled': ledEnabled,
      'taskRemindersEnabled': taskRemindersEnabled,
      'urgentRemindersEnabled': urgentRemindersEnabled,
      'silentRemindersEnabled': silentRemindersEnabled,
      'defaultSound': defaultSound,
      'taskRemindersSound': taskRemindersSound,
      'urgentRemindersSound': urgentRemindersSound,
      'defaultVibrationPattern': defaultVibrationPattern,
      'defaultChannel': defaultChannel,
      'notificationAudioStream': notificationAudioStream,
      'alarmModeEnabled': alarmModeEnabled,
      'alarmModeForHighPriority': alarmModeForHighPriority,
      'bypassDoNotDisturb': bypassDoNotDisturb,
      'alwaysUseAlarmForSpecialTasks': alwaysUseAlarmForSpecialTasks,
      'specialTaskSound': specialTaskSound,
      'specialTaskVibrationPattern': specialTaskVibrationPattern,
      'specialTaskAlarmMode': specialTaskAlarmMode,
      'allowUrgentDuringQuietHours': allowUrgentDuringQuietHours,
      'quietHoursEnabled': quietHoursEnabled,
      'quietHoursStart': quietHoursStart,
      'quietHoursEnd': quietHoursEnd,
      'quietHoursDays': quietHoursDays,
      'showOnLockScreen': showOnLockScreen,
      'wakeScreen': wakeScreen,
      'persistentNotifications': persistentNotifications,
      'showProgressInNotification': showProgressInNotification,
      'showCategoryInNotification': showCategoryInNotification,
      'autoExpandNotifications': autoExpandNotifications,
      'groupNotifications': groupNotifications,
      'notificationTimeout': notificationTimeout,
      'taskTitleTemplate': taskTitleTemplate,
      'taskBodyTemplate': taskBodyTemplate,
      'specialTaskTitleTemplate': specialTaskTitleTemplate,
      'specialTaskBodyTemplate': specialTaskBodyTemplate,
      'defaultTaskReminderTime': defaultTaskReminderTime,
      'autoReminderForHighPriority': autoReminderForHighPriority,
      'autoReminderForDueToday': autoReminderForDueToday,
      'useCriticalChannelForHighPriority': useCriticalChannelForHighPriority,
      'useCriticalChannelForSpecial': useCriticalChannelForSpecial,
      'defaultSnoozeDuration': defaultSnoozeDuration,
      'snoozeOptions': snoozeOptions,
      'maxSnoozeCount': maxSnoozeCount,
      'smartSnooze': smartSnooze,
      'earlyMorningReminderEnabled': earlyMorningReminderEnabled,
      'earlyMorningReminderHour': earlyMorningReminderHour,
    };
  }

  NotificationSettings copyWith({
    bool? hasNotificationPermission,
    bool? hasExactAlarmPermission,
    bool? hasFullScreenIntentPermission,
    bool? hasOverlayPermission,
    bool? hasBatteryOptimizationExemption,
    bool? notificationsEnabled,
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? ledEnabled,
    bool? taskRemindersEnabled,
    bool? urgentRemindersEnabled,
    bool? silentRemindersEnabled,
    String? defaultSound,
    String? taskRemindersSound,
    String? urgentRemindersSound,
    String? defaultVibrationPattern,
    String? defaultChannel,
    String? notificationAudioStream,
    bool? alarmModeEnabled,
    bool? alarmModeForHighPriority,
    bool? bypassDoNotDisturb,
    bool? alwaysUseAlarmForSpecialTasks,
    String? specialTaskSound,
    String? specialTaskVibrationPattern,
    bool? specialTaskAlarmMode,
    bool? allowUrgentDuringQuietHours,
    bool? quietHoursEnabled,
    int? quietHoursStart,
    int? quietHoursEnd,
    List<int>? quietHoursDays,
    bool? showOnLockScreen,
    bool? wakeScreen,
    bool? persistentNotifications,
    bool? showProgressInNotification,
    bool? showCategoryInNotification,
    bool? autoExpandNotifications,
    bool? groupNotifications,
    int? notificationTimeout,
    String? taskTitleTemplate,
    String? taskBodyTemplate,
    String? specialTaskTitleTemplate,
    String? specialTaskBodyTemplate,
    String? defaultTaskReminderTime,
    bool? autoReminderForHighPriority,
    bool? autoReminderForDueToday,
    bool? useCriticalChannelForHighPriority,
    bool? useCriticalChannelForSpecial,
    int? defaultSnoozeDuration,
    List<int>? snoozeOptions,
    int? maxSnoozeCount,
    bool? smartSnooze,
    bool? earlyMorningReminderEnabled,
    int? earlyMorningReminderHour,
  }) {
    return NotificationSettings(
      hasNotificationPermission: hasNotificationPermission ?? this.hasNotificationPermission,
      hasExactAlarmPermission: hasExactAlarmPermission ?? this.hasExactAlarmPermission,
      hasFullScreenIntentPermission: hasFullScreenIntentPermission ?? this.hasFullScreenIntentPermission,
      hasOverlayPermission: hasOverlayPermission ?? this.hasOverlayPermission,
      hasBatteryOptimizationExemption: hasBatteryOptimizationExemption ?? this.hasBatteryOptimizationExemption,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      ledEnabled: ledEnabled ?? this.ledEnabled,
      taskRemindersEnabled: taskRemindersEnabled ?? this.taskRemindersEnabled,
      urgentRemindersEnabled: urgentRemindersEnabled ?? this.urgentRemindersEnabled,
      silentRemindersEnabled: silentRemindersEnabled ?? this.silentRemindersEnabled,
      defaultSound: defaultSound ?? this.defaultSound,
      taskRemindersSound: taskRemindersSound ?? this.taskRemindersSound,
      urgentRemindersSound: urgentRemindersSound ?? this.urgentRemindersSound,
      defaultVibrationPattern: defaultVibrationPattern ?? this.defaultVibrationPattern,
      defaultChannel: defaultChannel ?? this.defaultChannel,
      notificationAudioStream: notificationAudioStream ?? this.notificationAudioStream,
      alarmModeEnabled: alarmModeEnabled ?? this.alarmModeEnabled,
      alarmModeForHighPriority: alarmModeForHighPriority ?? this.alarmModeForHighPriority,
      bypassDoNotDisturb: bypassDoNotDisturb ?? this.bypassDoNotDisturb,
      alwaysUseAlarmForSpecialTasks: alwaysUseAlarmForSpecialTasks ?? this.alwaysUseAlarmForSpecialTasks,
      specialTaskSound: specialTaskSound ?? this.specialTaskSound,
      specialTaskVibrationPattern: specialTaskVibrationPattern ?? this.specialTaskVibrationPattern,
      specialTaskAlarmMode: specialTaskAlarmMode ?? this.specialTaskAlarmMode,
      allowUrgentDuringQuietHours: allowUrgentDuringQuietHours ?? this.allowUrgentDuringQuietHours,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      quietHoursDays: quietHoursDays ?? this.quietHoursDays,
      showOnLockScreen: showOnLockScreen ?? this.showOnLockScreen,
      wakeScreen: wakeScreen ?? this.wakeScreen,
      persistentNotifications: persistentNotifications ?? this.persistentNotifications,
      showProgressInNotification: showProgressInNotification ?? this.showProgressInNotification,
      showCategoryInNotification: showCategoryInNotification ?? this.showCategoryInNotification,
      autoExpandNotifications: autoExpandNotifications ?? this.autoExpandNotifications,
      groupNotifications: groupNotifications ?? this.groupNotifications,
      notificationTimeout: notificationTimeout ?? this.notificationTimeout,
      taskTitleTemplate: taskTitleTemplate ?? this.taskTitleTemplate,
      taskBodyTemplate: taskBodyTemplate ?? this.taskBodyTemplate,
      specialTaskTitleTemplate: specialTaskTitleTemplate ?? this.specialTaskTitleTemplate,
      specialTaskBodyTemplate: specialTaskBodyTemplate ?? this.specialTaskBodyTemplate,
      defaultTaskReminderTime: defaultTaskReminderTime ?? this.defaultTaskReminderTime,
      autoReminderForHighPriority: autoReminderForHighPriority ?? this.autoReminderForHighPriority,
      autoReminderForDueToday: autoReminderForDueToday ?? this.autoReminderForDueToday,
      useCriticalChannelForHighPriority: useCriticalChannelForHighPriority ?? this.useCriticalChannelForHighPriority,
      useCriticalChannelForSpecial: useCriticalChannelForSpecial ?? this.useCriticalChannelForSpecial,
      defaultSnoozeDuration: defaultSnoozeDuration ?? this.defaultSnoozeDuration,
      snoozeOptions: snoozeOptions ?? this.snoozeOptions,
      maxSnoozeCount: maxSnoozeCount ?? this.maxSnoozeCount,
      smartSnooze: smartSnooze ?? this.smartSnooze,
      earlyMorningReminderEnabled: earlyMorningReminderEnabled ?? this.earlyMorningReminderEnabled,
      earlyMorningReminderHour: earlyMorningReminderHour ?? this.earlyMorningReminderHour,
    );
  }

  bool isInQuietHours() => isInQuietHoursAt(DateTime.now());

  bool isInQuietHoursAt(DateTime time) {
    if (!quietHoursEnabled) return false;
    if (quietHoursDays.isNotEmpty && !quietHoursDays.contains(time.weekday)) return false;
    final currentMinutes = time.hour * 60 + time.minute;
    if (quietHoursStart > quietHoursEnd) {
      return currentMinutes >= quietHoursStart || currentMinutes < quietHoursEnd;
    }
    return currentMinutes >= quietHoursStart && currentMinutes < quietHoursEnd;
  }

  static String formatMinutesToTime(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    final period = hours >= 12 ? 'PM' : 'AM';
    final displayHours = hours == 0 ? 12 : (hours > 12 ? hours - 12 : hours);
    return '$displayHours:${mins.toString().padLeft(2, '0')} $period';
  }

  static String formatHourToTime(int hour) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$displayHour:00 $period';
  }

  static String getWeekdayName(int weekday) {
    const days = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[weekday];
  }

  static String getWeekdayShortName(int weekday) {
    const days = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday];
  }

  static String getAudioStreamDisplayName(String stream) {
    switch (stream) {
      case 'alarm': return 'Alarm Volume';
      case 'ring': return 'Ringtone Volume';
      case 'media': return 'Media Volume';
      case 'notification':
      default: return 'Notification Volume';
    }
  }

  static String getSoundDisplayName(String sound) {
    if (sound == 'default') return 'Default';
    if (sound == 'alarm') return 'Alarm';
    if (sound == 'silent') return 'Silent';
    
    // Handle content URIs from system sound picker
    // e.g., content://media/internal/audio/media/39?title=Glitter&canonical=1
    if (sound.startsWith('content://') || sound.startsWith('Content://')) {
      try {
        final uri = Uri.parse(sound);
        // Try to get title from query parameters
        final title = uri.queryParameters['title'];
        if (title != null && title.isNotEmpty) {
          return title;
        }
        // Fallback: try to get the last path segment as name
        final pathSegments = uri.pathSegments;
        if (pathSegments.isNotEmpty) {
          final lastSegment = pathSegments.last;
          // If it's just a number (media ID), show generic name
          if (int.tryParse(lastSegment) != null) {
            return 'Custom Sound';
          }
          return lastSegment;
        }
        return 'Custom Sound';
      } catch (_) {
        return 'Custom Sound';
      }
    }
    
    // Handle file:// paths
    if (sound.startsWith('file://') || sound.contains('/')) {
      try {
        final uri = Uri.parse(sound);
        final fileName = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : sound;
        // Remove extension if present
        final dotIndex = fileName.lastIndexOf('.');
        return dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
      } catch (_) {
        return 'Custom Sound';
      }
    }
    
    return sound.replaceAll('_', ' ').split(' ').map((s) => s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : s).join(' ');
  }

  static String getVibrationDisplayName(String pattern) {
    return pattern.replaceAll('_', ' ').split(' ').map((s) => s[0].toUpperCase() + s.substring(1)).join(' ');
  }

  static String getReminderTimeDisplayName(String time) {
    switch (time) {
      case 'at_time': return 'At time of event';
      case '5_min': return '5 minutes before';
      case '10_min': return '10 minutes before';
      case '15_min': return '15 minutes before';
      case '30_min': return '30 minutes before';
      case '1_hour': return '1 hour before';
      default: return time;
    }
  }

  static String getSnoozeDurationDisplayName(int minutes) {
    return '$minutes minutes';
  }

  static String getTimeoutDisplayName(int seconds) {
    if (seconds == 0) return 'Never';
    return '$seconds seconds';
  }

  static String getChannelDisplayName(String channel) {
    switch (channel) {
      case 'task_reminders': return 'Task Reminders';
      case 'urgent_reminders': return 'Urgent Reminders';
      case 'silent_reminders': return 'Silent Reminders';
      case 'habit_reminders': return 'Habit Reminders';
      case 'habit_urgent_reminders': return 'Habit Urgent Reminders';
      case 'habit_silent_reminders': return 'Habit Silent Reminders';
      default: return channel;
    }
  }

  static const List<String> availableSounds = ['default', 'alarm', 'silent'];
  static const List<String> availableAudioStreams = ['notification', 'alarm', 'ring', 'media'];
  static const List<String> availableVibrationPatterns = ['default', 'short', 'long', 'staccato'];
  static const List<String> availableReminderTimes = ['at_time', '5_min', '10_min', '15_min', '30_min', '1_hour'];
  static const List<int> availableSnoozeOptions = [5, 10, 15, 30];
  static const List<int> availableTimeoutOptions = [0, 5, 10, 30, 60];
  static const List<String> availableChannels = ['task_reminders', 'urgent_reminders', 'silent_reminders'];
}
