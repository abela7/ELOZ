import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/dark_gradient.dart';
import '../../data/models/transaction.dart';
import '../../data/models/recurring_income.dart';
import '../../data/services/finance_settings_service.dart';
import '../../utils/currency_utils.dart';
import '../../utils/expense_range_utils.dart';
import '../providers/finance_providers.dart';
import '../providers/income_providers.dart';

/// Income Report Screen - Analytics and insights with comparative analysis
class IncomeReportScreen extends ConsumerStatefulWidget {
  const IncomeReportScreen({super.key});

  @override
  ConsumerState<IncomeReportScreen> createState() =>
      _IncomeReportScreenState();
}

class _IncomeReportScreenState extends ConsumerState<IncomeReportScreen> {
  DateTime _selectedDate = ExpenseRangeUtils.normalizeDate(DateTime.now());
  ExpenseRangeView _selectedRangeView = ExpenseRangeView.month;
  bool _showComparison = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final transactionsAsync = ref.watch(allTransactionsProvider);
    final defaultCurrencyAsync = ref.watch(defaultCurrencyProvider);
    final defaultCurrency =
        defaultCurrencyAsync.value ?? FinanceSettingsService.fallbackCurrency;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0D0F14)
          : const Color(0xFFF8F9FC),
      body: isDark
          ? DarkGradient.wrap(
              child: _buildBody(isDark, transactionsAsync, defaultCurrency),
            )
          : _buildBody(isDark, transactionsAsync, defaultCurrency),
    );
  }

  Widget _buildBody(
    bool isDark,
    AsyncValue<List<Transaction>> transactionsAsync,
    String defaultCurrency,
  ) {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(isDark),
          Expanded(
            child: transactionsAsync.when(
              data: (transactions) {
                final filtered = _filterIncomeTransactions(transactions);
                return _buildContent(isDark, filtered, defaultCurrency);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 20),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.arrow_back_rounded,
                    size: 20,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF4CAF50), Color(0xFF388E3C)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.analytics_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Income Report',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Analytics & insights',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    bool isDark,
    List<Transaction> transactions,
    String defaultCurrency,
  ) {
    final totalsByCurrency = ExpenseRangeUtils.totalsByCurrency(
      transactions,
      defaultCurrency: defaultCurrency,
    );
    final displayCurrency = totalsByCurrency.containsKey(defaultCurrency)
        ? defaultCurrency
        : (totalsByCurrency.isEmpty
              ? defaultCurrency
              : totalsByCurrency.keys.first);
    final total = totalsByCurrency[displayCurrency] ?? 0.0;
    final symbol = CurrencyUtils.getCurrencySymbol(displayCurrency);

    // Get previous period for comparison
    final previousRange = _previousRange();
    final transactionsAsync = ref.watch(allTransactionsProvider);
    final previousTransactions = transactionsAsync.maybeWhen(
      data: (allTx) => _filterTransactionsForRange(allTx, previousRange),
      orElse: () => <Transaction>[],
    );
    final previousTotal = ExpenseRangeUtils.totalsByCurrency(
      previousTransactions,
      defaultCurrency: defaultCurrency,
    )[displayCurrency] ?? 0.0;

    // Get recurring income data
    final recurringIncomesAsync = ref.watch(currentlyActiveRecurringIncomesProvider);
    final expectedIncome = recurringIncomesAsync.maybeWhen(
      data: (incomes) => _calculateExpectedIncome(incomes, displayCurrency),
      orElse: () => 0.0,
    );

    // Group by category
    final byCategory = <String, List<Transaction>>{};
    for (final tx in transactions) {
      final catId = tx.categoryId ?? 'uncategorized';
      byCategory.putIfAbsent(catId, () => []).add(tx);
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRangeSelector(isDark),
                const SizedBox(height: 16),
                _buildTotalCard(isDark, total, symbol, transactions.length),
                const SizedBox(height: 12),
                
                // Quick Stats Row
                if (transactions.isNotEmpty)
                  _buildQuickStatsRow(isDark, transactions, byCategory, symbol),
                const SizedBox(height: 16),
                if (_showComparison) ...[
                  _buildComparisonCard(
                    isDark,
                    total,
                    previousTotal,
                    symbol,
                    _selectedRangeView,
                  ),
                  const SizedBox(height: 16),
                ],
                if (expectedIncome > 0) ...[
                  _buildExpectedVsActualCard(
                    isDark,
                    total,
                    expectedIncome,
                    symbol,
                  ),
                  const SizedBox(height: 16),
                ],
                _buildInsightsCard(isDark, transactions, total, symbol),
                const SizedBox(height: 28),
                
                // Visual Charts Section Header
                if (transactions.isNotEmpty) ...[
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4CAF50), Color(0xFF388E3C)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.bar_chart_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'VISUAL REPORTS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF4CAF50),
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildIncomeOverTimeChart(isDark, transactions, displayCurrency, symbol),
                  const SizedBox(height: 16),
                  _buildCategoryPieChart(isDark, byCategory, displayCurrency, symbol),
                  const SizedBox(height: 28),
                ],
                
                Text(
                  'BY CATEGORY',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFCDAF56),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        if (byCategory.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.inbox_rounded,
                      size: 64,
                      color: isDark ? Colors.white12 : Colors.black12,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No income data',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final entry = byCategory.entries.toList()[index];
                  final catTotal = ExpenseRangeUtils.totalsByCurrency(
                    entry.value,
                    defaultCurrency: defaultCurrency,
                  )[displayCurrency] ?? 0.0;
                  return _buildCategoryTile(
                    isDark,
                    entry.key,
                    catTotal,
                    symbol,
                    entry.value.length,
                  );
                },
                childCount: byCategory.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRangeSelector(bool isDark) {
    return Column(
      children: [
        // First row: Day, Week, Month
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.06),
            ),
          ),
          child: Row(
            children: [
              _buildRangeChip(isDark, ExpenseRangeView.day, 'Day', Icons.today_rounded),
              const SizedBox(width: 4),
              _buildRangeChip(isDark, ExpenseRangeView.week, 'Week', Icons.view_week_rounded),
              const SizedBox(width: 4),
              _buildRangeChip(isDark, ExpenseRangeView.month, 'Month', Icons.calendar_month_rounded),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Second row: 6 Months, 1 Year
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.06),
            ),
          ),
          child: Row(
            children: [
              _buildRangeChip(isDark, ExpenseRangeView.sixMonths, '6 Months', Icons.date_range_rounded),
              const SizedBox(width: 4),
              _buildRangeChip(isDark, ExpenseRangeView.year, '1 Year', Icons.calendar_today_rounded),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRangeChip(bool isDark, ExpenseRangeView view, String label, IconData icon) {
    final isSelected = _selectedRangeView == view;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_selectedRangeView == view) return;
          setState(() => _selectedRangeView = view);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF4CAF50), Color(0xFF388E3C)],
                  )
                : null,
            color: isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF4CAF50).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white60 : Colors.black54),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white60 : Colors.black54),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTotalCard(
    bool isDark,
    double total,
    String symbol,
    int count,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF4CAF50).withOpacity(isDark ? 0.15 : 0.1),
            const Color(0xFF388E3C).withOpacity(isDark ? 0.05 : 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TOTAL INCOME',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF4CAF50),
                  letterSpacing: 1.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count transactions',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4CAF50),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '$symbol${total.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF1E1E1E),
              letterSpacing: -1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTile(
    bool isDark,
    String categoryId,
    double total,
    String symbol,
    int count,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.03),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.category_rounded,
              color: Color(0xFF4CAF50),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  categoryId,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '$count transactions',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$symbol${total.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: Color(0xFF4CAF50),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonCard(
    bool isDark,
    double currentTotal,
    double previousTotal,
    String symbol,
    ExpenseRangeView view,
  ) {
    final difference = currentTotal - previousTotal;
    final percentChange = previousTotal > 0
        ? ((difference / previousTotal) * 100)
        : 0.0;
    final isIncrease = difference > 0;
    final isDecrease = difference < 0;

    String periodLabel;
    switch (view) {
      case ExpenseRangeView.day:
        periodLabel = 'vs Yesterday';
        break;
      case ExpenseRangeView.week:
        periodLabel = 'vs Last Week';
        break;
      case ExpenseRangeView.month:
        periodLabel = 'vs Last Month';
        break;
      case ExpenseRangeView.sixMonths:
        periodLabel = 'vs Previous 6 Months';
        break;
      case ExpenseRangeView.year:
        periodLabel = 'vs Previous Year';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            (isIncrease ? Colors.green : isDecrease ? Colors.orange : Colors.grey)
                .withOpacity(isDark ? 0.15 : 0.1),
            (isIncrease ? Colors.green : isDecrease ? Colors.orange : Colors.grey)
                .withOpacity(isDark ? 0.05 : 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isIncrease ? Colors.green : isDecrease ? Colors.orange : Colors.grey)
              .withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isIncrease
                    ? Icons.trending_up_rounded
                    : isDecrease
                        ? Icons.trending_down_rounded
                        : Icons.trending_flat_rounded,
                color: isIncrease
                    ? Colors.green
                    : isDecrease
                        ? Colors.orange
                        : Colors.grey,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                periodLabel,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${difference >= 0 ? '+' : ''}$symbol${difference.abs().toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: isIncrease
                      ? Colors.green
                      : isDecrease
                          ? Colors.orange
                          : (isDark ? Colors.white : Colors.black87),
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isIncrease
                            ? Colors.green
                            : isDecrease
                                ? Colors.orange
                                : Colors.grey)
                        .withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${percentChange >= 0 ? '+' : ''}${percentChange.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isIncrease
                          ? Colors.green
                          : isDecrease
                              ? Colors.orange
                              : Colors.grey,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Previous: $symbol${previousTotal.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpectedVsActualCard(
    bool isDark,
    double actual,
    double expected,
    String symbol,
  ) {
    final variance = actual - expected;
    final percentVariance = expected > 0 ? ((variance / expected) * 100) : 0.0;
    final isAbove = variance > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.withOpacity(isDark ? 0.15 : 0.1),
            Colors.blue.withOpacity(isDark ? 0.05 : 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.compare_arrows_rounded, color: Colors.blue, size: 24),
              const SizedBox(width: 8),
              Text(
                'Expected vs Actual',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Expected',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$symbol${expected.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Actual',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$symbol${actual.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isAbove ? Colors.green : Colors.orange).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  isAbove ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  color: isAbove ? Colors.green : Colors.orange,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  '${variance >= 0 ? '+' : ''}$symbol${variance.abs().toStringAsFixed(2)} (${percentVariance >= 0 ? '+' : ''}${percentVariance.toStringAsFixed(1)}%)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isAbove ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsCard(
    bool isDark,
    List<Transaction> transactions,
    double total,
    String symbol,
  ) {
    final range = _currentRange();
    final days = range.end.difference(range.start).inDays + 1;
    final dailyAverage = days > 0 ? total / days : 0.0;

    // Find highest and lowest income days
    final byDate = <DateTime, double>{};
    for (final tx in transactions) {
      final date = ExpenseRangeUtils.normalizeDate(tx.transactionDate);
      byDate[date] = (byDate[date] ?? 0.0) + tx.amount;
    }

    final sortedDays = byDate.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final highestDay = sortedDays.isNotEmpty ? sortedDays.first : null;
    final lowestDay = sortedDays.isNotEmpty ? sortedDays.last : null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.purple.withOpacity(isDark ? 0.15 : 0.1),
            Colors.purple.withOpacity(isDark ? 0.05 : 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.purple.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_rounded, color: Colors.purple, size: 24),
              const SizedBox(width: 8),
              Text(
                'Insights',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInsightRow(
            isDark,
            Icons.calendar_today_rounded,
            'Daily Average',
            '$symbol${dailyAverage.toStringAsFixed(2)}',
          ),
          if (highestDay != null) ...[
            const SizedBox(height: 12),
            _buildInsightRow(
              isDark,
              Icons.arrow_circle_up_rounded,
              'Highest Day',
              '$symbol${highestDay.value.toStringAsFixed(2)} (${_formatShortDate(highestDay.key)})',
            ),
          ],
          if (lowestDay != null && lowestDay != highestDay) ...[
            const SizedBox(height: 12),
            _buildInsightRow(
              isDark,
              Icons.arrow_circle_down_rounded,
              'Lowest Day',
              '$symbol${lowestDay.value.toStringAsFixed(2)} (${_formatShortDate(lowestDay.key)})',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInsightRow(
    bool isDark,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Icon(icon, color: Colors.purple, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }

  List<Transaction> _filterIncomeTransactions(List<Transaction> transactions) {
    final range = _currentRange();
    return _filterTransactionsForRange(transactions, range);
  }

  List<Transaction> _filterTransactionsForRange(
    List<Transaction> transactions,
    ExpenseRange range,
  ) {
    return transactions.where((tx) {
      if (tx.type != 'income') return false;
      final txDate = ExpenseRangeUtils.normalizeDate(tx.transactionDate);
      return !txDate.isBefore(range.start) && !txDate.isAfter(range.end);
    }).toList();
  }

  ExpenseRange _currentRange() =>
      ExpenseRangeUtils.rangeFor(_selectedDate, _selectedRangeView);

  ExpenseRange _previousRange() {
    switch (_selectedRangeView) {
      case ExpenseRangeView.day:
        final prevDate = _selectedDate.subtract(const Duration(days: 1));
        return ExpenseRangeUtils.rangeFor(prevDate, _selectedRangeView);
      case ExpenseRangeView.week:
        final prevDate = _selectedDate.subtract(const Duration(days: 7));
        return ExpenseRangeUtils.rangeFor(prevDate, _selectedRangeView);
      case ExpenseRangeView.month:
        final prevDate = DateTime(_selectedDate.year, _selectedDate.month - 1, 1);
        return ExpenseRangeUtils.rangeFor(prevDate, _selectedRangeView);
      case ExpenseRangeView.sixMonths:
        final prevDate = DateTime(_selectedDate.year, _selectedDate.month - 6, 1);
        return ExpenseRangeUtils.rangeFor(prevDate, _selectedRangeView);
      case ExpenseRangeView.year:
        final prevDate = DateTime(_selectedDate.year - 1, _selectedDate.month, 1);
        return ExpenseRangeUtils.rangeFor(prevDate, _selectedRangeView);
    }
  }

  double _calculateExpectedIncome(
    List<RecurringIncome> incomes,
    String currency,
  ) {
    final range = _currentRange();
    double total = 0.0;

    for (final income in incomes) {
      if (income.currency != currency) continue;
      final occurrences = income.occurrencesBetween(range.start, range.end);
      total += occurrences.length * income.amount;
    }

    return total;
  }

  String _formatShortDate(DateTime date) {
    return '${date.day}/${date.month}';
  }

  Widget _buildQuickStatsRow(
    bool isDark,
    List<Transaction> transactions,
    Map<String, List<Transaction>> byCategory,
    String symbol,
  ) {
    // Calculate average per transaction
    final avgPerTransaction = transactions.isEmpty 
        ? 0.0 
        : transactions.fold<double>(0.0, (sum, tx) => sum + tx.amount) / transactions.length;
    
    // Find highest single transaction
    final highestTransaction = transactions.isEmpty
        ? 0.0
        : transactions.map((tx) => tx.amount).reduce((a, b) => a > b ? a : b);
    
    // Count of income sources (categories with income)
    final activeSources = byCategory.length;

    return Row(
      children: [
        Expanded(
          child: _buildQuickStatCard(
            isDark,
            Icons.payments_rounded,
            'Avg/Transaction',
            '$symbol${avgPerTransaction.toStringAsFixed(2)}',
            Colors.blue,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildQuickStatCard(
            isDark,
            Icons.star_rounded,
            'Highest',
            '$symbol${highestTransaction.toStringAsFixed(2)}',
            Colors.amber,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildQuickStatCard(
            isDark,
            Icons.category_rounded,
            'Sources',
            '$activeSources',
            const Color(0xFF4CAF50),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStatCard(
    bool isDark,
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(isDark ? 0.15 : 0.1),
            color.withOpacity(isDark ? 0.05 : 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyBarChart(
    bool isDark,
    List<Transaction> transactions,
    String currency,
    String symbol,
  ) {
    // Group by month
    final Map<String, double> monthlyIncome = {};
    for (final tx in transactions) {
      if (tx.currency == currency) {
        final monthKey = DateFormat('MMM yy').format(tx.transactionDate);
        monthlyIncome[monthKey] = (monthlyIncome[monthKey] ?? 0.0) + tx.amount;
      }
    }

    if (monthlyIncome.isEmpty) return const SizedBox.shrink();

    final sortedMonths = monthlyIncome.keys.toList();
    final maxY = monthlyIncome.values.reduce((a, b) => a > b ? a : b) * 1.2;

    final barGroups = <BarChartGroupData>[];
    for (int i = 0; i < sortedMonths.length; i++) {
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: monthlyIncome[sortedMonths[i]]!,
              gradient: const LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
              ),
              width: 20,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: maxY,
                color: isDark
                    ? Colors.white.withOpacity(0.03)
                    : Colors.black.withOpacity(0.03),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF4CAF50).withOpacity(isDark ? 0.12 : 0.08),
            const Color(0xFF388E3C).withOpacity(isDark ? 0.04 : 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF4CAF50).withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  color: Color(0xFF4CAF50),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'MONTHLY INCOME TREND',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF4CAF50),
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                minY: 0,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    tooltipBgColor: isDark
                        ? const Color(0xFF2D3139)
                        : Colors.white,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${sortedMonths[group.x.toInt()]}\n',
                        TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                        children: [
                          TextSpan(
                            text: '$symbol${rod.toY.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Color(0xFF4CAF50),
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= sortedMonths.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            sortedMonths[index].split(' ')[0], // Show only month abbreviation
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      interval: maxY / 4,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox.shrink();
                        return Text(
                          '$symbol${(value / 1000).toStringAsFixed(0)}k',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.05),
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                barGroups: barGroups,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeOverTimeChart(
    bool isDark,
    List<Transaction> transactions,
    String currency,
    String symbol,
  ) {
    // For longer periods (6 months, 1 year), group by month; otherwise by day
    final isLongPeriod = _selectedRangeView == ExpenseRangeView.sixMonths || 
                         _selectedRangeView == ExpenseRangeView.year;
    
    if (isLongPeriod) {
      return _buildMonthlyBarChart(isDark, transactions, currency, symbol);
    }
    
    // Group transactions by date for daily view
    final Map<DateTime, double> dailyIncome = {};
    for (final tx in transactions) {
      if (tx.currency == currency) {
        final date = ExpenseRangeUtils.normalizeDate(tx.transactionDate);
        dailyIncome[date] = (dailyIncome[date] ?? 0.0) + tx.amount;
      }
    }

    if (dailyIncome.isEmpty) return const SizedBox.shrink();

    final sortedDates = dailyIncome.keys.toList()..sort();
    final spots = <FlSpot>[];
    for (int i = 0; i < sortedDates.length; i++) {
      spots.add(FlSpot(i.toDouble(), dailyIncome[sortedDates[i]]!));
    }

    final maxY = dailyIncome.values.isEmpty 
        ? 100.0 
        : dailyIncome.values.reduce((a, b) => a > b ? a : b) * 1.2;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF4CAF50).withOpacity(isDark ? 0.12 : 0.08),
            const Color(0xFF388E3C).withOpacity(isDark ? 0.04 : 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF4CAF50).withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.show_chart_rounded,
                  color: Color(0xFF4CAF50),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'INCOME OVER TIME',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF4CAF50),
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.05),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: (sortedDates.length / 5).ceilToDouble(),
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= sortedDates.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            DateFormat('MMM d').format(sortedDates[index]),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 45,
                      interval: maxY / 4,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '$symbol${value.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (sortedDates.length - 1).toDouble(),
                minY: 0,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4CAF50), Color(0xFF388E3C)],
                    ),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: Colors.white,
                          strokeWidth: 2,
                          strokeColor: const Color(0xFF4CAF50),
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF4CAF50).withOpacity(0.3),
                          const Color(0xFF4CAF50).withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPieChart(
    bool isDark,
    Map<String, List<Transaction>> byCategory,
    String currency,
    String symbol,
  ) {
    // Calculate totals by category
    final Map<String, double> categoryTotals = {};
    for (final entry in byCategory.entries) {
      final total = entry.value
          .where((tx) => tx.currency == currency)
          .fold<double>(0.0, (sum, tx) => sum + tx.amount);
      if (total > 0) {
        categoryTotals[entry.key] = total;
      }
    }

    if (categoryTotals.isEmpty) return const SizedBox.shrink();

    final totalIncome = categoryTotals.values.reduce((a, b) => a + b);
    final sortedEntries = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Color palette for categories
    final colors = [
      const Color(0xFF4CAF50),
      const Color(0xFF2196F3),
      const Color(0xFFFFC107),
      const Color(0xFFFF9800),
      const Color(0xFF9C27B0),
      const Color(0xFF00BCD4),
      const Color(0xFFE91E63),
      const Color(0xFF8BC34A),
    ];

    int touchedIndex = -1;

    final sections = sortedEntries.asMap().entries.map((entry) {
      final index = entry.key;
      final catEntry = entry.value;
      final percentage = (catEntry.value / totalIncome) * 100;
      final isTouched = index == touchedIndex;
      
      return PieChartSectionData(
        value: catEntry.value,
        title: percentage >= 8 ? '${percentage.toStringAsFixed(0)}%' : '',
        color: colors[index % colors.length],
        radius: isTouched ? 90 : 80,
        titleStyle: TextStyle(
          fontSize: isTouched ? 14 : 12,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 2,
            ),
          ],
        ),
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.pie_chart_rounded,
                  color: Color(0xFF4CAF50),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'INCOME BY CATEGORY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF4CAF50),
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // Pie Chart
              SizedBox(
                height: 200,
                width: 200,
                child: PieChart(
                  PieChartData(
                    sections: sections,
                    sectionsSpace: 3,
                    centerSpaceRadius: 45,
                    borderData: FlBorderData(show: false),
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        // Touch interaction for highlighting slices
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              // Legend
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: sortedEntries.take(5).toList().asMap().entries.map((entry) {
                    final index = entry.key;
                    final catEntry = entry.value;
                    final percentage = (catEntry.value / totalIncome) * 100;
                    
                    // Get category name
                    final categoryAsync = ref.watch(transactionCategoryByIdProvider(catEntry.key));
                    final categoryName = categoryAsync?.name ?? 'Unknown';
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: colors[index % colors.length],
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  categoryName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '$symbol${catEntry.value.toStringAsFixed(2)} (${percentage.toStringAsFixed(1)}%)',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white38 : Colors.black38,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
