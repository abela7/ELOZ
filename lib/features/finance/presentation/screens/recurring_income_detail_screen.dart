import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/dark_gradient.dart';
import '../../data/models/recurring_income.dart';
import '../../data/models/transaction.dart';
import '../../data/models/account.dart';
import '../../data/models/transaction_category.dart';
import '../../utils/currency_utils.dart';
import '../../utils/expense_range_utils.dart';
import '../providers/finance_providers.dart';
import '../providers/income_providers.dart';
import 'add_recurring_income_screen.dart';

/// Recurring Income Detail Screen - Comprehensive view of a recurring income source
class RecurringIncomeDetailScreen extends ConsumerStatefulWidget {
  final String recurringIncomeId;

  const RecurringIncomeDetailScreen({
    super.key,
    required this.recurringIncomeId,
  });

  @override
  ConsumerState<RecurringIncomeDetailScreen> createState() =>
      _RecurringIncomeDetailScreenState();
}

class _RecurringIncomeDetailScreenState
    extends ConsumerState<RecurringIncomeDetailScreen> {
  int _selectedPeriodMonths = 6; // 3 or 6 months
  final Map<String, bool> _expandedGroups = {}; // Track which groups are expanded

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final recurringIncome = ref.watch(
      recurringIncomeByIdProvider(widget.recurringIncomeId),
    );

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0F14) : const Color(0xFFF8F9FC),
      body: isDark
          ? DarkGradient.wrap(
              child: _buildBody(isDark, recurringIncome),
            )
          : _buildBody(isDark, recurringIncome),
    );
  }

  Widget _buildBody(
    bool isDark,
    RecurringIncome? recurringIncome,
  ) {
    if (recurringIncome == null) {
      return Center(
        child: Text(
          'Recurring income not found',
          style: TextStyle(
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
      );
    }
    return _buildContent(isDark, recurringIncome);
  }

  Widget _buildContent(bool isDark, RecurringIncome income) {
    final symbol = CurrencyUtils.getCurrencySymbol(income.currency);
    final category = ref.watch(transactionCategoryByIdProvider(income.categoryId));
    
    // Get all transactions linked to this recurring income
    final allTransactionsAsync = ref.watch(allTransactionsProvider);
    final linkedTransactions = allTransactionsAsync.maybeWhen(
      data: (allTx) => allTx
          .where((tx) => 
              tx.type == 'income' && 
              tx.recurringGroupId == income.id)
          .toList()
        ..sort((a, b) => b.transactionDate.compareTo(a.transactionDate)),
      orElse: () => <Transaction>[],
    );

    // Calculate upcoming payments
    final now = DateTime.now();
    final endDate = now.add(Duration(days: 30 * _selectedPeriodMonths));
    final upcomingPayments = income.occurrencesBetween(now, endDate);
    
    // Calculate expected vs actual
    final expectedTotal = upcomingPayments.length * income.amount;
    final actualTotal = linkedTransactions.fold<double>(
      0.0,
      (sum, tx) => sum + tx.amount,
    );

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildSliverAppBar(isDark, income, category, symbol),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status & Quick Info Card
                _buildStatusCard(isDark, income, symbol),
                const SizedBox(height: 16),

                // Period Selector
                _buildPeriodSelector(isDark),
                const SizedBox(height: 16),

                // Expected vs Actual Card
                _buildExpectedVsActualCard(
                  isDark,
                  expectedTotal,
                  actualTotal,
                  upcomingPayments.length,
                  linkedTransactions.length,
                  symbol,
                ),
                const SizedBox(height: 24),

                // Upcoming Payments Section
                _buildUpcomingPaymentsSection(
                  isDark,
                  income,
                  upcomingPayments,
                  linkedTransactions,
                  symbol,
                ),
                
                const SizedBox(height: 24),

                // Payment History Section
                Text(
                  'PAYMENT HISTORY (${linkedTransactions.length})',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF4CAF50),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                if (linkedTransactions.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.03)
                          : Colors.black.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        'No payments received yet',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ),
                  )
                else
                  ...linkedTransactions.take(10).map((tx) => _buildHistoryTile(
                    isDark,
                    tx,
                    income.amount,
                    symbol,
                  )),
                
                if (linkedTransactions.length > 10) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      '+${linkedTransactions.length - 10} more payments',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
                
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSliverAppBar(
    bool isDark,
    RecurringIncome income,
    TransactionCategory? category,
    String symbol,
  ) {
    final topPadding = MediaQuery.of(context).padding.top;
    return SliverToBoxAdapter(
      child: Container(
        padding: EdgeInsets.fromLTRB(20, topPadding + 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row - Back & Edit buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.arrow_back_rounded,
                      size: 20,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddRecurringIncomeScreen(
                          income: income,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4CAF50), Color(0xFF388E3C)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: const [
                        Icon(
                          Icons.edit_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Edit',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Icon & Title
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        category?.color ?? const Color(0xFF4CAF50),
                        (category?.color ?? const Color(0xFF4CAF50)).withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    category?.icon ?? Icons.repeat_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        income.title,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${income.frequencyLabel} · $symbol${income.amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: category?.color ?? const Color(0xFF4CAF50),
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

  Widget _buildStatusCard(
    bool isDark,
    RecurringIncome income,
    String symbol,
  ) {
    final nextOccurrence = income.nextOccurrenceAfter(DateTime.now());
    final daysUntilNext = nextOccurrence?.difference(DateTime.now()).inDays;
    final isActive = income.isCurrentlyActive;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            (isActive ? Colors.green : Colors.orange).withOpacity(isDark ? 0.15 : 0.1),
            (isActive ? Colors.green : Colors.orange).withOpacity(isDark ? 0.05 : 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isActive ? Colors.green : Colors.orange).withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isActive ? Colors.green : Colors.orange).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isActive ? Icons.check_circle_rounded : Icons.pause_circle_rounded,
                  color: isActive ? Colors.green : Colors.orange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isActive ? 'ACTIVE' : 'PAUSED',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: isActive ? Colors.green : Colors.orange,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isActive
                          ? 'Automatically generating income'
                          : 'Not generating transactions',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (nextOccurrence != null && isActive) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.03)
                    : Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.event_rounded,
                    color: Colors.blue,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Next Payment',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('EEEE, MMMM d, yyyy').format(nextOccurrence),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (daysUntilNext != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        daysUntilNext == 0
                            ? 'Today'
                            : daysUntilNext == 1
                                ? 'Tomorrow'
                                : 'in $daysUntilNext days',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.blue,
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

  Widget _buildPeriodSelector(bool isDark) {
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
          _buildPeriodChip(isDark, 3, '3 Months'),
          const SizedBox(width: 4),
          _buildPeriodChip(isDark, 6, '6 Months'),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(bool isDark, int months, String label) {
    final isSelected = _selectedPeriodMonths == months;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedPeriodMonths = months);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFF4CAF50), Color(0xFF388E3C)],
                  )
                : null,
            color: isSelected ? null : Colors.transparent,
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

  Widget _buildUpcomingPaymentsSection(
    bool isDark,
    RecurringIncome income,
    List<DateTime> upcomingPayments,
    List<Transaction> linkedTransactions,
    String symbol,
  ) {
    // Group payments smartly based on frequency
    final groups = _groupPaymentsByPeriod(income, upcomingPayments, linkedTransactions);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.event_note_rounded, color: Colors.blue, size: 18),
                const SizedBox(width: 8),
                Text(
                  'UPCOMING PAYMENTS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.blue,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${upcomingPayments.length} total',
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
        ...groups.map((group) => _buildPaymentGroup(
          isDark,
          group,
          income.amount,
          symbol,
        )),
      ],
    );
  }

  List<PaymentGroup> _groupPaymentsByPeriod(
    RecurringIncome income,
    List<DateTime> upcomingPayments,
    List<Transaction> linkedTransactions,
  ) {
    if (upcomingPayments.isEmpty) return [];

    // Determine grouping strategy based on frequency
    switch (income.frequency) {
      case 'daily':
        // Group daily payments by week
        return _groupByWeek(upcomingPayments, linkedTransactions);
      case 'weekly':
        // Group weekly payments by month
        return _groupByMonth(upcomingPayments, linkedTransactions);
      case 'monthly':
      case 'yearly':
        // Show monthly/yearly payments individually (no grouping)
        return _groupIndividually(upcomingPayments, linkedTransactions);
      default:
        return _groupByMonth(upcomingPayments, linkedTransactions);
    }
  }

  List<PaymentGroup> _groupByWeek(
    List<DateTime> payments,
    List<Transaction> linkedTransactions,
  ) {
    final Map<String, List<PaymentItem>> weekGroups = {};
    
    for (final payment in payments) {
      // Get the start of the week (Monday)
      final weekStart = payment.subtract(Duration(days: payment.weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 6));
      final weekKey = '${DateFormat('MMM d').format(weekStart)} - ${DateFormat('MMM d, yyyy').format(weekEnd)}';
      
      final isPaid = linkedTransactions.any((tx) => 
        ExpenseRangeUtils.normalizeDate(tx.transactionDate) == 
        ExpenseRangeUtils.normalizeDate(payment)
      );
      
      weekGroups.putIfAbsent(weekKey, () => []);
      weekGroups[weekKey]!.add(PaymentItem(date: payment, isPaid: isPaid));
    }
    
    return weekGroups.entries.map((entry) {
      final paidCount = entry.value.where((p) => p.isPaid).length;
      return PaymentGroup(
        title: entry.key,
        subtitle: '${entry.value.length} payments · $paidCount paid',
        payments: entry.value,
      );
    }).toList();
  }

  List<PaymentGroup> _groupByMonth(
    List<DateTime> payments,
    List<Transaction> linkedTransactions,
  ) {
    final Map<String, List<PaymentItem>> monthGroups = {};
    
    for (final payment in payments) {
      final monthKey = DateFormat('MMMM yyyy').format(payment);
      
      final isPaid = linkedTransactions.any((tx) => 
        ExpenseRangeUtils.normalizeDate(tx.transactionDate) == 
        ExpenseRangeUtils.normalizeDate(payment)
      );
      
      monthGroups.putIfAbsent(monthKey, () => []);
      monthGroups[monthKey]!.add(PaymentItem(date: payment, isPaid: isPaid));
    }
    
    return monthGroups.entries.map((entry) {
      final paidCount = entry.value.where((p) => p.isPaid).length;
      return PaymentGroup(
        title: entry.key,
        subtitle: '${entry.value.length} payments · $paidCount paid',
        payments: entry.value,
      );
    }).toList();
  }

  List<PaymentGroup> _groupIndividually(
    List<DateTime> payments,
    List<Transaction> linkedTransactions,
  ) {
    return payments.map((payment) {
      final isPaid = linkedTransactions.any((tx) => 
        ExpenseRangeUtils.normalizeDate(tx.transactionDate) == 
        ExpenseRangeUtils.normalizeDate(payment)
      );
      
      return PaymentGroup(
        title: DateFormat('MMMM yyyy').format(payment),
        subtitle: isPaid ? 'Paid' : 'Pending',
        payments: [PaymentItem(date: payment, isPaid: isPaid)],
      );
    }).toList();
  }

  Widget _buildPaymentGroup(
    bool isDark,
    PaymentGroup group,
    double amount,
    String symbol,
  ) {
    final isExpanded = _expandedGroups[group.title] ?? false;
    final paidCount = group.payments.where((p) => p.isPaid).length;
    final totalCount = group.payments.length;
    final allPaid = paidCount == totalCount;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: allPaid
              ? const Color(0xFF4CAF50).withOpacity(0.3)
              : (isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.06)),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _expandedGroups[group.title] = !isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: allPaid
                          ? const Color(0xFF4CAF50).withOpacity(0.15)
                          : Colors.blue.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      allPaid
                          ? Icons.check_circle_rounded
                          : Icons.calendar_month_rounded,
                      color: allPaid ? const Color(0xFF4CAF50) : Colors.blue,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              group.subtitle,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                            if (paidCount > 0) ...[
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
                                child: Text(
                                  '$paidCount/$totalCount',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF4CAF50),
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$symbol${(amount * totalCount).toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: allPaid
                              ? const Color(0xFF4CAF50)
                              : (isDark ? Colors.white70 : Colors.black54),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: isDark ? Colors.white38 : Colors.black38,
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            Container(
              height: 1,
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.05),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: group.payments.map((payment) => 
                  _buildCompactPaymentTile(
                    isDark,
                    payment.date,
                    amount,
                    symbol,
                    payment.isPaid,
                  )
                ).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactPaymentTile(
    bool isDark,
    DateTime date,
    double amount,
    String symbol,
    bool isPaid,
  ) {
    final now = DateTime.now();
    final daysUntil = date.difference(now).inDays;
    final isToday = daysUntil == 0;
    final isPast = daysUntil < 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isPaid
            ? const Color(0xFF4CAF50).withOpacity(isDark ? 0.08 : 0.05)
            : (isDark
                ? Colors.white.withOpacity(0.02)
                : Colors.black.withOpacity(0.02)),
        borderRadius: BorderRadius.circular(12),
        border: isPaid
            ? Border.all(
                color: const Color(0xFF4CAF50).withOpacity(0.2),
              )
            : null,
      ),
      child: Row(
        children: [
          Icon(
            isPaid
                ? Icons.check_circle
                : (isToday
                    ? Icons.today_rounded
                    : Icons.circle_outlined),
            color: isPaid
                ? const Color(0xFF4CAF50)
                : (isToday
                    ? Colors.blue
                    : (isDark ? Colors.white24 : Colors.black26)),
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEE, MMM d').format(date),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                    decoration: isPaid ? TextDecoration.lineThrough : null,
                    decorationColor: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
                if (!isPaid && !isPast)
                  Text(
                    isToday
                        ? 'Due today'
                        : 'in ${daysUntil.abs()} day${daysUntil.abs() == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isToday ? Colors.blue : (isDark ? Colors.white24 : Colors.black26),
                    ),
                  ),
                if (isPast && !isPaid)
                  Text(
                    'Missed',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '$symbol${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: isPaid
                  ? const Color(0xFF4CAF50)
                  : (isDark ? Colors.white60 : Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpectedVsActualCard(
    bool isDark,
    double expected,
    double actual,
    int expectedCount,
    int actualCount,
    String symbol,
  ) {
    final difference = actual - expected;
    final percentageReceived = expected > 0 ? (actual / expected * 100) : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.withOpacity(isDark ? 0.12 : 0.08),
            Colors.blue.withOpacity(isDark ? 0.04 : 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.blue.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.compare_arrows_rounded, color: Colors.blue, size: 24),
              const SizedBox(width: 10),
              Text(
                'EXPECTED VS ACTUAL',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Colors.blue,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildStatBox(
                  isDark,
                  'Expected',
                  '$symbol${expected.toStringAsFixed(2)}',
                  '$expectedCount payments',
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatBox(
                  isDark,
                  'Received',
                  '$symbol${actual.toStringAsFixed(2)}',
                  '$actualCount payments',
                  const Color(0xFF4CAF50),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Progress bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Completion',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  Text(
                    '${percentageReceived.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: percentageReceived >= 100
                          ? const Color(0xFF4CAF50)
                          : Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (percentageReceived / 100).clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.05),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    percentageReceived >= 100
                        ? const Color(0xFF4CAF50)
                        : Colors.blue,
                  ),
                ),
              ),
            ],
          ),
          
          if (difference != 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (difference > 0 ? Colors.green : Colors.orange)
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    difference > 0
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    color: difference > 0 ? Colors.green : Colors.orange,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    difference > 0
                        ? '$symbol${difference.toStringAsFixed(2)} above expected'
                        : '$symbol${difference.abs().toStringAsFixed(2)} below expected',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: difference > 0 ? Colors.green : Colors.orange,
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

  Widget _buildStatBox(
    bool isDark,
    String label,
    String value,
    String subtitle,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.03)
            : Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTile(
    bool isDark,
    Transaction tx,
    double expectedAmount,
    String symbol,
  ) {
    final difference = tx.amount - expectedAmount;
    final isExact = difference == 0;
    final accountAsync = tx.accountId != null
        ? ref.watch(accountByIdProvider(tx.accountId!))
        : const AsyncValue<Account?>.data(null);
    final account = accountAsync.valueOrNull;

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
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF4CAF50),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('MMM d, yyyy').format(tx.transactionDate),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (account != null) ...[
                      Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 11,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        account.name,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ],
                    if (!isExact) ...[
                      if (account != null) const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: (difference > 0 ? Colors.green : Colors.orange)
                              .withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          difference > 0
                              ? '+$symbol${difference.toStringAsFixed(2)}'
                              : '$symbol${difference.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: difference > 0 ? Colors.green : Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Text(
            '$symbol${tx.amount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF4CAF50),
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper class for grouping payments
class PaymentGroup {
  final String title;
  final String subtitle;
  final List<PaymentItem> payments;

  PaymentGroup({
    required this.title,
    required this.subtitle,
    required this.payments,
  });
}

/// Helper class for individual payment items
class PaymentItem {
  final DateTime date;
  final bool isPaid;

  PaymentItem({
    required this.date,
    required this.isPaid,
  });
}
