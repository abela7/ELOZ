import '../models/bill.dart';
import '../../../../data/local/hive/hive_service.dart';

/// Repository for managing bills and subscriptions
class BillRepository {
  static const String _boxName = 'billsBox';

  Future<List<Bill>> getAllBills() async {
    final box = await HiveService.getBox<Bill>(_boxName);
    return box.values.toList();
  }

  Future<List<Bill>> getActiveBills() async {
    final bills = await getAllBills();
    return bills.where((b) => b.isActive).toList();
  }

  Future<List<Bill>> getBillsByType(String type) async {
    final bills = await getAllBills();
    return bills.where((b) => b.type == type && b.isActive).toList();
  }

  Future<List<Bill>> getBillsByCategory(String categoryId) async {
    final bills = await getAllBills();
    return bills.where((b) => b.categoryId == categoryId).toList();
  }

  Future<List<Bill>> getUpcomingBills({int days = 7}) async {
    final bills = await getActiveBills();
    final now = DateTime.now();
    final cutoff = now.add(Duration(days: days));
    return bills.where((b) {
        if (b.nextDueDate == null) return false;
        return b.nextDueDate!.isAfter(now) && b.nextDueDate!.isBefore(cutoff);
      }).toList()
      ..sort((a, b) => (a.nextDueDate ?? now).compareTo(b.nextDueDate ?? now));
  }

  Future<List<Bill>> getOverdueBills() async {
    final bills = await getActiveBills();
    return bills.where((b) => b.isOverdue).toList();
  }

  Future<void> createBill(Bill bill) async {
    final box = await HiveService.getBox<Bill>(_boxName);
    await box.put(bill.id, bill);
  }

  Future<void> updateBill(Bill bill) async {
    final box = await HiveService.getBox<Bill>(_boxName);
    await box.put(bill.id, bill);
  }

  Future<void> deleteBill(String id) async {
    final box = await HiveService.getBox<Bill>(_boxName);
    await box.delete(id);
  }

  Future<Bill?> getBillById(String id) async {
    final box = await HiveService.getBox<Bill>(_boxName);
    return box.get(id);
  }

  /// Calculate total monthly cost of all active bills/subscriptions
  Future<Map<String, double>> getTotalMonthlyCostByCurrency() async {
    final bills = await getActiveBills();
    final Map<String, double> totals = {};

    for (final bill in bills) {
      double monthlyAmount = bill.defaultAmount;

      // Convert to monthly equivalent
      switch (bill.frequency) {
        case 'weekly':
          monthlyAmount = bill.defaultAmount * 4.33; // ~4.33 weeks/month
          break;
        case 'yearly':
          monthlyAmount = bill.defaultAmount / 12;
          break;
        case 'monthly':
        default:
          monthlyAmount = bill.defaultAmount;
      }

      totals[bill.currency] = (totals[bill.currency] ?? 0) + monthlyAmount;
    }

    return totals;
  }
}
