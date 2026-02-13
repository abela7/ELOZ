import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/local/hive/hive_service.dart';

/// State class for Task Settings
/// 
/// NOTE: defaultReminder is DEPRECATED - use NotificationSettings.defaultTaskReminderTime instead
class TaskSettings {
  @Deprecated('Use NotificationSettings.defaultTaskReminderTime instead')
  final String defaultReminder;
  final String defaultPriority;
  final String? defaultCategoryId;
  final bool showStreakOnDashboard;
  final bool enablePerformanceScoring;

  TaskSettings({
    this.defaultReminder = '15 min before',
    this.defaultPriority = 'Medium',
    this.defaultCategoryId,
    this.showStreakOnDashboard = true,
    this.enablePerformanceScoring = true,
  });

  TaskSettings copyWith({
    String? defaultReminder,
    String? defaultPriority,
    String? defaultCategoryId,
    bool? showStreakOnDashboard,
    bool? enablePerformanceScoring,
  }) {
    return TaskSettings(
      defaultReminder: defaultReminder ?? this.defaultReminder,
      defaultPriority: defaultPriority ?? this.defaultPriority,
      defaultCategoryId: defaultCategoryId ?? this.defaultCategoryId,
      showStreakOnDashboard: showStreakOnDashboard ?? this.showStreakOnDashboard,
      enablePerformanceScoring: enablePerformanceScoring ?? this.enablePerformanceScoring,
    );
  }
}

/// StateNotifier for Task Settings - Persistence via Hive
class TaskSettingsNotifier extends StateNotifier<TaskSettings> {
  TaskSettingsNotifier() : super(TaskSettings()) {
    _loadSettings();
  }

  static const String _keyReminder = 'task_default_reminder';
  static const String _keyPriority = 'task_default_priority';
  static const String _keyCategoryId = 'task_default_category_id';
  static const String _keyShowStreak = 'task_show_streak';
  static const String _keyEnableScoring = 'task_enable_scoring';

  void _loadSettings() {
    final box = HiveService.box;
    state = TaskSettings(
      defaultReminder: box.get(_keyReminder, defaultValue: '15 min before') as String,
      defaultPriority: box.get(_keyPriority, defaultValue: 'Medium') as String,
      defaultCategoryId: box.get(_keyCategoryId) as String?,
      showStreakOnDashboard: box.get(_keyShowStreak, defaultValue: true) as bool,
      enablePerformanceScoring: box.get(_keyEnableScoring, defaultValue: true) as bool,
    );
  }

  Future<void> setDefaultReminder(String value) async {
    await HiveService.box.put(_keyReminder, value);
    state = state.copyWith(defaultReminder: value);
  }

  Future<void> setDefaultPriority(String value) async {
    await HiveService.box.put(_keyPriority, value);
    state = state.copyWith(defaultPriority: value);
  }

  Future<void> setDefaultCategoryId(String? value) async {
    await HiveService.box.put(_keyCategoryId, value);
    state = state.copyWith(defaultCategoryId: value);
  }

  Future<void> setShowStreak(bool value) async {
    await HiveService.box.put(_keyShowStreak, value);
    state = state.copyWith(showStreakOnDashboard: value);
  }

  Future<void> setEnableScoring(bool value) async {
    await HiveService.box.put(_keyEnableScoring, value);
    state = state.copyWith(enablePerformanceScoring: value);
  }
}

/// Provider for Task Settings
final taskSettingsProvider = StateNotifierProvider<TaskSettingsNotifier, TaskSettings>((ref) {
  return TaskSettingsNotifier();
});
