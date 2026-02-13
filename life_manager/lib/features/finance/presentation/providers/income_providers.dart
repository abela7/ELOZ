import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/recurring_income.dart';
import '../../data/repositories/recurring_income_repository.dart';
import '../../domain/services/income_service.dart';
import 'finance_providers.dart';
import '../../../../core/notifications/notification_hub.dart';

// ============================================================================
// Repository Providers
// ============================================================================

final recurringIncomeRepositoryProvider = Provider<RecurringIncomeRepository>((ref) {
  return RecurringIncomeRepository();
});

// ============================================================================
// Service Providers
// ============================================================================

final notificationHubProvider = Provider<NotificationHub>((ref) {
  return NotificationHub();
});

final incomeServiceProvider = Provider<IncomeService>((ref) {
  return IncomeService(
    recurringIncomeRepo: ref.watch(recurringIncomeRepositoryProvider),
    transactionRepo: ref.watch(transactionRepositoryProvider),
    accountRepo: ref.watch(accountRepositoryProvider),
    notificationHub: ref.watch(notificationHubProvider),
  );
});

// ============================================================================
// Recurring Income Providers
// ============================================================================
// Note: Income categories now use the unified TransactionCategory system
// from finance_providers.dart (incomeTransactionCategoriesProvider)

final recurringIncomesProvider = StreamProvider<List<RecurringIncome>>((ref) async* {
  final repo = ref.watch(recurringIncomeRepositoryProvider);
  await repo.init();
  
  // Initial load
  yield repo.getAll();
  
  // Listen for changes
  await for (final _ in Stream.periodic(const Duration(seconds: 2))) {
    yield repo.getAll();
  }
});

final activeRecurringIncomesProvider = StreamProvider<List<RecurringIncome>>((ref) async* {
  final repo = ref.watch(recurringIncomeRepositoryProvider);
  await repo.init();
  
  yield repo.getActive();
  
  await for (final _ in Stream.periodic(const Duration(seconds: 2))) {
    yield repo.getActive();
  }
});

final currentlyActiveRecurringIncomesProvider = StreamProvider<List<RecurringIncome>>((ref) async* {
  final repo = ref.watch(recurringIncomeRepositoryProvider);
  await repo.init();
  
  yield repo.getCurrentlyActive();
  
  await for (final _ in Stream.periodic(const Duration(seconds: 2))) {
    yield repo.getCurrentlyActive();
  }
});

final recurringIncomeByIdProvider = Provider.family<RecurringIncome?, String>((ref, id) {
  final incomesAsync = ref.watch(recurringIncomesProvider);
  return incomesAsync.maybeWhen(
    data: (incomes) {
      final matches = incomes.where((i) => i.id == id);
      return matches.isNotEmpty ? matches.first : null;
    },
    orElse: () => null,
  );
});

final recurringIncomesByCategoryProvider = Provider.family<List<RecurringIncome>, String>((ref, categoryId) {
  final incomesAsync = ref.watch(recurringIncomesProvider);
  return incomesAsync.maybeWhen(
    data: (incomes) => incomes.where((i) => i.categoryId == categoryId).toList(),
    orElse: () => [],
  );
});

// ============================================================================
// Income Statistics Providers
// ============================================================================

final incomeStatisticsProvider = FutureProvider.family<IncomeStatistics, IncomeStatisticsParams>((ref, params) async {
  final service = ref.watch(incomeServiceProvider);
  return await service.getStatistics(
    params.startDate,
    params.endDate,
    params.currency,
  );
});

final incomeComparisonProvider = FutureProvider.family<IncomeComparison, IncomeComparisonParams>((ref, params) async {
  final service = ref.watch(incomeServiceProvider);
  return await service.comparePeriods(
    params.period1Start,
    params.period1End,
    params.period2Start,
    params.period2End,
    params.currency,
  );
});

// ============================================================================
// Helper Classes
// ============================================================================

class IncomeStatisticsParams {
  final DateTime startDate;
  final DateTime endDate;
  final String currency;

  IncomeStatisticsParams({
    required this.startDate,
    required this.endDate,
    required this.currency,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IncomeStatisticsParams &&
          runtimeType == other.runtimeType &&
          startDate == other.startDate &&
          endDate == other.endDate &&
          currency == other.currency;

  @override
  int get hashCode => startDate.hashCode ^ endDate.hashCode ^ currency.hashCode;
}

class IncomeComparisonParams {
  final DateTime period1Start;
  final DateTime period1End;
  final DateTime period2Start;
  final DateTime period2End;
  final String currency;

  IncomeComparisonParams({
    required this.period1Start,
    required this.period1End,
    required this.period2Start,
    required this.period2End,
    required this.currency,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IncomeComparisonParams &&
          runtimeType == other.runtimeType &&
          period1Start == other.period1Start &&
          period1End == other.period1End &&
          period2Start == other.period2Start &&
          period2End == other.period2End &&
          currency == other.currency;

  @override
  int get hashCode =>
      period1Start.hashCode ^
      period1End.hashCode ^
      period2Start.hashCode ^
      period2End.hashCode ^
      currency.hashCode;
}
