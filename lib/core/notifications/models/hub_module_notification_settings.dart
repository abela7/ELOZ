import 'dart:convert';

import '../../models/notification_settings.dart';

/// Optional delivery override for a specific notification type.
///
/// Any null field means "use the type default".
class HubTypeDeliveryOverride {
  final String? channelKey;
  final String? soundKey;
  final String? audioStream;
  final String? vibrationPatternId;
  final bool? useAlarmMode;
  final bool? useFullScreenIntent;
  final bool? bypassQuietHours;

  const HubTypeDeliveryOverride({
    this.channelKey,
    this.soundKey,
    this.audioStream,
    this.vibrationPatternId,
    this.useAlarmMode,
    this.useFullScreenIntent,
    this.bypassQuietHours,
  });

  static const HubTypeDeliveryOverride empty = HubTypeDeliveryOverride();

  bool get hasOverrides =>
      channelKey != null ||
      soundKey != null ||
      audioStream != null ||
      vibrationPatternId != null ||
      useAlarmMode != null ||
      useFullScreenIntent != null ||
      bypassQuietHours != null;

  HubTypeDeliveryOverride copyWith({
    String? channelKey,
    String? soundKey,
    String? audioStream,
    String? vibrationPatternId,
    bool? useAlarmMode,
    bool? useFullScreenIntent,
    bool? bypassQuietHours,
  }) {
    return HubTypeDeliveryOverride(
      channelKey: channelKey ?? this.channelKey,
      soundKey: soundKey ?? this.soundKey,
      audioStream: audioStream ?? this.audioStream,
      vibrationPatternId: vibrationPatternId ?? this.vibrationPatternId,
      useAlarmMode: useAlarmMode ?? this.useAlarmMode,
      useFullScreenIntent: useFullScreenIntent ?? this.useFullScreenIntent,
      bypassQuietHours: bypassQuietHours ?? this.bypassQuietHours,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (channelKey != null) map['channelKey'] = channelKey;
    if (soundKey != null) map['soundKey'] = soundKey;
    if (audioStream != null) map['audioStream'] = audioStream;
    if (vibrationPatternId != null) {
      map['vibrationPatternId'] = vibrationPatternId;
    }
    if (useAlarmMode != null) map['useAlarmMode'] = useAlarmMode;
    if (useFullScreenIntent != null) {
      map['useFullScreenIntent'] = useFullScreenIntent;
    }
    if (bypassQuietHours != null) {
      map['bypassQuietHours'] = bypassQuietHours;
    }
    return map;
  }

  factory HubTypeDeliveryOverride.fromJson(Map<String, dynamic> json) {
    return HubTypeDeliveryOverride(
      channelKey: json['channelKey'] as String?,
      soundKey: json['soundKey'] as String?,
      audioStream: json['audioStream'] as String?,
      vibrationPatternId: json['vibrationPatternId'] as String?,
      useAlarmMode: json['useAlarmMode'] as bool?,
      useFullScreenIntent: json['useFullScreenIntent'] as bool?,
      bypassQuietHours: json['bypassQuietHours'] as bool?,
    );
  }
}

/// Lightweight per-module notification settings.
///
/// Every field is nullable. A null value means "use the global default
/// from [NotificationSettings]". Mini apps store only their overrides.
class HubModuleNotificationSettings {
  // General
  final bool? notificationsEnabled;

  // Channel / urgency
  final String? defaultUrgency; // 'default', 'urgent', 'silent'
  final String? defaultChannel; // channel key override
  final String? audioStream; // 'notification', 'alarm', 'ring', 'media'

  // Sound / vibration
  final String? defaultSound;
  final String? defaultVibrationPattern;

  // Special / alarm mode
  final bool? alwaysUseAlarmMode;
  final String? specialSound;
  final String? specialVibrationPattern;
  final bool? useFullScreenIntent;

  // Quiet hours
  final bool? allowDuringQuietHours;

  // Templates
  final String? titleTemplate;
  final String? bodyTemplate;
  final String? specialTitleTemplate;
  final String? specialBodyTemplate;

  // Snooze
  final int? defaultSnoozeDuration;
  final int? maxSnoozeCount;
  final List<int>? snoozeOptions;
  final bool? smartSnooze;

  // Display
  final bool? showOnLockScreen;
  final bool? wakeScreen;
  final bool? persistentNotifications;

  // Type clamping
  /// Maximum notification type level allowed for this module.
  ///
  /// `null` means no limit (all types allowed, same as `'special'`).
  /// Possible values: `'special'`, `'alarm'`, `'regular'`, `'silent'`.
  final String? maxAllowedType;

  /// Per-type delivery overrides keyed by notification type id.
  final Map<String, HubTypeDeliveryOverride>? typeOverrides;

  const HubModuleNotificationSettings({
    this.notificationsEnabled,
    this.defaultUrgency,
    this.defaultChannel,
    this.audioStream,
    this.defaultSound,
    this.defaultVibrationPattern,
    this.alwaysUseAlarmMode,
    this.specialSound,
    this.specialVibrationPattern,
    this.useFullScreenIntent,
    this.allowDuringQuietHours,
    this.titleTemplate,
    this.bodyTemplate,
    this.specialTitleTemplate,
    this.specialBodyTemplate,
    this.defaultSnoozeDuration,
    this.maxSnoozeCount,
    this.snoozeOptions,
    this.smartSnooze,
    this.showOnLockScreen,
    this.wakeScreen,
    this.persistentNotifications,
    this.maxAllowedType,
    this.typeOverrides,
  });

  static const HubModuleNotificationSettings empty =
      HubModuleNotificationSettings();

  bool get hasOverrides =>
      notificationsEnabled != null ||
      defaultUrgency != null ||
      defaultChannel != null ||
      audioStream != null ||
      defaultSound != null ||
      defaultVibrationPattern != null ||
      alwaysUseAlarmMode != null ||
      specialSound != null ||
      specialVibrationPattern != null ||
      useFullScreenIntent != null ||
      allowDuringQuietHours != null ||
      titleTemplate != null ||
      bodyTemplate != null ||
      specialTitleTemplate != null ||
      specialBodyTemplate != null ||
      defaultSnoozeDuration != null ||
      maxSnoozeCount != null ||
      snoozeOptions != null ||
      smartSnooze != null ||
      showOnLockScreen != null ||
      wakeScreen != null ||
      persistentNotifications != null ||
      maxAllowedType != null ||
      (typeOverrides != null && typeOverrides!.isNotEmpty);

  HubTypeDeliveryOverride overrideForType(String typeId) {
    return typeOverrides?[typeId] ?? HubTypeDeliveryOverride.empty;
  }

  HubModuleNotificationSettings withTypeOverride(
    String typeId,
    HubTypeDeliveryOverride? override,
  ) {
    final next = <String, HubTypeDeliveryOverride>{
      if (typeOverrides != null) ...typeOverrides!,
    };

    if (override == null || !override.hasOverrides) {
      next.remove(typeId);
    } else {
      next[typeId] = override;
    }

    return copyWith(
      typeOverrides: next.isEmpty ? null : next,
      clearTypeOverrides: next.isEmpty,
    );
  }

  // ---------------------------------------------------------------------------
  // Merge with global
  // ---------------------------------------------------------------------------

  /// Returns a fully-resolved [NotificationSettings] by layering this
  /// module's overrides on top of [global].
  NotificationSettings mergeWithGlobal(NotificationSettings global) {
    return global.copyWith(
      notificationsEnabled: notificationsEnabled ?? global.notificationsEnabled,
      defaultSound: defaultSound ?? global.defaultSound,
      defaultVibrationPattern:
          defaultVibrationPattern ?? global.defaultVibrationPattern,
      defaultChannel: defaultChannel ?? global.defaultChannel,
      notificationAudioStream: audioStream ?? global.notificationAudioStream,
      alwaysUseAlarmForSpecialTasks:
          alwaysUseAlarmMode ?? global.alwaysUseAlarmForSpecialTasks,
      specialTaskSound: specialSound ?? global.specialTaskSound,
      specialTaskVibrationPattern:
          specialVibrationPattern ?? global.specialTaskVibrationPattern,
      specialTaskAlarmMode:
          alwaysUseAlarmMode ?? global.specialTaskAlarmMode,
      allowUrgentDuringQuietHours:
          allowDuringQuietHours ?? global.allowUrgentDuringQuietHours,
      showOnLockScreen: showOnLockScreen ?? global.showOnLockScreen,
      wakeScreen: wakeScreen ?? global.wakeScreen,
      persistentNotifications:
          persistentNotifications ?? global.persistentNotifications,
      defaultSnoozeDuration:
          defaultSnoozeDuration ?? global.defaultSnoozeDuration,
      maxSnoozeCount: maxSnoozeCount ?? global.maxSnoozeCount,
      snoozeOptions: snoozeOptions ?? global.snoozeOptions,
      smartSnooze: smartSnooze ?? global.smartSnooze,
      taskTitleTemplate: titleTemplate ?? global.taskTitleTemplate,
      taskBodyTemplate: bodyTemplate ?? global.taskBodyTemplate,
      specialTaskTitleTemplate:
          specialTitleTemplate ?? global.specialTaskTitleTemplate,
      specialTaskBodyTemplate:
          specialBodyTemplate ?? global.specialTaskBodyTemplate,
    );
  }

  /// Resolves the effective channel key for a given urgency level.
  String resolveChannelKey({
    String? requestUrgency,
    String? requestChannelKey,
  }) {
    // Explicit channel in the request wins.
    if (requestChannelKey != null && requestChannelKey.isNotEmpty) {
      return requestChannelKey;
    }

    final urgency = requestUrgency ?? defaultUrgency ?? 'default';
    switch (urgency) {
      case 'urgent':
        return 'urgent_reminders';
      case 'silent':
        return 'silent_reminders';
      default:
        return defaultChannel ?? 'task_reminders';
    }
  }

  // ---------------------------------------------------------------------------
  // copyWith
  // ---------------------------------------------------------------------------

  HubModuleNotificationSettings copyWith({
    bool? notificationsEnabled,
    String? defaultUrgency,
    String? defaultChannel,
    String? audioStream,
    String? defaultSound,
    String? defaultVibrationPattern,
    bool? alwaysUseAlarmMode,
    String? specialSound,
    String? specialVibrationPattern,
    bool? useFullScreenIntent,
    bool? allowDuringQuietHours,
    String? titleTemplate,
    String? bodyTemplate,
    String? specialTitleTemplate,
    String? specialBodyTemplate,
    int? defaultSnoozeDuration,
    int? maxSnoozeCount,
    List<int>? snoozeOptions,
    bool? smartSnooze,
    bool? showOnLockScreen,
    bool? wakeScreen,
    bool? persistentNotifications,
    String? maxAllowedType,
    Map<String, HubTypeDeliveryOverride>? typeOverrides,
    bool clearTypeOverrides = false,
  }) {
    return HubModuleNotificationSettings(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      defaultUrgency: defaultUrgency ?? this.defaultUrgency,
      defaultChannel: defaultChannel ?? this.defaultChannel,
      audioStream: audioStream ?? this.audioStream,
      defaultSound: defaultSound ?? this.defaultSound,
      defaultVibrationPattern:
          defaultVibrationPattern ?? this.defaultVibrationPattern,
      alwaysUseAlarmMode: alwaysUseAlarmMode ?? this.alwaysUseAlarmMode,
      specialSound: specialSound ?? this.specialSound,
      specialVibrationPattern:
          specialVibrationPattern ?? this.specialVibrationPattern,
      useFullScreenIntent: useFullScreenIntent ?? this.useFullScreenIntent,
      allowDuringQuietHours:
          allowDuringQuietHours ?? this.allowDuringQuietHours,
      titleTemplate: titleTemplate ?? this.titleTemplate,
      bodyTemplate: bodyTemplate ?? this.bodyTemplate,
      specialTitleTemplate: specialTitleTemplate ?? this.specialTitleTemplate,
      specialBodyTemplate: specialBodyTemplate ?? this.specialBodyTemplate,
      defaultSnoozeDuration:
          defaultSnoozeDuration ?? this.defaultSnoozeDuration,
      maxSnoozeCount: maxSnoozeCount ?? this.maxSnoozeCount,
      snoozeOptions: snoozeOptions ?? this.snoozeOptions,
      smartSnooze: smartSnooze ?? this.smartSnooze,
      showOnLockScreen: showOnLockScreen ?? this.showOnLockScreen,
      wakeScreen: wakeScreen ?? this.wakeScreen,
      persistentNotifications:
          persistentNotifications ?? this.persistentNotifications,
      maxAllowedType: maxAllowedType ?? this.maxAllowedType,
      typeOverrides: clearTypeOverrides
          ? null
          : (typeOverrides ?? this.typeOverrides),
    );
  }

  /// Returns a copy where only null fields are replaced with [other]'s values.
  HubModuleNotificationSettings mergeFrom(
    HubModuleNotificationSettings other,
  ) {
    return HubModuleNotificationSettings(
      notificationsEnabled: notificationsEnabled ?? other.notificationsEnabled,
      defaultUrgency: defaultUrgency ?? other.defaultUrgency,
      defaultChannel: defaultChannel ?? other.defaultChannel,
      audioStream: audioStream ?? other.audioStream,
      defaultSound: defaultSound ?? other.defaultSound,
      defaultVibrationPattern:
          defaultVibrationPattern ?? other.defaultVibrationPattern,
      alwaysUseAlarmMode: alwaysUseAlarmMode ?? other.alwaysUseAlarmMode,
      specialSound: specialSound ?? other.specialSound,
      specialVibrationPattern:
          specialVibrationPattern ?? other.specialVibrationPattern,
      useFullScreenIntent: useFullScreenIntent ?? other.useFullScreenIntent,
      allowDuringQuietHours:
          allowDuringQuietHours ?? other.allowDuringQuietHours,
      titleTemplate: titleTemplate ?? other.titleTemplate,
      bodyTemplate: bodyTemplate ?? other.bodyTemplate,
      specialTitleTemplate: specialTitleTemplate ?? other.specialTitleTemplate,
      specialBodyTemplate: specialBodyTemplate ?? other.specialBodyTemplate,
      defaultSnoozeDuration:
          defaultSnoozeDuration ?? other.defaultSnoozeDuration,
      maxSnoozeCount: maxSnoozeCount ?? other.maxSnoozeCount,
      snoozeOptions: snoozeOptions ?? other.snoozeOptions,
      smartSnooze: smartSnooze ?? other.smartSnooze,
      showOnLockScreen: showOnLockScreen ?? other.showOnLockScreen,
      wakeScreen: wakeScreen ?? other.wakeScreen,
      persistentNotifications:
          persistentNotifications ?? other.persistentNotifications,
      maxAllowedType: maxAllowedType ?? other.maxAllowedType,
      typeOverrides: typeOverrides ?? other.typeOverrides,
    );
  }

  // ---------------------------------------------------------------------------
  // JSON
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (notificationsEnabled != null) {
      map['notificationsEnabled'] = notificationsEnabled;
    }
    if (defaultUrgency != null) map['defaultUrgency'] = defaultUrgency;
    if (defaultChannel != null) map['defaultChannel'] = defaultChannel;
    if (audioStream != null) map['audioStream'] = audioStream;
    if (defaultSound != null) map['defaultSound'] = defaultSound;
    if (defaultVibrationPattern != null) {
      map['defaultVibrationPattern'] = defaultVibrationPattern;
    }
    if (alwaysUseAlarmMode != null) {
      map['alwaysUseAlarmMode'] = alwaysUseAlarmMode;
    }
    if (specialSound != null) map['specialSound'] = specialSound;
    if (specialVibrationPattern != null) {
      map['specialVibrationPattern'] = specialVibrationPattern;
    }
    if (useFullScreenIntent != null) {
      map['useFullScreenIntent'] = useFullScreenIntent;
    }
    if (allowDuringQuietHours != null) {
      map['allowDuringQuietHours'] = allowDuringQuietHours;
    }
    if (titleTemplate != null) map['titleTemplate'] = titleTemplate;
    if (bodyTemplate != null) map['bodyTemplate'] = bodyTemplate;
    if (specialTitleTemplate != null) {
      map['specialTitleTemplate'] = specialTitleTemplate;
    }
    if (specialBodyTemplate != null) {
      map['specialBodyTemplate'] = specialBodyTemplate;
    }
    if (defaultSnoozeDuration != null) {
      map['defaultSnoozeDuration'] = defaultSnoozeDuration;
    }
    if (maxSnoozeCount != null) map['maxSnoozeCount'] = maxSnoozeCount;
    if (snoozeOptions != null) map['snoozeOptions'] = snoozeOptions;
    if (smartSnooze != null) map['smartSnooze'] = smartSnooze;
    if (showOnLockScreen != null) map['showOnLockScreen'] = showOnLockScreen;
    if (wakeScreen != null) map['wakeScreen'] = wakeScreen;
    if (persistentNotifications != null) {
      map['persistentNotifications'] = persistentNotifications;
    }
    if (maxAllowedType != null) map['maxAllowedType'] = maxAllowedType;
    if (typeOverrides != null && typeOverrides!.isNotEmpty) {
      final typeMap = <String, dynamic>{};
      typeOverrides!.forEach((typeId, override) {
        if (typeId.isEmpty || !override.hasOverrides) return;
        typeMap[typeId] = override.toJson();
      });
      if (typeMap.isNotEmpty) {
        map['typeOverrides'] = typeMap;
      }
    }
    return map;
  }

  factory HubModuleNotificationSettings.fromJson(Map<String, dynamic> json) {
    Map<String, HubTypeDeliveryOverride>? typeOverrides;
    final rawTypeOverrides = json['typeOverrides'];
    if (rawTypeOverrides is Map) {
      final parsed = <String, HubTypeDeliveryOverride>{};
      rawTypeOverrides.forEach((key, value) {
        if (key is! String || key.trim().isEmpty || value is! Map) return;
        final mapValue = value.cast<String, dynamic>();
        final override = HubTypeDeliveryOverride.fromJson(mapValue);
        if (!override.hasOverrides) return;
        parsed[key] = override;
      });
      if (parsed.isNotEmpty) {
        typeOverrides = parsed;
      }
    }

    return HubModuleNotificationSettings(
      notificationsEnabled: json['notificationsEnabled'] as bool?,
      defaultUrgency: json['defaultUrgency'] as String?,
      defaultChannel: json['defaultChannel'] as String?,
      audioStream: json['audioStream'] as String?,
      defaultSound: json['defaultSound'] as String?,
      defaultVibrationPattern: json['defaultVibrationPattern'] as String?,
      alwaysUseAlarmMode: json['alwaysUseAlarmMode'] as bool?,
      specialSound: json['specialSound'] as String?,
      specialVibrationPattern: json['specialVibrationPattern'] as String?,
      useFullScreenIntent: json['useFullScreenIntent'] as bool?,
      allowDuringQuietHours: json['allowDuringQuietHours'] as bool?,
      titleTemplate: json['titleTemplate'] as String?,
      bodyTemplate: json['bodyTemplate'] as String?,
      specialTitleTemplate: json['specialTitleTemplate'] as String?,
      specialBodyTemplate: json['specialBodyTemplate'] as String?,
      defaultSnoozeDuration: (json['defaultSnoozeDuration'] as num?)?.toInt(),
      maxSnoozeCount: (json['maxSnoozeCount'] as num?)?.toInt(),
      snoozeOptions: (json['snoozeOptions'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList(),
      smartSnooze: json['smartSnooze'] as bool?,
      showOnLockScreen: json['showOnLockScreen'] as bool?,
      wakeScreen: json['wakeScreen'] as bool?,
      persistentNotifications: json['persistentNotifications'] as bool?,
      maxAllowedType: json['maxAllowedType'] as String?,
      typeOverrides: typeOverrides,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory HubModuleNotificationSettings.fromJsonString(String jsonString) {
    final decoded = jsonDecode(jsonString);
    if (decoded is! Map<String, dynamic>) {
      return HubModuleNotificationSettings.empty;
    }
    return HubModuleNotificationSettings.fromJson(decoded);
  }
}
