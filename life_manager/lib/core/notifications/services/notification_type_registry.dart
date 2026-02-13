import '../models/hub_custom_notification_type.dart';
import '../models/hub_notification_type.dart';

/// Central registry for all notification types (built-in + custom).
///
/// The hub uses this to look up a type by ID and to clamp a requested type
/// to a user's `maxAllowedType` setting.
class NotificationTypeRegistry {
  static final NotificationTypeRegistry _instance =
      NotificationTypeRegistry._internal();
  factory NotificationTypeRegistry() => _instance;
  NotificationTypeRegistry._internal();

  /// All registered types keyed by ID.
  final Map<String, HubNotificationType> _types = {};

  bool _builtInsRegistered = false;

  /// Ensures built-in types are registered exactly once.
  void ensureBuiltInsRegistered() {
    if (_builtInsRegistered) return;
    for (final t in HubNotificationType.builtInTypes) {
      _types[t.id] = t;
    }
    _builtInsRegistered = true;
  }

  /// Registers a list of custom types from a mini app adapter.
  ///
  /// If a type with the same ID already exists, the new one wins.
  void registerCustomTypes(List<HubNotificationType> types) {
    for (final t in types) {
      _types[t.id] = t;
    }
  }

  /// Loads and registers custom types from Hive storage.
  ///
  /// Custom types WIN over adapter types (same ID = custom replaces adapter).
  /// Call this after registering adapter types during hub initialization.
  void loadCustomTypes(List<HubCustomNotificationType> customTypes) {
    for (final custom in customTypes) {
      _types[custom.id] = custom.toHubNotificationType();
    }
  }

  /// Unregisters all custom types belonging to [moduleId].
  void unregisterModuleTypes(String moduleId) {
    _types.removeWhere((_, t) => t.moduleId == moduleId);
  }

  /// Looks up a type by [id]. Returns `null` if not found.
  HubNotificationType? lookup(String id) {
    ensureBuiltInsRegistered();
    return _types[id];
  }

  /// Returns all registered types.
  List<HubNotificationType> get allTypes {
    ensureBuiltInsRegistered();
    return _types.values.toList();
  }

  /// Returns all types belonging to [moduleId] (custom types only).
  List<HubNotificationType> typesForModule(String moduleId) {
    ensureBuiltInsRegistered();
    return _types.values.where((t) => t.moduleId == moduleId).toList();
  }

  /// Returns all built-in (global) types.
  List<HubNotificationType> get builtInTypes {
    ensureBuiltInsRegistered();
    return _types.values.where((t) => t.moduleId == null).toList();
  }

  // ---------------------------------------------------------------------------
  // Type resolution + clamping
  // ---------------------------------------------------------------------------

  /// Resolves the effective [HubDeliveryConfig] for a schedule request.
  ///
  /// 1. Look up the requested [typeId] in the registry.
  /// 2. If not found, fall back to `'regular'`.
  /// 3. If [maxAllowedType] is set, clamp the type DOWN to that level.
  /// 4. Return the resolved [HubDeliveryConfig].
  ///
  /// [moduleDefaultChannel] is used when the type's channel is empty
  /// (meaning "use module default").
  HubDeliveryConfig resolve({
    required String typeId,
    String? maxAllowedType,
    String moduleDefaultChannel = 'task_reminders',
  }) {
    ensureBuiltInsRegistered();

    // 1. Look up
    var type = _types[typeId];
    type ??= _types['regular']!;

    var config = type.defaultConfig;

    // 2. Clamp if user set a max level
    if (maxAllowedType != null && maxAllowedType.isNotEmpty) {
      final maxLevel = HubNotificationTypeLevel.levelOf(maxAllowedType);
      final requestedLevel = _effectiveLevel(type);

      if (requestedLevel > maxLevel) {
        // Downgrade to the max allowed built-in type
        final clampedType = _types[maxAllowedType];
        if (clampedType != null) {
          config = clampedType.defaultConfig;
        }
      }
    }

    // 3. Resolve empty channel key to module default
    if (config.channelKey.isEmpty) {
      config = config.copyWith(channelKey: moduleDefaultChannel);
    }

    return config;
  }

  /// Determines the effective level for a type, taking into account that
  /// custom types inherit their level from their delivery config.
  int _effectiveLevel(HubNotificationType type) {
    // Built-in types have a fixed level
    final builtInLevel = HubNotificationTypeLevel.levelOf(type.id);
    if (type.moduleId == null) {
      // It's a built-in type
      return builtInLevel;
    }
    // Custom type: determine level from its config
    return HubNotificationTypeLevel.levelOfConfig(type.defaultConfig);
  }
}
