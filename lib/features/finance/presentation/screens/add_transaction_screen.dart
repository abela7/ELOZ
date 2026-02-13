import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/dark_gradient.dart';
import '../../data/models/transaction.dart' as finance;
import '../../data/models/transaction_category.dart';
import '../../data/models/transaction_template.dart';
import '../../data/models/bill.dart';
// Income categories now use TransactionCategory
import '../../data/models/account.dart';
import '../../../../core/models/recurrence_rule.dart';
import '../../../../core/widgets/recurrence_picker_sheet.dart';
import '../providers/finance_providers.dart';
// Income providers no longer needed - using unified TransactionCategory system
import '../../data/services/finance_settings_service.dart';
import '../../utils/currency_utils.dart';
import 'transaction_templates_screen.dart';
import 'transaction_categories_screen.dart';

/// Add Transaction Screen - Modern UI for adding Income, Expenses, and Transfers
class AddTransactionScreen extends ConsumerStatefulWidget {
  final finance.Transaction? transaction; // Optional for editing
  final String? initialType; // 'income', 'expense', 'transfer'
  final String? initialCategoryId; // Pre-select category

  const AddTransactionScreen({
    super.key,
    this.transaction,
    this.initialType,
    this.initialCategoryId,
  });

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Initialize to midnight today for consistent date filtering
  DateTime _selectedDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  TimeOfDay _selectedTime = TimeOfDay.now();
  String _transactionType = 'expense'; // 'income', 'expense', 'transfer'

  TransactionCategory? _selectedCategory;
  // Income now uses the same TransactionCategory as expenses
  Account? _selectedAccount;
  Account? _targetAccount; // For transfers
  Bill? _selectedBill; // Optional bill/subscription link for expenses

  bool _isRecurring = false;
  RecurrenceRule? _customRecurrence;
  String _recurrencePeriod = 'none';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      final t = widget.transaction!;
      _titleController.text = t.title;
      _amountController.text = t.amount.toString();
      _descriptionController.text = t.description ?? '';
      _selectedDate = t.transactionDate;
      _selectedTime =
          t.transactionTime ?? TimeOfDay.fromDateTime(t.transactionDate);
      _transactionType = t.type;
      _isRecurring = t.isRecurring;
      if (t.recurrenceRule != null) {
        try {
          _customRecurrence = RecurrenceRule.fromJson(t.recurrenceRule!);
        } catch (_) {
          _recurrencePeriod = t.recurrenceRule ?? 'none';
        }
      }
    } else {
      // Apply initial type if provided
      if (widget.initialType != null) {
        _transactionType = widget.initialType!;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: const Color(0xFFCDAF56),
              onPrimary: Colors.black,
              surface: const Color(0xFF2D3139),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() => _selectedTime = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Watch providers but don't modify state directly here
    final categoriesAsync = ref.watch(allTransactionCategoriesProvider);
    final accountsAsync = ref.watch(activeAccountsProvider);

    // Use ref.listen to safely update state when data arrives
    ref.listen<AsyncValue<List<Account>>>(activeAccountsProvider, (
      previous,
      next,
    ) {
      if (next.hasValue && _selectedAccount == null) {
        final accounts = next.value!;
        if (widget.transaction != null) {
          try {
            _selectedAccount = accounts.firstWhere(
              (a) => a.id == widget.transaction!.accountId,
            );
          } catch (e) {
            if (accounts.isNotEmpty) _selectedAccount = accounts.first;
          }
        } else if (accounts.isNotEmpty) {
          _selectedAccount = accounts.firstWhere(
            (a) => a.isDefault,
            orElse: () => accounts.first,
          );
        }

        if (widget.transaction != null &&
            _transactionType == 'transfer' &&
            _targetAccount == null) {
          try {
            _targetAccount = accounts.firstWhere(
              (a) => a.id == widget.transaction!.toAccountId,
            );
          } catch (e) {
            _targetAccount = null;
          }
        }
        setState(() {}); // Re-build once with initialized values
      }
    });

    ref.listen<AsyncValue<List<TransactionCategory>>>(
      allTransactionCategoriesProvider,
      (previous, next) {
        if (next.hasValue &&
            _selectedCategory == null &&
            _transactionType != 'income') {
          final categories = next.value!;
          if (widget.transaction != null) {
            try {
              _selectedCategory = categories.firstWhere(
                (c) => c.id == widget.transaction!.categoryId,
              );
            } catch (e) {
              final filtered = categories
                  .where((c) => c.type == _transactionType || c.type == 'both')
                  .toList();
              if (filtered.isNotEmpty) _selectedCategory = filtered.first;
            }
          } else if (widget.initialCategoryId != null) {
            try {
              _selectedCategory = categories.firstWhere(
                (c) => c.id == widget.initialCategoryId,
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
          setState(() {}); // Re-build once with initialized values
        }
      },
    );

    // Listen for income categories when type is income
    // Income categories now use the unified TransactionCategory system

    // Fallback manual checks for cases where listen doesn't trigger (data already cached)
    // But we wrap in a microtask to avoid building while building
    final needsAccountInit = _selectedAccount == null && accountsAsync.hasValue;
    final needsCategoryInit =
        _selectedCategory == null &&
        categoriesAsync.hasValue;

    if (needsAccountInit || needsCategoryInit) {
      Future.microtask(() {
        if (!mounted) return;
        bool changed = false;

        if (_selectedAccount == null && accountsAsync.hasValue) {
          final accounts = accountsAsync.value!;
          if (widget.transaction != null) {
            try {
              _selectedAccount = accounts.firstWhere(
                (a) => a.id == widget.transaction!.accountId,
              );
            } catch (e) {
              if (accounts.isNotEmpty) _selectedAccount = accounts.first;
            }
          } else if (accounts.isNotEmpty) {
            _selectedAccount = accounts.firstWhere(
              (a) => a.isDefault,
              orElse: () => accounts.first,
            );
          }
          changed = true;
        }

        // Auto-select transaction category for all types (unified system)
        if (_selectedCategory == null &&
            categoriesAsync.hasValue) {
          final categories = categoriesAsync.value!;
          if (widget.transaction != null) {
            try {
              _selectedCategory = categories.firstWhere(
                (c) => c.id == widget.transaction!.categoryId,
              );
            } catch (e) {
              final filtered = categories
                  .where((c) => c.type == _transactionType || c.type == 'both')
                  .toList();
              if (filtered.isNotEmpty) _selectedCategory = filtered.first;
            }
          } else if (widget.initialCategoryId != null) {
            try {
              _selectedCategory = categories.firstWhere(
                (c) => c.id == widget.initialCategoryId,
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
          widget.transaction == null ? 'Add Transaction' : 'Edit Transaction',
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
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFCDAF56).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                color: Color(0xFFCDAF56),
                size: 20,
              ),
            ),
            onPressed: () => _showTemplatePicker(context, isDark),
            tooltip: 'Use Template',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            const SizedBox(height: 16),
            // Amount Input (Modern & Large)
            _buildAmountInput(isDark),
            const SizedBox(height: 32),

            // Type Selector (Income, Expense, Transfer)
            _buildTypeSelector(isDark),
            const SizedBox(height: 32),

            // Details Card
            _buildDetailsCard(isDark, categoriesAsync, accountsAsync),
            const SizedBox(height: 24),

            // Date & Time Card
            _buildDateTimeCard(context, isDark),
            const SizedBox(height: 24),

            // Notes Section
            _buildNotesCard(isDark),
            const SizedBox(height: 32),

            // Save Button at the end
            _buildSaveButton(isDark),
            const SizedBox(height: 40),
          ],
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
          _buildSectionLabel('TRANSACTION DETAILS'),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _titleController,
            label: 'Title / Payee',
            hint: 'e.g., Grocery Store',
            icon: Icons.label_outline_rounded,
            isDark: isDark,
          ),
          const SizedBox(height: 20),
          // Use unified TransactionCategory for all types
          categoriesAsync.when(
            data: (categories) => _buildCategoryDropdown(categories, isDark),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: LinearProgressIndicator(),
            ),
            error: (_, __) => const Text('Error loading categories'),
          ),
          const SizedBox(height: 20),
          // Bill/Subscription link (only for expenses)
          if (_transactionType == 'expense')
            ref.watch(activeBillsProvider).when(
              data: (bills) => _buildBillSelector(bills, isDark),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          if (_transactionType == 'expense') const SizedBox(height: 20),
          accountsAsync.when(
            data: (accounts) => _buildAccountPickers(accounts, isDark),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: LinearProgressIndicator(),
            ),
            error: (_, __) => const Text('Error loading accounts'),
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimeCard(BuildContext context, bool isDark) {
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
          _buildSectionLabel('DATE & TIME'),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildDateTimeTile(
                  context,
                  label: 'Date',
                  value: DateFormat('MMM dd, yyyy').format(_selectedDate),
                  icon: Icons.calendar_today_rounded,
                  onTap: () => _selectDate(context),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDateTimeTile(
                  context,
                  label: 'Time',
                  value: _selectedTime.format(context),
                  icon: Icons.access_time_rounded,
                  onTap: () => _selectTime(context),
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
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
                : 'Repeat automatically',
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
                        RecurrenceRule.daily(startDate: _selectedDate),
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
        onPressed: _isSaving ? null : _saveTransaction,
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
                widget.transaction == null
                    ? 'SAVE TRANSACTION'
                    : 'UPDATE TRANSACTION',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 1,
                ),
              ),
      ),
    );
  }

  Widget _buildAmountInput(bool isDark) {
    final typeColor = _transactionType == 'expense'
        ? Colors.redAccent
        : (_transactionType == 'income'
              ? Colors.greenAccent
              : const Color(0xFFCDAF56));

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
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
            'ENTER AMOUNT',
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
              fontSize: 52,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF1E1E1E),
              letterSpacing: -2,
            ),
            decoration: InputDecoration(
              prefixText:
                  '${CurrencyUtils.getCurrencySymbol(_selectedAccount?.currency ?? FinanceSettingsService.fallbackCurrency)} ',
              prefixStyle: TextStyle(
                fontSize: 24,
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
            // Clear category selection if it doesn't match the new type
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

  Widget _buildCategoryDropdown(
    List<TransactionCategory> categories,
    bool isDark,
  ) {
    final filteredCategories = categories
        .where((c) => (c.type == _transactionType || c.type == 'both') && c.isActive)
        .toList();

    if (filteredCategories.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldLabel('CATEGORY', isDark),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.02)
                  : Colors.black.withOpacity(0.01),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.red.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No active ${_transactionType} categories found',
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 13,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TransactionCategoriesScreen(),
                    ),
                  ).then((_) {
                    ref.invalidate(allTransactionCategoriesProvider);
                  }),
                  child: const Text('Add'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (filteredCategories.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldLabel('CATEGORY', isDark),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.02)
                  : Colors.black.withOpacity(0.01),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.red.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No active ${_transactionType} categories found',
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 13,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TransactionCategoriesScreen(),
                    ),
                  ).then((_) {
                    ref.invalidate(allTransactionCategoriesProvider);
                  }),
                  child: const Text('Add'),
                ),
              ],
            ),
          ),
        ],
      );
    }

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

  // Income categories now use the unified _buildCategoryDropdown method

  Widget _buildBillSelector(List<Bill> bills, bool isDark) {
    if (bills.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('LINK TO BILL/SUBSCRIPTION (OPTIONAL)', isDark),
        const SizedBox(height: 10),
        DropdownButtonFormField<Bill>(
          value: _selectedBill,
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
          dropdownColor: isDark ? const Color(0xFF1A1D23) : Colors.white,
          decoration: InputDecoration(
            prefixIcon: const Icon(
              Icons.receipt_long_rounded,
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
          items: [
            DropdownMenuItem<Bill>(
              value: null,
              child: Text(
                'None (Regular expense)',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ),
            ...bills.map((bill) => DropdownMenuItem(
              value: bill,
              child: Row(
                children: [
                  Icon(
                    bill.type == 'subscription' 
                        ? Icons.subscriptions_rounded 
                        : Icons.receipt_rounded,
                    size: 16,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      bill.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${CurrencyUtils.getCurrencySymbol(bill.currency)}${bill.defaultAmount.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white24 : Colors.black26,
                    ),
                  ),
                ],
              ),
            )).toList(),
          ],
          onChanged: (val) {
            setState(() {
              _selectedBill = val;
              // Auto-fill from bill if selected
              if (val != null) {
                _titleController.text = '${val.name} Payment';
                _amountController.text = val.defaultAmount.toString();
                // Try to find matching category
                if (_selectedCategory?.id != val.categoryId) {
                  // Category will be auto-selected by the provider watch
                }
              }
            });
          },
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
                      Text(
                        '${CurrencyUtils.getCurrencySymbol(a.currency)}${a.balance.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white24 : Colors.black26,
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

  Widget _buildDateTimeTile(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label, isDark),
        const SizedBox(height: 10),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
            child: Row(
              children: [
                Icon(icon, size: 20, color: const Color(0xFFCDAF56)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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

  void _applyTemplate(TransactionTemplate template) {
    HapticFeedback.mediumImpact();
    setState(() {
      _titleController.text = template.transactionTitle;
      _amountController.text = template.amount > 0
          ? template.amount.toStringAsFixed(2)
          : '';
      _descriptionController.text = template.description ?? '';
      _transactionType = template.type;

      // Update Category
      if (template.categoryId != null) {
        final categories =
            ref.read(allTransactionCategoriesProvider).value ?? [];
        try {
          _selectedCategory = categories.firstWhere(
            (c) => c.id == template.categoryId,
          );
        } catch (_) {
          _selectedCategory = null;
        }
      }

      // Update Account
      if (template.accountId != null) {
        final accounts = ref.read(activeAccountsProvider).value ?? [];
        try {
          _selectedAccount = accounts.firstWhere(
            (a) => a.id == template.accountId,
          );
        } catch (_) {
          // Keep current if not found
        }
      }

      // Update Target Account for transfers
      if (_transactionType == 'transfer' && template.toAccountId != null) {
        final accounts = ref.read(activeAccountsProvider).value ?? [];
        try {
          _targetAccount = accounts.firstWhere(
            (a) => a.id == template.toAccountId,
          );
        } catch (_) {
          _targetAccount = null;
        }
      }

      // Update Recurrence
      _isRecurring = template.isRecurring;
      if (template.recurrenceRule != null) {
        try {
          _customRecurrence = RecurrenceRule.fromJson(template.recurrenceRule!);
        } catch (_) {
          _customRecurrence = null;
        }
      } else {
        _customRecurrence = null;
      }
    });
  }

  void _showTemplatePicker(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1A1D23) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final templatesAsync = ref.watch(allTransactionTemplatesProvider);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white12 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select Template',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                        letterSpacing: -0.5,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const TransactionTemplatesScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.settings_rounded, size: 18),
                      label: const Text('MANAGE'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFCDAF56),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: templatesAsync.when(
                  data: (templates) {
                    if (templates.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          children: [
                            Icon(
                              Icons.receipt_long_rounded,
                              size: 48,
                              color: isDark ? Colors.white10 : Colors.black12,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No templates found',
                              style: TextStyle(
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                      itemCount: templates.length,
                      itemBuilder: (context, index) {
                        final template = templates[index];
                        final typeColor = template.type == 'expense'
                            ? Colors.redAccent
                            : (template.type == 'income'
                                  ? Colors.greenAccent
                                  : const Color(0xFFCDAF56));

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
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
                          child: ListTile(
                            onTap: () {
                              _applyTemplate(template);
                              Navigator.pop(context);
                            },
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: typeColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                template.icon ?? Icons.receipt_long_rounded,
                                color: typeColor,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              template.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1E1E1E),
                              ),
                            ),
                            subtitle: Text(
                              '${template.transactionTitle} • ${template.amount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                            trailing: Icon(
                              Icons.chevron_right_rounded,
                              color: isDark ? Colors.white10 : Colors.black12,
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (e, _) => Center(child: Text('Error: $e')),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveTransaction() async {
    if (_isSaving) return;

    if (_amountController.text.isEmpty || _titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter title and amount')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Amount must be greater than zero')),
      );
      return;
    }

    if (_selectedAccount == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select an account')));
      return;
    }

    if (_transactionType == 'transfer' && _targetAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select target account for transfer'),
        ),
      );
      return;
    }

    if (_transactionType == 'expense') {
      final budgetCheck = await ref
          .read(budgetTrackerServiceProvider)
          .checkTransactionAgainstBudget(
            amount: amount,
            categoryId: _selectedCategory?.id,
            currency: _selectedAccount?.currency,
            accountId: _selectedAccount?.id,
          );
      final warnings = (budgetCheck['warnings'] as List?)?.cast<String>() ?? [];

      if (warnings.isNotEmpty && mounted) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Budget Alert'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: warnings
                  .map(
                    (warning) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('• $warning'),
                    ),
                  )
                  .toList(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Save Anyway'),
              ),
            ],
          ),
        );
        if (proceed != true) return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final transactionRepo = ref.read(transactionRepositoryProvider);
      final balanceService = ref.read(transactionBalanceServiceProvider);
      final settingsService = ref.read(financeSettingsServiceProvider);
      final defaultCurrency = await settingsService.getDefaultCurrency();

      // Store current version for balance correction if editing
      final oldTx = widget.transaction;

      final transactionDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      // Use income category ID for income, transaction category ID for others
      final categoryId = _selectedCategory?.id ?? 'other';

      final transaction = finance.Transaction(
        id: oldTx?.id,
        title: _titleController.text.trim(),
        amount: amount,
        type: _transactionType,
        categoryId: categoryId,
        accountId: _selectedAccount!.id,
        toAccountId: _transactionType == 'transfer' ? _targetAccount!.id : null,
        transactionDate: transactionDateTime,
        transactionTime: _selectedTime,
        description: _descriptionController.text.trim(),
        isRecurring: _isRecurring,
        recurrenceRule: _isRecurring
            ? (_customRecurrence?.toJson() ?? _recurrencePeriod)
            : null,
        recurringGroupId: _isRecurring
            ? (oldTx?.recurringGroupId ?? const Uuid().v4())
            : null,
        currency: _selectedAccount?.currency ?? defaultCurrency,
        billId: _selectedBill?.id, // Link to bill/subscription if selected
      );

      // 1. REVERSE OLD IMPACT (if editing an existing transaction)
      if (oldTx != null) {
        await balanceService.reverseTransactionImpact(oldTx);
      }

      // 2. APPLY NEW TRANSACTION IMPACT
      await balanceService.applyTransactionImpact(transaction);

      // 3. SAVE TRANSACTION RECORD
      if (oldTx == null) {
        await transactionRepo.createTransaction(transaction);
      } else {
        await transactionRepo.updateTransaction(transaction);
      }

      // 4. Process recurring immediately if it's a recurring transaction
      if (_isRecurring) {
        final spawnedCount = await ref
            .read(recurringTransactionServiceProvider)
            .processRecurringTransactions();
        if (spawnedCount > 0) {
          // Additional invalidations if multiple transactions were added
          ref.invalidate(allTransactionsProvider);
          ref.invalidate(activeAccountsProvider);
          ref.invalidate(totalBalanceProvider);
          ref.invalidate(monthlyStatisticsProvider);
        }
      }

      // Invalidate daily balance snapshots from the earliest impacted date
      final dailyBalanceService = ref.read(dailyBalanceServiceProvider);
      DateTime invalidateFrom = transaction.transactionDate;
      if (oldTx != null && oldTx.transactionDate.isBefore(invalidateFrom)) {
        invalidateFrom = oldTx.transactionDate;
      }
      await dailyBalanceService.invalidateFromDate(invalidateFrom);

      // Normalize date for provider invalidation
      final normalizedDate = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );
      ref.invalidate(allTransactionsProvider);
      ref.invalidate(transactionsForDateProvider(normalizedDate));
      ref.invalidate(activeAccountsProvider);
      ref.invalidate(totalBalanceProvider);
      ref.invalidate(dailyTotalBalanceProvider(normalizedDate));
      ref.invalidate(dailyTotalBalanceProvider);
      ref.invalidate(monthlyStatisticsProvider);

      // Update budget spending after transaction
      await ref.read(budgetTrackerServiceProvider).updateAllBudgetSpending();
      ref.invalidate(allBudgetsProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _transactionType == 'transfer'
                  ? 'Transfer completed!'
                  : 'Transaction saved!',
            ),
            backgroundColor: const Color(0xFFCDAF56),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving transaction: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
