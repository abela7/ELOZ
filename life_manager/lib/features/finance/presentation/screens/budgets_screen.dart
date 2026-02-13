import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/dark_gradient.dart';
import '../../data/models/account.dart';
import '../../data/models/budget.dart';
import '../../data/models/transaction.dart';
import '../../data/models/transaction_category.dart';
import '../../data/services/finance_settings_service.dart';
import '../../utils/currency_utils.dart';
import '../providers/finance_providers.dart';
import 'accounts_screen.dart';
import 'add_transaction_screen.dart';
import 'expenses_screen.dart';
import 'savings_goals_screen.dart';

enum _BudgetFilter { all, active, risk, exceeded, paused, stopped, ended }

enum _BudgetSort { urgency, highestAmount, lowestRemaining, alphabetical }

class BudgetsScreen extends ConsumerStatefulWidget {
  const BudgetsScreen({super.key});

  @override
  ConsumerState<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends ConsumerState<BudgetsScreen> {
  final TextEditingController _searchController = TextEditingController();
  _BudgetFilter _filter = _BudgetFilter.active;
  _BudgetSort _sort = _BudgetSort.urgency;
  bool _isControlPanelExpanded = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshBudgets());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshBudgets() async {
    final tracker = ref.read(budgetTrackerServiceProvider);
    await tracker.checkAndResetBudgets();
    await tracker.updateAllBudgetSpending();
    ref.invalidate(allBudgetsProvider);
    ref.invalidate(allBudgetStatusesProvider);
  }

  Future<void> _openBudgetEditor({
    Budget? budget,
    required String defaultCurrency,
    required List<TransactionCategory> categories,
    required List<Account> accounts,
    bool duplicate = false,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BudgetEditorSheet(
        budget: budget,
        categories: categories,
        accounts: accounts,
        defaultCurrency: defaultCurrency,
        duplicate: duplicate,
      ),
    );

    if (result == true) {
      await _refreshBudgets();
    }
  }

  Future<void> _toggleBudgetStatus(Budget budget) async {
    final updated = budget.copyWith();
    if (budget.isPausedState) {
      updated.resume();
    } else {
      updated.pause();
    }
    await ref.read(budgetRepositoryProvider).updateBudget(updated);
    await _refreshBudgets();
  }

  Future<void> _stopBudget(Budget budget) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop Budget'),
        content: Text(
          'Stop "${budget.name}"? This action disables tracking until you edit and reactivate it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Stop'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final updated = budget.copyWith();
    updated.stop(at: DateTime.now());
    await ref.read(budgetRepositoryProvider).updateBudget(updated);
    await _refreshBudgets();
  }

  Future<void> _endBudgetNow(Budget budget) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Budget'),
        content: Text(
          'End "${budget.name}" now? You can still view its history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orangeAccent),
            child: const Text('End'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final updated = budget.copyWith();
    updated.end(at: DateTime.now());
    await ref.read(budgetRepositoryProvider).updateBudget(updated);
    await _refreshBudgets();
  }

  Future<void> _deleteBudget(Budget budget) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Budget'),
        content: Text('Delete "${budget.name}" permanently?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(budgetRepositoryProvider).deleteBudget(budget.id);
      await _refreshBudgets();
    }
  }

  void _showHowBudgetWorksSheet(bool isDark) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1F26) : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'How Budgets Work',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                _buildHowItem(
                  '1',
                  'Set a limit by day, week, month, year, or custom range.',
                ),
                _buildHowItem(
                  '2',
                  'Target all expenses or one expense category and account.',
                ),
                _buildHowItem(
                  '3',
                  'Choose end condition: date, transaction count, or spent amount.',
                ),
                _buildHowItem(
                  '4',
                  'Pause, stop, or end budgets any time. Alerts run automatically.',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHowItem(String step, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFCDAF56).withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              step,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Color(0xFFCDAF56),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  bool _matchesFilter(Budget budget) {
    switch (_filter) {
      case _BudgetFilter.all:
        return true;
      case _BudgetFilter.active:
        return budget.canTrack;
      case _BudgetFilter.risk:
        return budget.canTrack &&
            budget.isApproachingLimit &&
            !budget.isExceeded;
      case _BudgetFilter.exceeded:
        return budget.canTrack && budget.isExceeded;
      case _BudgetFilter.paused:
        return budget.isPausedState;
      case _BudgetFilter.stopped:
        return budget.isStopped;
      case _BudgetFilter.ended:
        return budget.isEnded;
    }
  }

  List<Budget> _prepareBudgets(
    List<Budget> budgets,
    Map<String, TransactionCategory> categoriesById,
    Map<String, Account> accountsById,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = budgets.where((budget) {
      if (!_matchesFilter(budget)) return false;
      if (query.isEmpty) return true;

      final categoryName =
          categoriesById[budget.categoryId]?.name.toLowerCase() ?? 'overall';
      final accountName =
          accountsById[budget.accountId]?.name.toLowerCase() ?? 'all accounts';
      return budget.name.toLowerCase().contains(query) ||
          (budget.description?.toLowerCase().contains(query) ?? false) ||
          categoryName.contains(query) ||
          accountName.contains(query);
    }).toList();

    filtered.sort((a, b) {
      switch (_sort) {
        case _BudgetSort.urgency:
          final rankA = a.canTrack
              ? (a.isExceeded ? 0 : (a.isApproachingLimit ? 1 : 2))
              : (a.isPausedState ? 3 : (a.isStopped ? 4 : 5));
          final rankB = b.canTrack
              ? (b.isExceeded ? 0 : (b.isApproachingLimit ? 1 : 2))
              : (b.isPausedState ? 3 : (b.isStopped ? 4 : 5));
          if (rankA != rankB) return rankA.compareTo(rankB);
          return b.spendingPercentage.compareTo(a.spendingPercentage);
        case _BudgetSort.highestAmount:
          return b.amount.compareTo(a.amount);
        case _BudgetSort.lowestRemaining:
          return a.remaining.compareTo(b.remaining);
        case _BudgetSort.alphabetical:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultCurrency =
        ref.watch(defaultCurrencyProvider).value ??
        FinanceSettingsService.fallbackCurrency;
    final budgetsAsync = ref.watch(allBudgetsProvider);
    final categoriesAsync = ref.watch(allTransactionCategoriesProvider);
    final accountsAsync = ref.watch(activeAccountsProvider);
    final categories = categoriesAsync.valueOrNull ?? <TransactionCategory>[];
    final accounts = accountsAsync.valueOrNull ?? <Account>[];

    final content = _buildContent(
      isDark: isDark,
      defaultCurrency: defaultCurrency,
      budgetsAsync: budgetsAsync,
      categories: categories,
      accounts: accounts,
    );

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0D0F14)
          : const Color(0xFFF8F9FC),
      body: isDark ? DarkGradient.wrap(child: content) : content,
    );
  }

  Widget _buildContent({
    required bool isDark,
    required String defaultCurrency,
    required AsyncValue<List<Budget>> budgetsAsync,
    required List<TransactionCategory> categories,
    required List<Account> accounts,
  }) {
    return RefreshIndicator(
      onRefresh: _refreshBudgets,
      color: const Color(0xFFCDAF56),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          _buildSliverHeader(
            isDark: isDark,
            defaultCurrency: defaultCurrency,
            categories: categories,
            accounts: accounts,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              child: budgetsAsync.when(
                loading: () => _buildLoadingState(isDark),
                error: (error, _) => _buildErrorState(isDark, '$error'),
                data: (budgets) {
                  final categoriesById = <String, TransactionCategory>{
                    for (final category in categories) category.id: category,
                  };
                  final accountsById = <String, Account>{
                    for (final account in accounts) account.id: account,
                  };
                  final visible = _prepareBudgets(
                    budgets,
                    categoriesById,
                    accountsById,
                  );
                  final active = budgets
                      .where((budget) => budget.canTrack)
                      .toList();

                  final budgetedByCurrency = <String, double>{};
                  final spentByCurrency = <String, double>{};
                  for (final budget in active) {
                    budgetedByCurrency[budget.currency] =
                        (budgetedByCurrency[budget.currency] ?? 0) +
                        budget.amount;
                    spentByCurrency[budget.currency] =
                        (spentByCurrency[budget.currency] ?? 0) +
                        budget.currentSpent;
                  }

                  final primaryCurrency =
                      budgetedByCurrency.containsKey(defaultCurrency)
                      ? defaultCurrency
                      : (budgetedByCurrency.isNotEmpty
                            ? budgetedByCurrency.keys.first
                            : defaultCurrency);
                  final budgeted = budgetedByCurrency[primaryCurrency] ?? 0.0;
                  final spent = spentByCurrency[primaryCurrency] ?? 0.0;
                  final progress = budgeted > 0 ? (spent / budgeted) : 0.0;
                  final symbol = CurrencyUtils.getCurrencySymbol(
                    primaryCurrency,
                  );
                  final riskCount = active
                      .where(
                        (budget) =>
                            budget.isApproachingLimit && !budget.isExceeded,
                      )
                      .length;
                  final exceededCount = active
                      .where((budget) => budget.isExceeded)
                      .length;
                  final secondaryCurrencies = budgetedByCurrency.entries
                      .where((entry) => entry.key != primaryCurrency)
                      .toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildOverviewCard(
                        isDark: isDark,
                        activeCount: active.length,
                        riskCount: riskCount,
                        exceededCount: exceededCount,
                        symbol: symbol,
                        spent: spent,
                        budgeted: budgeted,
                        progress: progress,
                        secondaryCurrencies: secondaryCurrencies,
                        spentByCurrency: spentByCurrency,
                      ),
                      const SizedBox(height: 14),
                      _buildControlPanel(isDark),
                      const SizedBox(height: 12),
                      _buildIntegrationActions(isDark),
                      const SizedBox(height: 24),
                      Text(
                        'BUDGET PLANS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFCDAF56),
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (visible.isEmpty)
                        _buildEmptyState(
                          isDark: isDark,
                          defaultCurrency: defaultCurrency,
                          categories: categories,
                          accounts: accounts,
                        )
                      else
                        ...visible.map(
                          (budget) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _BudgetCard(
                              budget: budget,
                              category: categoriesById[budget.categoryId],
                              account: accountsById[budget.accountId],
                              isDark: isDark,
                              onEdit: () => _openBudgetEditor(
                                budget: budget,
                                defaultCurrency: defaultCurrency,
                                categories: categories,
                                accounts: accounts,
                              ),
                              onDuplicate: () => _openBudgetEditor(
                                budget: budget,
                                defaultCurrency: defaultCurrency,
                                categories: categories,
                                accounts: accounts,
                                duplicate: true,
                              ),
                              onToggleActive: () => _toggleBudgetStatus(budget),
                              onStop: () => _stopBudget(budget),
                              onEnd: () => _endBudgetNow(budget),
                              onDelete: () => _deleteBudget(budget),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverHeader({
    required bool isDark,
    required String defaultCurrency,
    required List<TransactionCategory> categories,
    required List<Account> accounts,
  }) {
    final topPadding = MediaQuery.of(context).padding.top;
    return SliverToBoxAdapter(
      child: Container(
        padding: EdgeInsets.fromLTRB(20, topPadding + 16, 20, 24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildHeaderIconButton(
                  isDark: isDark,
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.pop(context),
                ),
                Row(
                  children: [
                    _buildHeaderIconButton(
                      isDark: isDark,
                      icon: Icons.refresh_rounded,
                      onTap: _refreshBudgets,
                    ),
                    const SizedBox(width: 10),
                    _buildHeaderIconButton(
                      isDark: isDark,
                      icon: Icons.help_outline_rounded,
                      onTap: () => _showHowBudgetWorksSheet(isDark),
                    ),
                    const SizedBox(width: 10),
                    _buildHeaderIconButton(
                      isDark: isDark,
                      icon: Icons.add_rounded,
                      iconColor: const Color(0xFFCDAF56),
                      borderColor: const Color(0xFFCDAF56).withOpacity(0.2),
                      backgroundColor: const Color(
                        0xFFCDAF56,
                      ).withOpacity(0.08),
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        _openBudgetEditor(
                          defaultCurrency: defaultCurrency,
                          categories: categories,
                          accounts: accounts,
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFCDAF56), Color(0xFFB89636)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 28,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Budgets',
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
                        'Plan spending with confidence',
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

  Widget _buildHeaderIconButton({
    required bool isDark,
    required IconData icon,
    required VoidCallback onTap,
    Color? iconColor,
    Color? borderColor,
    Color? backgroundColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color:
              backgroundColor ??
              (isDark ? Colors.white.withOpacity(0.03) : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                borderColor ??
                (isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.06)),
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: iconColor ?? (isDark ? Colors.white70 : Colors.black54),
        ),
      ),
    );
  }

  Widget _buildOverviewCard({
    required bool isDark,
    required int activeCount,
    required int riskCount,
    required int exceededCount,
    required String symbol,
    required double spent,
    required double budgeted,
    required double progress,
    required List<MapEntry<String, double>> secondaryCurrencies,
    required Map<String, double> spentByCurrency,
  }) {
    final progressColor = exceededCount > 0
        ? const Color(0xFFFF5252)
        : (riskCount > 0 ? const Color(0xFFFFB300) : const Color(0xFFCDAF56));
    final today = DateFormat('EEE, MMM d, yyyy').format(DateTime.now());
    final isOverspent = spent > budgeted && budgeted > 0;
    final delta = (budgeted - spent).abs();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFCDAF56).withOpacity(isDark ? 0.17 : 0.1),
            const Color(0xFFB89636).withOpacity(isDark ? 0.07 : 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFCDAF56).withOpacity(0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'BUDGET HEALTH',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFCDAF56),
                  letterSpacing: 1.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFCDAF56).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$activeCount active',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFCDAF56),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'As of $today',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '$symbol${spent.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF1E1E1E),
              letterSpacing: -1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'spent of $symbol${budgeted.toStringAsFixed(2)} allocated',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0).toDouble(),
              minHeight: 9,
              backgroundColor: isDark ? Colors.white10 : Colors.black12,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  isDark: isDark,
                  title: isOverspent ? 'Over' : 'Remaining',
                  value: '$symbol${delta.toStringAsFixed(2)}',
                  color: isOverspent
                      ? const Color(0xFFFF5252)
                      : const Color(0xFF4CAF50),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  isDark: isDark,
                  title: 'At Risk',
                  value: '$riskCount',
                  color: const Color(0xFFFFB300),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  isDark: isDark,
                  title: 'Exceeded',
                  value: '$exceededCount',
                  color: const Color(0xFFFF5252),
                ),
              ),
            ],
          ),
          if (secondaryCurrencies.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: secondaryCurrencies.map((entry) {
                final otherSymbol = CurrencyUtils.getCurrencySymbol(entry.key);
                final spentValue = spentByCurrency[entry.key] ?? 0.0;
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
                    '$otherSymbol${spentValue.toStringAsFixed(0)} / $otherSymbol${entry.value.toStringAsFixed(0)}',
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

  Widget _buildMetricTile({
    required bool isDark,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.16 : 0.11),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: color.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1E1E1E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanel(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _isControlPanelExpanded = !_isControlPanelExpanded;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.tune_rounded,
                    size: 18,
                    color: Color(0xFFCDAF56),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'FILTERS & SORT',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFCDAF56),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _labelForFilter(_filter),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white38 : Colors.black45,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _isControlPanelExpanded
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
            crossFadeState: _isControlPanelExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Collapsed. Tap to refine budget list.',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search budgets or categories',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: _searchController.clear,
                            icon: const Icon(Icons.close_rounded),
                          ),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withOpacity(0.06)
                        : Colors.black.withOpacity(0.04),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _BudgetFilter.values
                        .map((filter) => _buildFilterChip(isDark, filter))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.06)
                        : Colors.black.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.08)
                          : Colors.black.withOpacity(0.08),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<_BudgetSort>(
                      isExpanded: true,
                      value: _sort,
                      items: _BudgetSort.values
                          .map(
                            (sort) => DropdownMenuItem<_BudgetSort>(
                              value: sort,
                              child: Text(_labelForSort(sort)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _sort = value);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntegrationActions(bool isDark) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildQuickAction(
                isDark: isDark,
                icon: Icons.add_card_rounded,
                label: 'Add Expense',
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          AddTransactionScreen(initialType: 'expense'),
                    ),
                  );
                  await _refreshBudgets();
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildQuickAction(
                isDark: isDark,
                icon: Icons.savings_rounded,
                label: 'Savings',
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SavingsGoalsScreen(),
                    ),
                  );
                  await _refreshBudgets();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildQuickAction(
                isDark: isDark,
                icon: Icons.account_balance_wallet_rounded,
                label: 'Accounts',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AccountsScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildQuickAction(
                isDark: isDark,
                icon: Icons.insights_rounded,
                label: 'Expenses',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ExpensesScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickAction({
    required bool isDark,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.08),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: const Color(0xFFCDAF56)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(bool isDark, _BudgetFilter filter) {
    final selected = _filter == filter;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          if (_filter == filter) return;
          HapticFeedback.selectionClick();
          setState(() => _filter = filter);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFCDAF56).withOpacity(0.2)
                : (isDark
                      ? Colors.white.withOpacity(0.04)
                      : Colors.black.withOpacity(0.04)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? const Color(0xFFCDAF56).withOpacity(0.42)
                  : (isDark
                        ? Colors.white.withOpacity(0.08)
                        : Colors.black.withOpacity(0.08)),
            ),
          ),
          child: Text(
            _labelForFilter(filter),
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected
                  ? const Color(0xFFCDAF56)
                  : (isDark ? Colors.white60 : Colors.black54),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return Column(
      children: [
        _buildLoadingBox(isDark, height: 220),
        const SizedBox(height: 14),
        _buildLoadingBox(isDark, height: 170),
        const SizedBox(height: 24),
        ...List.generate(
          3,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildLoadingBox(isDark, height: 150),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingBox(bool isDark, {required double height}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.05),
        ),
      ),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2.2)),
    );
  }

  Widget _buildErrorState(bool isDark, String error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.redAccent.withOpacity(0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Failed to load budgets',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.redAccent,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            error,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _refreshBudgets,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFCDAF56),
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required bool isDark,
    required String defaultCurrency,
    required List<TransactionCategory> categories,
    required List<Account> accounts,
  }) {
    return Container(
      width: double.infinity,
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
          Text(
            'No budgets for current filters',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1E1E1E),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Create a budget to track spending limits by category or overall.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => _openBudgetEditor(
              defaultCurrency: defaultCurrency,
              categories: categories,
              accounts: accounts,
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create Budget'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFCDAF56),
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  String _labelForFilter(_BudgetFilter filter) {
    switch (filter) {
      case _BudgetFilter.all:
        return 'All';
      case _BudgetFilter.active:
        return 'Active';
      case _BudgetFilter.risk:
        return 'At Risk';
      case _BudgetFilter.exceeded:
        return 'Exceeded';
      case _BudgetFilter.paused:
        return 'Paused';
      case _BudgetFilter.stopped:
        return 'Stopped';
      case _BudgetFilter.ended:
        return 'Ended';
    }
  }

  String _labelForSort(_BudgetSort sort) {
    switch (sort) {
      case _BudgetSort.urgency:
        return 'Urgency';
      case _BudgetSort.highestAmount:
        return 'Highest Amount';
      case _BudgetSort.lowestRemaining:
        return 'Lowest Remaining';
      case _BudgetSort.alphabetical:
        return 'Alphabetical';
    }
  }
}

class _BudgetCard extends StatefulWidget {
  final Budget budget;
  final TransactionCategory? category;
  final Account? account;
  final bool isDark;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onToggleActive;
  final VoidCallback onStop;
  final VoidCallback onEnd;
  final VoidCallback onDelete;

  const _BudgetCard({
    required this.budget,
    required this.category,
    required this.account,
    required this.isDark,
    required this.onEdit,
    required this.onDuplicate,
    required this.onToggleActive,
    required this.onStop,
    required this.onEnd,
    required this.onDelete,
  });

  @override
  State<_BudgetCard> createState() => _BudgetCardState();
}

class _BudgetCardState extends State<_BudgetCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final budget = widget.budget;
    final category = widget.category;
    final account = widget.account;
    final symbol = CurrencyUtils.getCurrencySymbol(budget.currency);
    final statusColor = _statusColor(budget);
    final progress = budget.amount > 0
        ? (budget.currentSpent / budget.amount)
        : 0.0;
    final periodStart = budget.getCurrentPeriodStart(asOf: DateTime.now());
    final periodEnd = budget.getCurrentPeriodEnd(asOf: DateTime.now());
    final isOverspent = budget.currentSpent > budget.amount;
    final balanceAmount = isOverspent
        ? (budget.currentSpent - budget.amount)
        : budget.remaining;

    return Container(
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: statusColor.withOpacity(0.3), width: 1.2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => _BudgetDetailScreen(
                  budgetId: budget.id,
                  isDark: widget.isDark,
                ),
              ),
            ).then((_) => widget.onEdit()); // Refresh on return
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: (category?.color ?? const Color(0xFFCDAF56))
                            .withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        category?.icon ?? Icons.account_balance_wallet_rounded,
                        color: category?.color ?? const Color(0xFFCDAF56),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            budget.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: widget.isDark
                                  ? Colors.white
                                  : const Color(0xFF1E1E1E),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${category?.name ?? 'Overall'} - ${budget.periodDescription}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: widget.isDark
                                  ? Colors.white54
                                  : Colors.black54,
                            ),
                          ),
                          if (account != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              account.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: widget.isDark
                                    ? Colors.white38
                                    : Colors.black45,
                              ),
                            ),
                          ],
                          if (budget.endCondition != 'indefinite') ...[
                            const SizedBox(height: 2),
                            Text(
                              budget.endConditionDescription,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: widget.isDark
                                    ? Colors.white38
                                    : Colors.black45,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: statusColor.withOpacity(0.35),
                        ),
                      ),
                      child: Text(
                        _statusLabel(budget),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _buildAmountBlock(
                      label: 'Spent',
                      value: '$symbol${budget.currentSpent.toStringAsFixed(2)}',
                      color: statusColor,
                    ),
                    const SizedBox(width: 10),
                    _buildAmountBlock(
                      label: 'Budget',
                      value: '$symbol${budget.amount.toStringAsFixed(2)}',
                      color: widget.isDark ? Colors.white70 : Colors.black87,
                    ),
                    const SizedBox(width: 10),
                    _buildAmountBlock(
                      label: isOverspent ? 'Over' : 'Remaining',
                      value: '$symbol${balanceAmount.toStringAsFixed(2)}',
                      color: isOverspent
                          ? const Color(0xFFFF5252)
                          : const Color(0xFF4CAF50),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0).toDouble(),
                    minHeight: 8,
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    backgroundColor: widget.isDark
                        ? Colors.white10
                        : Colors.black12,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '${budget.spendingPercentage.toStringAsFixed(0)}% used',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _lifecycleHint(budget),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: widget.isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 20,
                      color: widget.isDark ? Colors.white54 : Colors.black45,
                    ),
                  ],
                ),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 200),
                  crossFadeState: _expanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: const SizedBox(height: 0),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Range: ${DateFormat('MMM d, yyyy').format(periodStart)} - ${DateFormat('MMM d, yyyy').format(periodEnd)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: widget.isDark
                                ? Colors.white70
                                : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          budget.endConditionDescription,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: widget.isDark
                                ? Colors.white60
                                : Colors.black54,
                          ),
                        ),
                        if (budget.usesTransactionEnd &&
                            budget.endTransactionCount != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Progress: ${budget.matchedTransactionCount}/${budget.endTransactionCount} transactions',
                            style: TextStyle(
                              fontSize: 11,
                              color: widget.isDark
                                  ? Colors.white54
                                  : Colors.black54,
                            ),
                          ),
                        ],
                        if (budget.usesSpentEnd &&
                            budget.endSpentAmount != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Progress: $symbol${budget.lifetimeSpent.toStringAsFixed(2)} / $symbol${budget.endSpentAmount!.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: widget.isDark
                                  ? Colors.white54
                                  : Colors.black54,
                            ),
                          ),
                        ],
                        if ((budget.description ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            budget.description!.trim(),
                            style: TextStyle(
                              fontSize: 12,
                              color: widget.isDark
                                  ? Colors.white54
                                  : Colors.black54,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildActionButton(
                              icon: Icons.edit_rounded,
                              label: 'Edit',
                              onPressed: widget.onEdit,
                            ),
                            _buildActionButton(
                              icon: Icons.copy_rounded,
                              label: 'Duplicate',
                              onPressed: widget.onDuplicate,
                            ),
                            if (!budget.isStopped && !budget.isEnded)
                              _buildActionButton(
                                icon: budget.isPausedState
                                    ? Icons.play_circle_rounded
                                    : Icons.pause_circle_rounded,
                                label: budget.isPausedState
                                    ? 'Resume'
                                    : 'Pause',
                                onPressed: widget.onToggleActive,
                              ),
                            if (!budget.isStopped && !budget.isEnded)
                              _buildActionButton(
                                icon: Icons.stop_circle_outlined,
                                label: 'Stop',
                                onPressed: widget.onStop,
                                color: Colors.orangeAccent,
                              ),
                            if (!budget.isEnded)
                              _buildActionButton(
                                icon: Icons.flag_circle_outlined,
                                label: 'End now',
                                onPressed: widget.onEnd,
                                color: Colors.amber,
                              ),
                            _buildActionButton(
                              icon: Icons.delete_forever_rounded,
                              label: 'Delete',
                              onPressed: widget.onDelete,
                              color: Colors.redAccent,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAmountBlock({
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: color.withOpacity(0.9),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: widget.isDark ? Colors.white : const Color(0xFF1E1E1E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? color,
  }) {
    final foreground =
        color ?? (widget.isDark ? Colors.white70 : Colors.black87);
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: foreground,
        side: BorderSide(color: foreground.withOpacity(0.35)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }

  String _lifecycleHint(Budget budget) {
    if (budget.isEnded) {
      if (budget.endedAt != null) {
        return 'Ended ${DateFormat('MMM d').format(budget.endedAt!)}';
      }
      return 'Ended';
    }
    if (budget.isStopped) {
      if (budget.stoppedAt != null) {
        return 'Stopped ${DateFormat('MMM d').format(budget.stoppedAt!)}';
      }
      return 'Stopped';
    }
    if (budget.isPausedState) return 'Paused';
    return '${budget.daysRemaining} days left';
  }

  Color _statusColor(Budget budget) {
    if (budget.isEnded) return const Color(0xFF8D8D8D);
    if (budget.isStopped) return const Color(0xFFB26A00);
    if (budget.isPausedState) return Colors.blueGrey;
    if (budget.isExceeded) return const Color(0xFFFF5252);
    if (budget.isApproachingLimit) return const Color(0xFFFFB300);
    return const Color(0xFFCDAF56);
  }

  String _statusLabel(Budget budget) {
    if (budget.isEnded) return 'Ended';
    if (budget.isStopped) return 'Stopped';
    if (budget.isPausedState) return 'Paused';
    if (budget.isExceeded) return 'Exceeded';
    if (budget.isApproachingLimit) return 'At Risk';
    return 'Healthy';
  }
}

class _BudgetDetailScreen extends ConsumerStatefulWidget {
  final String budgetId;
  final bool isDark;

  const _BudgetDetailScreen({
    required this.budgetId,
    required this.isDark,
  });

  @override
  ConsumerState<_BudgetDetailScreen> createState() => _BudgetDetailScreenState();
}

class _BudgetDetailScreenState extends ConsumerState<_BudgetDetailScreen> {
  Future<void> _refresh() async {
    final tracker = ref.read(budgetTrackerServiceProvider);
    await tracker.checkAndResetBudgets();
    await tracker.updateAllBudgetSpending();
    ref.invalidate(allBudgetsProvider);
    ref.invalidate(allBudgetStatusesProvider);
    ref.invalidate(allTransactionsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final budgetsAsync = ref.watch(allBudgetsProvider);
    final categoriesAsync = ref.watch(allTransactionCategoriesProvider);
    final accountsAsync = ref.watch(allAccountsProvider);
    final transactionsAsync = ref.watch(allTransactionsProvider);

    return budgetsAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (budgets) {
        final budget = budgets.firstWhere((b) => b.id == widget.budgetId);
        final category = categoriesAsync.valueOrNull?.firstWhere(
          (c) => c.id == budget.categoryId,
          orElse: () => TransactionCategory(
            id: '',
            name: 'Overall',
            iconCodePoint: Icons.account_balance_wallet_rounded.codePoint,
            colorValue: const Color(0xFFCDAF56).value,
            type: 'expense',
          ),
        );
        final account = accountsAsync.valueOrNull?.firstWhere(
          (a) => a.id == budget.accountId,
          orElse: () => Account(id: '', name: 'All Accounts', balance: 0, currency: budget.currency),
        );

        final transactions = transactionsAsync.valueOrNull ?? [];
        final matchingTransactions = transactions.where((t) {
          if (!t.isExpense || t.isBalanceAdjustment) return false;
          if (budget.accountId != null && t.accountId != budget.accountId) return false;
          if (t.currency != budget.currency) return false;
          if (!budget.isOverallBudget && t.categoryId != budget.categoryId) return false;
          
          final periodStart = budget.getCurrentPeriodStart(asOf: DateTime.now());
          final periodEnd = budget.getCurrentPeriodEnd(asOf: DateTime.now());
          return t.transactionDate.isAfter(periodStart.subtract(const Duration(seconds: 1))) && 
                 t.transactionDate.isBefore(periodEnd.add(const Duration(seconds: 1)));
        }).toList();
        
        matchingTransactions.sort((a, b) => b.transactionDate.compareTo(a.transactionDate));

        final statusColor = _statusColor(budget);
        final progress = budget.amount > 0 ? (budget.currentSpent / budget.amount) : 0.0;
        final isOverspent = budget.currentSpent > budget.amount;
        final symbol = CurrencyUtils.getCurrencySymbol(budget.currency);

        final content = RefreshIndicator(
          onRefresh: _refresh,
          color: const Color(0xFFCDAF56),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              _buildHeader(context, budget, category, statusColor),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeroCard(budget, symbol, statusColor, progress, isOverspent),
                      const SizedBox(height: 24),
                      _buildStatsGrid(budget, symbol, statusColor),
                      const SizedBox(height: 32),
                      _sectionLabel('PLAN DETAILS'),
                      const SizedBox(height: 16),
                      _buildPlanDetailsCard(budget, category, account),
                      const SizedBox(height: 32),
                      _sectionLabel('RECENT TRANSACTIONS'),
                      const SizedBox(height: 16),
                      if (matchingTransactions.isEmpty)
                        _buildEmptyTransactions()
                      else
                        ...matchingTransactions.take(10).map((t) => _buildTransactionItem(t, category)),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );

        return Scaffold(
          backgroundColor: widget.isDark ? Colors.transparent : const Color(0xFFF5F5F7),
          body: widget.isDark ? DarkGradient.wrap(child: content) : content,
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, Budget budget, TransactionCategory? category, Color statusColor) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, 
            color: widget.isDark ? Colors.white : Colors.black87, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.edit_rounded, 
              color: widget.isDark ? Colors.white70 : Colors.black54, size: 20),
          onPressed: () => _editBudget(budget),
        ),
      ],
      expandedHeight: 120,
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        title: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              budget.name,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: widget.isDark ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              _statusLabel(budget).toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                color: statusColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(Budget budget, String symbol, Color statusColor, double progress, bool isOverspent) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: widget.isDark ? null : [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'CURRENT SPENDING',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: widget.isDark ? Colors.white38 : Colors.black38,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '$symbol${budget.currentSpent.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w900,
              color: widget.isDark ? Colors.white : Colors.black87,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'of $symbol${budget.amount.toStringAsFixed(2)} budget',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: widget.isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: 24),
          Stack(
            children: [
              Container(
                height: 12,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              FractionallySizedBox(
                widthFactor: progress.clamp(0.0, 1.0),
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [statusColor, statusColor.withOpacity(0.7)],
                    ),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _heroStat(
                'Remaining', 
                '$symbol${budget.remaining.toStringAsFixed(2)}',
                isOverspent ? Colors.redAccent : const Color(0xFF4CAF50),
              ),
              _heroStat(
                'Usage', 
                '${(progress * 100).toStringAsFixed(1)}%',
                statusColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: widget.isDark ? Colors.white38 : Colors.black38,
            letterSpacing: 0.5,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(Budget budget, String symbol, Color statusColor) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: [
        _statChip(Icons.calendar_today_rounded, 'Days Left', '${budget.daysRemaining} days'),
        _statChip(Icons.history_rounded, 'Lifetime', '$symbol${budget.lifetimeSpent.toStringAsFixed(0)}'),
        _statChip(Icons.receipt_long_rounded, 'Transactions', '${budget.matchedTransactionCount}'),
        _statChip(Icons.notifications_active_rounded, 'Alert at', '${budget.alertThreshold.toStringAsFixed(0)}%'),
      ],
    );
  }

  Widget _statChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.white.withOpacity(0.03) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFCDAF56).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: const Color(0xFFCDAF56)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: widget.isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: widget.isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanDetailsCard(Budget budget, TransactionCategory? category, Account? account) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.white.withOpacity(0.03) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Column(
        children: [
          _detailRow(Icons.category_rounded, 'Category', category?.name ?? 'Overall'),
          const Divider(height: 24),
          _detailRow(Icons.account_balance_rounded, 'Account', account?.name ?? 'All Accounts'),
          const Divider(height: 24),
          _detailRow(Icons.event_repeat_rounded, 'Period', budget.periodDescription),
          const Divider(height: 24),
          _detailRow(Icons.timer_rounded, 'End Condition', budget.endConditionDescription),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFFCDAF56)),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: widget.isDark ? Colors.white54 : Colors.black54,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: widget.isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionItem(Transaction t, TransactionCategory? budgetCategory) {
    final symbol = CurrencyUtils.getCurrencySymbol(t.currency ?? 'GBP');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.white.withOpacity(0.03) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (budgetCategory?.color ?? const Color(0xFFCDAF56)).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(budgetCategory?.icon ?? Icons.receipt_long_rounded, 
                size: 18, color: budgetCategory?.color ?? const Color(0xFFCDAF56)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: widget.isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  DateFormat('MMM d, yyyy • hh:mm a').format(t.transactionDate),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: widget.isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '-$symbol${t.amount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFFEF5350),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTransactions() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.01),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.history_rounded, size: 40, color: widget.isDark ? Colors.white12 : Colors.black12),
          const SizedBox(height: 12),
          Text(
            'No transactions found for this period',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: widget.isDark ? Colors.white24 : Colors.black26,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editBudget(Budget budget) async {
    final defaultCurrency = await ref.read(defaultCurrencyProvider.future);
    final categories = await ref.read(allTransactionCategoriesProvider.future);
    final accounts = await ref.read(allAccountsProvider.future);
    
    if (!mounted) return;
    
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BudgetEditorSheet(
        budget: budget,
        categories: categories,
        accounts: accounts,
        defaultCurrency: defaultCurrency,
        duplicate: false,
      ),
    );

    if (result == true) {
      await _refresh();
    }
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        color: Color(0xFFCDAF56),
        letterSpacing: 1.2,
      ),
    );
  }

  String _statusLabel(Budget budget) {
    if (budget.isEnded) return 'Ended';
    if (budget.isStopped) return 'Stopped';
    if (budget.isPausedState) return 'Paused';
    if (budget.isExceeded) return 'Exceeded';
    if (budget.isApproachingLimit) return 'At Risk';
    return 'Healthy';
  }

  Color _statusColor(Budget budget) {
    if (budget.isEnded) return const Color(0xFF8D8D8D);
    if (budget.isStopped) return const Color(0xFFB26A00);
    if (budget.isPausedState) return Colors.blueGrey;
    if (budget.isExceeded) return const Color(0xFFFF5252);
    if (budget.isApproachingLimit) return const Color(0xFFFFB300);
    return const Color(0xFFCDAF56);
  }
}

class _BudgetEditorSheet extends ConsumerStatefulWidget {
  final Budget? budget;
  final List<TransactionCategory> categories;
  final List<Account> accounts;
  final String defaultCurrency;
  final bool duplicate;

  const _BudgetEditorSheet({
    required this.budget,
    required this.categories,
    required this.accounts,
    required this.defaultCurrency,
    required this.duplicate,
  });

  @override
  ConsumerState<_BudgetEditorSheet> createState() => _BudgetEditorSheetState();
}

class _BudgetEditorSheetState extends ConsumerState<_BudgetEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _amountController;
  late TextEditingController _descriptionController;
  late TextEditingController _endTransactionCountController;
  late TextEditingController _endSpentAmountController;
  late String _period;
  late String _currency;
  late int _periodSpan;
  late String _endCondition;
  String? _categoryId;
  String? _accountId;
  late DateTime _startDate;
  DateTime? _endDate;
  bool _active = true;
  bool _alertEnabled = true;
  double _alertThreshold = 80;

  DateTime _normalize(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  bool get _requiresDateEnd =>
      _period == 'custom' || _endCondition == 'on_date';

  @override
  void initState() {
    super.initState();
    final source = widget.budget;
    _nameController = TextEditingController(
      text: source == null
          ? ''
          : (widget.duplicate ? '${source.name} Copy' : source.name),
    );
    _amountController = TextEditingController(
      text: source?.amount.toStringAsFixed(2) ?? '',
    );
    _descriptionController = TextEditingController(
      text: source?.description ?? '',
    );
    _endTransactionCountController = TextEditingController(
      text: source?.endTransactionCount?.toString() ?? '',
    );
    _endSpentAmountController = TextEditingController(
      text: source?.endSpentAmount?.toStringAsFixed(2) ?? '',
    );
    _period = source?.period ?? 'monthly';
    _periodSpan = (source?.periodSpan ?? 1).clamp(1, 365);
    _endCondition = source?.endCondition ?? 'indefinite';
    if (_period == 'custom') {
      _endCondition = 'on_date';
      _periodSpan = 1;
    }
    _currency = source?.currency ?? widget.defaultCurrency;
    _categoryId = source?.categoryId;
    _accountId = source?.accountId;
    _startDate = _normalize(
      widget.duplicate ? DateTime.now() : (source?.startDate ?? DateTime.now()),
    );
    _endDate = _requiresDateEnd ? source?.endDate : null;
    _active = source?.isActive ?? true;
    _alertEnabled = source?.alertEnabled ?? true;
    _alertThreshold = source?.alertThreshold ?? 80;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _endTransactionCountController.dispose();
    _endSpentAmountController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration({
    required String label,
    String? prefixText,
    String? hintText,
    IconData? prefixIcon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      labelText: label.toUpperCase(),
      labelStyle: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: isDark ? Colors.white38 : Colors.black38,
        letterSpacing: 1,
      ),
      hintText: hintText,
      hintStyle: TextStyle(
        color: isDark ? Colors.white10 : Colors.black12,
      ),
      prefixText: prefixText,
      prefixIcon: prefixIcon != null 
          ? Icon(prefixIcon, size: 20, color: const Color(0xFFCDAF56))
          : null,
      filled: true,
      fillColor: isDark
          ? Colors.white.withOpacity(0.02)
          : Colors.black.withOpacity(0.01),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.05),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.05),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFFCDAF56),
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFFEF5350),
          width: 1.5,
        ),
      ),
      isDense: true,
    );
  }

  BoxDecoration _panelDecoration(bool isDark) {
    return BoxDecoration(
      color: isDark
          ? Colors.white.withOpacity(0.03)
          : Colors.black.withOpacity(0.02),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.05),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        color: Color(0xFFCDAF56),
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _fieldLabel(bool isDark, String text) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: isDark ? Colors.white38 : Colors.black38,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildResponsivePair({
    required bool isCompact,
    required Widget first,
    required Widget second,
  }) {
    if (isCompact) {
      return Column(children: [first, const SizedBox(height: 10), second]);
    }
    return Row(
      children: [
        Expanded(child: first),
        const SizedBox(width: 10),
        Expanded(child: second),
      ],
    );
  }

  Widget _buildDateTile({
    required bool isDark,
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(isDark, label),
        const SizedBox(height: 10),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.02)
                  : Colors.black.withOpacity(0.01),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.05),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: const Color(0xFFCDAF56)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.calendar_today_rounded,
                  size: 16,
                  color: isDark ? Colors.white24 : Colors.black26,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleCard({
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.02)
            : Colors.black.withOpacity(0.01),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.05),
        ),
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white24 : Colors.black26,
          ),
        ),
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFCDAF56).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFFCDAF56), size: 18),
        ),
        value: value,
        onChanged: (val) {
          HapticFeedback.lightImpact();
          onChanged(val);
        },
        activeColor: const Color(0xFFCDAF56),
        activeTrackColor: const Color(0xFFCDAF56).withOpacity(0.3),
        inactiveThumbColor: isDark ? Colors.white24 : Colors.grey[400],
        inactiveTrackColor: isDark ? Colors.white10 : Colors.grey[200],
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  void _setBudgetAmount(double amount) {
    final normalized = amount.isFinite ? amount : 0.0;
    _amountController.text = normalized.toStringAsFixed(2);
  }

  void _applyAccountShare(Account account, double ratio) {
    final source = account.balance < 0 ? 0.0 : account.balance;
    _setBudgetAmount(source * ratio);
    _currency = account.currency;
  }

  Widget _buildFundingChip({
    required bool isDark,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.04)
              : Colors.black.withOpacity(0.02),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.08),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
      ),
    );
  }

  List<int> _spanOptionsForPeriod(String period) {
    switch (period) {
      case 'daily':
        return const [1, 2, 3, 5, 7, 14, 30];
      case 'weekly':
        return const [1, 2, 3, 4, 6, 8, 12];
      case 'monthly':
        return const [1, 2, 3, 4, 6, 12];
      case 'yearly':
        return const [1, 2, 3, 5, 10];
      case 'custom':
      default:
        return const [1];
    }
  }

  String _spanLabel(String period, int span) {
    switch (period) {
      case 'daily':
        return span == 1 ? '1 day' : '$span days';
      case 'weekly':
        return span == 1 ? '1 week' : '$span weeks';
      case 'monthly':
        return span == 1 ? '1 month' : '$span months';
      case 'yearly':
        return span == 1 ? '1 year' : '$span years';
      case 'custom':
      default:
        return 'Custom range';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) return;
    if (_requiresDateEnd && _endDate == null) return;
    if (_requiresDateEnd && _endDate!.isBefore(_startDate)) return;

    int? endTransactionCount;
    if (_endCondition == 'after_transactions') {
      endTransactionCount = int.tryParse(
        _endTransactionCountController.text.trim(),
      );
      if (endTransactionCount == null || endTransactionCount <= 0) return;
    }

    double? endSpentAmount;
    if (_endCondition == 'after_spent') {
      endSpentAmount = double.tryParse(_endSpentAmountController.text.trim());
      if (endSpentAmount == null || endSpentAmount <= 0) return;
    }

    final repo = ref.read(budgetRepositoryProvider);
    final existing = await repo.getAllBudgets();
    final duplicateActive =
        _active &&
        existing.any((budget) {
          if (budget.id == widget.budget?.id && !widget.duplicate) return false;
          if (!budget.canTrack) return false;
          return budget.period == _period &&
              budget.periodSpan == _periodSpan &&
              budget.currency == _currency &&
              budget.categoryId == _categoryId &&
              budget.accountId == _accountId;
        });

    if (duplicateActive && mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Similar Active Budget Exists'),
          content: const Text('Create this budget anyway?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Create'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    if (_accountId != null) {
      Account? selectedAccount;
      for (final account in widget.accounts) {
        if (account.id == _accountId) {
          selectedAccount = account;
          break;
        }
      }

      if (selectedAccount != null &&
          amount > selectedAccount.balance &&
          mounted) {
        final continueSave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Budget Above Account Balance'),
            content: Text(
              'Budget limit is higher than "${selectedAccount!.name}" balance.\n\nSave anyway?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Save'),
              ),
            ],
          ),
        );
        if (continueSave != true) return;
      }
    }

    final resolvedEndDate = _requiresDateEnd ? _endDate : null;
    var isPaused = widget.duplicate
        ? false
        : (widget.budget?.isPaused ?? false);
    var isStopped = widget.duplicate
        ? false
        : (widget.budget?.isStopped ?? false);
    DateTime? stoppedAt = widget.duplicate ? null : widget.budget?.stoppedAt;
    DateTime? endedAt = widget.duplicate ? null : widget.budget?.endedAt;

    if (_active) {
      isPaused = false;
      isStopped = false;
      stoppedAt = null;
      endedAt = null;
    } else if (!isStopped && endedAt == null) {
      isPaused = true;
    }

    final budget = Budget(
      id: widget.duplicate ? null : widget.budget?.id,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      amount: amount,
      period: _period,
      periodSpan: _periodSpan,
      categoryId: _categoryId,
      startDate: _startDate,
      endDate: resolvedEndDate,
      isActive: _active,
      createdAt: widget.duplicate ? null : widget.budget?.createdAt,
      currentSpent: widget.duplicate
          ? 0.0
          : (widget.budget?.currentSpent ?? 0.0),
      lifetimeSpent: widget.duplicate
          ? 0.0
          : (widget.budget?.lifetimeSpent ?? 0.0),
      matchedTransactionCount: widget.duplicate
          ? 0
          : (widget.budget?.matchedTransactionCount ?? 0),
      alertEnabled: _alertEnabled,
      alertThreshold: _alertThreshold,
      currency: _currency,
      accountId: _accountId,
      endCondition: _endCondition,
      endTransactionCount: endTransactionCount,
      endSpentAmount: endSpentAmount,
      isPaused: isPaused,
      isStopped: isStopped,
      stoppedAt: stoppedAt,
      endedAt: endedAt,
    );

    if (widget.budget == null || widget.duplicate) {
      await repo.createBudget(budget);
    } else {
      await repo.updateBudget(budget);
    }

    final tracker = ref.read(budgetTrackerServiceProvider);
    await tracker.checkAndResetBudgets();
    await tracker.updateAllBudgetSpending();
    ref.invalidate(allBudgetsProvider);
    ref.invalidate(allBudgetStatusesProvider);

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isCompact = MediaQuery.of(context).size.width < 430;
    final title = widget.budget == null
        ? 'Create Budget'
        : (widget.duplicate ? 'Duplicate Budget' : 'Edit Budget');
    Account? selectedAccount;
    if (_accountId != null) {
      for (final account in widget.accounts) {
        if (account.id == _accountId) {
          selectedAccount = account;
          break;
        }
      }
    }
    final linkedAccount = selectedAccount;

    final content = Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.transparent : const Color(0xFFF5F5F7),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white12 : Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCDAF56).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.account_balance_wallet_rounded, 
                        color: Color(0xFFCDAF56), size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          'Setup your spending limits',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, 
                        color: isDark ? Colors.white38 : Colors.black38),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Hero Amount Input
              Container(
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.03)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: const Color(0xFFCDAF56).withOpacity(0.2), 
                    width: 1.5,
                  ),
                  boxShadow: isDark ? null : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'BUDGET LIMIT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFCDAF56).withOpacity(0.7),
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                        letterSpacing: -1,
                      ),
                      decoration: InputDecoration(
                        prefixText: '${CurrencyUtils.getCurrencySymbol(_currency)} ',
                        prefixStyle: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFCDAF56).withOpacity(0.6),
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        hintText: '0.00',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.white10 : Colors.black12,
                        ),
                      ),
                      validator: (value) {
                        return (double.tryParse(value?.trim() ?? '') ?? 0) <= 0
                            ? 'Invalid amount'
                            : null;
                      },
                    ),
                    if (linkedAccount != null) ...[
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.02)
                              : Colors.black.withOpacity(0.01),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Quick set from ${linkedAccount.name}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: [
                                _buildFundingChip(
                                  isDark: isDark,
                                  label: '25%',
                                  onTap: () => setState(() => _applyAccountShare(linkedAccount, 0.25)),
                                ),
                                _buildFundingChip(
                                  isDark: isDark,
                                  label: '50%',
                                  onTap: () => setState(() => _applyAccountShare(linkedAccount, 0.5)),
                                ),
                                _buildFundingChip(
                                  isDark: isDark,
                                  label: '75%',
                                  onTap: () => setState(() => _applyAccountShare(linkedAccount, 0.75)),
                                ),
                                _buildFundingChip(
                                  isDark: isDark,
                                  label: '100%',
                                  onTap: () => setState(() => _applyAccountShare(linkedAccount, 1)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),
              _sectionLabel('DETAILS'),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: _panelDecoration(isDark),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: _fieldDecoration(
                        label: 'Budget Name',
                        hintText: 'e.g. Monthly Food',
                        prefixIcon: Icons.edit_note_rounded,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Required';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 2,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: _fieldDecoration(
                        label: 'Notes',
                        hintText: 'Optional description...',
                        prefixIcon: Icons.description_rounded,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              _sectionLabel('PLAN CONFIGURATION'),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: _panelDecoration(isDark),
                child: Column(
                  children: [
                    _buildResponsivePair(
                      isCompact: isCompact,
                      first: DropdownButtonFormField<String>(
                        value: _currency,
                        icon: Icon(Icons.keyboard_arrow_down_rounded, 
                            color: isDark ? Colors.white38 : Colors.black38),
                        dropdownColor: isDark ? const Color(0xFF1A1D23) : Colors.white,
                        decoration: _fieldDecoration(label: 'Currency', prefixIcon: Icons.payments_rounded),
                        items: FinanceSettingsService.supportedCurrencies
                            .map((c) => DropdownMenuItem(value: c, child: Text(c, 
                                style: const TextStyle(fontWeight: FontWeight.w600))))
                            .toList(),
                        onChanged: linkedAccount != null ? null : (value) {
                          if (value != null) setState(() => _currency = value);
                        },
                      ),
                      second: DropdownButtonFormField<String>(
                        value: _period,
                        icon: Icon(Icons.keyboard_arrow_down_rounded, 
                            color: isDark ? Colors.white38 : Colors.black38),
                        dropdownColor: isDark ? const Color(0xFF1A1D23) : Colors.white,
                        decoration: _fieldDecoration(label: 'Period', prefixIcon: Icons.event_repeat_rounded),
                        items: const [
                          DropdownMenuItem(value: 'daily', child: Text('Daily', style: TextStyle(fontWeight: FontWeight.w600))),
                          DropdownMenuItem(value: 'weekly', child: Text('Weekly', style: TextStyle(fontWeight: FontWeight.w600))),
                          DropdownMenuItem(value: 'monthly', child: Text('Monthly', style: TextStyle(fontWeight: FontWeight.w600))),
                          DropdownMenuItem(value: 'yearly', child: Text('Yearly', style: TextStyle(fontWeight: FontWeight.w600))),
                          DropdownMenuItem(value: 'custom', child: Text('Custom', style: TextStyle(fontWeight: FontWeight.w600))),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _period = value;
                            if (_period == 'custom') {
                              _periodSpan = 1;
                              _endCondition = 'on_date';
                            } else if (_periodSpan < 1) {
                              _periodSpan = 1;
                            }
                            if (!_requiresDateEnd) _endDate = null;
                          });
                        },
                      ),
                    ),
                    if (_period != 'custom') ...[
                      const SizedBox(height: 20),
                      _buildResponsivePair(
                        isCompact: isCompact,
                        first: DropdownButtonFormField<int>(
                          value: _periodSpan,
                          icon: Icon(Icons.keyboard_arrow_down_rounded, 
                              color: isDark ? Colors.white38 : Colors.black38),
                          dropdownColor: isDark ? const Color(0xFF1A1D23) : Colors.white,
                          decoration: _fieldDecoration(label: 'Repeat Every', prefixIcon: Icons.update_rounded),
                          items: _spanOptionsForPeriod(_period)
                              .map((span) => DropdownMenuItem(value: span, child: Text(_spanLabel(_period, span), 
                                  style: const TextStyle(fontWeight: FontWeight.w600))))
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _periodSpan = value);
                          },
                        ),
                        second: DropdownButtonFormField<String>(
                          value: _endCondition,
                          icon: Icon(Icons.keyboard_arrow_down_rounded, 
                              color: isDark ? Colors.white38 : Colors.black38),
                          dropdownColor: isDark ? const Color(0xFF1A1D23) : Colors.white,
                          decoration: _fieldDecoration(label: 'End Condition', prefixIcon: Icons.stop_circle_rounded),
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: 'indefinite', child: Text('No end', style: TextStyle(fontWeight: FontWeight.w600))),
                            DropdownMenuItem(value: 'on_date', child: Text('On date', style: TextStyle(fontWeight: FontWeight.w600))),
                            DropdownMenuItem(value: 'after_transactions', child: Text('After tx count', style: TextStyle(fontWeight: FontWeight.w600))),
                            DropdownMenuItem(value: 'after_spent', child: Text('After spent', style: TextStyle(fontWeight: FontWeight.w600))),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _endCondition = value;
                              if (!_requiresDateEnd) _endDate = null;
                            });
                          },
                        ),
                      ),
                      if (_endCondition == 'after_transactions') ...[
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _endTransactionCountController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: _fieldDecoration(
                            label: 'Transaction Limit',
                            hintText: 'Number of expenses',
                            prefixIcon: Icons.numbers_rounded,
                          ),
                          validator: (value) {
                            if (_endCondition != 'after_transactions') return null;
                            final parsed = int.tryParse(value?.trim() ?? '');
                            return (parsed == null || parsed <= 0) ? 'Invalid count' : null;
                          },
                        ),
                      ],
                      if (_endCondition == 'after_spent') ...[
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _endSpentAmountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: _fieldDecoration(
                            label: 'Spending Limit',
                            prefixText: '${CurrencyUtils.getCurrencySymbol(_currency)} ',
                            prefixIcon: Icons.money_off_rounded,
                          ),
                          validator: (value) {
                            if (_endCondition != 'after_spent') return null;
                            final parsed = double.tryParse(value?.trim() ?? '');
                            return (parsed == null || parsed <= 0) ? 'Invalid amount' : null;
                          },
                        ),
                      ],
                    ],
                    const SizedBox(height: 20),
                    _buildResponsivePair(
                      isCompact: isCompact,
                      first: DropdownButtonFormField<String?>(
                        value: _categoryId,
                        icon: Icon(Icons.keyboard_arrow_down_rounded, 
                            color: isDark ? Colors.white38 : Colors.black38),
                        dropdownColor: isDark ? const Color(0xFF1A1D23) : Colors.white,
                        decoration: _fieldDecoration(label: 'Category', prefixIcon: Icons.category_rounded),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('Overall', style: TextStyle(fontWeight: FontWeight.w600))),
                          ...widget.categories
                              .where((c) => c.type == 'expense' || c.type == 'both')
                              .map((c) => DropdownMenuItem<String?>(
                                value: c.id,
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: c.color.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(c.icon, color: c.color, size: 14),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                                  ],
                                ),
                              )),
                        ],
                        onChanged: (value) => setState(() => _categoryId = value),
                      ),
                      second: DropdownButtonFormField<String?>(
                        value: _accountId,
                        icon: Icon(Icons.keyboard_arrow_down_rounded, 
                            color: isDark ? Colors.white38 : Colors.black38),
                        dropdownColor: isDark ? const Color(0xFF1A1D23) : Colors.white,
                        decoration: _fieldDecoration(label: 'Account', prefixIcon: Icons.account_balance_rounded),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('All accounts', style: TextStyle(fontWeight: FontWeight.w600))),
                          ...widget.accounts.map((a) => DropdownMenuItem<String?>(
                            value: a.id,
                            child: Row(
                              children: [
                                Expanded(child: Text(a.name, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                                Text('${CurrencyUtils.getCurrencySymbol(a.currency)}${a.balance.toStringAsFixed(0)}', 
                                    style: TextStyle(fontSize: 10, color: isDark ? Colors.white24 : Colors.black26)),
                              ],
                            ),
                          )),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _accountId = value;
                            if (value == null) return;
                            for (final account in widget.accounts) {
                              if (account.id == value) {
                                _currency = account.currency;
                                break;
                              }
                            }
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              _sectionLabel('SCHEDULE'),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: _panelDecoration(isDark),
                child: Column(
                  children: [
                    _buildDateTile(
                      isDark: isDark,
                      icon: Icons.calendar_month_rounded,
                      label: 'Start Date',
                      value: DateFormat('MMM d, yyyy').format(_startDate),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _startDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                          builder: (context, child) => Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: isDark
                                  ? const ColorScheme.dark(primary: Color(0xFFCDAF56), onPrimary: Colors.black, surface: Color(0xFF2D3139))
                                  : const ColorScheme.light(primary: Color(0xFFCDAF56), onPrimary: Colors.white),
                            ),
                            child: child!,
                          ),
                        );
                        if (picked != null) setState(() => _startDate = _normalize(picked));
                      },
                    ),
                    if (_requiresDateEnd) ...[
                      const SizedBox(height: 20),
                      _buildDateTile(
                        isDark: isDark,
                        icon: Icons.event_available_rounded,
                        label: _period == 'custom' ? 'End Date' : 'End on Date',
                        value: _endDate == null ? 'Select date' : DateFormat('MMM d, yyyy').format(_endDate!),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _endDate ?? _startDate.add(const Duration(days: 30)),
                            firstDate: _startDate,
                            lastDate: DateTime(2100),
                            builder: (context, child) => Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: isDark
                                    ? const ColorScheme.dark(primary: Color(0xFFCDAF56), onPrimary: Colors.black, surface: Color(0xFF2D3139))
                                    : const ColorScheme.light(primary: Color(0xFFCDAF56), onPrimary: Colors.white),
                              ),
                              child: child!,
                            ),
                          );
                          if (picked != null) setState(() => _endDate = _normalize(picked));
                        },
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),
              _sectionLabel('STATUS & ALERTS'),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: _panelDecoration(isDark),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildToggleCard(
                      isDark: isDark,
                      icon: Icons.notifications_active_rounded,
                      title: 'Budget Alerts',
                      subtitle: 'Get notified when approaching limit',
                      value: _alertEnabled,
                      onChanged: (value) => setState(() => _alertEnabled = value),
                    ),
                    const SizedBox(height: 12),
                    _buildToggleCard(
                      isDark: isDark,
                      icon: Icons.play_circle_rounded,
                      title: 'Active Status',
                      subtitle: 'Budget is currently tracking expenses',
                      value: _active,
                      onChanged: (value) => setState(() => _active = value),
                    ),
                    if (_alertEnabled) ...[
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _fieldLabel(isDark, 'Alert Threshold'),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFCDAF56).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${_alertThreshold.toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFCDAF56),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Slider(
                        min: 50,
                        max: 100,
                        divisions: 10,
                        value: _alertThreshold,
                        activeColor: const Color(0xFFCDAF56),
                        inactiveColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                        onChanged: (value) => setState(() => _alertThreshold = value),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.white70 : Colors.black54,
                        side: BorderSide(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.1)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFCDAF56),
                        foregroundColor: const Color(0xFF1E1E1E),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Save Budget', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: isDark ? DarkGradient.wrap(child: content) : content,
      ),
    );
  }
}
