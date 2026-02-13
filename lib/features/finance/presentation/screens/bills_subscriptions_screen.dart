import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/dark_gradient.dart';
import '../../data/models/bill.dart';
import '../../data/models/transaction_category.dart';
import '../../data/models/account.dart';
import '../../utils/currency_utils.dart';
import '../providers/finance_providers.dart';
import 'add_bill_screen.dart';
import 'bill_detail_screen.dart';
import 'bills_report_screen.dart';

class BillsSubscriptionsScreen extends ConsumerStatefulWidget {
  const BillsSubscriptionsScreen({super.key});

  @override
  ConsumerState<BillsSubscriptionsScreen> createState() =>
      _BillsSubscriptionsScreenState();
}

class _DateRange {
  final DateTime start;
  final DateTime end;

  const _DateRange(this.start, this.end);
}

class _BillsSubscriptionsScreenState
    extends ConsumerState<BillsSubscriptionsScreen>
    with SingleTickerProviderStateMixin {
  String _selectedFilter = 'all'; // all, bills, subscriptions
  String _selectedPeriod = 'month'; // month, week
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final billsAsync = ref.watch(activeBillsProvider);
    final categoriesAsync = ref.watch(expenseTransactionCategoriesProvider);
    final upcomingBillsAsync = ref.watch(upcomingBillsProvider);

    final content = SafeArea(
      top: true,
      bottom: false,
      child: _buildContent(
        context,
        isDark,
        billsAsync,
        categoriesAsync,
        upcomingBillsAsync,
      ),
    );

    return Scaffold(
      backgroundColor: isDark ? Colors.transparent : const Color(0xFFF5F5F7),
      body: isDark ? DarkGradient.wrap(child: content) : content,
    );
  }

  Widget _buildContent(
    BuildContext context,
    bool isDark,
    AsyncValue<List<Bill>> billsAsync,
    AsyncValue<List<TransactionCategory>> categoriesAsync,
    AsyncValue<List<Bill>> upcomingBillsAsync,
  ) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildSliverAppBar(isDark),
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              // Summary Card
              billsAsync.when(
                data: (bills) => _buildSummaryCard(bills, isDark),
                loading: () => _buildSummaryCardLoading(isDark),
                error: (e, _) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 24),

              // Quick Actions
              _buildQuickActions(isDark),
              const SizedBox(height: 24),

              // Upcoming Section (if there are upcoming bills)
              upcomingBillsAsync.when(
                data: (upcoming) {
                  if (upcoming.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildSectionHeader('UPCOMING', isDark),
                      ),
                      const SizedBox(height: 12),
                      _buildUpcomingBillsList(
                        upcoming,
                        categoriesAsync,
                        isDark,
                      ),
                      const SizedBox(height: 24),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              // Period Selector
              _buildPeriodSelector(isDark),
              const SizedBox(height: 20),

              // Filter Chips
              _buildFilterChips(isDark),
              const SizedBox(height: 24),

              // Section Header for All Bills
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionHeader('YOUR BILLS', isDark),
                    billsAsync.when(
                      data: (bills) => Text(
                        '${bills.length} total',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),

        // Bills List
        billsAsync.when(
          data: (bills) => _buildBillsList(bills, categoriesAsync, isDark),
          loading: () => const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => SliverFillRemaining(
            child: Center(
              child: Text(
                'Error: $e',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ),
          ),
        ),

        // Bottom Padding
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildSliverAppBar(bool isDark) {
    return SliverAppBar(
      floating: true,
      pinned: true,
      primary: false,
      centerTitle: true,
      backgroundColor: isDark ? const Color(0xFF1A1D23) : Colors.white,
      elevation: 0,
      title: Text(
        'Bills & Subs',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : const Color(0xFF1E1E1E),
          letterSpacing: -0.3,
        ),
      ),
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: isDark ? Colors.white70 : Colors.black87,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.05),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(List<Bill> bills, bool isDark) {
    final range = _getSelectedRange();
    final commitmentTotals = _calculateCommitmentByCurrency(
      bills,
      range.start,
      range.end,
    );
    final occurrenceDates = _getOccurrenceDatesInRange(
      bills,
      range.start,
      range.end,
    );
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final upcomingCount = occurrenceDates
        .where((d) => !d.isBefore(todayStart))
        .length;
    final overdueCount = occurrenceDates
        .where((d) => d.isBefore(todayStart))
        .length;

    // Calculate monthly total across all currencies
    final monthlyTotal = bills
        .where((b) => b.isActive)
        .fold<Map<String, double>>({}, (acc, bill) {
          final monthly = _calculateMonthlyAmount(bill);
          acc[bill.currency] = (acc[bill.currency] ?? 0) + monthly;
          return acc;
        });

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF1A1D23), const Color(0xFF12151A)]
                : [Colors.white, const Color(0xFFF8F9FC)],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.05),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCDAF56).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        size: 11,
                        color: Color(0xFFCDAF56),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'MONTHLY',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFCDAF56),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                // Stats row
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildMiniStatBadge(
                      label: '',
                      value: bills.where((b) => b.isBill).length.toString(),
                      color: const Color(0xFF2196F3),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 6),
                    _buildMiniStatBadge(
                      label: '',
                      value: bills
                          .where((b) => b.isSubscription)
                          .length
                          .toString(),
                      color: const Color(0xFF9C27B0),
                      isDark: isDark,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Total Amount
            if (monthlyTotal.isEmpty)
              Text(
                '${CurrencyUtils.getCurrencySymbol('ETB')}0.00',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                  letterSpacing: -1,
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: monthlyTotal.entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '${CurrencyUtils.getCurrencySymbol(e.key)}${e.value.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                        letterSpacing: -1,
                      ),
                    ),
                  );
                }).toList(),
              ),

            const SizedBox(height: 20),

            // Stats Row
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.access_time_rounded,
                    label: 'Upcoming',
                    value: upcomingCount.toString(),
                    color: Colors.amber,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.warning_rounded,
                    label: 'Overdue',
                    value: overdueCount.toString(),
                    color: overdueCount > 0
                        ? Colors.redAccent
                        : Colors.greenAccent,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.paid_rounded,
                    label: 'This Period',
                    value: commitmentTotals.isEmpty
                        ? '0'
                        : commitmentTotals.values.first.toStringAsFixed(0),
                    color: const Color(0xFFCDAF56),
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStatBadge({
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label.isEmpty ? value : '$value $label',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.03)
            : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }

  double _calculateMonthlyAmount(Bill bill) {
    if (!bill.isActive) return 0;
    switch (bill.frequency) {
      case 'weekly':
        return bill.defaultAmount * 4.33;
      case 'yearly':
        return bill.defaultAmount / 12;
      default:
        return bill.defaultAmount;
    }
  }

  Widget _buildSummaryCardLoading(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D23) : Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFCDAF56)),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _buildQuickActionButton(
              icon: Icons.receipt_long_rounded,
              label: 'Add Bill',
              color: const Color(0xFF2196F3),
              isDark: isDark,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddBillScreen(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildQuickActionButton(
              icon: Icons.subscriptions_rounded,
              label: 'Add Subscription',
              color: const Color(0xFF9C27B0),
              isDark: isDark,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddBillScreen(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildQuickActionButton(
              icon: Icons.analytics_rounded,
              label: 'Reports',
              color: const Color(0xFFCDAF56),
              isDark: isDark,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BillsReportScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D23) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.03),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingBillsList(
    List<Bill> upcoming,
    AsyncValue<List<TransactionCategory>> categoriesAsync,
    bool isDark,
  ) {
    // Show max 3 upcoming bills
    final displayBills = upcoming.take(3).toList();

    return SizedBox(
      height: 130,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: displayBills.length,
        itemBuilder: (context, index) {
          final bill = displayBills[index];
          final categories = categoriesAsync.valueOrNull ?? [];
          final category = categories.firstWhere(
            (c) => c.id == bill.categoryId,
            orElse: () => TransactionCategory(
              name: 'Other',
              type: 'expense',
              colorValue: Colors.grey.value,
            ),
          );

          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _buildUpcomingCard(bill, category, isDark),
          );
        },
      ),
    );
  }

  Widget _buildUpcomingCard(
    Bill bill,
    TransactionCategory category,
    bool isDark,
  ) {
    final daysUntil = bill.nextDueDate?.difference(DateTime.now()).inDays ?? 0;
    final isToday = daysUntil == 0;
    final isTomorrow = daysUntil == 1;

    String dueText;
    Color dueColor;
    if (isToday) {
      dueText = 'Today';
      dueColor = Colors.redAccent;
    } else if (isTomorrow) {
      dueText = 'Tomorrow';
      dueColor = Colors.amber;
    } else {
      dueText = 'In $daysUntil days';
      dueColor = const Color(0xFFCDAF56);
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => BillDetailScreen(bill: bill)),
        );
      },
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D23) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isToday
                ? Colors.redAccent.withOpacity(0.3)
                : (isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.03)),
            width: isToday ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: category.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    bill.icon ?? category.icon ?? Icons.receipt_rounded,
                    color: category.color,
                    size: 18,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: dueColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    dueText,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: dueColor,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              bill.name,
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
              '${CurrencyUtils.getCurrencySymbol(bill.currency)}${bill.defaultAmount.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector(bool isDark) {
    final isMonth = _selectedPeriod == 'month';
    final label = isMonth
        ? DateFormat('MMMM yyyy').format(_selectedDate)
        : _formatWeekRange(_selectedDate);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('PERIOD', isDark),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.03)
                  : Colors.black.withOpacity(0.02),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildPeriodChip(
                    label: 'Week',
                    value: 'week',
                    isDark: isDark,
                  ),
                ),
                Expanded(
                  child: _buildPeriodChip(
                    label: 'Month',
                    value: 'month',
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _pickPeriodDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1D23) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.05),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCDAF56).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      color: Color(0xFFCDAF56),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tap to change ${_selectedPeriod}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded),
                        onPressed: () => _shiftPeriod(-1),
                        color: const Color(0xFFCDAF56),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded),
                        onPressed: () => _shiftPeriod(1),
                        color: const Color(0xFFCDAF56),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodChip({
    required String label,
    required String value,
    required bool isDark,
  }) {
    final isSelected = _selectedPeriod == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedPeriod = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFCDAF56) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isSelected
                  ? Colors.black87
                  : (isDark ? Colors.white54 : Colors.black54),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips(bool isDark) {
    final filters = [
      {'id': 'all', 'label': 'All', 'icon': Icons.grid_view_rounded},
      {'id': 'bills', 'label': 'Bills', 'icon': Icons.receipt_rounded},
      {
        'id': 'subscriptions',
        'label': 'Subscriptions',
        'icon': Icons.subscriptions_rounded,
      },
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: filters.map((filter) {
          final isSelected = _selectedFilter == filter['id'];
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedFilter = filter['id'] as String);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 18,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFCDAF56)
                      : (isDark ? const Color(0xFF1A1D23) : Colors.white),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFFCDAF56)
                        : (isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.black.withOpacity(0.05)),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      filter['icon'] as IconData,
                      size: 16,
                      color: isSelected
                          ? Colors.black87
                          : (isDark ? Colors.white54 : Colors.black54),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      filter['label'] as String,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: isSelected
                            ? Colors.black87
                            : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: const Color(0xFFCDAF56),
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildBillsList(
    List<Bill> bills,
    AsyncValue<List<TransactionCategory>> categoriesAsync,
    bool isDark,
  ) {
    // Filter bills based on selection
    List<Bill> filteredBills = bills;
    if (_selectedFilter == 'bills') {
      filteredBills = bills.where((b) => b.type == 'bill').toList();
    } else if (_selectedFilter == 'subscriptions') {
      filteredBills = bills.where((b) => b.type == 'subscription').toList();
    }

    // Sort: overdue first, then by next due date
    filteredBills.sort((a, b) {
      if (a.isOverdue && !b.isOverdue) return -1;
      if (!a.isOverdue && b.isOverdue) return 1;
      if (a.nextDueDate == null && b.nextDueDate == null) return 0;
      if (a.nextDueDate == null) return 1;
      if (b.nextDueDate == null) return -1;
      return a.nextDueDate!.compareTo(b.nextDueDate!);
    });

    if (filteredBills.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.03)
                      : Colors.black.withOpacity(0.02),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.receipt_long_rounded,
                  size: 48,
                  color: isDark
                      ? Colors.white.withOpacity(0.2)
                      : Colors.black.withOpacity(0.2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No ${_selectedFilter == 'all' ? 'bills or subscriptions' : _selectedFilter}',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap the + button to add your first one',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? Colors.white.withOpacity(0.3)
                      : Colors.black.withOpacity(0.3),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final bill = filteredBills[index];
          final categories = categoriesAsync.valueOrNull ?? [];
          final category = categories.firstWhere(
            (c) => c.id == bill.categoryId,
            orElse: () => TransactionCategory(
              name: 'Other',
              type: 'expense',
              colorValue: Colors.grey.value,
            ),
          );
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildBillCard(bill, category, isDark),
          );
        }, childCount: filteredBills.length),
      ),
    );
  }

  Widget _buildBillCard(Bill bill, TransactionCategory category, bool isDark) {
    final statusColor = bill.isOverdue
        ? Colors.redAccent
        : (bill.isDueSoon ? Colors.amber : Colors.greenAccent);
    final statusText = bill.isOverdue
        ? 'Overdue'
        : (bill.isDueSoon ? 'Due Soon' : 'Active');

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => BillDetailScreen(bill: bill)),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D23) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: bill.isOverdue
                ? Colors.redAccent.withOpacity(0.3)
                : (isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.03)),
            width: bill.isOverdue ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Icon
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: category.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    bill.icon ?? category.icon ?? Icons.receipt_rounded,
                    color: category.color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              bill.name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1E1E1E),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            bill.isSubscription
                                ? Icons.subscriptions_rounded
                                : Icons.receipt_rounded,
                            size: 12,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            bill.isSubscription ? 'Subscription' : 'Bill',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                          if (bill.isVariable) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Variable',
                                style: TextStyle(
                                  fontSize: 9,
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

                // Right side: Amount and Status
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${CurrencyUtils.getCurrencySymbol(bill.currency)}${bill.defaultAmount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                        ),
                      ),
                    ),
                    if (bill.nextDueDate != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(bill.nextDueDate!),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? Colors.white.withOpacity(0.3)
                              : Colors.black.withOpacity(0.3),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Compact Pay button
            Center(
              child: GestureDetector(
                onTap: () => _showPayBillSheet(bill, isDark),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCDAF56).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFCDAF56).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.payment_rounded,
                        size: 14,
                        color: Color(0xFFCDAF56),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Pay Now',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFCDAF56),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPayBillSheet(Bill bill, bool isDark) {
    final amountController = TextEditingController(
      text: bill.defaultAmount > 0 ? bill.defaultAmount.toString() : '',
    );
    Account? selectedAccount;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final accountsAsync = ref.watch(activeAccountsProvider);

          return Container(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 32,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1D23) : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white12 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Pay ${bill.name}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'AMOUNT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white38 : Colors.black38,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    prefixText:
                        '${CurrencyUtils.getCurrencySymbol(bill.currency)} ',
                    prefixStyle: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFCDAF56),
                    ),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withOpacity(0.03)
                        : Colors.black.withOpacity(0.02),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'PAY FROM',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white38 : Colors.black38,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                accountsAsync.when(
                  data: (accounts) {
                    if (accounts.isEmpty) {
                      return Text(
                        'No accounts available',
                        style: TextStyle(
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      );
                    }
                    selectedAccount ??= accounts.first;
                    return StatefulBuilder(
                      builder: (context, setState) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.03)
                              : Colors.black.withOpacity(0.02),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<Account>(
                            value: selectedAccount,
                            isExpanded: true,
                            dropdownColor: isDark
                                ? const Color(0xFF1A1D23)
                                : Colors.white,
                            items: accounts
                                .map(
                                  (a) => DropdownMenuItem(
                                    value: a,
                                    child: Row(
                                      children: [
                                        Icon(
                                          a.icon ??
                                              Icons
                                                  .account_balance_wallet_rounded,
                                          color: a.color,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            a.name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black87,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '${CurrencyUtils.getCurrencySymbol(a.currency)}${a.balance.toStringAsFixed(0)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark
                                                ? Colors.white38
                                                : Colors.black38,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => selectedAccount = v),
                          ),
                        ),
                      ),
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (e, _) => Text('Error: $e'),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final amount = double.tryParse(amountController.text);
                      if (amount == null || amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a valid amount'),
                          ),
                        );
                        return;
                      }
                      if (selectedAccount == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select an account'),
                          ),
                        );
                        return;
                      }

                      HapticFeedback.mediumImpact();
                      Navigator.pop(context);

                      // Pay the bill
                      await ref
                          .read(billServiceProvider)
                          .payBill(bill, amount, selectedAccount!.id);

                      // Refresh data
                      ref.invalidate(allBillsProvider);
                      ref.invalidate(activeBillsProvider);
                      ref.invalidate(billSummaryProvider);
                      ref.invalidate(upcomingBillsProvider);
                      ref.invalidate(allTransactionsProvider);
                      ref.invalidate(activeAccountsProvider);
                      ref.invalidate(totalBalanceProvider);

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${bill.name} paid successfully!'),
                            backgroundColor: const Color(0xFFCDAF56),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('CONFIRM PAYMENT'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFCDAF56),
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Helper Methods
  void _shiftPeriod(int direction) {
    setState(() {
      if (_selectedPeriod == 'month') {
        _selectedDate = DateTime(
          _selectedDate.year,
          _selectedDate.month + direction,
          1,
        );
      } else {
        _selectedDate = _selectedDate.add(Duration(days: 7 * direction));
      }
    });
  }

  Future<void> _pickPeriodDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: Color(0xFFCDAF56),
                    onPrimary: Colors.black,
                    surface: Color(0xFF1A1D23),
                    onSurface: Colors.white,
                  )
                : const ColorScheme.light(
                    primary: Color(0xFFCDAF56),
                    onPrimary: Colors.black,
                  ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = _selectedPeriod == 'month'
            ? DateTime(picked.year, picked.month, 1)
            : picked;
      });
    }
  }

  _DateRange _getSelectedRange() {
    final base = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    if (_selectedPeriod == 'week') {
      final start = _startOfWeek(base);
      final end = start.add(const Duration(days: 6));
      return _DateRange(start, end);
    }
    final start = DateTime(base.year, base.month, 1);
    final end = DateTime(base.year, base.month + 1, 0);
    return _DateRange(start, end);
  }

  DateTime _startOfWeek(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final diff = normalized.weekday - DateTime.monday;
    return normalized.subtract(Duration(days: diff));
  }

  String _formatWeekRange(DateTime date) {
    final start = _startOfWeek(date);
    final end = start.add(const Duration(days: 6));
    final startLabel = DateFormat('MMM d').format(start);
    final endLabel = DateFormat('MMM d').format(end);
    return '$startLabel - $endLabel';
  }

  Map<String, double> _calculateCommitmentByCurrency(
    List<Bill> bills,
    DateTime rangeStart,
    DateTime rangeEnd,
  ) {
    final totals = <String, double>{};
    for (final bill in bills.where((b) => b.isActive)) {
      final occurrences = _getBillOccurrencesInRange(
        bill,
        rangeStart,
        rangeEnd,
      );
      if (occurrences.isEmpty) continue;
      totals[bill.currency] =
          (totals[bill.currency] ?? 0) +
          bill.defaultAmount * occurrences.length;
    }
    return totals;
  }

  List<DateTime> _getOccurrenceDatesInRange(
    List<Bill> bills,
    DateTime rangeStart,
    DateTime rangeEnd,
  ) {
    final dates = <DateTime>[];
    for (final bill in bills.where((b) => b.isActive)) {
      dates.addAll(_getBillOccurrencesInRange(bill, rangeStart, rangeEnd));
    }
    return dates;
  }

  List<DateTime> _getBillOccurrencesInRange(
    Bill bill,
    DateTime rangeStart,
    DateTime rangeEnd,
  ) {
    final start = _normalizeDate(rangeStart);
    final end = _normalizeDate(rangeEnd);
    final recurrenceStart = _normalizeDate(bill.startDate);
    final baseStart = recurrenceStart.isBefore(start) ? recurrenceStart : start;

    List<DateTime> occurrences;
    if (bill.recurrence != null) {
      occurrences = bill.recurrence!.getOccurrencesInRange(baseStart, end);
    } else {
      switch (bill.frequency) {
        case 'weekly':
          occurrences = _getWeeklyOccurrences(bill, baseStart, end);
          break;
        case 'yearly':
          occurrences = _getYearlyOccurrences(bill, baseStart, end);
          break;
        case 'monthly':
        default:
          occurrences = _getMonthlyOccurrences(bill, baseStart, end);
      }
    }

    occurrences = occurrences
        .where((d) => !d.isBefore(recurrenceStart))
        .toList();
    final trimmed = _applyEndConditionToOccurrences(bill, occurrences);
    return trimmed.where((d) => !d.isBefore(start) && !d.isAfter(end)).toList();
  }

  List<DateTime> _getWeeklyOccurrences(
    Bill bill,
    DateTime start,
    DateTime end,
  ) {
    final weekday = (bill.nextDueDate ?? bill.startDate).weekday;
    final startDay = DateTime(start.year, start.month, start.day);
    final offset = (weekday - startDay.weekday + 7) % 7;
    var current = startDay.add(Duration(days: offset));
    final results = <DateTime>[];
    while (!current.isAfter(end)) {
      results.add(current);
      current = current.add(const Duration(days: 7));
    }
    return results;
  }

  List<DateTime> _getMonthlyOccurrences(
    Bill bill,
    DateTime start,
    DateTime end,
  ) {
    final dueDay = bill.dueDay ?? bill.startDate.day;
    var cursor = DateTime(start.year, start.month, 1);
    final lastMonth = DateTime(end.year, end.month, 1);
    final results = <DateTime>[];
    while (!cursor.isAfter(lastMonth)) {
      final day = _clampDay(dueDay, cursor.year, cursor.month);
      final dueDate = DateTime(cursor.year, cursor.month, day);
      if (!dueDate.isBefore(start) && !dueDate.isAfter(end)) {
        results.add(dueDate);
      }
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }
    return results;
  }

  List<DateTime> _getYearlyOccurrences(
    Bill bill,
    DateTime start,
    DateTime end,
  ) {
    final sourceDate = bill.nextDueDate ?? bill.startDate;
    final month = sourceDate.month;
    final day = sourceDate.day;
    final results = <DateTime>[];
    for (var year = start.year; year <= end.year; year++) {
      final clampedDay = _clampDay(day, year, month);
      final dueDate = DateTime(year, month, clampedDay);
      if (!dueDate.isBefore(start) && !dueDate.isAfter(end)) {
        results.add(dueDate);
      }
    }
    return results;
  }

  int _clampDay(int day, int year, int month) {
    final lastDay = DateTime(year, month + 1, 0).day;
    if (day < 1) return 1;
    if (day > lastDay) return lastDay;
    return day;
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  List<DateTime> _applyEndConditionToOccurrences(
    Bill bill,
    List<DateTime> occurrences,
  ) {
    if (occurrences.isEmpty) return occurrences;

    switch (bill.endCondition) {
      case 'on_date':
        if (bill.endDate == null) return occurrences;
        final endDate = _normalizeDate(bill.endDate!);
        return occurrences.where((d) => !d.isAfter(endDate)).toList();
      case 'after_occurrences':
        if (bill.endOccurrences == null || bill.endOccurrences! <= 0) {
          return [];
        }
        final startIndex = bill.occurrenceCount.clamp(0, occurrences.length);
        final remaining = (bill.endOccurrences! - bill.occurrenceCount).clamp(
          0,
          occurrences.length,
        );
        return occurrences.skip(startIndex).take(remaining).toList();
      case 'after_amount':
        if (bill.endAmount == null || bill.endAmount! <= 0) return [];
        final remainingAmount = bill.endAmount! - bill.totalPaidAmount;
        if (remainingAmount <= 0) return [];
        final amount = bill.defaultAmount;
        if (amount <= 0) return [];
        final paidOccurrences = (bill.totalPaidAmount / amount).floor();
        final maxFuture = (remainingAmount / amount).ceil();
        return occurrences
            .skip(paidOccurrences.clamp(0, occurrences.length))
            .take(maxFuture)
            .toList();
      case 'indefinite':
      default:
        return occurrences;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = date.difference(now).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    if (diff < 0) return '${-diff}d ago';
    if (diff < 7) return 'In ${diff}d';
    return DateFormat('MMM d').format(date);
  }
}
