/// A named bundle of notification delivery behavior.
///
/// The hub ships 4 built-in types (`special`, `alarm`, `regular`, `silent`)
/// and mini apps can register custom ones via their adapter.
class HubNotificationType {
  /// Unique identifier, e.g. `'special'`, `'alarm'`, `'finance_payment_due'`.
  final String id;

  /// Human-readable name shown in settings UI.
  final String displayName;

  /// `null` for global built-in types, or a module ID for module-scoped types.
  final String? moduleId;

  /// Groups this type under a section within the module.
  ///
  /// E.g. `'bills'`, `'debts'`, `'budgets'` inside Finance.
  /// `null` means ungrouped / module-level.
  final String? sectionId;

  /// The default delivery configuration for this type.
  final HubDeliveryConfig defaultConfig;

  const HubNotificationType({
    required this.id,
    required this.displayName,
    this.moduleId,
    this.sectionId,
    required this.defaultConfig,
  });

  // ---------------------------------------------------------------------------
  // Built-in types
  // ---------------------------------------------------------------------------

  /// Critical alerts that bypass DND, silent mode, and quiet hours.
  /// Uses native AlarmService with full-screen intent.
  static const special = HubNotificationType(
    id: 'special',
    displayName: 'Special Alert',
    defaultConfig: HubDeliveryConfig(
      channelKey: 'urgent_reminders',
      audioStream: 'alarm',
      useAlarmMode: true,
      useFullScreenIntent: true,
      bypassDnd: true,
      bypassQuietHours: true,
      persistent: true,
      wakeScreen: true,
    ),
  );

  /// Important time-sensitive notifications that bypass DND but no
  /// full-screen popup.
  static const alarm = HubNotificationType(
    id: 'alarm',
    displayName: 'Alarm',
    defaultConfig: HubDeliveryConfig(
      channelKey: 'urgent_reminders',
      audioStream: 'alarm',
      useAlarmMode: true,
      useFullScreenIntent: false,
      bypassDnd: true,
      bypassQuietHours: false,
      persistent: false,
      wakeScreen: true,
    ),
  );

  /// Standard notification using the module's default channel.
  static const regular = HubNotificationType(
    id: 'regular',
    displayName: 'Regular',
    defaultConfig: HubDeliveryConfig(
      channelKey: '', // resolved at runtime to module default
      audioStream: 'notification',
      useAlarmMode: false,
      useFullScreenIntent: false,
      bypassDnd: false,
      bypassQuietHours: false,
      persistent: false,
      wakeScreen: false,
    ),
  );

  /// Low-priority silent notification with no sound or vibration.
  static const silent = HubNotificationType(
    id: 'silent',
    displayName: 'Silent',
    defaultConfig: HubDeliveryConfig(
      channelKey: 'silent_reminders',
      audioStream: 'notification',
      useAlarmMode: false,
      useFullScreenIntent: false,
      bypassDnd: false,
      bypassQuietHours: false,
      persistent: false,
      wakeScreen: false,
      soundKey: '', // empty = no sound
      vibrationPatternId: '', // empty = no vibration
    ),
  );

  /// All built-in types in priority order (highest first).
  static const List<HubNotificationType> builtInTypes = [
    special,
    alarm,
    regular,
    silent,
  ];

  /// Returns the built-in type for [id], or `null`.
  static HubNotificationType? builtInById(String id) {
    for (final t in builtInTypes) {
      if (t.id == id) return t;
    }
    return null;
  }
}

/// Concrete delivery configuration resolved from a [HubNotificationType].
class HubDeliveryConfig {
  /// Android notification channel key.
  /// Empty string means "resolve to module's default channel at runtime".
  final String channelKey;

  /// Audio stream: `'alarm'`, `'notification'`, `'ring'`, `'media'`.
  final String audioStream;

  /// Whether to use native `AlarmService` (AlarmManager) for delivery.
  final bool useAlarmMode;

  /// Whether to show a full-screen intent (alarm popup on lock screen).
  final bool useFullScreenIntent;

  /// Whether this notification bypasses Do Not Disturb.
  final bool bypassDnd;

  /// Whether this notification bypasses the hub's quiet hours.
  final bool bypassQuietHours;

  /// Whether the notification persists until explicitly dismissed.
  final bool persistent;

  /// Whether to wake the device screen on delivery.
  final bool wakeScreen;

  /// Sound key override. `null` = use module/global default.
  /// Empty string = no sound.
  final String? soundKey;

  /// Vibration pattern override. `null` = use module/global default.
  /// Empty string = no vibration.
  final String? vibrationPatternId;

  const HubDeliveryConfig({
    required this.channelKey,
    this.audioStream = 'notification',
    this.useAlarmMode = false,
    this.useFullScreenIntent = false,
    this.bypassDnd = false,
    this.bypassQuietHours = false,
    this.persistent = false,
    this.wakeScreen = false,
    this.soundKey,
    this.vibrationPatternId,
  });

  /// Creates a copy with selected fields overridden.
  HubDeliveryConfig copyWith({
    String? channelKey,
    String? audioStream,
    bool? useAlarmMode,
    bool? useFullScreenIntent,
    bool? bypassDnd,
    bool? bypassQuietHours,
    bool? persistent,
    bool? wakeScreen,
    String? soundKey,
    String? vibrationPatternId,
  }) {
    return HubDeliveryConfig(
      channelKey: channelKey ?? this.channelKey,
      audioStream: audioStream ?? this.audioStream,
      useAlarmMode: useAlarmMode ?? this.useAlarmMode,
      useFullScreenIntent: useFullScreenIntent ?? this.useFullScreenIntent,
      bypassDnd: bypassDnd ?? this.bypassDnd,
      bypassQuietHours: bypassQuietHours ?? this.bypassQuietHours,
      persistent: persistent ?? this.persistent,
      wakeScreen: wakeScreen ?? this.wakeScreen,
      soundKey: soundKey ?? this.soundKey,
      vibrationPatternId: vibrationPatternId ?? this.vibrationPatternId,
    );
  }
}

/// Priority levels for the notification type hierarchy.
///
/// Used by `maxAllowedType` clamping. Higher index = higher priority.
/// `special` (3) > `alarm` (2) > `regular` (1) > `silent` (0).
class HubNotificationTypeLevel {
  static const int silent = 0;
  static const int regular = 1;
  static const int alarm = 2;
  static const int special = 3;

  /// Map from type ID to its numeric level.
  static int levelOf(String typeId) {
    switch (typeId) {
      case 'special':
        return special;
      case 'alarm':
        return alarm;
      case 'regular':
        return regular;
      case 'silent':
        return silent;
      default:
        // Custom types inherit the level of their base config.
        return regular;
    }
  }

  /// Returns the type ID that a custom type should be clamped to, based on
  /// its delivery config.
  static int levelOfConfig(HubDeliveryConfig config) {
    if (config.useFullScreenIntent && config.useAlarmMode) return special;
    if (config.useAlarmMode || config.bypassDnd) return alarm;
    if (config.channelKey == 'silent_reminders') return silent;
    return regular;
  }

  /// Display name for a level.
  static String displayName(String typeId) {
    switch (typeId) {
      case 'special':
        return 'Special (Alarm + Full Screen)';
      case 'alarm':
        return 'Alarm (Bypass DND)';
      case 'regular':
        return 'Regular';
      case 'silent':
        return 'Silent';
      default:
        return typeId;
    }
  }

  /// All built-in type IDs in descending priority order.
  static const List<String> allIds = ['special', 'alarm', 'regular', 'silent'];
}
