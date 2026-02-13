import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/recurring_income.dart';
import '../../finance_module.dart';
import '../providers/income_providers.dart';
import '../providers/finance_providers.dart';
import 'add_recurring_income_screen.dart';
import 'recurring_income_detail_screen.dart';

class RecurringIncomeScreen extends ConsumerWidget {
  const RecurringIncomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incomesAsync = ref.watch(recurringIncomesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1D1E33),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Recurring Income',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: Color(0xFF4CAF50)),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AddRecurringIncomeScreen(),
              ),
            ),
          ),
        ],
      ),
      body: incomesAsync.when(
        data: (incomes) => _buildContent(context, ref, incomes),
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
        ),
        error: (error, stack) => Center(
          child: Text(
            'Error loading recurring income',
            style: TextStyle(color: Colors.red[300]),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    List<RecurringIncome> incomes,
  ) {
    if (incomes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.repeat_rounded,
              size: 80,
              color: Colors.grey[700],
            ),
            const SizedBox(height: 16),
            Text(
              'No recurring income yet',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to add your first recurring income',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    final activeIncomes = incomes.where((i) => i.isCurrentlyActive).toList();
    final inactiveIncomes = incomes.where((i) => !i.isCurrentlyActive).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (activeIncomes.isNotEmpty) ...[
          _buildSectionHeader('Active', activeIncomes.length),
          const SizedBox(height: 12),
          ...activeIncomes.map((income) => _buildIncomeCard(context, ref, income)),
          const SizedBox(height: 24),
        ],
        if (inactiveIncomes.isNotEmpty) ...[
          _buildSectionHeader('Inactive', inactiveIncomes.length),
          const SizedBox(height: 12),
          ...inactiveIncomes.map((income) => _buildIncomeCard(context, ref, income)),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50).withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: Color(0xFF4CAF50),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIncomeCard(
    BuildContext context,
    WidgetRef ref,
    RecurringIncome income,
  ) {
    final category = ref.watch(transactionCategoryByIdProvider(income.categoryId));
    final nextOccurrence = income.nextOccurrenceAfter(DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: income.isCurrentlyActive
              ? const Color(0xFF4CAF50).withOpacity(0.3)
              : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RecurringIncomeDetailScreen(
                recurringIncomeId: income.id,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (category != null)
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: category.color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          category.icon,
                          color: category.color,
                          size: 24,
                        ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            income.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (income.payerName != null)
                            Text(
                              income.payerName!,
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
                      color: const Color(0xFF2A2D47),
                      onSelected: (value) => _handleMenuAction(
                        context,
                        ref,
                        value,
                        income,
                      ),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_rounded, color: Colors.white70, size: 20),
                              SizedBox(width: 12),
                              Text('Edit', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: income.isActive ? 'deactivate' : 'activate',
                          child: Row(
                            children: [
                              Icon(
                                income.isActive
                                    ? Icons.pause_circle_rounded
                                    : Icons.play_circle_rounded,
                                color: Colors.white70,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                income.isActive ? 'Deactivate' : 'Activate',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_rounded, color: Colors.red, size: 20),
                              SizedBox(width: 12),
                              Text('Delete', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoChip(
                        icon: Icons.attach_money_rounded,
                        label: '${income.currency} ${income.amount.toStringAsFixed(2)}',
                        color: const Color(0xFF4CAF50),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildInfoChip(
                        icon: Icons.repeat_rounded,
                        label: income.frequencyLabel,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                if (nextOccurrence != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.event_rounded,
                          color: Color(0xFF4CAF50),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Next: ${_formatDate(nextOccurrence)}',
                          style: const TextStyle(
                            color: Color(0xFF4CAF50),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        if (income.autoCreateTransaction)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Auto',
                              style: TextStyle(
                                color: Color(0xFF4CAF50),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                if (income.endDate != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.event_busy_rounded,
                        color: Colors.grey[500],
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Ends: ${_formatDate(income.endDate!)}',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    RecurringIncome income,
  ) async {
    final repo = ref.read(recurringIncomeRepositoryProvider);

    switch (action) {
      case 'edit':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddRecurringIncomeScreen(income: income),
          ),
        );
        break;
      case 'activate':
        await repo.reactivate(income.id);
        ref.invalidate(recurringIncomesProvider);
        await FinanceModule.refreshIncomeNotifications();
        break;
      case 'deactivate':
        await repo.deactivate(income.id);
        ref.invalidate(recurringIncomesProvider);
        await FinanceModule.refreshIncomeNotifications();
        break;
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1D1E33),
            title: const Text('Delete Income', style: TextStyle(color: Colors.white)),
            content: Text(
              'Are you sure you want to delete "${income.title}"?\n\nThis action cannot be undone.',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          await repo.delete(income.id);
          ref.invalidate(recurringIncomesProvider);
          await FinanceModule.refreshIncomeNotifications();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${income.title} deleted'),
                backgroundColor: const Color(0xFF4CAF50),
              ),
            );
          }
        }
        break;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
