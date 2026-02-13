import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/dark_gradient.dart';
import '../../data/models/transaction.dart' as finance;
import '../../data/models/transaction_category.dart';
import '../../utils/currency_utils.dart';
import '../providers/finance_providers.dart';

// ─── period enum ──────────────────────────────────────────────────────
enum _Period { month, threeMonths, sixMonths, year, custom }

// ─── screen ───────────────────────────────────────────────────────────
class ExpenseReportScreen extends ConsumerStatefulWidget {
  const ExpenseReportScreen({super.key});

  @override
  ConsumerState<ExpenseReportScreen> createState() =>
      _ExpenseReportScreenState();
}

class _ExpenseReportScreenState extends ConsumerState<ExpenseReportScreen> {
  static const _accent = Color(0xFFFF5252);
  static const _surfaceDark = Color(0xFF1A1D23);

  _Period _period = _Period.month;
  DateTime _anchor = DateTime.now();
  String? _drillCategory; // category id for drill-down

  // ─── build ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final txAsync = ref.watch(allTransactionsProvider);
    final catsAsync = ref.watch(allTransactionCategoriesProvider);
    final cur = ref.watch(defaultCurrencyProvider).value ?? 'ETB';

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
              const SizedBox(height: 10),
              _dateNav(isDark),
              const SizedBox(height: 20),
              txAsync.when(
                data: (txs) {
                  final cats = catsAsync.value ?? [];
                  return _body(txs, cats, isDark, cur);
                },
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
      backgroundColor:
          isDark ? const Color(0xFF0D0F14) : const Color(0xFFF5F6FA),
      body: isDark ? DarkGradient.wrap(child: body) : body,
    );
  }

  // ─── body ───────────────────────────────────────────────────────────
  Widget _body(
    List<finance.Transaction> allTxs,
    List<TransactionCategory> cats,
    bool isDark,
    String cur,
  ) {
    final range = _range();
    final expenses = allTxs.where((t) {
      if (!t.isExpense) return false;
      if ((t.currency ?? cur) != cur) return false;
      final d = t.transactionDate.toLocal();
      return !d.isBefore(range.start) && !d.isAfter(range.end);
    }).toList();

    if (expenses.isEmpty && _drillCategory == null) {
      return _emptyState(isDark, 'No expenses in this period', Icons.receipt_long_rounded);
    }

    final sym = CurrencyUtils.getCurrencySymbol(cur);
    final totalSpent = expenses.fold(0.0, (s, t) => s + t.amount);

    // If drilling into a specific category
    if (_drillCategory != null) {
      return _drillDownView(expenses, cats, isDark, cur, sym);
    }

    return Column(
      children: [
        _heroCard(expenses, totalSpent, sym, isDark),
        const SizedBox(height: 16),
        _quickStats(expenses, totalSpent, sym, isDark),
        const SizedBox(height: 16),
        _billsVsOneTimeCard(expenses, totalSpent, sym, isDark),
        const SizedBox(height: 16),
        _monthlyTrendCard(allTxs, isDark, cur),
        const SizedBox(height: 16),
        _categoryBreakdownCard(expenses, cats, totalSpent, isDark, sym),
        const SizedBox(height: 16),
        _topExpensesCard(expenses, cats, isDark, sym),
        const SizedBox(height: 16),
        _weekdayCard(expenses, isDark, sym),
        const SizedBox(height: 16),
        _dailyAvgCard(expenses, totalSpent, isDark, sym),
      ],
    );
  }

  // ─── drill-down view for a single category ──────────────────────────
  Widget _drillDownView(
    List<finance.Transaction> expenses,
    List<TransactionCategory> cats,
    bool isDark,
    String cur,
    String sym,
  ) {
    final catTxs = expenses.where((t) => t.categoryId == _drillCategory).toList()
      ..sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
    final cat = cats.firstWhere(
      (c) => c.id == _drillCategory,
      orElse: () => TransactionCategory(
        id: '',
        name: 'Unknown',
        colorValue: Colors.grey.value,
        type: 'expense',
        isSystemCategory: false,
        createdAt: DateTime.now(),
        sortOrder: 0,
      ),
    );
    final catTotal = catTxs.fold(0.0, (s, t) => s + t.amount);
    final totalExpenses = expenses.fold(0.0, (s, t) => s + t.amount);
    final pct = totalExpenses > 0 ? (catTotal / totalExpenses * 100) : 0.0;

    // Monthly trend for this category
    final range = _range();
    final monthlyData = <DateTime, double>{};
    var cursor = DateTime(range.start.year, range.start.month, 1);
    final endMonth = DateTime(range.end.year, range.end.month, 1);
    while (!cursor.isAfter(endMonth)) {
      final ms = cursor;
      final me = DateTime(cursor.year, cursor.month + 1, 0, 23, 59, 59);
      double t = 0;
      for (final tx in catTxs) {
        final d = tx.transactionDate.toLocal();
        if (!d.isBefore(ms) && !d.isAfter(me)) t += tx.amount;
      }
      monthlyData[cursor] = t;
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }

    return Column(
      children: [
        // Back to overview
        GestureDetector(
          onTap: () => setState(() => _drillCategory = null),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? _surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.06)
                    : Colors.black.withOpacity(0.06),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.arrow_back_rounded,
                    size: 18, color: _accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Back to overview',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Category hero
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                cat.color.withOpacity(0.15),
                cat.color.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cat.color.withOpacity(0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cat.color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(cat.icon ?? Icons.category_rounded,
                        color: cat.color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cat.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${catTxs.length} transactions  ·  ${pct.toStringAsFixed(1)}% of total',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '$sym${_fmt(catTotal)}',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                    letterSpacing: -1,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Monthly trend for this category
        if (monthlyData.length >= 2)
          _buildMiniTrend(monthlyData, cat.color, isDark, sym),
        if (monthlyData.length >= 2) const SizedBox(height: 16),

        // Transaction list
        _card(
          isDark: isDark,
          icon: Icons.list_rounded,
          title: 'TRANSACTIONS',
          child: Column(
            children: catTxs.take(20).map((tx) {
              final d = tx.transactionDate.toLocal();
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: cat.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          d.day.toString(),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: cat.color,
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
                            tx.title,
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
                            DateFormat('MMM d, yyyy').format(d),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white30 : Colors.black26,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '$sym${_fmt(tx.amount)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: _accent,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
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
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: Material(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.pop(context),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(Icons.arrow_back_rounded,
                  size: 20, color: isDark ? Colors.white70 : Colors.black87),
            ),
          ),
        ),
      ),
      title: Text(
        'Expense Report',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : const Color(0xFF1E1E1E),
        ),
      ),
      centerTitle: false,
    );
  }

  // ─── period chips ───────────────────────────────────────────────────
  Widget _periodChips(bool isDark) {
    const items = [
      (_Period.month, '1M'),
      (_Period.threeMonths, '3M'),
      (_Period.sixMonths, '6M'),
      (_Period.year, '1Y'),
      (_Period.custom, 'All'),
    ];
    return Row(
      children: items.map((e) {
        final sel = _period == e.$1;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: e.$1 == _Period.custom ? 0 : 8),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _period = e.$1;
                  _drillCategory = null;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: sel
                      ? _accent
                      : (isDark
                            ? Colors.white.withOpacity(0.04)
                            : Colors.white),
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
                        ? Colors.white
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
            onPressed: () {
              setState(() {
                _drillCategory = null;
                _shift(-1);
              });
            },
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
            onPressed: () {
              setState(() {
                _drillCategory = null;
                _shift(1);
              });
            },
            color: _accent,
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  // ─── hero card ──────────────────────────────────────────────────────
  Widget _heroCard(
    List<finance.Transaction> expenses,
    double totalSpent,
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
            _accent.withOpacity(0.12),
            _accent.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accent.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.trending_down_rounded,
                    color: _accent, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Total Expenses',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.12),
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
              '$sym${_fmt(totalSpent)}',
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
            '${expenses.length} transactions',
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

  // ─── quick stats ────────────────────────────────────────────────────
  Widget _quickStats(
    List<finance.Transaction> expenses,
    double totalSpent,
    String sym,
    bool isDark,
  ) {
    final range = _range();
    final days = range.end.difference(range.start).inDays + 1;
    final dailyAvg = days > 0 ? totalSpent / days : 0.0;
    final maxTx =
        expenses.isEmpty ? 0.0 : expenses.map((t) => t.amount).reduce((a, b) => a > b ? a : b);
    final uniqueCats =
        expenses.map((t) => t.categoryId).toSet().length;

    return Row(
      children: [
        _statChip(
          icon: Icons.calendar_today_rounded,
          value: '$sym${_fmtShort(dailyAvg)}',
          label: 'Daily avg',
          color: _accent,
          isDark: isDark,
        ),
        const SizedBox(width: 8),
        _statChip(
          icon: Icons.arrow_upward_rounded,
          value: '$sym${_fmtShort(maxTx)}',
          label: 'Largest',
          color: const Color(0xFFFF9800),
          isDark: isDark,
        ),
        const SizedBox(width: 8),
        _statChip(
          icon: Icons.receipt_long_rounded,
          value: expenses.length.toString(),
          label: 'Count',
          color: const Color(0xFF2196F3),
          isDark: isDark,
        ),
        const SizedBox(width: 8),
        _statChip(
          icon: Icons.category_rounded,
          value: uniqueCats.toString(),
          label: 'Categories',
          color: const Color(0xFF9C27B0),
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
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
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
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
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
                letterSpacing: 0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ─── bills vs one-time breakdown ────────────────────────────────────
  Widget _billsVsOneTimeCard(
    List<finance.Transaction> expenses,
    double totalSpent,
    String sym,
    bool isDark,
  ) {
    final billExpenses = expenses.where((t) => t.billId != null).toList();
    final oneTimeExpenses = expenses.where((t) => t.billId == null).toList();
    
    final billTotal = billExpenses.fold(0.0, (s, t) => s + t.amount);
    final oneTimeTotal = oneTimeExpenses.fold(0.0, (s, t) => s + t.amount);
    
    final billPercent = totalSpent > 0 ? (billTotal / totalSpent * 100) : 0.0;
    final oneTimePercent = totalSpent > 0 ? (oneTimeTotal / totalSpent * 100) : 0.0;

    return _card(
      isDark: isDark,
      icon: Icons.pie_chart_rounded,
      title: 'RECURRING VS ONE-TIME',
      child: Column(
        children: [
          // Bills/Subscriptions row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  size: 18,
                  color: Colors.amber,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bills & Subscriptions',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${billExpenses.length} payment${billExpenses.length != 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$sym${_fmtShort(billTotal)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.amber,
                    ),
                  ),
                  Text(
                    '${billPercent.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // One-time expenses row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.shopping_bag_rounded,
                  size: 18,
                  color: _accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'One-time Expenses',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${oneTimeExpenses.length} transaction${oneTimeExpenses.length != 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$sym${_fmtShort(oneTimeTotal)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: _accent,
                    ),
                  ),
                  Text(
                    '${oneTimePercent.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── monthly trend chart ────────────────────────────────────────────
  Widget _monthlyTrendCard(
    List<finance.Transaction> allTxs,
    bool isDark,
    String cur,
  ) {
    final range = _range();
    final data = _monthlyTrend(allTxs, range, cur);
    if (data.length < 2) return const SizedBox.shrink();

    final maxY = data.values.fold(0.0, (a, b) => a > b ? a : b);
    final sym = CurrencyUtils.getCurrencySymbol(cur);

    return _card(
      isDark: isDark,
      icon: Icons.show_chart_rounded,
      title: 'MONTHLY SPENDING TREND',
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
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: 1,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= data.length) {
                        return const SizedBox.shrink();
                      }
                      if (data.length > 6 &&
                          i % ((data.length / 6).ceil()) != 0) {
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
                        _accent.withOpacity(0.2),
                        _accent.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) => spots
                      .map((s) => LineTooltipItem(
                            '$sym${s.y.toStringAsFixed(0)}',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ))
                      .toList(),
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
  Widget _categoryBreakdownCard(
    List<finance.Transaction> expenses,
    List<TransactionCategory> cats,
    double totalSpent,
    bool isDark,
    String sym,
  ) {
    if (expenses.isEmpty) return const SizedBox.shrink();

    // Aggregate by category
    final catMap = <String, double>{};
    for (final t in expenses) {
      final cid = t.categoryId ?? 'other';
      catMap[cid] = (catMap[cid] ?? 0) + t.amount;
    }

    // Sort by amount desc
    final sorted = catMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Resolve category info
    final sections = sorted.map((e) {
      final cat = cats.firstWhere(
        (c) => c.id == e.key,
        orElse: () => TransactionCategory(
          id: e.key,
          name: _resolveCategoryName(e.key),
          colorValue: Colors.grey.value,
          type: 'expense',
          isSystemCategory: false,
          createdAt: DateTime.now(),
          sortOrder: 0,
        ),
      );
      return (cat: cat, amount: e.value);
    }).toList();

    return _card(
      isDark: isDark,
      icon: Icons.donut_large_rounded,
      title: 'CATEGORY BREAKDOWN',
      child: Column(
        children: [
          // Pie chart
          SizedBox(
            height: 160,
            child: PieChart(
              PieChartData(
                sections: sections.map((s) {
                  final pct = totalSpent > 0
                      ? (s.amount / totalSpent * 100)
                      : 0.0;
                  return PieChartSectionData(
                    value: s.amount,
                    title: pct >= 8 ? '${pct.toStringAsFixed(0)}%' : '',
                    color: s.cat.color,
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

          // Legend - tappable for drill-down
          ...sections.map((s) {
            final pct = totalSpent > 0
                ? (s.amount / totalSpent * 100)
                : 0.0;
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _drillCategory = s.cat.id);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? s.cat.color.withOpacity(0.06)
                      : s.cat.color.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: s.cat.color.withOpacity(0.12)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: s.cat.color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        s.cat.name,
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
                      '$sym${_fmt(s.amount)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 38,
                      child: Text(
                        '${pct.toStringAsFixed(0)}%',
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: s.cat.color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.chevron_right_rounded,
                        size: 16,
                        color: isDark ? Colors.white24 : Colors.black26),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 4),
          Text(
            'Tap a category to drill down',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
          ),
        ],
      ),
    );
  }

  // ─── top expenses ───────────────────────────────────────────────────
  Widget _topExpensesCard(
    List<finance.Transaction> expenses,
    List<TransactionCategory> cats,
    bool isDark,
    String sym,
  ) {
    if (expenses.isEmpty) return const SizedBox.shrink();

    final top = List<finance.Transaction>.from(expenses)
      ..sort((a, b) => b.amount.compareTo(a.amount));

    return _card(
      isDark: isDark,
      icon: Icons.star_rounded,
      title: 'TOP EXPENSES',
      child: Column(
        children: top.take(5).toList().asMap().entries.map((entry) {
          final tx = entry.value;
          final rank = entry.key + 1;
          final cat = cats.firstWhere(
            (c) => c.id == tx.categoryId,
            orElse: () => TransactionCategory(
              id: '',
              name: 'Other',
              colorValue: Colors.grey.value,
              type: 'expense',
              isSystemCategory: false,
              createdAt: DateTime.now(),
              sortOrder: 0,
            ),
          );
          final d = tx.transactionDate.toLocal();

          return Container(
            margin: EdgeInsets.only(bottom: entry.key < 4 ? 8 : 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.03)
                  : Colors.black.withOpacity(0.02),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _accent.withOpacity(rank <= 3 ? 0.15 : 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '#$rank',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: rank <= 3 ? _accent : (isDark ? Colors.white38 : Colors.black38),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx.title,
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
                        '${cat.name}  ·  ${DateFormat('MMM d').format(d)}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white30 : Colors.black26,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Text(
                  '$sym${_fmt(tx.amount)}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: _accent,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── weekday distribution ───────────────────────────────────────────
  Widget _weekdayCard(
    List<finance.Transaction> expenses,
    bool isDark,
    String sym,
  ) {
    if (expenses.isEmpty) return const SizedBox.shrink();

    final dayTotals = List.filled(7, 0.0);
    final dayCounts = List.filled(7, 0);
    for (final tx in expenses) {
      final wd = tx.transactionDate.toLocal().weekday - 1; // 0=Mon
      dayTotals[wd] += tx.amount;
      dayCounts[wd]++;
    }
    final maxDay = dayTotals.reduce((a, b) => a > b ? a : b);
    if (maxDay == 0) return const SizedBox.shrink();

    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return _card(
      isDark: isDark,
      icon: Icons.calendar_view_week_rounded,
      title: 'SPENDING BY WEEKDAY',
      child: SizedBox(
        height: 140,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(7, (i) {
            final pct = maxDay > 0 ? dayTotals[i] / maxDay : 0.0;
            final barH = (pct * 90).clamp(4.0, 90.0);
            final isMax = dayTotals[i] == maxDay && maxDay > 0;

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (dayCounts[i] > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          dayCounts[i].toString(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: isMax
                                ? _accent
                                : (isDark ? Colors.white38 : Colors.black38),
                          ),
                        ),
                      ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: barH,
                      decoration: BoxDecoration(
                        gradient: isMax
                            ? LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  _accent.withOpacity(0.7),
                                  _accent,
                                ],
                              )
                            : null,
                        color: isMax
                            ? null
                            : (isDark
                                  ? Colors.white.withOpacity(0.08)
                                  : Colors.black.withOpacity(0.06)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      days[i],
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: isMax ? FontWeight.w900 : FontWeight.w700,
                        color: isMax
                            ? _accent
                            : (isDark ? Colors.white38 : Colors.black38),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ─── daily average card ─────────────────────────────────────────────
  Widget _dailyAvgCard(
    List<finance.Transaction> expenses,
    double totalSpent,
    bool isDark,
    String sym,
  ) {
    if (expenses.isEmpty) return const SizedBox.shrink();

    final range = _range();
    final totalDays = range.end.difference(range.start).inDays + 1;
    final avg = totalDays > 0 ? totalSpent / totalDays : 0.0;

    // Find the highest and lowest spending days
    final dailyMap = <String, double>{};
    for (final tx in expenses) {
      final d = tx.transactionDate.toLocal();
      final key = '${d.year}-${d.month}-${d.day}';
      dailyMap[key] = (dailyMap[key] ?? 0) + tx.amount;
    }
    final daysWithSpending = dailyMap.length;
    final highestDay = dailyMap.isNotEmpty
        ? dailyMap.entries.reduce((a, b) => a.value > b.value ? a : b)
        : null;
    final lowestDay = dailyMap.isNotEmpty
        ? dailyMap.entries.reduce((a, b) => a.value < b.value ? a : b)
        : null;

    return _card(
      isDark: isDark,
      icon: Icons.insights_rounded,
      title: 'DAILY INSIGHTS',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _insightItem(
                  'Daily Average',
                  '$sym${_fmt(avg)}',
                  Icons.balance_rounded,
                  _accent,
                  isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _insightItem(
                  'Active Days',
                  '$daysWithSpending / $totalDays',
                  Icons.event_available_rounded,
                  const Color(0xFF4CAF50),
                  isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _insightItem(
                  'Highest Day',
                  highestDay != null
                      ? '$sym${_fmt(highestDay.value)}'
                      : '--',
                  Icons.arrow_upward_rounded,
                  const Color(0xFFFF9800),
                  isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _insightItem(
                  'Lowest Day',
                  lowestDay != null
                      ? '$sym${_fmt(lowestDay.value)}'
                      : '--',
                  Icons.arrow_downward_rounded,
                  const Color(0xFF2196F3),
                  isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _insightItem(
    String label,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                const SizedBox(height: 1),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white30 : Colors.black26,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── mini trend for drill-down ──────────────────────────────────────
  Widget _buildMiniTrend(
    Map<DateTime, double> data,
    Color color,
    bool isDark,
    String sym,
  ) {
    final maxY = data.values.fold(0.0, (a, b) => a > b ? a : b);

    return _card(
      isDark: isDark,
      icon: Icons.show_chart_rounded,
      title: 'MONTHLY TREND',
      child: SizedBox(
        height: 140,
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
              leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  interval: 1,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= data.length) {
                      return const SizedBox.shrink();
                    }
                    if (data.length > 6 &&
                        i % ((data.length / 6).ceil()) != 0) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        DateFormat('MMM').format(data.keys.toList()[i]),
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
                color: color,
                barWidth: 2.5,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                    radius: 3,
                    color: color,
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
                      color.withOpacity(0.2),
                      color.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ],
            minY: 0,
            maxY: maxY * 1.15,
          ),
        ),
      ),
    );
  }

  // ─── reusable card ──────────────────────────────────────────────────
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

  // ─── formatting ─────────────────────────────────────────────────────
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

  String _resolveCategoryName(String id) {
    // Fallback for orphaned transaction category IDs
    if (id == 'other') return 'Other';
    // Try to capitalize the ID as a last resort
    return id.replaceAll('cat_', '').replaceAll('_', ' ').split(' ').map((w) =>
      w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : w
    ).join(' ');
  }

  // ─── period logic ───────────────────────────────────────────────────
  String _label() {
    switch (_period) {
      case _Period.month:
        return DateFormat('MMMM yyyy').format(_anchor);
      case _Period.threeMonths:
        final end = DateTime(_anchor.year, _anchor.month + 2, 1);
        return '${DateFormat('MMM').format(_anchor)} - ${DateFormat('MMM yyyy').format(end)}';
      case _Period.sixMonths:
        final end = DateTime(_anchor.year, _anchor.month + 5, 1);
        return '${DateFormat('MMM').format(_anchor)} - ${DateFormat('MMM yyyy').format(end)}';
      case _Period.year:
        return _anchor.year.toString();
      case _Period.custom:
        return 'All Time';
    }
  }

  void _shift(int dir) {
    setState(() {
      switch (_period) {
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
        case _Period.custom:
          break;
      }
    });
  }

  _DateRange _range() {
    final b = DateTime(_anchor.year, _anchor.month, 1);
    switch (_period) {
      case _Period.month:
        return _DateRange(b, DateTime(b.year, b.month + 1, 0, 23, 59, 59));
      case _Period.threeMonths:
        return _DateRange(b, DateTime(b.year, b.month + 3, 0, 23, 59, 59));
      case _Period.sixMonths:
        return _DateRange(b, DateTime(b.year, b.month + 6, 0, 23, 59, 59));
      case _Period.year:
        return _DateRange(
          DateTime(b.year, 1, 1),
          DateTime(b.year, 12, 31, 23, 59, 59),
        );
      case _Period.custom:
        return _DateRange(
          DateTime(2000),
          DateTime.now().add(const Duration(days: 1)),
        );
    }
  }

  // ─── data helpers ───────────────────────────────────────────────────
  Map<DateTime, double> _monthlyTrend(
    List<finance.Transaction> allTxs,
    _DateRange range,
    String cur,
  ) {
    final expenses = allTxs.where((t) {
      if (!t.isExpense) return false;
      if ((t.currency ?? cur) != cur) return false;
      final d = t.transactionDate.toLocal();
      return !d.isBefore(range.start) && !d.isAfter(range.end);
    }).toList();

    final m = <DateTime, double>{};
    var c = DateTime(range.start.year, range.start.month, 1);
    final e = DateTime(range.end.year, range.end.month, 1);
    while (!c.isAfter(e)) {
      final ms = c;
      final me = DateTime(c.year, c.month + 1, 0, 23, 59, 59);
      double t = 0;
      for (final tx in expenses) {
        final d = tx.transactionDate.toLocal();
        if (!d.isBefore(ms) && !d.isAfter(me)) t += tx.amount;
      }
      m[c] = t;
      c = DateTime(c.year, c.month + 1, 1);
    }
    return m;
  }
}

class _DateRange {
  final DateTime start;
  final DateTime end;
  const _DateRange(this.start, this.end);
}
