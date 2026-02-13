import 'package:hive_flutter/hive_flutter.dart';
import '../models/task_template.dart';

/// Repository for managing TaskTemplate persistence with Hive
class TaskTemplateRepository {
  static const String _boxName = 'task_templates';
  Box<TaskTemplate>? _box;

  /// Get or open the Hive box
  Future<Box<TaskTemplate>> _getBox() async {
    if (_box != null && _box!.isOpen) {
      return _box!;
    }
    _box = await Hive.openBox<TaskTemplate>(_boxName);
    return _box!;
  }

  /// Get all templates
  Future<List<TaskTemplate>> getAllTemplates() async {
    final box = await _getBox();
    return box.values.toList();
  }

  /// Get templates by category
  Future<List<TaskTemplate>> getTemplatesByCategory(String categoryId) async {
    final box = await _getBox();
    return box.values.where((t) => t.categoryId == categoryId).toList();
  }

  /// Get templates without category (uncategorized)
  Future<List<TaskTemplate>> getUncategorizedTemplates() async {
    final box = await _getBox();
    return box.values.where((t) => t.categoryId == null || t.categoryId!.isEmpty).toList();
  }

  /// Get a template by ID
  Future<TaskTemplate?> getTemplateById(String id) async {
    final box = await _getBox();
    try {
      return box.values.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Create a new template
  Future<void> createTemplate(TaskTemplate template) async {
    final box = await _getBox();
    await box.put(template.id, template);
  }

  /// Update an existing template
  Future<void> updateTemplate(TaskTemplate template) async {
    final box = await _getBox();
    template.updatedAt = DateTime.now();
    await box.put(template.id, template);
  }

  /// Delete a template
  Future<void> deleteTemplate(String id) async {
    final box = await _getBox();
    await box.delete(id);
  }

  /// Record template usage
  Future<void> recordUsage(String id) async {
    final template = await getTemplateById(id);
    if (template != null) {
      template.recordUsage();
      await updateTemplate(template);
    }
  }

  /// Get most used templates (top N)
  Future<List<TaskTemplate>> getMostUsedTemplates({int limit = 5}) async {
    final box = await _getBox();
    final templates = box.values.toList();
    templates.sort((a, b) => b.usageCount.compareTo(a.usageCount));
    return templates.take(limit).toList();
  }

  /// Get recently used templates (top N)
  Future<List<TaskTemplate>> getRecentlyUsedTemplates({int limit = 5}) async {
    final box = await _getBox();
    final templates = box.values.where((t) => t.lastUsedAt != null).toList();
    templates.sort((a, b) => b.lastUsedAt!.compareTo(a.lastUsedAt!));
    return templates.take(limit).toList();
  }

  /// Search templates by title
  Future<List<TaskTemplate>> searchTemplates(String query) async {
    final box = await _getBox();
    final lowerQuery = query.toLowerCase();
    return box.values.where((t) {
      return t.title.toLowerCase().contains(lowerQuery) ||
          (t.description?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }
}
