import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/dark_gradient.dart';
import '../../data/models/transaction.dart';
import '../../data/services/finance_report_models.dart';
import '../../utils/currency_utils.dart';
import '../providers/finance_report_providers.dart';
import '../widgets/report_chart_widgets.dart';
import '../widgets/report_stat_cards.dart';

/// Daily finance report page with hero, income/expense, hourly chart,
/// category pie, account changes, and transaction summary.
class DailyFinanceReportPage extends ConsumerStatefulWidget {
  final DateTime initialDate;
  final String currency;

  const DailyFinanceReportPage({
    super.key,
    required this.initialDate,
    required this.currency,
  });

  @override
  ConsumerState<DailyFinanceReportPage> createState() =>
      _DailyFinanceReportPageState();
}

class _DailyFinanceReportPageState extends ConsumerState<DailyFinanceReportPage> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(widget.initialDate.year, widget.initialDate.month, widget.initialDate.day);
  }

  void _prevDay() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    });
  }

  void _nextDay() {
    setState(() {
      _selectedDate = _selectedDate.add(const Duration(days: 1));
    });
  }

  void _goToday() {
    setState(() {
      _selectedDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reportAsync = ref.watch(dailyReportProvider((
      date: _selectedDate,
      currency: widget.currency,
    )));
    final sym = CurrencyUtils.getCurrencySymbol(widget.currency);

    final body = CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: isDark ? const Color(0xFF1A1D23) : Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: Padding(
            padding: const EdgeInsets.all(8),
            child: Material(
              color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(context);
                },
                child: const SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(Icons.arrow_back_rounded, size: 20, color: Color(0xFFCDAF56)),
                ),
              ),
            ),
          ),
          title: Text(
            'Daily Report',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1E1E1E),
            ),
          ),
          centerTitle: false,
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              ReportPeriodNavigator(
                label: DateFormat('EEE, MMM d, yyyy').format(_selectedDate),
                onPrev: _prevDay,
                onNext: _nextDay,
                onToday: _goToday,
                isDark: isDark,
              ),
              const SizedBox(height: 20),
              reportAsync.when(
                data: (data) => _buildContent(context, data, isDark, sym),
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFFCDAF56)),
                  ),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: Text(
                      'Error: $e',
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black54,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0F14) : const Color(0xFFF8F9FC),
      body: isDark ? DarkGradient.wrap(child: body) : body,
    );
  }

  Widget _buildContent(
    BuildContext context,
    DailyReportData data,
    bool isDark,
    String sym,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ReportHeroCard(
          title: 'Balance',
          value: '$sym${data.closingBalance.toStringAsFixed(2)}',
          subtitle: 'Opening: $sym${data.openingBalance.toStringAsFixed(2)} · '
              '${data.incomeCount + data.expenseCount + data.transferCount} transactions',
          delta: data.netChange != 0 && data.openingBalance != 0
              ? (data.netChange / data.openingBalance.abs() * 100)
              : null,
          isPositiveGood: true,
          isDark: isDark,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ReportStatCard(
                icon: Icons.trending_up_rounded,
                label: 'Income',
                value: '$sym${data.totalIncome.toStringAsFixed(2)}',
                iconColor: const Color(0xFF4CAF50),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ReportStatCard(
                icon: Icons.trending_down_rounded,
                label: 'Expense',
                value: '$sym${data.totalExpense.toStringAsFixed(2)}',
                iconColor: const Color(0xFFFF5252),
                isDark: isDark,
              ),
            ),
          ],
        ),
        if (data.totalIncome > 0) ...[
          const SizedBox(height: 8),
          ReportStatCard(
            icon: Icons.savings_rounded,
            label: 'Savings Rate',
            value: '${data.savingsRate.toStringAsFixed(1)}%',
            isDark: isDark,
          ),
        ],
        const SizedBox(height: 24),
        _buildHourlyChart(data, isDark),
        const SizedBox(height: 24),
        if (data.expenseCategories.isNotEmpty) ...[
          ReportSectionCard(
            title: 'Expense by Category',
            icon: Icons.pie_chart_rounded,
            isDark: isDark,
            child: ReportPieChart(
              items: data.expenseCategories,
              total: data.totalExpense,
              isDark: isDark,
            ),
          ),
          const SizedBox(height: 24),
        ],
        if (data.accountChanges.isNotEmpty) ...[
          ReportSectionCard(
            title: 'Account Changes',
            icon: Icons.account_balance_wallet_rounded,
            isDark: isDark,
            child: Column(
              children: data.accountChanges.map((a) {
                final deltaStr = a.delta >= 0
                    ? '+$sym${a.delta.toStringAsFixed(2)}'
                    : '-$sym${(-a.delta).toStringAsFixed(2)}';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        a.accountName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      Text(
                        deltaStr,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: a.delta >= 0
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFFF5252),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),
        ],
        if (data.incomeTransactions.isNotEmpty ||
            data.expenseTransactions.isNotEmpty ||
            data.transferTransactions.isNotEmpty) ...[
          ReportSectionCard(
            title: 'Transactions',
            icon: Icons.list_rounded,
            isDark: isDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (data.incomeTransactions.isNotEmpty) ...[
                  _sectionLabel('Income', const Color(0xFF4CAF50), isDark),
                  ...(data.incomeTransactions as List<Transaction>).take(5).map(
                        (t) => _txTile(t, sym, true, isDark),
                      ),
                  const SizedBox(height: 12),
                ],
                if (data.expenseTransactions.isNotEmpty) ...[
                  _sectionLabel('Expense', const Color(0xFFFF5252), isDark),
                  ...(data.expenseTransactions as List<Transaction>).take(5).map(
                        (t) => _txTile(t, sym, false, isDark),
                      ),
                  const SizedBox(height: 12),
                ],
                if (data.transferTransactions.isNotEmpty) ...[
                  _sectionLabel('Transfers', const Color(0xFFCDAF56), isDark),
                  ...(data.transferTransactions as List<Transaction>).take(5).map(
                        (t) => _txTile(t, sym, null, isDark),
                      ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHourlyChart(DailyReportData data, bool isDark) {
    final hours = List.generate(24, (i) => i);
    final incomeVals = hours.map((h) => data.hourlyIncome[h] ?? 0.0).toList();
    final expenseVals = hours.map((h) => data.hourlyExpense[h] ?? 0.0).toList();
    final maxVal = [...incomeVals, ...expenseVals].reduce((a, b) => a > b ? a : b);
    if (maxVal <= 0) return const SizedBox.shrink();

    final groups = hours
        .map((h) => BarChartGroup(
              income: incomeVals[h] > 0 ? incomeVals[h] : null,
              expense: expenseVals[h] > 0 ? expenseVals[h] : null,
            ))
        .toList();
    final labels = hours.map((h) => '$h').toList();

    return ReportSectionCard(
      title: 'Activity by Hour',
      icon: Icons.access_time_rounded,
      isDark: isDark,
      child: ReportBarChart(
        groups: groups,
        labels: labels,
        maxY: maxVal * 1.2,
        isDark: isDark,
      ),
    );
  }

  Widget _sectionLabel(String text, Color color, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _txTile(Transaction t, String sym, bool? isIncome, bool isDark) {
    Color amountColor;
    String prefix = '';
    if (isIncome == true) {
      amountColor = const Color(0xFF4CAF50);
      prefix = '+';
    } else if (isIncome == false) {
      amountColor = const Color(0xFFFF5252);
      prefix = '-';
    } else {
      amountColor = const Color(0xFFCDAF56);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              t.title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '$prefix$sym${t.amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: amountColor,
            ),
          ),
        ],
      ),
    );
  }
}
