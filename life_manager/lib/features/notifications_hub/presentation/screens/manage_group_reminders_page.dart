import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../finance/data/models/bill.dart';
import '../../../finance/data/models/debt.dart';
import '../../../finance/data/models/recurring_income.dart';
import '../../../finance/data/repositories/bill_repository.dart';
import '../../../finance/data/repositories/debt_repository.dart';
import '../../../finance/data/repositories/recurring_income_repository.dart';
import '../../../finance/notifications/finance_notification_contract.dart';
import '../../../finance/notifications/finance_notification_creator_context.dart';
import '../../../finance/presentation/widgets/universal_reminder_section.dart';
import '../../../../core/theme/color_schemes.dart';

/// Full-screen page to manage ALL reminders for a bill or debt as one group.
/// Edits apply to the source entity and reschedule all its notifications.
class ManageGroupRemindersPage extends StatefulWidget {
  final String targetEntityId;
  final String section;
  final String entityName;

  const ManageGroupRemindersPage({
    super.key,
    required this.targetEntityId,
    required this.section,
    required this.entityName,
  });

  @override
  State<ManageGroupRemindersPage> createState() =>
      _ManageGroupRemindersPageState();
}

class _ManageGroupRemindersPageState extends State<ManageGroupRemindersPage> {
  bool _loading = true;
  Bill? _bill;
  Debt? _debt;
  RecurringIncome? _income;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    if (_isBillSection) {
      final bill = await BillRepository().getBillById(widget.targetEntityId);
      if (mounted) {
        setState(() {
          _bill = bill;
          _loading = false;
          _error = bill == null ? 'Bill not found' : null;
        });
      }
    } else if (_isRecurringIncomeSection) {
      final repo = RecurringIncomeRepository();
      try {
        await repo.init();
      } catch (e) {
        debugPrint('RecurringIncomeRepository init error: $e');
      }
      final income = repo.getById(widget.targetEntityId);
      if (mounted) {
        setState(() {
          _income = income;
          _loading = false;
          _error = income == null ? 'Recurring income not found' : null;
        });
      }
    } else {
      final debt = await DebtRepository().getDebtById(widget.targetEntityId);
      if (mounted) {
        setState(() {
          _debt = debt;
          _loading = false;
          _error = debt == null ? 'Debt not found' : null;
        });
      }
    }
  }

  bool get _isBillSection =>
      widget.section == FinanceNotificationContract.sectionBills;

  bool get _isRecurringIncomeSection =>
      widget.section == FinanceNotificationContract.sectionRecurringIncome;

  void _onRemindersChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Manage reminders'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: theme.colorScheme.onSurface,
        actions: [
          if (!_loading && _error == null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () {
                HapticFeedback.mediumImpact();
                _load();
              },
            ),
        ],
      ),
      body: _buildBody(isDark, theme),
    );
  }

  Widget _buildBody(bool isDark, ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Go back'),
              ),
            ],
          ),
        ),
      );
    }

    if (_bill != null) {
      return _ReminderEditorContent(
        entityName: widget.entityName,
        sectionLabel: _sectionLabel(widget.section),
        isDark: isDark,
        child: UniversalReminderSection(
          creatorContext: FinanceNotificationCreatorContext.forBill(
            billId: _bill!.id,
            billName: _bill!.name,
          ),
          isDark: isDark,
          onRemindersChanged: _onRemindersChanged,
        ),
      );
    }

    if (_debt != null) {
      return _ReminderEditorContent(
        entityName: widget.entityName,
        sectionLabel: _sectionLabel(widget.section),
        isDark: isDark,
        child: UniversalReminderSection(
          creatorContext: FinanceNotificationCreatorContext.forDebt(
            debtId: _debt!.id,
            debtorName: _debt!.name,
          ),
          isDark: isDark,
          onRemindersChanged: _onRemindersChanged,
        ),
      );
    }

    if (_income != null) {
      return _ReminderEditorContent(
        entityName: widget.entityName,
        sectionLabel: _sectionLabel(widget.section),
        isDark: isDark,
        child: UniversalReminderSection(
          creatorContext: FinanceNotificationCreatorContext.forRecurringIncome(
            incomeId: _income!.id,
            incomeName: _income!.title,
          ),
          isDark: isDark,
          onRemindersChanged: _onRemindersChanged,
        ),
      );
    }

    return const SizedBox.shrink();
  }

  String _sectionLabel(String section) {
    switch (section) {
      case FinanceNotificationContract.sectionBills:
        return 'Bills & Subscriptions';
      case FinanceNotificationContract.sectionDebts:
        return 'Debts';
      case FinanceNotificationContract.sectionLending:
        return 'Lending';
      case FinanceNotificationContract.sectionRecurringIncome:
        return 'Recurring Income';
      default:
        return section;
    }
  }
}

class _ReminderEditorContent extends StatelessWidget {
  final String entityName;
  final String sectionLabel;
  final bool isDark;
  final Widget child;

  const _ReminderEditorContent({
    required this.entityName,
    required this.sectionLabel,
    required this.isDark,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header card
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      AppColorSchemes.primaryGold.withOpacity(0.2),
                      AppColorSchemes.primaryGold.withOpacity(0.06),
                    ]
                  : [
                      AppColorSchemes.primaryGold.withOpacity(0.15),
                      AppColorSchemes.primaryGold.withOpacity(0.04),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColorSchemes.primaryGold.withOpacity(isDark ? 0.3 : 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColorSchemes.primaryGold.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.edit_notifications_rounded,
                      color: AppColorSchemes.primaryGold,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entityName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Edits apply to all reminders in this group',
                          style: TextStyle(
                            fontSize: 12,
                            color: (isDark ? Colors.white : Colors.black).withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColorSchemes.primaryGold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  sectionLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColorSchemes.primaryGold,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Editor
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            child: child,
          ),
        ),
      ],
    );
  }
}
