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

/// Monthly finance report page.
class MonthlyFinanceReportPage extends ConsumerStatefulWidget {
  final DateTime initialMonth;
  final String currency;

  const MonthlyFinanceReportPage({
    super.key,
    required this.initialMonth,
    required this.currency,
  });

  @override
  ConsumerState<MonthlyFinanceReportPage> createState() =>
      _MonthlyFinanceReportPageState();
}

class _MonthlyFinanceReportPageState extends ConsumerState<MonthlyFinanceReportPage> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    _month = DateTime(widget.initialMonth.year, widget.initialMonth.month, 1);
  }

  void _prevMonth() {
    setState(() {
      _month = DateTime(_month.year, _month.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _month = DateTime(_month.year, _month.month + 1, 1);
    });
  }

  void _goThisMonth() {
    setState(() {
      _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reportAsync = ref.watch(monthlyReportProvider((
      month: _month,
      currency: widget.currency,
    )));
    final sym = CurrencyUtils.getCurrencySymbol(widget.currency);
    final label = DateFormat('MMMM yyyy').format(_month);

    final body = CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: isDark ? const Color(0xFF1A1D23) : Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: _backButton(isDark),
          title: Text(
            'Monthly Report',
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
                label: label,
                onPrev: _prevMonth,
                onNext: _nextMonth,
                onToday: _goThisMonth,
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
                error: (e, _) => _errorWidget(e.toString(), isDark),
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

  Widget _backButton(bool isDark) {
    return Padding(
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
    );
  }

  Widget _errorWidget(String msg, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Text('Error: $msg', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 14)),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    MonthlyReportData data,
    bool isDark,
    String sym,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ReportHeroCard(
          title: 'Month Summary',
          value: '${data.net >= 0 ? '+' : ''}$sym${data.net.toStringAsFixed(2)}',
          subtitle: 'Income: $sym${data.totalIncome.toStringAsFixed(0)} · '
              'Expense: $sym${data.totalExpense.toStringAsFixed(0)}',
          delta: data.savingsRate,
          isPositiveGood: true,
          isDark: isDark,
        ),
        if (data.incomeChangeVsPrevMonth != null || data.expenseChangeVsPrevMonth != null) ...[
          const SizedBox(height: 16),
          ReportComparisonBadge(
            label: 'VS PREVIOUS MONTH',
            incomeChange: data.incomeChangeVsPrevMonth,
            expenseChange: data.expenseChangeVsPrevMonth,
            isDark: isDark,
          ),
        ],
        const SizedBox(height: 24),
        ReportSectionCard(
          title: 'Balance Trend',
          icon: Icons.show_chart_rounded,
          isDark: isDark,
          child: ReportLineChart(
            values: data.dailyClosingBalances,
            isDark: isDark,
          ),
        ),
        const SizedBox(height: 24),
        ReportSectionCard(
          title: 'Weekly Income vs Expense',
          icon: Icons.bar_chart_rounded,
          isDark: isDark,
          child: ReportBarChart(
            groups: data.weeklySummaries
                .map((w) => BarChartGroup(income: w.income, expense: w.expense))
                .toList(),
            labels: data.weeklySummaries.map((w) => w.label).toList(),
            isDark: isDark,
          ),
        ),
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
          ReportSectionCard(
            title: 'Category Ranking',
            icon: Icons.list_rounded,
            isDark: isDark,
            child: ReportCategoryRanking(
              items: data.expenseCategories,
              currencySymbol: sym,
              isDark: isDark,
            ),
          ),
          const SizedBox(height: 24),
        ],
        if (data.budgetStatuses.isNotEmpty) ...[
          ReportSectionCard(
            title: 'Budget Health',
            icon: Icons.account_balance_wallet_rounded,
            isDark: isDark,
            child: Column(
              children: data.budgetStatuses
                  .map((b) => ReportBudgetProgress(
                        name: b.budgetName,
                        limit: b.limit,
                        spent: b.spent,
                        isExceeded: b.isExceeded,
                        currencySymbol: sym,
                        isDark: isDark,
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 24),
        ],
        ReportSectionCard(
          title: 'Bills & Subscriptions',
          icon: Icons.receipt_long_rounded,
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _statRow('Paid this month', '${data.billsPaidCount}', isDark),
              _statRow('Upcoming', '${data.billsUpcomingCount}', isDark),
              _statRow('Total cost', '$sym${data.billsTotalCost.toStringAsFixed(0)}', isDark),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ReportSectionCard(
          title: 'Debt & Savings',
          icon: Icons.savings_rounded,
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _statRow('Debt payments', '$sym${data.debtPaymentsThisMonth.toStringAsFixed(0)}', isDark),
              _statRow('Savings contributions', '$sym${data.savingsContributionsThisMonth.toStringAsFixed(0)}', isDark),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (data.topExpenses.isNotEmpty || data.topIncomes.isNotEmpty)
          ReportSectionCard(
            title: 'Top Transactions',
            icon: Icons.star_rounded,
            isDark: isDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (data.topExpenses.isNotEmpty) ...[
                  Text('Largest expenses', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFFFF5252))),
                  const SizedBox(height: 6),
                  ...(data.topExpenses as List<Transaction>).map((t) => _txRow(t, sym, false, isDark)),
                  const SizedBox(height: 12),
                ],
                if (data.topIncomes.isNotEmpty) ...[
                  Text('Largest income', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF4CAF50))),
                  const SizedBox(height: 6),
                  ...(data.topIncomes as List<Transaction>).map((t) => _txRow(t, sym, true, isDark)),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _statRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.black45)),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
        ],
      ),
    );
  }

  Widget _txRow(Transaction t, String sym, bool isIncome, bool isDark) {
    final color = isIncome ? const Color(0xFF4CAF50) : const Color(0xFFFF5252);
    final prefix = isIncome ? '+' : '-';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(t.title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black54), overflow: TextOverflow.ellipsis),
          ),
          Text('$prefix$sym${t.amount.toStringAsFixed(2)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}
