import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'data/models/transaction.dart';
import 'data/models/transaction_category.dart';
import 'data/models/transaction_template.dart';
import 'data/models/budget.dart';
import 'data/models/account.dart';
import 'data/models/daily_balance.dart';
import 'data/models/debt_category.dart';
import 'data/models/debt.dart';
import 'data/models/bill_category.dart';
import 'data/models/bill.dart';
import 'data/models/savings_goal.dart';
import 'data/models/recurring_income.dart';
// IncomeCategory model deprecated - using TransactionCategory
import '../../data/local/hive/hive_service.dart';
import 'data/repositories/transaction_category_repository.dart';
import 'data/repositories/transaction_repository.dart';
import 'data/repositories/account_repository.dart';
import 'data/repositories/debt_category_repository.dart';
import 'data/repositories/debt_repository.dart';
import 'data/repositories/bill_category_repository.dart';
import 'data/repositories/bill_repository.dart';
import 'data/repositories/recurring_income_repository.dart';
// Income categories now use TransactionCategory system
import 'data/services/default_categories_service.dart';
import 'data/services/finance_settings_service.dart';
import 'data/services/transaction_balance_service.dart';
import 'data/services/recurring_transaction_service.dart';
import 'data/services/debt_service.dart';
import 'data/services/bill_service.dart';
import 'data/services/finance_notification_settings_service.dart';
import 'domain/services/income_service.dart';
import '../../core/notifications/notification_hub.dart';
import 'notifications/finance_notification_adapter.dart';
import 'notifications/finance_notification_scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils/perf_trace.dart';

/// Finance Module - Handles all Finance-related initialization
///
/// This module registers Hive adapters and opens database boxes
/// for the Finance mini-app. Following the modular super-app pattern,
/// each feature module handles its own initialization.
///
/// TypeId Range: 20-30 (reserved for Finance module)
class FinanceModule {
  static bool _initialized = false;
  static bool _boxesPreopened = false;
  static bool _defaultsInitialized = false;
  static bool _recurringProcessed = false;
  static bool _recurringProcessing = false;
  static Future<void>? _initFuture;

  /// Initialize the Finance module
  ///
  /// This should be called during app startup.
  /// It's safe to call multiple times (idempotent).
  static Future<void> init({
    bool deferRecurringProcessing = false,
    bool preOpenBoxes = true,
    bool bootstrapDefaults = true,
  }) async {
    final trace = PerfTrace('FinanceModule.init');
    final inFlight = _initFuture;
    if (inFlight != null) {
      await inFlight;
      if (preOpenBoxes && !_boxesPreopened) {
        await _preOpenBoxes();
      }
      if (bootstrapDefaults && !_defaultsInitialized) {
        await _initializeDefaultData();
      }
      if (!deferRecurringProcessing) {
        await _processRecurringTransactions();
      }
      trace.end('joined_inflight');
      return;
    }

    final run = _runInit(
      deferRecurringProcessing: deferRecurringProcessing,
      preOpenBoxes: preOpenBoxes,
      bootstrapDefaults: bootstrapDefaults,
    );
    _initFuture = run;
    try {
      await run;
      trace.end('done');
    } finally {
      if (identical(_initFuture, run)) {
        _initFuture = null;
      }
    }
  }

  static Future<void> _runInit({
    required bool deferRecurringProcessing,
    required bool preOpenBoxes,
    required bool bootstrapDefaults,
  }) async {
    if (!_initialized) {
      // Register Finance-related Hive adapters
      // TypeIds 20-29 are reserved for Finance module
      if (!Hive.isAdapterRegistered(20)) {
        Hive.registerAdapter(TransactionAdapter());
      }
      if (!Hive.isAdapterRegistered(21)) {
        Hive.registerAdapter(TransactionCategoryAdapter());
      }
      if (!Hive.isAdapterRegistered(22)) {
        Hive.registerAdapter(BudgetAdapter());
      }
      if (!Hive.isAdapterRegistered(23)) {
        Hive.registerAdapter(AccountAdapter());
      }
      if (!Hive.isAdapterRegistered(24)) {
        Hive.registerAdapter(DailyBalanceAdapter());
      }
      if (!Hive.isAdapterRegistered(25)) {
        Hive.registerAdapter(DebtCategoryAdapter());
      }
      if (!Hive.isAdapterRegistered(26)) {
        Hive.registerAdapter(DebtAdapter());
      }
      if (!Hive.isAdapterRegistered(27)) {
        Hive.registerAdapter(TransactionTemplateAdapter());
      }
      if (!Hive.isAdapterRegistered(28)) {
        Hive.registerAdapter(BillCategoryAdapter());
      }
      if (!Hive.isAdapterRegistered(29)) {
        Hive.registerAdapter(BillAdapter());
      }
      if (!Hive.isAdapterRegistered(30)) {
        Hive.registerAdapter(SavingsGoalAdapter());
      }
      if (!Hive.isAdapterRegistered(35)) {
        Hive.registerAdapter(RecurringIncomeAdapter());
      }
      // typeId 36 (IncomeCategory) is now deprecated - using TransactionCategory instead

      _initialized = true;
    }

    // Register this mini app with the Notification Hub.
    NotificationHub().registerAdapter(FinanceNotificationAdapter());

    if (preOpenBoxes) {
      await _preOpenBoxes();
    }

    if (bootstrapDefaults) {
      await _initializeDefaultData();
    }

    // Run bill category migration (one-time)
    await _migrateBillCategories();

    // Run debt category migration (one-time)
    await _migrateDebtCategories();

    if (!deferRecurringProcessing) {
      await _processRecurringTransactions();
    }
  }

  /// Call after a full data wipe to recreate default categories and a default
  /// Cash account. Settings (currency, security, notifications) are preserved.
  static Future<void> forceReinitializeDefaultsAfterWipe() async {
    _defaultsInitialized = false;
    await _preOpenBoxes();
    await _initializeDefaultData();
  }

  /// Run recurring transaction processing after startup.
  static Future<void> runPostStartupMaintenance() async {
    await init(
      deferRecurringProcessing: true,
      preOpenBoxes: true,
      bootstrapDefaults: true,
    );
    await _processRecurringTransactions();
    await processRecurringIncome(respectStartupSyncPreference: true);
  }

  static Future<void> _preOpenBoxes() async {
    if (_boxesPreopened) return;
    final trace = PerfTrace('FinanceModule.preOpenBoxes');
    await Future.wait([
      HiveService.getBox<Transaction>('transactionsBox'),
      HiveService.getBox<TransactionCategory>('transactionCategoriesBox'),
      HiveService.getBox<TransactionTemplate>('transactionTemplatesBox'),
      HiveService.getBox<Budget>('budgetsBox'),
      HiveService.getBox<Account>('accountsBox'),
      HiveService.getBox<DailyBalance>('dailyBalancesBox'),
      HiveService.getBox<DebtCategory>('debtCategoriesBox'),
      HiveService.getBox<Debt>('debtsBox'),
      HiveService.getBox<BillCategory>('billCategoriesBox'),
      HiveService.getBox<Bill>('billsBox'),
      HiveService.getBox<SavingsGoal>('savingsGoalsBox'),
      HiveService.getBox<RecurringIncome>('recurring_incomes'),
    ], eagerError: true);
    // 'income_categories' box deprecated - using 'transaction_categories' instead
    _boxesPreopened = true;
    trace.end('done');
  }

  static Future<void> _initializeDefaultData() async {
    if (_defaultsInitialized) return;
    await _preOpenBoxes();

    // Initialize default categories
    final categoryRepo = TransactionCategoryRepository();
    final defaultCategoriesService = DefaultCategoriesService(categoryRepo);
    await defaultCategoriesService.initializeDefaultCategories();

    // Initialize default account if none exist
    final accountRepo = AccountRepository();
    final existingAccounts = await accountRepo.getAllAccounts();
    if (existingAccounts.isEmpty) {
      final settingsService = FinanceSettingsService();
      final defaultCurrency = await settingsService.getDefaultCurrency();
      final defaultAccount = Account(
        name: 'Cash',
        type: 'cash',
        balance: 0.0,
        currency: defaultCurrency,
        iconCodePoint: Icons.account_balance_wallet_rounded.codePoint,
        iconFontFamily: 'MaterialIcons',
        colorValue: const Color(0xFFCDAF56).toARGB32(),
        isDefault: true,
      );
      await accountRepo.createAccount(defaultAccount);
    }

    // Initialize default debt categories
    final debtCategoryRepo = DebtCategoryRepository();
    final debtRepo = DebtRepository();
    final debtService = DebtService(debtRepo, debtCategoryRepo);
    await debtService.initializeDefaultCategories();

    // Initialize default bill categories
    final billCategoryRepo = BillCategoryRepository();
    final billRepo = BillRepository();
    final billService = BillService(billRepo, billCategoryRepo);
    await billService.initializeDefaultCategories();

    // Income categories now use the unified TransactionCategory system
    // (seeded via DefaultCategoriesService above)

    _defaultsInitialized = true;
  }

  /// Migrate BillCategory entries to TransactionCategory (one-time migration)
  static Future<void> _migrateBillCategories() async {
    final prefs = await SharedPreferences.getInstance();
    const migrationKey = 'bill_category_migrated_v1';

    // Check if migration already completed
    if (prefs.getBool(migrationKey) == true) {
      return;
    }

    try {
      debugPrint('Starting bill category migration...');

      // Get repositories
      final billCategoryRepo = BillCategoryRepository();
      final transactionCategoryRepo = TransactionCategoryRepository();
      final billRepo = BillRepository();
      final transactionRepo = TransactionRepository();

      // Get all existing bill categories
      final billCategories = await billCategoryRepo.getAllCategories();

      if (billCategories.isEmpty) {
        debugPrint('No bill categories to migrate');
        await prefs.setBool(migrationKey, true);
        return;
      }

      final existingExpenseCategories = await transactionCategoryRepo
          .getAllCategories();
      final existingByName = <String, TransactionCategory>{};
      for (final category in existingExpenseCategories) {
        if (category.type == 'expense') {
          existingByName[category.name.trim().toLowerCase()] = category;
        }
      }

      // Map old BillCategory IDs to new TransactionCategory IDs
      final Map<String, String> categoryIdMap = {};

      // Create TransactionCategory for each BillCategory
      for (final billCat in billCategories) {
        final normalizedName = billCat.name.trim().toLowerCase();
        final existing = existingByName[normalizedName];

        if (existing != null) {
          // Use existing category
          categoryIdMap[billCat.id] = existing.id;
          debugPrint(
            'Mapped bill category "${billCat.name}" to existing transaction category',
          );
        } else {
          // Create new TransactionCategory
          final newCategory = TransactionCategory(
            name: billCat.name,
            description: 'Bill/Subscription category (migrated)',
            type: 'expense',
            iconCodePoint: billCat.iconCodePoint,
            iconFontFamily: billCat.iconFontFamily,
            iconFontPackage: billCat.iconFontPackage,
            colorValue: billCat.colorValue,
            isActive: billCat.isActive,
            sortOrder: billCat.sortOrder,
            isSystemCategory: false,
          );

          await transactionCategoryRepo.createCategory(newCategory);
          categoryIdMap[billCat.id] = newCategory.id;
          existingByName[normalizedName] = newCategory;
          debugPrint('Created new transaction category for "${billCat.name}"');
        }
      }

      // Update all bills to use new category IDs
      final allBills = await billRepo.getAllBills();
      for (final bill in allBills) {
        final newCategoryId = categoryIdMap[bill.categoryId];
        if (newCategoryId != null && newCategoryId != bill.categoryId) {
          bill.categoryId = newCategoryId;
          await billRepo.updateBill(bill);
          debugPrint('Updated bill "${bill.name}" category ID');
        }
      }

      // Update existing transactions that used old BillCategory IDs
      final allTransactions = await transactionRepo.getAllTransactions();
      int updatedCount = 0;
      for (final transaction in allTransactions) {
        if (transaction.categoryId != null &&
            categoryIdMap.containsKey(transaction.categoryId)) {
          final newCategoryId = categoryIdMap[transaction.categoryId!];
          if (newCategoryId != null &&
              newCategoryId != transaction.categoryId) {
            transaction.categoryId = newCategoryId;
            await transactionRepo.updateTransaction(transaction);
            updatedCount++;
          }
        }
      }

      debugPrint(
        'Bill category migration completed: ${billCategories.length} categories migrated, $updatedCount transactions updated',
      );

      // Mark migration as complete
      await prefs.setBool(migrationKey, true);
    } catch (e, stackTrace) {
      debugPrint('Error during bill category migration: $e');
      debugPrint('Stack trace: $stackTrace');
      // Don't mark as complete so it can retry next time
    }
  }

  /// Migrate DebtCategory entries to TransactionCategory (one-time migration)
  /// Lending debts become expense categories
  static Future<void> _migrateDebtCategories() async {
    final prefs = await SharedPreferences.getInstance();
    const migrationKey = 'debt_category_migrated_v1';

    // Check if migration already completed
    if (prefs.getBool(migrationKey) == true) {
      return;
    }

    try {
      debugPrint('Starting debt category migration...');

      // Get repositories
      final debtCategoryRepo = DebtCategoryRepository();
      final transactionCategoryRepo = TransactionCategoryRepository();
      final debtRepo = DebtRepository();
      final transactionRepo = TransactionRepository();

      // Get all existing debt categories
      final debtCategories = await debtCategoryRepo.getAllCategories();

      if (debtCategories.isEmpty) {
        debugPrint('No debt categories to migrate');
        await prefs.setBool(migrationKey, true);
        return;
      }

      final existingExpenseCategories = await transactionCategoryRepo
          .getAllCategories();
      final existingByName = <String, TransactionCategory>{};
      for (final category in existingExpenseCategories) {
        if (category.type == 'expense') {
          existingByName[category.name.trim().toLowerCase()] = category;
        }
      }

      // Map old DebtCategory IDs to new TransactionCategory IDs
      final Map<String, String> categoryIdMap = {};

      // Create TransactionCategory for each DebtCategory
      for (final debtCat in debtCategories) {
        final normalizedName = debtCat.name.trim().toLowerCase();
        final existing = existingByName[normalizedName];

        if (existing != null) {
          // Use existing category
          categoryIdMap[debtCat.id] = existing.id;
          debugPrint(
            'Mapped debt category "${debtCat.name}" to existing transaction category',
          );
        } else {
          // Create new TransactionCategory
          final newCategory = TransactionCategory(
            name: debtCat.name,
            description: 'Lending category (migrated)',
            type: 'expense',
            iconCodePoint: debtCat.iconCodePoint,
            iconFontFamily: debtCat.iconFontFamily,
            iconFontPackage: debtCat.iconFontPackage,
            colorValue: debtCat.colorValue,
            isActive: debtCat.isActive,
            sortOrder: debtCat.sortOrder,
            isSystemCategory: false,
          );

          await transactionCategoryRepo.createCategory(newCategory);
          categoryIdMap[debtCat.id] = newCategory.id;
          existingByName[normalizedName] = newCategory;
          debugPrint('Created new transaction category for "${debtCat.name}"');
        }
      }

      // Update all debts to use new category IDs
      final allDebts = await debtRepo.getAllDebts();
      for (final debt in allDebts) {
        final newCategoryId = categoryIdMap[debt.categoryId];
        if (newCategoryId != null && newCategoryId != debt.categoryId) {
          debt.categoryId = newCategoryId;
          await debtRepo.updateDebt(debt);
          debugPrint('Updated debt "${debt.name}" category ID');
        }
      }

      // Update existing transactions that used old DebtCategory IDs
      final allTransactions = await transactionRepo.getAllTransactions();
      int updatedCount = 0;
      for (final transaction in allTransactions) {
        if (transaction.categoryId != null &&
            categoryIdMap.containsKey(transaction.categoryId)) {
          final newCategoryId = categoryIdMap[transaction.categoryId!];
          if (newCategoryId != null &&
              newCategoryId != transaction.categoryId) {
            transaction.categoryId = newCategoryId;
            await transactionRepo.updateTransaction(transaction);
            updatedCount++;
          }
        }
      }

      debugPrint(
        'Debt category migration completed: ${debtCategories.length} categories migrated, $updatedCount transactions updated',
      );

      // Mark migration as complete
      await prefs.setBool(migrationKey, true);
    } catch (e, stackTrace) {
      debugPrint('Error during debt category migration: $e');
      debugPrint('Stack trace: $stackTrace');
      // Don't mark as complete so it can retry next time
    }
  }

  static Future<void> _processRecurringTransactions() async {
    if (_recurringProcessed || _recurringProcessing) return;
    _recurringProcessing = true;
    try {
      final transactionRepo = TransactionRepository();
      final accountRepo = AccountRepository();
      final balanceService = TransactionBalanceService(
        accountRepo,
        transactionRepo,
      );
      final recurringService = RecurringTransactionService(
        transactionRepo,
        balanceService,
      );
      await recurringService.processRecurringTransactions();
      _recurringProcessed = true;
    } finally {
      _recurringProcessing = false;
    }
  }

  /// Process recurring income and schedule notifications for the next 6 months.
  /// This should be called on app startup and periodically (e.g., weekly).
  static Future<void> processRecurringIncome({
    bool respectStartupSyncPreference = false,
  }) async {
    try {
      final recurringIncomeRepo = RecurringIncomeRepository();
      await recurringIncomeRepo.init();
      final transactionRepo = TransactionRepository();
      final accountRepo = AccountRepository();
      final notificationHub = NotificationHub();

      final incomeService = IncomeService(
        recurringIncomeRepo: recurringIncomeRepo,
        transactionRepo: transactionRepo,
        accountRepo: accountRepo,
        notificationHub: notificationHub,
      );

      // Process any pending income transactions (for today)
      await incomeService.processPendingRecurringIncome();
      final scheduler = FinanceNotificationScheduler();
      final settingsService = FinanceNotificationSettingsService();
      final settings = await settingsService.load();
      final shouldSync =
          !respectStartupSyncPreference || settings.syncOnStartup;

      if (shouldSync) {
        final result = await scheduler.syncSchedules();
        debugPrint(
          'Finance notifications synced: '
          'cancelled=${result.cancelled}, '
          'scheduled=${result.scheduled}, '
          'failed=${result.failed}',
        );
      }
    } catch (e) {
      debugPrint('Error processing recurring income: $e');
    }
  }

  /// Refresh recurring income notifications.
  /// Call this when a recurring income is created, updated, or deleted.
  static Future<void> refreshIncomeNotifications() async {
    await processRecurringIncome(respectStartupSyncPreference: false);
  }

  /// Refresh finance schedules in Notification Hub.
  /// Call this after debt/bill reminder-related changes.
  static Future<void> refreshFinanceNotifications() async {
    try {
      await FinanceNotificationScheduler().syncSchedules();
    } catch (e) {
      debugPrint('Error refreshing finance notifications: $e');
    }
  }

  /// Check if the module is initialized
  static bool get isInitialized => _initialized;

  /// Hive typeId range reserved for Finance module: 20-30, 35-36
  /// - 20: Transaction
  /// - 21: TransactionCategory
  /// - 22: Budget
  /// - 23: Account
  /// - 24: DailyBalance
  /// - 25: DebtCategory
  /// - 26: Debt
  /// - 27: TransactionTemplate
  /// - 28: BillCategory
  /// - 29: Bill
  /// - 30: SavingsGoal
  /// - 35: RecurringIncome
  /// - 36: IncomeCategory
  static const int typeIdRangeStart = 20;
  static const int typeIdRangeEnd = 30;
  static const int typeIdExtendedStart = 35;
  static const int typeIdExtendedEnd = 36;
}
