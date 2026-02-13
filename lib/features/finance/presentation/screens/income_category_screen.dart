import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'recurring_income_detail_screen.dart';
import 'add_transaction_screen.dart';

/// Income Category Detail Screen
class IncomeCategoryScreen extends ConsumerStatefulWidget {
  final String categoryId;
  final String categoryName;
  final IconData categoryIcon;
  final Color categoryColor;

  const IncomeCategoryScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
    required this.categoryIcon,
    required this.categoryColor,
  });

  @override
  ConsumerState<IncomeCategoryScreen> createState() =>
      _IncomeCategoryScreenState();
}

class _IncomeCategoryScreenState extends ConsumerState<IncomeCategoryScreen> {
  ExpenseRangeView _selectedRangeView = ExpenseRangeView.month;
  DateTime _selectedDate = ExpenseRangeUtils.normalizeDate(DateTime.now());

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
                final filtered = _filterTransactions(transactions);
                return _buildScrollableContent(
                  isDark,
                  filtered,
                  defaultCurrency,
                );
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
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: widget.categoryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: widget.categoryColor.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  widget.categoryIcon,
                  color: widget.categoryColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.categoryName,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Income category',
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

  Widget _buildScrollableContent(
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

    // Get recurring incomes for this category
    final recurringIncomesAsync = ref.watch(recurringIncomesProvider);

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
                _buildSummaryCard(isDark, total, symbol, transactions.length),
                const SizedBox(height: 20),

                // Recurring Income Section - Show max 2, rest in scrollable list
                recurringIncomesAsync.when(
                  data: (allIncomes) {
                    final categoryIncomes = allIncomes
                        .where((i) => i.categoryId == widget.categoryId)
                        .toList();
                    if (categoryIncomes.isEmpty) return const SizedBox.shrink();

                    // Show only first 2 items to prevent overflow
                    final visibleIncomes = categoryIncomes.take(2).toList();
                    final moreCount =
                        categoryIncomes.length - visibleIncomes.length;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'RECURRING SOURCES',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Colors.blue,
                                letterSpacing: 1.5,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${categoryIncomes.length}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...visibleIncomes.map(
                          (income) =>
                              _buildRecurringIncomeCard(isDark, income, symbol),
                        ),
                        if (moreCount > 0) ...[
                          const SizedBox(height: 8),
                          Center(
                            child: Text(
                              '+$moreCount more source${moreCount == 1 ? '' : 's'}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),

                Text(
                  'TRANSACTIONS',
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
        if (transactions.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final tx = transactions[index];
                return _buildTransactionTile(isDark, tx, defaultCurrency);
              }, childCount: transactions.length),
            ),
          ),
      ],
    );
  }

  Widget _buildRecurringIncomeCard(
    bool isDark,
    RecurringIncome income,
    String symbol,
  ) {
    final nextOccurrence = income.nextOccurrenceAfter(DateTime.now());
    final isActive = income.isCurrentlyActive;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? Colors.blue.withOpacity(0.3)
              : (isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.03)),
          width: isActive ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  RecurringIncomeDetailScreen(recurringIncomeId: income.id),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.repeat_rounded,
                    color: Colors.blue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        income.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              income.frequencyLabel,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                          if (!isActive) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Inactive',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$symbol${income.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            if (nextOccurrence != null && isActive) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.event_rounded,
                      color: Colors.blue,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Next: ${DateFormat('MMM d, yyyy').format(nextOccurrence)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
                      ),
                    ),
                    if (income.autoCreateTransaction) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Auto',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4CAF50),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRangeSelector(bool isDark) {
    return Container(
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
            color: isSelected ? widget.categoryColor : Colors.transparent,
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

  Widget _buildSummaryCard(
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
            widget.categoryColor.withOpacity(isDark ? 0.15 : 0.1),
            widget.categoryColor.withOpacity(isDark ? 0.05 : 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: widget.categoryColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TOTAL EARNED',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: widget.categoryColor,
                  letterSpacing: 1.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: widget.categoryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count transactions',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: widget.categoryColor,
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

  Widget _buildTransactionTile(
    bool isDark,
    Transaction tx,
    String defaultCurrency,
  ) {
    final symbol = CurrencyUtils.getCurrencySymbol(
      tx.currency ?? defaultCurrency,
    );
    return Dismissible(
      key: Key(tx.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        child: const Icon(
          Icons.delete_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
      confirmDismiss: (direction) => _confirmDeleteTransaction(tx),
      onDismissed: (direction) => _deleteTransaction(tx),
      child: GestureDetector(
        onTap: () => _editTransaction(tx),
        child: Container(
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
                  color: widget.categoryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  widget.categoryIcon,
                  color: widget.categoryColor,
                  size: 20,
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
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('MMM d, yyyy • h:mm a').format(tx.transactionDate),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '+$symbol${tx.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: widget.categoryColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Icon(
                    Icons.edit_rounded,
                    size: 14,
                    color: isDark ? Colors.white24 : Colors.black26,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirmDeleteTransaction(Transaction tx) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1D1E33)
            : Colors.white,
        title: Text(
          'Delete Transaction',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black87,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${tx.title}"?\n\nThis action cannot be undone.',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white70
                : Colors.black54,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Colors.black54,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTransaction(Transaction tx) async {
    final repo = ref.read(transactionRepositoryProvider);
    await repo.deleteTransaction(tx.id);
    ref.invalidate(allTransactionsProvider);
    ref.invalidate(transactionsForDateProvider(
      ExpenseRangeUtils.normalizeDate(tx.transactionDate),
    ));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${tx.title} deleted'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _editTransaction(Transaction tx) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddTransactionScreen(
          transaction: tx,
          initialType: 'income',
        ),
      ),
    ).then((_) {
      ref.invalidate(allTransactionsProvider);
      ref.invalidate(transactionsForDateProvider(
        ExpenseRangeUtils.normalizeDate(tx.transactionDate),
      ));
    });
  }

  List<Transaction> _filterTransactions(List<Transaction> transactions) {
    final range = _currentRange();
    return transactions.where((tx) {
      if (tx.type != 'income' || tx.categoryId != widget.categoryId) {
        return false;
      }
      final txDate = ExpenseRangeUtils.normalizeDate(tx.transactionDate);
      return !txDate.isBefore(range.start) && !txDate.isAfter(range.end);
    }).toList()..sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
  }

  ExpenseRange _currentRange() =>
      ExpenseRangeUtils.rangeFor(_selectedDate, _selectedRangeView);
}
