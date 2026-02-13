import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/local/hive/hive_service.dart';

/// Provider for managing tags
final tagNotifierProvider = StateNotifierProvider<TagNotifier, List<String>>((ref) {
  return TagNotifier();
});

class TagNotifier extends StateNotifier<List<String>> {
  static const String _boxName = 'tagsBox';
  static const String _key = 'available_tags';

  TagNotifier() : super([]) {
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

  /// Get all available tags
  List<String> getTags() {
    return List.unmodifiable(state);
  }
}

