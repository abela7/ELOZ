import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/dark_gradient.dart';
import '../../../../core/widgets/color_picker_widget.dart';
import '../../../../core/widgets/icon_picker_widget.dart';
import '../../data/models/account.dart';
import '../../data/models/savings_goal.dart';
import '../../data/services/finance_settings_service.dart';
import '../../utils/currency_utils.dart';
import '../providers/finance_providers.dart';
import 'accounts_screen.dart';

enum _GoalFilter { active, archived, all }

enum _GoalAction { edit, add, fail, close, reopen, delete }

Widget _headerButton(
  BuildContext context,
  bool isDark,
  IconData icon,
  VoidCallback onTap, {
  Color? iconColor,
  Color? borderColor,
  Color? backgroundColor,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
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

String _statusText(SavingsGoal goal) {
  if (goal.isCompleted) return 'COMPLETED';
  if (goal.isFailed) return 'FAILED';
  if (goal.isClosed) return 'CLOSED';
  if (goal.isOverdue) return 'OVERDUE';
  return 'ACTIVE';
}

class SavingsGoalsScreen extends ConsumerStatefulWidget {
  const SavingsGoalsScreen({super.key});

  @override
  ConsumerState<SavingsGoalsScreen> createState() => _SavingsGoalsScreenState();
}

class _SavingsGoalsScreenState extends ConsumerState<SavingsGoalsScreen> {
  final TextEditingController _searchController = TextEditingController();
  _GoalFilter _filter = _GoalFilter.active;
  bool _showSearchFilters = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshGoals());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshGoals() async {
    ref.invalidate(allSavingsGoalsProvider);
    ref.invalidate(activeSavingsGoalsProvider);
    ref.invalidate(archivedSavingsGoalsProvider);
    ref.invalidate(savingsGoalsSummaryProvider);
  }

  String _money(String currency, double value) {
    final symbol = CurrencyUtils.getCurrencySymbol(currency);
    return '$symbol${value.toStringAsFixed(2)}';
  }

  bool _matchesFilter(SavingsGoal goal) {
    switch (_filter) {
      case _GoalFilter.active:
        return goal.isActive || goal.isCompleted;
      case _GoalFilter.archived:
        return goal.isArchived;
      case _GoalFilter.all:
        return true;
    }
  }

  List<SavingsGoal> _visibleGoals(List<SavingsGoal> goals) {
    final q = _searchController.text.trim().toLowerCase();
    final filtered = goals.where((goal) {
      if (!_matchesFilter(goal)) return false;
      if (q.isEmpty) return true;
      return goal.name.toLowerCase().contains(q) ||
          (goal.description?.toLowerCase().contains(q) ?? false);
    }).toList();

    filtered.sort((a, b) {
      if (a.isOverdue != b.isOverdue) return a.isOverdue ? -1 : 1;
      final byDate = a.targetDate.compareTo(b.targetDate);
      if (byDate != 0) return byDate;
      return b.remainingAmount.compareTo(a.remainingAmount);
    });
    return filtered;
  }

  Color _statusColor(SavingsGoal goal) {
    if (goal.isCompleted) return const Color(0xFF4CAF50);
    if (goal.isFailed) return const Color(0xFFEF5350);
    if (goal.isClosed) return const Color(0xFFFF9800);
    if (goal.isOverdue) return const Color(0xFFF44336);
    return const Color(0xFFCDAF56);
  }

  Future<void> _openGoalEditor({SavingsGoal? goal}) async {
    final defaultCurrency =
        ref.read(defaultCurrencyProvider).value ??
        FinanceSettingsService.fallbackCurrency;
    final accounts =
        ref.read(activeAccountsProvider).valueOrNull ?? <Account>[];

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _GoalEditorSheet(
        goal: goal,
        accounts: accounts,
        defaultCurrency: defaultCurrency,
      ),
    );

    if (saved == true) {
      await _refreshGoals();
    }
  }

  Future<void> _openContributionEditor({
    required SavingsGoal goal,
    SavingsContributionEntry? entry,
  }) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ContributionSheet(goal: goal, entry: entry),
    );

    if (saved == true) {
      await _refreshGoals();
    }
  }

  Future<void> _deleteGoal(SavingsGoal goal) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Goal'),
        content: Text('Delete "${goal.name}" permanently?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    await ref.read(savingsGoalRepositoryProvider).deleteGoal(goal.id);
    await _refreshGoals();
  }

  Future<void> _setGoalState(SavingsGoal goal, _GoalAction action) async {
    final repo = ref.read(savingsGoalRepositoryProvider);

    switch (action) {
      case _GoalAction.edit:
        await _openGoalEditor(goal: goal);
        return;
      case _GoalAction.add:
        await _openContributionEditor(goal: goal);
        return;
      case _GoalAction.fail:
        await repo.markGoalFailed(goal.id, reason: 'Marked as failed');
        break;
      case _GoalAction.close:
        await repo.closeGoal(goal.id, reason: 'Closed by user');
        break;
      case _GoalAction.reopen:
        await repo.reopenGoal(goal.id);
        break;
      case _GoalAction.delete:
        await _deleteGoal(goal);
        return;
    }

    await _refreshGoals();
  }

  Widget _buildBody(
    bool isDark,
    AsyncValue<List<SavingsGoal>> goalsAsync,
    AsyncValue<List<Account>> accountsAsync,
  ) {
    final defaultCurrency =
        ref.watch(defaultCurrencyProvider).value ??
        FinanceSettingsService.fallbackCurrency;

    final content = RefreshIndicator(
      onRefresh: _refreshGoals,
      color: const Color(0xFFCDAF56),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          _buildHeader(isDark),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              child: goalsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(42),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Error loading goals: $error',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ),
                data: (goals) {
                  final accounts = accountsAsync.valueOrNull ?? <Account>[];
                  final accountsById = {for (final a in accounts) a.id: a};
                  final visible = _visibleGoals(goals);

                  final targetByCurrency = <String, double>{};
                  final savedByCurrency = <String, double>{};
                  for (final goal in goals) {
                    targetByCurrency[goal.currency] =
                        (targetByCurrency[goal.currency] ?? 0) +
                        goal.targetAmount;
                    savedByCurrency[goal.currency] =
                        (savedByCurrency[goal.currency] ?? 0) +
                        goal.savedAmount;
                  }

                  final primaryCurrency =
                      targetByCurrency.containsKey(defaultCurrency)
                      ? defaultCurrency
                      : (targetByCurrency.isNotEmpty
                            ? targetByCurrency.keys.first
                            : defaultCurrency);
                  final target = targetByCurrency[primaryCurrency] ?? 0;
                  final saved = savedByCurrency[primaryCurrency] ?? 0;
                  final progress = target > 0
                      ? (saved / target).clamp(0.0, 1.0)
                      : 0.0;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSummaryCard(
                        isDark: isDark,
                        currency: primaryCurrency,
                        target: target,
                        saved: saved,
                        progress: progress,
                        activeCount: goals
                            .where((g) => g.isActive || g.isCompleted)
                            .length,
                      ),
                      const SizedBox(height: 24),
                      _buildQuickActions(isDark),
                      const SizedBox(height: 24),
                      _buildControls(isDark),
                      const SizedBox(height: 32),
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 16),
                        child: Text(
                          'YOUR SAVINGS GOALS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFFCDAF56),
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      if (visible.isEmpty)
                        _buildEmptyState(isDark)
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          itemCount: visible.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final goal = visible[index];
                            return _buildGoalCard(
                              isDark: isDark,
                              goal: goal,
                              account: accountsById[goal.accountId],
                            );
                          },
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

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0D0F14)
          : const Color(0xFFF8F9FC),
      body: isDark ? DarkGradient.wrap(child: content) : content,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final goalsAsync = ref.watch(allSavingsGoalsProvider);
    final accountsAsync = ref.watch(activeAccountsProvider);
    return _buildBody(isDark, goalsAsync, accountsAsync);
  }

  Widget _buildHeader(bool isDark) {
    final topPadding = MediaQuery.of(context).padding.top;
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, topPadding + 16, 20, 24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _headerButton(
                  context,
                  isDark,
                  Icons.arrow_back_ios_new_rounded,
                  () => Navigator.pop(context),
                ),
                Row(
                  children: [
                    _headerButton(
                      context,
                      isDark,
                      Icons.refresh_rounded,
                      _refreshGoals,
                    ),
                    const SizedBox(width: 12),
                    _headerButton(
                      context,
                      isDark,
                      Icons.add_rounded,
                      () => _openGoalEditor(),
                      iconColor: Colors.black,
                      backgroundColor: const Color(0xFFCDAF56),
                      borderColor: Colors.transparent,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Text(
                  'Savings Planner',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required bool isDark,
    required String currency,
    required double target,
    required double saved,
    required double progress,
    required int activeCount,
  }) {
    final symbol = CurrencyUtils.getCurrencySymbol(currency);
    final remaining = (target - saved).clamp(0.0, double.infinity);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: isDark ? const Color(0xFF2D3139) : Colors.white,
        border: Border.all(
          color: const Color(0xFFCDAF56).withOpacity(isDark ? 0.35 : 0.25),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TOTAL SAVED',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$symbol${saved.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF1F2937),
                      height: 1.1,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFCDAF56).withOpacity(0.16),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFCDAF56).withOpacity(0.28),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '$activeCount',
                      style: const TextStyle(
                        color: Color(0xFFCDAF56),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Text(
                      'GOALS',
                      style: TextStyle(
                        color: Color(0xFFCDAF56),
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _summaryItem(
                isDark,
                'Target',
                '$symbol${target.toStringAsFixed(0)}',
              ),
              _summaryItem(
                isDark,
                'Remaining',
                '$symbol${remaining.toStringAsFixed(0)}',
                isHighlight: true,
              ),
              _summaryItem(
                isDark,
                'Progress',
                '${(progress * 100).toStringAsFixed(0)}%',
              ),
            ],
          ),
          const SizedBox(height: 20),
          Stack(
            children: [
              Container(
                height: 12,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCDAF56),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(
    bool isDark,
    String label,
    String value, {
    bool isHighlight = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: isHighlight
                ? const Color(0xFFCDAF56)
                : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildControls(bool isDark) {
    final filterLabel = switch (_filter) {
      _GoalFilter.active => 'Active',
      _GoalFilter.archived => 'Archived',
      _GoalFilter.all => 'All Goals',
    };
    final hasSearch = _searchController.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.1 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _showSearchFilters = !_showSearchFilters);
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.tune_rounded,
                    size: 18,
                    color: Color(0xFFCDAF56),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Search & Filter',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                      ),
                    ),
                  ),
                  Text(
                    hasSearch ? '$filterLabel • Search on' : filterLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _showSearchFilters
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: _showSearchFilters
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search goals...',
                      hintStyle: TextStyle(
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                      isDense: true,
                      filled: true,
                      fillColor: isDark
                          ? Colors.black.withOpacity(0.2)
                          : Colors.black.withOpacity(0.03),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: _GoalFilter.values.map((filter) {
                      final selected = _filter == filter;
                      final label = switch (filter) {
                        _GoalFilter.active => 'Active',
                        _GoalFilter.archived => 'Archived',
                        _GoalFilter.all => 'All Goals',
                      };
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: InkWell(
                            onTap: () {
                              if (_filter == filter) return;
                              HapticFeedback.selectionClick();
                              setState(() => _filter = filter);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              height: 38,
                              decoration: BoxDecoration(
                                color: selected
                                    ? const Color(0xFFCDAF56)
                                    : (isDark
                                          ? Colors.white.withOpacity(0.05)
                                          : Colors.black.withOpacity(0.04)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: selected
                                        ? FontWeight.w900
                                        : FontWeight.w700,
                                    color: selected
                                        ? Colors.black
                                        : (isDark
                                              ? Colors.white54
                                              : Colors.black54),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(bool isDark) {
    Widget action(
      IconData icon,
      String label,
      VoidCallback onTap, {
      Color? color,
    }) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.08),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: (color ?? const Color(0xFFCDAF56)).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: color ?? const Color(0xFFCDAF56),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        action(
          Icons.add_rounded,
          'New Goal',
          () => _openGoalEditor(),
          color: const Color(0xFFCDAF56),
        ),
        const SizedBox(width: 12),
        action(
          Icons.account_balance_wallet_rounded,
          'Accounts',
          () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const AccountsScreen()),
            );
          },
          color: const Color(0xFFCDAF56),
        ),
      ],
    );
  }

  Widget _buildGoalCard({
    required bool isDark,
    required SavingsGoal goal,
    required Account? account,
  }) {
    final symbol = CurrencyUtils.getCurrencySymbol(goal.currency);
    final statusColor = _statusColor(goal);
    final accentColor = goal.color;
    final onAccentColor =
        ThemeData.estimateBrightnessForColor(accentColor) == Brightness.dark
        ? Colors.white
        : const Color(0xFF1E1E1E);
    final actions = <PopupMenuEntry<_GoalAction>>[
      const PopupMenuItem(value: _GoalAction.edit, child: Text('Edit Goal')),
      if (!goal.isArchived)
        const PopupMenuItem(value: _GoalAction.add, child: Text('Add Saving')),
      if (goal.isActive)
        const PopupMenuItem(
          value: _GoalAction.fail,
          child: Text('Mark Failed'),
        ),
      if (!goal.isClosed && !goal.isFailed)
        const PopupMenuItem(
          value: _GoalAction.close,
          child: Text('Close Goal'),
        ),
      if (goal.isArchived)
        const PopupMenuItem(
          value: _GoalAction.reopen,
          child: Text('Reopen Goal'),
        ),
      const PopupMenuDivider(),
      const PopupMenuItem(value: _GoalAction.delete, child: Text('Delete')),
    ];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: isDark ? const Color(0xFF1E2330) : Colors.white,
        border: Border.all(
          color: accentColor.withOpacity(isDark ? 0.26 : 0.18),
          width: 1.2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openGoalDetails(goal),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: accentColor.withOpacity(0.32),
                          ),
                        ),
                        child: Icon(
                          goal.icon ?? Icons.savings_rounded,
                          color: accentColor,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              goal.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1F2937),
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  Icons.event_rounded,
                                  size: 12,
                                  color: isDark
                                      ? Colors.white38
                                      : Colors.black38,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat(
                                    'MMM d, yyyy',
                                  ).format(goal.targetDate),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.black45,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: accentColor.withOpacity(
                                      isDark ? 0.2 : 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: accentColor.withOpacity(
                                        isDark ? 0.36 : 0.24,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: statusColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _statusText(goal),
                                        style: TextStyle(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w800,
                                          color: accentColor,
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
                      PopupMenuButton<_GoalAction>(
                        icon: Icon(
                          Icons.more_horiz_rounded,
                          color: isDark ? Colors.white54 : Colors.black38,
                        ),
                        onSelected: (action) => _setGoalState(goal, action),
                        itemBuilder: (_) => actions,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SAVED',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                          Text(
                            _money(goal.currency, goal.savedAmount),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1F2937),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: accentColor.withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          '${(goal.progressFraction * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: accentColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Stack(
                    children: [
                      Container(
                        height: 8,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: goal.progressFraction.clamp(0.0, 1.0),
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: accentColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _cadenceChip(
                          isDark,
                          'Weekly',
                          '$symbol${goal.requiredPerWeek.toStringAsFixed(0)}',
                          accentColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _cadenceChip(
                          isDark,
                          'Monthly',
                          '$symbol${goal.requiredPerMonth.toStringAsFixed(0)}',
                          accentColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => _openGoalDetails(goal),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isDark ? Colors.white10 : Colors.black12,
                              ),
                            ),
                          ),
                          child: Text(
                            'Details',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: goal.isArchived
                              ? null
                              : () => _openContributionEditor(goal: goal),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            foregroundColor: onAccentColor,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Add Saving',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cadenceChip(bool isDark, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(isDark ? 0.3 : 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openGoalDetails(SavingsGoal goal) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => _SavingsGoalDetailScreen(goalId: goal.id),
      ),
    );
    if (changed == true) {
      await _refreshGoals();
    }
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.08),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFCDAF56).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.savings_rounded,
              size: 40,
              color: const Color(0xFFCDAF56).withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No savings goals yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start planning your future by creating your\nfirst savings goal today.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.5,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: 200,
            child: ElevatedButton(
              onPressed: () => _openGoalEditor(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCDAF56),
                foregroundColor: Colors.black,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Create Goal',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SavingsGoalDetailScreen extends ConsumerStatefulWidget {
  final String goalId;

  const _SavingsGoalDetailScreen({required this.goalId});

  @override
  ConsumerState<_SavingsGoalDetailScreen> createState() =>
      _SavingsGoalDetailScreenState();
}

class _SavingsGoalDetailScreenState
    extends ConsumerState<_SavingsGoalDetailScreen> {
  Future<void> _refreshData() async {
    ref.invalidate(allSavingsGoalsProvider);
    ref.invalidate(activeSavingsGoalsProvider);
    ref.invalidate(archivedSavingsGoalsProvider);
    ref.invalidate(savingsGoalsSummaryProvider);
  }

  String _money(String currency, double amount) {
    final symbol = CurrencyUtils.getCurrencySymbol(currency);
    return '$symbol${amount.toStringAsFixed(2)}';
  }

  Color _statusColor(SavingsGoal goal) {
    if (goal.isCompleted) return const Color(0xFF4CAF50);
    if (goal.isFailed) return const Color(0xFFEF5350);
    if (goal.isClosed) return const Color(0xFFFF9800);
    if (goal.isOverdue) return const Color(0xFFF44336);
    return const Color(0xFFCDAF56);
  }

  Future<void> _openGoalEditor(SavingsGoal goal) async {
    final defaultCurrency =
        ref.read(defaultCurrencyProvider).value ??
        FinanceSettingsService.fallbackCurrency;
    final accounts =
        ref.read(activeAccountsProvider).valueOrNull ?? <Account>[];

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _GoalEditorSheet(
        goal: goal,
        accounts: accounts,
        defaultCurrency: defaultCurrency,
      ),
    );

    if (saved == true) {
      await _refreshData();
    }
  }

  Future<void> _openContributionEditor({
    required SavingsGoal goal,
    SavingsContributionEntry? entry,
  }) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ContributionSheet(goal: goal, entry: entry),
    );

    if (saved == true) {
      await _refreshData();
    }
  }

  Future<void> _undoContribution(
    SavingsGoal goal,
    SavingsContributionEntry entry,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Undo Saving'),
        content: Text('Remove ${_money(goal.currency, entry.amount)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Undo'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await ref
        .read(savingsGoalRepositoryProvider)
        .undoContribution(goalId: goal.id, contributionId: entry.id);
    await _refreshData();
  }

  Future<void> _deleteGoal(SavingsGoal goal) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Goal'),
        content: Text('Delete "${goal.name}" permanently?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await ref.read(savingsGoalRepositoryProvider).deleteGoal(goal.id);
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _setGoalState(SavingsGoal goal, _GoalAction action) async {
    final repo = ref.read(savingsGoalRepositoryProvider);

    switch (action) {
      case _GoalAction.edit:
        await _openGoalEditor(goal);
        return;
      case _GoalAction.add:
        await _openContributionEditor(goal: goal);
        return;
      case _GoalAction.fail:
        await repo.markGoalFailed(goal.id, reason: 'Marked as failed');
        break;
      case _GoalAction.close:
        await repo.closeGoal(goal.id, reason: 'Closed by user');
        break;
      case _GoalAction.reopen:
        await repo.reopenGoal(goal.id);
        break;
      case _GoalAction.delete:
        await _deleteGoal(goal);
        return;
    }

    await _refreshData();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final goalsAsync = ref.watch(allSavingsGoalsProvider);
    final accountsAsync = ref.watch(activeAccountsProvider);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0D0F14)
          : const Color(0xFFF8F9FC),
      body: isDark
          ? DarkGradient.wrap(
              child: _buildBody(isDark, goalsAsync, accountsAsync),
            )
          : _buildBody(isDark, goalsAsync, accountsAsync),
      floatingActionButton: goalsAsync.whenOrNull(
        data: (goals) {
          SavingsGoal? goal;
          try {
            goal = goals.firstWhere((item) => item.id == widget.goalId);
          } catch (_) {
            goal = null;
          }
          if (goal == null || goal.isArchived) return null;
          final accentColor = goal.color;
          final onAccentColor =
              ThemeData.estimateBrightnessForColor(accentColor) ==
                  Brightness.dark
              ? Colors.white
              : const Color(0xFF1E1E1E);
          return FloatingActionButton.extended(
            onPressed: () => _openContributionEditor(goal: goal!),
            backgroundColor: accentColor,
            foregroundColor: onAccentColor,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Saving'),
          );
        },
      ),
    );
  }

  Widget _buildBody(
    bool isDark,
    AsyncValue<List<SavingsGoal>> goalsAsync,
    AsyncValue<List<Account>> accountsAsync,
  ) {
    return goalsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Error loading goal: $error',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
        ),
      ),
      data: (goals) {
        SavingsGoal? goal;
        try {
          goal = goals.firstWhere((item) => item.id == widget.goalId);
        } catch (_) {
          goal = null;
        }
        if (goal == null) {
          return Center(
            child: Text(
              'Goal not found',
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
            ),
          );
        }
        final currentGoal = goal;
        final statusColor = _statusColor(currentGoal);

        final actions = <PopupMenuEntry<_GoalAction>>[
          const PopupMenuItem(
            value: _GoalAction.edit,
            child: Text('Edit Goal'),
          ),
          if (!currentGoal.isArchived)
            const PopupMenuItem(
              value: _GoalAction.add,
              child: Text('Add Saving'),
            ),
          if (currentGoal.isActive)
            const PopupMenuItem(
              value: _GoalAction.fail,
              child: Text('Mark Failed'),
            ),
          if (!currentGoal.isClosed && !currentGoal.isFailed)
            const PopupMenuItem(
              value: _GoalAction.close,
              child: Text('Close Goal'),
            ),
          if (currentGoal.isArchived)
            const PopupMenuItem(
              value: _GoalAction.reopen,
              child: Text('Reopen Goal'),
            ),
          const PopupMenuDivider(),
          const PopupMenuItem(value: _GoalAction.delete, child: Text('Delete')),
        ];

        return RefreshIndicator(
          onRefresh: _refreshData,
          color: const Color(0xFFCDAF56),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    MediaQuery.of(context).padding.top + 16,
                    20,
                    24,
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _headerButton(
                            context,
                            isDark,
                            Icons.arrow_back_ios_new_rounded,
                            () => Navigator.of(context).pop(),
                          ),
                          Row(
                            children: [
                              _headerButton(
                                context,
                                isDark,
                                Icons.edit_rounded,
                                () => _openGoalEditor(currentGoal),
                              ),
                              const SizedBox(width: 12),
                              PopupMenuButton<_GoalAction>(
                                onSelected: (action) =>
                                    _setGoalState(currentGoal, action),
                                itemBuilder: (_) => actions,
                                child: _headerButton(
                                  context,
                                  isDark,
                                  Icons.more_horiz_rounded,
                                  () {}, // Handled by PopupMenuButton
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(32),
                          color: isDark
                              ? const Color(0xFF1E2330)
                              : Colors.white,
                          border: Border.all(
                            color: currentGoal.color.withOpacity(
                              isDark ? 0.4 : 0.2,
                            ),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: currentGoal.color.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: currentGoal.color.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Icon(
                                    currentGoal.icon ?? Icons.savings_rounded,
                                    color: currentGoal.color,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        currentGoal.name,
                                        style: TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.5,
                                          color: isDark
                                              ? Colors.white
                                              : const Color(0xFF1F2937),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: currentGoal.color.withOpacity(
                                            0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: currentGoal.color
                                                .withOpacity(0.28),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 6,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                color: statusColor,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              _statusText(
                                                currentGoal,
                                              ).toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 0.5,
                                                color: currentGoal.color,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (currentGoal.description?.trim().isNotEmpty ==
                                true) ...[
                              const SizedBox(height: 20),
                              Text(
                                currentGoal.description!.trim(),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  height: 1.5,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black87,
                                ),
                              ),
                            ],
                            const SizedBox(height: 32),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'CURRENTLY SAVED',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.2,
                                        color: isDark
                                            ? Colors.white38
                                            : Colors.black38,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _money(
                                        currentGoal.currency,
                                        currentGoal.savedAmount,
                                      ),
                                      style: TextStyle(
                                        fontSize: 42,
                                        fontWeight: FontWeight.w900,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF1F2937),
                                        height: 1,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: currentGoal.color.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${(currentGoal.progressFraction * 100).toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: currentGoal.color,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Stack(
                              children: [
                                Container(
                                  height: 14,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withOpacity(0.05)
                                        : Colors.black.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                ),
                                FractionallySizedBox(
                                  widthFactor: currentGoal.progressFraction
                                      .clamp(0.0, 1.0),
                                  child: Container(
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: currentGoal.color,
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _detailItem(
                                  isDark,
                                  'Target',
                                  _money(
                                    currentGoal.currency,
                                    currentGoal.targetAmount,
                                  ),
                                ),
                                _detailItem(
                                  isDark,
                                  'Remaining',
                                  _money(
                                    currentGoal.currency,
                                    currentGoal.remainingAmount,
                                  ),
                                  isHighlight: true,
                                  highlightColor: currentGoal.color,
                                ),
                                _detailItem(
                                  isDark,
                                  'Time Left',
                                  currentGoal.isOverdue
                                      ? 'Overdue'
                                      : '${currentGoal.daysRemaining}d',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 16),
                        child: Text(
                          'SAVING PLAN',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFFCDAF56),
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 2.2,
                        children: [
                          _planTile(
                            currentGoal,
                            'Daily',
                            currentGoal.requiredPerDay,
                          ),
                          _planTile(
                            currentGoal,
                            'Weekly',
                            currentGoal.requiredPerWeek,
                          ),
                          _planTile(
                            currentGoal,
                            'Monthly',
                            currentGoal.requiredPerMonth,
                          ),
                          _planTile(
                            currentGoal,
                            'Quarterly',
                            currentGoal.requiredPerQuarter,
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 16),
                        child: Text(
                          'CONTRIBUTION HISTORY',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFFCDAF56),
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      if (currentGoal.contributionHistory.isEmpty)
                        _buildEmptyHistory(isDark)
                      else
                        ...currentGoal.contributionHistory.reversed.map((
                          entry,
                        ) {
                          return _buildHistoryItem(isDark, currentGoal, entry);
                        }),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailItem(
    bool isDark,
    String label,
    String value, {
    bool isHighlight = false,
    Color? highlightColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: isHighlight
                ? (highlightColor ?? const Color(0xFFCDAF56))
                : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyHistory(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.08),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.history_rounded,
            size: 48,
            color: isDark ? Colors.white12 : Colors.black12,
          ),
          const SizedBox(height: 12),
          Text(
            'No contributions yet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(
    bool isDark,
    SavingsGoal goal,
    SavingsContributionEntry entry,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2330) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: goal.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: goal.color.withOpacity(0.24)),
            ),
            child: Icon(Icons.add_chart_rounded, color: goal.color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _money(goal.currency, entry.amount),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: goal.color,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  DateFormat(
                    'MMM d, yyyy - hh:mm a',
                  ).format(entry.contributedAt),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white38 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () =>
                    _openContributionEditor(goal: goal, entry: entry),
                icon: Icon(
                  Icons.edit_rounded,
                  size: 18,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
              IconButton(
                onPressed: () => _undoContribution(goal, entry),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: Colors.redAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _planTile(SavingsGoal goal, String label, double amount) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2330) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: goal.color.withOpacity(isDark ? 0.26 : 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _money(goal.currency, amount),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: goal.color,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContributionSheet extends ConsumerStatefulWidget {
  final SavingsGoal goal;
  final SavingsContributionEntry? entry;

  const _ContributionSheet({required this.goal, this.entry});

  @override
  ConsumerState<_ContributionSheet> createState() => _ContributionSheetState();
}

class _ContributionSheetState extends ConsumerState<_ContributionSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late DateTime _date;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.entry?.amount.toStringAsFixed(2) ?? '',
    );
    _noteController = TextEditingController(text: widget.entry?.note ?? '');
    _date = widget.entry?.contributedAt ?? DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final amount = double.parse(_amountController.text.trim());
    final note = _noteController.text.trim().isEmpty
        ? null
        : _noteController.text.trim();

    setState(() => _isSaving = true);
    final repo = ref.read(savingsGoalRepositoryProvider);
    if (widget.entry == null) {
      await repo.addContribution(
        goalId: widget.goal.id,
        amount: amount,
        contributedAt: _date,
        note: note,
      );
    } else {
      await repo.updateContribution(
        goalId: widget.goal.id,
        contributionId: widget.entry!.id,
        amount: amount,
        contributedAt: _date,
        note: note,
      );
    }

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final symbol = CurrencyUtils.getCurrencySymbol(widget.goal.currency);

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.only(bottom: bottom),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1F26) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.entry == null ? 'Add Saving' : 'Edit Saving',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixText: '$symbol ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  validator: (value) {
                    final number = double.tryParse(value?.trim() ?? '');
                    if (number == null || number <= 0) {
                      return 'Enter a valid amount';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date'),
                  subtitle: Text(DateFormat('EEE, MMM d, yyyy').format(_date)),
                  trailing: const Icon(Icons.calendar_today_rounded),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() => _date = picked);
                    }
                  },
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _noteController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Note (optional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSaving
                            ? null
                            : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: _isSaving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF00BFA5),
                        ),
                        child: Text(_isSaving ? 'Saving...' : 'Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoalEditorSheet extends ConsumerStatefulWidget {
  final SavingsGoal? goal;
  final List<Account> accounts;
  final String defaultCurrency;

  const _GoalEditorSheet({
    required this.goal,
    required this.accounts,
    required this.defaultCurrency,
  });

  @override
  ConsumerState<_GoalEditorSheet> createState() => _GoalEditorSheetState();
}

class _GoalEditorSheetState extends ConsumerState<_GoalEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _targetController;
  late final TextEditingController _initialController;
  late final TextEditingController _descriptionController;

  late DateTime _startDate;
  late DateTime _targetDate;
  late String _currency;
  late IconData _selectedIcon;
  late Color _selectedColor;
  String? _accountId;
  bool _isSaving = false;

  bool get _isEdit => widget.goal != null;

  @override
  void initState() {
    super.initState();
    final goal = widget.goal;
    _nameController = TextEditingController(text: goal?.name ?? '');
    _targetController = TextEditingController(
      text: goal == null ? '' : goal.targetAmount.toStringAsFixed(2),
    );
    _initialController = TextEditingController(
      text: goal == null ? '' : goal.savedAmount.toStringAsFixed(2),
    );
    _descriptionController = TextEditingController(
      text: goal?.description ?? '',
    );
    _startDate = goal?.startDate ?? DateTime.now();
    _targetDate =
        goal?.targetDate ?? DateTime.now().add(const Duration(days: 365));
    _currency = goal?.currency ?? widget.defaultCurrency;
    _selectedIcon = goal?.icon ?? Icons.savings_rounded;
    _selectedColor = goal?.color ?? const Color(0xFF00BFA5);
    _accountId = goal?.accountId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _initialController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _showIconPicker(bool isDark) async {
    final icon = await showDialog<IconData>(
      context: context,
      builder: (context) =>
          IconPickerWidget(selectedIcon: _selectedIcon, isDark: isDark),
    );
    if (icon != null) {
      setState(() => _selectedIcon = icon);
    }
  }

  Future<void> _showColorPicker(bool isDark) async {
    final color = await showDialog<Color>(
      context: context,
      builder: (context) =>
          ColorPickerWidget(selectedColor: _selectedColor, isDark: isDark),
    );
    if (color != null) {
      setState(() => _selectedColor = color);
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final start = DateTime(_startDate.year, _startDate.month, _startDate.day);
    final end = DateTime(_targetDate.year, _targetDate.month, _targetDate.day);
    if (end.isBefore(start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Target date must be after start date')),
      );
      return;
    }

    final target = double.parse(_targetController.text.trim());
    final initial = _isEdit
        ? 0.0
        : (double.tryParse(_initialController.text.trim()) ?? 0);

    setState(() => _isSaving = true);
    final repo = ref.read(savingsGoalRepositoryProvider);

    if (!_isEdit) {
      final goal = SavingsGoal(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        targetAmount: target,
        savedAmount: 0,
        currency: _currency,
        startDate: _startDate,
        targetDate: _targetDate,
        accountId: _accountId,
        icon: _selectedIcon,
        colorValue: _selectedColor.toARGB32(),
      );

      if (initial > 0) {
        goal.addContribution(
          initial,
          contributedAt: _startDate,
          note: 'Initial saved amount',
        );
      }

      await repo.createGoal(goal);
    } else {
      final current = widget.goal!;
      await repo.updateGoal(
        current.copyWith(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          targetAmount: target,
          currency: _currency,
          startDate: _startDate,
          targetDate: _targetDate,
          accountId: _accountId,
          iconCodePoint: _selectedIcon.codePoint,
          iconFontFamily: _selectedIcon.fontFamily,
          iconFontPackage: _selectedIcon.fontPackage,
          colorValue: _selectedColor.toARGB32(),
        ),
      );
    }

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.only(bottom: bottom),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1F26) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Text(
                    _isEdit ? 'Edit Goal' : 'Create Goal',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Goal name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    validator: (value) {
                      if ((value?.trim().isEmpty ?? true)) {
                        return 'Enter goal name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.04)
                          : Colors.black.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.08)
                            : Colors.black.withOpacity(0.08),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _selectedColor.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedColor.withOpacity(0.45),
                            ),
                          ),
                          child: Icon(
                            _selectedIcon,
                            color: _selectedColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Appearance',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _showIconPicker(isDark),
                          icon: const Icon(Icons.apps_rounded, size: 18),
                          label: const Text('Icon'),
                        ),
                        TextButton.icon(
                          onPressed: () => _showColorPicker(isDark),
                          icon: const Icon(Icons.palette_rounded, size: 18),
                          label: const Text('Color'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _targetController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Target amount',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    validator: (value) {
                      final n = double.tryParse(value?.trim() ?? '');
                      if (n == null || n <= 0) return 'Enter valid amount';
                      return null;
                    },
                  ),
                  if (!_isEdit) ...[
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _initialController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Already saved (optional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _currency,
                          decoration: InputDecoration(
                            labelText: 'Currency',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          items: FinanceSettingsService.supportedCurrencies
                              .map(
                                (c) =>
                                    DropdownMenuItem(value: c, child: Text(c)),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _currency = value);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          value: _accountId,
                          decoration: InputDecoration(
                            labelText: 'Account',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('None'),
                            ),
                            ...widget.accounts.map(
                              (a) => DropdownMenuItem<String?>(
                                value: a.id,
                                child: Text(a.name),
                              ),
                            ),
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
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Start date'),
                    subtitle: Text(
                      DateFormat('MMM d, yyyy').format(_startDate),
                    ),
                    trailing: const Icon(Icons.calendar_today_rounded),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _startDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => _startDate = picked);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Target date'),
                    subtitle: Text(
                      DateFormat('MMM d, yyyy').format(_targetDate),
                    ),
                    trailing: const Icon(Icons.event_available_rounded),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _targetDate,
                        firstDate: _startDate,
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => _targetDate = picked);
                    },
                  ),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Notes (optional)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSaving
                              ? null
                              : () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: _isSaving ? null : _save,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFCDAF56),
                            foregroundColor: Colors.black,
                          ),
                          child: Text(_isSaving ? 'Saving...' : 'Save'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
