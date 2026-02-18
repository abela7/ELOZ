import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/models/reminder.dart';
import '../../../core/notifications/models/notification_hub_modules.dart';
import '../../../core/notifications/services/notification_flow_trace.dart';
import '../../../core/notifications/services/notification_module_policy.dart';
import '../../../core/notifications/services/universal_notification_repository.dart';
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

  Future<void> scheduleHabitReminders(
    Habit habit, {
    String sourceFlow = 'habit_runtime',
  }) async {
    if (!habit.reminderEnabled) return;

    final policy = await NotificationModulePolicy.read(
      NotificationHubModuleIds.habit,
    );
    if (!policy.enabled) {
      await cancelHabitReminders(
        habit.id,
        sourceFlow: sourceFlow,
        reason: policy.reason,
      );
      return;
    }

    if (await _hasEnabledUniversalDefinitions(habit.id)) {
      await cancelHabitReminders(
        habit.id,
        sourceFlow: sourceFlow,
        reason: 'universal_definition_enabled',
      );
      return;
    }

    // Load settings ONCE — previously this was re-loaded inside every
    // scheduleHabitReminder call, adding ~14 SharedPreferences reads.
    final settings = await _loadSettings();
    if (!settings.notificationsEnabled) return;

    final reminders = _parseReminderDuration(habit.reminderDuration);
    if (reminders.isEmpty) return;

    final windowDays = settings.rollingWindowDays
        .clamp(
          HabitNotificationSettings.minRollingWindowDays,
          HabitNotificationSettings.maxRollingWindowDays,
        )
        .toInt();
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
            sourceFlow: sourceFlow,
          ),
        ),
      );
    }

    NotificationFlowTrace.log(
      event: 'legacy_schedule_result',
      sourceFlow: sourceFlow,
      moduleId: NotificationHubModuleIds.habit,
      entityId: habit.id,
      details: <String, dynamic>{
        'occurrenceCount': occurrences.length,
        'reminderVariants': reminders.length,
        'plannedSchedules': pairs.length,
      },
    );
  }

  Future<void> rescheduleHabitReminders(
    Habit habit, {
    String sourceFlow = 'habit_reschedule',
  }) async {
    await cancelHabitReminders(
      habit.id,
      sourceFlow: sourceFlow,
      reason: 'reschedule',
    );
    await scheduleHabitReminders(habit, sourceFlow: sourceFlow);
  }

  Future<void> cancelHabitReminders(
    String habitId, {
    String sourceFlow = 'habit_runtime',
    String reason = 'cancel',
  }) async {
    await _notificationService.cancelAllHabitReminders(
      habitId,
      sourceFlow: sourceFlow,
      reason: reason,
    );
    NotificationFlowTrace.log(
      event: 'legacy_cancel_result',
      sourceFlow: sourceFlow,
      moduleId: NotificationHubModuleIds.habit,
      entityId: habitId,
      reason: reason,
    );
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
    final lower = normalized.toLowerCase();
    if (lower == 'no reminder') return [];

    // Canonical + legacy "at start time" values.
    const atTimeValues = <String>{
      'at task time',
      'at habit time',
      'at time',
      'on time',
      'at_time',
      'at start time',
      'at the start time',
      'start time',
      'at start',
    };
    if (atTimeValues.contains(lower)) {
      return [Reminder.atTaskTime()];
    }

    // Canonical code values (used by some legacy/migrated settings).
    if (lower == '5_min') return [Reminder.fiveMinutesBefore()];
    if (lower == '10_min') {
      return [Reminder(type: 'before', value: 10, unit: 'minutes')];
    }
    if (lower == '15_min') return [Reminder.fifteenMinutesBefore()];
    if (lower == '30_min') return [Reminder.thirtyMinutesBefore()];
    if (lower == '1_hour') return [Reminder.oneHourBefore()];
    if (lower == '1_day') return [Reminder.oneDayBefore()];

    if (lower.contains('5 min before') || lower.contains('5 minutes before')) {
      return [Reminder.fiveMinutesBefore()];
    }
    if (lower.contains('10 min before') || lower.contains('10 minutes before')) {
      return [Reminder(type: 'before', value: 10, unit: 'minutes')];
    }
    if (lower.contains('15 min before') || lower.contains('15 minutes before')) {
      return [Reminder.fifteenMinutesBefore()];
    }
    if (lower.contains('30 min before') || lower.contains('30 minutes before')) {
      return [Reminder.thirtyMinutesBefore()];
    }
    if (lower.contains('1 hour before') || lower.contains('1 hr before')) {
      return [Reminder.oneHourBefore()];
    }
    if (lower.contains('1 day before')) {
      return [Reminder.oneDayBefore()];
    }
    if (normalized.startsWith('Custom:')) {
      return _parseCustomReminder(normalized);
    }

    // Safer fallback for unknown values: fire at habit time.
    // (5-min fallback can easily become "past time" and be dropped.)
    return [Reminder.atTaskTime()];
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

  Future<bool> _hasEnabledUniversalDefinitions(String habitId) async {
    final repo = UniversalNotificationRepository();
    final defs = await repo.getAll(
      moduleId: NotificationHubModuleIds.habit,
      entityId: habitId,
      enabledOnly: true,
    );
    return defs.isNotEmpty;
  }
}
