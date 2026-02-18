import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/dark_gradient.dart';
import '../../data/services/finance_report_models.dart';
import '../../utils/currency_utils.dart';
import '../providers/finance_report_providers.dart';
import '../widgets/report_chart_widgets.dart';
import '../widgets/report_stat_cards.dart';

/// Yearly finance report page.
class YearlyFinanceReportPage extends ConsumerStatefulWidget {
  final int initialYear;
  final String currency;

  const YearlyFinanceReportPage({
    super.key,
    required this.initialYear,
    required this.currency,
  });

  @override
  ConsumerState<YearlyFinanceReportPage> createState() =>
      _YearlyFinanceReportPageState();
}

class _YearlyFinanceReportPageState extends ConsumerState<YearlyFinanceReportPage> {
  late int _year;

  @override
  void initState() {
    super.initState();
    _year = widget.initialYear;
  }

  void _prevYear() {
    setState(() => _year = _year - 1);
  }

  void _nextYear() {
    setState(() => _year = _year + 1);
  }

  void _goThisYear() {
    setState(() => _year = DateTime.now().year);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reportAsync = ref.watch(yearlyReportProvider((
      year: _year,
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
          leading: _backButton(isDark),
          title: Text(
            'Yearly Report',
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
                label: '$_year',
                onPrev: _prevYear,
                onNext: _nextYear,
                onToday: _goThisYear,
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
    YearlyReportData data,
    bool isDark,
    String sym,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ReportHeroCard(
          title: 'Annual Summary',
          value: '${data.net >= 0 ? '+' : ''}$sym${data.net.toStringAsFixed(2)}',
          subtitle: 'Income: $sym${data.totalIncome.toStringAsFixed(0)} · '
              'Expense: $sym${data.totalExpense.toStringAsFixed(0)}',
          delta: data.savingsRate,
          isPositiveGood: true,
          isDark: isDark,
        ),
        if (data.incomeChangeVsPrevYear != null || data.expenseChangeVsPrevYear != null) ...[
          const SizedBox(height: 16),
          ReportComparisonBadge(
            label: 'VS PREVIOUS YEAR',
            incomeChange: data.incomeChangeVsPrevYear,
            expenseChange: data.expenseChangeVsPrevYear,
            isDark: isDark,
          ),
        ],
        const SizedBox(height: 24),
        ReportSectionCard(
          title: 'Monthly Income vs Expense',
          icon: Icons.bar_chart_rounded,
          isDark: isDark,
          child: ReportBarChart(
            groups: data.monthlySummaries
                .map((m) => BarChartGroup(income: m.income, expense: m.expense))
                .toList(),
            labels: data.monthlySummaries.map((m) => m.label).toList(),
            isDark: isDark,
          ),
        ),
        const SizedBox(height: 24),
        ReportSectionCard(
          title: 'Net Worth Trend',
          icon: Icons.show_chart_rounded,
          isDark: isDark,
          child: ReportLineChart(
            values: data.monthlyClosingBalances,
            labels: data.monthlySummaries.map((m) => m.label).toList(),
            isDark: isDark,
          ),
        ),
        const SizedBox(height: 24),
        ReportSectionCard(
          title: 'Monthly Savings Rate',
          icon: Icons.trending_up_rounded,
          isDark: isDark,
          child: ReportLineChart(
            values: data.monthlySavingsRates,
            labels: data.monthlySummaries.map((m) => m.label).toList(),
            lineColor: const Color(0xFF4CAF50),
            isDark: isDark,
          ),
        ),
        const SizedBox(height: 24),
        if (data.expenseCategories.isNotEmpty) ...[
          ReportSectionCard(
            title: 'Annual Category Breakdown',
            icon: Icons.pie_chart_rounded,
            isDark: isDark,
            child: ReportPieChart(
              items: data.expenseCategories.take(8).toList(),
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
              maxItems: 10,
              isDark: isDark,
            ),
          ),
          const SizedBox(height: 24),
        ],
        if (data.bestIncomeMonth != null ||
            data.worstExpenseMonth != null ||
            data.bestSavingsMonth != null) ...[
          ReportSectionCard(
            title: 'Best & Worst Months',
            icon: Icons.emoji_events_rounded,
            isDark: isDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (data.bestIncomeMonth != null && data.bestIncomeAmount != null)
                  _highlightRow('Best income', data.bestIncomeMonth!, '$sym${data.bestIncomeAmount!.toStringAsFixed(0)}', isDark),
                if (data.worstExpenseMonth != null && data.worstExpenseAmount != null)
                  _highlightRow('Highest expense', data.worstExpenseMonth!, '$sym${data.worstExpenseAmount!.toStringAsFixed(0)}', isDark),
                if (data.bestSavingsMonth != null && data.bestSavingsRate != null)
                  _highlightRow('Best savings rate', data.bestSavingsMonth!, '${data.bestSavingsRate!.toStringAsFixed(1)}%', isDark),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        ReportSectionCard(
          title: 'Debt Overview',
          icon: Icons.account_balance_rounded,
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _statRow('Start of year', '$sym${data.debtStartOfYear.toStringAsFixed(0)}', isDark),
              _statRow('End of year', '$sym${data.debtEndOfYear.toStringAsFixed(0)}', isDark),
              _statRow('Total payments', '$sym${data.totalDebtPayments.toStringAsFixed(0)}', isDark),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ReportSectionCard(
          title: 'Savings Overview',
          icon: Icons.savings_rounded,
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _statRow('Start of year', '$sym${data.savingsStartOfYear.toStringAsFixed(0)}', isDark),
              _statRow('End of year', '$sym${data.savingsEndOfYear.toStringAsFixed(0)}', isDark),
              _statRow('Total contributions', '$sym${data.totalSavingsContributions.toStringAsFixed(0)}', isDark),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ReportSectionCard(
          title: 'Annual Quick Stats',
          icon: Icons.analytics_rounded,
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _statRow('Total transactions', '${data.totalTransactions}', isDark),
              _statRow('Avg monthly spend', '$sym${data.avgMonthlySpend.toStringAsFixed(0)}', isDark),
              _statRow('Avg monthly income', '$sym${data.avgMonthlyIncome.toStringAsFixed(0)}', isDark),
              if (data.mostUsedPaymentMethod != null)
                _statRow('Most used payment', data.mostUsedPaymentMethod!, isDark),
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

  Widget _highlightRow(String label, String month, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.black45)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(month, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFCDAF56))),
              Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
            ],
          ),
        ],
      ),
    );
  }
}
