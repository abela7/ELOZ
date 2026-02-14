import 'dart:convert';

/// Finance-only notification controls.
///
/// The Notification Hub still owns final delivery behavior (channels, sound,
/// vibration, alarm mode), but this model controls which Finance sections
/// can produce notifications and how far ahead they are planned.
class FinanceNotificationSettings {
  final bool notificationsEnabled;
  final bool syncOnStartup;
  final bool billsEnabled;
  final bool debtsEnabled;
  final bool lendingEnabled;
  final bool budgetsEnabled;
  final bool savingsGoalsEnabled;
  final bool recurringIncomeEnabled;
  final bool overdueAlertsUseAlarm;
  final bool dueTodayAlertsUseAlarm;
  final int planningWindowDays;
  final int defaultReminderHour;

  const FinanceNotificationSettings({
    this.notificationsEnabled = true,
    this.syncOnStartup = true,
    this.billsEnabled = true,
    this.debtsEnabled = true,
    this.lendingEnabled = true,
    this.budgetsEnabled = false,
    this.savingsGoalsEnabled = true,
    this.recurringIncomeEnabled = true,
    this.overdueAlertsUseAlarm = true,
    this.dueTodayAlertsUseAlarm = true,
    this.planningWindowDays = 180,
    this.defaultReminderHour = 9,
  });

  static const FinanceNotificationSettings defaults =
      FinanceNotificationSettings();

  FinanceNotificationSettings copyWith({
    bool? notificationsEnabled,
    bool? syncOnStartup,
    bool? billsEnabled,
    bool? debtsEnabled,
    bool? lendingEnabled,
    bool? budgetsEnabled,
    bool? savingsGoalsEnabled,
    bool? recurringIncomeEnabled,
    bool? overdueAlertsUseAlarm,
    bool? dueTodayAlertsUseAlarm,
    int? planningWindowDays,
    int? defaultReminderHour,
  }) {
    return FinanceNotificationSettings(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      syncOnStartup: syncOnStartup ?? this.syncOnStartup,
      billsEnabled: billsEnabled ?? this.billsEnabled,
      debtsEnabled: debtsEnabled ?? this.debtsEnabled,
      lendingEnabled: lendingEnabled ?? this.lendingEnabled,
      budgetsEnabled: budgetsEnabled ?? this.budgetsEnabled,
      savingsGoalsEnabled: savingsGoalsEnabled ?? this.savingsGoalsEnabled,
      recurringIncomeEnabled:
          recurringIncomeEnabled ?? this.recurringIncomeEnabled,
      overdueAlertsUseAlarm:
          overdueAlertsUseAlarm ?? this.overdueAlertsUseAlarm,
      dueTodayAlertsUseAlarm:
          dueTodayAlertsUseAlarm ?? this.dueTodayAlertsUseAlarm,
      planningWindowDays: _normalizePlanningWindow(
        planningWindowDays ?? this.planningWindowDays,
      ),
      defaultReminderHour: _normalizeReminderHour(
        defaultReminderHour ?? this.defaultReminderHour,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'notificationsEnabled': notificationsEnabled,
      'syncOnStartup': syncOnStartup,
      'billsEnabled': billsEnabled,
      'debtsEnabled': debtsEnabled,
      'lendingEnabled': lendingEnabled,
      'budgetsEnabled': budgetsEnabled,
      'savingsGoalsEnabled': savingsGoalsEnabled,
      'recurringIncomeEnabled': recurringIncomeEnabled,
      'overdueAlertsUseAlarm': overdueAlertsUseAlarm,
      'dueTodayAlertsUseAlarm': dueTodayAlertsUseAlarm,
      'planningWindowDays': planningWindowDays,
      'defaultReminderHour': defaultReminderHour,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  factory FinanceNotificationSettings.fromJson(Map<String, dynamic> json) {
    return FinanceNotificationSettings(
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      syncOnStartup: json['syncOnStartup'] as bool? ?? true,
      billsEnabled: json['billsEnabled'] as bool? ?? true,
      debtsEnabled: json['debtsEnabled'] as bool? ?? true,
      lendingEnabled: json['lendingEnabled'] as bool? ?? true,
      budgetsEnabled: json['budgetsEnabled'] as bool? ?? false,
      savingsGoalsEnabled: json['savingsGoalsEnabled'] as bool? ?? true,
      recurringIncomeEnabled: json['recurringIncomeEnabled'] as bool? ?? true,
      overdueAlertsUseAlarm: json['overdueAlertsUseAlarm'] as bool? ?? true,
      dueTodayAlertsUseAlarm: json['dueTodayAlertsUseAlarm'] as bool? ?? true,
      planningWindowDays: _normalizePlanningWindow(
        (json['planningWindowDays'] as num?)?.toInt() ?? 180,
      ),
      defaultReminderHour: _normalizeReminderHour(
        (json['defaultReminderHour'] as num?)?.toInt() ?? 9,
      ),
    );
  }

  factory FinanceNotificationSettings.fromJsonString(String jsonString) {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is Map<String, dynamic>) {
        return FinanceNotificationSettings.fromJson(decoded);
      }
      if (decoded is Map) {
        return FinanceNotificationSettings.fromJson(
          decoded.cast<String, dynamic>(),
        );
      }
    } catch (_) {}
    return defaults;
  }

  static int _normalizePlanningWindow(int value) {
    if (value < 7) return 7;
    if (value > 365) return 365;
    return value;
  }

  static int _normalizeReminderHour(int value) {
    if (value < 0) return 0;
    if (value > 23) return 23;
    return value;
  }
}
