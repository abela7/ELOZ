import '../models/bill_category.dart';
import '../../../../data/local/hive/hive_service.dart';

/// Repository for managing bill categories
class BillCategoryRepository {
  static const String _boxName = 'billCategoriesBox';

  Future<List<BillCategory>> getAllCategories() async {
    final box = await HiveService.getBox<BillCategory>(_boxName);
    return box.values.toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  Future<List<BillCategory>> getActiveCategories() async {
    final categories = await getAllCategories();
    return categories.where((c) => c.isActive).toList();
  }

  Future<void> createCategory(BillCategory category) async {
    final box = await HiveService.getBox<BillCategory>(_boxName);
    await box.put(category.id, category);
  }

  Future<void> updateCategory(BillCategory category) async {
    final box = await HiveService.getBox<BillCategory>(_boxName);
    await box.put(category.id, category);
  }

  Future<void> deleteCategory(String id) async {
    final box = await HiveService.getBox<BillCategory>(_boxName);
    await box.delete(id);
  }

  Future<BillCategory?> getCategoryById(String id) async {
    final box = await HiveService.getBox<BillCategory>(_boxName);
    return box.get(id);
  }
}
