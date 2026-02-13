import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/dark_gradient.dart';
import '../../data/models/bill.dart';
import '../../data/models/bill_category.dart';
import '../../utils/currency_utils.dart';
import '../providers/finance_providers.dart';

enum _ReportPeriod { month, quarter, year, all }

class BillsReportScreen extends ConsumerStatefulWidget {
  const BillsReportScreen({super.key});

  @override
  ConsumerState<BillsReportScreen> createState() => _BillsReportScreenState();
}

class _BillsReportScreenState extends ConsumerState<BillsReportScreen> {
  static const _accent = Color(0xFFCDAF56);
  static const _surfaceDark = Color(0xFF1A1D23);
  static const _bgDark = Color(0xFF0D0F14);

  _ReportPeriod _period = _ReportPeriod.month;
  DateTime _anchor = DateTime.now();

  // ─── build ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final billsAsync = ref.watch(activeBillsProvider);
    final catsAsync = ref.watch(activeBillCategoriesProvider);
    final currency = ref.watch(defaultCurrencyProvider).value ?? 'ETB';

    final body = CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        _appBar(isDark),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _periodChips(isDark),
              if (_period != _ReportPeriod.all) ...[
                const SizedBox(height: 10),
                _dateNav(isDark),
              ],
              const SizedBox(height: 20),
              billsAsync.when(
                data: (bills) => _body(
                  bills,
                  catsAsync.value ?? [],
                  isDark,
                  currency,
                ),
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
                  child: Center(
                    child: CircularProgressIndicator(color: _accent),
                  ),
                ),
                error: (e, _) => _emptyState(
                  isDark,
                  'Something went wrong',
                  Icons.error_outline_rounded,
                ),
              ),
            ]),
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: isDark ? _bgDark : const Color(0xFFF5F6FA),
      body: isDark ? DarkGradient.wrap(child: body) : body,
    );
  }

  // ─── sections ───────────────────────────────────────────────────────
  Widget _body(
    List<Bill> bills,
    List<BillCategory> cats,
    bool isDark,
    String cur,
  ) {
    final active = bills.where((b) => b.isActive).toList();
    if (active.isEmpty) {
      return _emptyState(isDark, 'No active bills yet', Icons.receipt_long_rounded);
    }

    final range = _range();
    final commitment = _totalCommitment(active, range, cur);
    final sym = CurrencyUtils.getCurrencySymbol(cur);

    return Column(
      children: [
        _heroCard(active, commitment, sym, isDark),
        const SizedBox(height: 16),
        _quickStats(active, commitment, sym, isDark, cur),
        const SizedBox(height: 16),
        _trendCard(bills, isDark, cur),
        const SizedBox(height: 16),
        _categoryCard(bills, cats, isDark, cur),
        const SizedBox(height: 16),
        _comparisonCard(active, range, isDark, cur),
        const SizedBox(height: 16),
        _timelineCard(bills, isDark),
      ],
    );
  }

  // ─── app bar ────────────────────────────────────────────────────────
  SliverAppBar _appBar(bool isDark) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: isDark ? _surfaceDark : Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: _iconBtn(
        icon: Icons.arrow_back_rounded,
        isDark: isDark,
        onTap: () => Navigator.pop(context),
      ),
      title: Text(
        'Bills Report',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : const Color(0xFF1E1E1E),
        ),
      ),
      centerTitle: false,
    );
  }

  Widget _iconBtn({
    required IconData icon,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Material(
        color: isDark
            ? Colors.white.withOpacity(0.08)
            : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, size: 20, color: isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }

  // ─── period chips ───────────────────────────────────────────────────
  Widget _periodChips(bool isDark) {
    const items = [
      (_ReportPeriod.month, 'Month'),
      (_ReportPeriod.quarter, 'Quarter'),
      (_ReportPeriod.year, 'Year'),
      (_ReportPeriod.all, 'All'),
    ];
    return Row(
      children: items.map((e) {
        final sel = _period == e.$1;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: e.$1 == _ReportPeriod.all ? 0 : 8),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _period = e.$1);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: sel
                      ? _accent
                      : (isDark ? Colors.white.withOpacity(0.04) : Colors.white),
                  borderRadius: BorderRadius.circular(12),
                  border: sel
                      ? null
                      : Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.06)
                              : Colors.black.withOpacity(0.06),
                        ),
                ),
                child: Text(
                  e.$2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: sel
                        ? Colors.black87
                        : (isDark ? Colors.white60 : Colors.black54),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── date nav ───────────────────────────────────────────────────────
  Widget _dateNav(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.06),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, size: 22),
            onPressed: () => _shift(-1),
            color: _accent,
            splashRadius: 20,
          ),
          Expanded(
            child: Text(
              _label(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF1E1E1E),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, size: 22),
            onPressed: () => _shift(1),
            color: _accent,
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  // ─── hero card ──────────────────────────────────────────────────────
  Widget _heroCard(
    List<Bill> active,
    double commitment,
    String sym,
    bool isDark,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _accent.withOpacity(0.15),
            _accent.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accent.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded,
                    color: _accent, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Total Commitment',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _label(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: _accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '$sym${_fmt(commitment)}',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                letterSpacing: -1,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${active.where((b) => b.isBill).length} bills  ·  ${active.where((b) => b.isSubscription).length} subscriptions',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }

  // ─── quick stats row ───────────────────────────────────────────────
  Widget _quickStats(
    List<Bill> active,
    double commitment,
    String sym,
    bool isDark,
    String cur,
  ) {
    final endingSoon = active.where((b) {
      if (b.endCondition == 'indefinite') return false;
      if (b.endCondition == 'after_occurrences' && b.endOccurrences != null) {
        return (b.endOccurrences! - b.occurrenceCount) <= 3;
      }
      if (b.endCondition == 'after_amount' && b.endAmount != null) {
        return (b.endAmount! - b.totalPaidAmount) <= b.defaultAmount * 3;
      }
      if (b.endCondition == 'on_date' && b.endDate != null) {
        return b.endDate!.difference(DateTime.now()).inDays <= 30;
      }
      return false;
    }).length;

    final totalOccurrences = active.fold<int>(0, (s, b) => s + b.occurrenceCount);
    final totalPaid = active.fold(0.0, (s, b) => s + b.totalPaidAmount);
    final avg = totalOccurrences > 0 ? totalPaid / totalOccurrences : 0.0;

    return Row(
      children: [
        _statChip(
          icon: Icons.receipt_long_rounded,
          value: active.length.toString(),
          label: 'Active',
          color: const Color(0xFF2196F3),
          isDark: isDark,
        ),
        const SizedBox(width: 8),
        _statChip(
          icon: Icons.timer_outlined,
          value: endingSoon.toString(),
          label: 'Ending',
          color: const Color(0xFFFF9800),
          isDark: isDark,
        ),
        const SizedBox(width: 8),
        _statChip(
          icon: Icons.payments_rounded,
          value: '$sym${_fmtShort(totalPaid)}',
          label: 'Paid',
          color: const Color(0xFF4CAF50),
          isDark: isDark,
        ),
        const SizedBox(width: 8),
        _statChip(
          icon: Icons.show_chart_rounded,
          value: '$sym${_fmtShort(avg)}',
          label: 'Avg',
          color: _accent,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _statChip({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? _surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.04),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white30 : Colors.black26,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── spending trend ─────────────────────────────────────────────────
  Widget _trendCard(List<Bill> bills, bool isDark, String cur) {
    final range = _range();
    final data = _monthlyTrend(bills, range);
    if (data.isEmpty || data.length < 2) return const SizedBox.shrink();

    final maxY = data.values.fold(0.0, (a, b) => a > b ? a : b);
    final sym = CurrencyUtils.getCurrencySymbol(cur);

    return _card(
      isDark: isDark,
      icon: Icons.trending_up_rounded,
      title: 'SPENDING TREND',
      child: SizedBox(
        height: 180,
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY > 0 ? maxY / 3 : 1,
                getDrawingHorizontalLine: (v) => FlLine(
                  color: isDark
                      ? Colors.white.withOpacity(0.04)
                      : Colors.black.withOpacity(0.04),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    getTitlesWidget: (v, _) => Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        '$sym${_fmtShort(v)}',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white24 : Colors.black26,
                        ),
                      ),
                    ),
                  ),
                ),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: 1,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= data.length) return const SizedBox.shrink();
                      // show max 6 labels
                      if (data.length > 6 && i % ((data.length / 6).ceil()) != 0) {
                        return const SizedBox.shrink();
                      }
                      final d = data.keys.toList()[i];
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          DateFormat('MMM').format(d),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: data.entries
                      .toList()
                      .asMap()
                      .entries
                      .map((e) => FlSpot(e.key.toDouble(), e.value.value))
                      .toList(),
                  isCurved: true,
                  curveSmoothness: 0.3,
                  color: _accent,
                  barWidth: 2.5,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                      radius: 3.5,
                      color: _accent,
                      strokeWidth: 2,
                      strokeColor: isDark ? _surfaceDark : Colors.white,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        _accent.withOpacity(0.25),
                        _accent.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) => spots.map((s) {
                    return LineTooltipItem(
                      '$sym${s.y.toStringAsFixed(0)}',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    );
                  }).toList(),
                ),
              ),
              minY: 0,
              maxY: maxY * 1.15,
            ),
          ),
        ),
      ),
    );
  }

  // ─── category breakdown ─────────────────────────────────────────────
  Widget _categoryCard(
    List<Bill> bills,
    List<BillCategory> cats,
    bool isDark,
    String cur,
  ) {
    final range = _range();
    final breakdown = _categoryBreakdown(bills, cats, range, cur);
    if (breakdown.isEmpty) return const SizedBox.shrink();

    final total = breakdown.values.fold(0.0, (a, b) => a + b.$1);
    final sym = CurrencyUtils.getCurrencySymbol(cur);
    final sorted = breakdown.entries.toList()
      ..sort((a, b) => b.value.$1.compareTo(a.value.$1));

    return _card(
      isDark: isDark,
      icon: Icons.donut_large_rounded,
      title: 'BY CATEGORY',
      child: Column(
        children: [
          SizedBox(
            height: 160,
            child: PieChart(
              PieChartData(
                sections: sorted.map((e) {
                  final pct = total > 0 ? (e.value.$1 / total * 100) : 0.0;
                  return PieChartSectionData(
                    value: e.value.$1,
                    title: pct >= 8 ? '${pct.toStringAsFixed(0)}%' : '',
                    color: e.value.$2,
                    radius: 50,
                    titleStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  );
                }).toList(),
                sectionsSpace: 2,
                centerSpaceRadius: 30,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...sorted.map((e) {
            final pct = total > 0 ? (e.value.$1 / total * 100) : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: e.value.$2,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      e.key,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '$sym${_fmt(e.value.$1)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 36,
                    child: Text(
                      '${pct.toStringAsFixed(0)}%',
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: e.value.$2,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── bills vs subscriptions ─────────────────────────────────────────
  Widget _comparisonCard(
    List<Bill> active,
    _DateRange range,
    bool isDark,
    String cur,
  ) {
    final sym = CurrencyUtils.getCurrencySymbol(cur);
    final billsAmt = _totalCommitment(
      active.where((b) => b.isBill).toList(), range, cur,
    );
    final subsAmt = _totalCommitment(
      active.where((b) => b.isSubscription).toList(), range, cur,
    );
    final total = billsAmt + subsAmt;
    if (total == 0) return const SizedBox.shrink();

    final billsPct = billsAmt / total;
    final subsPct = subsAmt / total;

    return _card(
      isDark: isDark,
      icon: Icons.compare_arrows_rounded,
      title: 'BILLS VS SUBSCRIPTIONS',
      child: Column(
        children: [
          // progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  if (billsPct > 0)
                    Flexible(
                      flex: (billsPct * 100).round(),
                      child: Container(color: const Color(0xFF2196F3)),
                    ),
                  if (subsPct > 0)
                    Flexible(
                      flex: (subsPct * 100).round(),
                      child: Container(color: const Color(0xFF9C27B0)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _comparisonSide(
                  label: 'Bills',
                  amount: '$sym${_fmt(billsAmt)}',
                  pct: '${(billsPct * 100).toStringAsFixed(0)}%',
                  color: const Color(0xFF2196F3),
                  isDark: isDark,
                ),
              ),
              Container(
                width: 1,
                height: 48,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                color: isDark
                    ? Colors.white.withOpacity(0.06)
                    : Colors.black.withOpacity(0.06),
              ),
              Expanded(
                child: _comparisonSide(
                  label: 'Subscriptions',
                  amount: '$sym${_fmt(subsAmt)}',
                  pct: '${(subsPct * 100).toStringAsFixed(0)}%',
                  color: const Color(0xFF9C27B0),
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _comparisonSide({
    required String label,
    required String amount,
    required String pct,
    required Color color,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            amount,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          pct,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }

  // ─── upcoming timeline ──────────────────────────────────────────────
  Widget _timelineCard(List<Bill> bills, bool isDark) {
    final now = DateTime.now();
    final cutoff = now.add(const Duration(days: 30));
    final upcoming = bills
        .where((b) =>
            b.isActive &&
            b.nextDueDate != null &&
            !b.nextDueDate!.isAfter(cutoff))
        .toList()
      ..sort((a, b) => a.nextDueDate!.compareTo(b.nextDueDate!));

    // include overdue and upcoming
    final items = upcoming.take(8).toList();
    if (items.isEmpty) return const SizedBox.shrink();

    return _card(
      isDark: isDark,
      icon: Icons.schedule_rounded,
      title: 'UPCOMING PAYMENTS',
      child: Column(
        children: items.asMap().entries.map((entry) {
          final bill = entry.value;
          final days = bill.nextDueDate!.difference(now).inDays;
          final overdue = days < 0;
          final soon = days >= 0 && days <= 3;
          final color = overdue
              ? const Color(0xFFEF5350)
              : (soon ? const Color(0xFFFF9800) : const Color(0xFF4CAF50));
          final sym = CurrencyUtils.getCurrencySymbol(bill.currency);

          return Container(
            margin: EdgeInsets.only(bottom: entry.key < items.length - 1 ? 8 : 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? color.withOpacity(0.06)
                  : color.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      bill.nextDueDate!.day.toString(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: color,
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
                        bill.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _dueLabelShort(days),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$sym${_fmt(bill.defaultAmount)}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── reusable card wrapper ──────────────────────────────────────────
  Widget _card({
    required bool isDark,
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? _surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.04),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _accent, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: _accent,
                    letterSpacing: 1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  // ─── empty state ────────────────────────────────────────────────────
  Widget _emptyState(bool isDark, String msg, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: isDark ? Colors.white12 : Colors.black12),
          const SizedBox(height: 12),
          Text(
            msg,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white30 : Colors.black26,
            ),
          ),
        ],
      ),
    );
  }

  // ─── formatting helpers ─────────────────────────────────────────────
  String _fmt(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 10000) return '${(v / 1000).toStringAsFixed(1)}k';
    if (v == v.truncateToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2);
  }

  String _fmtShort(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }

  String _dueLabelShort(int days) {
    if (days == 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    if (days < 0) return '${days.abs()}d overdue';
    return 'in ${days}d';
  }

  // ─── period helpers ─────────────────────────────────────────────────
  String _label() {
    switch (_period) {
      case _ReportPeriod.month:
        return DateFormat('MMMM yyyy').format(_anchor);
      case _ReportPeriod.quarter:
        final q = (_anchor.month - 1) ~/ 3 + 1;
        return 'Q$q ${_anchor.year}';
      case _ReportPeriod.year:
        return _anchor.year.toString();
      case _ReportPeriod.all:
        return 'All Time';
    }
  }

  void _shift(int dir) {
    setState(() {
      switch (_period) {
        case _ReportPeriod.month:
          _anchor = DateTime(_anchor.year, _anchor.month + dir, 1);
          break;
        case _ReportPeriod.quarter:
          _anchor = DateTime(_anchor.year, _anchor.month + 3 * dir, 1);
          break;
        case _ReportPeriod.year:
          _anchor = DateTime(_anchor.year + dir, 1, 1);
          break;
        case _ReportPeriod.all:
          break;
      }
    });
  }

  _DateRange _range() {
    final b = DateTime(_anchor.year, _anchor.month, 1);
    switch (_period) {
      case _ReportPeriod.month:
        return _DateRange(
          DateTime(b.year, b.month, 1),
          DateTime(b.year, b.month + 1, 0),
        );
      case _ReportPeriod.quarter:
        final q = (b.month - 1) ~/ 3;
        return _DateRange(
          DateTime(b.year, q * 3 + 1, 1),
          DateTime(b.year, q * 3 + 4, 0),
        );
      case _ReportPeriod.year:
        return _DateRange(DateTime(b.year, 1, 1), DateTime(b.year, 12, 31));
      case _ReportPeriod.all:
        return _DateRange(
          DateTime(2000),
          DateTime.now().add(const Duration(days: 1825)),
        );
    }
  }

  // ─── data calculations (logic preserved) ────────────────────────────
  double _totalCommitment(List<Bill> bills, _DateRange r, String cur) {
    double t = 0;
    for (final b in bills) {
      if (b.currency != cur) continue;
      t += b.defaultAmount * _occurrences(b, r.start, r.end).length;
    }
    return t;
  }

  Map<DateTime, double> _monthlyTrend(List<Bill> bills, _DateRange r) {
    final m = <DateTime, double>{};
    var c = DateTime(r.start.year, r.start.month, 1);
    final e = DateTime(r.end.year, r.end.month, 1);
    while (!c.isAfter(e)) {
      final ms = c;
      final me = DateTime(c.year, c.month + 1, 0);
      double t = 0;
      for (final b in bills.where((b) => b.isActive)) {
        t += b.defaultAmount * _occurrences(b, ms, me).length;
      }
      m[c] = t;
      c = DateTime(c.year, c.month + 1, 1);
    }
    return m;
  }

  /// Returns { categoryName: (totalAmount, color) }
  Map<String, (double, Color)> _categoryBreakdown(
    List<Bill> bills,
    List<BillCategory> cats,
    _DateRange r,
    String cur,
  ) {
    final result = <String, (double, Color)>{};
    for (final b in bills.where((b) => b.isActive && b.currency == cur)) {
      final occ = _occurrences(b, r.start, r.end);
      if (occ.isEmpty) continue;
      final cat = cats.firstWhere(
        (c) => c.id == b.categoryId,
        orElse: () => BillCategory(name: 'Other', color: Colors.grey),
      );
      final prev = result[cat.name];
      final amt = (prev?.$1 ?? 0) + b.defaultAmount * occ.length;
      result[cat.name] = (amt, cat.color);
    }
    return result;
  }

  List<DateTime> _occurrences(Bill bill, DateTime rs, DateTime re) {
    final s = DateTime(rs.year, rs.month, rs.day);
    final e = DateTime(re.year, re.month, re.day);
    final rStart = DateTime(bill.startDate.year, bill.startDate.month, bill.startDate.day);
    final base = rStart.isBefore(s) ? rStart : s;

    List<DateTime> occ;
    if (bill.recurrence != null) {
      occ = bill.recurrence!.getOccurrencesInRange(base, e);
    } else {
      switch (bill.frequency) {
        case 'weekly':
          occ = _weeklyOcc(bill, base, e);
          break;
        case 'yearly':
          occ = _yearlyOcc(bill, base, e);
          break;
        default:
          occ = _monthlyOcc(bill, base, e);
      }
    }

    occ = occ.where((d) => !d.isBefore(rStart)).toList();
    final trimmed = _applyEnd(bill, occ);
    return trimmed.where((d) => !d.isBefore(s) && !d.isAfter(e)).toList();
  }

  List<DateTime> _applyEnd(Bill b, List<DateTime> occ) {
    if (occ.isEmpty) return occ;
    switch (b.endCondition) {
      case 'on_date':
        if (b.endDate == null) return occ;
        final ed = DateTime(b.endDate!.year, b.endDate!.month, b.endDate!.day);
        return occ.where((d) => !d.isAfter(ed)).toList();
      case 'after_occurrences':
        if (b.endOccurrences == null || b.endOccurrences! <= 0) return [];
        return occ.take((b.endOccurrences! - b.occurrenceCount).clamp(0, occ.length)).toList();
      case 'after_amount':
        if (b.endAmount == null || b.endAmount! <= 0) return [];
        final rem = b.endAmount! - b.totalPaidAmount;
        if (rem <= 0 || b.defaultAmount <= 0) return [];
        return occ.take((rem / b.defaultAmount).ceil()).toList();
      default:
        return occ;
    }
  }

  List<DateTime> _weeklyOcc(Bill b, DateTime s, DateTime e) {
    final wd = (b.nextDueDate ?? b.startDate).weekday;
    final sd = DateTime(s.year, s.month, s.day);
    var cur = sd.add(Duration(days: (wd - sd.weekday + 7) % 7));
    final r = <DateTime>[];
    while (!cur.isAfter(e)) {
      r.add(cur);
      cur = cur.add(const Duration(days: 7));
    }
    return r;
  }

  List<DateTime> _monthlyOcc(Bill b, DateTime s, DateTime e) {
    final dd = b.dueDay ?? b.startDate.day;
    var c = DateTime(s.year, s.month, 1);
    final lm = DateTime(e.year, e.month, 1);
    final r = <DateTime>[];
    while (!c.isAfter(lm)) {
      final day = _clamp(dd, c.year, c.month);
      final d = DateTime(c.year, c.month, day);
      if (!d.isBefore(s) && !d.isAfter(e)) r.add(d);
      c = DateTime(c.year, c.month + 1, 1);
    }
    return r;
  }

  List<DateTime> _yearlyOcc(Bill b, DateTime s, DateTime e) {
    final src = b.nextDueDate ?? b.startDate;
    final r = <DateTime>[];
    for (var y = s.year; y <= e.year; y++) {
      final day = _clamp(src.day, y, src.month);
      final d = DateTime(y, src.month, day);
      if (!d.isBefore(s) && !d.isAfter(e)) r.add(d);
    }
    return r;
  }

  int _clamp(int d, int y, int m) {
    final last = DateTime(y, m + 1, 0).day;
    return d.clamp(1, last);
  }
}

class _DateRange {
  final DateTime start;
  final DateTime end;
  const _DateRange(this.start, this.end);
}
