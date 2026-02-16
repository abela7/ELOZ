import 'package:hive/hive.dart';

import '../../../data/local/hive/hive_service.dart';
import '../models/hub_custom_notification_type.dart';

/// Store for user-created/customized notification types.
///
/// Persists custom types to Hive. Custom types can:
/// - Be fully user-created (new type from scratch)
/// - Override adapter types (same ID = custom replaces adapter)
class CustomNotificationTypeStore {
  static const String _boxName = 'customNotificationTypes';
  Box<HubCustomNotificationType>? _box;

  Future<void> initialize() async {
    if (_box != null && _box!.isOpen) return;

    // Register adapter if not already registered
    if (!Hive.isAdapterRegistered(40)) {
      Hive.registerAdapter(HubCustomNotificationTypeAdapter());
    }

    _box = await HiveService.getBox<HubCustomNotificationType>(_boxName);
  }

  /// Get all custom types for a specific module.
  Future<List<HubCustomNotificationType>> getAllForModule(
    String moduleId,
  ) async {
    await initialize();
    return _box!.values.where((t) => t.moduleId == moduleId).toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
  }

  /// Get all custom types (all modules).
  Future<List<HubCustomNotificationType>> getAll() async {
    await initialize();
    return _box!.values.toList();
  }

  /// Get a specific type by ID.
  Future<HubCustomNotificationType?> getById(String typeId) async {
    await initialize();
    try {
      return _box!.values.firstWhere((t) => t.id == typeId);
    } catch (_) {
      return null;
    }
  }

  /// Save a custom type (create or update).
  Future<void> save(HubCustomNotificationType type) async {
    await initialize();

    final existing = await getById(type.id);

    if (existing != null) {
      // Update in-place so Hive persists actual changes.
      existing
        ..displayName = type.displayName
        ..moduleId = type.moduleId
        ..sectionId = type.sectionId
        ..iconCodePoint = type.iconCodePoint
        ..iconFontFamily = type.iconFontFamily
        ..iconFontPackage = type.iconFontPackage
        ..colorValue = type.colorValue
        ..deliveryConfigJson = Map<String, dynamic>.from(
          type.deliveryConfigJson,
        )
        ..isUserCreated = type.isUserCreated
        ..overridesAdapterTypeId = type.overridesAdapterTypeId
        ..updatedAt = DateTime.now();
      await existing.save();
    } else {
      await _box!.add(type);
    }
  }

  /// Delete a custom type by ID.
  Future<bool> delete(String typeId) async {
    await initialize();

    final entry = _box!.values.cast<HubCustomNotificationType?>().firstWhere(
      (t) => t?.id == typeId,
      orElse: () => null,
    );

    if (entry != null) {
      await entry.delete();
      return true;
    }
    return false;
  }

  /// Delete all custom types for a module (reset to adapter defaults).
  Future<int> deleteAllForModule(String moduleId) async {
    await initialize();

    final toDelete = _box!.values.where((t) => t.moduleId == moduleId).toList();

    for (final type in toDelete) {
      await type.delete();
    }

    return toDelete.length;
  }

  /// Delete all custom types (full reset).
  Future<int> deleteAll() async {
    await initialize();
    final count = _box!.length;
    await _box!.clear();
    return count;
  }

  /// Check if a type ID already exists.
  Future<bool> exists(String typeId) async {
    await initialize();
    return _box!.values.any((t) => t.id == typeId);
  }

  /// Get count of custom types for a module.
  Future<int> getCountForModule(String moduleId) async {
    await initialize();
    return _box!.values.where((t) => t.moduleId == moduleId).length;
  }

  /// Close the box (cleanup).
  Future<void> close() async {
    await _box?.close();
    _box = null;
  }
}
