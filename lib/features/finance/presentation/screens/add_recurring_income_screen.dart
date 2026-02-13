import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/bill_reminder.dart';
import '../../data/models/recurring_income.dart';
import '../../data/models/transaction_category.dart';
import '../../data/models/account.dart';
import '../../notifications/finance_notification_contract.dart';
import '../../notifications/finance_notification_scheduler.dart';
import '../providers/income_providers.dart';
import '../providers/finance_providers.dart';
import '../../../../core/theme/color_schemes.dart';
import '../../notifications/finance_notification_creator_context.dart';
import '../widgets/universal_reminder_section.dart';
import 'transaction_categories_screen.dart';

class AddRecurringIncomeScreen extends ConsumerStatefulWidget {
  final RecurringIncome? income;

  const AddRecurringIncomeScreen({super.key, this.income});

  @override
  ConsumerState<AddRecurringIncomeScreen> createState() =>
      _AddRecurringIncomeScreenState();
}

class _AddRecurringIncomeScreenState
    extends ConsumerState<AddRecurringIncomeScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _amountController;
  late TextEditingController _payerController;
  late TextEditingController _notesController;

  String? _selectedCategoryId;
  String? _selectedAccountId;
  String _selectedCurrency = 'USD';
  String _selectedFrequency = 'monthly';
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  int _dayOfMonth = 1;
  int _dayOfWeek = 1;
  bool _isActive = true;
  bool _autoCreateTransaction = false;
  bool _reminderEnabled = true;
  List<BillReminder> _reminders = [];
  bool _isGuaranteed = true;

  @override
  void initState() {
    super.initState();
    final income = widget.income;
    _titleController = TextEditingController(text: income?.title ?? '');
    _descriptionController = TextEditingController(text: income?.description ?? '');
    _amountController = TextEditingController(
      text: income?.amount.toString() ?? '',
    );
    _payerController = TextEditingController(text: income?.payerName ?? '');
    _notesController = TextEditingController(text: income?.notes ?? '');

    if (income != null) {
      _selectedCategoryId = income.categoryId;
      _selectedAccountId = income.accountId;
      _selectedCurrency = income.currency;
      _selectedFrequency = income.frequency;
      _startDate = income.startDate;
      _endDate = income.endDate;
      _dayOfMonth = income.dayOfMonth;
      _dayOfWeek = income.dayOfWeek;
      _isActive = income.isActive;
      _autoCreateTransaction = income.autoCreateTransaction;
      _reminderEnabled = income.reminderEnabled;
      _reminders = List<BillReminder>.from(income.reminders);
      _isGuaranteed = income.isGuaranteed;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    _payerController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(incomeTransactionCategoriesProvider);
    final accountsAsync = ref.watch(activeAccountsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1D1E33),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.income == null ? 'Add Recurring Income' : 'Edit Recurring Income',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text(
              'Save',
              style: TextStyle(
                color: Color(0xFF4CAF50),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildBasicInfoSection(),
            const SizedBox(height: 20),
            _buildAmountSection(accountsAsync),
            const SizedBox(height: 20),
            _buildCategorySection(categoriesAsync),
            const SizedBox(height: 20),
            _buildScheduleSection(),
            const SizedBox(height: 20),
            _buildOptionsSection(),
            const SizedBox(height: 20),
            _buildNotificationSection(),
            const SizedBox(height: 20),
            _buildAdditionalInfoSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return _buildSection(
      title: 'Basic Information',
      children: [
        _buildTextField(
          controller: _titleController,
          label: 'Title',
          hint: 'e.g., Monthly Salary',
          validator: (value) =>
              value?.isEmpty ?? true ? 'Title is required' : null,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _descriptionController,
          label: 'Description (optional)',
          hint: 'Brief description',
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildAmountSection(AsyncValue<List<Account>> accountsAsync) {
    return _buildSection(
      title: 'Amount & Account',
      children: [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _buildTextField(
                controller: _amountController,
                label: 'Amount',
                hint: '0.00',
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Amount is required';
                  if (double.tryParse(value!) == null) return 'Invalid amount';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDropdown<String>(
                value: _selectedCurrency,
                label: 'Currency',
                items: ['USD', 'EUR', 'GBP', 'ETB'],
                onChanged: (value) => setState(() => _selectedCurrency = value!),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        accountsAsync.when(
          data: (accounts) => _buildDropdown<String?>(
            value: _selectedAccountId,
            label: 'Target Account (optional)',
            items: <String?>[null, ...accounts.map((a) => a.id)],
            itemLabels: <String?, String>{
              null: 'No account',
              ...{for (var a in accounts) a.id: a.name}
            },
            onChanged: (value) => setState(() => _selectedAccountId = value),
          ),
          loading: () => const CircularProgressIndicator(),
          error: (_, __) => const SizedBox(),
        ),
      ],
    );
  }

  Widget _buildCategorySection(AsyncValue<List<TransactionCategory>> categoriesAsync) {
    return _buildSection(
      title: 'Category',
      children: [
        categoriesAsync.when(
          data: (categories) {
            if (categories.isEmpty) {
              return Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'No income categories found. Please add one first.',
                      style: TextStyle(
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
                      ref.invalidate(incomeTransactionCategoriesProvider);
                    }),
                    child: const Text(
                      'Add',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              );
            }

            if (_selectedCategoryId == null && categories.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                setState(() => _selectedCategoryId = categories.first.id);
              });
            }
            return _buildDropdown<String>(
              value: _selectedCategoryId,
              label: 'Category',
              items: categories.map((c) => c.id).toList(),
              itemLabels: {for (var c in categories) c.id: c.name},
              onChanged: (value) => setState(() => _selectedCategoryId = value),
            );
          },
          loading: () => const CircularProgressIndicator(),
          error: (_, __) => const Text('Error loading categories'),
        ),
      ],
    );
  }

  Widget _buildScheduleSection() {
    return _buildSection(
      title: 'Schedule',
      children: [
        _buildDropdown<String>(
          value: _selectedFrequency,
          label: 'Frequency',
          items: ['daily', 'weekly', 'biweekly', 'monthly', 'quarterly', 'yearly'],
          itemLabels: {
            'daily': 'Daily',
            'weekly': 'Weekly',
            'biweekly': 'Bi-weekly',
            'monthly': 'Monthly',
            'quarterly': 'Quarterly',
            'yearly': 'Yearly',
          },
          onChanged: (value) => setState(() => _selectedFrequency = value!),
        ),
        const SizedBox(height: 12),
        if (_selectedFrequency == 'monthly' || _selectedFrequency == 'quarterly')
          _buildDropdown<int>(
            value: _dayOfMonth,
            label: 'Day of Month',
            items: [-1, ...List.generate(28, (i) => i + 1)],
            itemLabels: {
              -1: 'Last day',
              ...{for (var i = 1; i <= 28; i++) i: '$i'}
            },
            onChanged: (value) => setState(() => _dayOfMonth = value!),
          ),
        if (_selectedFrequency == 'weekly' || _selectedFrequency == 'biweekly')
          _buildDropdown<int>(
            value: _dayOfWeek,
            label: 'Day of Week',
            items: [1, 2, 3, 4, 5, 6, 7],
            itemLabels: {
              1: 'Monday',
              2: 'Tuesday',
              3: 'Wednesday',
              4: 'Thursday',
              5: 'Friday',
              6: 'Saturday',
              7: 'Sunday',
            },
            onChanged: (value) => setState(() => _dayOfWeek = value!),
          ),
        const SizedBox(height: 12),
        _buildDateField(
          label: 'Start Date',
          date: _startDate,
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _startDate,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (date != null) setState(() => _startDate = date);
          },
        ),
        const SizedBox(height: 12),
        _buildDateField(
          label: 'End Date (optional)',
          date: _endDate,
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _endDate ?? _startDate.add(const Duration(days: 365)),
              firstDate: _startDate,
              lastDate: DateTime(2100),
            );
            setState(() => _endDate = date);
          },
          onClear: _endDate != null
              ? () => setState(() => _endDate = null)
              : null,
        ),
      ],
    );
  }

  Widget _buildOptionsSection() {
    return _buildSection(
      title: 'Options',
      children: [
        _buildSwitch(
          title: 'Active',
          subtitle: 'This income source is currently active',
          value: _isActive,
          onChanged: (value) => setState(() => _isActive = value),
        ),
        _buildSwitch(
          title: 'Auto-create Transactions',
          subtitle: 'Automatically create income transactions on due date',
          value: _autoCreateTransaction,
          onChanged: (value) => setState(() => _autoCreateTransaction = value),
        ),
        _buildSwitch(
          title: 'Guaranteed Income',
          subtitle: 'This income is guaranteed (e.g., salary) vs variable (e.g., bonus)',
          value: _isGuaranteed,
          onChanged: (value) => setState(() => _isGuaranteed = value),
        ),
      ],
    );
  }

  Widget _buildNotificationSection() {
    if (widget.income != null) {
      return _buildSection(
        title: 'Notifications',
        children: [
          UniversalReminderSection(
            creatorContext: FinanceNotificationCreatorContext.forRecurringIncome(
              incomeId: widget.income!.id,
              incomeName: widget.income!.title,
            ),
            isDark: true,
          ),
        ],
      );
    }
    return _buildSection(
      title: 'Notifications',
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.notifications_rounded,
                  size: 20, color: AppColorSchemes.primaryGold),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Add reminders after saving the income',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAdditionalInfoSection() {
    return _buildSection(
      title: 'Additional Information',
      children: [
        _buildTextField(
          controller: _payerController,
          label: 'Payer (optional)',
          hint: 'Who pays this income',
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _notesController,
          label: 'Notes (optional)',
          hint: 'Additional notes',
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF4CAF50),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: Colors.grey[400]),
        hintStyle: TextStyle(color: Colors.grey[600]),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey[700]!),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFF4CAF50)),
          borderRadius: BorderRadius.circular(12),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.red),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.red),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required String label,
    required List<T> items,
    Map<T, String>? itemLabels,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      style: const TextStyle(color: Colors.white),
      dropdownColor: const Color(0xFF2A2D47),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[400]),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey[700]!),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFF4CAF50)),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      items: items.map((item) {
        return DropdownMenuItem<T>(
          value: item,
          child: Text(
            itemLabels?[item] ?? item.toString(),
            style: const TextStyle(color: Colors.white),
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[700]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  date != null
                      ? '${date.day}/${date.month}/${date.year}'
                      : 'Not set',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
            Row(
              children: [
                if (onClear != null)
                  IconButton(
                    icon: const Icon(Icons.clear_rounded, color: Colors.red),
                    onPressed: onClear,
                  ),
                const Icon(Icons.calendar_today_rounded, color: Color(0xFF4CAF50)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required void Function(bool) onChanged,
  }) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.grey[500], fontSize: 12),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: const Color(0xFF4CAF50),
      contentPadding: EdgeInsets.zero,
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a category'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final income = (widget.income ?? RecurringIncome(
      title: '',
      amount: 0,
      currency: _selectedCurrency,
      categoryId: _selectedCategoryId!,
      startDate: _startDate,
    )).copyWith(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      amount: double.parse(_amountController.text),
      currency: _selectedCurrency,
      categoryId: _selectedCategoryId,
      accountId: _selectedAccountId,
      startDate: _startDate,
      endDate: _endDate,
      frequency: _selectedFrequency,
      dayOfMonth: _dayOfMonth,
      dayOfWeek: _dayOfWeek,
      isActive: _isActive,
      autoCreateTransaction: _autoCreateTransaction,
      reminderEnabled: _reminderEnabled,
      remindersJson: BillReminder.encodeList(_reminders),
      payerName: _payerController.text.trim().isEmpty
          ? null
          : _payerController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      isGuaranteed: _isGuaranteed,
    );

    final repo = ref.read(recurringIncomeRepositoryProvider);
    await repo.save(income);
    ref.invalidate(recurringIncomesProvider);

    try {
      await FinanceNotificationScheduler().syncRecurringIncome(income);
    } catch (e) {
      debugPrint('Recurring income notification sync error: $e');
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.income == null
                ? 'Recurring income added'
                : 'Recurring income updated',
          ),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
    }
  }
}
