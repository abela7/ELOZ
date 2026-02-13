import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/notifications/notifications.dart';
import '../../../routing/app_router.dart';
import '../data/models/bill_reminder.dart';
import '../data/models/bill.dart';
import '../data/models/debt.dart';
import '../data/models/recurring_income.dart';
import '../data/repositories/bill_repository.dart';
import '../data/repositories/debt_repository.dart';
import '../data/repositories/recurring_income_repository.dart';
import '../presentation/screens/bills_subscriptions_screen.dart';
import '../presentation/screens/budgets_screen.dart';
import '../presentation/screens/debts_screen.dart';
import '../presentation/screens/lending_screen.dart';
import '../presentation/screens/recurring_income_screen.dart';
import '../presentation/screens/savings_goals_screen.dart';
import 'finance_notification_contract.dart';
import 'finance_notification_scheduler.dart';

class FinanceNotificationAdapter implements MiniAppNotificationAdapter {
  @override
  NotificationHubModule get module => NotificationHubModule(
    moduleId: NotificationHubModuleIds.finance,
    displayName: 'Finance Manager',
    description: 'Bills, payments, and budget reminders',
    idRangeStart: NotificationHubIdRanges.financeStart,
    idRangeEnd: NotificationHubIdRanges.financeEnd,
    iconCodePoint: Icons.account_balance_wallet_rounded.codePoint,
    colorValue: Colors.green.toARGB32(),
  );

  // ═══════════════════════════════════════════════════════════════════════
  // Sections – each groups related notification types
  // ═══════════════════════════════════════════════════════════════════════

  @override
  List<HubNotificationSection> get sections => [
    HubNotificationSection(
      id: FinanceNotificationContract.sectionBills,
      displayName: 'Bills & Subscriptions',
      description: 'Payment reminders for recurring bills',
      iconCodePoint: Icons.receipt_long_rounded.codePoint,
      colorValue: Colors.blue.toARGB32(),
    ),
    HubNotificationSection(
      id: FinanceNotificationContract.sectionDebts,
      displayName: 'Debts',
      description: 'Debt payment reminders',
      iconCodePoint: Icons.money_off_rounded.codePoint,
      colorValue: Colors.red.toARGB32(),
    ),
    HubNotificationSection(
      id: FinanceNotificationContract.sectionLending,
      displayName: 'Lending',
      description: 'Money lent collection reminders',
      iconCodePoint: Icons.handshake_rounded.codePoint,
      colorValue: Colors.orange.toARGB32(),
    ),
    HubNotificationSection(
      id: FinanceNotificationContract.sectionBudgets,
      displayName: 'Budgets',
      description: 'Budget limit and window reminders',
      iconCodePoint: Icons.pie_chart_rounded.codePoint,
      colorValue: Colors.teal.toARGB32(),
    ),
    HubNotificationSection(
      id: FinanceNotificationContract.sectionSavingsGoals,
      displayName: 'Savings Goals',
      description: 'Savings deadline reminders',
      iconCodePoint: Icons.savings_rounded.codePoint,
      colorValue: Colors.green.toARGB32(),
    ),
    HubNotificationSection(
      id: FinanceNotificationContract.sectionRecurringIncome,
      displayName: 'Recurring Income',
      description: 'Expected income reminders',
      iconCodePoint: Icons.trending_up_rounded.codePoint,
      colorValue: Colors.purple.toARGB32(),
    ),
  ];

  // ═══════════════════════════════════════════════════════════════════════
  // Notification types – grouped by section
  // ═══════════════════════════════════════════════════════════════════════

  @override
  List<HubNotificationType> get customNotificationTypes => [
    // ── Bills & Subscriptions ──────────────────────────────────────────
    const HubNotificationType(
      id: FinanceNotificationContract.typeBillUpcoming,
      displayName: 'Upcoming Bill',
      moduleId: FinanceNotificationContract.moduleId,
      sectionId: FinanceNotificationContract.sectionBills,
      defaultConfig: HubDeliveryConfig(
        channelKey: 'task_reminders',
        audioStream: 'notification',
      ),
    ),
    const HubNotificationType(
      id: FinanceNotificationContract.typeBillTomorrow,
      displayName: 'Due Tomorrow',
      moduleId: FinanceNotificationContract.moduleId,
      sectionId: FinanceNotificationContract.sectionBills,
      defaultConfig: HubDeliveryConfig(
        channelKey: 'urgent_reminders',
        audioStream: 'notification',
        wakeScreen: true,
      ),
    ),
    const HubNotificationType(
      id: FinanceNotificationContract.typePaymentDue,
      displayName: 'Due Today',
      moduleId: FinanceNotificationContract.moduleId,
      sectionId: FinanceNotificationContract.sectionBills,
      defaultConfig: HubDeliveryConfig(
        channelKey: 'urgent_reminders',
        audioStream: 'alarm',
        useAlarmMode: true,
        wakeScreen: true,
      ),
    ),
    const HubNotificationType(
      id: FinanceNotificationContract.typeBillOverdue,
      displayName: 'Overdue',
      moduleId: FinanceNotificationContract.moduleId,
      sectionId: FinanceNotificationContract.sectionBills,
      defaultConfig: HubDeliveryConfig(
        channelKey: 'urgent_reminders',
        audioStream: 'alarm',
        useAlarmMode: true,
        bypassDnd: true,
        wakeScreen: true,
      ),
    ),

    // ── Debts ──────────────────────────────────────────────────────────
    const HubNotificationType(
      id: FinanceNotificationContract.typeDebtReminder,
      displayName: 'Debt Payment Reminder',
      moduleId: FinanceNotificationContract.moduleId,
      sectionId: FinanceNotificationContract.sectionDebts,
      defaultConfig: HubDeliveryConfig(
        channelKey: 'task_reminders',
        audioStream: 'notification',
        wakeScreen: true,
      ),
    ),

    // ── Lending ────────────────────────────────────────────────────────
    const HubNotificationType(
      id: FinanceNotificationContract.typeLendingReminder,
      displayName: 'Lending Collection Reminder',
      moduleId: FinanceNotificationContract.moduleId,
      sectionId: FinanceNotificationContract.sectionLending,
      defaultConfig: HubDeliveryConfig(
        channelKey: 'task_reminders',
        audioStream: 'notification',
        wakeScreen: true,
      ),
    ),

    // ── Budgets ────────────────────────────────────────────────────────
    const HubNotificationType(
      id: FinanceNotificationContract.typeBudgetLimit,
      displayName: 'Budget Limit Warning',
      moduleId: FinanceNotificationContract.moduleId,
      sectionId: FinanceNotificationContract.sectionBudgets,
      defaultConfig: HubDeliveryConfig(
        channelKey: 'urgent_reminders',
        audioStream: 'notification',
        wakeScreen: true,
      ),
    ),
    const HubNotificationType(
      id: FinanceNotificationContract.typeBudgetWindow,
      displayName: 'Budget Period Reminder',
      moduleId: FinanceNotificationContract.moduleId,
      sectionId: FinanceNotificationContract.sectionBudgets,
      defaultConfig: HubDeliveryConfig(
        channelKey: 'task_reminders',
        audioStream: 'notification',
      ),
    ),

    // ── Savings Goals ──────────────────────────────────────────────────
    const HubNotificationType(
      id: FinanceNotificationContract.typeSavingsDeadline,
      displayName: 'Savings Deadline Reminder',
      moduleId: FinanceNotificationContract.moduleId,
      sectionId: FinanceNotificationContract.sectionSavingsGoals,
      defaultConfig: HubDeliveryConfig(
        channelKey: 'task_reminders',
        audioStream: 'notification',
      ),
    ),

    // ── Recurring Income ───────────────────────────────────────────────
    const HubNotificationType(
      id: FinanceNotificationContract.typeIncomeReminder,
      displayName: 'Income Expected Reminder',
      moduleId: FinanceNotificationContract.moduleId,
      sectionId: FinanceNotificationContract.sectionRecurringIncome,
      defaultConfig: HubDeliveryConfig(
        channelKey: 'task_reminders',
        audioStream: 'notification',
      ),
    ),

    // ── General (no section) ───────────────────────────────────────────
    const HubNotificationType(
      id: FinanceNotificationContract.typeReminder,
      displayName: 'General Finance Reminder',
      moduleId: FinanceNotificationContract.moduleId,
      defaultConfig: HubDeliveryConfig(
        channelKey: 'task_reminders',
        audioStream: 'notification',
      ),
    ),
    const HubNotificationType(
      id: FinanceNotificationContract.typeSummary,
      displayName: 'Finance Summary',
      moduleId: FinanceNotificationContract.moduleId,
      defaultConfig: HubDeliveryConfig(
        channelKey: 'silent_reminders',
        audioStream: 'notification',
        soundKey: '',
        vibrationPatternId: '',
      ),
    ),
  ];

  @override
  Future<void> onNotificationTapped(NotificationHubPayload payload) async {
    await _openFinanceModule(payload);
  }

  @override
  Future<bool> onNotificationAction({
    required String actionId,
    required NotificationHubPayload payload,
    int? notificationId,
  }) async {
    switch (actionId) {
      case 'mark_paid':
      case 'mark_done':
      case 'view':
      case 'open':
        await _openFinanceModule(payload);
        return true;
      default:
        return false;
    }
  }

  @override
  Future<void> onNotificationDeleted(NotificationHubPayload payload) async {
    final targetId =
        payload.extras[FinanceNotificationContract.extraTargetEntityId];
    final reminderId = payload.extras['reminderId'];
    final section = payload.extras[FinanceNotificationContract.extraSection];

    if (targetId == null || targetId.isEmpty) return;

    if (section == FinanceNotificationContract.sectionRecurringIncome) {
      final repo = RecurringIncomeRepository();
      await repo.init();
      final income = repo.getById(targetId);
      if (income == null) return;
      if (reminderId != null && reminderId.isNotEmpty) {
        final updated = income.reminders.where((r) => r.id != reminderId).toList();
        if (updated.length < income.reminders.length) {
          final updatedIncome = income.copyWith(
            remindersJson: BillReminder.encodeList(updated),
            reminderEnabled: updated.isNotEmpty && income.reminderEnabled,
          );
          await repo.save(updatedIncome);
          await FinanceNotificationScheduler().syncRecurringIncome(updatedIncome);
        }
      }
      return;
    }

    if (reminderId == null || reminderId.isEmpty) return;

    if (section == FinanceNotificationContract.sectionBills) {
      final bill = await BillRepository().getBillById(targetId);
      if (bill == null) return;
      final updated = bill.reminders.where((r) => r.id != reminderId).toList();
      if (updated.length == bill.reminders.length) return;
      final updatedBill = bill.copyWith(
        remindersJson: BillReminder.encodeList(updated),
        reminderEnabled: updated.isNotEmpty && bill.reminderEnabled,
      );
      await BillRepository().updateBill(updatedBill);
      await FinanceNotificationScheduler().syncBill(updatedBill);
      return;
    }

    if (section == FinanceNotificationContract.sectionDebts ||
        section == FinanceNotificationContract.sectionLending) {
      final debt = await DebtRepository().getDebtById(targetId);
      if (debt == null) return;
      final updated = debt.reminders.where((r) => r.id != reminderId).toList();
      if (updated.length == debt.reminders.length) return;
      final updatedDebt = debt.copyWith(
        remindersJson: BillReminder.encodeList(updated),
        reminderEnabled: updated.isNotEmpty && debt.reminderEnabled,
      );
      await DebtRepository().updateDebt(updatedDebt);
      await FinanceNotificationScheduler().syncDebt(updatedDebt);
      return;
    }
  }

  @override
  Future<Map<String, String>> resolveVariablesForEntity(
    String entityId,
    String section,
  ) async {
    if (section == FinanceNotificationContract.sectionBills) {
      final bill = await BillRepository().getBillById(entityId);
      if (bill == null) return {};
      return _resolveBillVariables(bill);
    }
    if (section == FinanceNotificationContract.sectionDebts ||
        section == FinanceNotificationContract.sectionLending) {
      final debt = await DebtRepository().getDebtById(entityId);
      if (debt == null) return {};
      return _resolveDebtVariables(debt);
    }
    if (section == FinanceNotificationContract.sectionRecurringIncome) {
      final repo = RecurringIncomeRepository();
      await repo.init();
      final income = repo.getById(entityId);
      if (income == null) return {};
      return _resolveIncomeVariables(income);
    }
    return {};
  }

  Map<String, String> _resolveBillVariables(Bill bill) {
    final due = bill.nextDueDate;
    final now = DateTime.now();
    final delta = due != null ? due.difference(now).inDays : 0;
    final daysLeft = delta > 0 ? delta : 0;
    final daysOverdue = delta < 0 ? -delta : 0;
    return {
      '{billName}': bill.name,
      '{amount}': '${bill.defaultAmount}',
      '{dueDate}': due != null ? DateFormat('MMM d, yyyy').format(due) : '',
      '{daysLeft}': '$daysLeft',
      '{daysOverdue}': '$daysOverdue',
      '{category}': '',
    };
  }

  Map<String, String> _resolveDebtVariables(Debt debt) {
    final due = debt.dueDate;
    final now = DateTime.now();
    final delta = due != null ? due.difference(now).inDays : 0;
    final daysLeft = delta > 0 ? delta : 0;
    final daysOverdue = delta < 0 ? -delta : 0;
    return {
      '{billName}': debt.name,
      '{amount}': '${debt.originalAmount}',
      '{dueDate}': due != null ? DateFormat('MMM d, yyyy').format(due) : '',
      '{daysLeft}': '$daysLeft',
      '{daysOverdue}': '$daysOverdue',
      '{category}': '',
    };
  }

  Map<String, String> _resolveIncomeVariables(RecurringIncome income) {
    final now = DateTime.now();
    final due = income.nextOccurrenceAfter(now);
    final daysLeft = due != null ? due.difference(now).inDays : 0;
    return {
      '{billName}': income.title,
      '{amount}': '${income.amount}',
      '{dueDate}': due != null ? DateFormat('MMM d, yyyy').format(due) : '',
      '{daysLeft}': '$daysLeft',
      '{category}': '',
    };
  }

  String? _resolveSection(NotificationHubPayload payload) {
    final section = payload.extras[FinanceNotificationContract.extraSection];
    if (section != null && section.isNotEmpty) {
      return section;
    }

    // Backward compatibility for existing recurring-income payloads.
    final legacyType = payload.extras['type'];
    if (legacyType == 'recurring_income') {
      return FinanceNotificationContract.sectionRecurringIncome;
    }

    return null;
  }

  Future<void> _openFinanceModule(NotificationHubPayload payload) async {
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) {
      return;
    }
    GoRouter.of(context).go('/finance');

    final section = _resolveSection(payload);
    final destinationBuilder = _destinationForPayload(
      section: section,
      payload: payload,
    );
    if (destinationBuilder == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navContext = rootNavigatorKey.currentContext;
      if (navContext == null || !navContext.mounted) {
        return;
      }
      Navigator.of(
        navContext,
      ).push(MaterialPageRoute(builder: (_) => destinationBuilder()));
    });
  }

  Widget Function()? _destinationForPayload({
    required String? section,
    required NotificationHubPayload payload,
  }) {
    final targetId = payload.extras[FinanceNotificationContract.extraTargetEntityId];
    if (targetId != null && targetId.isNotEmpty) {
      switch (section) {
        case FinanceNotificationContract.sectionDebts:
          return () => DebtDetailsScreen(debtId: targetId);
        case FinanceNotificationContract.sectionLending:
          return () => LendingDetailsScreen(debtId: targetId);
      }
    }
    return _destinationForSection(section);
  }

  Widget Function()? _destinationForSection(String? section) {
    switch (section) {
      case FinanceNotificationContract.sectionBills:
        return () => const BillsSubscriptionsScreen();
      case FinanceNotificationContract.sectionDebts:
        return () => const DebtsScreen();
      case FinanceNotificationContract.sectionLending:
        return () => const LendingScreen();
      case FinanceNotificationContract.sectionBudgets:
        return () => const BudgetsScreen();
      case FinanceNotificationContract.sectionSavingsGoals:
        return () => const SavingsGoalsScreen();
      case FinanceNotificationContract.sectionRecurringIncome:
        return () => const RecurringIncomeScreen();
      default:
        return null;
    }
  }
}
