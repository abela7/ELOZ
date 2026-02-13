import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/dark_gradient.dart';
import '../../data/models/transaction_template.dart';
import '../providers/finance_providers.dart';
import 'add_transaction_template_screen.dart';

class TransactionTemplatesScreen extends ConsumerWidget {
  const TransactionTemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final templatesAsync = ref.watch(allTransactionTemplatesProvider);

    return Scaffold(
      body: isDark
          ? DarkGradient.wrap(
              child: _buildContent(context, ref, isDark, templatesAsync),
            )
          : _buildContent(context, ref, isDark, templatesAsync),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddTemplate(context),
        backgroundColor: const Color(0xFFCDAF56),
        foregroundColor: const Color(0xFF1E1E1E),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    AsyncValue<List<TransactionTemplate>> templatesAsync,
  ) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Transaction Templates',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: isDark ? Colors.white : const Color(0xFF1E1E1E),
            letterSpacing: -0.5,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white70 : Colors.black87,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: templatesAsync.when(
        data: (templates) {
          if (templates.isEmpty) {
            return _buildEmptyState(isDark);
          }
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: templates.length,
            itemBuilder: (context, index) {
              final template = templates[index];
              return _buildTemplateCard(context, ref, template, isDark);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_rounded,
            size: 80,
            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
          ),
          const SizedBox(height: 24),
          Text(
            'No Templates Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create templates for your frequent transactions',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateCard(
    BuildContext context,
    WidgetRef ref,
    TransactionTemplate template,
    bool isDark,
  ) {
    final typeColor = template.type == 'expense'
        ? Colors.redAccent
        : (template.type == 'income'
              ? Colors.greenAccent
              : const Color(0xFFCDAF56));

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.03)
            : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.05),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: typeColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            template.icon ?? Icons.receipt_long_rounded,
            color: typeColor,
            size: 24,
          ),
        ),
        title: Text(
          template.name,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: isDark ? Colors.white : const Color(0xFF1E1E1E),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${template.transactionTitle} • ${template.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => _navigateToEditTemplate(context, template),
              color: isDark ? Colors.white38 : Colors.black38,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              onPressed: () => _confirmDelete(context, ref, template),
              color: Colors.redAccent.withOpacity(0.7),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToAddTemplate(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddTransactionTemplateScreen(),
      ),
    );
  }

  void _navigateToEditTemplate(
    BuildContext context,
    TransactionTemplate template,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddTransactionTemplateScreen(template: template),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    TransactionTemplate template,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Template?'),
        content: Text('Are you sure you want to delete "${template.name}"?'),
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
      await ref
          .read(transactionTemplateRepositoryProvider)
          .deleteTemplate(template.id);
      ref.invalidate(allTransactionTemplatesProvider);
    }
  }
}
