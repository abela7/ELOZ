import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/dark_gradient.dart';
import '../../../../core/widgets/date_navigator_widget.dart';
import '../../finance_module.dart';
import '../../data/models/transaction.dart';
import '../../data/models/account.dart';
import '../providers/finance_providers.dart';
import '../../data/services/finance_settings_service.dart';
import '../../utils/currency_utils.dart';
import 'finance_settings_screen.dart';
import 'accounts_screen.dart';
import 'add_transaction_screen.dart';
import 'add_bill_screen.dart';
import 'add_recurring_income_screen.dart';
import 'budgets_screen.dart';
import 'debts_screen.dart';
import 'expenses_screen.dart';
import 'income_screen.dart';
import 'lending_screen.dart';
import 'savings_goals_screen.dart';

enum _BalanceFlowRange { day, week, month, year, custom }

/// Finances Screen - Finance Mini-App Dashboard
class FinancesScreen extends ConsumerStatefulWidget {
  const FinancesScreen({super.key});

  @override
  ConsumerState<FinancesScreen> createState() => _FinancesScreenState();
}

class _FinancesScreenState extends ConsumerState<FinancesScreen> {
  static const Duration _openTimeout = Duration(seconds: 12);

  // Initialize to midnight today for consistent date filtering
  DateTime _selectedDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  bool _isSearching = false;
  bool _isSummaryExpanded = false; // Summary accordion state
  bool _isDailyTransactionsExpanded =
      true; // Daily transactions accordion state
  String _selectedFilter =
      'all'; // Filter: 'all', 'income', 'expense', 'transfer'

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showFab = false;

  /// Whether the security gate has been passed for this screen instance.
  bool _authenticated = false;
  bool _authCheckDone = false;
  String? _startupError;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openFinance());
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final atBottom = pos.pixels >= pos.maxScrollExtent - 80 || pos.maxScrollExtent <= 0;
    if (_showFab != atBottom && mounted) {
      setState(() => _showFab = atBottom);
    }
  }

  Future<void> _openFinance() async {
    if (mounted) {
      setState(() {
        _startupError = null;
        _authCheckDone = false;
        _authenticated = false;
      });
    }

    try {
      await FinanceModule.init(
        deferRecurringProcessing: true,
        preOpenBoxes: true,
        bootstrapDefaults: true,
      ).timeout(_openTimeout);

      if (!mounted) return;
      await _checkAccess();
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _startupError = 'Finance took too long to initialize. Please retry.';
        _authCheckDone = true;
        _authenticated = false;
      });
    } catch (e) {
      debugPrint('Finance open failed: $e');
      if (!mounted) return;
      setState(() {
        _startupError = 'Could not initialize Finance securely. Please retry.';
        _authCheckDone = true;
        _authenticated = false;
      });
    }
  }

  Future<void> _checkAccess() async {
    final guard = ref.read(financeAccessGuardProvider);

    try {
      // If already unlocked from a previous session, skip the dialog.
      if (guard.isSessionUnlocked) {
        if (mounted) {
          setState(() {
            _authenticated = true;
            _authCheckDone = true;
          });
        }
        return;
      }

      final ok = await guard.ensureAccess(context);
      if (!mounted) return;

      if (ok) {
        setState(() {
          _authenticated = true;
          _authCheckDone = true;
        });
      } else {
        setState(() {
          _authenticated = false;
          _authCheckDone = true;
        });
        // Pop back if the user cancelled or was denied.
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      debugPrint('Finance unlock failed: $e');
      if (!mounted) return;
      setState(() {
        _startupError = 'Finance unlock failed. Please retry.';
        _authenticated = false;
        _authCheckDone = true;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Show nothing until auth check completes.
    if (!_authCheckDone) {
      return Scaffold(
        body: isDark
            ? DarkGradient.wrap(
                child: const Center(child: CircularProgressIndicator()),
              )
            : const Center(child: CircularProgressIndicator()),
      );
    }

    if (_startupError != null) {
      return Scaffold(
        body: isDark
            ? DarkGradient.wrap(
                child: _buildStartupErrorState(context, isDark, _startupError!),
              )
            : _buildStartupErrorState(context, isDark, _startupError!),
      );
    }

    // If authentication failed, keep a secure locked state.
    if (!_authenticated) {
      return Scaffold(
        body: isDark
            ? DarkGradient.wrap(child: _buildLockedState(context, isDark))
            : _buildLockedState(context, isDark),
      );
    }

    // Normalize date to midnight for provider key
    final normalizedDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final transactionsAsync = ref.watch(
      transactionsForDateProvider(normalizedDate),
    );

    return Scaffold(
      body: isDark
          ? DarkGradient.wrap(
              child: _buildContent(context, isDark, transactionsAsync),
            )
          : _buildContent(context, isDark, transactionsAsync),
    );
  }

  Widget _buildContent(
    BuildContext context,
    bool isDark,
    AsyncValue<List<Transaction>> transactionsAsync,
  ) {
    return Scaffold(
      backgroundColor: isDark ? Colors.transparent : const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: isDark ? Colors.white : Colors.black,
                ),
                decoration: InputDecoration(
                  hintText: 'Search transactions...',
                  hintStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() {});
                },
              )
            : const Text('Finance'),
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchController.clear();
                });
              },
              tooltip: 'Close Search',
            )
          else
            IconButton(
              icon: const Icon(Icons.search_rounded),
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
              tooltip: 'Search Transactions',
            ),
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.add_rounded),
              onPressed: () {
                _showAddTransactionPlaceholder(context);
              },
              tooltip: 'New Transaction',
            ),
        ],
      ),
      body: SafeArea(
        child: transactionsAsync.when(
          data: (transactions) {
            if (_isSearching && _searchController.text.isNotEmpty) {
              return _buildSearchResults(context, isDark, transactions);
            }
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _scrollController.hasClients) _onScroll();
            });
            return _buildFinanceContent(context, isDark, transactions);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => _buildLoadErrorState(
            context,
            isDark,
            'Error loading transactions: $error',
          ),
        ),
      ),
      floatingActionButton: _showFab && !_isSearching
          ? FloatingActionButton.extended(
              onPressed: () => _showFinanceActionSheet(context, isDark),
              backgroundColor: const Color(0xFFCDAF56),
              foregroundColor: const Color(0xFF1E1E1E),
              icon: const Icon(Icons.apps_rounded),
              label: const Text('Add'),
            )
          : null,
    );
  }

  Widget _buildStartupErrorState(
    BuildContext context,
    bool isDark,
    String message,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 44,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: isDark ? Colors.white70 : Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _openFinance,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLockedState(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 44,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            const SizedBox(height: 12),
            Text(
              'Finance is locked.',
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white70 : Colors.black54,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _openFinance,
              icon: const Icon(Icons.lock_open_rounded),
              label: const Text('Unlock'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadErrorState(
    BuildContext context,
    bool isDark,
    String message,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                final date = DateTime(
                  _selectedDate.year,
                  _selectedDate.month,
                  _selectedDate.day,
                );
                ref.invalidate(transactionsForDateProvider(date));
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(
    BuildContext context,
    bool isDark,
    List<Transaction> transactions,
  ) {
    final searchQuery = _searchController.text.toLowerCase();
    final filteredTransactions = transactions
        .where(
          (t) =>
              t.title.toLowerCase().contains(searchQuery) ||
              (t.description?.toLowerCase().contains(searchQuery) ?? false),
        )
        .toList();

    if (filteredTransactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: isDark ? Colors.white10 : Colors.grey[200],
            ),
            const SizedBox(height: 16),
            Text(
              'No transactions match your search',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 100),
      itemCount: filteredTransactions.length,
      itemBuilder: (context, index) {
        final transaction = filteredTransactions[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _TransactionCard(
            transaction: transaction,
            isDark: isDark,
            onTap: () {
              _showTransactionDetailPlaceholder(context, transaction);
            },
          ),
        );
      },
    );
  }

  Widget _buildFinanceContent(
    BuildContext context,
    bool isDark,
    List<Transaction> transactions,
  ) {
    final defaultCurrencyAsync = ref.watch(defaultCurrencyProvider);
    final defaultCurrency =
        defaultCurrencyAsync.value ?? FinanceSettingsService.fallbackCurrency;
    final monthlyStatsAsync = ref.watch(monthlyStatisticsProvider);
    final totalBalanceAsync = ref.watch(
      dailyTotalBalanceProvider(_selectedDate),
    );

    // Calculate statistics for selected date
    final allTransactions = transactions.length;
    final incomeTransactions = transactions
        .where((t) => t.isIncome && !t.isBalanceAdjustment)
        .length;
    final expenseTransactions = transactions
        .where((t) => t.isExpense && !t.isBalanceAdjustment)
        .length;
    final transferTransactions = transactions.where((t) => t.isTransfer).length;

    // Group income/expense by currency to avoid mixing currencies
    final Map<String, double> totalIncomeByCurrency = {};
    final Map<String, double> totalExpenseByCurrency = {};

    for (final t in transactions.where(
      (t) => t.isIncome && !t.isBalanceAdjustment,
    )) {
      final currency = t.currency ?? defaultCurrency;
      totalIncomeByCurrency[currency] =
          (totalIncomeByCurrency[currency] ?? 0) + t.amount;
    }

    for (final t in transactions.where(
      (t) => t.isExpense && !t.isBalanceAdjustment,
    )) {
      final currency = t.currency ?? defaultCurrency;
      totalExpenseByCurrency[currency] =
          (totalExpenseByCurrency[currency] ?? 0) + t.amount;
    }

    // For display, use primary currency (first currency found, or ETB)
    final primaryCurrency = transactions.isNotEmpty
        ? (transactions.first.currency ?? defaultCurrency)
        : defaultCurrency;
    final totalIncome = totalIncomeByCurrency[primaryCurrency] ?? 0.0;
    final totalExpense = totalExpenseByCurrency[primaryCurrency] ?? 0.0;

    // Filter transactions based on selected filter
    final displayTransactions =
        (() {
          switch (_selectedFilter) {
            case 'income':
              return transactions
                  .where((t) => t.isIncome && !t.isBalanceAdjustment)
                  .toList();
            case 'expense':
              return transactions
                  .where((t) => t.isExpense && !t.isBalanceAdjustment)
                  .toList();
            case 'transfer':
              return transactions.where((t) => t.isTransfer).toList();
            case 'all':
            default:
              return transactions;
          }
        })()..sort((a, b) {
          // First sort by date
          int dateCompare = b.transactionDate.compareTo(a.transactionDate);
          if (dateCompare != 0) return dateCompare;

          // If same date, sort by time
          final timeA = a.transactionTimeHour ?? 0;
          final timeB = b.transactionTimeHour ?? 0;
          if (timeB != timeA) return timeB.compareTo(timeA);

          final minA = a.transactionTimeMinute ?? 0;
          final minB = b.transactionTimeMinute ?? 0;
          return minB.compareTo(minA);
        });

    // Wrap content in GestureDetector for swipe navigation
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity == null) return;

        // Swipe Right (velocity > 0) → Go to Yesterday
        if (details.primaryVelocity! > 500) {
          HapticFeedback.selectionClick();
          setState(() {
            final prevDay = _selectedDate.subtract(const Duration(days: 1));
            _selectedDate = DateTime(prevDay.year, prevDay.month, prevDay.day);
          });
        }
        // Swipe Left (velocity < -500) → Go to Tomorrow
        else if (details.primaryVelocity! < -500) {
          HapticFeedback.selectionClick();
          setState(() {
            final nextDay = _selectedDate.add(const Duration(days: 1));
            _selectedDate = DateTime(nextDay.year, nextDay.month, nextDay.day);
          });
        }
      },
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          // Date Navigator Widget
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: DateNavigatorWidget(
              selectedDate: _selectedDate,
              onDateChanged: (newDate) {
                setState(() {
                  // Always normalize to midnight
                  _selectedDate = DateTime(
                    newDate.year,
                    newDate.month,
                    newDate.day,
                  );
                });
              },
            ),
          ),

          const SizedBox(height: 16),

          // Total Balance Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GestureDetector(
              onTap: () =>
                  _showBalanceBreakdown(context, isDark, defaultCurrency),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isDark
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Balance',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: isDark ? Colors.white24 : Colors.black26,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDateLabel(_selectedDate),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white30 : Colors.black26,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    totalBalanceAsync.when(
                      data: (balances) {
                        if (balances.isEmpty) {
                          return Text(
                            '${CurrencyUtils.getCurrencySymbol(defaultCurrency)}0.00',
                            style: Theme.of(context).textTheme.displaySmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1E1E1E),
                                ),
                          );
                        }

                        // For simplicity in the main card, show the default currency if present
                        final primaryCurrency =
                            balances.containsKey(defaultCurrency)
                            ? defaultCurrency
                            : balances.keys.first;
                        final balance = balances[primaryCurrency]!;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${CurrencyUtils.getCurrencySymbol(primaryCurrency)}${balance.toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.displaySmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: balance >= 0
                                        ? (isDark
                                              ? Colors.white
                                              : const Color(0xFF1E1E1E))
                                        : Colors.red,
                                  ),
                            ),
                            if (balances.length > 1) ...[
                              const SizedBox(height: 8),
                              ...balances.entries
                                  .where((e) => e.key != primaryCurrency)
                                  .map(
                                    (e) => Text(
                                      '${CurrencyUtils.getCurrencySymbol(e.key)}${e.value.toStringAsFixed(2)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? Colors.white70
                                                : Colors.grey[700],
                                          ),
                                    ),
                                  ),
                            ],
                          ],
                        );
                      },
                      loading: () => const CircularProgressIndicator(),
                      error: (error, stack) => Text('Error: $error'),
                    ),
                    const SizedBox(height: 16),
                    // Income/Expense/Debt summary
                    monthlyStatsAsync.when(
                      data: (stats) {
                        final incomeByCurrency =
                            stats['totalIncomeByCurrency']
                                as Map<String, double>? ??
                            {};
                        final expenseByCurrency =
                            stats['totalExpenseByCurrency']
                                as Map<String, double>? ??
                            {};

                        // Get primary currency for summary chips (default or first available)
                        String primaryCur = defaultCurrency;
                        if (incomeByCurrency.isNotEmpty)
                          primaryCur = incomeByCurrency.keys.first;
                        else if (expenseByCurrency.isNotEmpty)
                          primaryCur = expenseByCurrency.keys.first;

                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _SummaryChip(
                                    label: 'Income',
                                    amount: incomeByCurrency[primaryCur] ?? 0.0,
                                    currency: primaryCur,
                                    icon: Icons.arrow_downward_rounded,
                                    color: Colors.green,
                                    isDark: isDark,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _SummaryChip(
                                    label: 'Expense',
                                    amount:
                                        expenseByCurrency[primaryCur] ?? 0.0,
                                    currency: primaryCur,
                                    icon: Icons.arrow_upward_rounded,
                                    color: Colors.red,
                                    isDark: isDark,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Debt summary row
                            Consumer(
                              builder: (context, ref, _) {
                                final debtAsync = ref.watch(
                                  totalDebtByCurrencyForDateProvider(
                                    DateTime(
                                      _selectedDate.year,
                                      _selectedDate.month,
                                      _selectedDate.day,
                                    ),
                                  ),
                                );
                                return debtAsync.when(
                                  data: (debts) {
                                    if (debts.isEmpty)
                                      return const SizedBox.shrink();
                                    final debtAmount = debts[primaryCur] ?? 0.0;
                                    if (debtAmount == 0)
                                      return const SizedBox.shrink();
                                    return GestureDetector(
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const DebtsScreen(),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.white.withOpacity(0.03)
                                              : Colors.red.withOpacity(0.03),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(5),
                                              decoration: BoxDecoration(
                                                color: Colors.red.withOpacity(
                                                  0.08,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Icon(
                                                Icons.account_balance_rounded,
                                                size: 14,
                                                color: Colors.red.shade400,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              'Total Debt',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: isDark
                                                    ? Colors.white54
                                                    : Colors.black45,
                                              ),
                                            ),
                                            const Spacer(),
                                            Text(
                                              '${CurrencyUtils.getCurrencySymbol(primaryCur)}${debtAmount.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.red.shade400,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Icon(
                                              Icons.chevron_right_rounded,
                                              size: 16,
                                              color: isDark
                                                  ? Colors.white24
                                                  : Colors.black26,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                  loading: () => const SizedBox.shrink(),
                                  error: (_, __) => const SizedBox.shrink(),
                                );
                              },
                            ),

                            // Monthly Bills/Subscriptions Expenses Card
                            const SizedBox(height: 12),
                            Consumer(
                              builder: (context, ref, _) {
                                final billSummaryAsync = ref.watch(
                                  billSummaryProvider,
                                );

                                return billSummaryAsync.when(
                                  data: (summary) {
                                    final monthlyTotals =
                                        summary['monthlyTotals']
                                            as Map<String, double>?;

                                    // Calculate total across all currencies (or just show primary)
                                    double totalExpense = 0.0;
                                    String expenseCurrency = primaryCur;

                                    if (monthlyTotals != null &&
                                        monthlyTotals.isNotEmpty) {
                                      // Use primary currency if available, otherwise first currency
                                      if (monthlyTotals.containsKey(
                                        primaryCur,
                                      )) {
                                        totalExpense =
                                            monthlyTotals[primaryCur]!;
                                      } else {
                                        expenseCurrency =
                                            monthlyTotals.keys.first;
                                        totalExpense =
                                            monthlyTotals.values.first;
                                      }
                                    }

                                    return GestureDetector(
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const ExpensesScreen(),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.white.withOpacity(0.03)
                                              : const Color(
                                                  0xFFCDAF56,
                                                ).withOpacity(0.03),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(5),
                                              decoration: BoxDecoration(
                                                color: const Color(
                                                  0xFFCDAF56,
                                                ).withOpacity(0.08),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: const Icon(
                                                Icons.receipt_long_rounded,
                                                size: 14,
                                                color: Color(0xFFCDAF56),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Flexible(
                                              child: Text(
                                                'Monthly Expenses',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: isDark
                                                      ? Colors.white54
                                                      : Colors.black45,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              '${CurrencyUtils.getCurrencySymbol(expenseCurrency)}${totalExpense.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: isDark
                                                    ? Colors.white70
                                                    : Colors.black54,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Icon(
                                              Icons.chevron_right_rounded,
                                              size: 16,
                                              color: isDark
                                                  ? Colors.white24
                                                  : Colors.black26,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                  loading: () => const SizedBox.shrink(),
                                  error: (_, __) => const SizedBox.shrink(),
                                );
                              },
                            ),
                          ],
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Overview Stats Section - 2x2 Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _StatCard(
                  label: 'All',
                  value: allTransactions.toString(),
                  icon: Icons.receipt_long_rounded,
                  accentColor: const Color(0xFFCDAF56), // Gold
                  isDark: isDark,
                  isSelected: _selectedFilter == 'all',
                  onTap: () {
                    setState(() {
                      _selectedFilter = 'all';
                    });
                  },
                ),
                _StatCard(
                  label: 'Income',
                  value: incomeTransactions.toString(),
                  icon: Icons.arrow_downward_rounded,
                  accentColor: const Color(0xFF4CAF50), // Green
                  isDark: isDark,
                  isSelected: _selectedFilter == 'income',
                  onTap: () {
                    setState(() {
                      _selectedFilter = 'income';
                    });
                  },
                ),
                _StatCard(
                  label: 'Expense',
                  value: expenseTransactions.toString(),
                  icon: Icons.arrow_upward_rounded,
                  accentColor: const Color(0xFFEF5350), // Red
                  isDark: isDark,
                  isSelected: _selectedFilter == 'expense',
                  onTap: () {
                    setState(() {
                      _selectedFilter = 'expense';
                    });
                  },
                ),
                _StatCard(
                  label: 'Transfer',
                  value: transferTransactions.toString(),
                  icon: Icons.swap_horiz_rounded,
                  accentColor: const Color(0xFF42A5F5), // Blue
                  isDark: isDark,
                  isSelected: _selectedFilter == 'transfer',
                  onTap: () {
                    setState(() {
                      _selectedFilter = 'transfer';
                    });
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Transactions for the Day Section - Accordion
          if (displayTransactions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _DailyTransactionsAccordion(
                transactions: displayTransactions,
                isDark: isDark,
                isExpanded: _isDailyTransactionsExpanded,
                selectedFilter: _selectedFilter,
                onExpansionChanged: (expanded) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _isDailyTransactionsExpanded = expanded;
                  });
                },
                onTransactionTap: (transaction) {
                  _showTransactionDetailPlaceholder(context, transaction);
                },
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isDark
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Center(
                  child: Text(
                    _selectedFilter == 'all'
                        ? 'No transactions for this day'
                        : 'No $_selectedFilter transactions found',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isDark
                          ? const Color(0xFFBDBDBD)
                          : const Color(0xFF6E6E6E),
                    ),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 16),

          // Daily Summary Card - Enhanced Accordion
          if (totalIncome > 0 || totalExpense > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isDark
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                ),
                child: Column(
                  children: [
                    InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(
                          () => _isSummaryExpanded = !_isSummaryExpanded,
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Today's Summary",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF1E1E1E),
                                    ),
                                  ),
                                  if (!_isSummaryExpanded)
                                    Text(
                                      'Net: ${CurrencyUtils.getCurrencySymbol(primaryCurrency)}${(totalIncome - totalExpense).toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: (totalIncome - totalExpense) >= 0
                                            ? Colors.green.shade400
                                            : Colors.red.shade400,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            AnimatedRotation(
                              turns: _isSummaryExpanded ? 0.5 : 0,
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 20,
                                color: isDark ? Colors.white38 : Colors.black26,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_isSummaryExpanded)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        child: Column(
                          children: [
                            const Divider(height: 1, thickness: 1),
                            const SizedBox(height: 20),
                            _buildSummaryRow(
                              'Income',
                              totalIncome,
                              primaryCurrency,
                              Colors.green,
                              Icons.arrow_downward_rounded,
                              isDark,
                            ),
                            const SizedBox(height: 12),
                            _buildSummaryRow(
                              'Expense',
                              totalExpense,
                              primaryCurrency,
                              Colors.red,
                              Icons.arrow_upward_rounded,
                              isDark,
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Divider(height: 1, thickness: 1),
                            ),
                            _buildSummaryRow(
                              'Net Cash Flow',
                              totalIncome - totalExpense,
                              primaryCurrency,
                              (totalIncome - totalExpense) >= 0
                                  ? Colors.green
                                  : Colors.red,
                              Icons.account_balance_wallet_rounded,
                              isDark,
                              isBold: true,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),

          // Quick Actions Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Actions',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFFFFFFFF)
                        : const Color(0xFF1E1E1E),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _QuickActionButton(
                        icon: Icons.add_rounded,
                        label: 'Add Transaction',
                        isDark: isDark,
                        onTap: () {
                          _showAddTransactionPlaceholder(context);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickActionButton(
                        icon: Icons.account_balance_wallet_rounded,
                        label: 'Accounts',
                        isDark: isDark,
                        onTap: () {
                          _showAccountsPlaceholder(context);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _QuickActionButton(
                        icon: Icons.trending_down_rounded,
                        label: 'Expenses',
                        isDark: isDark,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const ExpensesScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickActionButton(
                        icon: Icons.trending_up_rounded,
                        label: 'Income',
                        isDark: isDark,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const IncomeScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _QuickActionButton(
                        icon: Icons.pie_chart_rounded,
                        label: 'Budgets',
                        isDark: isDark,
                        onTap: () {
                          _showBudgetsPlaceholder(context);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickActionButton(
                        icon: Icons.account_balance_rounded,
                        label: 'Debts',
                        isDark: isDark,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const DebtsScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _QuickActionButton(
                        icon: Icons.handshake_rounded,
                        label: 'Lending',
                        isDark: isDark,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const LendingScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickActionButton(
                        icon: Icons.savings_rounded,
                        label: 'Savings',
                        isDark: isDark,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const SavingsGoalsScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _QuickActionButton(
                        icon: Icons.settings_rounded,
                        label: 'Settings',
                        isDark: isDark,
                        onTap: () {
                          _showSettingsPlaceholder(context);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Finance Report Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Material(
              color: const Color(0xFFCDAF56).withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showReportPlaceholder(context);
                },
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.assessment_rounded,
                        color: Color(0xFFCDAF56),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Finance Report',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Color(0xFFCDAF56),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Opens a bottom sheet with quick actions: add expense, income, payment, etc.
  void _showFinanceActionSheet(BuildContext context, bool isDark) {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D24) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(sheetContext),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: _FinanceActionGrid(
                  isDark: isDark,
                  navigatorContext: context,
                  onClose: () => Navigator.pop(sheetContext),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Placeholder functions for screens to be built
  void _showAddTransactionPlaceholder(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const AddTransactionScreen()),
    );
  }

  void _showTransactionDetailPlaceholder(
    BuildContext context,
    Transaction transaction,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TransactionDetailModal(transaction: transaction),
    );
  }

  void _showAccountsPlaceholder(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const AccountsScreen()));
  }

  void _showBudgetsPlaceholder(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const BudgetsScreen()));
  }

  void _showSettingsPlaceholder(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const FinanceSettingsScreen()),
    );
  }

  void _showReportPlaceholder(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Finance Report screen - Build this next!'),
        backgroundColor: Color(0xFFCDAF56),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    double amount,
    String currency,
    Color color,
    IconData icon,
    bool isDark, {
    bool isBold = false,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ),
        Text(
          '$currency ${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 15,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
            color: color,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }

  void _showBalanceBreakdown(
    BuildContext context,
    bool isDark,
    String defaultCurrency,
  ) {
    HapticFeedback.mediumImpact();
    var rangeType = _BalanceFlowRange.month;
    var focusDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    var customStart = DateTime(focusDate.year, focusDate.month, 1);
    var customEnd = DateTime(focusDate.year, focusDate.month + 1, 0);
    var selectedCurrency = defaultCurrency;

    DateTime normalizeDate(DateTime date) =>
        DateTime(date.year, date.month, date.day);

    DateTime startOfWeek(DateTime date) {
      final normalized = normalizeDate(date);
      return normalized.subtract(Duration(days: normalized.weekday - 1));
    }

    DateTime endOfWeek(DateTime date) {
      return startOfWeek(date).add(const Duration(days: 6));
    }

    DateTime shiftMonths(DateTime date, int delta) {
      final monthIndex = (date.month - 1) + delta;
      final year = date.year + (monthIndex ~/ 12);
      final month = (monthIndex % 12) + 1;
      final maxDay = DateTime(year, month + 1, 0).day;
      return DateTime(year, month, date.day > maxDay ? maxDay : date.day);
    }

    DateTime shiftYears(DateTime date, int delta) {
      final year = date.year + delta;
      final maxDay = DateTime(year, date.month + 1, 0).day;
      return DateTime(year, date.month, date.day > maxDay ? maxDay : date.day);
    }

    MapEntry<DateTime, DateTime> currentRange() {
      switch (rangeType) {
        case _BalanceFlowRange.day:
          final day = normalizeDate(focusDate);
          return MapEntry(day, day);
        case _BalanceFlowRange.week:
          return MapEntry(startOfWeek(focusDate), endOfWeek(focusDate));
        case _BalanceFlowRange.month:
          return MapEntry(
            DateTime(focusDate.year, focusDate.month, 1),
            DateTime(focusDate.year, focusDate.month + 1, 0),
          );
        case _BalanceFlowRange.year:
          return MapEntry(
            DateTime(focusDate.year, 1, 1),
            DateTime(focusDate.year, 12, 31),
          );
        case _BalanceFlowRange.custom:
          final start = normalizeDate(customStart);
          final end = normalizeDate(customEnd);
          if (end.isBefore(start)) return MapEntry(end, start);
          return MapEntry(start, end);
      }
    }

    String rangeLabel(_BalanceFlowRange range) {
      switch (range) {
        case _BalanceFlowRange.day:
          return 'Day';
        case _BalanceFlowRange.week:
          return 'Week';
        case _BalanceFlowRange.month:
          return 'Month';
        case _BalanceFlowRange.year:
          return 'Year';
        case _BalanceFlowRange.custom:
          return 'Custom';
      }
    }

    String flowHeading(_BalanceFlowRange range) {
      switch (range) {
        case _BalanceFlowRange.day:
          return 'THIS DAY\'S FLOW';
        case _BalanceFlowRange.week:
          return 'THIS WEEK\'S FLOW';
        case _BalanceFlowRange.month:
          return 'THIS MONTH\'S FLOW';
        case _BalanceFlowRange.year:
          return 'THIS YEAR\'S FLOW';
        case _BalanceFlowRange.custom:
          return 'CUSTOM FLOW';
      }
    }

    String formatRange(DateTime start, DateTime end) {
      if (start.year == end.year &&
          start.month == end.month &&
          start.day == end.day) {
        return DateFormat('EEE, MMM d, yyyy').format(start);
      }
      if (start.year == end.year && start.month == end.month) {
        return '${DateFormat('MMM d').format(start)} - ${DateFormat('d, yyyy').format(end)}';
      }
      return '${DateFormat('MMM d, yyyy').format(start)} - ${DateFormat('MMM d, yyyy').format(end)}';
    }

    DateTime shiftedFocus(DateTime source, int direction) {
      switch (rangeType) {
        case _BalanceFlowRange.day:
          return source.add(Duration(days: direction));
        case _BalanceFlowRange.week:
          return source.add(Duration(days: 7 * direction));
        case _BalanceFlowRange.month:
          return shiftMonths(source, direction);
        case _BalanceFlowRange.year:
          return shiftYears(source, direction);
        case _BalanceFlowRange.custom:
          return source;
      }
    }

    String focusLabel() {
      switch (rangeType) {
        case _BalanceFlowRange.day:
          return DateFormat('EEE, MMM d, yyyy').format(focusDate);
        case _BalanceFlowRange.week:
          return formatRange(startOfWeek(focusDate), endOfWeek(focusDate));
        case _BalanceFlowRange.month:
          return DateFormat('MMMM yyyy').format(focusDate);
        case _BalanceFlowRange.year:
          return DateFormat('yyyy').format(focusDate);
        case _BalanceFlowRange.custom:
          return formatRange(customStart, customEnd);
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Consumer(
          builder: (context, ref, _) {
            final accountsAsync = ref.watch(activeAccountsProvider);
            final transactionsAsync = ref.watch(allTransactionsProvider);
            final range = currentRange();
            final rangeStart = range.key;
            final rangeEnd = range.value;

            Future<void> pickFocusDate() async {
              final picked = await showDatePicker(
                context: context,
                initialDate: focusDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked == null) return;
              setSheetState(() {
                focusDate = normalizeDate(picked);
              });
            }

            Future<void> pickCustomDate({required bool isStart}) async {
              final initialDate = isStart ? customStart : customEnd;
              final picked = await showDatePicker(
                context: context,
                initialDate: initialDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked == null) return;
              setSheetState(() {
                if (isStart) {
                  customStart = normalizeDate(picked);
                  if (customEnd.isBefore(customStart)) customEnd = customStart;
                } else {
                  customEnd = normalizeDate(picked);
                  if (customEnd.isBefore(customStart)) customStart = customEnd;
                }
              });
            }

            Widget buildRangeChip(_BalanceFlowRange value) {
              final selected = rangeType == value;
              return InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setSheetState(() {
                    rangeType = value;
                  });
                },
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFCDAF56).withOpacity(0.18)
                        : (isDark
                              ? Colors.white.withOpacity(0.04)
                              : Colors.black.withOpacity(0.04)),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFFCDAF56).withOpacity(0.45)
                          : (isDark
                                ? Colors.white.withOpacity(0.08)
                                : Colors.black.withOpacity(0.08)),
                    ),
                  ),
                  child: Text(
                    rangeLabel(value),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? const Color(0xFFCDAF56)
                          : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                ),
              );
            }

            Widget buildCurrencyChip(String currency, bool selected) {
              return InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setSheetState(() {
                    selectedCurrency = currency;
                  });
                },
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFCDAF56).withOpacity(0.16)
                        : (isDark
                              ? Colors.white.withOpacity(0.03)
                              : Colors.black.withOpacity(0.03)),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFFCDAF56).withOpacity(0.45)
                          : (isDark
                                ? Colors.white.withOpacity(0.08)
                                : Colors.black.withOpacity(0.08)),
                    ),
                  ),
                  child: Text(
                    currency,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? const Color(0xFFCDAF56)
                          : (isDark ? Colors.white60 : Colors.black54),
                    ),
                  ),
                ),
              );
            }

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1D23) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFCDAF56), Color(0xFFB8963E)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.analytics_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Balance Breakdown',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              Text(
                                'Where your money comes from & goes',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? Colors.white38
                                      : Colors.black38,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  Divider(
                    color: isDark
                        ? Colors.white10
                        : Colors.black.withOpacity(0.06),
                    height: 1,
                  ),

                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _BalanceFlowRange.values
                                .map(buildRangeChip)
                                .toList(),
                          ),
                          const SizedBox(height: 14),
                          if (rangeType == _BalanceFlowRange.custom)
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        pickCustomDate(isStart: true),
                                    icon: const Icon(
                                      Icons.calendar_today_rounded,
                                      size: 14,
                                    ),
                                    label: Text(
                                      DateFormat(
                                        'MMM d, yyyy',
                                      ).format(customStart),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: isDark
                                          ? Colors.white70
                                          : Colors.black87,
                                      side: BorderSide(
                                        color: isDark
                                            ? Colors.white12
                                            : Colors.black12,
                                      ),
                                      textStyle: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        pickCustomDate(isStart: false),
                                    icon: const Icon(
                                      Icons.calendar_today_rounded,
                                      size: 14,
                                    ),
                                    label: Text(
                                      DateFormat(
                                        'MMM d, yyyy',
                                      ).format(customEnd),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: isDark
                                          ? Colors.white70
                                          : Colors.black87,
                                      side: BorderSide(
                                        color: isDark
                                            ? Colors.white12
                                            : Colors.black12,
                                      ),
                                      textStyle: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withOpacity(0.03)
                                    : Colors.black.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white12
                                      : Colors.black12,
                                ),
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    onPressed: () {
                                      HapticFeedback.selectionClick();
                                      setSheetState(() {
                                        focusDate = shiftedFocus(focusDate, -1);
                                      });
                                    },
                                    icon: const Icon(
                                      Icons.chevron_left_rounded,
                                    ),
                                    iconSize: 22,
                                    visualDensity: VisualDensity.compact,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black54,
                                  ),
                                  Expanded(
                                    child: InkWell(
                                      onTap: pickFocusDate,
                                      borderRadius: BorderRadius.circular(8),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        child: Text(
                                          focusLabel(),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      HapticFeedback.selectionClick();
                                      setSheetState(() {
                                        focusDate = shiftedFocus(focusDate, 1);
                                      });
                                    },
                                    icon: const Icon(
                                      Icons.chevron_right_rounded,
                                    ),
                                    iconSize: 22,
                                    visualDensity: VisualDensity.compact,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black54,
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 20),
                          transactionsAsync.when(
                            data: (transactions) {
                              final filteredTransactions = transactions.where((
                                tx,
                              ) {
                                if (tx.isBalanceAdjustment ||
                                    (!tx.isIncome && !tx.isExpense)) {
                                  return false;
                                }
                                final txDate = normalizeDate(
                                  tx.transactionDate,
                                );
                                return !txDate.isBefore(rangeStart) &&
                                    !txDate.isAfter(rangeEnd);
                              }).toList();

                              final incomeByCurrency = <String, double>{};
                              final expenseByCurrency = <String, double>{};
                              for (final tx in filteredTransactions) {
                                final currency = tx.currency ?? defaultCurrency;
                                if (tx.isIncome) {
                                  incomeByCurrency[currency] =
                                      (incomeByCurrency[currency] ?? 0.0) +
                                      tx.amount;
                                } else if (tx.isExpense) {
                                  expenseByCurrency[currency] =
                                      (expenseByCurrency[currency] ?? 0.0) +
                                      tx.amount;
                                }
                              }

                              final currencies = <String>{
                                defaultCurrency,
                                selectedCurrency,
                                ...incomeByCurrency.keys,
                                ...expenseByCurrency.keys,
                              }.toList()..sort();
                              final activeCurrency =
                                  currencies.contains(selectedCurrency)
                                  ? selectedCurrency
                                  : defaultCurrency;
                              final symbol = CurrencyUtils.getCurrencySymbol(
                                activeCurrency,
                              );
                              final income =
                                  incomeByCurrency[activeCurrency] ?? 0.0;
                              final expense =
                                  expenseByCurrency[activeCurrency] ?? 0.0;
                              final netFlow = income - expense;
                              final total = income + expense;
                              final incomePct = total > 0
                                  ? (income / total * 100).clamp(0.0, 100.0)
                                  : 0.0;
                              final expensePct = total > 0
                                  ? (expense / total * 100).clamp(0.0, 100.0)
                                  : 0.0;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    flowHeading(rangeType),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFFCDAF56),
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    formatRange(rangeStart, rangeEnd),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white38
                                          : Colors.black45,
                                    ),
                                  ),
                                  if (currencies.length > 1) ...[
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: currencies
                                          .map(
                                            (currency) => buildCurrencyChip(
                                              currency,
                                              currency == activeCurrency,
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  _BreakdownRow(
                                    icon: Icons.arrow_downward_rounded,
                                    iconColor: Colors.green,
                                    label: 'Total Income',
                                    amount: income,
                                    symbol: symbol,
                                    isDark: isDark,
                                  ),
                                  const SizedBox(height: 10),
                                  _BreakdownRow(
                                    icon: Icons.arrow_upward_rounded,
                                    iconColor: Colors.red,
                                    label: 'Total Expenses',
                                    amount: expense,
                                    symbol: symbol,
                                    isDark: isDark,
                                    isNegative: true,
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    height: 1,
                                    color: isDark
                                        ? Colors.white10
                                        : Colors.black.withOpacity(0.06),
                                  ),
                                  const SizedBox(height: 10),
                                  _BreakdownRow(
                                    icon: netFlow >= 0
                                        ? Icons.trending_up_rounded
                                        : Icons.trending_down_rounded,
                                    iconColor: netFlow >= 0
                                        ? Colors.green
                                        : Colors.red,
                                    label: 'Net Cash Flow',
                                    amount: netFlow.abs(),
                                    symbol: symbol,
                                    isDark: isDark,
                                    isNegative: netFlow < 0,
                                    isBold: true,
                                  ),
                                  if (total > 0) ...[
                                    const SizedBox(height: 16),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: SizedBox(
                                        height: 12,
                                        child: Row(
                                          children: [
                                            if (income > 0)
                                              Expanded(
                                                flex: (income * 100).round(),
                                                child: Container(
                                                  color: Colors.green,
                                                ),
                                              ),
                                            if (expense > 0)
                                              Expanded(
                                                flex: (expense * 100).round(),
                                                child: Container(
                                                  color: Colors.red.shade400,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Income ${incomePct.toStringAsFixed(0)}%',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.green,
                                          ),
                                        ),
                                        Text(
                                          'Expenses ${expensePct.toStringAsFixed(0)}%',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (filteredTransactions.isEmpty) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      'No transactions in this period.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: isDark
                                            ? Colors.white38
                                            : Colors.black45,
                                      ),
                                    ),
                                  ],
                                ],
                              );
                            },
                            loading: () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            error: (_, __) =>
                                const Text('Error loading transactions'),
                          ),

                          const SizedBox(height: 28),

                          // Account Breakdown
                          Text(
                            'BY ACCOUNT',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFFCDAF56),
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          accountsAsync.when(
                            data: (accounts) {
                              if (accounts.isEmpty) {
                                return Text(
                                  'No accounts yet',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.black38,
                                  ),
                                );
                              }

                              // Sort by balance descending
                              final sortedAccounts = List<Account>.from(
                                accounts,
                              )..sort((a, b) => b.balance.compareTo(a.balance));
                              final totalBalance = sortedAccounts.fold<double>(
                                0.0,
                                (sum, a) =>
                                    sum +
                                    (a.currency == defaultCurrency
                                        ? a.balance
                                        : 0.0),
                              );

                              return Column(
                                children: sortedAccounts.map((account) {
                                  final percentage = totalBalance > 0
                                      ? (account.balance / totalBalance * 100)
                                            .clamp(0.0, 100.0)
                                      : 0.0;
                                  final acctSymbol =
                                      CurrencyUtils.getCurrencySymbol(
                                        account.currency,
                                      );

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white.withOpacity(0.03)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: isDark
                                          ? null
                                          : [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  0.03,
                                                ),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color: const Color(
                                                  0xFFCDAF56,
                                                ).withOpacity(0.12),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: const Icon(
                                                Icons
                                                    .account_balance_wallet_rounded,
                                                color: Color(0xFFCDAF56),
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    account.name,
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: isDark
                                                          ? Colors.white
                                                          : Colors.black87,
                                                    ),
                                                  ),
                                                  Text(
                                                    '${account.accountType} · ${account.currency}',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: isDark
                                                          ? Colors.white38
                                                          : Colors.black38,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  '$acctSymbol${account.balance.toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w900,
                                                    color: account.balance >= 0
                                                        ? const Color(
                                                            0xFF4CAF50,
                                                          )
                                                        : Colors.red,
                                                  ),
                                                ),
                                                if (account.currency ==
                                                        defaultCurrency &&
                                                    totalBalance > 0)
                                                  Text(
                                                    '${percentage.toStringAsFixed(1)}%',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: isDark
                                                          ? Colors.white38
                                                          : Colors.black38,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        if (account.currency ==
                                                defaultCurrency &&
                                            totalBalance > 0) ...[
                                          const SizedBox(height: 10),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            child: LinearProgressIndicator(
                                              value: percentage / 100,
                                              minHeight: 4,
                                              backgroundColor: isDark
                                                  ? Colors.white.withOpacity(
                                                      0.05,
                                                    )
                                                  : Colors.black.withOpacity(
                                                      0.05,
                                                    ),
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    const Color(
                                                      0xFFCDAF56,
                                                    ).withOpacity(0.8),
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                            loading: () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            error: (_, __) =>
                                const Text('Error loading accounts'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _formatDateLabel(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

/// Breakdown Row Widget for balance breakdown sheet
class _BreakdownRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final double amount;
  final String symbol;
  final bool isDark;
  final bool isNegative;
  final bool isBold;

  const _BreakdownRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.amount,
    required this.symbol,
    required this.isDark,
    this.isNegative = false,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: isBold ? 14 : 13,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ),
        Text(
          '${isNegative ? '-' : ''}$symbol${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: isBold ? 18 : 15,
            fontWeight: FontWeight.w900,
            color: isNegative ? Colors.red : const Color(0xFF4CAF50),
          ),
        ),
      ],
    );
  }
}

/// Summary Chip Widget
class _SummaryChip extends StatelessWidget {
  final String label;
  final double amount;
  final String currency;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _SummaryChip({
    required this.label,
    required this.amount,
    required this.currency,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.04)
            : color.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(isDark ? 0.12 : 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black45,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${CurrencyUtils.getCurrencySymbol(currency)}${amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Stat Filter Card - Clean, minimal design
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;
  final bool isDark;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
    required this.isDark,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                    ? accentColor.withOpacity(0.12)
                    : accentColor.withOpacity(0.06))
              : (isDark ? Colors.white.withOpacity(0.04) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? accentColor.withOpacity(isDark ? 0.5 : 0.4)
                : (isDark
                      ? Colors.white.withOpacity(0.06)
                      : Colors.transparent),
            width: 1,
          ),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: isSelected
                        ? accentColor.withOpacity(0.08)
                        : Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(isSelected ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                        height: 1.0,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quick Action Button - Clean, consistent design
class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFFCDAF56);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: accentColor, size: 18),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF2A2A2A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Action-oriented grid for the FAB: Add Expense, Add Payment, Add Balance, etc.
class _FinanceActionGrid extends StatelessWidget {
  final bool isDark;
  final BuildContext navigatorContext;
  final VoidCallback onClose;

  const _FinanceActionGrid({
    required this.isDark,
    required this.navigatorContext,
    required this.onClose,
  });

  void _navigate(Widget screen) {
    onClose();
    Navigator.of(navigatorContext).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFCDAF56);
    final textColor = isDark ? Colors.white : Colors.black87;

    final actions = <_ActionItem>[
      _ActionItem('Add Expense', Icons.trending_down_rounded, () => _navigate(const AddTransactionScreen(initialType: 'expense'))),
      _ActionItem('Add Income', Icons.trending_up_rounded, () => _navigate(const AddTransactionScreen(initialType: 'income'))),
      _ActionItem('Add Balance (Fund)', Icons.account_balance_wallet_rounded, () => _navigate(const AddTransactionScreen(initialType: 'income'))),
      _ActionItem('Add Payment', Icons.payments_rounded, () => _navigate(const AddTransactionScreen(initialType: 'expense'))),
      _ActionItem('Add Transfer', Icons.swap_horiz_rounded, () => _navigate(const AddTransactionScreen(initialType: 'transfer'))),
      _ActionItem('Add Bill', Icons.receipt_long_rounded, () => _navigate(const AddBillScreen())),
      _ActionItem('Add Recurring Income', Icons.repeat_rounded, () => _navigate(const AddRecurringIncomeScreen())),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;
        final itemWidth = (constraints.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: actions.map((item) {
            return SizedBox(
              width: itemWidth,
              child: Material(
                color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    item.onTap();
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: gold.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(item.icon, color: gold, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _ActionItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  _ActionItem(this.label, this.icon, this.onTap);
}

/// Transaction Card Widget
class _TransactionCard extends ConsumerWidget {
  final Transaction transaction;
  final bool isDark;
  final VoidCallback? onTap;

  const _TransactionCard({
    required this.transaction,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typeColor = transaction.typeColor;
    final accountsAsync = ref.watch(allAccountsProvider);
    final category = transaction.categoryId != null
        ? ref.watch(transactionCategoryByIdProvider(transaction.categoryId!))
        : null;

    // Find account name if available
    String? accountName;
    accountsAsync.whenData((accounts) {
      final account = accounts
          .where((a) => a.id == transaction.accountId)
          .firstOrNull;
      if (account != null) {
        accountName = account.name;
      }
    });

    // Check if this is a bill/subscription payment
    final billAsync = transaction.billId != null
        ? ref.watch(billByIdProvider(transaction.billId!))
        : null;

    final catColor = category?.color ?? typeColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Category Icon
              Container(
                width: 40,
                height: 40,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: catColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  category?.icon ?? transaction.icon ?? transaction.typeIcon,
                  color: catColor,
                  size: 18,
                ),
              ),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            transaction.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E1E1E),
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Bill/Subscription badge
                        if (transaction.billId != null && billAsync != null)
                          billAsync.when(
                            data: (bill) {
                              if (bill == null) return const SizedBox.shrink();
                              return Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      bill.type == 'subscription'
                                          ? Icons.subscriptions_rounded
                                          : Icons.receipt_rounded,
                                      size: 10,
                                      color: Colors.amber,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      bill.type == 'subscription'
                                          ? 'SUB'
                                          : 'BILL',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.amber,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                        // Lending badge
                        if (transaction.debtId != null)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.purple.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  transaction.isExpense
                                      ? Icons.trending_down_rounded
                                      : Icons.trending_up_rounded,
                                  size: 10,
                                  color: Colors.purple,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  transaction.isExpense ? 'LENT' : 'REPAY',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.purple,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    // Metadata: time + category + account
                    Text.rich(
                      TextSpan(
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                        children: [
                          TextSpan(
                            text: DateFormat(
                              'h:mm a',
                            ).format(transaction.transactionDate),
                          ),
                          if (category != null) ...[
                            const TextSpan(text: '  ·  '),
                            TextSpan(
                              text: category.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: catColor.withOpacity(0.85),
                              ),
                            ),
                          ],
                          if (accountName != null) ...[
                            const TextSpan(text: '  ·  '),
                            TextSpan(
                              text: accountName!,
                              style: TextStyle(
                                color: isDark ? Colors.white30 : Colors.black26,
                              ),
                            ),
                          ],
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Amount
              const SizedBox(width: 10),
              Text(
                transaction.displayAmount,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: typeColor,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Smart Tag Widget
class _SmartTag extends StatelessWidget {
  final String label;
  final Color color;
  final bool isDark;
  final IconData? icon;

  const _SmartTag({
    required this.label,
    required this.color,
    required this.isDark,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Daily Transactions Accordion (collapsible list of all transactions for the day)
class _DailyTransactionsAccordion extends StatelessWidget {
  final List<Transaction> transactions;
  final bool isDark;
  final bool isExpanded;
  final String selectedFilter;
  final ValueChanged<bool> onExpansionChanged;
  final ValueChanged<Transaction> onTransactionTap;

  const _DailyTransactionsAccordion({
    required this.transactions,
    required this.isDark,
    required this.isExpanded,
    required this.selectedFilter,
    required this.onExpansionChanged,
    required this.onTransactionTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final today = DateTime.now();
    final selectedDate = transactions.isNotEmpty
        ? DateTime(
            transactions.first.transactionDate.year,
            transactions.first.transactionDate.month,
            transactions.first.transactionDate.day,
          )
        : today;

    String dateLabel;
    if (selectedDate.year == today.year &&
        selectedDate.month == today.month &&
        selectedDate.day == today.day) {
      dateLabel = 'Today';
    } else if (selectedDate.year == today.year &&
        selectedDate.month == today.month &&
        selectedDate.day == today.day - 1) {
      dateLabel = 'Yesterday';
    } else {
      dateLabel = dateFormat.format(selectedDate);
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        children: [
          // Accordion Header
          InkWell(
            onTap: () => onExpansionChanged(!isExpanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.receipt_long_rounded,
                    size: 20,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Transactions for $dateLabel',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${transactions.length}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black54,
                                ),
                              ),
                              TextSpan(
                                text:
                                    ' transaction${transactions.length != 1 ? 's' : ''}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.black45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: isDark ? Colors.white38 : Colors.black26,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Accordion Content
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: isExpanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      children: transactions
                          .map(
                            (transaction) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _TransactionCard(
                                transaction: transaction,
                                isDark: isDark,
                                onTap: () => onTransactionTap(transaction),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

/// Transactions Accordion (for showing more transactions)
class _TransactionsAccordion extends StatelessWidget {
  final List<Transaction> transactions;
  final bool isDark;
  final bool isExpanded;
  final ValueChanged<bool> onExpansionChanged;
  final ValueChanged<Transaction> onTransactionTap;

  const _TransactionsAccordion({
    required this.transactions,
    required this.isDark,
    required this.isExpanded,
    required this.onExpansionChanged,
    required this.onTransactionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        children: [
          // Accordion Header
          InkWell(
            onTap: () => onExpansionChanged(!isExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${transactions.length} more',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E1E1E),
                            ),
                          ),
                          TextSpan(
                            text:
                                ' transaction${transactions.length != 1 ? 's' : ''}',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: isDark ? Colors.white38 : Colors.black26,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Accordion Content
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: transactions
                    .map(
                      (transaction) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _TransactionCard(
                          transaction: transaction,
                          isDark: isDark,
                          onTap: () => onTransactionTap(transaction),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }
}

/// Transaction Detail Modal - For viewing and managing individual transactions
class _TransactionDetailModal extends ConsumerWidget {
  final Transaction transaction;

  const _TransactionDetailModal({required this.transaction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final typeColor = transaction.typeColor;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F26) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Header with Title & Amount
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _SmartTag(
                      label: transaction.type.toUpperCase(),
                      color: typeColor,
                      isDark: isDark,
                      icon: transaction.typeIcon,
                    ),
                  ],
                ),
              ),
              Text(
                transaction.displayAmount,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: typeColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Details Grid
          _buildDetailRow(
            Icons.calendar_today_rounded,
            'Date & Time',
            '${DateFormat('MMM dd, yyyy').format(transaction.transactionDate)} at ${transaction.transactionTime?.format(context) ?? 'No time'}',
            isDark,
          ),
          const SizedBox(height: 20),

          FutureBuilder(
            future: ref
                .read(accountRepositoryProvider)
                .getAccountById(transaction.accountId ?? ''),
            builder: (context, snapshot) {
              final account = snapshot.data;
              return _buildDetailRow(
                Icons.account_balance_wallet_rounded,
                transaction.type == 'transfer' ? 'From Account' : 'Account',
                account?.name ?? 'Unknown Account',
                isDark,
              );
            },
          ),

          if (transaction.type == 'transfer') ...[
            const SizedBox(height: 20),
            FutureBuilder(
              future: ref
                  .read(accountRepositoryProvider)
                  .getAccountById(transaction.toAccountId ?? ''),
              builder: (context, snapshot) {
                final account = snapshot.data;
                return _buildDetailRow(
                  Icons.arrow_forward_rounded,
                  'To Account',
                  account?.name ?? 'Unknown Account',
                  isDark,
                );
              },
            ),
          ],

          const SizedBox(height: 20),
          FutureBuilder(
            future: ref
                .read(transactionCategoryRepositoryProvider)
                .getCategoryById(transaction.categoryId ?? ''),
            builder: (context, snapshot) {
              final category = snapshot.data;
              return _buildDetailRow(
                category?.icon ?? Icons.category_rounded,
                'Category',
                category?.name ?? 'No Category',
                isDark,
              );
            },
          ),

          if (transaction.description != null &&
              transaction.description!.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildDetailRow(
              Icons.notes_rounded,
              'Notes',
              transaction.description!,
              isDark,
            ),
          ],

          const SizedBox(height: 40),

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            AddTransactionScreen(transaction: transaction),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit_rounded, size: 20),
                  label: const Text('EDIT'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(
                      color: Color(0xFFCDAF56),
                      width: 1.5,
                    ),
                    foregroundColor: const Color(0xFFCDAF56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _confirmDelete(context, ref),
                  icon: const Icon(Icons.delete_forever_rounded, size: 20),
                  label: const Text('DELETE'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.redAccent.withOpacity(0.1),
                    foregroundColor: Colors.redAccent,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Colors.redAccent, width: 1),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value,
    bool isDark,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFCDAF56).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFFCDAF56), size: 20),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white38 : Colors.grey,
                letterSpacing: 1,
              ),
            ),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction?'),
        content: const Text(
          'This will permanently delete the transaction and revert its impact on your account balance.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final balanceService = ref.read(transactionBalanceServiceProvider);
        final transactionRepo = ref.read(transactionRepositoryProvider);

        // REVERSE THE TRANSACTION'S IMPACT ON BALANCE
        await balanceService.reverseTransactionImpact(transaction);

        // DELETE THE TRANSACTION RECORD
        await transactionRepo.deleteTransaction(transaction.id);

        // Invalidate daily balance snapshots from the transaction date onward
        final dailyBalanceService = ref.read(dailyBalanceServiceProvider);
        await dailyBalanceService.invalidateFromDate(
          transaction.transactionDate,
        );

        // REFRESH PROVIDERS
        ref.invalidate(allTransactionsProvider);
        ref.invalidate(activeAccountsProvider);
        ref.invalidate(totalBalanceProvider);
        ref.invalidate(monthlyStatisticsProvider);

        // Normalize date for daily provider invalidation
        final date = transaction.transactionDate;
        final normalizedDate = DateTime(date.year, date.month, date.day);
        ref.invalidate(transactionsForDateProvider(normalizedDate));
        ref.invalidate(dailyTotalBalanceProvider(normalizedDate));
        ref.invalidate(dailyTotalBalanceProvider);

        // Update budgets
        await ref.read(budgetTrackerServiceProvider).updateAllBudgetSpending();
        ref.invalidate(allBudgetsProvider);

        if (context.mounted) {
          Navigator.pop(context); // Close modal
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transaction deleted and balance corrected'),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}
