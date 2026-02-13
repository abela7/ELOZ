import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/dark_gradient.dart';
import '../../data/models/sleep_debt_report.dart';
import '../../data/services/sleep_debt_report_service.dart';
import '../providers/sleep_providers.dart';

// ─── period enum ─────────────────────────────────────────────────────────
enum _DebtPeriod { daily, weekly, monthly, yearly, allTime }

// ─── screen ──────────────────────────────────────────────────────────────
class SleepDebtReportScreen extends ConsumerStatefulWidget {
  const SleepDebtReportScreen({super.key});

  @override
  ConsumerState<SleepDebtReportScreen> createState() =>
      _SleepDebtReportScreenState();
}

class _SleepDebtReportScreenState extends ConsumerState<SleepDebtReportScreen> {
  static const _gold = AppColors.gold;

  _DebtPeriod _period = _DebtPeriod.weekly;
  DateTime _anchor = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final range = _range();
    final targetAsync = ref.watch(sleepTargetSettingsProvider);

    final body = SafeArea(
      top: true,
      bottom: false,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          _appBar(isDark),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _periodChips(isDark),
              const SizedBox(height: 12),
              if (_period != _DebtPeriod.allTime) _dateNav(isDark, range),
              if (_period != _DebtPeriod.allTime) const SizedBox(height: 20),
              targetAsync.when(
                data: (settings) => _body(isDark, range, settings.targetHours),
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
                  child: Center(child: CircularProgressIndicator(color: _gold)),
                ),
                error: (e, _) => _emptyState(isDark, 'Failed to load target'),
              ),
            ]),
          ),
        ),
      ],
      ),
    );

    return Scaffold(
      backgroundColor: isDark ? Colors.transparent : const Color(0xFFF5F5F7),
      body: isDark ? DarkGradient.wrap(child: body) : body,
    );
  }

  SliverAppBar _appBar(bool isDark) {
    return SliverAppBar(
      pinned: true,
      primary: false,
      backgroundColor: isDark
          ? const Color(0xFF2A2D3A)
          : const Color(0xFFF5F5F7),
      surfaceTintColor: Colors.transparent,
      title: const Text('Sleep Debt Report'),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => Navigator.of(context).pop(),
      ),
    );
  }

  Widget _periodChips(bool isDark) {
    const items = [
      (_DebtPeriod.daily, 'Daily'),
      (_DebtPeriod.weekly, 'Weekly'),
      (_DebtPeriod.monthly, 'Monthly'),
      (_DebtPeriod.yearly, 'Yearly'),
      (_DebtPeriod.allTime, 'All'),
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
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: items.map((e) {
          final sel = _period == e.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _period = e.$1);
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
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: Text(
                  e.$2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
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

  Widget _dateNav(bool isDark, ({DateTime start, DateTime end}) range) {
    String label;
    switch (_period) {
      case _DebtPeriod.daily:
        label =
            '${DateFormat('MMM d').format(range.start)} – ${DateFormat('MMM d').format(range.end)}';
        break;
      case _DebtPeriod.weekly:
        label =
            '${DateFormat('MMM d').format(range.start)} – ${DateFormat('MMM d').format(range.end)}';
        break;
      case _DebtPeriod.monthly:
        label = DateFormat('MMMM yyyy').format(range.start);
        break;
      case _DebtPeriod.yearly:
        label = '${range.start.year}';
        break;
      case _DebtPeriod.allTime:
        label = 'All time';
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
              color: isDark ? Colors.white : Colors.black87,
            ),
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

  Widget _body(bool isDark, ({DateTime start, DateTime end}) range, double targetHours) {
    ref.watch(sleepRecordsProvider);
    final service = ref.read(sleepDebtReportServiceProvider);

    if (_period == _DebtPeriod.allTime) {
      return FutureBuilder<List<YearlyDebtEntry>>(
        future: service.getAllTimeYearlyBreakdown(targetHours: targetHours),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 80),
              child: Center(child: CircularProgressIndicator(color: _gold)),
            );
          }
          final yearly = snap.data!;
          final total = yearly.fold<int>(0, (s, e) => s + e.debtMinutes);
          final h = total ~/ 60;
          final m = total % 60;
          final formatted = '${h}h ${m}m';
          return Column(
            children: [
              _heroCard(isDark, total, formatted, 0, targetHours: targetHours),
              const SizedBox(height: 16),
              _quickStatsAllTime(isDark, total, yearly.length, targetHours),
              const SizedBox(height: 16),
              if (yearly.isNotEmpty) ...[
                _section(
                  isDark,
                  'YEARLY BREAKDOWN',
                  Icons.bar_chart_rounded,
                  child: _allTimeYearlyBarChart(isDark, yearly),
                ),
                const SizedBox(height: 16),
                _section(
                  isDark,
                  'YEAR-BY-YEAR DETAIL',
                  Icons.calendar_view_month_rounded,
                  child: _allTimeYearlyList(isDark, yearly),
                ),
                const SizedBox(height: 16),
              ],
              _section(
                isDark,
                'ABOUT ALL-TIME DEBT',
                Icons.info_outline_rounded,
                child: _infoText(
                  isDark,
                  'This is your total sleep debt since ${yearly.isNotEmpty ? yearly.first.year : "records began"}. '
                  'Each night you slept less than your ${targetHours.toStringAsFixed(1)}h target added to this total. '
                  'Missing nights count as full target debt. Try to gradually reduce debt with extra sleep on rest days.',
                ),
              ),
            ],
          );
        },
      );
    }

    return FutureBuilder<dynamic>(
      future: _fetchData(service, range, targetHours),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 80),
            child: Center(child: CircularProgressIndicator(color: _gold)),
          );
        }
        final data = snap.data!;
        final totalMinutes = _totalFromData(data);
        final h = totalMinutes ~/ 60;
        final m = totalMinutes % 60;
        final formatted = '${h}h ${m}m';

        final prevRange = _previousRange();
        final prevFuture = prevRange != null
            ? _fetchData(service, prevRange, targetHours)
            : null;

        return FutureBuilder<dynamic>(
          future: prevFuture,
          builder: (context, prevSnap) {
            final prevMinutes =
                prevSnap.hasData ? _totalFromData(prevSnap.data!) : null;
            final trend = prevMinutes != null
                ? (prevMinutes - totalMinutes).sign // + = improving, - = worsening
                : 0;

            return FutureBuilder<List<DailyDebtEntry>>(
              future: _fetchDailyContext(service, range, targetHours),
              builder: (context, dailySnap) {
                final dailyContext = dailySnap.data ?? const <DailyDebtEntry>[];
                final hasDailyContext = dailyContext.isNotEmpty;

                return Column(
                  children: [
                    _heroCard(isDark, totalMinutes, formatted, trend,
                        targetHours: targetHours),
                    const SizedBox(height: 16),
                    if (prevMinutes != null)
                      _periodComparison(isDark, totalMinutes, prevMinutes),
                    const SizedBox(height: 16),
                    _quickStats(isDark, data, totalMinutes, targetHours),
                    const SizedBox(height: 16),
                    if (hasDailyContext)
                      _debtHeatmap(isDark, dailyContext, targetHours, range)
                    else
                      _insufficientDataSection(
                        isDark,
                        'DEBT CALENDAR',
                        Icons.calendar_today_rounded,
                        'No daily records for this period yet. '
                            'Log sleep to unlock calendar and detailed visuals.',
                      ),
                    const SizedBox(height: 16),
                    _barChart(isDark, data, targetHours),
                    const SizedBox(height: 16),
                    _trendChart(isDark, data),
                    const SizedBox(height: 16),
                    if (dailyContext.length >= 7)
                      _weekdayPattern(isDark, dailyContext)
                    else
                      _insufficientDataSection(
                        isDark,
                        'WEEKDAY DEBT PATTERN',
                        Icons.date_range_rounded,
                        'Need at least 7 daily points to analyze weekday pattern.',
                      ),
                    const SizedBox(height: 16),
                    _debtSourceBreakdown(isDark, dailyContext, targetHours),
                    const SizedBox(height: 16),
                    _detailList(isDark, data, targetHours),
                    const SizedBox(height: 16),
                    _observations(isDark, dailyContext, totalMinutes, targetHours),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Future<dynamic> _fetchData(
    SleepDebtReportService service,
    ({DateTime start, DateTime end}) range,
    double targetHours,
  ) async {
    switch (_period) {
      case _DebtPeriod.daily:
        return service.getDailyBreakdown(
          start: range.start,
          end: range.end,
          targetHours: targetHours,
        );
      case _DebtPeriod.weekly:
        return service.getWeeklyBreakdown(
          start: range.start,
          end: range.end,
          targetHours: targetHours,
        );
      case _DebtPeriod.monthly:
        return service.getMonthlyBreakdown(
          start: range.start,
          end: range.end,
          targetHours: targetHours,
        );
      case _DebtPeriod.yearly:
        return service.getYearlyBreakdown(
          start: range.start,
          end: range.end,
          targetHours: targetHours,
        );
      case _DebtPeriod.allTime:
        return null;
    }
  }

  Future<List<DailyDebtEntry>> _fetchDailyContext(
    SleepDebtReportService service,
    ({DateTime start, DateTime end}) range,
    double targetHours,
  ) {
    return service.getDailyBreakdown(
      start: range.start,
      end: range.end,
      targetHours: targetHours,
    );
  }

  ({DateTime start, DateTime end})? _previousRange() {
    final a = DateTime(_anchor.year, _anchor.month, _anchor.day);
    switch (_period) {
      case _DebtPeriod.daily:
        return (
          start: a.subtract(const Duration(days: 13)),
          end: a.subtract(const Duration(days: 7)),
        );
      case _DebtPeriod.weekly:
        final mon = a.subtract(Duration(days: (a.weekday - 1) % 7));
        final prevMon = mon.subtract(const Duration(days: 7));
        return (
          start: prevMon,
          end: prevMon.add(const Duration(days: 6)),
        );
      case _DebtPeriod.monthly:
        return (
          start: DateTime(a.year, a.month - 1, 1),
          end: DateTime(a.year, a.month, 0),
        );
      case _DebtPeriod.yearly:
        return (
          start: DateTime(a.year - 1, 1, 1),
          end: DateTime(a.year - 1, 12, 31),
        );
      case _DebtPeriod.allTime:
        return null;
    }
  }

  int _totalFromData(dynamic data) {
    if (data is List<DailyDebtEntry>) return data.fold<int>(0, (s, e) => s + e.debtMinutes);
    if (data is List<WeeklyDebtEntry>) return data.fold<int>(0, (s, e) => s + e.debtMinutes);
    if (data is List<MonthlyDebtEntry>) return data.fold<int>(0, (s, e) => s + e.debtMinutes);
    if (data is List<YearlyDebtEntry>) return data.fold<int>(0, (s, e) => s + e.debtMinutes);
    return 0;
  }

  // ══════════════════════════ HERO CARD ═══════════════════════════════
  Widget _heroCard(
    bool isDark,
    int totalMinutes,
    String formatted,
    int trend, {
    double targetHours = 8.0,
  }) {
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
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _gold.withOpacity(isDark ? 0.15 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.trending_down_rounded, size: 18, color: _gold),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _period == _DebtPeriod.allTime ? 'All-Time Debt' : 'Total Debt',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ),
              if (trend != 0) const SizedBox(width: 8),
              if (trend != 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (trend > 0 ? AppColors.success : AppColors.error)
                        .withOpacity(isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        trend > 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                        size: 14,
                        color: trend > 0 ? AppColors.success : AppColors.error,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        trend > 0 ? 'Improving' : 'Worsening',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: trend > 0 ? AppColors.success : AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatted,
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: totalMinutes > 0
                          ? AppColors.error
                          : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    _periodLabel(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (totalMinutes > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '~${(totalMinutes / (targetHours * 60)).ceil()} night${(totalMinutes / (targetHours * 60)).ceil() != 1 ? 's' : ''} at ${targetHours == targetHours.truncateToDouble() ? targetHours.toInt() : targetHours.toStringAsFixed(1)}h to clear',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _periodLabel() {
    switch (_period) {
      case _DebtPeriod.daily:
        return 'Last 7 days';
      case _DebtPeriod.weekly:
        return 'This week (Mon–Sun)';
      case _DebtPeriod.monthly:
        return 'This month';
      case _DebtPeriod.yearly:
        return 'This year';
      case _DebtPeriod.allTime:
        return 'Since first record';
    }
  }

  // ══════════════════════════ PERIOD COMPARISON ══════════════════════════
  Widget _periodComparison(bool isDark, int current, int previous) {
    final diff = previous - current;
    final diffAbs = diff.abs();
    final h = diffAbs ~/ 60;
    final m = diffAbs % 60;
    final diffStr = '${h}h ${m}m';
    final improving = diff > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (improving ? AppColors.success : AppColors.error)
            .withOpacity(isDark ? 0.08 : 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (improving ? AppColors.success : AppColors.error).withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            improving ? Icons.thumb_up_rounded : Icons.warning_amber_rounded,
            size: 24,
            color: improving ? AppColors.success : AppColors.error,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  improving
                      ? '${diffStr} less debt than previous period'
                      : '${diffStr} more debt than previous period',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  improving ? 'Keep it up!' : 'Try to catch up on sleep',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════ QUICK STATS ═══════════════════════════════
  Widget _quickStats(bool isDark, dynamic data, int totalMinutes, double targetHours) {
    int nightsWithDebt = 0;
    int totalNights = 0;

    if (data is List<DailyDebtEntry>) {
      totalNights = data.length;
      nightsWithDebt = data.where((e) => e.debtMinutes > 0).length;
    } else if (data is List<WeeklyDebtEntry>) {
      for (final e in data) {
        totalNights += e.nightsWithData + e.nightsMissing;
      }
      nightsWithDebt = data.where((e) => e.debtMinutes > 0).length;
    } else if (data is List<MonthlyDebtEntry>) {
      totalNights = data.fold<int>(0, (s, e) => s + e.nightsInMonth);
      nightsWithDebt = data.where((e) => e.debtMinutes > 0).length;
    } else if (data is List<YearlyDebtEntry>) {
      totalNights = data.length;
      nightsWithDebt = data.where((e) => e.debtMinutes > 0).length;
    }

    int targetHit = 0;
    if (data is List<DailyDebtEntry>) {
      targetHit = data.where((e) => e.debtMinutes == 0).length;
      totalNights = data.length;
    } else if (data is List<WeeklyDebtEntry>) {
      targetHit = data.where((e) => e.debtMinutes == 0).length;
      totalNights = data.length;
    } else if (data is List<MonthlyDebtEntry>) {
      targetHit = data.where((e) => e.debtMinutes == 0).length;
      totalNights = data.length;
    } else if (data is List<YearlyDebtEntry>) {
      targetHit = data.where((e) => e.debtMinutes == 0).length;
      totalNights = data.length;
    }
    final targetHitPct = totalNights > 0 ? (targetHit / totalNights * 100).round() : 0;
    final avgPerNight = totalNights > 0 ? totalMinutes / totalNights : 0;
    final avgH = (avgPerNight / 60).floor();
    final avgM = (avgPerNight % 60).round();

    return Row(
      children: [
        _statChip(isDark, Icons.trending_down_rounded,
            '${totalMinutes ~/ 60}h ${totalMinutes % 60}m', 'Total Debt', AppColors.error),
        const SizedBox(width: 8),
        _statChip(isDark, Icons.check_circle_rounded,
            '$targetHitPct%', 'Target Hit', AppColors.success),
        const SizedBox(width: 8),
        _statChip(isDark, Icons.nightlight_round,
            '$nightsWithDebt', 'Nights in Debt', AppColors.warning),
        const SizedBox(width: 8),
        _statChip(isDark, Icons.schedule_rounded,
            '${avgH}h ${avgM}m', 'Avg/Night', AppColors.info),
      ],
    );
  }

  Widget _quickStatsAllTime(bool isDark, int total, int yearsCount, double targetHours) {
    final h = total ~/ 60;
    final m = total % 60;
    return Row(
      children: [
        _statChip(isDark, Icons.history_rounded, '${h}h ${m}m', 'Total', AppColors.error),
        const SizedBox(width: 8),
        _statChip(isDark, Icons.calendar_today_rounded, '$yearsCount', 'Years', _gold),
        const SizedBox(width: 8),
        _statChip(isDark, Icons.flag_rounded, targetHours.toStringAsFixed(1), 'Target (h)', AppColors.info),
      ],
    );
  }

  Widget _statChip(bool isDark, IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
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
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════ DEBT HEATMAP ═══════════════════════════════
  Color _debtHeatColor(bool isDark, int debtMinutes, int targetMinutes) {
    if (debtMinutes <= 0) return AppColors.success.withOpacity(isDark ? 0.3 : 0.4);
    final pct = (debtMinutes / targetMinutes).clamp(0.0, 1.0);
    if (pct >= 1.0) return AppColors.error;
    if (pct >= 0.75) return AppColors.error.withOpacity(0.85);
    if (pct >= 0.5) return AppColors.error.withOpacity(0.6);
    if (pct >= 0.25) return AppColors.warning.withOpacity(0.8);
    return AppColors.warning.withOpacity(0.4);
  }

  Color _debtHeatEmpty(bool isDark) =>
      isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04);

  Widget _debtHeatmap(
    bool isDark,
    List<DailyDebtEntry> daily,
    double targetHours,
    ({DateTime start, DateTime end}) range,
  ) {
    final targetMinutes = (targetHours * 60).round();
    final dayLookup = <int, DailyDebtEntry>{};
    for (final e in daily) {
      dayLookup[e.date.day + e.date.month * 100 + e.date.year * 10000] = e;
    }

    final allDates = <DateTime>[];
    var d = range.start;
    while (!d.isAfter(range.end)) {
      allDates.add(d);
      d = d.add(const Duration(days: 1));
    }

    if (allDates.length <= 7) {
      return _section(isDark, 'DEBT CALENDAR', Icons.calendar_today_rounded,
          child: Row(
            children: allDates.map((date) {
              final key = date.day + date.month * 100 + date.year * 10000;
              final entry = dayLookup[key];
              final debt = entry?.debtMinutes ?? 0;
              final color = entry != null
                  ? _debtHeatColor(isDark, debt, targetMinutes)
                  : _debtHeatEmpty(isDark);
              return Expanded(
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    height: 56,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                      border: date.day == DateTime.now().day &&
                              date.month == DateTime.now().month &&
                              date.year == DateTime.now().year
                          ? Border.all(color: _gold, width: 1.5)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${date.day}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: debt > 0
                                ? (debt >= targetMinutes ? Colors.white : Colors.black87)
                                : (isDark ? Colors.white54 : Colors.black45),
                          ),
                        ),
                        if (entry != null)
                          Text(
                            entry.formattedDebt,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: debt > 0
                                  ? (debt >= targetMinutes ? Colors.white70 : Colors.black54)
                                  : (isDark ? Colors.white38 : Colors.black38),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ));
    }

    if (allDates.length <= 31) {
      final firstDay = allDates.first;
      final offset = (firstDay.weekday - 1) % 7;
      return _section(isDark, 'DEBT CALENDAR', Icons.calendar_today_rounded,
          child: Column(
            children: [
              Row(
                children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                    .map((l) => Expanded(
                          child: Center(
                            child: Text(
                              l,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                          ),
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
                    final key = date.day + date.month * 100 + date.year * 10000;
                    final entry = dayLookup[key];
                    final debt = entry?.debtMinutes ?? 0;
                    final color = entry != null
                        ? _debtHeatColor(isDark, debt, targetMinutes)
                        : _debtHeatEmpty(isDark);
                    return Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(6),
                        border: date.day == DateTime.now().day &&
                                date.month == DateTime.now().month &&
                                date.year == DateTime.now().year
                            ? Border.all(color: _gold, width: 1)
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          '${date.day}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: debt > 0
                                ? (debt >= targetMinutes ? Colors.white : Colors.black87)
                                : (isDark ? Colors.white24 : Colors.black26),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 12),
              _heatLegendDebt(isDark),
            ],
          ));
    }

    return const SizedBox.shrink();
  }

  Widget _heatLegendDebt(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('None ', style: TextStyle(fontSize: 9, color: isDark ? Colors.white38 : Colors.black38)),
        Container(width: 12, height: 10, decoration: BoxDecoration(color: AppColors.success.withOpacity(0.5), borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text('Low ', style: TextStyle(fontSize: 9, color: isDark ? Colors.white38 : Colors.black38)),
        Container(width: 12, height: 10, decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.6), borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text('High ', style: TextStyle(fontSize: 9, color: isDark ? Colors.white38 : Colors.black38)),
        Container(width: 12, height: 10, decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(2))),
      ],
    );
  }

  // ══════════════════════════ DEBT SOURCE BREAKDOWN ═══════════════════════
  Widget _debtSourceBreakdown(bool isDark, dynamic data, double targetHours) {
    int fromShort = 0;
    int fromMissing = 0;

    if (data is List<DailyDebtEntry>) {
      for (final e in data) {
        if (e.hadData)
          fromShort += e.debtMinutes;
        else
          fromMissing += e.debtMinutes;
      }
    }
    if (data is! List<DailyDebtEntry> || (fromShort + fromMissing) == 0) {
      return const SizedBox.shrink();
    }

    final total = fromShort + fromMissing;
    final shortPct = total > 0 ? (fromShort / total * 100).round() : 0;
    final missingPct = total > 0 ? (fromMissing / total * 100).round() : 0;

    return _section(isDark, 'DEBT SOURCE', Icons.pie_chart_rounded,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _sourceBar(isDark, 'Short sleep', fromShort, shortPct, AppColors.error),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _sourceBar(isDark, 'Missing nights', fromMissing, missingPct, AppColors.warning),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _sourceLegend(isDark, 'Short sleep', fromShort, shortPct, AppColors.error),
                _sourceLegend(isDark, 'Missing', fromMissing, missingPct, AppColors.warning),
              ],
            ),
          ],
        ));
  }

  Widget _sourceBar(bool isDark, String label, int minutes, int pct, Color color) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.black45)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (pct / 100).clamp(0.0, 1.0),
            minHeight: 10,
            backgroundColor: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: 4),
        Text('${h}h ${m}m ($pct%)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
      ],
    );
  }

  Widget _sourceLegend(bool isDark, String label, int minutes, int pct, Color color) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text('$label: ${h}h ${m}m', style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87)),
      ],
    );
  }

  // ══════════════════════════ WEEKDAY PATTERN ═════════════════════════════
  Widget _weekdayPattern(bool isDark, List<DailyDebtEntry> daily) {
    final byWeekday = <int, List<int>>{};
    for (final e in daily) {
      byWeekday.putIfAbsent(e.date.weekday, () => []).add(e.debtMinutes);
    }
    final avgs = <int, double>{};
    for (final wd in [1, 2, 3, 4, 5, 6, 7]) {
      final list = byWeekday[wd] ?? [];
      avgs[wd] = list.isEmpty ? 0 : list.reduce((a, b) => a + b) / list.length / 60.0;
    }
    final maxH = avgs.values.reduce(max).clamp(0.5, 24.0);
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return _section(isDark, 'WEEKDAY DEBT PATTERN', Icons.date_range_rounded,
        child: SizedBox(
          height: 180,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (i) {
              final wd = i + 1;
              final h = avgs[wd] ?? 0;
              final pct = maxH > 0 ? h / maxH : 0.0;
              final barH = (pct * 120).clamp(4.0, 120.0);
              final isWorst = h == maxH && h > 0;
              return Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      h > 0 ? '${h.toStringAsFixed(1)}h' : '',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: isWorst ? AppColors.error : (isDark ? Colors.white54 : Colors.black45),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: barH,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: h > 0
                            ? (isWorst ? AppColors.error : AppColors.error.withOpacity(0.6))
                            : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04)),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isWorst ? AppColors.error : (isDark ? Colors.white54 : Colors.black45),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ));
  }

  // ══════════════════════════ OBSERVATIONS ═══════════════════════════════
  Widget _observations(bool isDark, dynamic data, int totalMinutes, double targetHours) {
    final obs = <String>[];

    if (data is List<DailyDebtEntry>) {
      if (data.isEmpty) return const SizedBox.shrink();

      final withDebt = data.where((e) => e.debtMinutes > 0).length;
      final missing = data.where((e) => !e.hadData).length;
      final shortSleep = data.where((e) => e.hadData && e.debtMinutes > 0).length;

      if (totalMinutes > 0) {
        final h = totalMinutes ~/ 60;
        obs.add('You accumulated ${h}h ${totalMinutes % 60}m of sleep debt this period. '
            'Consider adding 30–60 extra minutes on rest days to catch up gradually.');
      }

      if (missing > 0) {
        obs.add('$missing night${missing != 1 ? 's' : ''} had no logged sleep (counted as full target debt). '
            'Logging every night gives a more accurate picture.');
      }

      if (shortSleep > 0 && withDebt > 0) {
        obs.add('$shortSleep night${shortSleep != 1 ? 's' : ''} you slept but were under your ${targetHours.toStringAsFixed(1)}h target. '
            'Try going to bed 15–30 minutes earlier on busy days.');
      }

      if (data.length >= 14) {
        final firstHalf = data.take(data.length ~/ 2).fold<int>(0, (s, e) => s + e.debtMinutes);
        final secondHalf = data.skip(data.length ~/ 2).fold<int>(0, (s, e) => s + e.debtMinutes);
        final diff = secondHalf - firstHalf;
        if (diff > 60) {
          final dh = diff ~/ 60;
          obs.add('Your debt increased by ${dh}h ${diff % 60}m in the second half of this period. '
              'Review recent habits—stress, schedule changes, or screen time may be affecting sleep.');
        } else if (diff < -60) {
          final dh = (-diff) ~/ 60;
          obs.add('Great progress! You reduced debt by ${dh}h ${(-diff) % 60}m in the second half. Keep it up!');
        }
      }

      final byWeekday = <int, int>{};
      for (final e in data.where((x) => x.debtMinutes > 0)) {
        byWeekday[e.date.weekday] = (byWeekday[e.date.weekday] ?? 0) + e.debtMinutes;
      }
      if (byWeekday.isNotEmpty) {
        final worstWd = byWeekday.entries.reduce((a, b) => a.value > b.value ? a : b);
        const dayNames = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
        obs.add('${dayNames[worstWd.key]} contributes the most to your debt. '
            'Consider protecting sleep especially on ${dayNames[worstWd.key]} nights.');
      }
    }

    if (obs.isEmpty) return const SizedBox.shrink();

    return _section(isDark, 'INSIGHTS', Icons.lightbulb_rounded,
        child: Column(
          children: obs
              .map((line) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(Icons.insights_rounded, size: 16, color: _gold),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            line,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ))
              .toList(),
        ));
  }

  // ══════════════════════════ ALL-TIME CHARTS & LIST ═══════════════════════
  Widget _allTimeYearlyBarChart(bool isDark, List<YearlyDebtEntry> yearly) {
    final maxM = yearly.map((e) => e.debtMinutes).reduce(max).clamp(1, 100000);
    final maxY = (maxM / 60.0) * 1.15;

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          barGroups: yearly.asMap().entries.map((e) {
            final hours = e.value.debtMinutes / 60.0;
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: hours,
                  color: AppColors.error,
                  width: yearly.length > 10 ? 8 : 16,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            );
          }).toList(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (v, _) => Text(
                  '${v.toStringAsFixed(0)}h',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= yearly.length) return const SizedBox.shrink();
                  return Text(
                    '${yearly[i].year}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, gi, rod, ri) {
                final e = yearly[group.x];
                return BarTooltipItem(
                  '${e.year}\n${e.formattedDebt}\n${e.nightsWithData} nights logged',
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _allTimeYearlyList(bool isDark, List<YearlyDebtEntry> yearly) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: yearly.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
      ),
      itemBuilder: (_, i) {
        final e = yearly[i];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    '${e.year}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.error,
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
                      '${e.nightsWithData} nights logged',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(isDark ? 0.15 : 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  e.formattedDebt,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ══════════════════════════ BAR CHART (unchanged, streamlined) ═══════════
  Widget _barChart(bool isDark, dynamic data, double targetHours) {
    List<({String label, int minutes})> items = [];
    if (data is List<DailyDebtEntry>) {
      if (data.isEmpty) {
        return _insufficientDataSection(
          isDark,
          'DAILY DEBT',
          Icons.bar_chart_rounded,
          'No daily data available in this range yet.',
        );
      }
      items = data.map((e) => (label: DateFormat('d').format(e.date), minutes: e.debtMinutes)).toList();
    } else if (data is List<WeeklyDebtEntry>) {
      if (data.isEmpty) {
        return _insufficientDataSection(
          isDark,
          'WEEKLY DEBT',
          Icons.bar_chart_rounded,
          'Need at least one completed week with data.',
        );
      }
      items = data.map((e) => (label: DateFormat('d').format(e.weekStart), minutes: e.debtMinutes)).toList();
    } else if (data is List<MonthlyDebtEntry>) {
      if (data.isEmpty) {
        return _insufficientDataSection(
          isDark,
          'MONTHLY DEBT',
          Icons.bar_chart_rounded,
          'No monthly data available yet for this selection.',
        );
      }
      items = data.map((e) => (label: DateFormat('MMM').format(DateTime(e.year, e.month)), minutes: e.debtMinutes)).toList();
    } else if (data is List<YearlyDebtEntry>) {
      if (data.isEmpty) {
        return _insufficientDataSection(
          isDark,
          'YEARLY DEBT',
          Icons.bar_chart_rounded,
          'No yearly data available yet.',
        );
      }
      items = data.map((e) => (label: '${e.year}', minutes: e.debtMinutes)).toList();
    }
    if (items.isEmpty) {
      return _insufficientDataSection(
        isDark,
        'DEBT CHART',
        Icons.bar_chart_rounded,
        'Not enough data to draw this chart yet.',
      );
    }

    final maxM = items.map((e) => e.minutes).reduce(max).clamp(1, 10000);
    final maxY = (maxM / 60.0) * 1.15;

    return _section(
      isDark,
      _period == _DebtPeriod.daily ? 'DAILY DEBT' : _period == _DebtPeriod.weekly
          ? 'WEEKLY DEBT'
          : _period == _DebtPeriod.monthly ? 'MONTHLY DEBT' : 'YEARLY DEBT',
      Icons.bar_chart_rounded,
      child: SizedBox(
        height: 200,
        child: BarChart(
          BarChartData(
            maxY: maxY,
            barGroups: items.asMap().entries.map((e) {
              final minutes = e.value.minutes;
              final hours = minutes / 60.0;
              return BarChartGroupData(
                x: e.key,
                barRods: [
                  BarChartRodData(
                    toY: hours,
                    color: minutes > 0 ? AppColors.error : AppColors.success,
                    width: items.length > 20 ? 6 : 12,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ],
              );
            }).toList(),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04),
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  getTitlesWidget: (v, _) => Text(
                    '${v.toStringAsFixed(0)}h',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: max(1, (items.length / 6).ceilToDouble()),
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= items.length) return const SizedBox.shrink();
                    return Text(
                      items[i].label,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    );
                  },
                ),
              ),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, gi, rod, ri) {
                  final m = items[group.x].minutes;
                  final h = m ~/ 60;
                  final min = m % 60;
                  return BarTooltipItem(
                    '${items[group.x].label}\n${h}h ${min}m',
                    const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════ TREND CHART ═════════════════════════════════
  Widget _trendChart(bool isDark, dynamic data) {
    List<int> minutesList = [];
    if (data is List<DailyDebtEntry>) minutesList = data.map((e) => e.debtMinutes).toList();
    else if (data is List<WeeklyDebtEntry>) minutesList = data.map((e) => e.debtMinutes).toList();
    else if (data is List<MonthlyDebtEntry>) minutesList = data.map((e) => e.debtMinutes).toList();
    else if (data is List<YearlyDebtEntry>) minutesList = data.map((e) => e.debtMinutes).toList();
    if (minutesList.length < 2) {
      return _insufficientDataSection(
        isDark,
        'DEBT TREND',
        Icons.show_chart_rounded,
        'Need at least 2 data points to render a trend line.',
      );
    }

    final spots = minutesList.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value / 60.0)).toList();
    final maxY = minutesList.map((m) => m / 60.0).reduce(max) * 1.15;

    return _section(isDark, 'DEBT TREND', Icons.show_chart_rounded,
        child: SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: maxY.clamp(2, 24),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    getTitlesWidget: (v, _) => Text(
                      '${v.toStringAsFixed(0)}h',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ),
                ),
                bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
                    final m = minutesList[s.x.toInt()];
                    final h = m ~/ 60;
                    final min = m % 60;
                    return LineTooltipItem(
                      '${h}h ${min}m',
                      const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
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
                  color: AppColors.error,
                  dotData: FlDotData(
                    show: minutesList.length <= 31,
                    getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                      radius: 3,
                      color: AppColors.error,
                      strokeWidth: 2,
                      strokeColor: isDark ? const Color(0xFF2A2D3A) : Colors.white,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.error.withOpacity(0.2),
                        AppColors.error.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }

  // ══════════════════════════ DETAIL LIST (enhanced) ═══════════════════════
  Widget _detailList(bool isDark, dynamic data, double targetHours) {
    List<Widget> rows = [];
    if (data is List<DailyDebtEntry>) {
      final showItems = data.take(28).toList();
      for (final e in showItems) {
        final actualStr = e.hadData
            ? '${e.actualMinutes ~/ 60}h ${e.actualMinutes % 60}m'
            : '—';
        final targetStr = '${e.targetMinutes ~/ 60}h';
        rows.add(_detailRowRich(
          isDark,
          DateFormat('EEE, MMM d').format(e.date),
          e.formattedDebt,
          actualStr,
          targetStr,
          e.hadData,
        ));
      }
    } else if (data is List<WeeklyDebtEntry>) {
      rows = data.map((e) {
        final end = e.weekStart.add(const Duration(days: 6));
        final label = '${DateFormat('MMM d').format(e.weekStart)} – ${DateFormat('MMM d').format(end)}';
        return _detailRowRich(isDark, label, e.formattedDebt, '${e.nightsWithData} logged', '7 nights', e.nightsWithData > 0);
      }).toList();
    } else if (data is List<MonthlyDebtEntry>) {
      rows = data.map((e) {
        final label = DateFormat('MMMM yyyy').format(DateTime(e.year, e.month));
        return _detailRowRich(isDark, label, e.formattedDebt, '${e.nightsWithData} nights', '${e.nightsInMonth} days', e.nightsWithData > 0);
      }).toList();
    } else if (data is List<YearlyDebtEntry>) {
      rows = data.map((e) => _detailRowRich(isDark, '${e.year}', e.formattedDebt, '${e.nightsWithData} nights', '365 days', e.nightsWithData > 0)).toList();
    }
    if (rows.isEmpty) return const SizedBox.shrink();

    return _section(isDark, 'DAILY BREAKDOWN', Icons.view_list_rounded,
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rows.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
          ),
          itemBuilder: (_, i) => rows[i],
        ));
  }

  Widget _detailRowRich(
    bool isDark,
    String label,
    String debt,
    String subtitle,
    String targetInfo,
    bool hadData,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hadData ? 'Actual: $subtitle · Target: $targetInfo' : 'No data · Target: $targetInfo',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: hadData
                      ? AppColors.error.withOpacity(isDark ? 0.15 : 0.1)
                      : AppColors.warning.withOpacity(isDark ? 0.15 : 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  debt,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: hadData ? AppColors.error : AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════ SECTION & HELPERS ═══════════════════════════
  Widget _insufficientDataSection(
    bool isDark,
    String title,
    IconData icon,
    String message,
  ) {
    return _section(
      isDark,
      title,
      icon,
      child: _infoText(
        isDark,
        message,
      ),
    );
  }

  Widget _section(bool isDark, String title, IconData icon, {required Widget child}) {
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
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: _gold),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: _gold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _infoText(bool isDark, String msg) {
    return Text(
      msg,
      style: TextStyle(
        fontSize: 13,
        height: 1.5,
        color: isDark ? Colors.white54 : Colors.black45,
      ),
    );
  }

  Widget _emptyState(bool isDark, String msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(Icons.error_outline_rounded, size: 48, color: isDark ? Colors.white24 : Colors.black26),
          const SizedBox(height: 12),
          Text(msg, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: isDark ? Colors.white38 : Colors.black38)),
        ],
      ),
    );
  }

  ({DateTime start, DateTime end}) _range() {
    final a = DateTime(_anchor.year, _anchor.month, _anchor.day);
    switch (_period) {
      case _DebtPeriod.daily:
        return (start: a.subtract(const Duration(days: 6)), end: a);
      case _DebtPeriod.weekly:
        final daysSinceMonday = (a.weekday - 1) % 7;
        final monday = a.subtract(Duration(days: daysSinceMonday));
        return (start: monday, end: monday.add(const Duration(days: 6)));
      case _DebtPeriod.monthly:
        return (start: DateTime(a.year, a.month, 1), end: DateTime(a.year, a.month + 1, 0));
      case _DebtPeriod.yearly:
        return (start: DateTime(a.year, 1, 1), end: DateTime(a.year, 12, 31));
      case _DebtPeriod.allTime:
        return (start: DateTime(2020, 1, 1), end: DateTime.now());
    }
  }

  void _shift(int dir) {
    setState(() {
      switch (_period) {
        case _DebtPeriod.daily:
          _anchor = _anchor.add(Duration(days: dir));
          break;
        case _DebtPeriod.weekly:
          _anchor = _anchor.add(Duration(days: 7 * dir));
          break;
        case _DebtPeriod.monthly:
          _anchor = DateTime(_anchor.year, _anchor.month + dir, 1);
          break;
        case _DebtPeriod.yearly:
          _anchor = DateTime(_anchor.year + dir, 1, 1);
          break;
        case _DebtPeriod.allTime:
          break;
      }
    });
  }
}
