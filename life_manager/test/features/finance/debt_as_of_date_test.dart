import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/finance/data/models/debt.dart';

void main() {
  group('Debt historical as-of balance', () {
    test('keeps prior day balances unchanged after later payment', () {
      final monday = DateTime(2026, 2, 9, 9, 0);
      final friday = DateTime(2026, 2, 13, 14, 30);

      final debt = Debt(
        name: 'Test Debt',
        categoryId: 'cat-1',
        originalAmount: 100,
        createdAt: monday,
      );

      debt.paymentLogJson = [
        DebtPaymentEntry(
          id: 'p1',
          amount: 50,
          paidAt: friday,
          balanceAfter: 50,
        ).encode(),
      ];

      expect(debt.balanceAsOfDate(DateTime(2026, 2, 8)), 0); // before created
      expect(debt.balanceAsOfDate(DateTime(2026, 2, 9)), 100); // monday
      expect(debt.balanceAsOfDate(DateTime(2026, 2, 12)), 100); // thursday
      expect(debt.balanceAsOfDate(DateTime(2026, 2, 13)), 50); // friday
      expect(debt.balanceAsOfDate(DateTime(2026, 2, 14)), 50); // saturday
    });
  });
}

