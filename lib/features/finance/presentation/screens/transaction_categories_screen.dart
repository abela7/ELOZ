import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/dark_gradient.dart';
import '../../../../core/widgets/icon_picker_widget.dart';
import '../../../../core/widgets/color_picker_widget.dart';
import '../../data/models/transaction_category.dart';
import '../../data/services/finance_settings_service.dart';
import '../../utils/currency_utils.dart';
import '../providers/finance_providers.dart';

/// Transaction Categories Management Screen
class TransactionCategoriesScreen extends ConsumerStatefulWidget {
  const TransactionCategoriesScreen({super.key});

  @override
  ConsumerState<TransactionCategoriesScreen> createState() =>
      _TransactionCategoriesScreenState();
}

class _TransactionCategoriesScreenState
    extends ConsumerState<TransactionCategoriesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = 'all'; // 'all', 'income', 'expense'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedFilter = ['all', 'income', 'expense'][_tabController.index];
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: isDark
          ? DarkGradient.wrap(child: _buildContent(context, isDark))
          : _buildContent(context, isDark),
    );
  }

  Widget _buildContent(BuildContext context, bool isDark) {
    final categoriesAsync = ref.watch(allTransactionCategoriesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Transaction Categories'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => _showCategoryInfo(context, isDark),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFCDAF56),
          labelColor: const Color(0xFFCDAF56),
          unselectedLabelColor: isDark ? Colors.white60 : Colors.grey[600],
          tabs: const [
            Tab(text: 'All Categories'),
            Tab(text: 'Income'),
            Tab(text: 'Expense'),
          ],
        ),
      ),
      body: categoriesAsync.when(
        data: (categories) => _buildCategoriesList(context, isDark, categories),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            Center(child: Text('Error loading categories: $error')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCategoryDialog(context, isDark),
        backgroundColor: const Color(0xFFCDAF56),
        icon: const Icon(Icons.add_rounded, color: Color(0xFF1E1E1E)),
        label: const Text(
          'Add Category',
          style: TextStyle(
            color: Color(0xFF1E1E1E),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoriesList(
    BuildContext context,
    bool isDark,
    List<TransactionCategory> allCategories,
  ) {
    // Filter categories based on selected tab
    List<TransactionCategory> filteredCategories;
    switch (_selectedFilter) {
      case 'income':
        filteredCategories = allCategories
            .where((c) => c.type == 'income')
            .toList();
        break;
      case 'expense':
        filteredCategories = allCategories
            .where((c) => c.type == 'expense')
            .toList();
        break;
      default:
        filteredCategories = allCategories;
    }

    if (filteredCategories.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset(
                'assets/animations/big-frown.json',
                width: 160,
                height: 160,
                repeat: true,
              ),
              const SizedBox(height: 24),
              Text(
                _selectedFilter == 'all'
                    ? 'No Categories Yet'
                    : 'No ${_selectedFilter.toUpperCase()} Categories',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _selectedFilter == 'all'
                    ? 'Start organizing your finances by creating your first category.'
                    : 'You haven\'t created any ${_selectedFilter} categories yet.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => _showAddCategoryDialog(context, isDark),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create Category'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCDAF56),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Separate system and custom categories
    final systemCategories = filteredCategories
        .where((c) => c.isSystemCategory)
        .toList();
    final customCategories = filteredCategories
        .where((c) => !c.isSystemCategory)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // System Categories Section
        if (systemCategories.isNotEmpty) ...[
          _buildSectionHeader(context, isDark, 'System Categories'),
          const SizedBox(height: 12),
          ...systemCategories.map(
            (category) =>
                _buildCategoryCard(context, isDark, category, isSystem: true),
          ),
          const SizedBox(height: 24),
        ],

        // Custom Categories Section
        if (customCategories.isNotEmpty) ...[
          _buildSectionHeader(context, isDark, 'Custom Categories'),
          const SizedBox(height: 12),
          ...customCategories.map(
            (category) =>
                _buildCategoryCard(context, isDark, category, isSystem: false),
          ),
        ],

        const SizedBox(height: 80), // Space for FAB
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, bool isDark, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: const Color(0xFFCDAF56),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    bool isDark,
    TransactionCategory category, {
    required bool isSystem,
  }) {
    final defaultCurrencyAsync = ref.watch(defaultCurrencyProvider);
    final defaultCurrency =
        defaultCurrencyAsync.value ?? FinanceSettingsService.fallbackCurrency;
    final currencySymbol = CurrencyUtils.getCurrencySymbol(defaultCurrency);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D3139) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: category.color.withOpacity(isDark ? 0.15 : 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: category.color.withOpacity(isDark ? 0.05 : 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              _showEditCategoryDialog(context, isDark, category);
            },
            onLongPress: () {
              HapticFeedback.mediumImpact();
              _showCategoryOptions(context, isDark, category, isSystem);
            },
            child: Stack(
              children: [
                // Visual accent for budget categories
                if (category.monthlyBudget != null)
                  Positioned(
                    right: -10,
                    top: -10,
                    child: Icon(
                      Icons.pie_chart_rounded,
                      size: 60,
                      color: category.color.withOpacity(0.05),
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      // Enhanced Icon Container
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              category.color.withOpacity(0.2),
                              category.color.withOpacity(0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: category.color.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          category.icon ?? Icons.category_rounded,
                          color: category.color,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    category.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                          color: isDark
                                              ? Colors.white
                                              : const Color(0xFF1E1E1E),
                                          letterSpacing: -0.3,
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _buildTypeBadge(context, isDark, category.type),
                              ],
                            ),
                            if (category.description != null &&
                                category.description!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                category.description!,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: isDark
                                          ? const Color(0xFFBDBDBD)
                                          : const Color(0xFF6E6E6E),
                                      fontWeight: FontWeight.w500,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                if (category.monthlyBudget != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFFCDAF56,
                                      ).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.account_balance_wallet_rounded,
                                          size: 10,
                                          color: Color(0xFFCDAF56),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$currencySymbol${category.monthlyBudget!.toStringAsFixed(0)}/mo',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFFCDAF56),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (category.monthlyBudget != null && isSystem)
                                  const SizedBox(width: 8),
                                if (isSystem)
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline_rounded,
                                        size: 12,
                                        color: isDark
                                            ? Colors.white24
                                            : Colors.grey[400],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'PRESET',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: isDark
                                              ? Colors.white24
                                              : Colors.grey[400],
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // More Menu
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert_rounded,
                          color: isDark ? Colors.white38 : Colors.grey[400],
                          size: 20,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showEditCategoryDialog(context, isDark, category);
                          } else if (value == 'delete') {
                            _confirmDeleteCategory(context, isDark, category);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_rounded, size: 18),
                                SizedBox(width: 12),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_rounded,
                                  size: 18,
                                  color: Colors.red,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
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
        ),
      ),
    );
  }

  Widget _buildTypeBadge(BuildContext context, bool isDark, String type) {
    Color badgeColor;
    IconData badgeIcon;
    String badgeText;

    switch (type) {
      case 'income':
        badgeColor = Colors.green;
        badgeIcon = Icons.arrow_downward_rounded;
        badgeText = 'Income';
        break;
      case 'expense':
        badgeColor = Colors.red;
        badgeIcon = Icons.arrow_upward_rounded;
        badgeText = 'Expense';
        break;
      default:
        badgeColor = Colors.blue;
        badgeIcon = Icons.swap_horiz_rounded;
        badgeText = 'Both';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, size: 12, color: badgeColor),
          const SizedBox(width: 4),
          Text(
            badgeText,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: badgeColor,
            ),
          ),
        ],
      ),
    );
  }

  void _showCategoryOptions(
    BuildContext context,
    bool isDark,
    TransactionCategory category,
    bool isSystem,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D3139) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Category info
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: category.color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        category.icon ?? Icons.category_rounded,
                        color: category.color,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category.name,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1E1E1E),
                                ),
                          ),
                          if (isSystem) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Preset Category',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.white60
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Options
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCDAF56).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    color: Color(0xFFCDAF56),
                    size: 20,
                  ),
                ),
                title: const Text('Edit Category'),
                subtitle: const Text('Modify name, icon, color, or budget'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showEditCategoryDialog(context, isDark, category);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.delete_rounded,
                    color: Colors.red,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Delete Category',
                  style: TextStyle(color: Colors.red),
                ),
                subtitle: const Text(
                  'Remove this category permanently',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _confirmDeleteCategory(context, isDark, category);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => _AddEditCategoryDialog(isDark: isDark),
    );
  }

  void _showEditCategoryDialog(
    BuildContext context,
    bool isDark,
    TransactionCategory category,
  ) {
    showDialog(
      context: context,
      builder: (context) =>
          _AddEditCategoryDialog(isDark: isDark, category: category),
    );
  }

  void _confirmDeleteCategory(
    BuildContext context,
    bool isDark,
    TransactionCategory category,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF2D3139) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.warning_rounded,
                color: Colors.red,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Delete Category?')),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${category.name}"? This action cannot be undone.',
          style: TextStyle(
            color: isDark ? const Color(0xFFBDBDBD) : const Color(0xFF6E6E6E),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.grey[700],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await ref
                    .read(transactionCategoryRepositoryProvider)
                    .deleteCategory(category.id);
                if (mounted) {
                  ref.invalidate(allTransactionCategoriesProvider);
                  ref.invalidate(expenseTransactionCategoriesProvider);
                  ref.invalidate(incomeTransactionCategoriesProvider);
                }
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Category deleted'),
                      backgroundColor: Color(0xFFCDAF56),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting category: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showCategoryInfo(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF2D3139) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFCDAF56).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.info_rounded,
                color: Color(0xFFCDAF56),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('About Categories')),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            'Categories help you organize and track your transactions.\n\n'
            '• Long-press any category to edit or delete\n'
            '• Tap a category to edit it directly\n'
            '• Set monthly budgets for better spending control\n'
            '• Choose icons and colors to easily identify categories\n'
            '• Preset categories can be customized or removed',
            style: TextStyle(
              color: isDark ? const Color(0xFFBDBDBD) : const Color(0xFF6E6E6E),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Got it',
              style: TextStyle(color: Color(0xFFCDAF56)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Add/Edit Category Dialog
class _AddEditCategoryDialog extends ConsumerStatefulWidget {
  final bool isDark;
  final TransactionCategory? category;

  const _AddEditCategoryDialog({required this.isDark, this.category});

  @override
  ConsumerState<_AddEditCategoryDialog> createState() =>
      _AddEditCategoryDialogState();
}

class _AddEditCategoryDialogState
    extends ConsumerState<_AddEditCategoryDialog> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _budgetController;

  IconData _selectedIcon = Icons.category_rounded;
  Color _selectedColor = Colors.blue;
  String _selectedType = 'expense';
  bool _hasBudget = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _descriptionController = TextEditingController(
      text: widget.category?.description ?? '',
    );
    _budgetController = TextEditingController(
      text: widget.category?.monthlyBudget?.toStringAsFixed(0) ?? '',
    );

    if (widget.category != null) {
      _selectedIcon = widget.category!.icon ?? Icons.category_rounded;
      _selectedColor = widget.category!.color;
      _selectedType = widget.category!.type;
      _hasBudget = widget.category!.monthlyBudget != null;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.category != null;
    final defaultCurrencyAsync = ref.watch(defaultCurrencyProvider);
    final defaultCurrency =
        defaultCurrencyAsync.value ?? FinanceSettingsService.fallbackCurrency;
    final currencySymbol = CurrencyUtils.getCurrencySymbol(defaultCurrency);

    return Dialog(
      backgroundColor: widget.isDark ? const Color(0xFF1A1D23) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Custom Header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              decoration: BoxDecoration(
                color: widget.isDark
                    ? const Color(0xFF2D3139)
                    : Colors.grey[50],
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCDAF56).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      isEdit ? Icons.edit_rounded : Icons.add_rounded,
                      color: const Color(0xFFCDAF56),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit ? 'Edit Category' : 'Add New Category',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: widget.isDark
                                ? Colors.white
                                : const Color(0xFF1E1E1E),
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'Organize your transactions beautifully',
                          style: TextStyle(
                            fontSize: 12,
                            color: widget.isDark
                                ? Colors.white38
                                : Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: widget.isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.05),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Visual Identity Section
                  _buildSectionLabel('CATEGORY IDENTITY'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildIdentityOption(
                        context,
                        'Pick Icon',
                        _selectedIcon,
                        _selectedColor,
                        () => _showIconPicker(context),
                        isIcon: true,
                      ),
                      const SizedBox(width: 16),
                      _buildIdentityOption(
                        context,
                        'Pick Color',
                        null,
                        _selectedColor,
                        () => _showColorPicker(context),
                        isIcon: false,
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Form Fields Section
                  _buildSectionLabel('BASIC INFORMATION'),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _nameController,
                    label: 'Category Name',
                    hint: 'e.g., Groceries',
                    icon: Icons.label_rounded,
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _descriptionController,
                    label: 'Description',
                    hint: 'Optional details...',
                    icon: Icons.description_rounded,
                  ),
                  const SizedBox(height: 28),

                  // Type Selection
                  _buildSectionLabel('CATEGORY TYPE'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTypeChip(
                          'Income',
                          'income',
                          Icons.arrow_downward_rounded,
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTypeChip(
                          'Expense',
                          'expense',
                          Icons.arrow_upward_rounded,
                          Colors.red,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTypeChip(
                          'Both',
                          'both',
                          Icons.swap_horiz_rounded,
                          Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Settings Section
                  _buildSectionLabel('BUDGET SETTINGS'),
                  const SizedBox(height: 12),
                  _buildModernSwitch(
                    title: 'Set Monthly Budget',
                    subtitle: 'Track spending against a limit',
                    value: _hasBudget,
                    onChanged: (value) {
                      setState(() {
                        _hasBudget = value;
                        if (!_hasBudget) _budgetController.clear();
                      });
                    },
                    icon: Icons.pie_chart_rounded,
                  ),

                  if (_hasBudget) ...[
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _budgetController,
                      label: 'Budget Amount',
                      hint: '0.00',
                      icon: Icons.account_balance_wallet_rounded,
                      isNumeric: true,
                      prefix: '$currencySymbol ',
                    ),
                  ],
                  const SizedBox(height: 32),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(
                              color: widget.isDark
                                  ? Colors.white12
                                  : Colors.grey[300]!,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: widget.isDark
                                  ? Colors.white70
                                  : Colors.grey[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _saveCategory,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFCDAF56),
                            foregroundColor: const Color(0xFF1E1E1E),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 8,
                            shadowColor: const Color(
                              0xFFCDAF56,
                            ).withOpacity(0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            isEdit ? 'SAVE CHANGES' : 'CREATE CATEGORY',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
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

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: const Color(0xFFCDAF56),
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildIdentityOption(
    BuildContext context,
    String label,
    IconData? icon,
    Color color,
    VoidCallback onTap, {
    required bool isIcon,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 64,
              decoration: BoxDecoration(
                color: widget.isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isIcon
                      ? color.withOpacity(0.3)
                      : color.withOpacity(0.6),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: isIcon
                    ? Icon(icon, color: color, size: 28)
                    : Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: widget.isDark ? Colors.white54 : Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isNumeric = false,
    String? prefix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: widget.isDark ? Colors.white70 : Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: isNumeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : null,
          style: TextStyle(
            color: widget.isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixText: prefix,
            prefixIcon: Icon(icon, size: 20, color: const Color(0xFFCDAF56)),
            filled: true,
            fillColor: widget.isDark
                ? Colors.white.withOpacity(0.03)
                : Colors.grey.withOpacity(0.03),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: widget.isDark ? Colors.white10 : Colors.grey[200]!,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: widget.isDark ? Colors.white10 : Colors.grey[200]!,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFFCDAF56),
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.white.withOpacity(0.02)
            : Colors.grey.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 11,
            color: widget.isDark ? Colors.white38 : Colors.grey[600],
          ),
        ),
        secondary: Icon(icon, color: const Color(0xFFCDAF56), size: 20),
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFFCDAF56),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildTypeChip(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final isSelected = _selectedType == value;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _selectedType = value);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.1)
              : (widget.isDark
                    ? Colors.white.withOpacity(0.03)
                    : Colors.grey.withOpacity(0.03)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color.withOpacity(0.5) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? color
                  : (widget.isDark ? Colors.white24 : Colors.grey[400]),
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? color
                    : (widget.isDark ? Colors.white24 : Colors.grey[400]),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showIconPicker(BuildContext context) async {
    final icon = await showDialog<IconData>(
      context: context,
      builder: (context) =>
          IconPickerWidget(selectedIcon: _selectedIcon, isDark: widget.isDark),
    );
    if (icon != null) {
      setState(() => _selectedIcon = icon);
    }
  }

  Future<void> _showColorPicker(BuildContext context) async {
    final color = await showDialog<Color>(
      context: context,
      builder: (context) => ColorPickerWidget(
        selectedColor: _selectedColor,
        isDark: widget.isDark,
      ),
    );
    if (color != null) {
      setState(() => _selectedColor = color);
    }
  }

  Future<void> _saveCategory() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a category name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final categoryRepo = ref.read(transactionCategoryRepositoryProvider);

      if (widget.category != null) {
        // Update existing category
        final updated = widget.category!.copyWith(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          iconCodePoint: _selectedIcon.codePoint,
          iconFontFamily: _selectedIcon.fontFamily,
          iconFontPackage: _selectedIcon.fontPackage,
          colorValue: _selectedColor.value,
          type: _selectedType,
          monthlyBudget: _hasBudget && _budgetController.text.trim().isNotEmpty
              ? double.tryParse(_budgetController.text.trim())
              : null,
        );
        await categoryRepo.updateCategory(updated);
      } else {
        // Create new category
        final newCategory = TransactionCategory(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          iconCodePoint: _selectedIcon.codePoint,
          iconFontFamily: _selectedIcon.fontFamily,
          iconFontPackage: _selectedIcon.fontPackage,
          colorValue: _selectedColor.value,
          type: _selectedType,
          isSystemCategory: false,
          monthlyBudget: _hasBudget && _budgetController.text.trim().isNotEmpty
              ? double.tryParse(_budgetController.text.trim())
              : null,
        );
        await categoryRepo.createCategory(newCategory);
      }

      ref.invalidate(allTransactionCategoriesProvider);
      ref.invalidate(expenseTransactionCategoriesProvider);
      ref.invalidate(incomeTransactionCategoriesProvider);

      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.category != null
                  ? 'Category updated!'
                  : 'Category created!',
            ),
            backgroundColor: const Color(0xFFCDAF56),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
