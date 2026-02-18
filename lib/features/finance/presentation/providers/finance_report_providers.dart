import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/finance_report_service.dart';
import '../../data/services/finance_report_models.dart';
import 'finance_providers.dart';

/// Finance report service provider
final financeReportServiceProvider = Provider<FinanceReportService>((ref) {
  return FinanceReportService(
    transactionRepo: ref.watch(transactionRepositoryProvider),
    accountRepo: ref.watch(accountRepositoryProvider),
    categoryRepo: ref.watch(transactionCategoryRepositoryProvider),
    dailyBalanceService: ref.watch(dailyBalanceServiceProvider),
    budgetTracker: ref.watch(budgetTrackerServiceProvider),
    debtRepo: ref.watch(debtRepositoryProvider),
    billRepo: ref.watch(billRepositoryProvider),
    savingsRepo: ref.watch(savingsGoalRepositoryProvider),
    statsService: ref.watch(financeStatisticsServiceProvider),
  );
});

/// Daily report provider
final dailyReportProvider =
    FutureProvider.family<DailyReportData, ({DateTime date, String currency})>(
  (ref, params) async {
    final service = ref.watch(financeReportServiceProvider);
    return service.getDailyReport(params.date, params.currency);
  },
);

/// Weekly report provider
final weeklyReportProvider =
    FutureProvider.family<WeeklyReportData, ({DateTime weekStart, String currency})>(
  (ref, params) async {
    final service = ref.watch(financeReportServiceProvider);
    return service.getWeeklyReport(params.weekStart, params.currency);
  },
);

/// Monthly report provider
final monthlyReportProvider =
    FutureProvider.family<MonthlyReportData, ({DateTime month, String currency})>(
  (ref, params) async {
    final service = ref.watch(financeReportServiceProvider);
    return service.getMonthlyReport(params.month, params.currency);
  },
);

/// Yearly report provider
final yearlyReportProvider =
    FutureProvider.family<YearlyReportData, ({int year, String currency})>(
  (ref, params) async {
    final service = ref.watch(financeReportServiceProvider);
    return service.getYearlyReport(params.year, params.currency);
  },
);

/// Hub summaries provider for the report landing page
final financeReportHubSummariesProvider =
    FutureProvider.family<Map<String, Map<String, dynamic>>, String>((ref, currency) async {
  final service = ref.watch(financeReportServiceProvider);
  return service.getHubSummaries(currency);
});
