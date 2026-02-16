import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import '../../../../core/theme/dark_gradient.dart';
import '../../../../core/widgets/date_navigator_widget.dart';
import '../../data/models/transaction.dart';
import '../../data/services/finance_settings_service.dart';
import '../../utils/currency_utils.dart';
import '../../utils/expense_range_utils.dart';
import '../providers/finance_providers.dart';
import 'add_transaction_screen.dart';
import 'all_expenses_list_screen.dart';
import 'bills_subscriptions_screen.dart';
import 'expense_category_screen.dart';
import 'expense_report_screen.dart';
import 'transaction_categories_screen.dart';

import '../../data/models/transaction_category.dart';

/// Expenses Screen - Central hub for expense management
class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  final _quickAmountController = TextEditingController();
  String? _selectedQuickCategory;
  DateTime _selectedDate = ExpenseRangeUtils.normalizeDate(DateTime.now());
  ExpenseRangeView _selectedRangeView = ExpenseRangeView.day;
  bool _isDailyBreakdownExpanded = false;

  @override
  void dispose() {
    _quickAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final transactionsAsync = ref.watch(allTransactionsProvider);
    final billSummaryAsync = ref.watch(billSummaryProvider);
    final defaultCurrencyAsync = ref.watch(defaultCurrencyProvider);
    final defaultCurrency =
        defaultCurrencyAsync.value ?? FinanceSettingsService.fallbackCurrency;
    final expenseCategoriesAsync = ref.watch(expenseTransactionCategoriesProvider);
    final expenseCategories = expenseCategoriesAsync.valueOrNull ?? [];

    final content = SafeArea(
      top: true,
      bottom: false,
      child: _buildContent(
        context,
        isDark,
        transactionsAsync,
        billSummaryAsync,
        defaultCurrency,
        expenseCategories,
      ),
    );

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0D0F14)
          : const Color(0xFFF8F9FC),
      body: isDark ? DarkGradient.wrap(child: content) : content,
    );
  }

  Widget _buildContent(
    BuildContext context,
    bool isDark,
    AsyncValue<List<Transaction>> transactionsAsync,
    AsyncValue<Map<String, dynamic>> billSummaryAsync,
    String defaultCurrency,
    List<TransactionCategory> expenseCategories,
  ) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildSliverAppBar(isDark, defaultCurrency),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                _buildDateScopeSection(isDark),
                const SizedBox(height: 16),

                // Selected period summary card
                transactionsAsync.when(
                  data: (transactions) => _buildPeriodSummaryCard(
                    isDark,
                    transactions,
                    defaultCurrency,
                  ),
                  loading: () => _buildLoadingCard(isDark),
                  error: (e, _) => _buildErrorCard(e.toString(), isDark),
                ),
                const SizedBox(height: 14),

                // Day-by-day breakdown for the selected period
                transactionsAsync.when(
                  data: (transactions) => _buildDailyBreakdownCard(
                    isDark,
                    transactions,
                    defaultCurrency,
                  ),
                  loading: () => _buildLoadingCard(isDark),
                  error: (e, _) => _buildErrorCard(e.toString(), isDark),
                ),
                const SizedBox(height: 24),

                // Quick Add Section
                if (expenseCategories.isNotEmpty) ...[
                  _buildQuickAddSection(isDark, defaultCurrency, expenseCategories),
                  const SizedBox(height: 28),
                ],

                // Bills & Subscriptions
                if (billSummaryAsync.hasValue) ...[
                  Text(
                    'RECURRING',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFCDAF56),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  billSummaryAsync.when(
                    data: (summary) =>
                        _buildBillsCard(isDark, summary, defaultCurrency),
                    loading: () => _buildCategoryCardSkeleton(isDark),
                    error: (error, stackTrace) =>
                        _buildBillsCard(isDark, {}, defaultCurrency),
                  ),
                  const SizedBox(height: 24),
                ],

                // Expense Categories Grid
                if (expenseCategories.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'EXPENSE CATEGORIES',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFCDAF56),
                          letterSpacing: 1.5,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const AllExpensesListScreen(),
                            ),
                          ).then((_) =>
                              ref.invalidate(allTransactionsProvider));
                        },
                        child: Text(
                          'View All Expenses',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFCDAF56),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                transactionsAsync.when(
                  data: (transactions) => _buildCategoriesGrid(
                    isDark,
                    _selectedExpenseTransactions(transactions),
                    defaultCurrency,
                    expenseCategories,
                  ),
                  loading: () => _buildCategoriesGridSkeleton(isDark),
                  error: (error, stackTrace) =>
                      _buildCategoriesGrid(isDark, [], defaultCurrency, expenseCategories),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSliverAppBar(bool isDark, String defaultCurrency) {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          children: [
            // Top Row - Back & Add buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Back Button with outline
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.03)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.08)
                            : Colors.black.withOpacity(0.06),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      Icons.arrow_back_rounded,
                      size: 20,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),

                Row(
                  children: [
                    // Category Manager Button
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TransactionCategoriesScreen(),
                          ),
                        ).then((_) {
                          ref.invalidate(expenseTransactionCategoriesProvider);
                          ref.invalidate(allTransactionsProvider);
                        });
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.03)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withOpacity(0.08)
                                : Colors.black.withOpacity(0.06),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons.category_rounded,
                          size: 20,
                          color: const Color(0xFFFF6B6B),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Report Button
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ExpenseReportScreen(),
                          ),
                        );
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.03)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withOpacity(0.08)
                                : Colors.black.withOpacity(0.06),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons.analytics_rounded,
                          size: 20,
                          color: const Color(0xFFCDAF56),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Add Button with outline
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                AddTransactionScreen(initialType: 'expense'),
                          ),
                        ).then((_) => ref.invalidate(allTransactionsProvider));
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF5252).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFFF5252).withOpacity(0.2),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          size: 22,
                          color: Color(0xFFFF5252),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Header Row - Icon + Title
            Row(
              children: [
                // Expenses Icon with gradient and outline
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFF5252), Color(0xFFE53935)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.trending_down_rounded,
                    size: 28,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 18),

                // Title & Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Expenses',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1E1E1E),
                          letterSpacing: -0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Track & manage spending',
                        style: TextStyle(
                          fontSize: 13,
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
      ),
    );
  }

  ExpenseRange _selectedRange() =>
      ExpenseRangeUtils.rangeFor(_selectedDate, _selectedRangeView);

  List<Transaction> _selectedExpenseTransactions(
    List<Transaction> transactions,
  ) {
    return ExpenseRangeUtils.filterExpensesForRange(
      transactions,
      range: _selectedRange(),
    );
  }

  String _selectedPeriodLabel() {
    switch (_selectedRangeView) {
      case ExpenseRangeView.day:
        return 'DAY';
      case ExpenseRangeView.week:
        return 'WEEK';
      case ExpenseRangeView.month:
        return 'MONTH';
      case ExpenseRangeView.sixMonths:
        return '6 MONTHS';
      case ExpenseRangeView.year:
        return 'YEAR';
    }
  }

  String _selectedRangeDateLabel(ExpenseRange range) {
    switch (_selectedRangeView) {
      case ExpenseRangeView.day:
        return DateFormat('EEE, MMM d, yyyy').format(range.start);
      case ExpenseRangeView.week:
        return '${DateFormat('MMM d').format(range.start)} - ${DateFormat('MMM d, yyyy').format(range.end)}';
      case ExpenseRangeView.month:
        return DateFormat('MMMM yyyy').format(range.start);
      case ExpenseRangeView.sixMonths:
        return '${DateFormat('MMM yyyy').format(range.start)} - ${DateFormat('MMM yyyy').format(range.end)}';
      case ExpenseRangeView.year:
        return '${DateFormat('MMM yyyy').format(range.start)} - ${DateFormat('MMM yyyy').format(range.end)}';
    }
  }

  Widget _buildDateScopeSection(bool isDark) {
    final range = _selectedRange();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DateNavigatorWidget(
          selectedDate: _selectedDate,
          onDateChanged: (newDate) {
            setState(() {
              _selectedDate = ExpenseRangeUtils.normalizeDate(newDate);
            });
          },
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.06),
            ),
          ),
          child: Row(
            children: [
              _buildRangeChip(isDark, ExpenseRangeView.day, 'Day'),
              _buildRangeChip(isDark, ExpenseRangeView.week, 'Week'),
              _buildRangeChip(isDark, ExpenseRangeView.month, 'Month'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _selectedRangeDateLabel(range),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
        ),
      ],
    );
  }

  Widget _buildRangeChip(bool isDark, ExpenseRangeView view, String label) {
    final isSelected = _selectedRangeView == view;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_selectedRangeView == view) return;
          HapticFeedback.selectionClick();
          setState(() => _selectedRangeView = view);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFF5252) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white60 : Colors.black54),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSummaryCard(
    bool isDark,
    List<Transaction> transactions,
    String defaultCurrency,
  ) {
    final range = _selectedRange();
    final periodTransactions = _selectedExpenseTransactions(transactions);
    final totalsByCurrency = ExpenseRangeUtils.totalsByCurrency(
      periodTransactions,
      defaultCurrency: defaultCurrency,
    );

    final displayCurrency = totalsByCurrency.containsKey(defaultCurrency)
        ? defaultCurrency
        : (totalsByCurrency.isEmpty
              ? defaultCurrency
              : totalsByCurrency.keys.first);
    final primaryTotal = totalsByCurrency[displayCurrency] ?? 0.0;
    final dailyAverage = range.totalDays > 0
        ? primaryTotal / range.totalDays
        : 0.0;
    final secondaryTotals = totalsByCurrency.entries
        .where((entry) => entry.key != displayCurrency)
        .toList();
    final symbol = CurrencyUtils.getCurrencySymbol(displayCurrency);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFF5252).withOpacity(isDark ? 0.15 : 0.1),
            const Color(0xFFFF1744).withOpacity(isDark ? 0.05 : 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFFF5252).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SELECTED ${_selectedPeriodLabel()}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFFF5252),
                  letterSpacing: 1.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5252).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${periodTransactions.length} expenses',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFF5252),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _selectedRangeDateLabel(range),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '$symbol${primaryTotal.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF1E1E1E),
              letterSpacing: -1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '~$symbol${dailyAverage.toStringAsFixed(2)}/day average',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
          if (secondaryTotals.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: secondaryTotals.map((entry) {
                final secondarySymbol = CurrencyUtils.getCurrencySymbol(
                  entry.key,
                );
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.06)
                        : Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$secondarySymbol${entry.value.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDailyBreakdownCard(
    bool isDark,
    List<Transaction> transactions,
    String defaultCurrency,
  ) {
    final range = _selectedRange();
    final periodTransactions = _selectedExpenseTransactions(transactions);
    final periodTotals = ExpenseRangeUtils.totalsByCurrency(
      periodTransactions,
      defaultCurrency: defaultCurrency,
    );
    final primaryCurrency = periodTotals.containsKey(defaultCurrency)
        ? defaultCurrency
        : (periodTotals.isEmpty ? defaultCurrency : periodTotals.keys.first);

    final dailyTotals = ExpenseRangeUtils.dailyTotals(
      periodTransactions,
      range: range,
      defaultCurrency: defaultCurrency,
    );

    var maxPrimaryAmount = 0.0;
    for (final day in dailyTotals) {
      final value = day.totalsByCurrency[primaryCurrency] ?? 0.0;
      if (value > maxPrimaryAmount) {
        maxPrimaryAmount = value;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _isDailyBreakdownExpanded = !_isDailyBreakdownExpanded;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_view_week_rounded,
                    size: 18,
                    color: Color(0xFFCDAF56),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'DAILY BREAKDOWN',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFCDAF56),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${dailyTotals.length} days',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _isDailyBreakdownExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: _isDailyBreakdownExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Collapsed. Tap to view per-day expenses.',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ),
            secondChild: Column(
              children: [
                const SizedBox(height: 14),
                ...dailyTotals.map(
                  (dailyTotal) => _buildDailyBreakdownRow(
                    isDark,
                    dailyTotal,
                    primaryCurrency,
                    maxPrimaryAmount,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyBreakdownRow(
    bool isDark,
    ExpenseDailyTotal dailyTotal,
    String primaryCurrency,
    double maxPrimaryAmount,
  ) {
    final primaryAmount = dailyTotal.totalsByCurrency[primaryCurrency] ?? 0.0;
    final widthFactor = maxPrimaryAmount <= 0
        ? 0.0
        : (primaryAmount / maxPrimaryAmount).clamp(0.0, 1.0);
    final symbol = CurrencyUtils.getCurrencySymbol(primaryCurrency);
    final secondary = _formatSecondaryCurrencyTotals(
      dailyTotal.totalsByCurrency,
      primaryCurrency,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat('EEE, MMM d').format(dailyTotal.date),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
              if (dailyTotal.transactionCount > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    '${dailyTotal.transactionCount} tx',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ),
              Text(
                '$symbol${primaryAmount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: primaryAmount > 0
                      ? const Color(0xFFFF5252)
                      : (isDark ? Colors.white30 : Colors.black26),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 7,
              color: isDark
                  ? Colors.white.withOpacity(0.06)
                  : Colors.black.withOpacity(0.06),
              child: FractionallySizedBox(
                widthFactor: widthFactor,
                alignment: Alignment.centerLeft,
                child: Container(
                  decoration: const BoxDecoration(color: Color(0xFFFF5252)),
                ),
              ),
            ),
          ),
          if (secondary.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              secondary,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatSecondaryCurrencyTotals(
    Map<String, double> totalsByCurrency,
    String primaryCurrency,
  ) {
    final secondary = totalsByCurrency.entries
        .where((entry) => entry.key != primaryCurrency && entry.value > 0)
        .toList();
    if (secondary.isEmpty) {
      return '';
    }

    return secondary
        .map((entry) {
          final symbol = CurrencyUtils.getCurrencySymbol(entry.key);
          return '$symbol${entry.value.toStringAsFixed(2)}';
        })
        .join(' | ');
  }

  Widget _buildQuickAddSection(bool isDark, String defaultCurrency, List<TransactionCategory> expenseCategories) {
    final symbol = CurrencyUtils.getCurrencySymbol(defaultCurrency);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.03),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.flash_on_rounded,
                color: Color(0xFFCDAF56),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'QUICK ADD',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFCDAF56),
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: expenseCategories.length,
              itemBuilder: (context, index) {
                final cat = expenseCategories[index];
                final isSelected = _selectedQuickCategory == cat.id;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(
                        () =>
                            _selectedQuickCategory = isSelected ? null : cat.id,
                      );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? cat.color
                            : cat.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? cat.color
                              : cat.color.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            cat.icon ?? Icons.category_rounded,
                            size: 18,
                            color: isSelected ? Colors.white : cat.color,
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 8),
                            Text(
                              cat.name.split(' ').first,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _quickAmountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white24 : Colors.black26,
                    ),
                    prefixText: '$symbol ',
                    prefixStyle: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: _selectedQuickCategory != null && expenseCategories.any((c) => c.id == _selectedQuickCategory)
                          ? expenseCategories.firstWhere((c) => c.id == _selectedQuickCategory).color
                          : (isDark ? Colors.white38 : Colors.black38),
                    ),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withOpacity(0.03)
                        : Colors.grey.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => _quickAddExpense(defaultCurrency),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: (_selectedQuickCategory != null && expenseCategories.any((c) => c.id == _selectedQuickCategory))
                          ? [
                              expenseCategories.firstWhere((c) => c.id == _selectedQuickCategory).color,
                              expenseCategories.firstWhere((c) => c.id == _selectedQuickCategory).color.withOpacity(0.8),
                            ]
                          : [const Color(0xFFCDAF56), const Color(0xFFE8D48A)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBillsCard(
    bool isDark,
    Map<String, dynamic> summary,
    String defaultCurrency,
  ) {
    final monthlyTotals = summary['monthlyTotals'] as Map<String, double>?;
    final totalBills = summary['totalBills'] ?? 0;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const BillsSubscriptionsScreen(),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.amber.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                color: Colors.amber,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bills & Subscriptions',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$totalBills active',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
              ),
            ),
            if (monthlyTotals != null && monthlyTotals.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${CurrencyUtils.getCurrencySymbol(monthlyTotals.keys.first)}${monthlyTotals.values.first.toStringAsFixed(0)}/mo',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.amber,
                  ),
                ),
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? Colors.white12 : Colors.black12,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesGrid(
    bool isDark,
    List<Transaction> transactions,
    String defaultCurrency,
    List<TransactionCategory> expenseCategories,
  ) {
    if (expenseCategories.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            children: [
              Lottie.asset(
                'assets/animations/sad.json',
                width: 120,
                height: 120,
                repeat: true,
              ),
              const SizedBox(height: 12),
              Text(
                'No expense categories yet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add categories to start tracking your expenses',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TransactionCategoriesScreen(),
                  ),
                ).then((_) {
                  ref.invalidate(expenseTransactionCategoriesProvider);
                }),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Add Categories'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCDAF56),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.15,
      ),
      itemCount: expenseCategories.length,
      itemBuilder: (context, index) {
        final cat = expenseCategories[index];
        final categoryTransactions = transactions
            .where((t) => t.categoryId == cat.id)
            .toList();
        final totalsByCurrency = ExpenseRangeUtils.totalsByCurrency(
          categoryTransactions,
          defaultCurrency: defaultCurrency,
        );
        final displayCurrency = totalsByCurrency.containsKey(defaultCurrency)
            ? defaultCurrency
            : (totalsByCurrency.isEmpty
                  ? defaultCurrency
                  : totalsByCurrency.keys.first);
        final spent = totalsByCurrency[displayCurrency] ?? 0.0;
        final hasMultipleCurrencies = totalsByCurrency.length > 1;
        final symbol = CurrencyUtils.getCurrencySymbol(displayCurrency);
        final transactionCount = categoryTransactions.length;
        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ExpenseCategoryScreen(
                  categoryId: cat.id,
                  categoryName: cat.name,
                  categoryIcon: cat.icon ?? Icons.category_rounded,
                  categoryColor: cat.color,
                ),
              ),
            ).then((_) => ref.invalidate(allTransactionsProvider));
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: cat.color.withOpacity(isDark ? 0.15 : 0.1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: cat.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(cat.icon ?? Icons.category_rounded, color: cat.color, size: 22),
                    ),
                    if (transactionCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: cat.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$transactionCount',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: cat.color,
                          ),
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  cat.name.split('&').first.trim(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  spent > 0
                      ? '$symbol${spent.toStringAsFixed(2)}'
                      : 'No expenses',
                  style: TextStyle(
                    fontSize: spent > 0 ? 14 : 11,
                    fontWeight: spent > 0 ? FontWeight.w900 : FontWeight.w500,
                    color: spent > 0
                        ? cat.color
                        : (isDark ? Colors.white24 : Colors.black26),
                  ),
                ),
                if (hasMultipleCurrencies)
                  Text(
                    '+${totalsByCurrency.length - 1} currencies',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryCardSkeleton(bool isDark) => Container(
    height: 88,
    decoration: BoxDecoration(
      color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
      borderRadius: BorderRadius.circular(20),
    ),
  );
  Widget _buildCategoriesGridSkeleton(bool isDark) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.15,
    ),
    itemCount: 6,
    itemBuilder: (context, index) => Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
    ),
  );
  Widget _buildLoadingCard(bool isDark) => Container(
    width: double.infinity,
    height: 140,
    decoration: BoxDecoration(
      color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
      borderRadius: BorderRadius.circular(28),
    ),
    child: const Center(child: CircularProgressIndicator()),
  );
  Widget _buildErrorCard(String error, bool isDark) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
      borderRadius: BorderRadius.circular(28),
    ),
    child: Text(
      'Error: $error',
      style: const TextStyle(color: Color(0xFFFF5252)),
    ),
  );

  Future<void> _quickAddExpense(String defaultCurrency) async {
    if (_selectedQuickCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a category first'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final amountText = _quickAmountController.text.trim();
    if (amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an amount'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Get default account
    final accountRepo = ref.read(accountRepositoryProvider);
    final defaultAccount = await accountRepo.getDefaultAccount();
    if (!mounted) return;

    if (defaultAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'No default account set. Please set a default account first.',
          ),
          backgroundColor: Colors.orange.shade400,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    final categories = ref.read(expenseTransactionCategoriesProvider).valueOrNull ?? [];
    final cat = categories.firstWhere(
      (c) => c.id == _selectedQuickCategory,
      orElse: () => categories.first,
    );

    final transaction = Transaction(
      title: cat.name,
      amount: amount,
      type: 'expense',
      categoryId: cat.id,
      accountId: defaultAccount.id, // Link to default account
      transactionDate: DateTime.now(),
      transactionTime: TimeOfDay.now(),
      currency: defaultCurrency,
      isCleared: true,
    );

    try {
      final repo = ref.read(transactionRepositoryProvider);
      await repo.createTransaction(transaction);

      // Deduct from account balance
      defaultAccount.balance -= amount;
      await accountRepo.updateAccount(defaultAccount);

      // Invalidate all relevant providers
      ref.invalidate(allTransactionsProvider);
      ref.invalidate(totalBalanceProvider);
      ref.invalidate(monthlyStatisticsProvider);
      ref.invalidate(defaultAccountProvider);
      ref.invalidate(allAccountsProvider);

      _quickAmountController.clear();
      setState(() => _selectedQuickCategory = null);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${CurrencyUtils.getCurrencySymbol(defaultCurrency)}$amountText from ${defaultAccount.name} → ${cat.name}',
            ),
            backgroundColor: cat.color,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
