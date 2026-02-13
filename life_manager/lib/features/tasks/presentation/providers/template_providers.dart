import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/models/task_template.dart';
import '../../../../data/repositories/task_template_repository.dart';

/// Singleton provider for TaskTemplateRepository instance
final templateRepositoryProvider = Provider<TaskTemplateRepository>((ref) {
  return TaskTemplateRepository();
});

/// StateNotifier for managing template list state
class TemplateNotifier extends StateNotifier<AsyncValue<List<TaskTemplate>>> {
  final TaskTemplateRepository repository;

  TemplateNotifier(this.repository) : super(const AsyncValue.loading()) {
    loadTemplates();
  }

  /// Load all templates from database
  Future<void> loadTemplates() async {
    state = const AsyncValue.loading();
    try {
      final templates = await repository.getAllTemplates();
      // Sort by usage count (most used first), then by title
      templates.sort((a, b) {
        final usageCompare = b.usageCount.compareTo(a.usageCount);
        if (usageCompare != 0) return usageCompare;
        return a.title.compareTo(b.title);
      });
      state = AsyncValue.data(templates);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Add a new template
  Future<void> addTemplate(TaskTemplate template) async {
    try {
      // Update state immediately
      state.whenData((templates) {
        state = AsyncValue.data([...templates, template]);
      });
      await repository.createTemplate(template);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadTemplates();
    }
  }

  /// Update an existing template
  Future<void> updateTemplate(TaskTemplate template) async {
    try {
      state.whenData((templates) {
        final updatedTemplates = templates.map((t) => t.id == template.id ? template : t).toList();
        state = AsyncValue.data(updatedTemplates);
      });
      await repository.updateTemplate(template);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadTemplates();
    }
  }

  /// Delete a template
  Future<void> deleteTemplate(String id) async {
    try {
      state.whenData((templates) {
        final updatedTemplates = templates.where((t) => t.id != id).toList();
        state = AsyncValue.data(updatedTemplates);
      });
      await repository.deleteTemplate(id);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadTemplates();
    }
  }

  /// Record template usage (when used to create a task)
  Future<void> recordUsage(String id) async {
    try {
      // Only call repository.recordUsage which handles the actual recording
      // Don't call recordUsage() on local state as they share the same Hive object reference
      await repository.recordUsage(id);
      
      // Refresh state to reflect the updated usage
      await loadTemplates();
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }
}

/// Provider for TemplateNotifier
final templateNotifierProvider =
    StateNotifierProvider<TemplateNotifier, AsyncValue<List<TaskTemplate>>>((ref) {
  final repository = ref.watch(templateRepositoryProvider);
  return TemplateNotifier(repository);
});

/// Provider for templates grouped by category
final templatesGroupedByCategoryProvider = Provider<AsyncValue<Map<String?, List<TaskTemplate>>>>((ref) {
  final templatesAsync = ref.watch(templateNotifierProvider);
  return templatesAsync.whenData((templates) {
    final Map<String?, List<TaskTemplate>> grouped = {};
    
    for (final template in templates) {
      final categoryId = template.categoryId;
      grouped.putIfAbsent(categoryId, () => []).add(template);
    }
    
    return grouped;
  });
});

/// Provider for getting a single template by ID
final templateByIdProvider = Provider.family<AsyncValue<TaskTemplate?>, String>((ref, id) {
  final templatesAsync = ref.watch(templateNotifierProvider);
  return templatesAsync.whenData((templates) {
    try {
      return templates.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  });
});

/// Provider for templates by category
final templatesByCategoryProvider = Provider.family<AsyncValue<List<TaskTemplate>>, String?>((ref, categoryId) {
  final templatesAsync = ref.watch(templateNotifierProvider);
  return templatesAsync.whenData((templates) {
    if (categoryId == null) {
      return templates.where((t) => t.categoryId == null || t.categoryId!.isEmpty).toList();
    }
    return templates.where((t) => t.categoryId == categoryId).toList();
  });
});

/// Provider for most used templates
final mostUsedTemplatesProvider = Provider<AsyncValue<List<TaskTemplate>>>((ref) {
  final templatesAsync = ref.watch(templateNotifierProvider);
  return templatesAsync.whenData((templates) {
    final sorted = List<TaskTemplate>.from(templates);
    sorted.sort((a, b) => b.usageCount.compareTo(a.usageCount));
    return sorted.take(5).toList();
  });
});

/// Provider for recently used templates
final recentlyUsedTemplatesProvider = Provider<AsyncValue<List<TaskTemplate>>>((ref) {
  final templatesAsync = ref.watch(templateNotifierProvider);
  return templatesAsync.whenData((templates) {
    final withUsage = templates.where((t) => t.lastUsedAt != null).toList();
    withUsage.sort((a, b) => b.lastUsedAt!.compareTo(a.lastUsedAt!));
    return withUsage.take(5).toList();
  });
});

/// Provider for searching templates
final templateSearchProvider = Provider.family<AsyncValue<List<TaskTemplate>>, String>((ref, query) {
  final templatesAsync = ref.watch(templateNotifierProvider);
  return templatesAsync.whenData((templates) {
    if (query.isEmpty) return templates;
    final lowerQuery = query.toLowerCase();
    return templates.where((t) {
      return t.title.toLowerCase().contains(lowerQuery) ||
          (t.description?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  });
});
