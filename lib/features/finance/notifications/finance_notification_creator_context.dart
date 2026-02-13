import 'package:flutter/material.dart';

import '../../../core/notifications/models/notification_creator_context.dart';
import 'finance_notification_contract.dart';

/// Builds [NotificationCreatorContext] for Finance module entities.
///
/// Used when opening the Universal Notification Creator from bills,
/// debts, or recurring income screens.
class FinanceNotificationCreatorContext {
  static const _financeVariables = [
    NotificationTemplateVariable(
      key: '{billName}',
      description: 'Name of the bill or subscription',
      example: 'Netflix',
    ),
    NotificationTemplateVariable(
      key: '{amount}',
      description: 'Amount due',
      example: 'ETB 500.00',
    ),
    NotificationTemplateVariable(
      key: '{dueDate}',
      description: 'Due date (formatted)',
      example: 'Feb 12, 2025',
    ),
    NotificationTemplateVariable(
      key: '{daysLeft}',
      description: 'Days until due',
      example: '3',
    ),
    NotificationTemplateVariable(
      key: '{daysOverdue}',
      description: 'Days past due (for overdue notifications)',
      example: '2',
    ),
    NotificationTemplateVariable(
      key: '{category}',
      description: 'Category name',
      example: 'Entertainment',
    ),
  ];

  static const _financeConditions = [
    NotificationCreatorCondition(
      id: FinanceNotificationContract.conditionAlways,
      label: 'Always',
      description: 'Notify every time (each due date)',
    ),
    NotificationCreatorCondition(
      id: FinanceNotificationContract.conditionOnce,
      label: 'Once',
      description: 'Only the first time',
    ),
    NotificationCreatorCondition(
      id: FinanceNotificationContract.conditionIfUnpaid,
      label: 'If Unpaid',
      description: 'Only when still unpaid',
    ),
    NotificationCreatorCondition(
      id: FinanceNotificationContract.conditionIfOverdue,
      label: 'If Overdue',
      description: 'Only when past due',
    ),
  ];

  static final _billActions = [
    NotificationCreatorAction(
      actionId: 'view',
      label: 'View',
      iconCodePoint: Icons.visibility_rounded.codePoint,
      iconFontFamily: 'MaterialIcons',
      navigates: true,
    ),
    NotificationCreatorAction(
      actionId: 'mark_paid',
      label: 'Mark Paid',
      iconCodePoint: Icons.check_circle_rounded.codePoint,
      iconFontFamily: 'MaterialIcons',
      performsAction: true,
      navigates: false,
    ),
    NotificationCreatorAction(
      actionId: 'snooze',
      label: 'Snooze',
      iconCodePoint: Icons.snooze_rounded.codePoint,
      iconFontFamily: 'MaterialIcons',
      performsAction: true,
      navigates: false,
    ),
  ];

  static final _billKinds = [
    NotificationCreatorKind(
      id: 'reminder_before',
      label: 'Reminder Before Due',
      description: 'Notify X days before due date',
      defaults: NotificationCreatorDefaults(
        titleTemplate: '{billName} due in {daysLeft} days',
        bodyTemplate: '{amount} - due {dueDate}',
        typeId: FinanceNotificationContract.typeBillUpcoming,
        timing: 'before',
        timingValue: 3,
        timingUnit: 'days',
        hour: 9,
        minute: 0,
        condition: FinanceNotificationContract.conditionAlways,
        actionsEnabled: true,
        actions: [
          NotificationCreatorAction(
            actionId: 'view',
            label: 'View',
            iconCodePoint: Icons.visibility_rounded.codePoint,
            iconFontFamily: 'MaterialIcons',
            navigates: true,
          ),
          NotificationCreatorAction(
            actionId: 'snooze',
            label: 'Snooze',
            iconCodePoint: Icons.snooze_rounded.codePoint,
            iconFontFamily: 'MaterialIcons',
            performsAction: true,
            navigates: false,
          ),
        ],
      ),
    ),
    NotificationCreatorKind(
      id: 'due_today',
      label: 'Due Today',
      description: 'Notify on the due date',
      defaults: NotificationCreatorDefaults(
        titleTemplate: 'Due today: {billName}',
        bodyTemplate: '{amount} due - pay now',
        typeId: FinanceNotificationContract.typePaymentDue,
        timing: 'on_due',
        timingValue: 0,
        timingUnit: 'days',
        hour: 9,
        minute: 0,
        condition: FinanceNotificationContract.conditionAlways,
        actionsEnabled: true,
        actions: [
          NotificationCreatorAction(
            actionId: 'view',
            label: 'View',
            iconCodePoint: Icons.visibility_rounded.codePoint,
            iconFontFamily: 'MaterialIcons',
            navigates: true,
          ),
          NotificationCreatorAction(
            actionId: 'mark_paid',
            label: 'Mark Paid',
            iconCodePoint: Icons.check_circle_rounded.codePoint,
            iconFontFamily: 'MaterialIcons',
            performsAction: true,
            navigates: false,
          ),
          NotificationCreatorAction(
            actionId: 'snooze',
            label: 'Snooze',
            iconCodePoint: Icons.snooze_rounded.codePoint,
            iconFontFamily: 'MaterialIcons',
            performsAction: true,
            navigates: false,
          ),
        ],
      ),
    ),
    NotificationCreatorKind(
      id: 'overdue',
      label: 'Overdue',
      description: 'Notify when past due',
      defaults: NotificationCreatorDefaults(
        titleTemplate: 'Overdue: {billName}',
        bodyTemplate: '{daysOverdue} days overdue - {amount}',
        typeId: FinanceNotificationContract.typeBillOverdue,
        timing: 'after_due',
        timingValue: 1,
        timingUnit: 'days',
        hour: 9,
        minute: 0,
        condition: FinanceNotificationContract.conditionIfOverdue,
        actionsEnabled: true,
        actions: [
          NotificationCreatorAction(
            actionId: 'view',
            label: 'View',
            iconCodePoint: Icons.visibility_rounded.codePoint,
            iconFontFamily: 'MaterialIcons',
            navigates: true,
          ),
          NotificationCreatorAction(
            actionId: 'mark_paid',
            label: 'Mark Paid',
            iconCodePoint: Icons.check_circle_rounded.codePoint,
            iconFontFamily: 'MaterialIcons',
            performsAction: true,
            navigates: false,
          ),
          NotificationCreatorAction(
            actionId: 'snooze',
            label: 'Snooze',
            iconCodePoint: Icons.snooze_rounded.codePoint,
            iconFontFamily: 'MaterialIcons',
            performsAction: true,
            navigates: false,
          ),
        ],
      ),
    ),
    NotificationCreatorKind(
      id: 'tomorrow',
      label: 'Due Tomorrow',
      description: 'Notify the day before due',
      defaults: NotificationCreatorDefaults(
        titleTemplate: '{billName} due tomorrow',
        bodyTemplate: '{amount} - due {dueDate}',
        typeId: FinanceNotificationContract.typeBillTomorrow,
        timing: 'before',
        timingValue: 1,
        timingUnit: 'days',
        hour: 9,
        minute: 0,
        condition: FinanceNotificationContract.conditionAlways,
        actionsEnabled: true,
        actions: [
          NotificationCreatorAction(
            actionId: 'view',
            label: 'View',
            iconCodePoint: Icons.visibility_rounded.codePoint,
            iconFontFamily: 'MaterialIcons',
            navigates: true,
          ),
          NotificationCreatorAction(
            actionId: 'mark_paid',
            label: 'Mark Paid',
            iconCodePoint: Icons.check_circle_rounded.codePoint,
            iconFontFamily: 'MaterialIcons',
            performsAction: true,
            navigates: false,
          ),
          NotificationCreatorAction(
            actionId: 'snooze',
            label: 'Snooze',
            iconCodePoint: Icons.snooze_rounded.codePoint,
            iconFontFamily: 'MaterialIcons',
            performsAction: true,
            navigates: false,
          ),
        ],
      ),
    ),
  ];

  /// Context for a bill reminder.
  static NotificationCreatorContext forBill({
    required String billId,
    required String billName,
  }) {
    return NotificationCreatorContext(
      moduleId: FinanceNotificationContract.moduleId,
      section: FinanceNotificationContract.sectionBills,
      entityId: billId,
      entityName: billName,
      variables: _financeVariables,
      availableActions: _billActions,
      defaults: _billKinds.first.defaults,
      conditions: _financeConditions,
      notificationKinds: _billKinds,
    );
  }

  /// Context for a debt reminder.
  static NotificationCreatorContext forDebt({
    required String debtId,
    required String debtorName,
  }) {
    return NotificationCreatorContext(
      moduleId: FinanceNotificationContract.moduleId,
      section: FinanceNotificationContract.sectionDebts,
      entityId: debtId,
      entityName: debtorName,
      variables: _financeVariables,
      availableActions: [
        NotificationCreatorAction(
          actionId: 'view',
          label: 'View',
          iconCodePoint: Icons.visibility_rounded.codePoint,
          iconFontFamily: 'MaterialIcons',
          navigates: true,
        ),
        NotificationCreatorAction(
          actionId: 'snooze',
          label: 'Snooze',
          iconCodePoint: Icons.snooze_rounded.codePoint,
          iconFontFamily: 'MaterialIcons',
          performsAction: true,
          navigates: false,
        ),
      ],
      defaults: NotificationCreatorDefaults(
        titleTemplate: '{billName} - payment due in {daysLeft} days',
        bodyTemplate: '{amount} - due {dueDate}',
        typeId: FinanceNotificationContract.typeDebtReminder,
        timing: 'before',
        timingValue: 1,
        timingUnit: 'days',
        hour: 9,
        minute: 0,
        condition: FinanceNotificationContract.conditionAlways,
        actionsEnabled: true,
        actions: [
          NotificationCreatorAction(
            actionId: 'view',
            label: 'View',
            iconCodePoint: Icons.visibility_rounded.codePoint,
            iconFontFamily: 'MaterialIcons',
            navigates: true,
          ),
          NotificationCreatorAction(
            actionId: 'snooze',
            label: 'Snooze',
            iconCodePoint: Icons.snooze_rounded.codePoint,
            iconFontFamily: 'MaterialIcons',
            performsAction: true,
            navigates: false,
          ),
        ],
      ),
      conditions: _financeConditions,
    );
  }

  /// Context for recurring income reminder.
  static NotificationCreatorContext forRecurringIncome({
    required String incomeId,
    required String incomeName,
  }) {
    return NotificationCreatorContext(
      moduleId: FinanceNotificationContract.moduleId,
      section: FinanceNotificationContract.sectionRecurringIncome,
      entityId: incomeId,
      entityName: incomeName,
      variables: _financeVariables,
      availableActions: [
        NotificationCreatorAction(
          actionId: 'view',
          label: 'View',
          iconCodePoint: Icons.visibility_rounded.codePoint,
          iconFontFamily: 'MaterialIcons',
          navigates: true,
        ),
        NotificationCreatorAction(
          actionId: 'snooze',
          label: 'Snooze',
          iconCodePoint: Icons.snooze_rounded.codePoint,
          iconFontFamily: 'MaterialIcons',
          performsAction: true,
          navigates: false,
        ),
      ],
      defaults: NotificationCreatorDefaults(
        titleTemplate: '{billName} - expected in {daysLeft} days',
        bodyTemplate: '{amount} - due {dueDate}',
        typeId: FinanceNotificationContract.typeIncomeReminder,
        timing: 'before',
        timingValue: 1,
        timingUnit: 'days',
        hour: 9,
        minute: 0,
        condition: FinanceNotificationContract.conditionAlways,
        actionsEnabled: true,
        actions: [
          NotificationCreatorAction(
            actionId: 'view',
            label: 'View',
            iconCodePoint: Icons.visibility_rounded.codePoint,
            iconFontFamily: 'MaterialIcons',
            navigates: true,
          ),
          NotificationCreatorAction(
            actionId: 'snooze',
            label: 'Snooze',
            iconCodePoint: Icons.snooze_rounded.codePoint,
            iconFontFamily: 'MaterialIcons',
            performsAction: true,
            navigates: false,
          ),
        ],
      ),
      conditions: _financeConditions,
    );
  }
}
