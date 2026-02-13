import 'dart:convert';

const String habitNotificationSettingsKey = 'habit_notification_settings';

class HabitNotificationSettings {
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

  // Channel settings
  final bool habitRemindersEnabled;
  final bool urgentRemindersEnabled;
  final bool silentRemindersEnabled;

  // Urgency / channel selection
  final String defaultUrgency; // 'default', 'urgent', 'silent'

  // Sounds & audio
  final String defaultSound;
  final String habitRemindersSound;
  final String urgentRemindersSound;
  final String defaultVibrationPattern;
  final String defaultChannel;
  final String notificationAudioStream; // notification, alarm, ring, media

  // Special habit alerts
  final bool alwaysUseAlarmForSpecialHabits;
  final String specialHabitSound;
  final String specialHabitVibrationPattern;
  final bool specialHabitAlarmMode;
  final bool allowSpecialDuringQuietHours;

  // Quiet hours
  final bool quietHoursEnabled;
  final int quietHoursStart; // Minutes from midnight
  final int quietHoursEnd;   // Minutes from midnight
  final List<int> quietHoursDays; // 1-7 (Mon-Sun)

  // Behavior & display
  final bool showOnLockScreen;
  final bool wakeScreen;
  final bool persistentNotifications;
  final bool groupNotifications;
  final int notificationTimeout;

  // Notification templates
  final String habitTitleTemplate;
  final String habitBodyTemplate;
  final String specialHabitTitleTemplate;
  final String specialHabitBodyTemplate;

  // Default reminder behavior
  final String defaultHabitReminderTime;
  final int defaultSnoozeDuration;
  final List<int> snoozeOptions;
  final int maxSnoozeCount;
  final bool smartSnooze;
  final bool earlyMorningReminderEnabled;
  final int earlyMorningReminderHour;

  // Scheduling window
  final int rollingWindowDays;

  const HabitNotificationSettings({
    this.hasNotificationPermission = false,
    this.hasExactAlarmPermission = false,
    this.hasFullScreenIntentPermission = false,
    this.hasOverlayPermission = false,
    this.hasBatteryOptimizationExemption = false,
    this.notificationsEnabled = true,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.ledEnabled = true,
    this.habitRemindersEnabled = true,
    this.urgentRemindersEnabled = true,
    this.silentRemindersEnabled = false,
    this.defaultUrgency = 'default',
    this.defaultSound = 'default',
    this.habitRemindersSound = 'default',
    this.urgentRemindersSound = 'default',
    this.defaultVibrationPattern = 'default',
    this.defaultChannel = 'habit_reminders',
    this.notificationAudioStream = 'notification',
    this.alwaysUseAlarmForSpecialHabits = true,
    this.specialHabitSound = 'alarm',
    this.specialHabitVibrationPattern = 'default',
    this.specialHabitAlarmMode = true,
    this.allowSpecialDuringQuietHours = true,
    this.quietHoursEnabled = false,
    this.quietHoursStart = 1380, // 11:00 PM
    this.quietHoursEnd = 420, // 7:00 AM
    this.quietHoursDays = const [],
    this.showOnLockScreen = true,
    this.wakeScreen = true,
    this.persistentNotifications = false,
    this.groupNotifications = false,
    this.notificationTimeout = 0,
    this.habitTitleTemplate = '{title}',
    this.habitBodyTemplate = '{description}',
    this.specialHabitTitleTemplate = '⭐ {title}',
    this.specialHabitBodyTemplate = '',
    this.defaultHabitReminderTime = 'at_time',
    this.defaultSnoozeDuration = 10,
    this.snoozeOptions = const [5, 10, 15, 30],
    this.maxSnoozeCount = 3,
    this.smartSnooze = false,
    this.earlyMorningReminderEnabled = false,
    this.earlyMorningReminderHour = 7,
    this.rollingWindowDays = 14,
  });

  static const HabitNotificationSettings defaults = HabitNotificationSettings();

  HabitNotificationSettings copyWith({
    bool? hasNotificationPermission,
    bool? hasExactAlarmPermission,
    bool? hasFullScreenIntentPermission,
    bool? hasOverlayPermission,
    bool? hasBatteryOptimizationExemption,
    bool? notificationsEnabled,
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? ledEnabled,
    bool? habitRemindersEnabled,
    bool? urgentRemindersEnabled,
    bool? silentRemindersEnabled,
    String? defaultUrgency,
    String? defaultSound,
    String? habitRemindersSound,
    String? urgentRemindersSound,
    String? defaultVibrationPattern,
    String? defaultChannel,
    String? notificationAudioStream,
    bool? alwaysUseAlarmForSpecialHabits,
    String? specialHabitSound,
    String? specialHabitVibrationPattern,
    bool? specialHabitAlarmMode,
    bool? allowSpecialDuringQuietHours,
    bool? quietHoursEnabled,
    int? quietHoursStart,
    int? quietHoursEnd,
    List<int>? quietHoursDays,
    bool? showOnLockScreen,
    bool? wakeScreen,
    bool? persistentNotifications,
    bool? groupNotifications,
    int? notificationTimeout,
    String? habitTitleTemplate,
    String? habitBodyTemplate,
    String? specialHabitTitleTemplate,
    String? specialHabitBodyTemplate,
    String? defaultHabitReminderTime,
    int? defaultSnoozeDuration,
    List<int>? snoozeOptions,
    int? maxSnoozeCount,
    bool? smartSnooze,
    bool? earlyMorningReminderEnabled,
    int? earlyMorningReminderHour,
    int? rollingWindowDays,
  }) {
    return HabitNotificationSettings(
      hasNotificationPermission: hasNotificationPermission ?? this.hasNotificationPermission,
      hasExactAlarmPermission: hasExactAlarmPermission ?? this.hasExactAlarmPermission,
      hasFullScreenIntentPermission:
          hasFullScreenIntentPermission ?? this.hasFullScreenIntentPermission,
      hasOverlayPermission: hasOverlayPermission ?? this.hasOverlayPermission,
      hasBatteryOptimizationExemption:
          hasBatteryOptimizationExemption ?? this.hasBatteryOptimizationExemption,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      ledEnabled: ledEnabled ?? this.ledEnabled,
      habitRemindersEnabled: habitRemindersEnabled ?? this.habitRemindersEnabled,
      urgentRemindersEnabled: urgentRemindersEnabled ?? this.urgentRemindersEnabled,
      silentRemindersEnabled: silentRemindersEnabled ?? this.silentRemindersEnabled,
      defaultUrgency: defaultUrgency ?? this.defaultUrgency,
      defaultSound: defaultSound ?? this.defaultSound,
      habitRemindersSound: habitRemindersSound ?? this.habitRemindersSound,
      urgentRemindersSound: urgentRemindersSound ?? this.urgentRemindersSound,
      defaultVibrationPattern: defaultVibrationPattern ?? this.defaultVibrationPattern,
      defaultChannel: defaultChannel ?? this.defaultChannel,
      notificationAudioStream: notificationAudioStream ?? this.notificationAudioStream,
      alwaysUseAlarmForSpecialHabits:
          alwaysUseAlarmForSpecialHabits ?? this.alwaysUseAlarmForSpecialHabits,
      specialHabitSound: specialHabitSound ?? this.specialHabitSound,
      specialHabitVibrationPattern:
          specialHabitVibrationPattern ?? this.specialHabitVibrationPattern,
      specialHabitAlarmMode: specialHabitAlarmMode ?? this.specialHabitAlarmMode,
      allowSpecialDuringQuietHours:
          allowSpecialDuringQuietHours ?? this.allowSpecialDuringQuietHours,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      quietHoursDays: quietHoursDays ?? this.quietHoursDays,
      showOnLockScreen: showOnLockScreen ?? this.showOnLockScreen,
      wakeScreen: wakeScreen ?? this.wakeScreen,
      persistentNotifications: persistentNotifications ?? this.persistentNotifications,
      groupNotifications: groupNotifications ?? this.groupNotifications,
      notificationTimeout: notificationTimeout ?? this.notificationTimeout,
      habitTitleTemplate: habitTitleTemplate ?? this.habitTitleTemplate,
      habitBodyTemplate: habitBodyTemplate ?? this.habitBodyTemplate,
      specialHabitTitleTemplate: specialHabitTitleTemplate ?? this.specialHabitTitleTemplate,
      specialHabitBodyTemplate: specialHabitBodyTemplate ?? this.specialHabitBodyTemplate,
      defaultHabitReminderTime:
          defaultHabitReminderTime ?? this.defaultHabitReminderTime,
      defaultSnoozeDuration: defaultSnoozeDuration ?? this.defaultSnoozeDuration,
      snoozeOptions: snoozeOptions ?? this.snoozeOptions,
      maxSnoozeCount: maxSnoozeCount ?? this.maxSnoozeCount,
      smartSnooze: smartSnooze ?? this.smartSnooze,
      earlyMorningReminderEnabled:
          earlyMorningReminderEnabled ?? this.earlyMorningReminderEnabled,
      earlyMorningReminderHour: earlyMorningReminderHour ?? this.earlyMorningReminderHour,
      rollingWindowDays: rollingWindowDays ?? this.rollingWindowDays,
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
      'habitRemindersEnabled': habitRemindersEnabled,
      'urgentRemindersEnabled': urgentRemindersEnabled,
      'silentRemindersEnabled': silentRemindersEnabled,
      'defaultUrgency': defaultUrgency,
      'defaultSound': defaultSound,
      'habitRemindersSound': habitRemindersSound,
      'urgentRemindersSound': urgentRemindersSound,
      'defaultVibrationPattern': defaultVibrationPattern,
      'defaultChannel': defaultChannel,
      'notificationAudioStream': notificationAudioStream,
      'alwaysUseAlarmForSpecialHabits': alwaysUseAlarmForSpecialHabits,
      'specialHabitSound': specialHabitSound,
      'specialHabitVibrationPattern': specialHabitVibrationPattern,
      'specialHabitAlarmMode': specialHabitAlarmMode,
      'allowSpecialDuringQuietHours': allowSpecialDuringQuietHours,
      'quietHoursEnabled': quietHoursEnabled,
      'quietHoursStart': quietHoursStart,
      'quietHoursEnd': quietHoursEnd,
      'quietHoursDays': quietHoursDays,
      'showOnLockScreen': showOnLockScreen,
      'wakeScreen': wakeScreen,
      'persistentNotifications': persistentNotifications,
      'groupNotifications': groupNotifications,
      'notificationTimeout': notificationTimeout,
      'habitTitleTemplate': habitTitleTemplate,
      'habitBodyTemplate': habitBodyTemplate,
      'specialHabitTitleTemplate': specialHabitTitleTemplate,
      'specialHabitBodyTemplate': specialHabitBodyTemplate,
      'defaultHabitReminderTime': defaultHabitReminderTime,
      'defaultSnoozeDuration': defaultSnoozeDuration,
      'snoozeOptions': snoozeOptions,
      'maxSnoozeCount': maxSnoozeCount,
      'smartSnooze': smartSnooze,
      'earlyMorningReminderEnabled': earlyMorningReminderEnabled,
      'earlyMorningReminderHour': earlyMorningReminderHour,
      'rollingWindowDays': rollingWindowDays,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  factory HabitNotificationSettings.fromJson(Map<String, dynamic> json) {
    final urgency = _normalizeUrgency(json['defaultUrgency'] as String?);
    final audioStream = _normalizeAudioStream(
      json['notificationAudioStream'] as String? ?? json['streamOverride'] as String?,
    );
    final windowRaw =
        (json['rollingWindowDays'] as num?)?.toInt() ?? defaults.rollingWindowDays;
    final window = windowRaw < 1 ? defaults.rollingWindowDays : windowRaw;
    final snoozeOptions = (json['snoozeOptions'] as List<dynamic>?)
            ?.map((e) => (e as num).toInt())
            .toList() ??
        defaults.snoozeOptions;

    return HabitNotificationSettings(
      hasNotificationPermission: json['hasNotificationPermission'] as bool? ?? false,
      hasExactAlarmPermission: json['hasExactAlarmPermission'] as bool? ?? false,
      hasFullScreenIntentPermission: json['hasFullScreenIntentPermission'] as bool? ?? false,
      hasOverlayPermission: json['hasOverlayPermission'] as bool? ?? false,
      hasBatteryOptimizationExemption:
          json['hasBatteryOptimizationExemption'] as bool? ?? false,
      notificationsEnabled:
          json['notificationsEnabled'] as bool? ?? json['enabled'] as bool? ?? true,
      soundEnabled: json['soundEnabled'] as bool? ?? true,
      vibrationEnabled: json['vibrationEnabled'] as bool? ?? true,
      ledEnabled: json['ledEnabled'] as bool? ?? true,
      habitRemindersEnabled: json['habitRemindersEnabled'] as bool? ?? true,
      urgentRemindersEnabled: json['urgentRemindersEnabled'] as bool? ?? true,
      silentRemindersEnabled: json['silentRemindersEnabled'] as bool? ?? false,
      defaultUrgency: urgency,
      defaultSound: json['defaultSound'] as String? ?? defaults.defaultSound,
      habitRemindersSound: json['habitRemindersSound'] as String? ?? defaults.habitRemindersSound,
      urgentRemindersSound: json['urgentRemindersSound'] as String? ?? defaults.urgentRemindersSound,
      defaultVibrationPattern:
          json['defaultVibrationPattern'] as String? ?? defaults.defaultVibrationPattern,
      defaultChannel: _normalizeChannel(
            json['defaultChannel'] as String?,
          ) ??
          defaults.defaultChannel,
      notificationAudioStream: audioStream,
      alwaysUseAlarmForSpecialHabits:
          json['alwaysUseAlarmForSpecialHabits'] as bool? ?? defaults.alwaysUseAlarmForSpecialHabits,
      specialHabitSound: json['specialHabitSound'] as String? ?? defaults.specialHabitSound,
      specialHabitVibrationPattern: json['specialHabitVibrationPattern'] as String? ??
          defaults.specialHabitVibrationPattern,
      specialHabitAlarmMode:
          json['specialHabitAlarmMode'] as bool? ?? defaults.specialHabitAlarmMode,
      allowSpecialDuringQuietHours: json['allowSpecialDuringQuietHours'] as bool? ??
          defaults.allowSpecialDuringQuietHours,
      quietHoursEnabled: json['quietHoursEnabled'] as bool? ?? defaults.quietHoursEnabled,
      quietHoursStart: json['quietHoursStart'] as int? ?? defaults.quietHoursStart,
      quietHoursEnd: json['quietHoursEnd'] as int? ?? defaults.quietHoursEnd,
      quietHoursDays: (json['quietHoursDays'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          defaults.quietHoursDays,
      showOnLockScreen: json['showOnLockScreen'] as bool? ?? defaults.showOnLockScreen,
      wakeScreen: json['wakeScreen'] as bool? ?? defaults.wakeScreen,
      persistentNotifications:
          json['persistentNotifications'] as bool? ?? defaults.persistentNotifications,
      groupNotifications: json['groupNotifications'] as bool? ?? defaults.groupNotifications,
      notificationTimeout: json['notificationTimeout'] as int? ?? defaults.notificationTimeout,
      habitTitleTemplate: json['habitTitleTemplate'] as String? ?? defaults.habitTitleTemplate,
      habitBodyTemplate: json['habitBodyTemplate'] as String? ?? defaults.habitBodyTemplate,
      specialHabitTitleTemplate:
          json['specialHabitTitleTemplate'] as String? ?? defaults.specialHabitTitleTemplate,
      specialHabitBodyTemplate:
          json['specialHabitBodyTemplate'] as String? ?? defaults.specialHabitBodyTemplate,
      defaultHabitReminderTime:
          json['defaultHabitReminderTime'] as String? ?? defaults.defaultHabitReminderTime,
      defaultSnoozeDuration:
          json['defaultSnoozeDuration'] as int? ?? defaults.defaultSnoozeDuration,
      snoozeOptions: snoozeOptions,
      maxSnoozeCount: json['maxSnoozeCount'] as int? ?? defaults.maxSnoozeCount,
      smartSnooze: json['smartSnooze'] as bool? ?? defaults.smartSnooze,
      earlyMorningReminderEnabled:
          json['earlyMorningReminderEnabled'] as bool? ?? defaults.earlyMorningReminderEnabled,
      earlyMorningReminderHour:
          json['earlyMorningReminderHour'] as int? ?? defaults.earlyMorningReminderHour,
      rollingWindowDays: window,
    );
  }

  factory HabitNotificationSettings.fromJsonString(String jsonString) {
    try {
      final map = jsonDecode(jsonString) as Map<String, dynamic>;
      return HabitNotificationSettings.fromJson(map);
    } catch (_) {
      return defaults;
    }
  }

  bool isInQuietHours() => isInQuietHoursAt(DateTime.now());

  bool isInQuietHoursAt(DateTime time) {
    if (!quietHoursEnabled) return false;
    if (quietHoursDays.isNotEmpty && !quietHoursDays.contains(time.weekday)) {
      return false;
    }
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
      case 'alarm':
        return 'Alarm Volume';
      case 'ring':
        return 'Ringtone Volume';
      case 'media':
        return 'Media Volume';
      case 'notification':
      default:
        return 'Notification Volume';
    }
  }

  static String getSoundDisplayName(String sound) {
    if (sound == 'default') return 'Default';
    if (sound == 'alarm') return 'Alarm';
    if (sound == 'silent') return 'Silent';

    if (sound.startsWith('content://') || sound.startsWith('Content://')) {
      try {
        final uri = Uri.parse(sound);
        final title = uri.queryParameters['title'];
        if (title != null && title.isNotEmpty) {
          return title;
        }
        final pathSegments = uri.pathSegments;
        if (pathSegments.isNotEmpty) {
          final lastSegment = pathSegments.last;
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

    if (sound.startsWith('file://') || sound.contains('/')) {
      try {
        final uri = Uri.parse(sound);
        final fileName = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : sound;
        final dotIndex = fileName.lastIndexOf('.');
        return dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
      } catch (_) {
        return 'Custom Sound';
      }
    }

    return sound
        .replaceAll('_', ' ')
        .split(' ')
        .map((s) => s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : s)
        .join(' ');
  }

  static String getVibrationDisplayName(String pattern) {
    return pattern
        .replaceAll('_', ' ')
        .split(' ')
        .map((s) => s[0].toUpperCase() + s.substring(1))
        .join(' ');
  }

  static String getReminderTimeDisplayName(String time) {
    switch (time) {
      case 'at_time':
        return 'At habit time';
      case '5_min':
        return '5 minutes before';
      case '10_min':
        return '10 minutes before';
      case '15_min':
        return '15 minutes before';
      case '30_min':
        return '30 minutes before';
      case '1_hour':
        return '1 hour before';
      default:
        return time;
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
      case 'habit_reminders':
        return 'Habit Reminders';
      case 'habit_urgent_reminders':
        return 'Urgent Reminders';
      case 'habit_silent_reminders':
        return 'Silent Reminders';
      default:
        return channel;
    }
  }

  static const List<String> availableSounds = ['default', 'alarm', 'silent'];
  static const List<String> availableAudioStreams = ['notification', 'alarm', 'ring', 'media'];
  static const List<String> availableVibrationPatterns = ['default', 'short', 'long', 'staccato'];
  static const List<String> availableReminderTimes = [
    'at_time',
    '5_min',
    '10_min',
    '15_min',
    '30_min',
    '1_hour',
  ];
  static const List<int> availableSnoozeOptions = [5, 10, 15, 30];
  static const List<int> availableTimeoutOptions = [0, 5, 10, 30, 60];
  static const List<String> availableChannels = [
    'habit_reminders',
    'habit_urgent_reminders',
    'habit_silent_reminders',
  ];

  static String _normalizeUrgency(String? value) {
    switch (value) {
      case 'urgent':
      case 'silent':
      case 'default':
        return value!;
      default:
        return defaults.defaultUrgency;
    }
  }

  static String _normalizeAudioStream(String? value) {
    switch (value) {
      case 'notification':
      case 'alarm':
      case 'ring':
      case 'media':
        return value!;
      default:
        return defaults.notificationAudioStream;
    }
  }

  static String? _normalizeChannel(String? value) {
    switch (value) {
      case 'habit_reminders':
      case 'habit_urgent_reminders':
      case 'habit_silent_reminders':
        return value;
      case 'task_reminders':
        return 'habit_reminders';
      case 'urgent_reminders':
        return 'habit_urgent_reminders';
      case 'silent_reminders':
        return 'habit_silent_reminders';
      default:
        return null;
    }
  }
}
