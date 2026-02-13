import '../../../core/notifications/models/notification_hub_modules.dart';

/// Canonical contract for Finance <-> Notification Hub integration.
///
/// These constants define:
/// - notification type IDs used by Finance
/// - extras keys included in hub payloads
/// - section/screen identifiers for deep-link routing
class FinanceNotificationContract {
  static const String moduleId = NotificationHubModuleIds.finance;
  static const String managedBy = 'finance_scheduler_v1';

  // Hub notification types - Bills
  static const String typeBillUpcoming = 'finance_bill_upcoming';
  static const String typeBillTomorrow = 'finance_bill_tomorrow';
  static const String typePaymentDue = 'finance_payment_due';
  static const String typeBillOverdue = 'finance_bill_overdue';

  // Hub notification types - Debts & Lending
  static const String typeDebtReminder = 'finance_debt_reminder';
  static const String typeLendingReminder = 'finance_lending_reminder';

  // Hub notification types - Budgets
  static const String typeBudgetLimit = 'finance_budget_limit';
  static const String typeBudgetWindow = 'finance_budget_window';

  // Hub notification types - Savings & Income
  static const String typeSavingsDeadline = 'finance_savings_deadline';
  static const String typeIncomeReminder = 'finance_income_reminder';
  
  // Hub notification types - General
  static const String typeReminder = 'finance_reminder';
  static const String typeSummary = 'finance_summary';

  // Extras keys
  static const String extraManagedBy = 'managedBy';
  static const String extraSection = 'section';
  static const String extraScreen = 'screen';
  static const String extraSource = 'source';
  static const String extraTemplate = 'template';
  static const String extraPriorityTier = 'priorityTier';
  static const String extraTargetEntityId = 'targetEntityId';
  static const String extraTargetDate = 'targetDate';
  static const String extraEntityKind = 'entityKind';
  static const String extraOnceKey = 'onceKey';

  // Reminder conditions
  static const String conditionAlways = 'always';
  static const String conditionIfUnpaid = 'if_unpaid';
  static const String conditionIfOverdue = 'if_overdue';
  static const String conditionOnce = 'once';

  // Section identifiers
  static const String sectionBills = 'bills';
  static const String sectionDebts = 'debts';
  static const String sectionLending = 'lending';
  static const String sectionBudgets = 'budgets';
  static const String sectionSavingsGoals = 'savings_goals';
  static const String sectionRecurringIncome = 'recurring_income';

  // Screen identifiers (used by FinanceNotificationAdapter deep-linking)
  static const String screenBills = 'bills_subscriptions';
  static const String screenDebts = 'debts';
  static const String screenLending = 'lending';
  static const String screenBudgets = 'budgets';
  static const String screenSavingsGoals = 'savings_goals';
  static const String screenRecurringIncome = 'recurring_income';

  // Data sources
  static const String sourceBills = 'billsBox';
  static const String sourceDebts = 'debtsBox';
  static const String sourceBudgets = 'budgetsBox';
  static const String sourceSavingsGoals = 'savingsGoalsBox';
  static const String sourceRecurringIncome = 'recurring_incomes';

  // Template names
  static const String templateBillDue = 'bill_due';
  static const String templateBillFriendly = 'bill_due_friendly';
  static const String templateBillAction = 'bill_due_action';
  static const String templateBillCompact = 'bill_due_compact';
  static const String templateDebtDue = 'debt_due';
  static const String templateLendingDue = 'lending_due';
  static const String templateBudgetWindow = 'budget_window';
  static const String templateBudgetLimit = 'budget_limit';
  static const String templateSavingsGoal = 'savings_goal_deadline';
  static const String templateRecurringIncome = 'recurring_income_due';
}
