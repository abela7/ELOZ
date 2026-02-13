import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/finance/data/models/budget.dart';

void main() {
  group('Budget period window calculations', () {
    test('monthly budget stays anchored to start day across months', () {
      final budget = Budget(
        name: 'Groceries',
        amount: 500,
        period: 'monthly',
        startDate: DateTime(2026, 1, 15),
      );

      final start = budget.getCurrentPeriodStart(asOf: DateTime(2026, 2, 20));
      final end = budget.getCurrentPeriodEnd(asOf: DateTime(2026, 2, 20));

      expect(start, DateTime(2026, 2, 15));
      expect(end, DateTime(2026, 3, 14));
    });

    test('yearly budget period is anchored to original month/day', () {
      final budget = Budget(
        name: 'Annual Plan',
        amount: 12000,
        period: 'yearly',
        startDate: DateTime(2025, 6, 10),
      );

      final start = budget.getCurrentPeriodStart(asOf: DateTime(2026, 1, 1));
      final end = budget.getCurrentPeriodEnd(asOf: DateTime(2026, 1, 1));

      expect(start, DateTime(2025, 6, 10));
      expect(end, DateTime(2026, 6, 9));
    });

    test('custom budget is active only inside configured date range', () {
      final budget = Budget(
        name: 'Short Trip',
        amount: 800,
        period: 'custom',
        startDate: DateTime(2026, 2, 1),
        endDate: DateTime(2026, 2, 28),
      );

      expect(budget.isInActivePeriodAt(DateTime(2026, 1, 31)), false);
      expect(budget.isInActivePeriodAt(DateTime(2026, 2, 15)), true);
      expect(budget.isInActivePeriodAt(DateTime(2026, 3, 1)), false);
    });

    test('spending percentage can exceed 100 when budget is exceeded', () {
      final budget = Budget(name: 'Test', amount: 100, currentSpent: 150);

      expect(budget.spendingPercentage, 150);
      expect(budget.isExceeded, true);
    });
  });
}
