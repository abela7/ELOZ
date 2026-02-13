import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/models/reminder.dart';
import '../../../core/services/notification_service.dart';
import '../data/models/habit.dart';
import '../data/models/habit_notification_settings.dart';
import '../data/repositories/habit_repository.dart';

class HabitReminderService {
  static final HabitReminderService _instance =
      HabitReminderService._internal();
  factory HabitReminderService() => _instance;
  HabitReminderService._internal();

  final NotificationService _notificationService = NotificationService();

  /// How many notifications to schedule concurrently.
  /// Too high can saturate the platform channel; 4 is a safe sweet-spot.
  static const int _parallelBatchSize = 4;

  Future<void> scheduleHabitReminders(Habit habit) async {
    if (!habit.reminderEnabled) return;

    // Load settings ONCE — previously this was re-loaded inside every
    // scheduleHabitReminder call, adding ~14 SharedPreferences reads.
    final settings = await _loadSettings();
    if (!settings.notificationsEnabled) return;

    final reminders = _parseReminderDuration(habit.reminderDuration);
    if (reminders.isEmpty) return;

    final windowDays = settings.rollingWindowDays < 1
        ? 1
        : settings.rollingWindowDays;
    final occurrences = _buildRollingWindowOccurrences(habit, windowDays);
    if (occurrences.isEmpty) return;

    final channelOverride = _effectiveChannelForHabit(
      settings,
      habit.isSpecial,
    );
    final audioStreamOverride = habit.isSpecial
        ? null
        : settings.notificationAudioStream;

    // Build all (date, reminder) pairs upfront so we can batch them.
    final pairs = <({DateTime date, Reminder reminder})>[];
    for (final date in occurrences) {
      for (final reminder in reminders) {
        pairs.add((date: date, reminder: reminder));
      }
    }

    // Schedule in parallel batches instead of one-by-one sequential awaits.
    for (var i = 0; i < pairs.length; i += _parallelBatchSize) {
      final batch = pairs.skip(i).take(_parallelBatchSize);
      await Future.wait(
        batch.map(
          (p) => _notificationService.scheduleHabitReminder(
            habit: habit,
            reminder: p.reminder,
            scheduledDate: p.date,
            channelKeyOverride: channelOverride,
            audioStreamOverride: audioStreamOverride,
          ),
        ),
      );
    }
  }

  Future<void> rescheduleHabitReminders(Habit habit) async {
    await cancelHabitReminders(habit.id);
    await scheduleHabitReminders(habit);
  }

  Future<void> cancelHabitReminders(String habitId) async {
    await _notificationService.cancelAllHabitReminders(habitId);
  }

  Future<void> cancelAllHabitReminders() async {
    final repository = HabitRepository();
    final habits = await repository.getAllHabits(includeArchived: true);
    for (final habit in habits) {
      await cancelHabitReminders(habit.id);
    }
  }

  /// Cached settings to avoid hitting SharedPreferences on every call.
  HabitNotificationSettings? _cachedSettings;
  DateTime? _settingsCachedAt;
  static const Duration _settingsCacheTtl = Duration(seconds: 30);

  Future<HabitNotificationSettings> _loadSettings() async {
    final now = DateTime.now();
    if (_cachedSettings != null &&
        _settingsCachedAt != null &&
        now.difference(_settingsCachedAt!) < _settingsCacheTtl) {
      return _cachedSettings!;
    }
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(habitNotificationSettingsKey);
    _cachedSettings = jsonString == null
        ? HabitNotificationSettings.defaults
        : HabitNotificationSettings.fromJsonString(jsonString);
    _settingsCachedAt = now;
    return _cachedSettings!;
  }

  /// Invalidate the settings cache (call when user changes notification settings).
  void invalidateSettingsCache() {
    _cachedSettings = null;
    _settingsCachedAt = null;
  }

  List<DateTime> _buildRollingWindowOccurrences(Habit habit, int windowDays) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(Duration(days: windowDays - 1));

    final occurrences = <DateTime>[];
    DateTime cursor = start;
    while (!cursor.isAfter(end)) {
      if (habit.isDueOn(cursor)) {
        occurrences.add(cursor);
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return occurrences;
  }

  String _effectiveChannelForHabit(
    HabitNotificationSettings settings,
    bool isSpecial,
  ) {
    final useSpecialAlertRouting =
        isSpecial &&
        (settings.alwaysUseAlarmForSpecialHabits ||
            settings.specialHabitAlarmMode);

    if (useSpecialAlertRouting) {
      if (settings.urgentRemindersEnabled) {
        return 'habit_urgent_reminders';
      }
      if (settings.habitRemindersEnabled) {
        return settings.defaultChannel;
      }
      return 'habit_silent_reminders';
    }

    switch (settings.defaultUrgency) {
      case 'urgent':
        if (settings.urgentRemindersEnabled) {
          return 'habit_urgent_reminders';
        }
        break;
      case 'silent':
        if (settings.silentRemindersEnabled) {
          return 'habit_silent_reminders';
        }
        break;
      case 'default':
      default:
        if (settings.habitRemindersEnabled) {
          return settings.defaultChannel;
        }
        break;
    }

    if (settings.habitRemindersEnabled) {
      return settings.defaultChannel;
    }
    if (settings.urgentRemindersEnabled) {
      return 'habit_urgent_reminders';
    }
    return 'habit_silent_reminders';
  }

  List<Reminder> _parseReminderDuration(String? reminderDuration) {
    if (reminderDuration == null || reminderDuration.isEmpty) return [];

    final normalized = reminderDuration.trim();
    if (normalized.toLowerCase() == 'no reminder') return [];

    if (normalized.contains('5 min before') ||
        normalized.contains('5 minutes before')) {
      return [Reminder.fiveMinutesBefore()];
    }
    if (normalized.contains('15 min before') ||
        normalized.contains('15 minutes before')) {
      return [Reminder.fifteenMinutesBefore()];
    }
    if (normalized.contains('30 min before') ||
        normalized.contains('30 minutes before')) {
      return [Reminder.thirtyMinutesBefore()];
    }
    if (normalized.contains('1 hour before') ||
        normalized.contains('1 hr before')) {
      return [Reminder.oneHourBefore()];
    }
    if (normalized.contains('1 day before')) {
      return [Reminder.oneDayBefore()];
    }
    if (normalized.toLowerCase() == 'at task time' ||
        normalized.toLowerCase() == 'at habit time' ||
        normalized.toLowerCase() == 'on time') {
      return [Reminder.atTaskTime()];
    }
    if (normalized.startsWith('Custom:')) {
      return _parseCustomReminder(normalized);
    }

    return [Reminder.fiveMinutesBefore()];
  }

  List<Reminder> _parseCustomReminder(String reminderString) {
    final reminders = <Reminder>[];
    final customPart = reminderString.substring(8).trim();
    final hourMatch = RegExp(r'(\d+)\s*h').firstMatch(customPart);
    final minuteMatch = RegExp(r'(\d+)\s*m').firstMatch(customPart);

    if (hourMatch != null || minuteMatch != null) {
      int totalMinutes = 0;
      if (hourMatch != null) {
        totalMinutes += int.parse(hourMatch.group(1)!) * 60;
      }
      if (minuteMatch != null) {
        totalMinutes += int.parse(minuteMatch.group(1)!);
      }
      if (totalMinutes > 0) {
        reminders.add(
          Reminder(type: 'before', value: totalMinutes, unit: 'minutes'),
        );
      }
    }

    return reminders.isNotEmpty ? reminders : [Reminder.fiveMinutesBefore()];
  }
}
