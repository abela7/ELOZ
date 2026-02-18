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
      expect(
        ComprehensiveAppBackupService.isFinanceHiveFileName(
          'mbt_moods_v1.hive',
        ),
        isFalse,
      );
      expect(
        ComprehensiveAppBackupService.isFinanceHiveFileName(
          'mbt_mood_entries_v1.hive',
        ),
        isFalse,
      );
    });

    test('filters finance-only preferences and keeps hub/shared keys', () {
      expect(
        ComprehensiveAppBackupService.isFinancePreferenceKeyName(
          'notification_hub_module_settings_v1_finance',
        ),
        isTrue,
      );
      expect(
        ComprehensiveAppBackupService.isFinancePreferenceKeyName(
          'finance_passcode_recovery_only_mode',
        ),
        isTrue,
      );
      expect(
        ComprehensiveAppBackupService.isFinancePreferenceKeyName(
          'notification_hub_history_v1',
        ),
        isFalse,
      );
      expect(
        ComprehensiveAppBackupService.isFinancePreferenceKeyName(
          'tracked_native_alarms_v1',
        ),
        isFalse,
      );
      expect(
        ComprehensiveAppBackupService.isFinancePreferenceKeyName(
          'mbt_mood_reminder_enabled_v1',
        ),
        isFalse,
      );
      expect(
        ComprehensiveAppBackupService.isFinancePreferenceKeyName(
          'mbt_mood_reminder_hour_v1',
        ),
        isFalse,
      );
    });

    test('filters finance secure-storage keys only', () {
      expect(
        ComprehensiveAppBackupService.isFinanceSecureStorageKeyName(
          'finance_passcode_hash_v1',
        ),
        isTrue,
      );
      expect(
        ComprehensiveAppBackupService.isFinanceSecureStorageKeyName(
          'encryption_key_v1',
        ),
        isFalse,
      );
    });

    test('sanitizes and merges hub enabled states for finance-safe restore', () {
      final sanitized =
          ComprehensiveAppBackupService.sanitizeHubEnabledStatesJsonForBackup(
            '{"task":true,"habit":false,"finance":true}',
          );
      expect(sanitized.contains('"finance"'), isFalse);
      expect(sanitized.contains('"task"'), isTrue);
      expect(sanitized.contains('"habit"'), isTrue);

      final merged =
          ComprehensiveAppBackupService.mergeHubEnabledStatesJsonWithPreservedFinance(
            '{"task":false,"habit":true}',
            false,
          );
      expect(merged.contains('"finance":false'), isTrue);
      expect(merged.contains('"task":false'), isTrue);
      expect(merged.contains('"habit":true'), isTrue);

      final mergedFallback =
          ComprehensiveAppBackupService.mergeHubEnabledStatesJsonWithPreservedFinance(
            'not-json',
            true,
          );
      expect(mergedFallback.contains('"finance":true'), isTrue);
    });
  });
}
