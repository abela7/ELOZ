import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/sleep_record.dart';
import '../../data/models/day_sleep_summary.dart';
import '../../data/models/sleep_factor.dart';
import '../../data/models/sleep_template.dart';
import '../../data/models/sleep_statistics.dart';
import '../../data/models/sleep_period_report.dart';
import '../../data/models/sleep_weekly_report.dart';
import '../../data/models/sleep_debt_consistency.dart';
import '../../data/repositories/sleep_record_repository.dart';
import '../../data/services/sleep_debt_consistency_service.dart';
import '../../data/services/sleep_debt_report_service.dart';
import '../../data/services/sleep_correlation_service.dart';
import '../../data/models/sleep_correlation_insight.dart';
import '../../data/repositories/sleep_factor_repository.dart';
import '../../data/repositories/sleep_template_repository.dart';
import '../../data/services/sleep_statistics_service.dart';
import '../../data/services/sleep_scoring_service.dart';
import '../../data/services/sleep_period_report_service.dart';
import '../../data/services/sleep_weekly_report_service.dart';
import '../../data/services/sleep_reminder_service.dart';
import '../../data/services/sleep_target_service.dart';
import '../../data/services/wind_down_schedule_service.dart';
import '../../data/services/low_sleep_reminder_service.dart';

// ============================================================================
// Repository Providers
// ============================================================================

/// Sleep Record Repository Provider
final sleepRecordRepositoryProvider = Provider<SleepRecordRepository>((ref) {
  return SleepRecordRepository();
});

/// Sleep Factor Repository Provider
final sleepFactorRepositoryProvider = Provider<SleepFactorRepository>((ref) {
  return SleepFactorRepository();
});

/// Sleep Template Repository Provider
final sleepTemplateRepositoryProvider = Provider<SleepTemplateRepository>((ref) {
  return SleepTemplateRepository();
});

// ============================================================================
// Service Providers
// ============================================================================

/// Sleep Statistics Service Provider
final sleepStatisticsServiceProvider = Provider<SleepStatisticsService>((ref) {
  return SleepStatisticsService();
});

/// Sleep scoring service provider (target-aware scoring).
final sleepScoringServiceProvider = Provider<SleepScoringService>((ref) {
  return SleepScoringService();
});

/// Sleep weekly report service provider.
final sleepWeeklyReportServiceProvider = Provider<SleepWeeklyReportService>((ref) {
  final scoring = ref.watch(sleepScoringServiceProvider);
  return SleepWeeklyReportService(scoringService: scoring);
});

/// Sleep period report service provider (weekend/month/year/custom range).
final sleepPeriodReportServiceProvider = Provider<SleepPeriodReportService>((ref) {
  final scoring = ref.watch(sleepScoringServiceProvider);
  return SleepPeriodReportService(scoringService: scoring);
});

/// Sleep reminders service provider.
final sleepReminderServiceProvider = Provider<SleepReminderService>((ref) {
  return SleepReminderService();
});

/// Sleep target service (single target + thresholds for all records).
final sleepTargetServiceProvider = Provider<SleepTargetService>((ref) {
  return SleepTargetService();
});

/// Wind-down schedule service (bedtime per day + reminder offset).
final windDownScheduleServiceProvider = Provider<WindDownScheduleService>((ref) {
  return WindDownScheduleService();
});

/// Low-sleep reminder: notify when sleep < threshold (user-configurable).
final lowSleepReminderServiceProvider = Provider<LowSleepReminderService>((ref) {
  return LowSleepReminderService();
});

/// Low-sleep reminder settings (enabled + threshold) for UI binding.
final lowSleepReminderSettingsProvider =
    FutureProvider<({bool enabled, double threshold, double hoursAfterWake})>((ref) async {
  final service = ref.watch(lowSleepReminderServiceProvider);
  return (
    enabled: await service.isEnabled(),
    threshold: await service.getThresholdHours(),
    hoursAfterWake: await service.getHoursAfterWake(),
  );
});

/// Sleep target settings (target hours + dangerous/poor/healthy thresholds).
final sleepTargetSettingsProvider = FutureProvider<SleepTargetSettings>((ref) async {
  final service = ref.watch(sleepTargetServiceProvider);
  return service.getSettings();
});

/// Sleep debt + consistency service (Phase 1).
final sleepDebtConsistencyServiceProvider =
    Provider<SleepDebtConsistencyService>((ref) {
  final repository = ref.watch(sleepRecordRepositoryProvider);
  return SleepDebtConsistencyService(repository: repository);
});

/// Sleep debt report service (daily/weekly/monthly/yearly/all-time breakdowns).
final sleepDebtReportServiceProvider =
    Provider<SleepDebtReportService>((ref) {
  final repository = ref.watch(sleepRecordRepositoryProvider);
  return SleepDebtReportService(repository: repository);
});

/// Sleep correlation service (Phase 2 - factor insights).
final sleepCorrelationServiceProvider =
    Provider<SleepCorrelationService>((ref) {
  final repository = ref.watch(sleepRecordRepositoryProvider);
  return SleepCorrelationService(repository: repository);
});

/// Factor correlation insights for the last 30 days.
/// Invalidates when records change.
final sleepCorrelationInsightsProvider =
    FutureProvider<SleepCorrelationInsights>((ref) async {
  ref.watch(sleepRecordsProvider);
  final service = ref.watch(sleepCorrelationServiceProvider);
  return service.getInsights();
});

/// Factor correlation insights for a specific date range (Report Factors tab).
/// Invalidates when records change.
final sleepCorrelationInsightsForRangeProvider =
    FutureProvider.family<SleepCorrelationInsights,
        ({DateTime start, DateTime end})>((ref, range) async {
  ref.watch(sleepRecordsProvider);
  final service = ref.watch(sleepCorrelationServiceProvider);
  return service.getInsights(
    startDate: range.start,
    endDate: range.end,
  );
});

/// Sleep debt and consistency for a 7-day window ending on [referenceDate].
/// Invalidates when records change via sleepRecordsProvider dependency.
final sleepDebtConsistencyProvider =
    FutureProvider.family<SleepDebtConsistency, DateTime>((ref, referenceDate) async {
  ref.watch(sleepRecordsProvider);
  final service = ref.watch(sleepDebtConsistencyServiceProvider);
  final settings = await ref.watch(sleepTargetSettingsProvider.future);
  return service.calculate(
    referenceDate: referenceDate,
    targetHours: settings.targetHours,
  );
});

// ============================================================================
// Data Providers - Sleep Records
// ============================================================================

/// Stream provider for all sleep records
final sleepRecordsStreamProvider = StreamProvider<List<SleepRecord>>((ref) {
  final repository = ref.watch(sleepRecordRepositoryProvider);
  return repository.watchAll();
});

/// Future provider for all sleep records
final sleepRecordsProvider = FutureProvider<List<SleepRecord>>((ref) async {
  final repository = ref.watch(sleepRecordRepositoryProvider);
  return repository.getAll();
});

/// Future provider for main sleep records (excluding naps)
final mainSleepRecordsProvider = FutureProvider<List<SleepRecord>>((ref) async {
  final repository = ref.watch(sleepRecordRepositoryProvider);
  return repository.getMainSleepRecords();
});

/// Future provider for nap records
final napRecordsProvider = FutureProvider<List<SleepRecord>>((ref) async {
  final repository = ref.watch(sleepRecordRepositoryProvider);
  return repository.getNapRecords();
});

/// Provider for sleep records by date
final sleepRecordsByDateProvider =
    FutureProvider.family<List<SleepRecord>, DateTime>((ref, date) async {
  final repository = ref.watch(sleepRecordRepositoryProvider);
  return repository.getByDate(date);
});

/// Provider for sleep records by date range
final sleepRecordsByDateRangeProvider = FutureProvider.family<
    List<SleepRecord>,
    ({DateTime startDate, DateTime endDate})>((ref, params) async {
  final repository = ref.watch(sleepRecordRepositoryProvider);
  return repository.getByDateRange(params.startDate, params.endDate);
});

/// Provider for this week's sleep records
final thisWeekSleepRecordsProvider = FutureProvider<List<SleepRecord>>((ref) async {
  final repository = ref.watch(sleepRecordRepositoryProvider);
  return repository.getThisWeek();
});

/// Provider for this month's sleep records
final thisMonthSleepRecordsProvider =
    FutureProvider<List<SleepRecord>>((ref) async {
  final repository = ref.watch(sleepRecordRepositoryProvider);
  return repository.getThisMonth();
});

/// Provider for last N days sleep records
final lastNDaysSleepRecordsProvider =
    FutureProvider.family<List<SleepRecord>, int>((ref, days) async {
  final repository = ref.watch(sleepRecordRepositoryProvider);
  return repository.getLastNDays(days);
});

/// Provider for latest sleep record
final latestSleepRecordProvider = FutureProvider<SleepRecord?>((ref) async {
  final repository = ref.watch(sleepRecordRepositoryProvider);
  return repository.getLatest();
});

/// Provider for sleep record by ID
final sleepRecordByIdProvider =
    FutureProvider.family<SleepRecord?, String>((ref, id) async {
  final repository = ref.watch(sleepRecordRepositoryProvider);
  return repository.getById(id);
});

/// Stream provider for sleep record by ID
final sleepRecordStreamByIdProvider =
    StreamProvider.family<SleepRecord?, String>((ref, id) {
  final repository = ref.watch(sleepRecordRepositoryProvider);
  return repository.watchById(id);
});

/// Provider for all unique sleep tags
final sleepTagsProvider = FutureProvider<List<String>>((ref) async {
  final repository = ref.watch(sleepRecordRepositoryProvider);
  return repository.getAllTags();
});

// ============================================================================
// Statistics Providers
// ============================================================================

/// Provider for overall sleep statistics (last 365 days for performance).
/// Scoped to avoid loading years of data; sufficient for dashboard metrics.
final overallSleepStatisticsProvider =
    FutureProvider<SleepStatistics>((ref) async {
  final repository = ref.watch(sleepRecordRepositoryProvider);
  final service = ref.watch(sleepStatisticsServiceProvider);
  final targetService = ref.watch(sleepTargetServiceProvider);

  final records = await repository.getLastNDays(365);
  final settings = await targetService.getSettings();

  return service.calculateStatistics(records, targetHours: settings.targetHours);
});

/// Provider for sleep statistics by date range
final sleepStatisticsByDateRangeProvider = FutureProvider.family<
    SleepStatistics,
    ({DateTime startDate, DateTime endDate})>((ref, params) async {
  final repository = ref.watch(sleepRecordRepositoryProvider);
  final service = ref.watch(sleepStatisticsServiceProvider);
  final targetService = ref.watch(sleepTargetServiceProvider);

  final records =
      await repository.getByDateRange(params.startDate, params.endDate);
  final settings = await targetService.getSettings();

  return service.calculateStatistics(
    records,
    startDate: params.startDate,
    endDate: params.endDate,
    targetHours: settings.targetHours,
  );
});

/// Provider for this week's sleep statistics
final thisWeekSleepStatisticsProvider =
    FutureProvider<SleepStatistics>((ref) async {
  final repository = ref.watch(sleepRecordRepositoryProvider);
  final service = ref.watch(sleepStatisticsServiceProvider);
  final targetService = ref.watch(sleepTargetServiceProvider);

  final records = await repository.getThisWeek();
  final settings = await targetService.getSettings();

  final now = DateTime.now();
  final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
  final startDate = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
  final endDate = startDate.add(const Duration(days: 6));

  return service.calculateStatistics(
    records,
    startDate: startDate,
    endDate: endDate,
    targetHours: settings.targetHours,
  );
});

/// Provider for this month's sleep statistics
final thisMonthSleepStatisticsProvider =
    FutureProvider<SleepStatistics>((ref) async {
  final repository = ref.watch(sleepRecordRepositoryProvider);
  final service = ref.watch(sleepStatisticsServiceProvider);
  final targetService = ref.watch(sleepTargetServiceProvider);

  final records = await repository.getThisMonth();
  final settings = await targetService.getSettings();

  final now = DateTime.now();
  final startDate = DateTime(now.year, now.month, 1);
  final endDate = DateTime(now.year, now.month + 1, 0);

  return service.calculateStatistics(
    records,
    startDate: startDate,
    endDate: endDate,
    targetHours: settings.targetHours,
  );
});

/// Provider for last N days sleep statistics
final lastNDaysSleepStatisticsProvider =
    FutureProvider.family<SleepStatistics, int>((ref, days) async {
  final repository = ref.watch(sleepRecordRepositoryProvider);
  final service = ref.watch(sleepStatisticsServiceProvider);
  final targetService = ref.watch(sleepTargetServiceProvider);

  final records = await repository.getLastNDays(days);
  final settings = await targetService.getSettings();

  final endDate = DateTime.now();
  final startDate = endDate.subtract(Duration(days: days));

  return service.calculateStatistics(
    records,
    startDate: startDate,
    endDate: endDate,
    targetHours: settings.targetHours,
  );
});

/// Provider for sleep trend (last N days)
final sleepTrendProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>((ref, days) async {
  final repository = ref.watch(sleepRecordRepositoryProvider);
  final service = ref.watch(sleepStatisticsServiceProvider);

  final records = await repository.getLastNDays(days);

  return service.getSleepTrend(records, days);
});

/// Provider for sleep recommendations
final sleepRecommendationsProvider =
    FutureProvider<List<String>>((ref) async {
  final repository = ref.watch(sleepRecordRepositoryProvider);
  final service = ref.watch(sleepStatisticsServiceProvider);

  final recentRecords = await repository.getLastNDays(7);
  final stats = await ref.watch(overallSleepStatisticsProvider.future);

  return service.getRecommendations(stats, recentRecords);
});

/// Provider for sleep debt
final sleepDebtProvider = FutureProvider<double>((ref) async {
  final repository = ref.watch(sleepRecordRepositoryProvider);
  final service = ref.watch(sleepStatisticsServiceProvider);
  final targetService = ref.watch(sleepTargetServiceProvider);

  final records = await repository.getLastNDays(30);
  final settings = await targetService.getSettings();

  return service.calculateSleepDebt(records, targetHours: settings.targetHours);
});

/// Weekly report for a specific week start (Monday).
final sleepGoalWeeklyReportProvider =
    FutureProvider.family<SleepWeeklyReport, DateTime>((ref, weekStart) async {
  final normalizedWeekStart =
      DateTime(weekStart.year, weekStart.month, weekStart.day);
  final weekEnd = normalizedWeekStart.add(const Duration(days: 6));

  final recordRepo = ref.watch(sleepRecordRepositoryProvider);
  final targetService = ref.watch(sleepTargetServiceProvider);
  final reportService = ref.watch(sleepWeeklyReportServiceProvider);

  final records = await recordRepo.getByDateRange(normalizedWeekStart, weekEnd);
  final settings = await targetService.getSettings();

  return reportService.calculateWeeklyReport(
    weekStart: normalizedWeekStart,
    records: records,
    targetHours: settings.targetHours,
  );
});

/// Weekly report for current week.
final thisWeekSleepGoalReportProvider = FutureProvider<SleepWeeklyReport>((ref) async {
  final now = DateTime.now();
  final monday = now.subtract(Duration(days: now.weekday - 1));
  final weekStart = DateTime(monday.year, monday.month, monday.day);
  return ref.watch(sleepGoalWeeklyReportProvider(weekStart).future);
});

/// Period report for any date range.
final sleepPeriodReportProvider = FutureProvider.family<
    SleepPeriodReport,
    ({DateTime startDate, DateTime endDate})>((ref, range) async {
  final start = DateTime(
    range.startDate.year,
    range.startDate.month,
    range.startDate.day,
  );
  final end = DateTime(
    range.endDate.year,
    range.endDate.month,
    range.endDate.day,
  );

  final recordRepo = ref.watch(sleepRecordRepositoryProvider);
  final targetService = ref.watch(sleepTargetServiceProvider);
  final reportService = ref.watch(sleepPeriodReportServiceProvider);

  final records = await recordRepo.getByDateRange(start, end);
  final settings = await targetService.getSettings();

  return reportService.calculatePeriodReport(
    startDate: start,
    endDate: end,
    records: records,
    targetHours: settings.targetHours,
  );
});

// ============================================================================
// Filter State Providers
// ============================================================================

/// State provider for selected date filter
final selectedDateFilterProvider = StateProvider<DateTime>((ref) {
  return DateTime.now();
});

/// State provider for date range filter
final dateRangeFilterProvider = StateProvider<({DateTime start, DateTime end})>((ref) {
  final now = DateTime.now();
  final start = now.subtract(const Duration(days: 7));
  return (start: start, end: now);
});

/// State provider for selected quality filter
final selectedQualityFilterProvider = StateProvider<String?>((ref) => null);

/// State provider for tag filter
final selectedTagFilterProvider = StateProvider<String?>((ref) => null);

/// State provider for show naps filter
final showNapsFilterProvider = StateProvider<bool>((ref) => false);

// ============================================================================
// Sleep Calendar Providers
// ============================================================================

/// Monthly sleep calendar: map of date -> DaySleepSummary for the visible month.
/// Used by Sleep Calendar screen for day cell heatmap and indicators.
final monthlySleepCalendarProvider = FutureProvider.family<
    Map<DateTime, DaySleepSummary>,
    ({int year, int month})>((ref, params) async {
  ref.watch(sleepRecordsProvider);

  final startDate = DateTime(params.year, params.month, 1);
  final lastDay = DateTime(params.year, params.month + 1, 0);
  final endDate = DateTime(
    lastDay.year,
    lastDay.month,
    lastDay.day,
    23,
    59,
    59,
  );

  final records = await ref.read(
    sleepRecordsByDateRangeProvider(
      (startDate: startDate, endDate: endDate),
    ).future,
  );

  final Map<DateTime, DaySleepSummary> map = {};
  final byDate = <DateTime, List<SleepRecord>>{};

  for (final r in records) {
    final key = DateTime(r.sleepDate.year, r.sleepDate.month, r.sleepDate.day);
    byDate.putIfAbsent(key, () => []).add(r);
  }

  for (final entry in byDate.entries) {
    final dayRecords = entry.value;
    final mainRecords = dayRecords.where((r) => !r.isNap).toList();
    final naps = dayRecords.where((r) => r.isNap).toList();

    if (mainRecords.isEmpty) {
      if (naps.isNotEmpty) {
        final avgScore = naps.fold<double>(0, (s, r) {
          final score = r.sleepScore ?? r.calculateSleepScore();
          return s + score;
        }) / naps.length;
        final bestNap = naps.reduce(
          (a, b) =>
              (b.sleepScore ?? b.calculateSleepScore()) >=
                  (a.sleepScore ?? a.calculateSleepScore())
              ? b
              : a,
        );
        map[entry.key] = DaySleepSummary(
          totalHours: naps.fold<double>(0, (s, r) => s + r.totalSleepHours),
          avgScore: avgScore,
          grade: bestNap.scoreGradeDisplay,
          quality: bestNap.quality,
          qualityColor: bestNap.qualityColor,
          hasNap: true,
          goalMet: false,
          recordCount: dayRecords.length,
        );
      }
      continue;
    }

    final totalHours = mainRecords.fold<double>(
      0,
      (s, r) => s + r.actualSleepHours,
    );
    final avgScore = mainRecords.fold<double>(0, (s, r) {
      final score = r.sleepScore ?? r.calculateSleepScore();
      return s + score;
    }) / mainRecords.length;
    final best = mainRecords.reduce(
      (a, b) =>
          (b.sleepScore ?? b.calculateSleepScore()) >=
              (a.sleepScore ?? a.calculateSleepScore())
          ? b
          : a,
    );
    final goalMet = best.scoredGoalMet ?? false;

    map[entry.key] = DaySleepSummary(
      totalHours: totalHours,
      avgScore: avgScore,
      grade: best.scoreGradeDisplay,
      quality: best.quality,
      qualityColor: best.qualityColor,
      hasNap: naps.isNotEmpty,
      goalMet: goalMet,
      recordCount: dayRecords.length,
    );
  }

  return map;
});

// ============================================================================
// Sleep Factor Providers
// ============================================================================

/// Stream provider for all sleep factors
final sleepFactorsStreamProvider = StreamProvider<List<SleepFactor>>((ref) {
  final repository = ref.watch(sleepFactorRepositoryProvider);
  return repository.watchAll();
});

/// Future provider for all sleep factors (with caching)
final sleepFactorsProvider = FutureProvider<List<SleepFactor>>((ref) async {
  final repository = ref.watch(sleepFactorRepositoryProvider);
  return repository.getAll();
});

/// Future provider for default sleep factors
final defaultSleepFactorsProvider = FutureProvider<List<SleepFactor>>((ref) async {
  final repository = ref.watch(sleepFactorRepositoryProvider);
  return repository.getDefaultFactors();
});

/// Future provider for custom sleep factors
final customSleepFactorsProvider = FutureProvider<List<SleepFactor>>((ref) async {
  final repository = ref.watch(sleepFactorRepositoryProvider);
  return repository.getCustomFactors();
});

/// Provider for sleep factor by ID
final sleepFactorByIdProvider =
    FutureProvider.family<SleepFactor?, String>((ref, id) async {
  final repository = ref.watch(sleepFactorRepositoryProvider);
  return repository.getById(id);
});

/// Stream provider for sleep factor by ID
final sleepFactorStreamByIdProvider =
    StreamProvider.family<SleepFactor?, String>((ref, id) {
  final repository = ref.watch(sleepFactorRepositoryProvider);
  return repository.watchById(id);
});

// ============================================================================
// Sleep Template Providers
// ============================================================================

final sleepTemplatesStreamProvider = StreamProvider<List<SleepTemplate>>((ref) {
  final repository = ref.watch(sleepTemplateRepositoryProvider);
  return repository.watchAll();
});

final sleepTemplatesProvider = FutureProvider<List<SleepTemplate>>((ref) async {
  final repository = ref.watch(sleepTemplateRepositoryProvider);
  return repository.getAll();
});

/// Default template for pre-filling add sleep log. Fast after module init.
final defaultSleepTemplateProvider = FutureProvider<SleepTemplate?>((ref) async {
  final repository = ref.watch(sleepTemplateRepositoryProvider);
  return repository.getDefaultTemplate();
});
