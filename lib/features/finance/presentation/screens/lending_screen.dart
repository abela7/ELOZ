import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/dark_gradient.dart';
import '../../../../core/widgets/color_picker_widget.dart';
import '../../../../core/widgets/date_navigator_widget.dart';
import '../../../../core/widgets/icon_picker_widget.dart';
import '../../data/models/account.dart';
import '../../data/models/debt.dart';
import '../../data/models/transaction_category.dart';
import '../../data/services/finance_settings_service.dart';
import '../../notifications/finance_notification_scheduler.dart';
import '../../utils/currency_utils.dart';
import '../providers/finance_providers.dart';
import 'lending_report_screen.dart';

import '../../../../core/constants/app_colors.dart';

enum LendingFilter { all, active, overdue, closed }

class LendingScreen extends ConsumerStatefulWidget {
  const LendingScreen({super.key});

  @override
  ConsumerState<LendingScreen> createState() => _LendingScreenState();
}

class _LendingScreenState extends ConsumerState<LendingScreen> {
  DateTime _selectedDate = _normalize(DateTime.now());
  LendingFilter _filter = LendingFilter.active;

  static DateTime _normalize(DateTime date) {
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  void _invalidate() => invalidateLendingDebtProviders(ref);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultCurrency =
        ref.watch(defaultCurrencyProvider).value ??
        FinanceSettingsService.fallbackCurrency;
    final accounts = ref.watch(activeAccountsProvider).valueOrNull ?? [];
    final categories =
        ref.watch(allExpenseTransactionCategoriesProvider).valueOrNull ?? [];
    final debtsAsync = ref.watch(allLentDebtsProvider);

    final content = SafeArea(
      child: debtsAsync.when(
        data: (allDebts) {
          final filtered =
              allDebts.where((debt) {
                if (!debt.existsAsOfDate(_selectedDate)) return false;
                final outstanding = debt.balanceAsOfDate(_selectedDate);
                final active = outstanding > 0 && debt.status == 'active';
                final overdue =
                    active &&
                    debt.dueDate != null &&
                    _normalize(debt.dueDate!).isBefore(_selectedDate);
                final closed = outstanding <= 0 || debt.status != 'active';
                switch (_filter) {
                  case LendingFilter.all:
                    return true;
                  case LendingFilter.active:
                    return active;
                  case LendingFilter.overdue:
                    return overdue;
                  case LendingFilter.closed:
                    return closed;
                }
              }).toList()..sort(
                (a, b) => b
                    .balanceAsOfDate(_selectedDate)
                    .compareTo(a.balanceAsOfDate(_selectedDate)),
              );

          final totals = <String, double>{};
          var activeCount = 0;
          var overdueCount = 0;
          for (final debt in allDebts) {
            if (!debt.existsAsOfDate(_selectedDate)) continue;
            final outstanding = debt.balanceAsOfDate(_selectedDate);
            if (outstanding > 0 && debt.status == 'active') {
              totals[debt.currency] =
                  (totals[debt.currency] ?? 0) + outstanding;
              activeCount++;
              if (debt.dueDate != null &&
                  _normalize(debt.dueDate!).isBefore(_selectedDate)) {
                overdueCount++;
              }
            }
          }

          final primaryCurrency = totals.containsKey(defaultCurrency)
              ? defaultCurrency
              : (totals.keys.isNotEmpty ? totals.keys.first : defaultCurrency);
          final primarySymbol = CurrencyUtils.getCurrencySymbol(
            primaryCurrency,
          );
          final primaryOutstanding = totals[primaryCurrency] ?? 0.0;
          final accountById = {
            for (final account in accounts) account.id: account,
          };
          final categoryById = <String, TransactionCategory>{
            for (final category in categories) category.id: category,
          };

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  children: [
                    _iconButton(
                      isDark: isDark,
                      icon: Icons.arrow_back_rounded,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [AppColors.gold, Color(0xFFB8963E)],
                        ),
                      ),
                      child: const Icon(
                        Icons.handshake_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lending',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black87,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            'Money you gave to others',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white60 : Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _iconButton(
                      isDark: isDark,
                      icon: Icons.analytics_rounded,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const LendingReportScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
                child: DateNavigatorWidget(
                  selectedDate: _selectedDate,
                  onDateChanged: (date) => setState(() {
                    _selectedDate = _normalize(date);
                  }),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A1D23) : Colors.white,
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Outstanding as of ${DateFormat('yyyy-MM-dd').format(_selectedDate)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$primarySymbol${primaryOutstanding.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.0,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _statChip(
                            isDark: isDark,
                            label: 'Active',
                            value: '$activeCount',
                            color: AppColors.gold,
                          ),
                          const SizedBox(width: 8),
                          _statChip(
                            isDark: isDark,
                            label: 'Overdue',
                            value: '$overdueCount',
                            color: const Color(0xFFEF5350),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Row(
                  children: LendingFilter.values.map((filter) {
                    final selected = filter == _filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _filter = filter),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.gold
                                : (isDark
                                      ? const Color(0xFF1A1D23)
                                      : Colors.white),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected
                                  ? AppColors.gold
                                  : (isDark
                                        ? Colors.white.withOpacity(0.05)
                                        : Colors.black.withOpacity(0.05)),
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: Text(
                            _filterLabel(filter),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: selected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: selected
                                  ? Colors.black87
                                  : (isDark ? Colors.white70 : Colors.black87),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No lending records for this filter.',
                          style: TextStyle(
                            color: isDark ? Colors.white60 : Colors.black45,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 6, 20, 100),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final debt = filtered[index];
                          final outstanding = debt.balanceAsOfDate(
                            _selectedDate,
                          );
                          final category = categoryById[debt.categoryId];
                          final account = debt.accountId == null
                              ? null
                              : accountById[debt.accountId];
                          final dueDays = debt.dueDate == null
                              ? null
                              : _normalize(
                                  debt.dueDate!,
                                ).difference(_selectedDate).inDays;
                          return InkWell(
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      LendingDetailsScreen(debtId: debt.id),
                                ),
                              );
                              _invalidate();
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withOpacity(0.04)
                                    : Colors.white,
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
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: debt.color.withOpacity(0.16),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      debt.icon ?? Icons.handshake_rounded,
                                      color: debt.color,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          debt.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black87,
                                          ),
                                        ),
                                        Text(
                                          debt.creditorName ?? 'No borrower',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark
                                                ? Colors.white60
                                                : Colors.black45,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          [
                                            if (category != null) category.name,
                                            if (account != null) account.name,
                                            if (dueDays != null)
                                              dueDays < 0
                                                  ? '${dueDays.abs()}d overdue'
                                                  : '$dueDays d left',
                                          ].join(' â€¢ '),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color:
                                                dueDays != null && dueDays < 0
                                                ? const Color(0xFFEF5350)
                                                : (isDark
                                                      ? Colors.white54
                                                      : Colors.black45),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${CurrencyUtils.getCurrencySymbol(debt.currency)}${outstanding.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFFEF5350),
                                        ),
                                      ),
                                      Text(
                                        '${debt.paymentProgress.toStringAsFixed(0)}% collected',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark
                                              ? Colors.white54
                                              : Colors.black45,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );

    return Scaffold(
      backgroundColor: isDark ? Colors.transparent : const Color(0xFFF5F5F7),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _LendingSheet(
            isDark: isDark,
            onSaved: _invalidate,
            initialDate: _selectedDate,
          ),
        ),
        backgroundColor: AppColors.gold,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Lending'),
      ),
      body: isDark ? DarkGradient.wrap(child: content) : content,
    );
  }

  static String _filterLabel(LendingFilter filter) {
    switch (filter) {
      case LendingFilter.all:
        return 'All';
      case LendingFilter.active:
        return 'Active';
      case LendingFilter.overdue:
        return 'Overdue';
      case LendingFilter.closed:
        return 'Closed';
    }
  }

  Widget _iconButton({
    required bool isDark,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D23) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.05),
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isDark ? Colors.white70 : Colors.black54,
        ),
      ),
    );
  }

  Widget _statChip({
    required bool isDark,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.whiteOpacity01
              : Colors.black.withOpacity(0.02),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white60 : Colors.black45,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w800, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class LendingDetailsScreen extends ConsumerStatefulWidget {
  final String debtId;

  const LendingDetailsScreen({super.key, required this.debtId});

  @override
  ConsumerState<LendingDetailsScreen> createState() =>
      _LendingDetailsScreenState();
}

class _LendingDetailsScreenState extends ConsumerState<LendingDetailsScreen> {
  final _amountController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _invalidate() => invalidateLendingDebtProviders(ref);

  Future<void> _recordCollection(Debt debt) async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0 || amount > debt.currentBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid collection amount')),
      );
      return;
    }
    await ref.read(debtRepositoryProvider).recordPayment(debt.id, amount);
    _amountController.clear();
    _invalidate();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final debts = ref.watch(allLentDebtsProvider);

    return debts.when(
      data: (items) {
        final debt = items.cast<Debt?>().firstWhere(
          (item) => item?.id == widget.debtId,
          orElse: () => null,
        );
        if (debt == null) {
          return const Scaffold(body: Center(child: Text('Record not found')));
        }
        final symbol = CurrencyUtils.getCurrencySymbol(debt.currency);
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final daysLeft = debt.dueDate == null
            ? null
            : DateTime(
                debt.dueDate!.year,
                debt.dueDate!.month,
                debt.dueDate!.day,
              ).difference(today).inDays;
        final dailyTarget =
            (daysLeft != null && daysLeft > 0 && debt.currentBalance > 0)
            ? debt.currentBalance / daysLeft
            : null;

        final content = ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    debt.name,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    debt.creditorName ?? 'No borrower',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white60 : Colors.black45,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Outstanding: $symbol${debt.currentBalance.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFEF5350),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Collected: $symbol${(debt.originalAmount - debt.currentBalance).clamp(0.0, double.infinity).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4CAF50),
                    ),
                  ),
                  if (debt.dueDate != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      daysLeft == null
                          ? ''
                          : (daysLeft < 0
                                ? '${daysLeft.abs()} days overdue'
                                : '$daysLeft days left'),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: daysLeft != null && daysLeft < 0
                            ? const Color(0xFFEF5350)
                            : (isDark ? Colors.white70 : Colors.black54),
                      ),
                    ),
                  ],
                  if (dailyTarget != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'To fully collect by due date: $symbol${dailyTarget.toStringAsFixed(2)}/day',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.gold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Record collection',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      prefixText: '$symbol ',
                      labelText: 'Amount',
                      filled: true,
                      fillColor: isDark
                          ? AppColors.whiteOpacity01
                          : AppColors.blackOpacity005,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => _amountController.text =
                            (debt.currentBalance * 0.5).toStringAsFixed(2),
                        child: const Text('50%'),
                      ),
                      TextButton(
                        onPressed: () => _amountController.text = debt
                            .currentBalance
                            .toStringAsFixed(2),
                        child: const Text('Full'),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () => _recordCollection(debt),
                        icon: const Icon(Icons.payments_rounded, size: 16),
                        label: const Text('Record'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'History',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (debt.paymentHistory.isEmpty)
                    Text(
                      'No collections yet.',
                      style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.black45,
                      ),
                    )
                  else
                    ...debt.paymentHistory.map((entry) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.whiteOpacity01
                              : AppColors.blackOpacity005,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    DateFormat(
                                      'MMM d, yyyy â€¢ h:mm a',
                                    ).format(entry.paidAt),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black54,
                                    ),
                                  ),
                                  Text(
                                    'Balance after: $symbol${entry.balanceAfter.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.black45,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '+$symbol${entry.amount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Color(0xFF4CAF50),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (value) async {
                                if (value == 'undo') {
                                  await ref
                                      .read(debtRepositoryProvider)
                                      .undoPayment(
                                        debtId: debt.id,
                                        paymentId: entry.id,
                                      );
                                  _invalidate();
                                } else if (value == 'edit') {
                                  final controller = TextEditingController(
                                    text: entry.amount.toStringAsFixed(2),
                                  );
                                  final amount = await showDialog<double>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text('Edit collection'),
                                      content: TextField(
                                        controller: controller,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(
                                                double.tryParse(
                                                  controller.text,
                                                ),
                                              ),
                                          child: const Text('Save'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (amount != null && amount > 0) {
                                    await ref
                                        .read(debtRepositoryProvider)
                                        .updatePayment(
                                          debtId: debt.id,
                                          paymentId: entry.id,
                                          amount: amount,
                                        );
                                    _invalidate();
                                  }
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                                PopupMenuItem(
                                  value: 'undo',
                                  child: Text('Undo'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        );

        return Scaffold(
          appBar: AppBar(
            title: const Text('Lending Details'),
            actions: [
              IconButton(
                onPressed: () async {
                  await showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => _LendingSheet(
                      isDark: isDark,
                      debt: debt,
                      onSaved: _invalidate,
                      initialDate: debt.createdAt,
                    ),
                  );
                },
                icon: const Icon(Icons.edit_rounded),
              ),
              IconButton(
                onPressed: () async {
                  try {
                    await FinanceNotificationScheduler()
                        .cancelDebtNotifications(debt.id);
                  } catch (_) {}
                  await ref.read(debtRepositoryProvider).deleteDebt(debt.id);
                  _invalidate();
                  if (mounted) Navigator.of(context).pop();
                },
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          backgroundColor: isDark
              ? Colors.transparent
              : const Color(0xFFF5F5F7),
          body: isDark ? DarkGradient.wrap(child: content) : content,
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(body: Center(child: Text('Error: $error'))),
    );
  }
}

class _LendingSheet extends ConsumerStatefulWidget {
  final bool isDark;
  final Debt? debt;
  final DateTime initialDate;
  final VoidCallback onSaved;

  const _LendingSheet({
    required this.isDark,
    this.debt,
    required this.initialDate,
    required this.onSaved,
  });

  @override
  ConsumerState<_LendingSheet> createState() => _LendingSheetState();
}

class _LendingSheetState extends ConsumerState<_LendingSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _borrowerController;
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;

  DateTime? _dueDate;
  late DateTime _lentDate;
  String? _categoryId;
  String? _accountId;
  String _currency = FinanceSettingsService.fallbackCurrency;
  IconData? _icon;
  Color _color = AppColors.gold;
  bool _saving = false;

  bool get _isEdit => widget.debt != null;

  @override
  void initState() {
    super.initState();
    final debt = widget.debt;
    _titleController = TextEditingController(text: debt?.name ?? '');
    _borrowerController = TextEditingController(text: debt?.creditorName ?? '');
    _amountController = TextEditingController(
      text: debt?.currentBalance.toStringAsFixed(2) ?? '',
    );
    _notesController = TextEditingController(text: debt?.notes ?? '');
    _dueDate = debt?.dueDate;
    _lentDate = debt?.createdAt ?? widget.initialDate;
    _categoryId = debt?.categoryId;
    _accountId = debt?.accountId;
    _currency = debt?.currency ?? _currency;
    _icon = debt?.icon ?? Icons.handshake_rounded;
    _color = debt?.color ?? _color;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _borrowerController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save(
    List<TransactionCategory> categories,
    List<Account> accounts,
  ) async {
    final title = _titleController.text.trim();
    final borrower = _borrowerController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());
    if (title.isEmpty || borrower.isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }
    if (_categoryId == null) {
      _categoryId = categories.isEmpty ? null : categories.first.id;
    }
    if (_accountId == null) {
      _accountId = accounts.isEmpty ? null : accounts.first.id;
    }
    if (_categoryId == null || _accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Category and source account are required'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(debtRepositoryProvider);
      if (_isEdit) {
        final debt = widget.debt!;
        final updated = debt.copyWith(
          name: title,
          creditorName: borrower,
          currentBalance: amount,
          originalAmount: amount > debt.originalAmount
              ? amount
              : debt.originalAmount,
          categoryId: _categoryId,
          accountId: _accountId,
          dueDate: _dueDate,
          createdAt: _lentDate,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          currency: _currency,
          iconCodePoint: _icon?.codePoint,
          iconFontFamily: _icon?.fontFamily,
          iconFontPackage: _icon?.fontPackage,
          colorValue: _color.value,
          direction: DebtDirection.lent.name,
          status: amount <= 0 ? 'paidOff' : debt.status,
        );
        await repo.updateDebt(updated);
      } else {
        final debt = Debt(
          name: title,
          categoryId: _categoryId!,
          originalAmount: amount,
          currentBalance: amount,
          creditorName: borrower,
          accountId: _accountId,
          dueDate: _dueDate,
          createdAt: _lentDate,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          currency: _currency,
          direction: DebtDirection.lent.name,
          icon: _icon,
          colorValue: _color.value,
        );
        // Use DebtService to create both debt and expense transaction
        final debtService = ref.read(debtServiceProvider);
        await debtService.createLendingWithTransaction(debt: debt);
      }
      widget.onSaved();
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories =
        ref.watch(expenseTransactionCategoriesProvider).valueOrNull ?? [];
    final accounts = ref.watch(activeAccountsProvider).valueOrNull ?? [];
    if (_categoryId == null && categories.isNotEmpty) {
      _categoryId = categories.first.id;
    }
    if (_accountId == null && accounts.isNotEmpty) {
      _accountId = accounts.first.id;
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1A1D23) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: widget.isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _isEdit ? 'Edit Lending' : 'Add Lending',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: widget.isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                // Basic Information Card
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: widget.isDark
                        ? Colors.white.withOpacity(0.03)
                        : Colors.black.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: widget.isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.05),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BASIC INFORMATION',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFCDAF56),
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _textField(
                        _titleController,
                        'Title',
                        Icons.title_rounded,
                        widget.isDark,
                      ),
                      const SizedBox(height: 16),
                      _textField(
                        _borrowerController,
                        'Borrower',
                        Icons.person_rounded,
                        widget.isDark,
                      ),
                      const SizedBox(height: 16),
                      _textField(
                        _amountController,
                        _isEdit ? 'Outstanding amount' : 'Amount lent',
                        Icons.payments_rounded,
                        widget.isDark,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ],
                  ),
                ),
                // Details Card
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: widget.isDark
                        ? Colors.white.withOpacity(0.03)
                        : Colors.black.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: widget.isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.05),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DETAILS',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFCDAF56),
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _categoryId,
                        isExpanded: true,
                        decoration: _commonFieldDecoration(widget.isDark)
                            .copyWith(
                              hintText: 'Select category',
                              prefixIcon: Icon(
                                Icons.category_rounded,
                                size: 20,
                                color: const Color(0xFFCDAF56),
                              ),
                            ),
                        items: categories
                            .map(
                              (category) => DropdownMenuItem<String>(
                                value: category.id,
                                child: Text(
                                  category.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _categoryId = value),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _accountId,
                        isExpanded: true,
                        decoration: _commonFieldDecoration(widget.isDark)
                            .copyWith(
                              hintText: 'Select source account',
                              prefixIcon: Icon(
                                Icons.account_balance_wallet,
                                size: 20,
                                color: const Color(0xFFCDAF56),
                              ),
                            ),
                        items: accounts
                            .map(
                              (account) => DropdownMenuItem<String>(
                                value: account.id,
                                child: Text(
                                  '${account.name} â€¢ ${account.currency}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() {
                          _accountId = value;
                          final selected = accounts
                              .where((account) => account.id == value)
                              .cast<Account?>()
                              .firstWhere(
                                (account) => account != null,
                                orElse: () => null,
                              );
                          if (selected != null) _currency = selected.currency;
                        }),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: _currency,
                        isExpanded: true,
                        decoration: _commonFieldDecoration(widget.isDark)
                            .copyWith(
                              hintText: 'Select currency',
                              prefixIcon: Icon(
                                Icons.currency_exchange,
                                size: 20,
                                color: const Color(0xFFCDAF56),
                              ),
                            ),
                        items: FinanceSettingsService.supportedCurrencies
                            .map(
                              (currency) => DropdownMenuItem<String>(
                                value: currency,
                                child: Text(
                                  '${CurrencyUtils.getCurrencySymbol(currency)} $currency',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _currency = value ?? _currency),
                      ),
                    ],
                  ),
                ),
                // Schedule Card
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: widget.isDark
                        ? Colors.white.withOpacity(0.03)
                        : Colors.black.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: widget.isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.05),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SCHEDULE',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFCDAF56),
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                side: BorderSide(
                                  color: widget.isDark
                                      ? Colors.white.withOpacity(0.12)
                                      : Colors.black.withOpacity(0.12),
                                ),
                              ),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _lentDate,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null)
                                  setState(() => _lentDate = picked);
                              },
                              icon: const Icon(
                                Icons.calendar_today_rounded,
                                size: 16,
                              ),
                              label: Text(
                                'Lent: ${DateFormat('MMM d, yyyy').format(_lentDate)}',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                side: BorderSide(
                                  color: widget.isDark
                                      ? Colors.white.withOpacity(0.12)
                                      : Colors.black.withOpacity(0.12),
                                ),
                              ),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _dueDate ?? _lentDate,
                                  firstDate: _lentDate,
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null)
                                  setState(() => _dueDate = picked);
                              },
                              icon: const Icon(Icons.flag_rounded, size: 16),
                              label: Text(
                                _dueDate == null
                                    ? 'Due: None'
                                    : 'Due: ${DateFormat('MMM d, yyyy').format(_dueDate!)}',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Notes Card
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: widget.isDark
                        ? Colors.white.withOpacity(0.03)
                        : Colors.black.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: widget.isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.05),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NOTES',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFCDAF56),
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _textField(
                        _notesController,
                        'Notes (optional)',
                        Icons.notes_rounded,
                        widget.isDark,
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
                // Customize Card
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: widget.isDark
                        ? Colors.white.withOpacity(0.03)
                        : Colors.black.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: widget.isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.05),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CUSTOMIZE APPEARANCE',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFCDAF56),
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                side: BorderSide(
                                  color: widget.isDark
                                      ? Colors.white.withOpacity(0.12)
                                      : Colors.black.withOpacity(0.12),
                                ),
                              ),
                              onPressed: () async {
                                final icon = await showDialog<IconData>(
                                  context: context,
                                  builder: (_) => IconPickerWidget(
                                    selectedIcon: _icon,
                                    isDark: widget.isDark,
                                  ),
                                );
                                if (icon != null) setState(() => _icon = icon);
                              },
                              icon: Icon(
                                _icon ?? Icons.handshake_rounded,
                                color: _color,
                              ),
                              label: const Text('Icon'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                side: BorderSide(
                                  color: widget.isDark
                                      ? Colors.white.withOpacity(0.12)
                                      : Colors.black.withOpacity(0.12),
                                ),
                              ),
                              onPressed: () async {
                                final color = await showDialog<Color>(
                                  context: context,
                                  builder: (_) => ColorPickerWidget(
                                    selectedColor: _color,
                                    isDark: widget.isDark,
                                  ),
                                );
                                if (color != null)
                                  setState(() => _color = color);
                              },
                              icon: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: _color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              label: const Text('Color'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: ElevatedButton(
                    onPressed: _saving
                        ? null
                        : () => _save(categories, accounts),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFCDAF56),
                      foregroundColor: const Color(0xFF1E1E1E),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.black,
                              strokeWidth: 3,
                            ),
                          )
                        : Text(
                            _isEdit ? 'UPDATE' : 'SAVE',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              letterSpacing: 1,
                            ),
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

  Widget _textField(
    TextEditingController controller,
    String label,
    IconData icon,
    bool isDark, {
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 15,
        color: isDark ? Colors.white : Colors.black87,
      ),
      decoration: _commonFieldDecoration(isDark).copyWith(
        hintText: label,
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFFCDAF56)),
      ),
    );
  }

  InputDecoration _commonFieldDecoration(bool isDark) {
    return InputDecoration(
      hintStyle: TextStyle(color: isDark ? Colors.white10 : Colors.black12),
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
        borderSide: const BorderSide(color: Color(0xFFCDAF56), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFEF5350), width: 1.5),
      ),
    );
  }
}

void invalidateLendingDebtProviders(WidgetRef ref) {
  ref.invalidate(allDebtsProvider);
  ref.invalidate(activeDebtsProvider);
  ref.invalidate(totalDebtByCurrencyProvider);
  ref.invalidate(totalDebtByCurrencyForDateProvider);
  ref.invalidate(debtStatisticsProvider);
  ref.invalidate(debtsGroupedByCategoryProvider);
  ref.invalidate(debtsNeedingAttentionProvider);

  ref.invalidate(allLentDebtsProvider);
  ref.invalidate(activeLentDebtsProvider);
  ref.invalidate(totalLentByCurrencyProvider);
  ref.invalidate(totalLentByCurrencyForDateProvider);
  ref.invalidate(lentStatisticsProvider);
  ref.invalidate(lentGroupedByCategoryProvider);
  ref.invalidate(lentNeedingAttentionProvider);
}
