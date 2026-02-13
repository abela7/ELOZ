import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/sleep_factor.dart';
import '../../../../data/local/hive/hive_service.dart';
import '../../sleep_module.dart';

/// Repository for managing Sleep Factors
class SleepFactorRepository {
  static bool _defaultsInitialized = false;
  static bool _defaultsSynced = false;
  static Box<SleepFactor>? _cachedBox;

  /// Get the Hive box for sleep factors (with caching)
  Future<Box<SleepFactor>> _getBox() async {
    // Return cached box if available
    if (_cachedBox != null && _cachedBox!.isOpen) {
      return _cachedBox!;
    }

    try {
      debugPrint('📦 Opening sleep factors box...');
      final box = await HiveService.getBox<SleepFactor>(SleepModule.sleepFactorsBoxName);
      _cachedBox = box; // Cache the box
      debugPrint('✓ Sleep factors box opened. Items: ${box.length}');
      
      // Initialize defaults on first access if not already done
      if (!_defaultsInitialized && box.isEmpty) {
        debugPrint('🔧 Initializing default factors...');
        await _initializeDefaults(box);
        _defaultsInitialized = true;
        debugPrint('✓ Default factors initialized. Items: ${box.length}');
      }

      if (!_defaultsSynced) {
        await _syncDefaultFactors(box);
        _defaultsSynced = true;
      }
      
      return box;
    } catch (e, stackTrace) {
      debugPrint('❌ Error opening sleep factors box: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Initialize default factors (private helper)
  Future<void> _initializeDefaults(Box<SleepFactor> box) async {
    try {
      final defaultFactors = SleepFactor.getDefaultFactors();
      debugPrint('📝 Creating ${defaultFactors.length} default factors...');
      
      // Batch write for better performance
      final batch = <String, SleepFactor>{};
      for (final factor in defaultFactors) {
        batch[factor.id] = factor;
      }
      await box.putAll(batch);
      
      debugPrint('✓ All ${batch.length} default factors added successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ Error initializing default factors: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Initialize default factors if none exist (public for module init)
  Future<void> initializeDefaultFactors() async {
    if (_defaultsInitialized) return;
    final box = await HiveService.getBox<SleepFactor>(SleepModule.sleepFactorsBoxName);
    if (box.isEmpty) {
      await _initializeDefaults(box);
    }
    await _syncDefaultFactors(box);
    _defaultsInitialized = true;
    _defaultsSynced = true;
  }

  Future<void> _syncDefaultFactors(Box<SleepFactor> box) async {
    final defaults = SleepFactor.getDefaultFactors();
    final defaultByName = <String, SleepFactor>{
      for (final factor in defaults) factor.name.toLowerCase(): factor,
    };

    final existingDefaultNames = box.values
        .where((factor) => factor.isDefault)
        .map((factor) => factor.name.toLowerCase())
        .toSet();

    // Add missing built-in defaults for existing users.
    final missingDefaults = defaults
        .where((factor) => !existingDefaultNames.contains(factor.name.toLowerCase()))
        .toList();
    if (missingDefaults.isNotEmpty) {
      await box.putAll({for (final factor in missingDefaults) factor.id: factor});
    }

    // Backfill/normalize type + schema for default factors already in DB.
    final updates = <String, SleepFactor>{};
    for (final factor in box.values.where((f) => f.isDefault)) {
      final canonical = defaultByName[factor.name.toLowerCase()];
      if (canonical == null) continue;

      final needsTypeFix = factor.factorTypeValue != canonical.factorTypeValue;
      final needsSchemaFix = factor.schemaVersion < SleepFactor.currentSchemaVersion;
      if (needsTypeFix || needsSchemaFix) {
        updates[factor.id] = factor.copyWith(
          factorTypeValue: canonical.factorTypeValue,
          schemaVersion: SleepFactor.currentSchemaVersion,
        );
      }
    }
    if (updates.isNotEmpty) {
      await box.putAll(updates);
    }
  }

  /// Create a new sleep factor
  Future<void> create(SleepFactor factor) async {
    final box = await _getBox();
    await box.put(factor.id, factor);
  }

  /// Update an existing sleep factor
  Future<void> update(SleepFactor factor) async {
    final box = await _getBox();
    await box.put(factor.id, factor);
  }

  /// Delete a sleep factor
  Future<void> delete(String id) async {
    final box = await _getBox();
    await box.delete(id);
  }

  /// Get a sleep factor by ID
  Future<SleepFactor?> getById(String id) async {
    final box = await _getBox();
    return box.get(id);
  }

  /// Get all sleep factors
  Future<List<SleepFactor>> getAll() async {
    try {
      final box = await _getBox();
      final factors = box.values.toList();
      debugPrint('📊 getAll() returning ${factors.length} factors');
      return factors;
    } catch (e, stackTrace) {
      debugPrint('❌ Error in getAll(): $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Get all default factors
  Future<List<SleepFactor>> getDefaultFactors() async {
    final box = await _getBox();
    return box.values.where((factor) => factor.isDefault).toList();
  }

  /// Get all custom factors (non-default)
  Future<List<SleepFactor>> getCustomFactors() async {
    final box = await _getBox();
    return box.values.where((factor) => !factor.isDefault).toList();
  }

  /// Watch all sleep factors (stream)
  Stream<List<SleepFactor>> watchAll() async* {
    final box = await _getBox();
    yield box.values.toList();
    
    await for (final _ in box.watch()) {
      yield box.values.toList();
    }
  }

  /// Watch a specific sleep factor by ID (stream)
  Stream<SleepFactor?> watchById(String id) async* {
    final box = await _getBox();
    yield box.get(id);
    
    await for (final _ in box.watch(key: id)) {
      yield box.get(id);
    }
  }

  /// Check if a factor with the same name exists
  Future<bool> existsByName(String name, {String? excludeId}) async {
    final box = await _getBox();
    return box.values.any((factor) => 
      factor.name.toLowerCase() == name.toLowerCase() && 
      (excludeId == null || factor.id != excludeId)
    );
  }

  /// Get factors by IDs (for displaying selected factors)
  Future<List<SleepFactor>> getByIds(List<String> ids) async {
    final box = await _getBox();
    return ids
        .map((id) => box.get(id))
        .where((factor) => factor != null)
        .cast<SleepFactor>()
        .toList();
  }

  /// Clears all factors and re-initializes with defaults. Used for full reset.
  Future<void> resetToDefaults() async {
    final box = await _getBox();
    await box.clear();
    _defaultsInitialized = false;
    _defaultsSynced = false;
    await _initializeDefaults(box);
    _defaultsInitialized = true;
    _defaultsSynced = true;
  }
}
