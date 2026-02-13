import '../models/transaction_template.dart';
import '../../../../data/local/hive/hive_service.dart';

/// Repository for managing transaction templates
class TransactionTemplateRepository {
  static const String _boxName = 'transactionTemplatesBox';

  /// Get all transaction templates
  Future<List<TransactionTemplate>> getAllTemplates() async {
    final box = await HiveService.getBox<TransactionTemplate>(_boxName);
    return box.values.toList();
  }

  /// Create a new transaction template
  Future<void> createTemplate(TransactionTemplate template) async {
    final box = await HiveService.getBox<TransactionTemplate>(_boxName);
    await box.put(template.id, template);
  }

  /// Update an existing transaction template
  Future<void> updateTemplate(TransactionTemplate template) async {
    final box = await HiveService.getBox<TransactionTemplate>(_boxName);
    await box.put(template.id, template);
  }

  /// Delete a transaction template
  Future<void> deleteTemplate(String id) async {
    final box = await HiveService.getBox<TransactionTemplate>(_boxName);
    await box.delete(id);
  }

  /// Get a transaction template by ID
  Future<TransactionTemplate?> getTemplateById(String id) async {
    final box = await HiveService.getBox<TransactionTemplate>(_boxName);
    return box.get(id);
  }
}
