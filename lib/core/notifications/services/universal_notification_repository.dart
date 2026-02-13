import 'package:hive_flutter/hive_flutter.dart';

import '../models/universal_notification.dart';

/// Repository for Universal Notifications created via the Universal Creator.
///
/// All notifications from all modules are stored in a single Hive box.
/// Replaces scattered storage (bill.remindersJson, task reminders, etc.).
class UniversalNotificationRepository {
  static const String _boxName = 'universal_notifications';
  Box<UniversalNotification>? _box;

  Future<void> init() async {
    if (_box != null && _box!.isOpen) return;

    if (!Hive.isAdapterRegistered(41)) {
      Hive.registerAdapter(UniversalNotificationAdapter());
    }

    _box = await Hive.openBox<UniversalNotification>(_boxName);
  }

  Box<UniversalNotification> get _safeBox {
    if (_box == null || !_box!.isOpen) {
      throw StateError(
        'UniversalNotificationRepository not initialized. Call init() first.',
      );
    }
    return _box!;
  }

  /// Get all notifications (optionally filtered).
  Future<List<UniversalNotification>> getAll({
    String? moduleId,
    String? section,
    String? entityId,
    bool enabledOnly = false,
  }) async {
    await init();
    var list = _safeBox.values.toList();
    if (moduleId != null) {
      list = list.where((n) => n.moduleId == moduleId).toList();
    }
    if (section != null) {
      list = list.where((n) => n.section == section).toList();
    }
    if (entityId != null) {
      list = list.where((n) => n.entityId == entityId).toList();
    }
    if (enabledOnly) {
      list = list.where((n) => n.enabled).toList();
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Get notifications for a specific entity.
  Future<List<UniversalNotification>> getByEntity(String entityId) async {
    return getAll(entityId: entityId);
  }

  /// Get a notification by ID.
  Future<UniversalNotification?> getById(String id) async {
    await init();
    return _safeBox.get(id);
  }

  /// Save a notification (create or update).
  Future<void> save(UniversalNotification notification) async {
    await init();
    await _safeBox.put(notification.id, notification);
  }

  /// Delete a notification.
  Future<void> delete(String id) async {
    await init();
    await _safeBox.delete(id);
  }

  /// Remove all stored definitions. Use for full hub reset.
  Future<void> clearAll() async {
    await init();
    await _safeBox.clear();
  }

  /// Delete all notifications for an entity (e.g. when entity is deleted).
  Future<int> deleteByEntity(String entityId) async {
    await init();
    final toDelete = _safeBox.values
        .where((n) => n.entityId == entityId)
        .map((n) => n.id)
        .toList();
    if (toDelete.isEmpty) return 0;
    await _safeBox.deleteAll(toDelete);
    return toDelete.length;
  }

  /// Get count of notifications.
  Future<int> get count async {
    await init();
    return _safeBox.length;
  }

  /// Watch the box for changes (for reactive UIs).
  Stream<BoxEvent> watch() {
    if (_box == null || !_box!.isOpen) {
      return Stream.empty();
    }
    return _safeBox.watch();
  }

  Future<void> close() async {
    await _box?.close();
    _box = null;
  }
}
