import 'dart:convert';

import 'package:hive/hive.dart';

import 'hub_notification_type.dart';

part 'hub_custom_notification_type.g.dart';

/// A user-created notification type that extends or overrides adapter types.
///
/// Stored in Hive and merged with adapter types at runtime.
/// 
/// Users can customize:
/// - Display name
/// - Icon (code point, family, package)
/// - Color
/// - Section assignment
/// - Full delivery config (channel, sound, audio stream, alarm mode, etc.)
@HiveType(typeId: 40) // Use next available typeId in your app
class HubCustomNotificationType extends HiveObject {
  /// Unique type ID (e.g., 'finance_custom_urgent_reminder').
  /// Must be unique across all types (built-in + adapter + custom).
  @HiveField(0)
  String id;

  /// Human-readable display name shown in Hub UI.
  @HiveField(1)
  String displayName;

  /// Module ID this type belongs to.
  @HiveField(2)
  String moduleId;

  /// Optional section ID to group under (e.g., 'bills', 'debts').
  @HiveField(3)
  String? sectionId;

  /// Icon code point (from MaterialIcons or custom font).
  @HiveField(4)
  int iconCodePoint;

  /// Icon font family (defaults to MaterialIcons).
  @HiveField(5)
  String iconFontFamily;

  /// Icon font package (null for MaterialIcons).
  @HiveField(6)
  String? iconFontPackage;

  /// Color value (ARGB) for badges and type indicators.
  @HiveField(7)
  int colorValue;

  /// Delivery configuration as JSON.
  /// Stored as Map to avoid Hive adapter complexity.
  @HiveField(8)
  Map<String, dynamic> deliveryConfigJson;

  /// When this type was created.
  @HiveField(9)
  DateTime createdAt;

  /// When this type was last modified.
  @HiveField(10)
  DateTime updatedAt;

  /// Whether this is a user-created type (true) or overrides an adapter type (false).
  @HiveField(11)
  bool isUserCreated;

  /// Original adapter type ID if this overrides an adapter type.
  /// Null if this is a fully custom user-created type.
  @HiveField(12)
  String? overridesAdapterTypeId;

  HubCustomNotificationType({
    required this.id,
    required this.displayName,
    required this.moduleId,
    this.sectionId,
    required this.iconCodePoint,
    this.iconFontFamily = 'MaterialIcons',
    this.iconFontPackage,
    required this.colorValue,
    required this.deliveryConfigJson,
    required this.createdAt,
    required this.updatedAt,
    this.isUserCreated = true,
    this.overridesAdapterTypeId,
  });

  // ---------------------------------------------------------------------------
  // Conversion to/from HubNotificationType
  // ---------------------------------------------------------------------------

  /// Converts this custom type to a standard [HubNotificationType] for registration.
  HubNotificationType toHubNotificationType() {
    return HubNotificationType(
      id: id,
      displayName: displayName,
      moduleId: moduleId,
      sectionId: sectionId,
      defaultConfig: HubDeliveryConfig(
        channelKey: deliveryConfigJson['channelKey'] as String? ?? '',
        audioStream: deliveryConfigJson['audioStream'] as String? ?? 'notification',
        useAlarmMode: deliveryConfigJson['useAlarmMode'] as bool? ?? false,
        useFullScreenIntent: deliveryConfigJson['useFullScreenIntent'] as bool? ?? false,
        bypassDnd: deliveryConfigJson['bypassDnd'] as bool? ?? false,
        bypassQuietHours: deliveryConfigJson['bypassQuietHours'] as bool? ?? false,
        persistent: deliveryConfigJson['persistent'] as bool? ?? false,
        wakeScreen: deliveryConfigJson['wakeScreen'] as bool? ?? false,
        soundKey: deliveryConfigJson['soundKey'] as String?,
        vibrationPatternId: deliveryConfigJson['vibrationPatternId'] as String?,
      ),
    );
  }

  /// Creates a custom type from an existing [HubNotificationType] (for editing).
  factory HubCustomNotificationType.fromHubNotificationType(
    HubNotificationType type, {
    int? iconCodePoint,
    String? iconFontFamily,
    String? iconFontPackage,
    int? colorValue,
    bool isUserCreated = false,
    String? overridesAdapterTypeId,
  }) {
    final config = type.defaultConfig;
    return HubCustomNotificationType(
      id: type.id,
      displayName: type.displayName,
      moduleId: type.moduleId ?? '',
      sectionId: type.sectionId,
      iconCodePoint: iconCodePoint ?? 0xe145, // Default: notifications icon
      iconFontFamily: iconFontFamily ?? 'MaterialIcons',
      iconFontPackage: iconFontPackage,
      colorValue: colorValue ?? 0xFF2196F3, // Default: blue
      deliveryConfigJson: {
        'channelKey': config.channelKey,
        'audioStream': config.audioStream,
        'useAlarmMode': config.useAlarmMode,
        'useFullScreenIntent': config.useFullScreenIntent,
        'bypassDnd': config.bypassDnd,
        'bypassQuietHours': config.bypassQuietHours,
        'persistent': config.persistent,
        'wakeScreen': config.wakeScreen,
        if (config.soundKey != null) 'soundKey': config.soundKey,
        if (config.vibrationPatternId != null) 'vibrationPatternId': config.vibrationPatternId,
      },
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isUserCreated: isUserCreated,
      overridesAdapterTypeId: overridesAdapterTypeId,
    );
  }

  // ---------------------------------------------------------------------------
  // Convenience methods
  // ---------------------------------------------------------------------------

  /// Creates a blank custom type with sensible defaults.
  factory HubCustomNotificationType.blank({
    required String moduleId,
    String? sectionId,
  }) {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch;
    return HubCustomNotificationType(
      id: '${moduleId}_custom_$timestamp',
      displayName: 'New Notification Type',
      moduleId: moduleId,
      sectionId: sectionId,
      iconCodePoint: 0xe145, // notifications_rounded
      iconFontFamily: 'MaterialIcons',
      colorValue: 0xFF2196F3, // blue
      deliveryConfigJson: {
        'channelKey': 'task_reminders',
        'audioStream': 'notification',
        'useAlarmMode': false,
        'useFullScreenIntent': false,
        'bypassDnd': false,
        'bypassQuietHours': false,
        'persistent': false,
        'wakeScreen': false,
      },
      createdAt: now,
      updatedAt: now,
      isUserCreated: true,
    );
  }

  /// Creates a copy of this type (for duplication).
  HubCustomNotificationType duplicate({String? newId, String? newDisplayName}) {
    final now = DateTime.now();
    return HubCustomNotificationType(
      id: newId ?? '${id}_copy_${now.millisecondsSinceEpoch}',
      displayName: newDisplayName ?? '$displayName (Copy)',
      moduleId: moduleId,
      sectionId: sectionId,
      iconCodePoint: iconCodePoint,
      iconFontFamily: iconFontFamily,
      iconFontPackage: iconFontPackage,
      colorValue: colorValue,
      deliveryConfigJson: Map<String, dynamic>.from(deliveryConfigJson),
      createdAt: now,
      updatedAt: now,
      isUserCreated: true,
      overridesAdapterTypeId: null, // Duplicates are always new user types
    );
  }

  /// Updates this type's properties.
  void update({
    String? displayName,
    String? sectionId,
    int? iconCodePoint,
    String? iconFontFamily,
    String? iconFontPackage,
    int? colorValue,
    Map<String, dynamic>? deliveryConfigJson,
  }) {
    if (displayName != null) this.displayName = displayName;
    if (sectionId != null) this.sectionId = sectionId;
    if (iconCodePoint != null) this.iconCodePoint = iconCodePoint;
    if (iconFontFamily != null) this.iconFontFamily = iconFontFamily;
    if (iconFontPackage != null) this.iconFontPackage = iconFontPackage;
    if (colorValue != null) this.colorValue = colorValue;
    if (deliveryConfigJson != null) {
      this.deliveryConfigJson = deliveryConfigJson;
    }
    updatedAt = DateTime.now();
  }

  // ---------------------------------------------------------------------------
  // JSON serialization (for backup / debugging)
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'moduleId': moduleId,
      'sectionId': sectionId,
      'iconCodePoint': iconCodePoint,
      'iconFontFamily': iconFontFamily,
      'iconFontPackage': iconFontPackage,
      'colorValue': colorValue,
      'deliveryConfigJson': deliveryConfigJson,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isUserCreated': isUserCreated,
      'overridesAdapterTypeId': overridesAdapterTypeId,
    };
  }

  factory HubCustomNotificationType.fromJson(Map<String, dynamic> json) {
    return HubCustomNotificationType(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      moduleId: json['moduleId'] as String,
      sectionId: json['sectionId'] as String?,
      iconCodePoint: json['iconCodePoint'] as int,
      iconFontFamily: json['iconFontFamily'] as String? ?? 'MaterialIcons',
      iconFontPackage: json['iconFontPackage'] as String?,
      colorValue: json['colorValue'] as int,
      deliveryConfigJson: (json['deliveryConfigJson'] as Map).cast<String, dynamic>(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      isUserCreated: json['isUserCreated'] as bool? ?? true,
      overridesAdapterTypeId: json['overridesAdapterTypeId'] as String?,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory HubCustomNotificationType.fromJsonString(String jsonString) {
    return HubCustomNotificationType.fromJson(
      jsonDecode(jsonString) as Map<String, dynamic>,
    );
  }

  @override
  String toString() {
    return 'HubCustomNotificationType('
        'id: $id, '
        'displayName: $displayName, '
        'moduleId: $moduleId, '
        'sectionId: $sectionId, '
        'isUserCreated: $isUserCreated'
        ')';
  }
}
