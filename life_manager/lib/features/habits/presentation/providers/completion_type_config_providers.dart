import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/completion_type_config.dart';
import '../../data/repositories/completion_type_config_repository.dart';

/// Singleton provider for CompletionTypeConfigRepository instance
final completionTypeConfigRepositoryProvider = Provider<CompletionTypeConfigRepository>((ref) {
  return CompletionTypeConfigRepository();
});

/// StateNotifier for managing completion type config list state
class CompletionTypeConfigNotifier extends StateNotifier<AsyncValue<List<CompletionTypeConfig>>> {
  final CompletionTypeConfigRepository repository;

  CompletionTypeConfigNotifier(this.repository) : super(const AsyncValue.loading()) {
    _initialize();
  }

  /// Initialize with defaults if empty
  Future<void> _initialize() async {
    await repository.initializeDefaults();
    await loadConfigs();
  }

  /// Load all configs from database
  Future<void> loadConfigs() async {
    state = const AsyncValue.loading();
    try {
      final configs = await repository.getAllConfigs();
      state = AsyncValue.data(configs);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Update a config - optimized: update state immediately
  Future<void> updateConfig(CompletionTypeConfig config) async {
    try {
      // Update state immediately
      state.whenData((configs) {
        final updatedConfigs = configs.map((c) => c.id == config.id ? config.copyWith(updatedAt: DateTime.now()) : c).toList();
        state = AsyncValue.data(updatedConfigs);
      });
      // Persist to database
      await repository.saveConfig(config.copyWith(updatedAt: DateTime.now()));
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await loadConfigs(); // Reload on error
    }
  }

  /// Get config by type ID
  CompletionTypeConfig? getConfigByTypeId(String typeId) {
    return state.maybeWhen(
      data: (configs) {
        try {
          return configs.firstWhere((c) => c.typeId == typeId);
        } catch (e) {
          return null;
        }
      },
      orElse: () => null,
    );
  }
}

/// Provider for CompletionTypeConfigNotifier
final completionTypeConfigNotifierProvider =
    StateNotifierProvider<CompletionTypeConfigNotifier, AsyncValue<List<CompletionTypeConfig>>>((ref) {
  final repository = ref.watch(completionTypeConfigRepositoryProvider);
  return CompletionTypeConfigNotifier(repository);
});
