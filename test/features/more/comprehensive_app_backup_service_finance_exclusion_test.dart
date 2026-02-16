import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/more/data/services/comprehensive_app_backup_service.dart';

void main() {
  group('ComprehensiveAppBackupService finance exclusion', () {
    test('flags finance hive boxes regardless of case style', () {
      const financeBoxNames = <String>[
        'accountsbox',
        'accountsBox',
        'transactionsbox',
        'transactionsBox',
        'transactioncategoriesbox',
        'transactionCategoriesBox',
        'transactiontemplatesbox',
        'transactionTemplatesBox',
        'budgetsbox',
        'budgetsBox',
        'dailybalancesbox',
        'dailyBalancesBox',
        'debtcategoriesbox',
        'debtCategoriesBox',
        'debtsbox',
        'debtsBox',
        'billcategoriesbox',
        'billCategoriesBox',
        'billsbox',
        'billsBox',
        'savingsgoalsbox',
        'savingsGoalsBox',
        'recurring_incomes',
      ];

      for (final boxName in financeBoxNames) {
        expect(
          ComprehensiveAppBackupService.isFinanceHiveBoxName(boxName),
          isTrue,
          reason: 'Finance box "$boxName" must be excluded.',
        );
      }
    });

    test('flags finance hive files and keeps non-finance files', () {
      const financeFiles = <String>[
        'accountsbox.hive',
        'transactionsbox.hive',
        'transactioncategoriesbox.hive',
        'transactiontemplatesbox.hive',
        'budgetsbox.hive',
        'dailybalancesbox.hive',
        'debtcategoriesbox.hive',
        'debtsbox.hive',
        'billcategoriesbox.hive',
        'billsbox.hive',
        'savingsgoalsbox.hive',
        'recurring_incomes.hive',
      ];

      for (final fileName in financeFiles) {
        expect(
          ComprehensiveAppBackupService.isFinanceHiveFileName(fileName),
          isTrue,
          reason: 'Finance file "$fileName" must never be included/restored.',
        );
        expect(
          ComprehensiveAppBackupService.isFinanceHiveFileName(
            fileName.toUpperCase(),
          ),
          isTrue,
          reason: 'Finance file matching must stay case-insensitive.',
        );
      }

      expect(
        ComprehensiveAppBackupService.isFinanceHiveFileName('tasksbox.hive'),
        isFalse,
      );
      expect(
        ComprehensiveAppBackupService.isFinanceHiveFileName('habitsbox.hive'),
        isFalse,
      );
      expect(
        ComprehensiveAppBackupService.isFinanceHiveFileName(
          'universal_notifications.hive',
        ),
        isFalse,
      );
    });
  });
}
