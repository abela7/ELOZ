import 'package:flutter/material.dart';
import '../models/debt.dart';
import '../models/debt_category.dart';
import '../models/transaction.dart' as finance;
import '../repositories/debt_category_repository.dart';
import '../repositories/debt_repository.dart';
import '../repositories/transaction_repository.dart';
import 'transaction_balance_service.dart';

/// Service for debt management and calculations
class DebtService {
  final DebtRepository _debtRepository;
  final DebtCategoryRepository _categoryRepository;
  final TransactionRepository? _transactionRepository;
  final TransactionBalanceService? _balanceService;

  DebtService(
    this._debtRepository,
    this._categoryRepository, [
    this._transactionRepository,
    this._balanceService,
  ]);

  /// Initialize default debt categories if none exist
  Future<void> initializeDefaultCategories() async {
    final hasCategories = await _categoryRepository.hasCategories();
    if (hasCategories) return;

    final defaults = [
      DebtCategory(
        name: 'Credit Card',
        description: 'Credit card balances',
        icon: Icons.credit_card_rounded,
        colorValue: Colors.red.shade600.value,
        sortOrder: 0,
      ),
      DebtCategory(
        name: 'Personal Loan',
        description: 'Personal loans from banks or individuals',
        icon: Icons.person_rounded,
        colorValue: Colors.orange.shade600.value,
        sortOrder: 1,
      ),
      DebtCategory(
        name: 'Student Loan',
        description: 'Education-related loans',
        icon: Icons.school_rounded,
        colorValue: Colors.blue.shade600.value,
        sortOrder: 2,
      ),
      DebtCategory(
        name: 'Car Loan',
        description: 'Auto financing',
        icon: Icons.directions_car_rounded,
        colorValue: Colors.teal.shade600.value,
        sortOrder: 3,
      ),
      DebtCategory(
        name: 'Mortgage',
        description: 'Home loans',
        icon: Icons.home_rounded,
        colorValue: Colors.green.shade600.value,
        sortOrder: 4,
      ),
      DebtCategory(
        name: 'Medical',
        description: 'Medical bills and healthcare debt',
        icon: Icons.local_hospital_rounded,
        colorValue: Colors.pink.shade600.value,
        sortOrder: 5,
      ),
      DebtCategory(
        name: 'Business',
        description: 'Business-related debt',
        icon: Icons.business_rounded,
        colorValue: Colors.indigo.shade600.value,
        sortOrder: 6,
      ),
      DebtCategory(
        name: 'Other',
        description: 'Other types of debt',
        icon: Icons.more_horiz_rounded,
        colorValue: Colors.grey.shade600.value,
        sortOrder: 7,
      ),
    ];

    for (final category in defaults) {
      await _categoryRepository.createCategory(category);
    }
  }

  /// Get total debt balance grouped by currency
  Future<Map<String, double>> getTotalDebtByCurrency({
    DebtDirection direction = DebtDirection.owed,
  }) async {
    return await _debtRepository.getTotalDebtByCurrency(direction: direction);
  }

  /// Get debt summary for a specific currency
  Future<Map<String, dynamic>> getDebtSummary({
    String? currency,
    DebtDirection direction = DebtDirection.owed,
  }) async {
    final stats = await _debtRepository.getDebtStatistics(direction: direction);
    final debtByCurrency = await _debtRepository.getTotalDebtByCurrency(
      direction: direction,
    );

    return {...stats, 'debtByCurrency': debtByCurrency};
  }

  /// Get debts grouped by category
  Future<Map<String, List<Debt>>> getDebtsGroupedByCategory({
    DebtDirection direction = DebtDirection.owed,
  }) async {
    final categories = await _categoryRepository.getAllCategories();
    final debts = await _debtRepository.getAllDebts(direction: direction);

    final Map<String, List<Debt>> grouped = {};

    for (final category in categories) {
      grouped[category.id] = debts
          .where((d) => d.categoryId == category.id)
          .toList();
    }

    return grouped;
  }

  /// Get category with its debts
  Future<Map<String, dynamic>> getCategoryWithDebts(
    String categoryId, {
    DebtDirection direction = DebtDirection.owed,
  }) async {
    final category = await _categoryRepository.getCategoryById(categoryId);
    if (category == null) return {};

    final debts = await _debtRepository.getDebtsByCategory(
      categoryId,
      direction: direction,
    );
    final totalOwed = debts
        .where((d) => d.isActive)
        .fold<double>(0, (sum, d) => sum + d.currentBalance);

    return {
      'category': category,
      'debts': debts,
      'totalOwed': totalOwed,
      'activeCount': debts.where((d) => d.isActive).length,
      'paidOffCount': debts.where((d) => d.isPaidOff).length,
    };
  }

  /// Create a lending debt and associated expense transaction
  /// Returns the created debt with transactionId set
  Future<Debt> createLendingWithTransaction({
    required Debt debt,
  }) async {
    // First create the debt
    await _debtRepository.createDebt(debt);

    // If transaction repository is available, create expense transaction
    if (_transactionRepository != null && _balanceService != null) {
      final transaction = finance.Transaction(
        title: '${debt.name} (Lending)',
        amount: debt.originalAmount,
        type: 'expense',
        categoryId: debt.categoryId,
        accountId: debt.accountId,
        transactionDate: debt.createdAt,
        currency: debt.currency,
        description: debt.notes != null 
            ? 'Lent to ${debt.creditorName ?? "someone"}\n${debt.notes}'
            : 'Lent to ${debt.creditorName ?? "someone"}',
        isRecurring: false,
        debtId: debt.id, // Link transaction to debt
      );

      await _transactionRepository.createTransaction(transaction);
      await _balanceService.applyTransactionImpact(transaction);

      // Update debt with transaction ID
      final updatedDebt = debt.copyWith(transactionId: transaction.id);
      await _debtRepository.updateDebt(updatedDebt);

      return updatedDebt;
    }

    return debt;
  }

  /// Record a debt payment and optionally create a transaction
  Future<void> recordDebtPayment({
    required String debtId,
    required double amount,
    String? accountId,
    DateTime? paymentDate,
  }) async {
    // Update debt balance
    await _debtRepository.recordPayment(debtId, amount);
  }

  /// Record a debt repayment and create income transaction
  /// For when someone pays back money they owe you (lending repayment)
  Future<void> recordLendingRepayment({
    required String debtId,
    required double amount,
    required String accountId,
    DateTime? paymentDate,
  }) async {
    // Update debt balance
    await _debtRepository.recordPayment(debtId, amount);

    // If transaction repository is available, create income transaction
    if (_transactionRepository != null && _balanceService != null) {
      final debt = await _debtRepository.getDebtById(debtId);
      if (debt == null) return;

      final transaction = finance.Transaction(
        title: '${debt.name} Repayment',
        amount: amount,
        type: 'income',
        categoryId: debt.categoryId, // Use same category
        accountId: accountId,
        transactionDate: paymentDate ?? DateTime.now(),
        currency: debt.currency,
        description: 'Repayment from ${debt.creditorName ?? "borrower"}',
        isRecurring: false,
        debtId: debt.id, // Link transaction to debt
      );

      await _transactionRepository.createTransaction(transaction);
      await _balanceService.applyTransactionImpact(transaction);
    }
  }

  /// Get debts needing attention (overdue or due soon)
  Future<List<Debt>> getDebtsNeedingAttention({
    DebtDirection direction = DebtDirection.owed,
  }) async {
    final overdue = await _debtRepository.getOverdueDebts(direction: direction);
    final dueSoon = await _debtRepository.getDebtsDueSoon(direction: direction);

    // Combine and deduplicate
    final Set<String> ids = {};
    final List<Debt> result = [];

    for (final debt in [...overdue, ...dueSoon]) {
      if (!ids.contains(debt.id)) {
        ids.add(debt.id);
        result.add(debt);
      }
    }

    // Sort by due date (most urgent first)
    result.sort((a, b) {
      if (a.dueDate == null && b.dueDate == null) return 0;
      if (a.dueDate == null) return 1;
      if (b.dueDate == null) return -1;
      return a.dueDate!.compareTo(b.dueDate!);
    });

    return result;
  }

  /// Calculate net worth considering debts
  /// (Total assets - Total debts)
  Future<Map<String, double>> calculateNetWorthByCurrency({
    required Map<String, double> assetsByCurrency,
  }) async {
    final debtsByCurrency = await getTotalDebtByCurrency(
      direction: DebtDirection.owed,
    );

    final Set<String> allCurrencies = {
      ...assetsByCurrency.keys,
      ...debtsByCurrency.keys,
    };

    final Map<String, double> netWorthByCurrency = {};

    for (final currency in allCurrencies) {
      final assets = assetsByCurrency[currency] ?? 0;
      final debts = debtsByCurrency[currency] ?? 0;
      netWorthByCurrency[currency] = assets - debts;
    }

    return netWorthByCurrency;
  }
}
