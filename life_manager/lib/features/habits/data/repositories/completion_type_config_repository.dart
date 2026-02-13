import 'package:hive_flutter/hive_flutter.dart';
import '../models/completion_type_config.dart';
import '../../../../data/local/hive/hive_service.dart';

/// Repository for completion type configuration CRUD operations using Hive
class CompletionTypeConfigRepository {
  static const String boxName = 'completionTypeConfigsBox';

  /// Cached box reference for performance
  Box<CompletionTypeConfig>? _cachedBox;

  /// Get the configs box (lazy initialization with caching)
  Future<Box<CompletionTypeConfig>> _getBox() async {
    if (_cachedBox != null && _cachedBox!.isOpen) {
      return _cachedBox!;
    }
    _cachedBox = await HiveService.getBox<CompletionTypeConfig>(boxName);
    return _cachedBox!;
  }

  /// Create or update a config
  Future<void> saveConfig(CompletionTypeConfig config) async {
    final box = await _getBox();
    await box.put(config.id, config);
  }

  /// Get all configs
  Future<List<CompletionTypeConfig>> getAllConfigs() async {
    final box = await _getBox();
    return box.values.toList();
  }

  /// Get config by type ID
  Future<CompletionTypeConfig?> getConfigByTypeId(String typeId) async {
    final box = await _getBox();
    try {
      return box.values.firstWhere((c) => c.typeId == typeId);
    } catch (e) {
      return null;
    }
  }

  /// Initialize with defaults if empty
  Future<void> initializeDefaults() async {
    final box = await _getBox();
    if (box.isEmpty) {
      await saveConfig(CompletionTypeConfig.yesNoDefault());
      await saveConfig(CompletionTypeConfig.numericDefault());
      await saveConfig(CompletionTypeConfig.timerDefault());
      await saveConfig(CompletionTypeConfig.quitDefault());
    }
  }

  /// Delete a config
  Future<void> deleteConfig(String id) async {
    final box = await _getBox();
    await box.delete(id);
  }

  /// Delete all configs
  Future<void> deleteAllConfigs() async {
    final box = await _getBox();
    await box.clear();
  }
}
