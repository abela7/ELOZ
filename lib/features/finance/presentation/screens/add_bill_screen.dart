import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/color_schemes.dart';
import '../../../../core/theme/dark_gradient.dart';
import '../../data/models/bill.dart';
import '../../data/models/bill_reminder.dart';
import '../../data/models/transaction_category.dart';
import '../../data/services/finance_settings_service.dart';
import '../../notifications/finance_notification_scheduler.dart';
import '../../utils/currency_utils.dart';
import '../providers/finance_providers.dart';
import '../../notifications/finance_notification_creator_context.dart';
import '../widgets/universal_reminder_section.dart';
import '../../../../core/models/recurrence_rule.dart';
import '../../../../core/widgets/recurrence_picker_sheet.dart';

class AddBillScreen extends ConsumerStatefulWidget {
  final Bill? bill;

  const AddBillScreen({super.key, this.bill});

  @override
  ConsumerState<AddBillScreen> createState() => _AddBillScreenState();
}

class _AddBillScreenState extends ConsumerState<AddBillScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _providerController = TextEditingController();
  final _notesController = TextEditingController();

  String _type = 'bill'; // 'bill' or 'subscription'
  String _amountType = 'fixed'; // 'fixed' or 'variable'
  String _frequency = 'monthly';
  String _currency = FinanceSettingsService
      .fallbackCurrency; // Will be initialized from settings
  int? _dueDay;
  DateTime? _nextDueDate;
  DateTime _startDate = DateTime.now();
  String _endCondition = 'indefinite';
  final _endOccurrencesController = TextEditingController();
  final _endAmountController = TextEditingController();
  DateTime? _endDate;
  TransactionCategory? _selectedCategory;
  RecurrenceRule? _customRecurrence;
  bool _reminderEnabled = true;
  List<BillReminder> _reminders = [];
  bool _isSaving = false;
  bool _currencyLoaded = false;

  @override
  void initState() {
    super.initState();
    if (widget.bill != null) {
      _populateFromBill(widget.bill!);
      _currencyLoaded = true;
    } else {
      _loadDefaultCurrency();
      // New bill: default due day to start date's day for monthly
      if (_frequency == 'monthly' && _dueDay == null) {
        _dueDay = _startDate.day;
      }
      _applySuggestedNextDueDate();
    }
  }

  Future<void> _loadDefaultCurrency() async {
    final settingsService = FinanceSettingsService();
    final defaultCurrency = await settingsService.getDefaultCurrency();
    if (mounted) {
      setState(() {
        _currency = defaultCurrency;
        _currencyLoaded = true;
      });
    }
  }

  /// Date-only normalization to avoid time-of-day math drift.
  DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  /// Computes the first due date from start date, due day, and frequency.
  ///
  /// Rules:
  /// - Date-only comparison (no hour/minute drift)
  /// - Uses max(today, startDate) as the reference
  /// - Includes "today" when it matches the schedule
  DateTime? _computeSuggestedNextDueDate() {
    final dueDay = _dueDay ?? _startDate.day;
    final today = _dateOnly(DateTime.now());
    final start = _dateOnly(_startDate);
    final ref = start.isAfter(today) ? start : today;

    switch (_frequency) {
      case 'weekly':
        final targetWeekday = start.weekday;
        final offset = (targetWeekday - ref.weekday + 7) % 7;
        return ref.add(Duration(days: offset));

      case 'monthly':
        int year = ref.year;
        int month = ref.month;
        int day = dueDay.clamp(1, DateTime(year, month + 1, 0).day);
        var candidate = DateTime(year, month, day);

        if (candidate.isBefore(ref)) {
          month++;
          if (month > 12) {
            month = 1;
            year++;
          }
          day = dueDay.clamp(1, DateTime(year, month + 1, 0).day);
          candidate = DateTime(year, month, day);
        }
        return candidate;

      case 'yearly':
        final targetMonth = start.month;
        int year = ref.year;
        int day = dueDay.clamp(1, DateTime(year, targetMonth + 1, 0).day);
        var candidate = DateTime(year, targetMonth, day);

        if (candidate.isBefore(ref)) {
          year++;
          day = dueDay.clamp(1, DateTime(year, targetMonth + 1, 0).day);
          candidate = DateTime(year, targetMonth, day);
        }
        return candidate;

      case 'custom':
        if (_customRecurrence != null) {
          final rule = _withStartDate(_customRecurrence!, start);
          if (rule.isDueOn(ref)) {
            return ref;
          }
          return rule.getNextOccurrence(
                ref.subtract(const Duration(days: 1)),
              ) ??
              ref;
        }
        return _nextDueDate != null ? _dateOnly(_nextDueDate!) : ref;

      default:
        return ref;
    }
  }

  void _applySuggestedNextDueDate() {
    final suggested = _computeSuggestedNextDueDate();
    if (suggested != null) _nextDueDate = suggested;
  }

  void _populateFromBill(Bill bill) {
    _nameController.text = bill.name;
    _amountController.text = bill.defaultAmount > 0
        ? bill.defaultAmount.toString()
        : '';
    _providerController.text = bill.providerName ?? '';
    _notesController.text = bill.notes ?? '';
    _type = bill.type;
    _amountType = bill.amountType;
    _frequency = bill.frequency;
    _currency = bill.currency;
    _dueDay = bill.dueDay;
    _nextDueDate = bill.nextDueDate;
    _startDate = bill.startDate;
    _endCondition = bill.endCondition;
    _endDate = bill.endDate;
    _endOccurrencesController.text = bill.endOccurrences != null
        ? bill.endOccurrences.toString()
        : '';
    _endAmountController.text = bill.endAmount != null
        ? bill.endAmount.toString()
        : '';
    _reminderEnabled = bill.reminderEnabled;
    _reminders = List<BillReminder>.from(bill.reminders);
    if (bill.recurrenceRule != null) {
      _customRecurrence = bill.recurrence;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _providerController.dispose();
    _notesController.dispose();
    _endOccurrencesController.dispose();
    _endAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categoriesAsync = ref.watch(expenseTransactionCategoriesProvider);
    final isEditing = widget.bill != null;

    final content = _buildContent(context, isDark, categoriesAsync, isEditing);

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
    AsyncValue<List<TransactionCategory>> categoriesAsync,
    bool isEditing,
  ) {
    return Form(
      key: _formKey,
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(isDark, isEditing),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Type selector (Bill vs Subscription)
                _buildTypeSelector(isDark),
                const SizedBox(height: 24),

                // Name field
                _buildTextField(
                  controller: _nameController,
                  label: 'Name',
                  hint: _type == 'subscription'
                      ? 'e.g., Netflix, Spotify'
                      : 'e.g., Electricity, Water',
                  icon: Icons.label_rounded,
                  isDark: isDark,
                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 18),

                // Provider field
                _buildTextField(
                  controller: _providerController,
                  label: 'Provider / Company',
                  hint: 'e.g., Netflix Inc, City Water',
                  icon: Icons.business_rounded,
                  isDark: isDark,
                ),
                const SizedBox(height: 18),

                // Category
                categoriesAsync.when(
                  data: (categories) {
                    if (_selectedCategory == null && categories.isNotEmpty) {
                      if (widget.bill != null) {
                        _selectedCategory = categories.firstWhere(
                          (c) => c.id == widget.bill!.categoryId,
                          orElse: () => categories.first,
                        );
                      } else {
                        _selectedCategory = categories.first;
                      }
                    }
                    return _buildCategorySelector(categories, isDark);
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Error: $e'),
                ),
                const SizedBox(height: 24),

                _buildSectionLabel('AMOUNT', isDark),
                const SizedBox(height: 14),

                // Amount type (Fixed vs Variable)
                _buildAmountTypeSelector(isDark),
                const SizedBox(height: 14),

                // Amount field
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildTextField(
                        controller: _amountController,
                        label: _amountType == 'fixed'
                            ? 'Amount'
                            : 'Estimated Amount',
                        hint: '0.00',
                        icon: Icons.attach_money_rounded,
                        isDark: isDark,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (v) {
                          if (_amountType == 'fixed' && (v?.isEmpty ?? true)) {
                            return 'Required for fixed amount';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _buildCurrencySelector(isDark)),
                  ],
                ),
                const SizedBox(height: 24),

                _buildSectionLabel('PAYMENT SCHEDULE', isDark),
                const SizedBox(height: 14),

                // Frequency selector
                _buildFrequencySelector(isDark),
                const SizedBox(height: 14),

                // Start date
                _buildStartDatePicker(isDark),
                const SizedBox(height: 14),

                // Due day (for monthly)
                if (_frequency == 'monthly') _buildDueDaySelector(isDark),
                if (_frequency == 'monthly') const SizedBox(height: 14),

                // Custom recurrence
                if (_frequency == 'custom') _buildCustomRecurrence(isDark),
                if (_frequency == 'custom') const SizedBox(height: 14),

                // End condition
                _buildEndConditionSection(isDark),
                const SizedBox(height: 14),

                // Next due date
                _buildNextDueDatePicker(isDark),
                const SizedBox(height: 24),

                _buildSectionLabel('REMINDERS', isDark),
                const SizedBox(height: 14),

                _buildReminderSettings(isDark),
                const SizedBox(height: 20),

                // Notes
                _buildTextField(
                  controller: _notesController,
                  label: 'Notes',
                  hint: 'Any additional notes...',
                  icon: Icons.notes_rounded,
                  isDark: isDark,
                  maxLines: 3,
                ),
                const SizedBox(height: 28),

                // Save button integrated into the scrollable list
                _buildSaveButtonIntegrated(isDark),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButtonIntegrated(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFCDAF56).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _isSaving ? null : _saveBill,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFCDAF56),
            foregroundColor: Colors.black87,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            disabledBackgroundColor: const Color(0xFFCDAF56).withOpacity(0.5),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.black87,
                  ),
                )
              : Text(
                  widget.bill == null
                      ? 'Add ${_type == 'subscription' ? 'Subscription' : 'Bill'}'
                      : 'Save Changes',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: 0.3,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(bool isDark, bool isEditing) {
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
        isEditing
            ? 'Edit ${_type == 'subscription' ? 'Subscription' : 'Bill'}'
            : 'Add Bill / Subscription',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : const Color(0xFF1E1E1E),
        ),
      ),
      actions: [
        if (isEditing)
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.redAccent,
                size: 22,
              ),
              onPressed: _confirmDelete,
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

  Widget _buildTypeSelector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TYPE',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white38 : Colors.black38,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.03),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              _buildTypeChip('bill', 'Bill', Icons.receipt_rounded, isDark),
              const SizedBox(width: 6),
              _buildTypeChip(
                'subscription',
                'Subscription',
                Icons.subscriptions_rounded,
                isDark,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTypeChip(String type, String label, IconData icon, bool isDark) {
    final isSelected = _type == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _type = type);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFCDAF56) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? Colors.black87
                    : (isDark ? Colors.white38 : Colors.black38),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? Colors.black87
                      : (isDark ? Colors.white54 : Colors.black54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmountTypeSelector(bool isDark) {
    return Row(
      children: [
        _buildAmountTypeChip(
          'fixed',
          'Fixed',
          'Same amount every time',
          isDark,
        ),
        const SizedBox(width: 12),
        _buildAmountTypeChip('variable', 'Variable', 'Amount changes', isDark),
      ],
    );
  }

  Widget _buildAmountTypeChip(
    String type,
    String label,
    String desc,
    bool isDark,
  ) {
    final isSelected = _amountType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _amountType = type);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFCDAF56).withOpacity(0.1)
                : (isDark
                      ? Colors.white.withOpacity(0.02)
                      : Colors.black.withOpacity(0.01)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFCDAF56)
                  : (isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.05)),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isSelected
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    size: 18,
                    color: isSelected
                        ? const Color(0xFFCDAF56)
                        : (isDark ? Colors.white24 : Colors.black26),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySelector(
    List<TransactionCategory> categories,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Category', isDark),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: categories.map((category) {
            final isSelected = _selectedCategory?.id == category.id;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedCategory = category);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? category.color.withOpacity(0.2)
                      : (isDark
                            ? Colors.white.withOpacity(0.03)
                            : Colors.black.withOpacity(0.02)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? category.color
                        : (isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.black.withOpacity(0.05)),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      category.icon ?? Icons.category_rounded,
                      size: 16,
                      color: category.color,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      category.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCurrencySelector(bool isDark) {
    final currencies = FinanceSettingsService.supportedCurrencies;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Currency', isDark),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
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
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _currencyLoaded ? _currency : null,
              isExpanded: true,
              dropdownColor: isDark ? const Color(0xFF1A1D23) : Colors.white,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
              items: currencies
                  .map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Text('${CurrencyUtils.getCurrencySymbol(c)} $c'),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _currency = v!),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFrequencySelector(bool isDark) {
    final frequencies = [
      {
        'id': 'weekly',
        'label': 'Weekly',
        'icon': Icons.calendar_view_week_rounded,
      },
      {
        'id': 'monthly',
        'label': 'Monthly',
        'icon': Icons.calendar_month_rounded,
      },
      {'id': 'yearly', 'label': 'Yearly', 'icon': Icons.calendar_today_rounded},
      {'id': 'custom', 'label': 'Custom', 'icon': Icons.tune_rounded},
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: frequencies.map((freq) {
        final isSelected = _frequency == freq['id'];
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _frequency = freq['id'] as String;
              _applySuggestedNextDueDate();
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFCDAF56)
                  : (isDark
                        ? Colors.white.withOpacity(0.03)
                        : Colors.black.withOpacity(0.02)),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFCDAF56)
                    : (isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.05)),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  freq['icon'] as IconData,
                  size: 16,
                  color: isSelected
                      ? Colors.black87
                      : (isDark ? Colors.white38 : Colors.black38),
                ),
                const SizedBox(width: 6),
                Text(
                  freq['label'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? Colors.black87
                        : (isDark ? Colors.white54 : Colors.black54),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDueDaySelector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Due Day of Month', isDark),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
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
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              value: _dueDay,
              isExpanded: true,
              hint: Text(
                'Select day',
                style: TextStyle(
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
              dropdownColor: isDark ? const Color(0xFF1A1D23) : Colors.white,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Not set'),
                ),
                ...List.generate(31, (i) => i + 1).map(
                  (d) => DropdownMenuItem(
                    value: d,
                    child: Text('${d}${_getDaySuffix(d)}'),
                  ),
                ),
              ],
              onChanged: (v) => setState(() {
                _dueDay = v;
                _applySuggestedNextDueDate();
              }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomRecurrence(bool isDark) {
    return InkWell(
      onTap: () => _showRecurrencePicker(isDark),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
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
            const Icon(Icons.tune_rounded, color: Color(0xFFCDAF56)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _customRecurrence?.getDescription() ?? 'Set custom schedule',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartDatePicker(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Start Date', isDark),
        const SizedBox(height: 10),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _startDate,
              firstDate: DateTime(2015),
              lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
            );
            if (picked != null) {
              setState(() {
                _startDate = picked;
                if (_endDate != null && _endDate!.isBefore(_startDate)) {
                  _endDate = _startDate;
                }
                _applySuggestedNextDueDate();
              });
            }
          },
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
                const Icon(
                  Icons.play_circle_outline_rounded,
                  size: 20,
                  color: Color(0xFFCDAF56),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${_startDate.day}/${_startDate.month}/${_startDate.year}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEndConditionSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('End Condition', isDark),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildEndConditionChip(
              label: 'Indefinite',
              value: 'indefinite',
              isDark: isDark,
            ),
            _buildEndConditionChip(
              label: 'After X times',
              value: 'after_occurrences',
              isDark: isDark,
            ),
            _buildEndConditionChip(
              label: 'After X amount',
              value: 'after_amount',
              isDark: isDark,
            ),
            _buildEndConditionChip(
              label: 'On date',
              value: 'on_date',
              isDark: isDark,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_endCondition == 'after_occurrences')
          _buildTextField(
            controller: _endOccurrencesController,
            label: 'Number of payments',
            hint: 'e.g., 12',
            icon: Icons.repeat_rounded,
            isDark: isDark,
            keyboardType: TextInputType.number,
          ),
        if (_endCondition == 'after_amount')
          _buildTextField(
            controller: _endAmountController,
            label: 'Total amount limit',
            hint: '0.00',
            icon: Icons.payments_rounded,
            isDark: isDark,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        if (_endCondition == 'on_date') _buildEndDatePicker(isDark),
      ],
    );
  }

  Widget _buildEndConditionChip({
    required String label,
    required String value,
    required bool isDark,
  }) {
    final isSelected = _endCondition == value;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _endCondition = value;
          _applySuggestedNextDueDate();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFCDAF56).withOpacity(0.15)
              : (isDark
                    ? Colors.white.withOpacity(0.02)
                    : Colors.black.withOpacity(0.01)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFCDAF56)
                : (isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.05)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSelected
                ? const Color(0xFFCDAF56)
                : (isDark ? Colors.white54 : Colors.black54),
          ),
        ),
      ),
    );
  }

  Widget _buildEndDatePicker(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('End Date', isDark),
        const SizedBox(height: 10),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _endDate ?? _startDate,
              firstDate: _startDate,
              lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
            );
            if (picked != null) {
              setState(() => _endDate = picked);
            }
          },
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
                const Icon(
                  Icons.flag_circle_rounded,
                  size: 20,
                  color: Color(0xFFCDAF56),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _endDate != null
                        ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                        : 'Select date',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNextDueDatePicker(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Next Due Date', isDark),
        const SizedBox(height: 10),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _nextDueDate ?? DateTime.now(),
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
            );
            if (picked != null) {
              setState(() => _nextDueDate = picked);
            }
          },
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
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 20,
                  color: Color(0xFFCDAF56),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _nextDueDate != null
                        ? '${_nextDueDate!.day}/${_nextDueDate!.month}/${_nextDueDate!.year}'
                        : 'Select date',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReminderSettings(bool isDark) {
    if (widget.bill != null) {
      return UniversalReminderSection(
        creatorContext: FinanceNotificationCreatorContext.forBill(
          billId: widget.bill!.id,
          billName: widget.bill!.name,
        ),
        isDark: isDark,
        title: 'Payment Reminders',
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D23) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.notifications_rounded, size: 20, color: AppColorSchemes.primaryGold),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Add reminders after saving the bill',
              style: TextStyle(
                fontSize: 14,
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label, isDark),
        const SizedBox(height: 10),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white24 : Colors.black26,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Icon(icon, color: const Color(0xFFCDAF56), size: 20),
            filled: true,
            fillColor: isDark
                ? Colors.white.withOpacity(0.03)
                : Colors.black.withOpacity(0.02),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.08),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.08),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFCDAF56), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.redAccent, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String label, bool isDark) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: isDark ? Colors.white38 : Colors.black38,
        letterSpacing: 1,
      ),
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

  void _showRecurrencePicker(bool isDark) async {
    final result = await showModalBottomSheet<RecurrenceRule>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => RecurrencePickerSheet(
          initialRule: _customRecurrence,
          isDark: isDark,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _customRecurrence = result;
        _applySuggestedNextDueDate();
      });
    }
  }

  RecurrenceRule _withStartDate(RecurrenceRule rule, DateTime startDate) {
    return RecurrenceRule(
      type: rule.type,
      interval: rule.interval,
      daysOfWeek: rule.daysOfWeek,
      daysOfMonth: rule.daysOfMonth,
      dayOfYear: rule.dayOfYear,
      startDate: startDate,
      endCondition: rule.endCondition,
      endDate: rule.endDate,
      unit: rule.unit,
      occurrences: rule.occurrences,
      skipWeekends: rule.skipWeekends,
      frequency: rule.frequency,
    );
  }

  Future<void> _saveBill() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a category')));
      return;
    }

    int? endOccurrences;
    double? endAmount;
    if (_endCondition == 'after_occurrences') {
      endOccurrences = int.tryParse(_endOccurrencesController.text.trim());
      if (endOccurrences == null || endOccurrences <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid number of payments')),
        );
        return;
      }
    }
    if (_endCondition == 'after_amount') {
      endAmount = double.tryParse(_endAmountController.text.trim());
      if (endAmount == null || endAmount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid total amount')),
        );
        return;
      }
    }
    if (_endCondition == 'on_date') {
      if (_endDate == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Select an end date')));
        return;
      }
      if (_endDate!.isBefore(_startDate)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('End date must be after start date')),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final billRepo = ref.read(billRepositoryProvider);
      final amount = double.tryParse(_amountController.text) ?? 0.0;

      final Bill bill;
      if (widget.bill != null) {
        bill = widget.bill!.copyWith(
          name: _nameController.text.trim(),
          providerName: _providerController.text.trim().isEmpty
              ? null
              : _providerController.text.trim(),
          categoryId: _selectedCategory!.id,
          type: _type,
          amountType: _amountType,
          defaultAmount: amount,
          currency: _currency,
          frequency: _frequency,
          dueDay: _dueDay,
          nextDueDate: _nextDueDate,
          reminderEnabled: _reminderEnabled,
          remindersJson: BillReminder.encodeList(_reminders),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          startDate: _startDate,
          endCondition: _endCondition,
          endOccurrences: endOccurrences,
          endAmount: endAmount,
          endDate: _endDate,
          recurrenceRule: _frequency == 'custom' && _customRecurrence != null
              ? _withStartDate(_customRecurrence!, _startDate).toJson()
              : widget.bill!.recurrenceRule,
        );
      } else {
        bill = Bill(
          name: _nameController.text.trim(),
          providerName: _providerController.text.trim().isEmpty
              ? null
              : _providerController.text.trim(),
          categoryId: _selectedCategory!.id,
          type: _type,
          amountType: _amountType,
          defaultAmount: amount,
          currency: _currency,
          frequency: _frequency,
          dueDay: _dueDay,
          nextDueDate: _nextDueDate,
          reminderEnabled: _reminderEnabled,
          remindersJson: BillReminder.encodeList(_reminders),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          startDate: _startDate,
          endCondition: _endCondition,
          endOccurrences: endOccurrences,
          endAmount: endAmount,
          endDate: _endDate,
          isActive: true,
        );

        if (_frequency == 'custom' && _customRecurrence != null) {
          bill.recurrence = _withStartDate(_customRecurrence!, _startDate);
        }
      }

      if (widget.bill == null) {
        await billRepo.createBill(bill);
      } else {
        await billRepo.updateBill(bill);
      }

      // Sync with Notification Hub – do not block save if sync fails.
      String? syncError;
      try {
        final scheduler = FinanceNotificationScheduler();
        await scheduler.syncBill(bill);
      } catch (e) {
        syncError = '$e';
      }

      ref.invalidate(allBillsProvider);
      ref.invalidate(activeBillsProvider);
      ref.invalidate(billSummaryProvider);
      ref.invalidate(upcomingBillsProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.bill == null
                  ? '${_type == 'subscription' ? 'Subscription' : 'Bill'} added!'
                  : 'Changes saved!',
            ),
            backgroundColor: const Color(0xFFCDAF56),
          ),
        );
        if (syncError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Saved successfully, but reminder sync failed. '
                'Open bill details and resave reminders.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('AddBillScreen._saveBill error: $e');
      debugPrint('$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Bill?'),
        content: Text(
          'Are you sure you want to delete "${widget.bill!.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                // Keep Notification Hub clean when a bill/subscription is deleted.
                await FinanceNotificationScheduler().cancelBillNotifications(
                  widget.bill!.id,
                );
              } catch (_) {}
              await ref
                  .read(billRepositoryProvider)
                  .deleteBill(widget.bill!.id);
              ref.invalidate(allBillsProvider);
              ref.invalidate(activeBillsProvider);
              ref.invalidate(billSummaryProvider);
              if (mounted) Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
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
