import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/local/hive/hive_service.dart';

/// Provider for managing habit tags
final habitTagNotifierProvider = StateNotifierProvider<HabitTagNotifier, List<String>>((ref) {
  return HabitTagNotifier();
});

class HabitTagNotifier extends StateNotifier<List<String>> {
  static const String _boxName = 'habitTagsBox';
  static const String _key = 'available_tags';

  HabitTagNotifier() : super([]) {
    _loadTags();
  }

  /// Load tags from Hive
  Future<void> _loadTags() async {
    try {
      final box = await HiveService.getBox(_boxName);
      final tags = box.get(_key, defaultValue: <String>[]) as List<dynamic>?;
      if (tags != null) {
        state = tags.cast<String>();
      }
    } catch (e) {
      // If box doesn't exist or error occurs, start with empty list
      state = [];
    }
  }

  /// Save tags to Hive
  Future<void> _saveTags() async {
    try {
      final box = await HiveService.getBox(_boxName);
      await box.put(_key, state);
    } catch (e) {
      // Handle error silently or log it
    }
  }

  /// Add a new tag
  Future<void> addTag(String tag) async {
    final normalizedTag = tag.trim().toLowerCase();
    if (normalizedTag.isNotEmpty && !state.contains(normalizedTag)) {
      state = [...state, normalizedTag];
      await _saveTags();
    }
  }

  /// Remove a tag
  Future<void> removeTag(String tag) async {
    state = state.where((t) => t != tag).toList();
    await _saveTags();
  }

  /// Clear all tags
  Future<void> clearAllTags() async {
    state = [];
    try {
      final box = await HiveService.getBox(_boxName);
      await box.delete(_key);
    } catch (_) {
      // Ignore errors; state already cleared.
    }
  }

  /// Get all available tags
  List<String> getTags() {
    return List.unmodifiable(state);
  }
}
