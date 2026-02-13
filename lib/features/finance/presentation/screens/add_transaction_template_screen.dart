import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/dark_gradient.dart';
import '../../../../core/widgets/icon_picker_widget.dart';
import '../../../../core/models/recurrence_rule.dart';
import '../../../../core/widgets/recurrence_picker_sheet.dart';
import '../../data/models/transaction_template.dart';
import '../../data/models/transaction_category.dart';
import '../../data/models/account.dart';
import '../providers/finance_providers.dart';
import '../../utils/currency_utils.dart';
import '../../data/services/finance_settings_service.dart';

class AddTransactionTemplateScreen extends ConsumerStatefulWidget {
  final TransactionTemplate? template;

  const AddTransactionTemplateScreen({super.key, this.template});

  @override
  ConsumerState<AddTransactionTemplateScreen> createState() =>
      _AddTransactionTemplateScreenState();
}

class _AddTransactionTemplateScreenState
    extends ConsumerState<AddTransactionTemplateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _transactionType = 'expense';
  TransactionCategory? _selectedCategory;
  Account? _selectedAccount;
  Account? _targetAccount;
  IconData _selectedIcon = Icons.receipt_long_rounded;
  bool _isRecurring = false;
  RecurrenceRule? _customRecurrence;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.template != null) {
      final t = widget.template!;
      _nameController.text = t.name;
      _titleController.text = t.transactionTitle;
      _amountController.text = t.amount.toString();
      _descriptionController.text = t.description ?? '';
      _transactionType = t.type;
      _selectedIcon = t.icon ?? Icons.receipt_long_rounded;
      _isRecurring = t.isRecurring;
      if (t.recurrenceRule != null) {
        try {
          _customRecurrence = RecurrenceRule.fromJson(t.recurrenceRule!);
        } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _titleController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categoriesAsync = ref.watch(allTransactionCategoriesProvider);
    final accountsAsync = ref.watch(activeAccountsProvider);

    // Initial value loading (reusing AddTransactionScreen logic)
    ref.listen<AsyncValue<List<Account>>>(activeAccountsProvider, (
      previous,
      next,
    ) {
      if (next.hasValue && _selectedAccount == null) {
        final accounts = next.value!;
        if (widget.template != null) {
          try {
            _selectedAccount = accounts.firstWhere(
              (a) => a.id == widget.template!.accountId,
            );
          } catch (e) {
            if (accounts.isNotEmpty) _selectedAccount = accounts.first;
          }
          if (_transactionType == 'transfer' && _targetAccount == null) {
            try {
              _targetAccount = accounts.firstWhere(
                (a) => a.id == widget.template!.toAccountId,
              );
            } catch (e) {
              _targetAccount = null;
            }
          }
        } else if (accounts.isNotEmpty) {
          _selectedAccount = accounts.firstWhere(
            (a) => a.isDefault,
            orElse: () => accounts.first,
          );
        }
        setState(() {});
      }
    });

    ref.listen<AsyncValue<List<TransactionCategory>>>(
      allTransactionCategoriesProvider,
      (previous, next) {
        if (next.hasValue && _selectedCategory == null) {
          final categories = next.value!;
          if (widget.template != null) {
            try {
              _selectedCategory = categories.firstWhere(
                (c) => c.id == widget.template!.categoryId,
              );
            } catch (e) {
              final filtered = categories
                  .where((c) => c.type == _transactionType || c.type == 'both')
                  .toList();
              if (filtered.isNotEmpty) _selectedCategory = filtered.first;
            }
          } else {
            final filtered = categories
                .where((c) => c.type == _transactionType || c.type == 'both')
                .toList();
            if (filtered.isNotEmpty) _selectedCategory = filtered.first;
          }
          setState(() {});
        }
      },
    );

    // Fallback manual checks for cases where listen doesn't trigger (data already cached)
    if ((_selectedAccount == null && accountsAsync.hasValue) ||
        (_selectedCategory == null && categoriesAsync.hasValue)) {
      Future.microtask(() {
        if (!mounted) return;
        bool changed = false;

        if (_selectedAccount == null && accountsAsync.hasValue) {
          final accounts = accountsAsync.value!;
          if (widget.template != null) {
            try {
              _selectedAccount = accounts.firstWhere(
                (a) => a.id == widget.template!.accountId,
              );
            } catch (e) {
              if (accounts.isNotEmpty) _selectedAccount = accounts.first;
            }
            if (_transactionType == 'transfer' && _targetAccount == null) {
              try {
                _targetAccount = accounts.firstWhere(
                  (a) => a.id == widget.template!.toAccountId,
                );
              } catch (e) {
                _targetAccount = null;
              }
            }
          } else if (accounts.isNotEmpty) {
            _selectedAccount = accounts.firstWhere(
              (a) => a.isDefault,
              orElse: () => accounts.first,
            );
          }
          changed = true;
        }

        if (_selectedCategory == null && categoriesAsync.hasValue) {
          final categories = categoriesAsync.value!;
          if (widget.template != null) {
            try {
              _selectedCategory = categories.firstWhere(
                (c) => c.id == widget.template!.categoryId,
              );
            } catch (e) {
              final filtered = categories
                  .where((c) => c.type == _transactionType || c.type == 'both')
                  .toList();
              if (filtered.isNotEmpty) _selectedCategory = filtered.first;
            }
          } else {
            final filtered = categories
                .where((c) => c.type == _transactionType || c.type == 'both')
                .toList();
            if (filtered.isNotEmpty) _selectedCategory = filtered.first;
          }
          changed = true;
        }

        if (changed) setState(() {});
      });
    }

    return Scaffold(
      body: isDark
          ? DarkGradient.wrap(
              child: _buildContent(
                context,
                isDark,
                categoriesAsync,
                accountsAsync,
              ),
            )
          : _buildContent(context, isDark, categoriesAsync, accountsAsync),
    );
  }

  Widget _buildContent(
    BuildContext context,
    bool isDark,
    AsyncValue<List<TransactionCategory>> categoriesAsync,
    AsyncValue<List<Account>> accountsAsync,
  ) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.template == null ? 'New Template' : 'Edit Template',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: isDark ? Colors.white : const Color(0xFF1E1E1E),
            letterSpacing: -0.5,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.close_rounded,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            const SizedBox(height: 16),
            _buildIconSelector(isDark),
            const SizedBox(height: 24),
            _buildNameField(isDark),
            const SizedBox(height: 24),
            _buildAmountInput(isDark),
            const SizedBox(height: 32),
            _buildTypeSelector(isDark),
            const SizedBox(height: 32),
            _buildDetailsCard(isDark, categoriesAsync, accountsAsync),
            const SizedBox(height: 24),
            _buildNotesCard(isDark),
            const SizedBox(height: 32),
            _buildSaveButton(isDark),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildIconSelector(bool isDark) {
    return Center(
      child: GestureDetector(
        onTap: () async {
          final icon = await showDialog<IconData>(
            context: context,
            builder: (context) =>
                IconPickerWidget(selectedIcon: _selectedIcon, isDark: isDark),
          );
          if (icon != null) {
            setState(() => _selectedIcon = icon);
          }
        },
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFFCDAF56).withOpacity(0.1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFCDAF56).withOpacity(0.3)),
          ),
          child: Icon(_selectedIcon, size: 32, color: const Color(0xFFCDAF56)),
        ),
      ),
    );
  }

  Widget _buildNameField(bool isDark) {
    return _buildTextField(
      controller: _nameController,
      label: 'TEMPLATE NAME',
      hint: 'e.g., Monthly Rent, Coffee Run...',
      icon: Icons.bookmark_outline_rounded,
      isDark: isDark,
    );
  }

  Widget _buildAmountInput(bool isDark) {
    final typeColor = _transactionType == 'expense'
        ? Colors.redAccent
        : (_transactionType == 'income'
              ? Colors.greenAccent
              : const Color(0xFFCDAF56));

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.03)
            : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: typeColor.withOpacity(0.2), width: 1.5),
      ),
      child: Column(
        children: [
          Text(
            'DEFAULT AMOUNT',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: typeColor.withOpacity(0.7),
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF1E1E1E),
              letterSpacing: -2,
            ),
            decoration: InputDecoration(
              prefixText:
                  '${CurrencyUtils.getCurrencySymbol(_selectedAccount?.currency ?? FinanceSettingsService.fallbackCurrency)} ',
              prefixStyle: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: typeColor.withOpacity(0.6),
              ),
              border: InputBorder.none,
              hintText: '0.00',
              hintStyle: TextStyle(
                color: isDark ? Colors.white12 : Colors.grey[300],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSelector(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.03)
            : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Row(
        children: [
          _buildTypeButton(
            'expense',
            'Expense',
            Icons.arrow_upward_rounded,
            Colors.redAccent,
            isDark,
          ),
          const SizedBox(width: 8),
          _buildTypeButton(
            'income',
            'Income',
            Icons.arrow_downward_rounded,
            Colors.greenAccent,
            isDark,
          ),
          const SizedBox(width: 8),
          _buildTypeButton(
            'transfer',
            'Transfer',
            Icons.swap_horiz_rounded,
            Colors.blueAccent,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildTypeButton(
    String type,
    String label,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    final isSelected = _transactionType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() {
            _transactionType = type;
            if (_selectedCategory != null &&
                _selectedCategory!.type != 'both' &&
                _selectedCategory!.type != _transactionType) {
              _selectedCategory = null;
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white24 : Colors.grey[400]),
                size: 20,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white38 : Colors.grey[500]),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsCard(
    bool isDark,
    AsyncValue<List<TransactionCategory>> categoriesAsync,
    AsyncValue<List<Account>> accountsAsync,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel('TEMPLATE DETAILS'),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _titleController,
            label: 'Title / Payee',
            hint: 'e.g., Grocery Store',
            icon: Icons.label_outline_rounded,
            isDark: isDark,
          ),
          const SizedBox(height: 20),
          categoriesAsync.when(
            data: (categories) => _buildCategoryDropdown(categories, isDark),
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const Text('Error loading categories'),
          ),
          const SizedBox(height: 20),
          accountsAsync.when(
            data: (accounts) => _buildAccountPickers(accounts, isDark),
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const Text('Error loading accounts'),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryDropdown(
    List<TransactionCategory> categories,
    bool isDark,
  ) {
    final filteredCategories = categories
        .where((c) => c.type == _transactionType || c.type == 'both')
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('CATEGORY', isDark),
        const SizedBox(height: 10),
        DropdownButtonFormField<TransactionCategory>(
          value: _selectedCategory,
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
          dropdownColor: isDark ? const Color(0xFF1A1D23) : Colors.white,
          decoration: InputDecoration(
            prefixIcon: const Icon(
              Icons.category_rounded,
              size: 20,
              color: Color(0xFFCDAF56),
            ),
            filled: true,
            fillColor: isDark
                ? Colors.white.withOpacity(0.02)
                : Colors.black.withOpacity(0.01),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
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
          ),
          items: filteredCategories
              .map(
                (c) => DropdownMenuItem(
                  value: c,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: c.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          c.icon ?? Icons.category_rounded,
                          color: c.color,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          c.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: (val) => setState(() => _selectedCategory = val),
        ),
      ],
    );
  }

  Widget _buildAccountPickers(List<Account> accounts, bool isDark) {
    if (_transactionType == 'transfer') {
      return Column(
        children: [
          _buildAccountDropdown(
            'FROM ACCOUNT',
            _selectedAccount,
            accounts,
            (val) => setState(() => _selectedAccount = val),
            isDark,
          ),
          const SizedBox(height: 20),
          _buildAccountDropdown(
            'TO ACCOUNT',
            _targetAccount,
            accounts,
            (val) => setState(() => _targetAccount = val),
            isDark,
          ),
        ],
      );
    }
    return _buildAccountDropdown(
      'ACCOUNT',
      _selectedAccount,
      accounts,
      (val) => setState(() => _selectedAccount = val),
      isDark,
    );
  }

  Widget _buildAccountDropdown(
    String label,
    Account? value,
    List<Account> accounts,
    Function(Account?) onChanged,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label, isDark),
        const SizedBox(height: 10),
        DropdownButtonFormField<Account>(
          value: value,
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
          dropdownColor: isDark ? const Color(0xFF1A1D23) : Colors.white,
          decoration: InputDecoration(
            prefixIcon: const Icon(
              Icons.account_balance_wallet_rounded,
              size: 20,
              color: Color(0xFFCDAF56),
            ),
            filled: true,
            fillColor: isDark
                ? Colors.white.withOpacity(0.02)
                : Colors.black.withOpacity(0.01),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
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
          ),
          items: accounts
              .map(
                (a) => DropdownMenuItem(
                  value: a,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: a.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          a.icon ?? Icons.account_balance_wallet_rounded,
                          color: a.color,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          a.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildNotesCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel('ADDITIONAL INFO'),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _descriptionController,
            label: 'Description / Notes',
            hint: 'Optional notes...',
            icon: Icons.notes_rounded,
            isDark: isDark,
            maxLines: 3,
          ),
          const SizedBox(height: 20),
          _buildModernSwitch(
            title: 'Is Recurring',
            subtitle: _isRecurring && _customRecurrence != null
                ? _customRecurrence!.getDescription()
                : 'Default recurrence for this template',
            value: _isRecurring,
            onChanged: (val) async {
              if (val) {
                final rule = await showModalBottomSheet<RecurrenceRule>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => RecurrencePickerSheet(
                    isDark: isDark,
                    initialRule:
                        _customRecurrence ??
                        RecurrenceRule.daily(startDate: DateTime.now()),
                  ),
                );
                if (rule != null) {
                  setState(() {
                    _isRecurring = true;
                    _customRecurrence = rule;
                  });
                }
              } else {
                setState(() => _isRecurring = false);
              }
            },
            icon: Icons.repeat_rounded,
            isDark: isDark,
          ),
          if (_isRecurring && _customRecurrence != null)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 52),
              child: TextButton.icon(
                onPressed: () async {
                  final rule = await showModalBottomSheet<RecurrenceRule>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => RecurrencePickerSheet(
                      isDark: isDark,
                      initialRule: _customRecurrence,
                    ),
                  );
                  if (rule != null) {
                    setState(() => _customRecurrence = rule);
                  }
                },
                icon: const Icon(Icons.edit_calendar_rounded, size: 16),
                label: const Text('EDIT SCHEDULE'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFCDAF56),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveTemplate,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFCDAF56),
          disabledBackgroundColor: const Color(0xFFCDAF56).withOpacity(0.5),
          foregroundColor: const Color(0xFF1E1E1E),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: _isSaving
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.black,
                  strokeWidth: 3,
                ),
              )
            : Text(
                widget.template == null ? 'CREATE TEMPLATE' : 'UPDATE TEMPLATE',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 1,
                ),
              ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        color: Color(0xFFCDAF56),
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildFieldLabel(String label, bool isDark) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: isDark ? Colors.white38 : Colors.black38,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label, isDark),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: isDark ? Colors.white10 : Colors.black12,
            ),
            prefixIcon: Icon(icon, size: 20, color: const Color(0xFFCDAF56)),
            filled: true,
            fillColor: isDark
                ? Colors.white.withOpacity(0.02)
                : Colors.black.withOpacity(0.01),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
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
              borderSide: const BorderSide(
                color: Color(0xFFCDAF56),
                width: 1.5,
              ),
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
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.02)
            : Colors.black.withOpacity(0.01),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white24 : Colors.black26,
          ),
        ),
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFCDAF56).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFFCDAF56), size: 18),
        ),
        value: value,
        onChanged: (val) {
          HapticFeedback.selectionClick();
          onChanged(val);
        },
        activeColor: const Color(0xFFCDAF56),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Future<void> _saveTemplate() async {
    if (_nameController.text.isEmpty || _titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter template name and title')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final repository = ref.read(transactionTemplateRepositoryProvider);

      final template = TransactionTemplate(
        id: widget.template?.id,
        name: _nameController.text.trim(),
        transactionTitle: _titleController.text.trim(),
        amount: double.tryParse(_amountController.text) ?? 0.0,
        type: _transactionType,
        categoryId: _selectedCategory?.id,
        accountId: _selectedAccount?.id,
        toAccountId: _transactionType == 'transfer' ? _targetAccount?.id : null,
        description: _descriptionController.text.trim(),
        icon: _selectedIcon,
        isRecurring: _isRecurring,
        recurrenceRule: _isRecurring ? _customRecurrence?.toJson() : null,
      );

      if (widget.template == null) {
        await repository.createTemplate(template);
      } else {
        await repository.updateTemplate(template);
      }

      ref.invalidate(allTransactionTemplatesProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
