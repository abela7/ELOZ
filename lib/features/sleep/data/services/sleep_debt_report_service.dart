import '../models/sleep_debt_report.dart';
import '../repositories/sleep_record_repository.dart';

/// Service for sleep debt reports by period (daily, weekly, monthly, yearly, all time).
class SleepDebtReportService {
  final SleepRecordRepository _repository;

  SleepDebtReportService({required SleepRecordRepository repository})
    : _repository = repository;

  /// Returns Monday 00:00 of the week containing [date].
  static DateTime _mondayOfWeek(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  static int _dailyDeltaMinutes(DailyDebtEntry e) {
    // Positive = debt added, negative = debt repaid.
    return e.targetMinutes - e.actualMinutes;
  }

  static int _rollingDebtMinutes(
    List<DailyDebtEntry> entries, {
    int initialDebtMinutes = 0,
  }) {
    var debt = initialDebtMinutes;
    final sorted = [...entries]..sort((a, b) => a.date.compareTo(b.date));
    for (final e in sorted) {
      debt += _dailyDeltaMinutes(e);
      if (debt < 0) debt = 0;
    }
    return debt;
  }

  Future<DateTime?> _firstMainSleepDate() async {
    final records = await _repository.getMainSleepRecords();
    if (records.isEmpty) return null;

    records.sort((a, b) => a.bedTime.compareTo(b.bedTime));
    final first = records.first.bedTime;
    return DateTime(first.year, first.month, first.day);
  }

  /// Daily debt breakdown for [start] to [end]. Only past/today days count.
  Future<List<DailyDebtEntry>> getDailyBreakdown({
    required DateTime start,
    required DateTime end,
    required double targetHours,
  }) async {
    final targetMinutes = (targetHours * 60).round();
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final startDate = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);

    final mainSleep = await _repository.getMainSleepByDateRange(
      startDate,
      endDate,
    );
    final Map<DateTime, int> minutesByDate = {};
    for (final r in mainSleep) {
      final d = DateTime(r.bedTime.year, r.bedTime.month, r.bedTime.day);
      final mins = (r.actualSleepHours * 60).round();
      minutesByDate[d] = (minutesByDate[d] ?? 0) + mins;
    }

    final entries = <DailyDebtEntry>[];
    var d = startDate;
    while (!d.isAfter(endDate)) {
      if (d.isAfter(todayDate)) break;

      final actual = minutesByDate[d] ?? 0;
      final debt = actual > 0
          ? (targetMinutes - actual).clamp(0, targetMinutes)
          : targetMinutes;

      entries.add(
        DailyDebtEntry(
          date: d,
          debtMinutes: debt,
          actualMinutes: actual,
          targetMinutes: targetMinutes,
          hadData: actual > 0,
        ),
      );
      d = d.add(const Duration(days: 1));
    }
    return entries;
  }

  /// Weekly debt (Mon–Sun) for weeks overlapping [start]–[end].
  Future<List<WeeklyDebtEntry>> getWeeklyBreakdown({
    required DateTime start,
    required DateTime end,
    required double targetHours,
  }) async {
    final daily = await getDailyBreakdown(
      start: start,
      end: end,
      targetHours: targetHours,
    );
    if (daily.isEmpty) return [];

    final weekMap = <int, List<DailyDebtEntry>>{};
    for (final e in daily) {
      final mon = _mondayOfWeek(e.date);
      final key = mon.year * 10000 + mon.month * 100 + mon.day;
      weekMap.putIfAbsent(key, () => []).add(e);
    }

    return weekMap.entries.map((e) {
      final weekStart = DateTime(
        e.value.first.date.year,
        e.value.first.date.month,
        e.value.first.date.day,
      );
      final mon = _mondayOfWeek(weekStart);
      final debt = _rollingDebtMinutes(e.value);
      final withData = e.value.where((d) => d.hadData).length;
      final missing = e.value.where((d) => !d.hadData).length;

      return WeeklyDebtEntry(
        weekStart: mon,
        debtMinutes: debt,
        nightsWithData: withData,
        nightsMissing: missing,
      );
    }).toList()..sort((a, b) => a.weekStart.compareTo(b.weekStart));
  }

  /// Monthly debt for months in [start]–[end].
  Future<List<MonthlyDebtEntry>> getMonthlyBreakdown({
    required DateTime start,
    required DateTime end,
    required double targetHours,
  }) async {
    final daily = await getDailyBreakdown(
      start: start,
      end: end,
      targetHours: targetHours,
    );
    if (daily.isEmpty) return [];

    final monthMap = <int, List<DailyDebtEntry>>{};
    for (final e in daily) {
      final key = e.date.year * 100 + e.date.month;
      monthMap.putIfAbsent(key, () => []).add(e);
    }

    return monthMap.entries.map((e) {
      final year = e.key ~/ 100;
      final month = e.key % 100;
      final debt = _rollingDebtMinutes(e.value);
      final withData = e.value.where((d) => d.hadData).length;
      final lastDay = DateTime(year, month + 1, 0).day;

      return MonthlyDebtEntry(
        year: year,
        month: month,
        debtMinutes: debt,
        nightsWithData: withData,
        nightsInMonth: lastDay,
      );
    }).toList()..sort((a, b) {
      if (a.year != b.year) return a.year.compareTo(b.year);
      return a.month.compareTo(b.month);
    });
  }

  /// Yearly debt for years in [start]–[end].
  Future<List<YearlyDebtEntry>> getYearlyBreakdown({
    required DateTime start,
    required DateTime end,
    required double targetHours,
  }) async {
    final daily = await getDailyBreakdown(
      start: start,
      end: end,
      targetHours: targetHours,
    );
    if (daily.isEmpty) return [];

    final yearMap = <int, List<DailyDebtEntry>>{};
    for (final e in daily) {
      yearMap.putIfAbsent(e.date.year, () => []).add(e);
    }

    return yearMap.entries.map((e) {
      final debt = _rollingDebtMinutes(e.value);
      final withData = e.value.where((d) => d.hadData).length;

      return YearlyDebtEntry(
        year: e.key,
        debtMinutes: debt,
        nightsWithData: withData,
      );
    }).toList()..sort((a, b) => a.year.compareTo(b.year));
  }

  /// All-time total debt. Uses records from inception to today.
  /// Processes year-by-year to avoid loading years of data at once.
  Future<int> getAllTimeDebtMinutes({required double targetHours}) async {
    final first = await _firstMainSleepDate();
    if (first == null) return 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daily = await getDailyBreakdown(
      start: first,
      end: today,
      targetHours: targetHours,
    );
    return _rollingDebtMinutes(daily);
  }

  /// All-time yearly breakdown for robust all-time report.
  /// Processes year-by-year so each query handles ~365 days max.
  Future<List<YearlyDebtEntry>> getAllTimeYearlyBreakdown({
    required double targetHours,
  }) async {
    final entries = <YearlyDebtEntry>[];
    final first = await _firstMainSleepDate();
    if (first == null) return entries;

    final endOfThisYear = DateTime.now();
    var year = first.year;

    while (year <= endOfThisYear.year) {
      final startOfYear = DateTime(year, 1, 1);
      final start = startOfYear.isBefore(first) ? first : startOfYear;
      final end = year < endOfThisYear.year
          ? DateTime(year, 12, 31)
          : endOfThisYear;
      final yearly = await getYearlyBreakdown(
        start: start,
        end: end,
        targetHours: targetHours,
      );
      entries.addAll(yearly);
      year++;
    }
    entries.sort((a, b) => a.year.compareTo(b.year));
    return entries;
  }
}
