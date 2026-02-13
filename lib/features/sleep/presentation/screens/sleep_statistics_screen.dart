import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/dark_gradient.dart';
import '../../data/models/sleep_factor.dart';
import '../../data/models/sleep_record.dart';
import '../../data/services/sleep_target_service.dart';
import '../providers/sleep_providers.dart';
import 'sleep_calendar_screen.dart';
import 'sleep_factor_insights_screen.dart';

// ─── period enum ──────────────────────────────────────────────────────
enum _Period { week, month, threeMonths, sixMonths, year, factors }

// ─── helper models ────────────────────────────────────────────────────

class _DaySummary {
  final DateTime date;
  final double hours;
  final int score;
  final String grade;
  final String quality;
  final SleepStatus status;
  final List<String> factorIds;
  final DateTime? bedTime;
  final DateTime? wakeTime;

  const _DaySummary({
    required this.date,
    required this.hours,
    required this.score,
    required this.grade,
    required this.quality,
    required this.status,
    required this.factorIds,
    this.bedTime,
    this.wakeTime,
  });
}

class _FactorStat {
  final String factorId;
  int countWith = 0;
  double totalScoreWith = 0;
  int countWithout = 0;
  double totalScoreWithout = 0;

  _FactorStat(this.factorId);

  double get avgWith => countWith > 0 ? totalScoreWith / countWith : 0;
  double get avgWithout =>
      countWithout > 0 ? totalScoreWithout / countWithout : 0;
  double get impact => avgWith - avgWithout;
}

// ─── screen ───────────────────────────────────────────────────────────
class SleepStatisticsScreen extends ConsumerStatefulWidget {
  const SleepStatisticsScreen({super.key});

  @override
  ConsumerState<SleepStatisticsScreen> createState() =>
      _SleepStatisticsScreenState();
}

class _SleepStatisticsScreenState
    extends ConsumerState<SleepStatisticsScreen> {
  static const _gold = AppColors.gold;

  _Period _period = _Period.month;
  _Period _lastDataPeriod = _Period.month;  // Used when Factors tab: which period range to use
  DateTime _anchor = DateTime.now();

  // ─────────────────────────── build ───────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final range = _range();
    final recordsAsync = ref.watch(
        sleepRecordsByDateRangeProvider(
            (startDate: range.start, endDate: range.end)));
    final targetAsync = ref.watch(sleepTargetSettingsProvider);
    final factorsAsync = ref.watch(sleepFactorsStreamProvider);

    final body = SafeArea(
      top: true,
      bottom: false,
      child: CustomScrollView(
        physics:
            const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          _appBar(isDark),
          SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _periodChips(isDark),
              const SizedBox(height: 12),
              _dateNav(isDark, range),
              const SizedBox(height: 20),
              if (_period == _Period.factors)
                SleepFactorInsightsContent(dateRange: range)
              else
                recordsAsync.when(
                  data: (records) {
                    final settings = targetAsync.value;
                    final factors = factorsAsync.value ?? [];
                    if (settings == null) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }
                    return _body(
                        records, settings, factors, isDark, range);
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 80),
                    child: Center(
                        child:
                            CircularProgressIndicator(color: _gold)),
                  ),
                  error: (e, _) => _emptyState(isDark,
                      'Something went wrong', Icons.error_outline_rounded),
                ),
            ]),
          ),
        ),
      ],
      ),
    );

    return Scaffold(
      backgroundColor:
          isDark ? Colors.transparent : const Color(0xFFF5F5F7),
      body: isDark ? DarkGradient.wrap(child: body) : body,
    );
  }

  // ─────────────────────────── app bar ─────────────────────────────────
  SliverAppBar _appBar(bool isDark) {
    return SliverAppBar(
      pinned: true,
      primary: false,
      backgroundColor: isDark
          ? const Color(0xFF2A2D3A)
          : const Color(0xFFF5F5F7),
      surfaceTintColor: Colors.transparent,
      title: const Text('Sleep Report'),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.calendar_month_rounded),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const SleepCalendarScreen(),
              ),
            );
          },
          tooltip: 'Sleep Calendar',
        ),
      ],
    );
  }

  // ─────────────────────────── body ────────────────────────────────────
  Widget _body(
    List<SleepRecord> allRecords,
    SleepTargetSettings settings,
    List<SleepFactor> allFactors,
    bool isDark,
    ({DateTime start, DateTime end}) range,
  ) {
    final records = allRecords.where((r) => !r.isNap).toList();
    if (records.isEmpty) {
      return _emptyState(
          isDark, 'No sleep data for this period', Icons.bedtime_rounded);
    }

    final dayMap = <DateTime, List<SleepRecord>>{};
    for (final r in records) {
      final d = DateTime(r.bedTime.year, r.bedTime.month, r.bedTime.day);
      dayMap.putIfAbsent(d, () => []).add(r);
    }

    final days = <_DaySummary>[];
    for (final entry in dayMap.entries) {
      final recs = entry.value;
      final totalHours =
          recs.fold<double>(0, (s, r) => s + r.actualSleepHours);
      final bestRecord = recs.reduce((a, b) =>
          (a.sleepScore ?? a.calculateSleepScore()) >=
                  (b.sleepScore ?? b.calculateSleepScore())
              ? a
              : b);
      final score =
          bestRecord.sleepScore ?? bestRecord.calculateSleepScore();
      final status = SleepTargetService.getStatusForHoursWithSettings(
          totalHours, settings);
      final allFactorIds = <String>[];
      for (final r in recs) {
        if (r.factorsBeforeSleep != null) {
          allFactorIds.addAll(r.factorsBeforeSleep!);
        }
      }
      days.add(_DaySummary(
        date: entry.key,
        hours: totalHours,
        score: score,
        grade: bestRecord.scoreGradeDisplay,
        quality: bestRecord.qualityDisplayName,
        status: status,
        factorIds: allFactorIds.toSet().toList(),
        bedTime: bestRecord.bedTime,
        wakeTime: bestRecord.wakeTime,
      ));
    }
    days.sort((a, b) => a.date.compareTo(b.date));

    // ── aggregates ──
    final avgHours =
        days.fold<double>(0, (s, d) => s + d.hours) / days.length;
    final avgScore =
        days.fold<int>(0, (s, d) => s + d.score) / days.length;
    final targetHit =
        days.where((d) => d.status == SleepStatus.healthy).length;
    final sleepDebt = days.fold<double>(
        0, (s, d) => s + max(0, settings.targetHours - d.hours));

    final bedMinutes = days
        .where((d) => d.bedTime != null)
        .map((d) {
          final bt = d.bedTime!;
          var m = bt.hour * 60 + bt.minute;
          if (m < 720) m += 1440;
          return m.toDouble();
        })
        .toList();
    double consistency = 0;
    if (bedMinutes.length > 1) {
      final mean =
          bedMinutes.reduce((a, b) => a + b) / bedMinutes.length;
      final variance = bedMinutes.fold<double>(
              0, (s, m) => s + pow(m - mean, 2)) /
          bedMinutes.length;
      consistency = sqrt(variance);
    }

    final allFactorIds = <String>{};
    for (final d in days) {
      allFactorIds.addAll(d.factorIds);
    }
    final factorStats = <String, _FactorStat>{};
    for (final fid in allFactorIds) {
      factorStats[fid] = _FactorStat(fid);
    }
    for (final d in days) {
      for (final fid in allFactorIds) {
        final stat = factorStats[fid]!;
        if (d.factorIds.contains(fid)) {
          stat.countWith++;
          stat.totalScoreWith += d.score;
        } else {
          stat.countWithout++;
          stat.totalScoreWithout += d.score;
        }
      }
    }

    final qualityDist = <String, int>{};
    for (final d in days) {
      qualityDist[d.quality] = (qualityDist[d.quality] ?? 0) + 1;
    }

    final weekdayTotals = <int, double>{};
    final weekdayCounts = <int, int>{};
    for (final d in days) {
      weekdayTotals[d.date.weekday] =
          (weekdayTotals[d.date.weekday] ?? 0) + d.hours;
      weekdayCounts[d.date.weekday] =
          (weekdayCounts[d.date.weekday] ?? 0) + 1;
    }

    return Column(
      children: [
        _heroCard(isDark, avgHours, avgScore, days.length, settings),
        const SizedBox(height: 16),
        _quickStats(isDark, avgScore, targetHit, days.length,
            sleepDebt, consistency),
        const SizedBox(height: 16),
        _calendarHeatmap(isDark, days, settings, allFactors, range),
        const SizedBox(height: 16),
        _trendChart(isDark, days, settings),
        const SizedBox(height: 16),
        _barChart(isDark, days, settings),
        const SizedBox(height: 16),
        _qualityPie(isDark, qualityDist, days.length),
        const SizedBox(height: 16),
        _scoreTrend(isDark, days),
        const SizedBox(height: 16),
        _factorBreakdown(isDark, factorStats, allFactors),
        const SizedBox(height: 16),
        _dailyReport(isDark, days, settings, allFactors),
        const SizedBox(height: 16),
        _weekdayPattern(
            isDark, weekdayTotals, weekdayCounts, settings),
        const SizedBox(height: 16),
        _observations(isDark, days, settings, avgHours, avgScore,
            consistency, sleepDebt),
      ],
    );
  }

  // ══════════════════════════ PERIOD CHIPS ══════════════════════════════
  Widget _periodChips(bool isDark) {
    const items = [
      (_Period.week, '1W'),
      (_Period.month, '1M'),
      (_Period.threeMonths, '3M'),
      (_Period.sixMonths, '6M'),
      (_Period.year, '1Y'),
      (_Period.factors, 'Factors'),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
      ),
      child: Row(
        children: items.map((e) {
          final sel = _period == e.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  final next = e.$1;
                  if (next != _Period.factors) _lastDataPeriod = next;
                  _period = next;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? _gold : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: sel
                      ? [
                          BoxShadow(
                              color: _gold.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4))
                        ]
                      : [],
                ),
                child: Text(
                  e.$2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: sel ? FontWeight.w900 : FontWeight.w600,
                    color: sel
                        ? const Color(0xFF1E1E1E)
                        : (isDark ? Colors.white54 : Colors.black45),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ══════════════════════════ DATE NAV ══════════════════════════════════
  Widget _dateNav(
      bool isDark, ({DateTime start, DateTime end}) range) {
    String label;
    switch (_period) {
      case _Period.week:
        label =
            '${DateFormat('MMM d').format(range.start)} – ${DateFormat('MMM d').format(range.end)}';
        break;
      case _Period.month:
        label = DateFormat('MMMM yyyy').format(range.start);
        break;
      case _Period.threeMonths:
      case _Period.sixMonths:
        label =
            '${DateFormat('MMM yyyy').format(range.start)} – ${DateFormat('MMM yyyy').format(range.end)}';
        break;
      case _Period.year:
        label = '${range.start.year}';
        break;
      case _Period.factors:
        switch (_lastDataPeriod) {
          case _Period.week:
            label = '${DateFormat('MMM d').format(range.start)} – ${DateFormat('MMM d').format(range.end)}';
            break;
          case _Period.month:
            label = DateFormat('MMMM yyyy').format(range.start);
            break;
          case _Period.threeMonths:
          case _Period.sixMonths:
            label = '${DateFormat('MMM yyyy').format(range.start)} – ${DateFormat('MMM yyyy').format(range.end)}';
            break;
          case _Period.year:
            label = '${range.start.year}';
            break;
          case _Period.factors:
            label = DateFormat('MMMM yyyy').format(range.start);
            break;
        }
        break;
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () => _shift(-1),
          icon: Icon(Icons.chevron_left_rounded,
              color: isDark ? Colors.white54 : Colors.black45),
        ),
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          onPressed: () => _shift(1),
          icon: Icon(Icons.chevron_right_rounded,
              color: isDark ? Colors.white54 : Colors.black45),
        ),
      ],
    );
  }

  // ══════════════════════════ HERO CARD ═════════════════════════════════
  Widget _heroCard(bool isDark, double avgHours, double avgScore,
      int nights, SleepTargetSettings settings) {
    final grade = avgScore >= 90
        ? 'A'
        : avgScore >= 80
            ? 'B'
            : avgScore >= 70
                ? 'C'
                : avgScore >= 60
                    ? 'D'
                    : avgScore >= 50
                        ? 'E'
                        : 'F';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: _gold.withOpacity(isDark ? 0.15 : 0.1),
                          borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.bedtime_rounded,
                          size: 18, color: _gold),
                    ),
                    const SizedBox(width: 10),
                    Text('Average Sleep',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white54
                                : Colors.black45)),
                  ],
                ),
                const SizedBox(height: 12),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${avgHours.toStringAsFixed(1)}h',
                    style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: isDark ? Colors.white : Colors.black87),
                  ),
                ),
                Text(
                  'avg over $nights night${nights != 1 ? 's' : ''}  ·  target ${settings.targetHours.toStringAsFixed(1)}h',
                  style: TextStyle(
                      fontSize: 12,
                      color:
                          isDark ? Colors.white54 : Colors.black45),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              Text(grade,
                  style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      color: _gold,
                      letterSpacing: -1)),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: _gold.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _gold.withOpacity(0.3), width: 1)),
                child: Text('Score: ${avgScore.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _gold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════ QUICK STATS ═══════════════════════════════
  Widget _quickStats(bool isDark, double avgScore, int targetHit,
      int totalDays, double sleepDebt, double consistency) {
    final avgGrade = avgScore >= 90 ? 'A' :
                    avgScore >= 80 ? 'B' :
                    avgScore >= 70 ? 'C' :
                    avgScore >= 60 ? 'D' :
                    avgScore >= 50 ? 'E' : 'F';

    return Row(
      children: [
        _statChip(isDark, Icons.trending_up_rounded,
            avgGrade, 'Avg Grade', _gold),
        const SizedBox(width: 8),
        _statChip(
            isDark,
            Icons.check_circle_rounded,
            '${totalDays > 0 ? (targetHit / totalDays * 100).toStringAsFixed(0) : 0}%',
            'Target Hit',
            AppColors.success),
        const SizedBox(width: 8),
        _statChip(
            isDark,
            Icons.trending_down_rounded,
            '${sleepDebt.toStringAsFixed(1)}h',
            'Sleep Debt',
            AppColors.error),
        const SizedBox(width: 8),
        _statChip(
            isDark,
            Icons.access_time_rounded,
            '${consistency.toStringAsFixed(0)}m',
            'Consistency',
            AppColors.info),
      ],
    );
  }

  Widget _statChip(bool isDark, IconData icon, String value,
      String label, Color color) {
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black87)),
            ),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white38 : Colors.black38),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════ CALENDAR HEATMAP ══════════════════════════
  /// Monochromatic gold heatmap – higher score = more intense gold
  Color _heatColor(bool isDark, int score) {
    // 5-stop gold gradient: very faint → saturated gold
    if (score >= 80) return _gold;
    if (score >= 60) return _gold.withOpacity(0.7);
    if (score >= 40) return _gold.withOpacity(0.45);
    if (score >= 20) return _gold.withOpacity(0.25);
    return _gold.withOpacity(0.12);
  }

  Color _heatEmptyColor(bool isDark) =>
      isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04);

  Widget _calendarHeatmap(
      bool isDark,
      List<_DaySummary> days,
      SleepTargetSettings settings,
      List<SleepFactor> factors,
      ({DateTime start, DateTime end}) range) {
    final dayLookup = <int, _DaySummary>{};
    for (final d in days) {
      dayLookup[d.date.day + d.date.month * 100 + d.date.year * 10000] = d;
    }

    final allDates = <DateTime>[];
    var d = range.start;
    while (!d.isAfter(range.end)) {
      allDates.add(d);
      d = d.add(const Duration(days: 1));
    }

    // ── week view ──
    if (_period == _Period.week) {
      return _section(isDark, 'SLEEP HEATMAP', Icons.calendar_today_rounded,
          child: Column(
            children: [
              Row(
                children: allDates.take(7).map((date) {
                  final key =
                      date.day + date.month * 100 + date.year * 10000;
                  final day = dayLookup[key];
                  return Expanded(
                      child: _heatCellModern(
                          isDark, date, day, factors, settings,
                          large: true));
                }).toList(),
              ),
              const SizedBox(height: 12),
              _heatLegend(isDark),
            ],
          ));
    }

    // ── month view ──
    if (_period == _Period.month && allDates.length <= 31) {
      final firstDay = allDates.first;
      final offset = (firstDay.weekday - 1) % 7;

      return _section(isDark, 'SLEEP HEATMAP', Icons.calendar_today_rounded,
          child: Column(
            children: [
              Row(
                children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                    .map((l) => Expanded(
                          child: Center(
                              child: Text(l,
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? Colors.white38
                                          : Colors.black38))),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 6),
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                children: [
                  ...List.generate(offset, (_) => const SizedBox.shrink()),
                  ...allDates.map((date) {
                    final key = date.day +
                        date.month * 100 +
                        date.year * 10000;
                    final day = dayLookup[key];
                    return _heatCellModern(
                        isDark, date, day, factors, settings,
                        large: false);
                  }),
                ],
              ),
              const SizedBox(height: 12),
              _heatLegend(isDark),
            ],
          ));
    }

    // ── compact view (3M+) ──
    return _section(isDark, 'SLEEP HEATMAP', Icons.calendar_today_rounded,
        child: Column(
          children: [
            Wrap(
              spacing: 3,
              runSpacing: 3,
              children: allDates.map((date) {
                final key =
                    date.day + date.month * 100 + date.year * 10000;
                final day = dayLookup[key];
                final color = day == null
                    ? _heatEmptyColor(isDark)
                    : _heatColor(isDark, day.score);
                return GestureDetector(
                  onTap: day != null
                      ? () => _showDayPopup(
                          context, isDark, day, factors, settings)
                      : null,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            _heatLegend(isDark),
          ],
        ));
  }

  Widget _heatCellModern(
      bool isDark,
      DateTime date,
      _DaySummary? day,
      List<SleepFactor> factors,
      SleepTargetSettings settings,
      {required bool large}) {
    final hasData = day != null;
    final bgColor =
        hasData ? _heatColor(isDark, day.score) : _heatEmptyColor(isDark);
    final isToday = _isToday(date);

    return GestureDetector(
      onTap: hasData
          ? () =>
              _showDayPopup(context, isDark, day, factors, settings)
          : null,
      child: Container(
        height: large ? 60 : null,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(large ? 12 : 8),
          border: isToday
              ? Border.all(color: _gold, width: 1.5)
              : null,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: large ? 14 : 11,
                  fontWeight: FontWeight.w700,
                  color: hasData
                      ? (day.score >= 60
                          ? const Color(0xFF1E1E1E)
                          : (isDark ? Colors.white : Colors.black87))
                      : (isDark ? Colors.white24 : Colors.black26),
                ),
              ),
              if (large && hasData)
                Text(
                  '${day.hours.toStringAsFixed(1)}h',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: day.score >= 60
                        ? const Color(0xFF1E1E1E).withOpacity(0.7)
                        : (isDark ? Colors.white54 : Colors.black45),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heatLegend(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Low ',
            style: TextStyle(
                fontSize: 9,
                color: isDark ? Colors.white38 : Colors.black38)),
        ...List.generate(5, (i) {
          final opacity = [0.12, 0.25, 0.45, 0.7, 1.0][i];
          return Container(
            width: 16,
            height: 10,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: _gold.withOpacity(opacity),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
        Text(' High',
            style: TextStyle(
                fontSize: 9,
                color: isDark ? Colors.white38 : Colors.black38)),
      ],
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  // ══════════════════════ DAY POPUP DIALOG ══════════════════════════════
  void _showDayPopup(BuildContext context, bool isDark,
      _DaySummary day, List<SleepFactor> allFactors,
      SleepTargetSettings settings) {
    final style = settings.getStatusStyle(day.status);
    final statusLabel = switch (day.status) {
      SleepStatus.dangerous => 'Dangerous',
      SleepStatus.poor => 'Poor',
      SleepStatus.fair => 'Fair',
      SleepStatus.healthy => 'Healthy',
      SleepStatus.extended => 'Extended',
      SleepStatus.overslept => 'Overslept',
    };

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor:
            isDark ? const Color(0xFF2D3139) : Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text(
          DateFormat('EEEE, MMM d').format(day.date),
          style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('${day.hours.toStringAsFixed(1)}h',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: isDark
                            ? Colors.white
                            : Colors.black87)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: style.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(style.iconData,
                          size: 14, color: style.color),
                      const SizedBox(width: 4),
                      Text(statusLabel,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: style.color)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _popupRow('Score', '${day.score} (${day.grade})', isDark),
            _popupRow('Quality', day.quality, isDark),
            if (day.bedTime != null)
              _popupRow('Bedtime',
                  DateFormat('h:mm a').format(day.bedTime!), isDark),
            if (day.wakeTime != null)
              _popupRow('Wake',
                  DateFormat('h:mm a').format(day.wakeTime!), isDark),
            if (day.factorIds.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Factors',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? Colors.white54
                          : Colors.black45)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: day.factorIds.map((fid) {
                  final f = allFactors
                      .where((f) => f.id == fid)
                      .firstOrNull;
                  if (f == null) return const SizedBox.shrink();
                  return Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: f.color.withOpacity(isDark ? 0.15 : 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: f.color.withOpacity(isDark ? 0.3 : 0.2),
                        width: 1,
                      ),
                    ),
                    child: Icon(f.icon, size: 16, color: f.color),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close',
                style: TextStyle(color: _gold)),
          ),
        ],
      ),
    );
  }

  Widget _popupRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? Colors.white54
                      : Colors.black45)),
          Text(value,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color:
                      isDark ? Colors.white : Colors.black87)),
        ],
      ),
    );
  }

  // ══════════════════════ SLEEP TREND ═══════════════════════════════════
  Widget _trendChart(bool isDark, List<_DaySummary> days,
      SleepTargetSettings settings) {
    if (days.length < 2) return const SizedBox.shrink();

    final spots = <FlSpot>[];
    for (var i = 0; i < days.length; i++) {
      spots.add(FlSpot(i.toDouble(), days[i].hours));
    }
    final thirdLen = max(1, days.length ~/ 3);
    final firstAvg =
        days.take(thirdLen).fold<double>(0, (s, d) => s + d.hours) /
            thirdLen;
    final lastAvg = days
            .skip(max(0, days.length - thirdLen))
            .fold<double>(0, (s, d) => s + d.hours) /
        thirdLen;
    final trendDelta = lastAvg - firstAvg;
    final trendColor = trendDelta < -0.2
        ? AppColors.error
        : (lastAvg >= settings.effectiveHealthyMin &&
                lastAvg <= settings.effectiveHealthyMax)
            ? AppColors.success
            : _gold;
    final trendLabel = trendDelta < -0.2
        ? 'Declining'
        : (lastAvg >= settings.effectiveHealthyMin &&
                lastAvg <= settings.effectiveHealthyMax)
            ? 'Healthy'
            : 'Stable';
    final maxY = days.map((d) => d.hours).reduce(max);

    return _section(isDark, 'SLEEP TREND', Icons.show_chart_rounded,
        trailing: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: trendColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(trendLabel,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: trendColor)),
        ),
        child: SizedBox(
          height: 200,
          child: LineChart(LineChartData(
            minY: 0,
            maxY: (maxY * 1.15).clamp(10, 16),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: maxY > 0 ? maxY / 3 : 1,
              getDrawingHorizontalLine: (_) => FlLine(
                  color: isDark
                      ? Colors.white.withOpacity(0.04)
                      : Colors.black.withOpacity(0.04),
                  strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: _chartTitles(isDark, days),
            extraLinesData: ExtraLinesData(horizontalLines: [
              HorizontalLine(
                  y: settings.targetHours,
                  color: _gold.withOpacity(0.5),
                  strokeWidth: 1.5,
                  dashArray: [6, 4]),
              HorizontalLine(
                  y: settings.effectiveHealthyMin,
                  color: AppColors.success.withOpacity(0.2),
                  strokeWidth: 1,
                  dashArray: [4, 4]),
              HorizontalLine(
                  y: settings.effectiveHealthyMax,
                  color: AppColors.success.withOpacity(0.2),
                  strokeWidth: 1,
                  dashArray: [4, 4]),
            ]),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (spots) => spots.map((s) {
                  final dd = days[s.x.toInt()];
                  return LineTooltipItem(
                    '${dd.hours.toStringAsFixed(1)}h',
                    const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                  );
                }).toList(),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.3,
                barWidth: 2.5,
                isStrokeCapRound: true,
                color: trendColor,
                dotData: FlDotData(
                  show: days.length <= 31,
                  getDotPainter: (spot, _, __, ___) {
                    final dd = days[spot.x.toInt()];
                    final c =
                        settings.getStatusStyle(dd.status).color;
                    return FlDotCirclePainter(
                        radius: 3.5,
                        color: c,
                        strokeWidth: 2,
                        strokeColor: isDark
                            ? const Color(0xFF2A2D3A)
                            : Colors.white);
                  },
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      trendColor.withOpacity(0.2),
                      trendColor.withOpacity(0.0)
                    ],
                  ),
                ),
              ),
            ],
          )),
        ));
  }

  // ══════════════════════ BAR CHART ═════════════════════════════════════
  Widget _barChart(bool isDark, List<_DaySummary> days,
      SleepTargetSettings settings) {
    if (days.isEmpty) return const SizedBox.shrink();

    List<_DaySummary> displayDays = days;
    bool isWeekly = false;
    if (days.length > 35) {
      isWeekly = true;
      final weekMap = <int, List<_DaySummary>>{};
      for (final dd in days) {
        final weekNum =
            dd.date.difference(days.first.date).inDays ~/ 7;
        weekMap.putIfAbsent(weekNum, () => []).add(dd);
      }
      displayDays = weekMap.entries.map((e) {
        final avgH = e.value.fold<double>(0, (s, dd) => s + dd.hours) /
            e.value.length;
        final avgS =
            (e.value.fold<int>(0, (s, dd) => s + dd.score) /
                    e.value.length)
                .round();
        final status =
            SleepTargetService.getStatusForHoursWithSettings(
                avgH, settings);
        return _DaySummary(
            date: e.value.first.date,
            hours: avgH,
            score: avgS,
            grade: '',
            quality: '',
            status: status,
            factorIds: []);
      }).toList();
    }

    final maxY = displayDays.map((dd) => dd.hours).reduce(max);

    return _section(
        isDark,
        isWeekly ? 'WEEKLY AVERAGE' : 'DAILY SLEEP',
        Icons.bar_chart_rounded,
        child: SizedBox(
          height: 200,
          child: BarChart(BarChartData(
            maxY: (maxY * 1.15).clamp(10, 16),
            barGroups: displayDays.asMap().entries.map((e) {
              final st =
                  settings.getStatusStyle(e.value.status);
              return BarChartGroupData(x: e.key, barRods: [
                BarChartRodData(
                  toY: e.value.hours,
                  color: st.color,
                  width: displayDays.length > 20 ? 6 : 12,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4)),
                ),
              ]);
            }).toList(),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                  color: isDark
                      ? Colors.white.withOpacity(0.04)
                      : Colors.black.withOpacity(0.04),
                  strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: _chartTitles(isDark, displayDays),
            extraLinesData: ExtraLinesData(horizontalLines: [
              HorizontalLine(
                  y: settings.targetHours,
                  color: _gold.withOpacity(0.5),
                  strokeWidth: 1.5,
                  dashArray: [6, 4]),
            ]),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, gi, rod, ri) {
                  final dd = displayDays[group.x];
                  return BarTooltipItem(
                    '${DateFormat('MMM d').format(dd.date)}\n${dd.hours.toStringAsFixed(1)}h',
                    const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                  );
                },
              ),
            ),
          )),
        ));
  }

  // ══════════════════════ QUALITY PIE ═══════════════════════════════════
  Widget _qualityPie(
      bool isDark, Map<String, int> qualityDist, int total) {
    if (qualityDist.isEmpty) return const SizedBox.shrink();

    const colorMap = {
      'Poor': Color(0xFFEF5350),
      'Fair': Color(0xFFFFA726),
      'Good': Color(0xFFCDAF56),
      'Very Good': Color(0xFF8BC34A),
      'Excellent': Color(0xFF4CAF50),
    };
    const emojiMap = {
      'Poor': '😫',
      'Fair': '🥱',
      'Good': '🙂',
      'Very Good': '🤩',
      'Excellent': '💪',
    };

    final sections = qualityDist.entries.map((e) {
      final pct = total > 0 ? e.value / total * 100 : 0.0;
      return PieChartSectionData(
        value: e.value.toDouble(),
        color: colorMap[e.key] ?? Colors.grey,
        radius: 50,
        title: pct >= 8 ? '${pct.toStringAsFixed(0)}%' : '',
        titleStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: Colors.white),
      );
    }).toList();

    return _section(
        isDark, 'QUALITY DISTRIBUTION', Icons.pie_chart_rounded,
        child: Column(
          children: [
            SizedBox(
              height: 160,
              child: PieChart(PieChartData(
                sections: sections,
                centerSpaceRadius: 30,
                sectionsSpace: 2,
              )),
            ),
            const SizedBox(height: 16),
            ...qualityDist.entries.map((e) {
              final pct = total > 0
                  ? (e.value / total * 100).toStringAsFixed(0)
                  : '0';
              final c = colorMap[e.key] ?? Colors.grey;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color: c, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text('${emojiMap[e.key] ?? ''} ${e.key}',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white
                                : Colors.black87)),
                    const Spacer(),
                    Text('${e.value} ($pct%)',
                        style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? Colors.white54
                                : Colors.black45)),
                  ],
                ),
              );
            }),
          ],
        ));
  }

  // ══════════════════════ SCORE TREND ═══════════════════════════════════
  Widget _scoreTrend(bool isDark, List<_DaySummary> days) {
    if (days.length < 2) return const SizedBox.shrink();

    final spots = <FlSpot>[];
    for (var i = 0; i < days.length; i++) {
      spots.add(FlSpot(i.toDouble(), days[i].score.toDouble()));
    }

    return _section(
        isDark, 'SCORE TREND', Icons.insights_rounded,
        child: SizedBox(
          height: 160,
          child: LineChart(LineChartData(
            minY: 0,
            maxY: 100,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 25,
              getDrawingHorizontalLine: (_) => FlLine(
                  color: isDark
                      ? Colors.white.withOpacity(0.04)
                      : Colors.black.withOpacity(0.04),
                  strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 25,
                getTitlesWidget: (v, _) => Text('${v.toInt()}',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.white38
                            : Colors.black38)),
              )),
              bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval:
                    max(1, (days.length / 6).ceilToDouble()),
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= days.length) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                      DateFormat('d').format(days[i].date),
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white38
                              : Colors.black38));
                },
              )),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (spots) => spots
                    .map((s) => LineTooltipItem(
                          'Score: ${s.y.toInt()}',
                          const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700),
                        ))
                    .toList(),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.3,
                barWidth: 2.5,
                isStrokeCapRound: true,
                color: _gold,
                dotData: FlDotData(
                  show: days.length <= 31,
                  getDotPainter: (_, __, ___, ____) =>
                      FlDotCirclePainter(
                          radius: 3,
                          color: _gold,
                          strokeWidth: 2,
                          strokeColor: isDark
                              ? const Color(0xFF2A2D3A)
                              : Colors.white),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _gold.withOpacity(0.15),
                      _gold.withOpacity(0.0)
                    ],
                  ),
                ),
              ),
            ],
          )),
        ));
  }

  // ══════════════════════ FACTOR BREAKDOWN ══════════════════════════════
  Widget _factorBreakdown(bool isDark,
      Map<String, _FactorStat> factorStats,
      List<SleepFactor> allFactors) {
    if (factorStats.isEmpty) {
      return _section(
          isDark, 'FACTOR IMPACT', Icons.science_rounded,
          child: _infoText(isDark,
              'No factor data yet. Add factors to sleep logs to see their impact here.'));
    }

    final sorted = factorStats.values
        .where((s) => s.countWith >= 2)
        .toList()
      ..sort((a, b) => a.impact.compareTo(b.impact));

    if (sorted.isEmpty) {
      return _section(
          isDark, 'FACTOR IMPACT', Icons.science_rounded,
          child: _infoText(isDark,
              'Need more data. Log at least 2 nights with a factor for comparison.'));
    }

    return _section(
        isDark, 'FACTOR IMPACT', Icons.science_rounded,
        child: Column(
          children: sorted.map((stat) {
            final f = allFactors
                .where((f) => f.id == stat.factorId)
                .firstOrNull;
            if (f == null) return const SizedBox.shrink();
            final isSemanticGood = f.isGood;
            final impactColor = isSemanticGood
                ? AppColors.success
                : AppColors.error;
            final impactLabel =
                isSemanticGood ? 'Good influence' : 'Bad influence';

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                            color: f.color.withOpacity(
                                isDark ? 0.2 : 0.1),
                            borderRadius:
                                BorderRadius.circular(8)),
                        child: Icon(f.icon,
                            size: 14, color: f.color),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(f.name,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? Colors.white
                                      : Colors.black87))),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: impactColor.withOpacity(0.15),
                            borderRadius:
                                BorderRadius.circular(6)),
                        child: Text(impactLabel,
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: impactColor)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                          child: _factorBar(
                              isDark,
                              'With (${stat.countWith}x)',
                              stat.avgWith,
                              f.color)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _factorBar(
                              isDark,
                              'Without (${stat.countWithout}x)',
                              stat.avgWithout,
                              isDark
                                  ? Colors.white24
                                  : Colors.grey.shade400)),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ));
  }

  Widget _factorBar(
      bool isDark, String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white38 : Colors.black38)),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (value / 100).clamp(0, 1).toDouble(),
            minHeight: 6,
            backgroundColor: isDark
                ? Colors.white.withOpacity(0.04)
                : Colors.black.withOpacity(0.04),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: 2),
        Text('${value.toStringAsFixed(0)}',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87)),
      ],
    );
  }

  // ══════════════════════ DAILY REPORT ══════════════════════════════════
  static DateTime _mondayOfWeek(DateTime d) {
    return d.subtract(Duration(days: d.weekday - 1));
  }

  Widget _dailyReport(bool isDark, List<_DaySummary> days,
      SleepTargetSettings settings, List<SleepFactor> allFactors) {
    final sorted = [...days]
      ..sort((a, b) => b.date.compareTo(a.date));

    final byWeek = <DateTime, List<_DaySummary>>{};
    for (final dd in sorted) {
      final mon = DateTime(
          _mondayOfWeek(dd.date).year,
          _mondayOfWeek(dd.date).month,
          _mondayOfWeek(dd.date).day);
      byWeek.putIfAbsent(mon, () => []).add(dd);
    }
    final weekKeys = byWeek.keys.toList()..sort((a, b) => b.compareTo(a));

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2)),
              ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: sorted.length <= 14,
          tilePadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Icon(Icons.view_list_rounded, size: 16, color: _gold),
          title: Text(
            'DAILY REPORT',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: _gold,
              letterSpacing: 1.2,
            ),
          ),
          subtitle: Text(
            '${sorted.length} day${sorted.length != 1 ? 's' : ''}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
          children: [
            for (int w = 0; w < weekKeys.length; w++) ...[
              if (w > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Divider(
                    height: 1,
                    thickness: 2,
                    color: _gold.withOpacity(0.3),
                  ),
                ),
              _weekHeader(isDark, weekKeys[w]),
              const SizedBox(height: 8),
              ...byWeek[weekKeys[w]]!.map((dd) =>
                  _dailyReportRow(
                      context, isDark, dd, settings, allFactors)),
              if (w < weekKeys.length - 1) const SizedBox(height: 4),
            ],
          ],
        ),
      ),
    );
  }

  Widget _weekHeader(bool isDark, DateTime monday) {
    final sunday = monday.add(const Duration(days: 6));
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: _gold.withOpacity(0.6),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Week of ${DateFormat('MMM d').format(monday)} – ${DateFormat('MMM d').format(sunday)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : Colors.black87,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dailyReportRow(
    BuildContext context,
    bool isDark,
    _DaySummary dd,
    SleepTargetSettings settings,
    List<SleepFactor> allFactors,
  ) {
    final style = settings.getStatusStyle(dd.status);
    final statusLabel = switch (dd.status) {
      SleepStatus.dangerous => 'Dangerous',
      SleepStatus.poor => 'Poor',
      SleepStatus.fair => 'Fair',
      SleepStatus.healthy => 'Healthy',
      SleepStatus.extended => 'Extended',
      SleepStatus.overslept => 'Overslept',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: () => _showDayPopup(context, isDark, dd, allFactors, settings),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _heatColor(isDark, dd.score),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    '${dd.date.day}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: dd.score >= 60
                          ? const Color(0xFF1E1E1E)
                          : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEE, MMM d').format(dd.date),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${dd.hours.toStringAsFixed(1)}h  ·  Grade ${dd.grade}  ·  ${dd.quality}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: style.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(style.iconData, size: 13, color: style.color),
                    const SizedBox(width: 4),
                    Text(statusLabel,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: style.color)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════ WEEKDAY PATTERN ═══════════════════════════════
  Widget _weekdayPattern(bool isDark, Map<int, double> totals,
      Map<int, int> counts, SleepTargetSettings settings) {
    if (totals.isEmpty) return const SizedBox.shrink();

    final avgs = <int, double>{};
    for (final wd in [1, 2, 3, 4, 5, 6, 7]) {
      avgs[wd] = (counts[wd] ?? 0) > 0
          ? (totals[wd] ?? 0) / counts[wd]!
          : 0;
    }
    final maxH = avgs.values.reduce(max).clamp(1.0, 16.0);
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return _section(
        isDark, 'WEEKDAY PATTERN', Icons.date_range_rounded,
        child: SizedBox(
          height: 160,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (i) {
              final wd = i + 1;
              final h = avgs[wd] ?? 0;
              final pct = maxH > 0 ? h / maxH : 0.0;
              final barH = (pct * 100).clamp(4.0, 100.0);
              final isMax = h == maxH && h > 0;
              final status =
                  SleepTargetService.getStatusForHoursWithSettings(
                      h, settings);
              final barColor =
                  settings.getStatusStyle(status).color;

              return Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                        h > 0 ? h.toStringAsFixed(1) : '',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: isMax
                                ? _gold
                                : (isDark
                                    ? Colors.white54
                                    : Colors.black45))),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: barH,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 4),
                      decoration: BoxDecoration(
                        color: h > 0
                            ? barColor
                            : (isDark
                                ? Colors.white.withOpacity(0.04)
                                : Colors.black.withOpacity(0.04)),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(labels[i],
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isMax
                                ? _gold
                                : (isDark
                                    ? Colors.white54
                                    : Colors.black45))),
                  ],
                ),
              );
            }),
          ),
        ));
  }

  // ══════════════════════ OBSERVATIONS ══════════════════════════════════
  Widget _observations(
      bool isDark,
      List<_DaySummary> days,
      SleepTargetSettings settings,
      double avgHours,
      double avgScore,
      double consistency,
      double sleepDebt) {
    final obs = <String>[];

    if (days.isEmpty) return const SizedBox.shrink();

    final gap = settings.targetHours - avgHours;
    if (gap > 0.5) {
      obs.add(
          'Average sleep: ${avgHours.toStringAsFixed(1)}h (${gap.toStringAsFixed(1)}h below ${settings.targetHours.toStringAsFixed(1)}h target). Try going to bed earlier.');
    } else if (avgHours > settings.oversleptAbove) {
      obs.add(
          'Average sleep: ${avgHours.toStringAsFixed(1)}h (above ${settings.oversleptAbove.toStringAsFixed(1)}h oversleep threshold). Consider setting an alarm.');
    } else {
      obs.add(
          'Average sleep: ${avgHours.toStringAsFixed(1)}h is within your target range. Avg score: ${avgScore.toStringAsFixed(0)}.');
    }

    if (days.length >= 7) {
      final mid = days.length ~/ 2;
      final firstHalf = days.sublist(0, mid);
      final secondHalf = days.sublist(mid);
      final firstAvg =
          firstHalf.fold<int>(0, (s, d) => s + d.score) / firstHalf.length;
      final secondAvg =
          secondHalf.fold<int>(0, (s, d) => s + d.score) / secondHalf.length;
      final diff = secondAvg - firstAvg;
      if (diff > 5) {
        obs.add(
            'Score trend: improved by ${diff.toStringAsFixed(0)} pts in the latter half (${firstAvg.toStringAsFixed(0)} → ${secondAvg.toStringAsFixed(0)}).');
      } else if (diff < -5) {
        obs.add(
            'Score trend: declined by ${diff.abs().toStringAsFixed(0)} pts in the latter half (${firstAvg.toStringAsFixed(0)} → ${secondAvg.toStringAsFixed(0)}).');
      }
    }

    if (consistency > 60) {
      obs.add(
          'Bedtime variance: ~${consistency.toStringAsFixed(0)} min. A more consistent schedule can improve sleep quality.');
    } else if (consistency > 0 && consistency <= 30) {
      obs.add(
          'Bedtime consistency: excellent (~${consistency.toStringAsFixed(0)} min variation).');
    }

    if (sleepDebt > 5) {
      obs.add(
          'Sleep debt: ${sleepDebt.toStringAsFixed(1)}h accumulated. Consider extra sleep on rest days to catch up.');
    }

    if (days.length >= 2) {
      final best = days.reduce((a, b) => a.score > b.score ? a : b);
      final worst = days.reduce((a, b) => a.score < b.score ? a : b);
      if (best.score != worst.score) {
        obs.add(
            'Best: ${DateFormat('MMM d').format(best.date)} (${best.score}). Worst: ${DateFormat('MMM d').format(worst.date)} (${worst.score}).');
      }
    }

    if (obs.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2)),
              ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: obs.length <= 3,
          tilePadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Icon(Icons.insights_rounded, size: 16, color: _gold),
          title: Text(
            'OBSERVATIONS',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: _gold,
              letterSpacing: 1.2,
            ),
          ),
          subtitle: Text(
            '${obs.length} insight${obs.length != 1 ? 's' : ''}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
          children: [
            ...obs.map((line) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.insights_rounded,
                            size: 15, color: _gold),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(line,
                              style: TextStyle(
                                  fontSize: 13,
                                  height: 1.5,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black87))),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════ HELPERS ═══════════════════════════════════

  /// Section card with gold uppercase label and icon (design guide pattern)
  Widget _section(bool isDark, String title, IconData icon,
      {required Widget child, Widget? trailing}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: _gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: _gold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _infoText(bool isDark, String msg) {
    return Text(msg,
        style: TextStyle(
            fontSize: 13,
            height: 1.5,
            color: isDark ? Colors.white54 : Colors.black45));
  }

  Widget _emptyState(bool isDark, String msg, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(icon,
              size: 48,
              color: isDark ? Colors.white24 : Colors.black26),
          const SizedBox(height: 12),
          Text(msg,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color:
                      isDark ? Colors.white38 : Colors.black38)),
        ],
      ),
    );
  }

  FlTitlesData _chartTitles(
      bool isDark, List<_DaySummary> days) {
    return FlTitlesData(
      leftTitles: AxisTitles(
          sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 36,
        getTitlesWidget: (v, _) => Text(
            '${v.toStringAsFixed(0)}h',
            style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white38 : Colors.black38)),
      )),
      bottomTitles: AxisTitles(
          sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 28,
        interval: max(1, (days.length / 6).ceilToDouble()),
        getTitlesWidget: (v, _) {
          final i = v.toInt();
          if (i < 0 || i >= days.length) {
            return const SizedBox.shrink();
          }
          return Text(DateFormat('d').format(days[i].date),
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? Colors.white38
                      : Colors.black38));
        },
      )),
      rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false)),
    );
  }

  ({DateTime start, DateTime end}) _range() {
    final a = DateTime(_anchor.year, _anchor.month, _anchor.day);
    switch (_period) {
      case _Period.week:
        final daysSinceMonday = (a.weekday - 1) % 7;
        final monday = a.subtract(Duration(days: daysSinceMonday));
        return (
          start: monday,
          end: monday.add(const Duration(days: 6))
        );
      case _Period.month:
        return (
          start: DateTime(a.year, a.month, 1),
          end: DateTime(a.year, a.month + 1, 0)
        );
      case _Period.threeMonths:
        return (
          start: DateTime(a.year, a.month, 1),
          end: DateTime(a.year, a.month + 3, 0)
        );
      case _Period.sixMonths:
        return (
          start: DateTime(a.year, a.month, 1),
          end: DateTime(a.year, a.month + 6, 0)
        );
      case _Period.year:
        return (
          start: DateTime(a.year, 1, 1),
          end: DateTime(a.year, 12, 31)
        );
      case _Period.factors:
        return _rangeForPeriod(_lastDataPeriod, a);
    }
  }

  ({DateTime start, DateTime end}) _rangeForPeriod(_Period p, DateTime a) {
    switch (p) {
      case _Period.week:
        final daysSinceMonday = (a.weekday - 1) % 7;
        final monday = a.subtract(Duration(days: daysSinceMonday));
        return (
          start: monday,
          end: monday.add(const Duration(days: 6))
        );
      case _Period.month:
        return (
          start: DateTime(a.year, a.month, 1),
          end: DateTime(a.year, a.month + 1, 0)
        );
      case _Period.threeMonths:
        return (
          start: DateTime(a.year, a.month, 1),
          end: DateTime(a.year, a.month + 3, 0)
        );
      case _Period.sixMonths:
        return (
          start: DateTime(a.year, a.month, 1),
          end: DateTime(a.year, a.month + 6, 0)
        );
      case _Period.year:
        return (
          start: DateTime(a.year, 1, 1),
          end: DateTime(a.year, 12, 31)
        );
      case _Period.factors:
        return (
          start: DateTime(a.year, a.month, 1),
          end: DateTime(a.year, a.month + 1, 0)
        );
    }
  }

  void _shift(int dir) {
    setState(() {
      switch (_period) {
        case _Period.week:
          _anchor = _anchor.add(Duration(days: 7 * dir));
          break;
        case _Period.month:
          _anchor =
              DateTime(_anchor.year, _anchor.month + dir, 1);
          break;
        case _Period.threeMonths:
          _anchor =
              DateTime(_anchor.year, _anchor.month + 3 * dir, 1);
          break;
        case _Period.sixMonths:
          _anchor =
              DateTime(_anchor.year, _anchor.month + 6 * dir, 1);
          break;
        case _Period.year:
          _anchor = DateTime(_anchor.year + dir, 1, 1);
          break;
        case _Period.factors:
          switch (_lastDataPeriod) {
            case _Period.week:
              _anchor = _anchor.add(Duration(days: 7 * dir));
              break;
            case _Period.month:
              _anchor = DateTime(_anchor.year, _anchor.month + dir, 1);
              break;
            case _Period.threeMonths:
              _anchor = DateTime(_anchor.year, _anchor.month + 3 * dir, 1);
              break;
            case _Period.sixMonths:
              _anchor = DateTime(_anchor.year, _anchor.month + 6 * dir, 1);
              break;
            case _Period.year:
              _anchor = DateTime(_anchor.year + dir, 1, 1);
              break;
            case _Period.factors:
              _anchor = DateTime(_anchor.year, _anchor.month + dir, 1);
              break;
          }
          break;
      }
    });
  }
}
