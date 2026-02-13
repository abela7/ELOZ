/// Action button definition for hub notifications.
class HubNotificationAction {
  final String actionId;
  final String label;
  final bool showsUserInterface;
  final bool cancelNotification;

  const HubNotificationAction({
    required this.actionId,
    required this.label,
    this.showsUserInterface = false,
    this.cancelNotification = true,
  });
}

class NotificationHubScheduleRequest {
  final String moduleId;
  final String entityId;
  final String title;
  final String body;
  final DateTime scheduledAt;
  final String reminderType;
  final int reminderValue;
  final String reminderUnit;
  final int? notificationId;
  final String? channelKey;
  final String? soundKey;
  final int? iconCodePoint;
  final String? iconFontFamily;
  final String? iconFontPackage;
  final int? colorValue;
  final Map<String, String> extras;

  // ── Notification type (preferred way to configure delivery) ─────────────

  /// The notification type ID that determines delivery behavior.
  ///
  /// Built-in types: `'special'`, `'alarm'`, `'regular'`, `'silent'`.
  /// Mini apps can also use custom types registered via their adapter.
  ///
  /// When set, the hub resolves channel, sound, alarm mode, etc. from the
  /// type's [HubDeliveryConfig]. Individual flag overrides below still apply
  /// on top of the type's defaults.
  final String type;

  // ── Legacy fields (kept for backward compatibility) ─────────────────────
  // These are secondary to `type`. When `type` is set, the hub uses the
  // type's config first, then applies any non-null overrides below.

  /// Urgency tier: 'default', 'urgent', 'silent'.
  final String? urgency;

  /// Whether this is a "special" notification (legacy flag).
  final bool isSpecial;

  /// Override the audio stream: 'notification', 'alarm', 'ring', 'media'.
  final String? audioStream;

  /// Force alarm-mode (AlarmManager) for this notification.
  final bool? useAlarmMode;

  /// Use Android alarmClock schedule mode for better OEM reliability (nek12 Layer 3).
  /// Shows in status bar; use for critical reminders (e.g. wind-down).
  final bool? useAlarmClockScheduleMode;

  /// Per-notification quiet-hours privilege override.
  ///
  /// - `null` => use the notification type default (`HubDeliveryConfig`)
  /// - `true` => this notification may pass quiet hours
  /// - `false` => this notification cannot bypass quiet hours
  final bool? bypassQuietHours;

  /// Whether to use full-screen intent for this notification.
  final bool? useFullScreenIntent;

  /// Priority label: 'High', 'Medium', 'Low'.
  final String? priority;

  /// Optional vibration pattern id override.
  final String? vibrationPatternId;

  /// Action buttons displayed on the notification.
  final List<HubNotificationAction> actionButtons;

  const NotificationHubScheduleRequest({
    required this.moduleId,
    required this.entityId,
    required this.title,
    required this.body,
    required this.scheduledAt,
    this.reminderType = 'at_time',
    this.reminderValue = 0,
    this.reminderUnit = 'minutes',
    this.notificationId,
    this.channelKey,
    this.soundKey,
    this.iconCodePoint,
    this.iconFontFamily,
    this.iconFontPackage,
    this.colorValue,
    this.extras = const <String, String>{},
    // Notification type (new preferred API)
    this.type = 'regular',
    // Legacy fields (backward compat)
    this.urgency,
    this.isSpecial = false,
    this.audioStream,
    this.useAlarmMode,
    this.useAlarmClockScheduleMode,
    this.bypassQuietHours,
    this.useFullScreenIntent,
    this.priority,
    this.vibrationPatternId,
    this.actionButtons = const <HubNotificationAction>[],
  });
}
