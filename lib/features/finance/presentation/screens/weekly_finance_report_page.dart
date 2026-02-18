import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/dark_gradient.dart';
import '../../data/services/finance_report_models.dart';
import '../../utils/currency_utils.dart';
import '../providers/finance_report_providers.dart';
import '../widgets/report_chart_widgets.dart';
import '../widgets/report_stat_cards.dart';

/// Weekly finance report page.
class WeeklyFinanceReportPage extends ConsumerStatefulWidget {
  final DateTime initialWeekStart;
  final String currency;

  const WeeklyFinanceReportPage({
    super.key,
    required this.initialWeekStart,
    required this.currency,
  });

  @override
  ConsumerState<WeeklyFinanceReportPage> createState() =>
      _WeeklyFinanceReportPageState();
}

class _WeeklyFinanceReportPageState extends ConsumerState<WeeklyFinanceReportPage> {
  late DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    _weekStart = DateTime(
      widget.initialWeekStart.year,
      widget.initialWeekStart.month,
      widget.initialWeekStart.day,
    );
  }

  void _prevWeek() {
    setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7)));
  }

  void _nextWeek() {
    setState(() => _weekStart = _weekStart.add(const Duration(days: 7)));
  }

  void _goThisWeek() {
    final now = DateTime.now();
    final weekday = now.weekday;
    setState(() {
      _weekStart = DateTime(now.year, now.month, now.day - (weekday - 1));
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reportAsync = ref.watch(weeklyReportProvider((
      weekStart: _weekStart,
      currency: widget.currency,
    )));
    final sym = CurrencyUtils.getCurrencySymbol(widget.currency);
    final weekEnd = _weekStart.add(const Duration(days: 6));
    final label =
        '${DateFormat('MMM d').format(_weekStart)} - ${DateFormat('MMM d').format(weekEnd)}';

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
            'Weekly Report',
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
                onPrev: _prevWeek,
                onNext: _nextWeek,
                onToday: _goThisWeek,
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
    WeeklyReportData data,
    bool isDark,
    String sym,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ReportHeroCard(
          title: 'Week Summary',
          value: '${data.net >= 0 ? '+' : ''}$sym${data.net.toStringAsFixed(2)}',
          subtitle: 'Income: $sym${data.totalIncome.toStringAsFixed(0)} · '
              'Expense: $sym${data.totalExpense.toStringAsFixed(0)}',
          delta: data.savingsRate,
          isPositiveGood: true,
          isDark: isDark,
        ),
        if (data.incomeChangeVsPrevWeek != null || data.expenseChangeVsPrevWeek != null) ...[
          const SizedBox(height: 16),
          ReportComparisonBadge(
            label: 'VS PREVIOUS WEEK',
            incomeChange: data.incomeChangeVsPrevWeek,
            expenseChange: data.expenseChangeVsPrevWeek,
            isDark: isDark,
          ),
        ],
        const SizedBox(height: 24),
        ReportSectionCard(
          title: 'Daily Income vs Expense',
          icon: Icons.bar_chart_rounded,
          isDark: isDark,
          child: ReportBarChart(
            groups: data.dailySummaries
                .map((d) => BarChartGroup(income: d.income, expense: d.expense))
                .toList(),
            labels: data.dailySummaries.map((d) => d.label).toList(),
            isDark: isDark,
          ),
        ),
        const SizedBox(height: 24),
        ReportSectionCard(
          title: 'Balance Trend',
          icon: Icons.show_chart_rounded,
          isDark: isDark,
          child: ReportLineChart(
            values: data.dailyClosingBalances,
            labels: data.dailySummaries.map((d) => d.label).toList(),
            isDark: isDark,
          ),
        ),
        const SizedBox(height: 24),
        if (data.topExpenseCategories.isNotEmpty)
          ReportSectionCard(
            title: 'Top Categories',
            icon: Icons.pie_chart_rounded,
            isDark: isDark,
            child: ReportCategoryRanking(
              items: data.topExpenseCategories,
              currencySymbol: sym,
              maxItems: 7,
              isDark: isDark,
            ),
          ),
        const SizedBox(height: 24),
        ReportSectionCard(
          title: 'Insights',
          icon: Icons.lightbulb_rounded,
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _insightRow('Average daily spend', '$sym${data.averageDailySpending.toStringAsFixed(0)}', isDark),
              if (data.busiestDay != null)
                _insightRow('Busiest day', data.busiestDay!, isDark),
              if (data.quietestDay != null)
                _insightRow('Quietest day', data.quietestDay!, isDark),
              _insightRow('Total transactions', '${data.totalTransactions}', isDark),
              if (data.highestSingleExpense != null)
                _insightRow('Highest expense', '$sym${data.highestSingleExpense!.toStringAsFixed(0)}', isDark),
              if (data.highestSingleIncome != null)
                _insightRow('Highest income', '$sym${data.highestSingleIncome!.toStringAsFixed(0)}', isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _insightRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
