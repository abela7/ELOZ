import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import '../../../../core/theme/dark_gradient.dart';
import '../../../../core/widgets/date_navigator_widget.dart';
import '../../data/models/transaction.dart';
import '../../data/models/transaction_category.dart';
import '../../data/models/recurring_income.dart';
import '../../data/models/account.dart';
import '../../data/services/finance_settings_service.dart';
import '../../utils/currency_utils.dart';
import '../../utils/expense_range_utils.dart';
import '../providers/finance_providers.dart';
import '../providers/income_providers.dart';
import 'add_transaction_screen.dart';
import 'income_category_screen.dart';
import 'income_report_screen.dart';
import 'recurring_income_screen.dart';
import 'transaction_categories_screen.dart';

// Income categories are now dynamic - loaded from TransactionCategoryRepository via incomeTransactionCategoriesProvider

/// Income Screen - Central hub for income management
class IncomeScreen extends ConsumerStatefulWidget {
  const IncomeScreen({super.key});

  @override
  ConsumerState<IncomeScreen> createState() => _IncomeScreenState();
}

class _IncomeScreenState extends ConsumerState<IncomeScreen> {
  final _quickAmountController = TextEditingController();
  String? _selectedQuickCategory;
  DateTime _selectedDate = ExpenseRangeUtils.normalizeDate(DateTime.now());
  ExpenseRangeView _selectedRangeView = ExpenseRangeView.day;
  bool _isDailyBreakdownExpanded = false;
  bool _isRecurringIncomeExpanded = true;

  @override
  void dispose() {
    _quickAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final transactionsAsync = ref.watch(allTransactionsProvider);
    final defaultCurrencyAsync = ref.watch(defaultCurrencyProvider);
    final defaultCurrency =
        defaultCurrencyAsync.value ?? FinanceSettingsService.fallbackCurrency;

    final content = _buildContent(
      context,
      isDark,
      transactionsAsync,
      defaultCurrency,
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
    String defaultCurrency,
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

                // Recurring Income Summary
                Consumer(
                  builder: (context, ref, child) {
                    final recurringAsync = ref.watch(currentlyActiveRecurringIncomesProvider);
                    return recurringAsync.when(
                      data: (incomes) => incomes.isEmpty
                          ? const SizedBox.shrink()
                          : _buildRecurringIncomeSummary(isDark, incomes, defaultCurrency),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // Quick Add Section - uses dynamic categories
                Consumer(
                  builder: (context, ref, child) {
                    final categoriesAsync = ref.watch(incomeTransactionCategoriesProvider);
                    return categoriesAsync.when(
                      data: (categories) => categories.isEmpty
                          ? const SizedBox.shrink()
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildQuickAddSection(isDark, defaultCurrency, categories),
                                const SizedBox(height: 28),
                                const Text(
                                  'INCOME CATEGORIES',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF4CAF50),
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                            ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    );
                  },
                ),

                // Income Categories Grid
                Consumer(
                  builder: (context, ref, child) {
                    final categoriesAsync = ref.watch(incomeTransactionCategoriesProvider);
                    final recurringAsync = ref.watch(currentlyActiveRecurringIncomesProvider);
                    
                    return categoriesAsync.when(
                      data: (categories) => transactionsAsync.when(
                        data: (transactions) => recurringAsync.when(
                          data: (recurringIncomes) => _buildCategoriesGrid(
                            isDark,
                            _selectedIncomeTransactions(transactions),
                            defaultCurrency,
                            categories,
                            recurringIncomes,
                          ),
                          loading: () => _buildCategoriesGrid(
                            isDark,
                            _selectedIncomeTransactions(transactions),
                            defaultCurrency,
                            categories,
                            [],
                          ),
                          error: (_, __) => _buildCategoriesGrid(
                            isDark,
                            _selectedIncomeTransactions(transactions),
                            defaultCurrency,
                            categories,
                            [],
                          ),
                        ),
                        loading: () => _buildCategoriesGridSkeleton(isDark),
                        error: (error, stackTrace) =>
                            _buildCategoriesGrid(isDark, [], defaultCurrency, categories, []),
                      ),
                      loading: () => _buildCategoriesGridSkeleton(isDark),
                      error: (_, __) => _buildCategoriesGridSkeleton(isDark),
                    );
                  },
                ),
                const SizedBox(height: 28),

                // All Income Transactions Section
                Consumer(
                  builder: (context, ref, child) {
                    final categoriesAsync = ref.watch(incomeTransactionCategoriesProvider);
                    return categoriesAsync.maybeWhen(
                      data: (categories) => categories.isEmpty
                          ? const SizedBox.shrink()
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'ALL INCOME TRANSACTIONS',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF4CAF50),
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                            ),
                      orElse: () => const SizedBox.shrink(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),

        // Transaction List
        Consumer(
          builder: (context, ref, child) {
            final categoriesAsync = ref.watch(incomeTransactionCategoriesProvider);
            final categories = categoriesAsync.valueOrNull ?? [];
            if (categories.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

            return transactionsAsync.when(
              data: (transactions) {
                final incomeTransactions = _selectedIncomeTransactions(transactions);
                if (incomeTransactions.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox_rounded,
                              size: 64,
                              color: isDark ? Colors.white12 : Colors.black12,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No income transactions',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add your first income to get started',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white24 : Colors.black26,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final tx = incomeTransactions[index];
                        return _buildTransactionTile(isDark, tx, defaultCurrency);
                      },
                      childCount: incomeTransactions.length,
                    ),
                  ),
                );
              },
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (_, __) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Text(
                      'Error loading transactions',
                      style: TextStyle(
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTransactionTile(
    bool isDark,
    Transaction tx,
    String defaultCurrency,
  ) {
    final symbol = CurrencyUtils.getCurrencySymbol(tx.currency ?? defaultCurrency);
    final categoryId = tx.categoryId ?? '';
    final accountId = tx.accountId ?? '';
    final category = categoryId.isNotEmpty
        ? ref.watch(transactionCategoryByIdProvider(categoryId))
        : null;
    
    Account? account;
    if (accountId.isNotEmpty) {
      final accountAsyncValue = ref.watch(accountByIdProvider(accountId));
      account = accountAsyncValue.valueOrNull;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
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
          // Category Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: (category?.color ?? const Color(0xFF4CAF50))
                  .withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              category?.icon ?? Icons.attach_money_rounded,
              color: category?.color ?? const Color(0xFF4CAF50),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          
          // Transaction Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Description / Title
                Text(
                  tx.description?.isEmpty ?? true ? 'Income' : tx.description!,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                
                // Category Name
                if (category != null)
                  Text(
                    category.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: category.color,
                    ),
                  ),
                const SizedBox(height: 2),
                
                // Date & Account Info
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 11,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('MMM d, yyyy').format(tx.transactionDate),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                    if (account != null) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 11,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          account.name,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          
          // Amount
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+$symbol${tx.amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF4CAF50),
                ),
              ),
              if (tx.currency != defaultCurrency)
                Text(
                  tx.currency ?? defaultCurrency,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(bool isDark, String defaultCurrency) {
    final topPadding = MediaQuery.of(context).padding.top;
    return SliverToBoxAdapter(
      child: Container(
        padding: EdgeInsets.fromLTRB(20, topPadding + 16, 20, 24),
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
                          Icons.category_rounded,
                          size: 20,
                          color: Colors.purple,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Recurring Income Button
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RecurringIncomeScreen(),
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
                          Icons.repeat_rounded,
                          size: 20,
                          color: Colors.blue,
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
                            builder: (context) => const IncomeReportScreen(),
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
                                AddTransactionScreen(initialType: 'income'),
                          ),
                        ).then((_) => ref.invalidate(allTransactionsProvider));
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFF4CAF50).withOpacity(0.2),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          size: 22,
                          color: Color(0xFF4CAF50),
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
                // Income Icon with gradient and outline
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF4CAF50), Color(0xFF388E3C)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.trending_up_rounded,
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
                        'Income',
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
                        'Track & manage earnings',
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

  List<Transaction> _selectedIncomeTransactions(
    List<Transaction> transactions,
  ) {
    return ExpenseRangeUtils.filterIncomesForRange(
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
            color: isSelected ? const Color(0xFF4CAF50) : Colors.transparent,
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
    final periodTransactions = _selectedIncomeTransactions(transactions);
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
                'SELECTED ${_selectedPeriodLabel()}',
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
                  '${periodTransactions.length} incomes',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4CAF50),
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
    final periodTransactions = _selectedIncomeTransactions(transactions);
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
                'Collapsed. Tap to view per-day income.',
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
                      ? const Color(0xFF4CAF50)
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
                  decoration: const BoxDecoration(color: Color(0xFF4CAF50)),
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

  Widget _buildQuickAddSection(bool isDark, String defaultCurrency, List<TransactionCategory> categories) {
    final symbol = CurrencyUtils.getCurrencySymbol(defaultCurrency);

    // Find the selected category from the dynamic list
    TransactionCategory? selectedCat;
    if (_selectedQuickCategory != null) {
      final matches = categories.where((c) => c.id == _selectedQuickCategory);
      selectedCat = matches.isNotEmpty ? matches.first : null;
    }

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
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final cat = categories[index];
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
                            cat.icon,
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
                      color: selectedCat?.color
                          ?? (isDark ? Colors.white38 : Colors.black38),
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
                onTap: () => _quickAddIncome(defaultCurrency),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: selectedCat != null
                          ? [
                              selectedCat.color,
                              selectedCat.color.withOpacity(0.8),
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

  Widget _buildRecurringIncomeSummary(
    bool isDark,
    List<RecurringIncome> incomes,
    String defaultCurrency,
  ) {
    final symbol = CurrencyUtils.getCurrencySymbol(defaultCurrency);
    final totalMonthly = incomes
        .where((i) => i.currency == defaultCurrency)
        .fold<double>(0.0, (sum, i) {
      switch (i.frequency) {
        case 'daily':
          return sum + (i.amount * 30);
        case 'weekly':
          return sum + (i.amount * 4.33);
        case 'biweekly':
          return sum + (i.amount * 2.17);
        case 'monthly':
          return sum + i.amount;
        case 'quarterly':
          return sum + (i.amount / 3);
        case 'yearly':
          return sum + (i.amount / 12);
        default:
          return sum + i.amount;
      }
    });

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.withOpacity(isDark ? 0.12 : 0.08),
            Colors.blue.withOpacity(isDark ? 0.04 : 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.blue.withOpacity(isDark ? 0.15 : 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header - always visible
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _isRecurringIncomeExpanded = !_isRecurringIncomeExpanded);
            },
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.repeat_rounded,
                      color: Colors.blue,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RECURRING INCOME',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Colors.blue,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$symbol${totalMonthly.toStringAsFixed(2)}/mo · ${incomes.length} source${incomes.length == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isRecurringIncomeExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Colors.blue,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),

          // Expandable content
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Monthly & Yearly estimates
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.03)
                                : Colors.white.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Monthly',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white38 : Colors.black38,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$symbol${totalMonthly.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.03)
                                : Colors.white.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Yearly',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white38 : Colors.black38,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$symbol${(totalMonthly * 12).toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // List of active recurring incomes
                  ...incomes.map((income) {
                    final cat = ref.watch(transactionCategoryByIdProvider(income.categoryId));
                    final nextOccurrence = income.nextOccurrenceAfter(DateTime.now());
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: (cat?.color ?? Colors.grey).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              cat?.icon ?? Icons.attach_money_rounded,
                              color: cat?.color ?? Colors.grey,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  income.title,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${income.frequencyLabel}${nextOccurrence != null ? ' · Next: ${nextOccurrence.day}/${nextOccurrence.month}' : ''}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.white38 : Colors.black38,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '$symbol${income.amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF4CAF50),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 8),
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RecurringIncomeScreen(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'View All',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            crossFadeState: _isRecurringIncomeExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesGrid(
    bool isDark,
    List<Transaction> transactions,
    String defaultCurrency,
    List<TransactionCategory> categories,
    List<RecurringIncome> recurringIncomes,
  ) {
    if (categories.isEmpty) {
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
                'No income categories yet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add categories to start tracking your income',
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
                  ref.invalidate(incomeTransactionCategoriesProvider);
                }),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Add Categories'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
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
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
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
        final earned = totalsByCurrency[displayCurrency] ?? 0.0;
        
        // Add recurring income monthly estimate for this category
        final categoryRecurring = recurringIncomes
            .where((i) => i.categoryId == cat.id && i.currency == displayCurrency)
            .toList();
        final recurringMonthlyEstimate = categoryRecurring.fold<double>(0.0, (sum, i) {
          switch (i.frequency) {
            case 'daily':
              return sum + (i.amount * 30);
            case 'weekly':
              return sum + (i.amount * 4.33);
            case 'biweekly':
              return sum + (i.amount * 2.17);
            case 'monthly':
              return sum + i.amount;
            case 'quarterly':
              return sum + (i.amount / 3);
            case 'yearly':
              return sum + (i.amount / 12);
            default:
              return sum + i.amount;
          }
        });
        
        final hasRecurring = categoryRecurring.isNotEmpty;
        final hasMultipleCurrencies = totalsByCurrency.length > 1;
        final symbol = CurrencyUtils.getCurrencySymbol(displayCurrency);
        final transactionCount = categoryTransactions.length;
        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => IncomeCategoryScreen(
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
                      child: Icon(cat.icon, color: cat.color, size: 22),
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
                if (hasRecurring) ...[
                  // Show recurring estimate prominently
                  Text(
                    '$symbol${recurringMonthlyEstimate.toStringAsFixed(2)}/mo',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Colors.blue,
                    ),
                  ),
                  if (earned > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Earned: $symbol${earned.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: cat.color,
                      ),
                    ),
                  ],
                ] else ...[
                  Text(
                    earned > 0
                        ? '$symbol${earned.toStringAsFixed(2)}'
                        : 'No income',
                    style: TextStyle(
                      fontSize: earned > 0 ? 14 : 11,
                      fontWeight: earned > 0 ? FontWeight.w900 : FontWeight.w500,
                      color: earned > 0
                          ? cat.color
                          : (isDark ? Colors.white24 : Colors.black26),
                    ),
                  ),
                ],
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

  Future<void> _quickAddIncome(String defaultCurrency) async {
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

    // Get category from dynamic categories provider
    final categoriesAsync = ref.read(incomeTransactionCategoriesProvider);
    final categories = categoriesAsync.valueOrNull ?? [];
    final catMatches = categories.where((c) => c.id == _selectedQuickCategory);
    if (catMatches.isEmpty) return;
    final cat = catMatches.first;

    final transaction = Transaction(
      title: cat.name,
      amount: amount,
      type: 'income',
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

      // Add to account balance
      defaultAccount.balance += amount;
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
              '${CurrencyUtils.getCurrencySymbol(defaultCurrency)}$amountText → ${defaultAccount.name} from ${cat.name}',
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
