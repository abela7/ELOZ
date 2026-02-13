import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/dark_gradient.dart';
import '../../../../core/widgets/date_navigator_widget.dart';
import '../../data/models/account.dart';
import '../../data/models/transaction.dart';
import '../../data/services/finance_settings_service.dart';
import '../../utils/currency_utils.dart';
import '../../utils/expense_range_utils.dart';
import '../providers/finance_providers.dart';
import 'add_transaction_screen.dart';

/// Expense Category Detail Screen - Modern UI
class ExpenseCategoryScreen extends ConsumerStatefulWidget {
  final String categoryId;
  final String categoryName;
  final IconData categoryIcon;
  final Color categoryColor;

  const ExpenseCategoryScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
    required this.categoryIcon,
    required this.categoryColor,
  });

  @override
  ConsumerState<ExpenseCategoryScreen> createState() =>
      _ExpenseCategoryScreenState();
}

class _ExpenseCategoryScreenState extends ConsumerState<ExpenseCategoryScreen> {
  ExpenseRangeView _selectedRangeView = ExpenseRangeView.day;
  DateTime _selectedDate = ExpenseRangeUtils.normalizeDate(DateTime.now());
  TimeOfDay _selectedTime = TimeOfDay.now();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _amountFocusNode = FocusNode();

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? ColorScheme.dark(
                    primary: widget.categoryColor,
                    onPrimary: Colors.white,
                    surface: const Color(0xFF2D3139),
                    onSurface: Colors.white,
                  )
                : ColorScheme.light(
                    primary: widget.categoryColor,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Colors.black87,
                  ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = ExpenseRangeUtils.normalizeDate(picked));
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? ColorScheme.dark(
                    primary: widget.categoryColor,
                    onPrimary: Colors.white,
                    surface: const Color(0xFF2D3139),
                    onSurface: Colors.white,
                  )
                : ColorScheme.light(
                    primary: widget.categoryColor,
                    onPrimary: Colors.white,
                  ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final transactionsAsync = ref.watch(allTransactionsProvider);
    final defaultCurrencyAsync = ref.watch(defaultCurrencyProvider);
    final defaultAccountAsync = ref.watch(defaultAccountProvider);
    final defaultCurrency =
        defaultCurrencyAsync.value ?? FinanceSettingsService.fallbackCurrency;
    final defaultAccount = defaultAccountAsync.value;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0D0F14)
          : const Color(0xFFF8F9FC),
      body: isDark
          ? DarkGradient.wrap(
              child: _buildBody(
                isDark,
                transactionsAsync,
                defaultCurrency,
                defaultAccount,
              ),
            )
          : _buildBody(
              isDark,
              transactionsAsync,
              defaultCurrency,
              defaultAccount,
            ),
    );
  }

  Widget _buildBody(
    bool isDark,
    AsyncValue<List<Transaction>> transactionsAsync,
    String defaultCurrency,
    Account? defaultAccount,
  ) {
    return SafeArea(
      child: Column(
        children: [
          // Custom Header
          _buildHeader(isDark),

          // Content
          Expanded(
            child: transactionsAsync.when(
              data: (transactions) {
                final filtered = _filterTransactions(transactions);
                return _buildScrollableContent(
                  isDark,
                  filtered,
                  defaultCurrency,
                  defaultAccount,
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
          // Top Row - Back button
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
              // Full Entry Button
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddTransactionScreen(
                        initialType: 'expense',
                        initialCategoryId: widget.categoryId,
                      ),
                    ),
                  ).then((_) => ref.invalidate(allTransactionsProvider));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: widget.categoryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: widget.categoryColor.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.add_rounded,
                        size: 18,
                        color: widget.categoryColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Add Expense',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: widget.categoryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Category Header - Icon + Title aligned
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                // Category Icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        widget.categoryColor,
                        widget.categoryColor.withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    widget.categoryIcon,
                    size: 28,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),

                // Title + Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.categoryName,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1E1E1E),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Track your spending',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white38 : Colors.black38,
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
    );
  }

  Widget _buildScrollableContent(
    bool isDark,
    List<Transaction> transactions,
    String defaultCurrency,
    Account? defaultAccount,
  ) {
    final totalsByCurrency = ExpenseRangeUtils.totalsByCurrency(
      transactions,
      defaultCurrency: defaultCurrency,
    );

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period Selector
          _buildPeriodSelector(isDark),
          const SizedBox(height: 20),

          // Stats Row
          _buildStatsRow(
            isDark,
            totalsByCurrency,
            transactions.length,
            defaultCurrency,
          ),
          const SizedBox(height: 24),

          // Quick Add Card
          _buildQuickAddCard(isDark, defaultCurrency, defaultAccount),
          const SizedBox(height: 28),

          // Recent Expenses Header
          if (transactions.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'RECENT EXPENSES',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: widget.categoryColor,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  '${transactions.length} total',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white24 : Colors.black26,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Transaction List
            ...transactions
                .take(15)
                .map((t) => _buildTransactionItem(isDark, t, defaultCurrency)),
          ] else
            _buildEmptyState(isDark),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  ExpenseRange _selectedRange() =>
      ExpenseRangeUtils.rangeFor(_selectedDate, _selectedRangeView);

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

  Widget _buildPeriodSelector(bool isDark) {
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
            color: isDark
                ? Colors.white.withOpacity(0.03)
                : Colors.black.withOpacity(0.02),
            borderRadius: BorderRadius.circular(14),
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
          setState(() {
            _selectedRangeView = view;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
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
                  : (isDark ? Colors.white54 : Colors.black54),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(
    bool isDark,
    Map<String, double> totalsByCurrency,
    int count,
    String defaultCurrency,
  ) {
    final range = _selectedRange();
    final displayCurrency = totalsByCurrency.containsKey(defaultCurrency)
        ? defaultCurrency
        : (totalsByCurrency.isEmpty
              ? defaultCurrency
              : totalsByCurrency.keys.first);
    final total = totalsByCurrency[displayCurrency] ?? 0.0;
    final symbol = CurrencyUtils.getCurrencySymbol(displayCurrency);
    final dailyAverage = range.totalDays > 0 ? total / range.totalDays : 0.0;
    final secondaryCurrencyCount = totalsByCurrency.length > 1
        ? totalsByCurrency.length - 1
        : 0;

    return Row(
      children: [
        // Total Spent
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  widget.categoryColor.withOpacity(isDark ? 0.2 : 0.1),
                  widget.categoryColor.withOpacity(isDark ? 0.08 : 0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: widget.categoryColor.withOpacity(0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Spent',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: widget.categoryColor,
                  ),
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '$symbol${total.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                      letterSpacing: -1,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '~$symbol${dailyAverage.toStringAsFixed(2)}/day',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
                if (secondaryCurrencyCount > 0)
                  Text(
                    '+$secondaryCurrencyCount currencies',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white30 : Colors.black38,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Expense Count
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.03),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAddCard(
    bool isDark,
    String defaultCurrency,
    Account? defaultAccount,
  ) {
    final symbol = CurrencyUtils.getCurrencySymbol(defaultCurrency);
    final dateFormat = DateFormat('MMM d');
    final timeFormat = DateFormat('h:mm a');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: widget.categoryColor.withOpacity(isDark ? 0.15 : 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.categoryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.flash_on_rounded,
                  size: 18,
                  color: widget.categoryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Add Expense',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                      ),
                    ),
                    if (defaultAccount != null)
                      Text(
                        'From: ${defaultAccount.name}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: widget.categoryColor.withOpacity(0.8),
                        ),
                      )
                    else
                      Text(
                        'No default account set',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade400,
                        ),
                      ),
                  ],
                ),
              ),
              // Full Entry Button
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddTransactionScreen(
                        initialType: 'expense',
                        initialCategoryId: widget.categoryId,
                      ),
                    ),
                  ).then((_) => ref.invalidate(allTransactionsProvider));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.edit_rounded,
                        size: 14,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Full',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Date & Time Row
          Row(
            children: [
              // Date Picker
              Expanded(
                child: GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.03)
                          : Colors.grey.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.black.withOpacity(0.03),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 16,
                          color: widget.categoryColor,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _isToday(_selectedDate)
                                ? 'Today'
                                : dateFormat.format(_selectedDate),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_drop_down_rounded,
                          size: 18,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Time Picker
              Expanded(
                child: GestureDetector(
                  onTap: _pickTime,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.03)
                          : Colors.grey.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.black.withOpacity(0.03),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 16,
                          color: widget.categoryColor,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            timeFormat.format(
                              DateTime(
                                2000,
                                1,
                                1,
                                _selectedTime.hour,
                                _selectedTime.minute,
                              ),
                            ),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_drop_down_rounded,
                          size: 18,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Amount Input Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Currency Symbol
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: widget.categoryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  symbol,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: widget.categoryColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Amount Field
              Expanded(
                child: TextField(
                  controller: _amountController,
                  focusNode: _amountFocusNode,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    hintStyle: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white12 : Colors.black12,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                ),
              ),

              // Add Button
              GestureDetector(
                onTap: defaultAccount != null
                    ? () => _quickAddExpense(defaultCurrency, defaultAccount)
                    : null,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: defaultAccount != null
                        ? LinearGradient(
                            colors: [
                              widget.categoryColor,
                              widget.categoryColor.withOpacity(0.8),
                            ],
                          )
                        : null,
                    color: defaultAccount == null
                        ? Colors.grey.withOpacity(0.3)
                        : null,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    color: defaultAccount != null ? Colors.white : Colors.grey,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Note Input
          TextField(
            controller: _noteController,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: 'Add a note (optional)',
              hintStyle: TextStyle(
                color: isDark ? Colors.white24 : Colors.black26,
              ),
              prefixIcon: Icon(
                Icons.note_rounded,
                size: 18,
                color: isDark ? Colors.white24 : Colors.black26,
              ),
              filled: true,
              fillColor: isDark
                  ? Colors.white.withOpacity(0.02)
                  : Colors.grey.withOpacity(0.03),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),

          // No default account warning
          if (defaultAccount == null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_rounded,
                    size: 18,
                    color: Colors.orange.shade400,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Set a default account in Accounts to use Quick Add',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  Widget _buildTransactionItem(
    bool isDark,
    Transaction transaction,
    String defaultCurrency,
  ) {
    final symbol = CurrencyUtils.getCurrencySymbol(
      transaction.currency ?? defaultCurrency,
    );
    final dateFormat = DateFormat('MMM d');
    final timeFormat = DateFormat('h:mm a');

    return Dismissible(
      key: Key(transaction.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDeleteTransaction(transaction),
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 24),
      ),
      child: GestureDetector(
        onTap: () => _editTransaction(transaction),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.02) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.03)
                  : Colors.black.withOpacity(0.02),
            ),
          ),
          child: Row(
            children: [
              // Date Badge
              Container(
                width: 48,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: widget.categoryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      dateFormat.format(transaction.transactionDate).split(' ')[0],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: widget.categoryColor,
                      ),
                    ),
                    Text(
                      transaction.transactionDate.day.toString(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: widget.categoryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Title & Time
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeFormat.format(transaction.transactionDate),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white24 : Colors.black26,
                      ),
                    ),
                  ],
                ),
              ),

              // Amount + edit hint
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '-$symbol${transaction.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFE53935),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Icon(
                    Icons.edit_rounded,
                    size: 12,
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _editTransaction(Transaction transaction) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddTransactionScreen(
          transaction: transaction,
          initialType: 'expense',
        ),
      ),
    ).then((_) {
      ref.invalidate(allTransactionsProvider);
      ref.invalidate(totalBalanceProvider);
      ref.invalidate(monthlyStatisticsProvider);
    });
  }

  Future<bool> _confirmDeleteTransaction(Transaction transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Transaction'),
        content: Text('Delete "${transaction.title}" (${transaction.amount.toStringAsFixed(2)})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final repo = ref.read(transactionRepositoryProvider);
      await repo.deleteTransaction(transaction.id);

      // Restore balance if account linked
      if (transaction.accountId != null) {
        final accountRepo = ref.read(accountRepositoryProvider);
        final account = await accountRepo.getAccountById(transaction.accountId!);
        if (account != null) {
          account.balance += transaction.amount; // Restore the expense
          await accountRepo.updateAccount(account);
        }
      }

      ref.invalidate(allTransactionsProvider);
      ref.invalidate(totalBalanceProvider);
      ref.invalidate(monthlyStatisticsProvider);
      ref.invalidate(allAccountsProvider);
      ref.invalidate(defaultAccountProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${transaction.title} deleted'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return true;
    }
    return false;
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: widget.categoryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              widget.categoryIcon,
              size: 36,
              color: widget.categoryColor.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No expenses yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Use Quick Add above to record your first expense',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
          ),
        ],
      ),
    );
  }

  List<Transaction> _filterTransactions(List<Transaction> transactions) {
    final range = _selectedRange();
    final expensesInRange = ExpenseRangeUtils.filterExpensesForRange(
      transactions,
      range: range,
    );

    return expensesInRange
        .where((transaction) => transaction.categoryId == widget.categoryId)
        .toList()
      ..sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
  }

  Future<void> _quickAddExpense(String defaultCurrency, Account account) async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter an amount'),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a valid amount'),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    // Check if account has sufficient funds
    if (account.balance < amount) {
      final shouldContinue = await _showInsufficientFundsDialog(
        account,
        amount,
      );
      if (!shouldContinue) return;
    }

    HapticFeedback.mediumImpact();
    _amountFocusNode.unfocus();

    // Create transaction with selected date/time and linked account
    final transactionDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final transaction = Transaction(
      title: _noteController.text.isNotEmpty
          ? _noteController.text
          : widget.categoryName,
      amount: amount,
      type: 'expense',
      categoryId: widget.categoryId,
      accountId: account.id, // Link to specific account
      transactionDate: transactionDate,
      transactionTime: _selectedTime,
      currency: defaultCurrency,
      isCleared: true,
    );

    try {
      final repo = ref.read(transactionRepositoryProvider);
      await repo.createTransaction(transaction);

      // Deduct from the account
      final accountRepo = ref.read(accountRepositoryProvider);
      account.balance -= amount;
      await accountRepo.updateAccount(account);

      // Invalidate all relevant providers
      ref.invalidate(allTransactionsProvider);
      ref.invalidate(totalBalanceProvider);
      ref.invalidate(monthlyStatisticsProvider);
      ref.invalidate(defaultAccountProvider);
      ref.invalidate(allAccountsProvider);

      _amountController.clear();
      _noteController.clear();

      // Keep selected date anchor stable; reset only time after add.
      setState(() {
        _selectedTime = TimeOfDay.now();
      });

      if (mounted) {
        final dateStr = _isToday(transactionDate)
            ? 'Today'
            : DateFormat('MMM d').format(transactionDate);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${CurrencyUtils.getCurrencySymbol(defaultCurrency)}$amountText from ${account.name} ($dateStr)',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: widget.categoryColor,
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Future<bool> _showInsufficientFundsDialog(
    Account account,
    double amount,
  ) async {
    final symbol = CurrencyUtils.getCurrencySymbol(account.currency);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF2D3139) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                Icons.warning_rounded,
                color: Colors.orange.shade400,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Low Balance',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${account.name} has $symbol${account.balance.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This expense of $symbol${amount.toStringAsFixed(2)} will make the balance negative.',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.categoryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Add Anyway'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }
}
