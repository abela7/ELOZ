import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/dark_gradient.dart';
import '../../../../core/widgets/date_navigator_widget.dart';
import '../../data/models/transaction.dart';
import '../../data/models/transaction_category.dart';
import '../../data/services/finance_settings_service.dart';
import '../../utils/currency_utils.dart';
import '../../utils/expense_range_utils.dart';
import '../providers/finance_providers.dart';
import 'add_transaction_screen.dart';

/// Grouping modes for the income list.
enum _GroupBy { none, category, day, week, month, year }

/// All Income List Screen – view all income in list/grid with filters,
/// grouping, and tap-to-view/edit/delete.
class AllIncomeListScreen extends ConsumerStatefulWidget {
  const AllIncomeListScreen({super.key});

  @override
  ConsumerState<AllIncomeListScreen> createState() =>
      _AllIncomeListScreenState();
}

class _AllIncomeListScreenState extends ConsumerState<AllIncomeListScreen> {
  bool _isListView = true;
  ExpenseRangeView _rangeView = ExpenseRangeView.month;
  DateTime _selectedDate = ExpenseRangeUtils.normalizeDate(DateTime.now());
  _GroupBy _groupBy = _GroupBy.day;
  String? _selectedCategoryId;
  final Set<String> _selectedIds = {};

  static const Color _accentColor = Color(0xFF4CAF50);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final transactionsAsync = ref.watch(allTransactionsProvider);
    final categoriesAsync = ref.watch(incomeTransactionCategoriesProvider);
    final defaultCurrencyAsync = ref.watch(defaultCurrencyProvider);
    final defaultCurrency =
        defaultCurrencyAsync.value ?? FinanceSettingsService.fallbackCurrency;
    final categories = categoriesAsync.valueOrNull ?? [];

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0D0F14)
          : const Color(0xFFF8F9FC),
      bottomNavigationBar: _selectedIds.isNotEmpty
          ? _buildBulkActionBar(isDark)
          : null,
      body: isDark
          ? DarkGradient.wrap(
              child: _buildBody(
                context,
                isDark,
                transactionsAsync,
                categories,
                defaultCurrency,
              ),
            )
          : _buildBody(
              context,
              isDark,
              transactionsAsync,
              categories,
              defaultCurrency,
            ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    bool isDark,
    AsyncValue<List<Transaction>> transactionsAsync,
    List<TransactionCategory> categories,
    String defaultCurrency,
  ) {
    return SafeArea(
      top: true,
      child: Column(
        children: [
          _buildAppBar(context, isDark),
          Expanded(
            child: transactionsAsync.when(
              data: (all) {
                final filtered = _filterIncome(all);
                final grouped = _groupTransactions(filtered, categories);
                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _buildFilters(isDark, categories),
                    ),
                    if (filtered.isEmpty)
                      SliverFillRemaining(child: _buildEmptyState(isDark))
                    else
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          child: _buildGroupedContent(
                            isDark,
                            grouped,
                            defaultCurrency,
                            categories,
                          ),
                        ),
                      ),
                  ],
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

  Widget _buildAppBar(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (_selectedIds.isNotEmpty) {
                setState(() => _selectedIds.clear());
              } else {
                Navigator.pop(context);
              }
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.06),
                ),
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                size: 20,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
          const Spacer(),
          _buildViewToggle(isDark),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () async {
              HapticFeedback.mediumImpact();
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (c) => AddTransactionScreen(initialType: 'income'),
                ),
              );
              ref.invalidate(allTransactionsProvider);
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _accentColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _accentColor.withOpacity(0.3)),
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
    );
  }

  Widget _buildBulkActionBar(bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: 12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D23) : Colors.white,
        border: Border(
          top: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedIds.clear());
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white70 : Colors.black87,
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _performBulkDelete,
                icon: const Icon(Icons.delete_rounded, size: 20),
                label: Text('Delete (${_selectedIds.length})'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewToggle(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _viewModeButton(isDark, true, Icons.list_rounded),
          _viewModeButton(isDark, false, Icons.grid_view_rounded),
        ],
      ),
    );
  }

  Widget _viewModeButton(bool isDark, bool isList, IconData icon) {
    final selected = _isListView == isList;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _isListView = isList);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _accentColor.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 20,
          color: selected
              ? _accentColor
              : (isDark ? Colors.white38 : Colors.black38),
        ),
      ),
    );
  }

  Widget _buildFilters(bool isDark, List<TransactionCategory> categories) {
    final range = ExpenseRangeUtils.rangeFor(_selectedDate, _rangeView);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DateNavigatorWidget(
            selectedDate: _selectedDate,
            onDateChanged: (d) {
              setState(
                () => _selectedDate = ExpenseRangeUtils.normalizeDate(d),
              );
            },
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _rangeChip(isDark, ExpenseRangeView.day, 'Day'),
                const SizedBox(width: 8),
                _rangeChip(isDark, ExpenseRangeView.week, 'Week'),
                const SizedBox(width: 8),
                _rangeChip(isDark, ExpenseRangeView.month, 'Month'),
                const SizedBox(width: 8),
                _rangeChip(isDark, ExpenseRangeView.year, 'Year'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _formatRangeLabel(range),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            value: _selectedCategoryId,
            decoration: InputDecoration(
              filled: true,
              fillColor: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            hint: const Text('All categories'),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('All categories'),
              ),
              ...categories.map(
                (c) => DropdownMenuItem<String?>(
                  value: c.id,
                  child: Row(
                    children: [
                      Icon(
                        c.icon ?? Icons.category_rounded,
                        size: 18,
                        color: c.color,
                      ),
                      const SizedBox(width: 8),
                      Text(c.name, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ),
            ],
            onChanged: (v) {
              HapticFeedback.selectionClick();
              setState(() => _selectedCategoryId = v);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<_GroupBy>(
            value: _groupBy,
            decoration: InputDecoration(
              filled: true,
              fillColor: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            items: const [
              DropdownMenuItem(
                value: _GroupBy.none,
                child: Text('No grouping'),
              ),
              DropdownMenuItem(
                value: _GroupBy.category,
                child: Text('By category'),
              ),
              DropdownMenuItem(value: _GroupBy.day, child: Text('By day')),
              DropdownMenuItem(value: _GroupBy.week, child: Text('By week')),
              DropdownMenuItem(value: _GroupBy.month, child: Text('By month')),
              DropdownMenuItem(value: _GroupBy.year, child: Text('By year')),
            ],
            onChanged: (v) {
              if (v != null) {
                HapticFeedback.selectionClick();
                setState(() => _groupBy = v);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _rangeChip(bool isDark, ExpenseRangeView view, String label) {
    final selected = _rangeView == view;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _rangeView = view);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? _accentColor.withOpacity(0.2)
              : (isDark
                    ? Colors.white.withOpacity(0.04)
                    : Colors.black.withOpacity(0.04)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected
                ? _accentColor
                : (isDark ? Colors.white60 : Colors.black54),
          ),
        ),
      ),
    );
  }

  String _formatRangeLabel(ExpenseRange range) {
    switch (_rangeView) {
      case ExpenseRangeView.day:
        return DateFormat('EEE, MMM d, yyyy').format(range.start);
      case ExpenseRangeView.week:
        return '${DateFormat('MMM d').format(range.start)} - '
            '${DateFormat('MMM d, yyyy').format(range.end)}';
      case ExpenseRangeView.month:
        return DateFormat('MMMM yyyy').format(range.start);
      case ExpenseRangeView.sixMonths:
        return '${DateFormat('MMM yyyy').format(range.start)} - '
            '${DateFormat('MMM yyyy').format(range.end)}';
      case ExpenseRangeView.year:
        return '${DateFormat('MMM yyyy').format(range.start)} - '
            '${DateFormat('MMM yyyy').format(range.end)}';
    }
  }

  List<Transaction> _filterIncome(List<Transaction> all) {
    final range = ExpenseRangeUtils.rangeFor(_selectedDate, _rangeView);
    var filtered = ExpenseRangeUtils.filterIncomesForRange(all, range: range);
    if (_selectedCategoryId != null) {
      filtered = filtered
          .where((t) => t.categoryId == _selectedCategoryId)
          .toList();
    }
    filtered.sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
    return filtered;
  }

  Map<String, List<Transaction>> _groupTransactions(
    List<Transaction> filtered,
    List<TransactionCategory> categories,
  ) {
    if (_groupBy == _GroupBy.none) {
      return {'': filtered};
    }

    TransactionCategory? _catFor(String? id) {
      if (id == null) return null;
      for (final c in categories) {
        if (c.id == id) return c;
      }
      return null;
    }

    final map = <String, List<Transaction>>{};
    for (final t in filtered) {
      String key;
      switch (_groupBy) {
        case _GroupBy.category:
          key = _catFor(t.categoryId)?.name ?? 'Uncategorized';
          break;
        case _GroupBy.day:
          key = DateFormat('EEE, MMM d').format(t.transactionDate);
          break;
        case _GroupBy.week:
          final start = ExpenseRangeUtils.startOfWeek(t.transactionDate);
          key = '${DateFormat('MMM d').format(start)} week';
          break;
        case _GroupBy.month:
          key = DateFormat('MMMM yyyy').format(t.transactionDate);
          break;
        case _GroupBy.year:
          key = t.transactionDate.year.toString();
          break;
        default:
          key = '';
      }
      map.putIfAbsent(key, () => []).add(t);
    }

    final keys = map.keys.toList();
    keys.sort((a, b) {
      if (_groupBy == _GroupBy.category) return a.compareTo(b);
      if (_groupBy == _GroupBy.day ||
          _groupBy == _GroupBy.week ||
          _groupBy == _GroupBy.month ||
          _groupBy == _GroupBy.year) {
        final aFirst = map[a]!.first.transactionDate;
        final bFirst = map[b]!.first.transactionDate;
        return bFirst.compareTo(aFirst);
      }
      return 0;
    });

    return {for (final k in keys) k: map[k]!};
  }

  Widget _buildGroupedContent(
    bool isDark,
    Map<String, List<Transaction>> grouped,
    String defaultCurrency,
    List<TransactionCategory> categories,
  ) {
    final entries = grouped.entries.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: entries.expand((e) {
        final header = e.key.isNotEmpty
            ? Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 12),
                child: Row(
                  children: [
                    Text(
                      e.key.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF4CAF50),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _accentColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${e.value.length}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF4CAF50),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : const SizedBox.shrink();
        final items = _isListView
            ? e.value
                  .map(
                    (t) =>
                        _buildListTile(isDark, t, defaultCurrency, categories),
                  )
                  .toList()
            : [
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.0,
                  children: e.value
                      .map(
                        (t) => _buildGridCard(
                          isDark,
                          t,
                          defaultCurrency,
                          categories,
                        ),
                      )
                      .toList(),
                ),
              ];
        return [header, ...items];
      }).toList(),
    );
  }

  Future<void> _performBulkDelete() async {
    if (_selectedIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Selected'),
        content: Text(
          'Delete ${_selectedIds.length} income item(s)? Account balances will be updated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final all = await ref.read(allTransactionsProvider.future);
    final toDelete = all.where((t) => _selectedIds.contains(t.id)).toList();
    final balanceService = ref.read(transactionBalanceServiceProvider);
    final transactionRepo = ref.read(transactionRepositoryProvider);
    final budgetTracker = ref.read(budgetTrackerServiceProvider);
    final dailyBalanceService = ref.read(dailyBalanceServiceProvider);

    for (final t in toDelete) {
      await balanceService.reverseTransactionImpact(t);
      await transactionRepo.deleteTransaction(t.id);
      await dailyBalanceService.invalidateFromDate(t.transactionDate);
    }
    await budgetTracker.updateAllBudgetSpending();

    setState(() => _selectedIds.clear());
    _invalidateAll();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${toDelete.length} income item(s) deleted'),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _onItemLongPress(Transaction t) {
    HapticFeedback.mediumImpact();
    setState(() {
      if (_selectedIds.contains(t.id)) {
        _selectedIds.remove(t.id);
      } else {
        _selectedIds.add(t.id);
      }
    });
  }

  void _onItemTap(
    Transaction t,
    String defaultCurrency,
    List<TransactionCategory> categories,
  ) {
    if (_selectedIds.isNotEmpty) {
      setState(() {
        if (_selectedIds.contains(t.id)) {
          _selectedIds.remove(t.id);
        } else {
          _selectedIds.add(t.id);
        }
      });
    } else {
      _showIncomeDetail(t, defaultCurrency, categories);
    }
  }

  TransactionCategory? _categoryFor(
    List<TransactionCategory> categories,
    String? categoryId,
  ) {
    if (categoryId == null) return null;
    for (final c in categories) {
      if (c.id == categoryId) return c;
    }
    return null;
  }

  Widget _buildListTile(
    bool isDark,
    Transaction t,
    String defaultCurrency,
    List<TransactionCategory> categories,
  ) {
    final cat = _categoryFor(categories, t.categoryId);
    final color = cat != null ? Color(cat.colorValue) : _accentColor;
    final symbol = CurrencyUtils.getCurrencySymbol(
      t.currency ?? defaultCurrency,
    );

    return Dismissible(
      key: Key(t.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(t),
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 24),
      ),
      child: GestureDetector(
        onLongPress: () => _onItemLongPress(t),
        onTap: () => _onItemTap(t, defaultCurrency, categories),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _selectedIds.contains(t.id)
                ? (isDark
                      ? _accentColor.withOpacity(0.08)
                      : _accentColor.withOpacity(0.06))
                : (isDark ? Colors.white.withOpacity(0.03) : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _selectedIds.contains(t.id)
                  ? _accentColor.withOpacity(0.4)
                  : (isDark
                        ? Colors.white.withOpacity(0.04)
                        : Colors.black.withOpacity(0.03)),
            ),
          ),
          child: Row(
            children: [
              if (_selectedIds.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(
                    _selectedIds.contains(t.id)
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 24,
                    color: _selectedIds.contains(t.id)
                        ? _accentColor
                        : (isDark ? Colors.white38 : Colors.black38),
                  ),
                ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  cat?.icon ?? Icons.category_rounded,
                  size: 24,
                  color: color,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${DateFormat('MMM d').format(t.transactionDate)} • '
                      '${cat?.name ?? 'Uncategorized'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white38 : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '+$symbol${t.amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF4CAF50),
                ),
              ),
              if (_selectedIds.isEmpty) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: isDark ? Colors.white24 : Colors.black26,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridCard(
    bool isDark,
    Transaction t,
    String defaultCurrency,
    List<TransactionCategory> categories,
  ) {
    final cat = _categoryFor(categories, t.categoryId);
    final color = cat != null ? Color(cat.colorValue) : _accentColor;
    final symbol = CurrencyUtils.getCurrencySymbol(
      t.currency ?? defaultCurrency,
    );

    final isSelected = _selectedIds.contains(t.id);
    return GestureDetector(
      onLongPress: () => _onItemLongPress(t),
      onTap: () => _onItemTap(t, defaultCurrency, categories),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                    ? _accentColor.withOpacity(0.08)
                    : _accentColor.withOpacity(0.06))
              : (isDark ? Colors.white.withOpacity(0.03) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? _accentColor.withOpacity(0.4)
                : color.withOpacity(isDark ? 0.2 : 0.15),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (_selectedIds.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      isSelected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 20,
                      color: isSelected
                          ? _accentColor
                          : (isDark ? Colors.white38 : Colors.black38),
                    ),
                  ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    cat?.icon ?? Icons.category_rounded,
                    size: 18,
                    color: color,
                  ),
                ),
                const Spacer(),
                if (_selectedIds.isEmpty)
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: isDark ? Colors.white24 : Colors.black26,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              t.title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1E1E1E),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              DateFormat('MMM d').format(t.transactionDate),
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white38 : Colors.black45,
              ),
            ),
            const Spacer(),
            Text(
              '+$symbol${t.amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF4CAF50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.trending_up_rounded,
              size: 64,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
            const SizedBox(height: 20),
            Text(
              'No income in this period',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Change the date range or category filter',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showIncomeDetail(
    Transaction t,
    String defaultCurrency,
    List<TransactionCategory> categories,
  ) {
    HapticFeedback.lightImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cat = _categoryFor(categories, t.categoryId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D23) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewPadding.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color:
                              (cat != null
                                      ? Color(cat.colorValue)
                                      : _accentColor)
                                  .withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          cat?.icon ?? Icons.category_rounded,
                          size: 28,
                          color: cat != null
                              ? Color(cat.colorValue)
                              : _accentColor,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.title,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1E1E1E),
                              ),
                            ),
                            Text(
                              '${DateFormat('MMM d, yyyy').format(t.transactionDate)} • '
                              '${cat?.name ?? 'Uncategorized'}',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '+${CurrencyUtils.getCurrencySymbol(t.currency ?? defaultCurrency)}${t.amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF4CAF50),
                        ),
                      ),
                    ],
                  ),
                  if (t.notes != null && t.notes!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      t.notes!,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _editIncome(t);
                          },
                          icon: const Icon(Icons.edit_rounded, size: 20),
                          label: const Text('Edit'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _accentColor,
                            side: const BorderSide(color: Color(0xFF4CAF50)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            final deleted = await _confirmDelete(t);
                            if (deleted && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${t.title} deleted'),
                                  backgroundColor: Colors.red.shade400,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.delete_rounded, size: 20),
                          label: const Text('Delete'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red.shade400,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _editIncome(Transaction t) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (c) =>
            AddTransactionScreen(transaction: t, initialType: 'income'),
      ),
    ).then((_) => _invalidateAll());
  }

  Future<bool> _confirmDelete(Transaction t) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Income'),
        content: Text(
          'Delete "${t.title}" (${CurrencyUtils.getCurrencySymbol(t.currency ?? FinanceSettingsService.fallbackCurrency)}${t.amount.toStringAsFixed(2)})? '
          'Account balance will be updated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return false;

    final balanceService = ref.read(transactionBalanceServiceProvider);
    final transactionRepo = ref.read(transactionRepositoryProvider);
    final budgetTracker = ref.read(budgetTrackerServiceProvider);
    final dailyBalanceService = ref.read(dailyBalanceServiceProvider);

    await balanceService.reverseTransactionImpact(t);
    await transactionRepo.deleteTransaction(t.id);
    await budgetTracker.updateAllBudgetSpending();
    await dailyBalanceService.invalidateFromDate(t.transactionDate);

    _invalidateAll();
    return true;
  }

  void _invalidateAll() {
    ref.invalidate(allTransactionsProvider);
    ref.invalidate(totalBalanceProvider);
    ref.invalidate(monthlyStatisticsProvider);
    ref.invalidate(allBudgetsProvider);
    ref.invalidate(allBudgetStatusesProvider);
    ref.invalidate(allAccountsProvider);
    ref.invalidate(defaultAccountProvider);
  }
}
