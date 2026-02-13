import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sleep_template.dart';
import '../../../../data/local/hive/hive_service.dart';
import '../../sleep_module.dart';

/// Legacy default template names that were previously hardcoded. Removed in one-time migration.
const _legacyDefaultNames = {
  'Night 11:00 PM - 7:00 AM',
  'Night 10:30 PM - 6:30 AM',
  'Power Nap 20 min',
  'Recovery Nap 45 min',
};

class SleepTemplateRepository {
  static Box<SleepTemplate>? _cachedBox;
  static const String _migrationKey = 'sleep_templates_legacy_removed';

  Future<Box<SleepTemplate>> _getBox() async {
    if (_cachedBox != null && _cachedBox!.isOpen) {
      return _cachedBox!;
    }
    final box = await HiveService.getBox<SleepTemplate>(
      SleepModule.sleepTemplatesBoxName,
    );
    _cachedBox = box;
    await _removeLegacyDefaultsIfNeeded(box);
    return box;
  }

  /// One-time migration: remove previously hardcoded default templates.
  Future<void> _removeLegacyDefaultsIfNeeded(Box<SleepTemplate> box) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_migrationKey) == true) return;

    final toRemove = box.values
        .where((t) => _legacyDefaultNames.contains(t.name))
        .map((t) => t.id)
        .toList();
    if (toRemove.isNotEmpty) {
      await box.deleteAll(toRemove);
    }
    await prefs.setBool(_migrationKey, true);
  }

  /// Warms the cache so add-log sheet opens fast. No default templates added.
  Future<void> warmCache() async {
    if (_cachedBox != null && _cachedBox!.isOpen) return;
    await _getBox();
  }

  Future<List<SleepTemplate>> getAll() async {
    final box = await _getBox();
    final list = box.values.toList();
    list.sort((a, b) {
      if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  Stream<List<SleepTemplate>> watchAll() async* {
    final box = await _getBox();
    yield await getAll();
    await for (final _ in box.watch()) {
      yield await getAll();
    }
  }

  Future<void> create(SleepTemplate template) async {
    final box = await _getBox();
    await box.put(
      template.id,
      template.copyWith(schemaVersion: SleepTemplate.currentSchemaVersion),
    );
  }

  Future<void> update(SleepTemplate template) async {
    final box = await _getBox();
    await box.put(
      template.id,
      template.copyWith(
        updatedAt: DateTime.now(),
        schemaVersion: SleepTemplate.currentSchemaVersion,
      ),
    );
  }

  Future<void> delete(String id) async {
    final box = await _getBox();
    await box.delete(id);
  }

  /// Returns the default template (used to pre-fill add sleep log).
  Future<SleepTemplate?> getDefaultTemplate() async {
    final list = await getAll();
    for (final t in list) {
      if (t.isDefault) return t;
    }
    return list.isNotEmpty ? list.first : null;
  }

  /// Clears all templates. Used for full reset. Only user-created templates exist.
  Future<void> resetToDefaults() async {
    final box = await _getBox();
    await box.clear();
  }

  /// Set a template as the default, unsetting all others
  Future<void> setAsDefault(String templateId) async {
    final box = await _getBox();
    final templates = box.values.toList();

    // Unset all templates as default
    for (final template in templates) {
      if (template.isDefault) {
        await box.put(
          template.id,
          template.copyWith(isDefault: false, updatedAt: DateTime.now()),
        );
      }
    }

    // Set the selected template as default
    final selectedTemplate = templates.firstWhere((t) => t.id == templateId);
    await box.put(
      selectedTemplate.id,
      selectedTemplate.copyWith(isDefault: true, updatedAt: DateTime.now()),
    );
  }
}
