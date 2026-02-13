import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/dark_gradient.dart';
import '../../data/models/bill.dart';
import '../../data/models/transaction_category.dart';
import '../../data/models/account.dart';
import '../../data/repositories/bill_repository.dart';
import '../../notifications/finance_notification_scheduler.dart' hide debugPrint;
import '../../utils/currency_utils.dart';
import '../providers/finance_providers.dart';
import '../../notifications/finance_notification_creator_context.dart';
import '../widgets/universal_reminder_section.dart';
import 'add_bill_screen.dart';

/// Bill/Subscription Detail Screen - View Mode
/// Displays comprehensive information about a bill or subscription
class BillDetailScreen extends ConsumerStatefulWidget {
  final Bill bill;

  const BillDetailScreen({super.key, required this.bill});

  @override
  ConsumerState<BillDetailScreen> createState() => _BillDetailScreenState();
}

class _BillDetailScreenState extends ConsumerState<BillDetailScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categoriesAsync = ref.watch(expenseTransactionCategoriesProvider);
    final accountsAsync = ref.watch(activeAccountsProvider);
    final billAsync = ref.watch(billByIdProvider(widget.bill.id));

    final bill = billAsync.whenOrNull(data: (b) => b) ?? widget.bill;

    final content = _buildContent(
      context,
      isDark,
      bill,
      categoriesAsync,
      accountsAsync,
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
    Bill bill,
    AsyncValue<List<TransactionCategory>> categoriesAsync,
    AsyncValue<List<Account>> accountsAsync,
  ) {
    final category = categoriesAsync.when(
      data: (categories) => categories.firstWhere(
        (c) => c.id == bill.categoryId,
        orElse: () => TransactionCategory(
          name: 'Other',
          type: 'expense',
          colorValue: Colors.grey.value,
        ),
      ),
      loading: () => null,
      error: (_, __) => null,
    );

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildSliverAppBar(isDark, bill),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Hero Card with Amount
              _buildHeroCard(bill, category, isDark),
              const SizedBox(height: 20),

              // Status Card
              _buildStatusCard(bill, isDark),
              const SizedBox(height: 20),

              // Payment Schedule Section
              _buildSectionLabel('PAYMENT SCHEDULE', isDark),
              const SizedBox(height: 14),
              _buildScheduleCard(bill, isDark),
              const SizedBox(height: 20),

              // Payment History Section
              _buildSectionLabel('PAYMENT HISTORY', isDark),
              const SizedBox(height: 14),
              _buildHistoryCard(bill, isDark),
              const SizedBox(height: 20),

              // Notification Settings Section
              _buildSectionLabel('PAYMENT REMINDERS', isDark),
              const SizedBox(height: 14),
              UniversalReminderSection(
                creatorContext: FinanceNotificationCreatorContext.forBill(
                  billId: bill.id,
                  billName: bill.name,
                ),
                isDark: isDark,
                title: 'Payment Reminders',
              ),
              const SizedBox(height: 20),

              // Notes Section (if present)
              if (bill.notes != null && bill.notes!.isNotEmpty) ...[
                _buildSectionLabel('NOTES', isDark),
                const SizedBox(height: 14),
                _buildNotesCard(bill, isDark),
                const SizedBox(height: 20),
              ],

              // Metadata
              _buildMetadataCard(bill, isDark),
              const SizedBox(height: 32),

              // Action Buttons
              _buildActionButtons(bill, isDark),
              const SizedBox(height: 40),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildSliverAppBar(bool isDark, Bill bill) {
    final isSubscription = bill.isSubscription;

    return SliverAppBar(
      floating: false,
      pinned: true,
      backgroundColor: isDark ? const Color(0xFF1A1D23) : Colors.white,
      elevation: 0,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white : Colors.black87,
            size: 22,
          ),
          onPressed: () => Navigator.pop(context),
          padding: EdgeInsets.zero,
        ),
      ),
      title: Text(
        isSubscription ? 'Subscription Details' : 'Bill Details',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : const Color(0xFF1E1E1E),
        ),
      ),
      actions: [
        // Edit Button
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFCDAF56).withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(
              Icons.edit_rounded,
              color: Color(0xFFCDAF56),
              size: 22,
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddBillScreen(bill: bill),
                ),
              );
            },
            padding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(width: 8),
      ],
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

  Widget _buildHeroCard(Bill bill, TransactionCategory? category, bool isDark) {
    final currencySymbol = CurrencyUtils.getCurrencySymbol(bill.currency);
    final icon = bill.icon ?? category?.icon ?? Icons.receipt_rounded;
    final color = bill.color;
    final isSubscription = bill.isSubscription;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1A1D23), const Color(0xFF12151A)]
              : [Colors.white, const Color(0xFFF5F5F5)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.05),
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
          // Icon and Type Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(icon, color: color, size: 36),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Name
          Text(
            bill.name,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1E1E1E),
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Type Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isSubscription
                  ? const Color(0xFF2196F3).withOpacity(0.15)
                  : const Color(0xFFCDAF56).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSubscription
                      ? Icons.subscriptions_rounded
                      : Icons.receipt_rounded,
                  size: 14,
                  color: isSubscription
                      ? const Color(0xFF2196F3)
                      : const Color(0xFFCDAF56),
                ),
                const SizedBox(width: 6),
                Text(
                  isSubscription ? 'SUBSCRIPTION' : 'BILL',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isSubscription
                        ? const Color(0xFF2196F3)
                        : const Color(0xFFCDAF56),
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Amount
          Text(
            '$currencySymbol${bill.defaultAmount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF1E1E1E),
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),

          // Frequency
          Text(
            bill.frequencyText.replaceFirst('/', 'per ').toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white38 : Colors.black38,
              letterSpacing: 1,
            ),
          ),

          if (bill.providerName != null && bill.providerName!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.04)
                    : Colors.black.withOpacity(0.02),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.business_rounded,
                    size: 14,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    bill.providerName!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white54 : Colors.black54,
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

  Widget _buildStatusCard(Bill bill, bool isDark) {
    final statusColor = bill.isOverdue
        ? Colors.redAccent
        : (bill.isDueSoon ? Colors.amber : Colors.greenAccent);
    final statusText = bill.isOverdue
        ? 'Overdue'
        : (bill.isDueSoon ? 'Due Soon' : 'On Track');
    final statusIcon = bill.isOverdue
        ? Icons.warning_rounded
        : (bill.isDueSoon
              ? Icons.access_time_rounded
              : Icons.check_circle_rounded);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D23) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.3), width: 1.5),
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(statusIcon, color: statusColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (bill.nextDueDate != null) ...[
            const SizedBox(height: 16),
            Divider(
              height: 1,
              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatusItem(
                    icon: Icons.calendar_today_rounded,
                    label: 'Next Due',
                    value: _formatDate(bill.nextDueDate!),
                    subValue: _formatRelativeDate(bill.nextDueDate!),
                    color: const Color(0xFFCDAF56),
                    isDark: isDark,
                  ),
                ),
                Container(
                  width: 1,
                  height: 50,
                  color: isDark
                      ? Colors.white10
                      : Colors.black.withOpacity(0.06),
                ),
                Expanded(
                  child: _buildStatusItem(
                    icon: Icons.timelapse_rounded,
                    label: 'Days Until Due',
                    value: '${bill.daysUntilDue.abs()}',
                    subValue: bill.daysUntilDue < 0
                        ? 'days overdue'
                        : 'days left',
                    color: bill.daysUntilDue < 0
                        ? Colors.redAccent
                        : Colors.greenAccent,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusItem({
    required IconData icon,
    required String label,
    required String value,
    required String subValue,
    required Color color,
    required bool isDark,
  }) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 8),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white38 : Colors.black38,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subValue,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleCard(Bill bill, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D23) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.03),
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
          _buildDetailRow(
            icon: Icons.repeat_rounded,
            label: 'Frequency',
            value: _capitalizeFirst(bill.frequency),
            isDark: isDark,
          ),
          const SizedBox(height: 16),
          _buildDetailRow(
            icon: Icons.play_circle_outline_rounded,
            label: 'Start Date',
            value: DateFormat('MMM dd, yyyy').format(bill.startDate),
            isDark: isDark,
          ),
          if (bill.dueDay != null) ...[
            const SizedBox(height: 16),
            _buildDetailRow(
              icon: Icons.event_rounded,
              label: 'Due Day',
              value: '${bill.dueDay}${_getDaySuffix(bill.dueDay!)} of month',
              isDark: isDark,
            ),
          ],
          const SizedBox(height: 16),
          _buildDetailRow(
            icon: Icons.flag_circle_rounded,
            label: 'End Condition',
            value: _getEndConditionText(bill),
            isDark: isDark,
          ),
          if (bill.amountType == 'variable') ...[
            const SizedBox(height: 16),
            Divider(
              height: 1,
              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This is a variable amount bill. The actual amount may differ each billing period.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.orange,
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

  Widget _buildHistoryCard(Bill bill, bool isDark) {
    final currencySymbol = CurrencyUtils.getCurrencySymbol(bill.currency);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D23) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.03),
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
              Expanded(
                child: _buildHistoryStat(
                  icon: Icons.paid_rounded,
                  label: 'Times Paid',
                  value: '${bill.occurrenceCount}',
                  color: const Color(0xFF4CAF50),
                  isDark: isDark,
                ),
              ),
              Container(
                width: 1,
                height: 60,
                color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
              ),
              Expanded(
                child: _buildHistoryStat(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Total Paid',
                  value:
                      '$currencySymbol${bill.totalPaidAmount.toStringAsFixed(0)}',
                  color: const Color(0xFFCDAF56),
                  isDark: isDark,
                ),
              ),
            ],
          ),
          if (bill.lastPaidDate != null) ...[
            const SizedBox(height: 16),
            Divider(
              height: 1,
              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
            ),
            const SizedBox(height: 16),
            _buildDetailRow(
              icon: Icons.history_rounded,
              label: 'Last Paid',
              value: DateFormat('MMM dd, yyyy').format(bill.lastPaidDate!),
              trailing: bill.lastPaidAmount != null
                  ? '$currencySymbol${bill.lastPaidAmount!.toStringAsFixed(2)}'
                  : null,
              isDark: isDark,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHistoryStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 10),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
      ],
    );
  }

  Widget _buildNotesCard(Bill bill, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D23) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.03),
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
              Icon(
                Icons.notes_rounded,
                size: 18,
                color: const Color(0xFFCDAF56),
              ),
              const SizedBox(width: 10),
              Text(
                'Notes',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            bill.notes!,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: isDark ? Colors.white70 : Colors.black54,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataCard(Bill bill, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        children: [
          _buildMetadataRow(
            label: 'Created',
            value: DateFormat('MMM dd, yyyy').format(bill.createdAt),
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _buildMetadataRow(
            label: 'Bill ID',
            value: '${bill.id.substring(0, 8)}...',
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataRow({
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(Bill bill, bool isDark) {
    return Column(
      children: [
        // Pay Now Button (if bill has next due date)
        if (bill.nextDueDate != null)
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () => _showPayBillSheet(context, bill, isDark),
              icon: const Icon(Icons.payment_rounded, size: 22),
              label: const Text(
                'PAY NOW',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  letterSpacing: 1,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCDAF56),
                foregroundColor: Colors.black87,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        if (bill.nextDueDate != null) const SizedBox(height: 12),

        // Edit Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddBillScreen(bill: bill),
                ),
              );
            },
            icon: Icon(
              Icons.edit_rounded,
              size: 20,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            label: Text(
              'EDIT ${bill.isSubscription ? 'SUBSCRIPTION' : 'BILL'}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                letterSpacing: 1,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    String? trailing,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFCDAF56).withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFFCDAF56)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white38 : Colors.black38,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null)
          Text(
            trailing,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: const Color(0xFFCDAF56),
            ),
          ),
      ],
    );
  }

  Widget _buildSectionLabel(String label, bool isDark) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: Color(0xFFCDAF56),
        letterSpacing: 1.2,
      ),
    );
  }

  void _showPayBillSheet(BuildContext context, Bill bill, bool isDark) {
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

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  String _formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(date.year, date.month, date.day);
    final diff = targetDate.difference(today).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    if (diff < 0) return '${-diff} days ago';
    if (diff < 7) return 'In $diff days';
    return DateFormat('MMM dd').format(date);
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  String _getEndConditionText(Bill bill) {
    switch (bill.endCondition) {
      case 'indefinite':
        return 'Never ends';
      case 'after_occurrences':
        return bill.endOccurrences != null
            ? 'After ${bill.endOccurrences} payments'
            : 'After X payments';
      case 'after_amount':
        return bill.endAmount != null
            ? 'After ${CurrencyUtils.getCurrencySymbol(bill.currency)}${bill.endAmount!.toStringAsFixed(0)} total'
            : 'After X amount';
      case 'on_date':
        return bill.endDate != null
            ? 'On ${_formatDate(bill.endDate!)}'
            : 'On specific date';
      default:
        return 'Unknown';
    }
  }

  String _getDaySuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }
}
