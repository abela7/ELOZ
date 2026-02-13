import 'package:flutter/foundation.dart';

import '../../../core/notifications/notifications.dart';
import '../data/models/bill.dart';
import '../data/models/bill_reminder.dart';
import '../data/models/debt.dart';
import '../data/models/recurring_income.dart';
import '../data/models/finance_notification_settings.dart';
import '../data/models/savings_goal.dart';
import '../data/repositories/bill_repository.dart';
import '../data/repositories/budget_repository.dart';
import '../data/repositories/debt_repository.dart';
import '../data/repositories/recurring_income_repository.dart';
import '../data/repositories/savings_goal_repository.dart';
import '../data/services/finance_notification_settings_service.dart';
import 'finance_notification_contract.dart';

class FinanceNotificationSyncResult {
  final int cancelled;
  final int scheduled;
  final int failed;
  final Map<String, int> scheduledBySection;

  const FinanceNotificationSyncResult({
    required this.cancelled,
    required this.scheduled,
    required this.failed,
    required this.scheduledBySection,
  });
}

/// Central scheduler for Finance notifications.
///
/// All Finance reminders are converted into standardized
/// [NotificationHubScheduleRequest] payloads with rich metadata.
class FinanceNotificationScheduler {
  final NotificationHub _notificationHub;
  final BillRepository _billRepository;
  final DebtRepository _debtRepository;
  final BudgetRepository _budgetRepository;
  final SavingsGoalRepository _savingsGoalRepository;
  final RecurringIncomeRepository _recurringIncomeRepository;
  final FinanceNotificationSettingsService _settingsService;

  FinanceNotificationScheduler({
    NotificationHub? notificationHub,
    BillRepository? billRepository,
    DebtRepository? debtRepository,
    BudgetRepository? budgetRepository,
    SavingsGoalRepository? savingsGoalRepository,
    RecurringIncomeRepository? recurringIncomeRepository,
    FinanceNotificationSettingsService? settingsService,
  }) : _notificationHub = notificationHub ?? NotificationHub(),
       _billRepository = billRepository ?? BillRepository(),
       _debtRepository = debtRepository ?? DebtRepository(),
       _budgetRepository = budgetRepository ?? BudgetRepository(),
       _savingsGoalRepository =
           savingsGoalRepository ?? SavingsGoalRepository(),
       _recurringIncomeRepository =
           recurringIncomeRepository ?? RecurringIncomeRepository(),
       _settingsService =
           settingsService ?? FinanceNotificationSettingsService();

  Future<FinanceNotificationSyncResult> syncSchedules() async {
    await _notificationHub.initialize();

    final settings = await _settingsService.load();
    final existingModuleSettings = await _notificationHub.getModuleSettings(
      FinanceNotificationContract.moduleId,
    );
    await _notificationHub.setModuleSettings(
      FinanceNotificationContract.moduleId,
      existingModuleSettings.copyWith(
        notificationsEnabled: settings.notificationsEnabled,
      ),
    );

    final cancelled = await clearScheduledNotifications();
    if (!settings.notificationsEnabled) {
      return FinanceNotificationSyncResult(
        cancelled: cancelled,
        scheduled: 0,
        failed: 0,
        scheduledBySection: <String, int>{},
      );
    }

    final triggeredOnceKeys = await _loadTriggeredOnceKeys();
    final now = DateTime.now();
    final horizon = now.add(Duration(days: settings.planningWindowDays));
    final requests = <_SectionedRequest>[];

    if (settings.billsEnabled) {
      requests.addAll(
        await _buildBillRequests(now, horizon, settings, triggeredOnceKeys),
      );
    }
    if (settings.debtsEnabled) {
      requests.addAll(
        await _buildDebtRequests(
          now,
          horizon,
          settings,
          triggeredOnceKeys: triggeredOnceKeys,
          direction: DebtDirection.owed,
        ),
      );
    }
    if (settings.lendingEnabled) {
      requests.addAll(
        await _buildDebtRequests(
          now,
          horizon,
          settings,
          triggeredOnceKeys: triggeredOnceKeys,
          direction: DebtDirection.lent,
        ),
      );
    }
    if (settings.budgetsEnabled) {
      requests.addAll(await _buildBudgetRequests(now, horizon, settings));
    }
    if (settings.savingsGoalsEnabled) {
      requests.addAll(await _buildSavingsGoalRequests(now, horizon, settings));
    }
    if (settings.recurringIncomeEnabled) {
      requests.addAll(
        await _buildRecurringIncomeRequests(
          now,
          horizon,
          settings,
          triggeredOnceKeys,
        ),
      );
    }

    var scheduled = 0;
    var failed = 0;
    final scheduledBySection = <String, int>{};

    final summary = await _notificationHub.getDashboardSummary();
    const maxTotalAlarms = 480;
    final budget = maxTotalAlarms - summary.totalPending;
    var requestsToSchedule = requests;
    if (requests.length > budget && budget > 0) {
      requestsToSchedule = _prioritizeRequests(requests, budget);
      debugPrint(
        'FinanceNotificationScheduler: prioritized ${requestsToSchedule.length}/'
        '${requests.length} requests (budget: $budget). '
        'Dropped lower-priority sections to stay under $maxTotalAlarms alarms.',
      );
    } else if (requests.length > budget && budget <= 0) {
      debugPrint(
        'FinanceNotificationScheduler: no alarm budget (${summary.totalPending} pending). '
        'Skipping Finance schedule.',
      );
      return FinanceNotificationSyncResult(
        cancelled: cancelled,
        scheduled: 0,
        failed: requests.length,
        scheduledBySection: const {},
      );
    }

    for (final sectioned in requestsToSchedule) {
      final result = await _notificationHub.schedule(sectioned.request);
      if (!result.success) {
        failed++;
        if (failed <= 3) {
          debugPrint(
            'FinanceNotificationScheduler: schedule failed – '
            '${result.failureReason}',
          );
        }
        continue;
      }
      scheduled++;
      scheduledBySection[sectioned.section] =
          (scheduledBySection[sectioned.section] ?? 0) + 1;
    }

    return FinanceNotificationSyncResult(
      cancelled: cancelled,
      scheduled: scheduled,
      failed: failed,
      scheduledBySection: scheduledBySection,
    );
  }

  Future<int> clearScheduledNotifications() {
    return _notificationHub.cancelForModule(
      moduleId: FinanceNotificationContract.moduleId,
    );
  }

  Future<List<_SectionedRequest>> _buildBillRequests(
    DateTime now,
    DateTime horizon,
    FinanceNotificationSettings settings,
    Set<String> triggeredOnceKeys,
  ) async {
    final bills = await _billRepository.getActiveBills();
    final requests = <_SectionedRequest>[];

    for (final bill in bills) {
      if (!bill.reminderEnabled || bill.nextDueDate == null) {
        continue;
      }

      final dueAt = _atReminderHour(
        bill.nextDueDate!,
        settings.defaultReminderHour,
      );

      // Iterate through all reminders for this bill
      final reminders = bill.reminders;
      for (final reminder in reminders) {
        if (!reminder.enabled) {
          continue;
        }

        final onceKey = _onceKeyForBill(bill, reminder, dueAt);
        if (_isOnceReminderConsumed(reminder, onceKey, triggeredOnceKeys)) {
          continue;
        }

        // Evaluate condition
        if (!_evaluateCondition(bill, reminder)) {
          continue;
        }

        // Calculate fire time from reminder
        final fireAt = reminder.calculateFireTime(bill.nextDueDate!);

        // Skip if beyond horizon or too far in the past
        if (fireAt.isAfter(horizon)) {
          continue;
        }

        // Allow overdue notifications to fire within 1 day of now
        final dueDays = _daysUntil(now, dueAt);
        final isOverdue = dueDays < 0;
        if (fireAt.isBefore(now.subtract(const Duration(days: 1)))) {
          continue;
        }

        // If fire time is in the past but bill is still relevant, fire soon
        final effectiveFireAt = fireAt.isBefore(now)
            ? now.add(const Duration(minutes: 2))
            : fireAt;

        // Determine priority tier
        final priorityTier = _priorityTierForBill(
          isOverdue: isOverdue,
          dueDays: dueDays,
          type: reminder.typeId,
        );

        // Build message (use template or auto-generate)
        final message = _buildBillMessage(
          bill: bill,
          dueAt: dueAt,
          dueDays: dueDays,
          isOverdue: isOverdue,
          templateKey: FinanceNotificationContract.templateBillDue,
          titleTemplate: reminder.titleTemplate,
          bodyTemplate: reminder.bodyTemplate,
        );

        final entityId = 'bill:${bill.id}:${reminder.id}:${_dateKey(dueAt)}';
        final extras = <String, String>{
          FinanceNotificationContract.extraManagedBy:
              FinanceNotificationContract.managedBy,
          FinanceNotificationContract.extraSection:
              FinanceNotificationContract.sectionBills,
          FinanceNotificationContract.extraScreen:
              FinanceNotificationContract.screenBills,
          FinanceNotificationContract.extraSource:
              FinanceNotificationContract.sourceBills,
          FinanceNotificationContract.extraTemplate:
              FinanceNotificationContract.templateBillDue,
          FinanceNotificationContract.extraPriorityTier: priorityTier,
          FinanceNotificationContract.extraTargetEntityId: bill.id,
          FinanceNotificationContract.extraTargetDate: dueAt.toIso8601String(),
          FinanceNotificationContract.extraEntityKind: bill.type,
          'type': reminder.typeId,
          'reminderId': reminder.id,
          'condition': reminder.condition,
        };
        if (reminder.condition == FinanceNotificationContract.conditionOnce) {
          extras[FinanceNotificationContract.extraOnceKey] = onceKey;
        }

        requests.add(
          _SectionedRequest(
            section: FinanceNotificationContract.sectionBills,
            request: NotificationHubScheduleRequest(
              moduleId: FinanceNotificationContract.moduleId,
              entityId: entityId,
              title: message.title,
              body: message.body,
              scheduledAt: effectiveFireAt,
              reminderType: reminder.timing,
              reminderValue: reminder.value,
              reminderUnit: reminder.unit,
              iconCodePoint: bill.iconCodePoint,
              iconFontFamily: bill.iconFontFamily,
              iconFontPackage: bill.iconFontPackage,
              colorValue: bill.colorValue,
              extras: extras,
              type: reminder.typeId,
              priority: _priorityLabel(priorityTier),
            ),
          ),
        );
      }
    }

    return requests;
  }

  Future<List<_SectionedRequest>> _buildDebtRequests(
    DateTime now,
    DateTime horizon,
    FinanceNotificationSettings settings, {
    required Set<String> triggeredOnceKeys,
    required DebtDirection direction,
  }) async {
    final debts = await _debtRepository.getActiveDebts(direction: direction);
    final requests = <_SectionedRequest>[];
    final isLending = direction == DebtDirection.lent;
    final section = isLending
        ? FinanceNotificationContract.sectionLending
        : FinanceNotificationContract.sectionDebts;
    final screen = isLending
        ? FinanceNotificationContract.screenLending
        : FinanceNotificationContract.screenDebts;
    final template = isLending
        ? FinanceNotificationContract.templateLendingDue
        : FinanceNotificationContract.templateDebtDue;

    for (final debt in debts) {
      if (!debt.reminderEnabled || debt.dueDate == null) {
        continue;
      }

      final dueAt = _atReminderHour(
        debt.dueDate!,
        settings.defaultReminderHour,
      );
      if (dueAt.isAfter(horizon)) {
        continue;
      }

      final dueDays = _daysUntil(now, dueAt);
      final isOverdue = dueDays < 0;

      final reminders = debt.reminders;
      for (final reminder in reminders) {
        if (!reminder.enabled) {
          continue;
        }

        final onceKey = _onceKeyForDebt(debt, reminder, direction);
        if (_isOnceReminderConsumed(reminder, onceKey, triggeredOnceKeys)) {
          continue;
        }

        if (!_evaluateConditionForDebt(debt, reminder)) {
          continue;
        }

        final fireAt = reminder.calculateFireTime(debt.dueDate!);
        if (fireAt.isAfter(horizon)) {
          continue;
        }
        if (fireAt.isBefore(now.subtract(const Duration(days: 1)))) {
          continue;
        }

        final effectiveFireAt = fireAt.isBefore(now)
            ? now.add(const Duration(minutes: 2))
            : fireAt;

        final priorityTier = _priorityTierForBill(
          isOverdue: isOverdue,
          dueDays: dueDays,
          type: reminder.typeId,
        );

        final title = isOverdue
            ? '${debt.name} ${isLending ? 'collection' : 'payment'} overdue'
            : dueDays == 0
            ? '${debt.name} due today'
            : '${debt.name} due in $dueDays day${dueDays == 1 ? '' : 's'}';

        final body =
            'Remaining ${debt.currency} ${debt.currentBalance.toStringAsFixed(2)} - due ${_dateLabel(dueAt)}';

        final entityId =
            'debt:${direction.name}:${debt.id}:${reminder.id}:${_dateKey(dueAt)}';
        final extras = <String, String>{
          FinanceNotificationContract.extraManagedBy:
              FinanceNotificationContract.managedBy,
          FinanceNotificationContract.extraSection: section,
          FinanceNotificationContract.extraScreen: screen,
          FinanceNotificationContract.extraSource:
              FinanceNotificationContract.sourceDebts,
          FinanceNotificationContract.extraTemplate: template,
          FinanceNotificationContract.extraPriorityTier: priorityTier,
          FinanceNotificationContract.extraTargetEntityId: debt.id,
          FinanceNotificationContract.extraTargetDate: dueAt.toIso8601String(),
          FinanceNotificationContract.extraEntityKind: direction.name,
          'type': reminder.typeId,
          'reminderId': reminder.id,
          'condition': reminder.condition,
        };
        if (reminder.condition == FinanceNotificationContract.conditionOnce) {
          extras[FinanceNotificationContract.extraOnceKey] = onceKey;
        }

        requests.add(
          _SectionedRequest(
            section: section,
            request: NotificationHubScheduleRequest(
              moduleId: FinanceNotificationContract.moduleId,
              entityId: entityId,
              title: title,
              body: body,
              scheduledAt: effectiveFireAt,
              reminderType: reminder.timing,
              reminderValue: reminder.value,
              reminderUnit: reminder.unit,
              iconCodePoint: debt.iconCodePoint,
              iconFontFamily: debt.iconFontFamily,
              iconFontPackage: debt.iconFontPackage,
              colorValue: debt.colorValue,
              extras: extras,
              type: reminder.typeId,
              priority: _priorityLabel(priorityTier),
            ),
          ),
        );
      }
    }

    return requests;
  }

  bool _evaluateConditionForDebt(Debt debt, BillReminder reminder) {
    switch (reminder.condition) {
      case FinanceNotificationContract.conditionAlways:
      case FinanceNotificationContract.conditionOnce:
        return true;
      case FinanceNotificationContract.conditionIfUnpaid:
        return debt.currentBalance > 0;
      case FinanceNotificationContract.conditionIfOverdue:
        return debt.isOverdue;
      default:
        return true;
    }
  }

  Future<List<_SectionedRequest>> _buildBudgetRequests(
    DateTime now,
    DateTime horizon,
    FinanceNotificationSettings settings,
  ) async {
    final budgets = await _budgetRepository.getActiveBudgets();
    final requests = <_SectionedRequest>[];

    for (final budget in budgets) {
      if (!budget.alertEnabled) {
        continue;
      }

      final periodEnd = budget.getCurrentPeriodEnd(asOf: now);
      if (periodEnd.isAfter(horizon)) {
        continue;
      }

      final scheduledAt = budget.shouldAlert
          ? now.add(const Duration(minutes: 3))
          : _atReminderHour(periodEnd, settings.defaultReminderHour);
      if (!scheduledAt.isAfter(now)) {
        continue;
      }

      final template = budget.shouldAlert
          ? FinanceNotificationContract.templateBudgetLimit
          : FinanceNotificationContract.templateBudgetWindow;
      final priorityTier = budget.isExceeded ? 'high' : 'medium';
      final title = budget.isExceeded
          ? 'Budget exceeded: ${budget.name}'
          : budget.isApproachingLimit
          ? 'Budget warning: ${budget.name}'
          : 'Budget review: ${budget.name}';
      final body = budget.isExceeded || budget.isApproachingLimit
          ? 'Spent ${budget.spendingPercentage.toStringAsFixed(0)}% of ${budget.currency} ${budget.amount.toStringAsFixed(2)}'
          : 'Period ends on ${_dateLabel(periodEnd)}';

      final entityId =
          'budget:${budget.id}:${_dateKey(periodEnd)}:${budget.shouldAlert ? "alert" : "review"}';
      final extras = <String, String>{
        FinanceNotificationContract.extraManagedBy:
            FinanceNotificationContract.managedBy,
        FinanceNotificationContract.extraSection:
            FinanceNotificationContract.sectionBudgets,
        FinanceNotificationContract.extraScreen:
            FinanceNotificationContract.screenBudgets,
        FinanceNotificationContract.extraSource:
            FinanceNotificationContract.sourceBudgets,
        FinanceNotificationContract.extraTemplate: template,
        FinanceNotificationContract.extraPriorityTier: priorityTier,
        FinanceNotificationContract.extraTargetEntityId: budget.id,
        FinanceNotificationContract.extraTargetDate: periodEnd
            .toIso8601String(),
        FinanceNotificationContract.extraEntityKind: budget.isCategoryBudget
            ? 'category_budget'
            : 'overall_budget',
      };

      requests.add(
        _SectionedRequest(
          section: FinanceNotificationContract.sectionBudgets,
          request: NotificationHubScheduleRequest(
            moduleId: FinanceNotificationContract.moduleId,
            entityId: entityId,
            title: title,
            body: body,
            scheduledAt: scheduledAt,
            reminderType: budget.shouldAlert
                ? 'threshold_reached'
                : 'period_end_review',
            reminderValue: budget.alertThreshold.toInt(),
            reminderUnit: 'percent',
            extras: extras,
            type:
                budget.isExceeded &&
                    (settings.overdueAlertsUseAlarm ||
                        settings.dueTodayAlertsUseAlarm)
                ? FinanceNotificationContract.typePaymentDue
                : FinanceNotificationContract.typeReminder,
            priority: priorityTier == 'high' ? 'High' : 'Medium',
          ),
        ),
      );
    }

    return requests;
  }

  Future<List<_SectionedRequest>> _buildSavingsGoalRequests(
    DateTime now,
    DateTime horizon,
    FinanceNotificationSettings settings,
  ) async {
    final goals = await _savingsGoalRepository.getActiveGoals();
    final requests = <_SectionedRequest>[];

    for (final goal in goals.where(
      (g) => g.isActive && g.remainingAmount > 0,
    )) {
      final targetAt = _atReminderHour(
        goal.targetDate,
        settings.defaultReminderHour,
      );
      if (!targetAt.isAfter(horizon)) {
        if (goal.isOverdue) {
          requests.add(
            _buildSavingsRequest(
              goal: goal,
              scheduledAt: now.add(const Duration(minutes: 2)),
              type: settings.overdueAlertsUseAlarm
                  ? FinanceNotificationContract.typePaymentDue
                  : FinanceNotificationContract.typeReminder,
              priorityTier: 'high',
              daysBefore: -1,
              reminderHour: settings.defaultReminderHour,
            ),
          );
          continue;
        }
      }

      if (targetAt.isAfter(horizon) || goal.isOverdue) {
        continue;
      }

      for (final daysBefore in const <int>[14, 7, 3, 1, 0]) {
        var fireAt = targetAt.subtract(Duration(days: daysBefore));
        if (!fireAt.isAfter(now)) {
          final isTargetToday = _daysUntil(now, targetAt) == 0;
          if (daysBefore == 0 && isTargetToday) {
            fireAt = now.add(const Duration(minutes: 2));
          } else {
            continue;
          }
        }

        final highPriority = daysBefore <= 1;
        final shouldUseAlarm = highPriority && settings.dueTodayAlertsUseAlarm;

        requests.add(
          _buildSavingsRequest(
            goal: goal,
            scheduledAt: fireAt,
            type: shouldUseAlarm
                ? FinanceNotificationContract.typePaymentDue
                : FinanceNotificationContract.typeReminder,
            priorityTier: highPriority ? 'high' : 'medium',
            daysBefore: daysBefore,
            reminderHour: settings.defaultReminderHour,
          ),
        );
      }
    }

    return requests;
  }

  _SectionedRequest _buildSavingsRequest({
    required SavingsGoal goal,
    required DateTime scheduledAt,
    required String type,
    required String priorityTier,
    required int daysBefore,
    required int reminderHour,
  }) {
    final targetAt = _atReminderHour(goal.targetDate, reminderHour);
    final title = daysBefore < 0
        ? 'Savings goal overdue: ${goal.name}'
        : daysBefore == 0
        ? '${goal.name} target date is today'
        : '${goal.name} target in $daysBefore day${daysBefore == 1 ? '' : 's'}';
    final body =
        'Remaining ${goal.currency} ${goal.remainingAmount.toStringAsFixed(2)} Â- target ${_dateLabel(targetAt)}';
    final entityId = daysBefore < 0
        ? 'savings:${goal.id}:overdue'
        : 'savings:${goal.id}:${_dateKey(targetAt)}:$daysBefore';

    final extras = <String, String>{
      FinanceNotificationContract.extraManagedBy:
          FinanceNotificationContract.managedBy,
      FinanceNotificationContract.extraSection:
          FinanceNotificationContract.sectionSavingsGoals,
      FinanceNotificationContract.extraScreen:
          FinanceNotificationContract.screenSavingsGoals,
      FinanceNotificationContract.extraSource:
          FinanceNotificationContract.sourceSavingsGoals,
      FinanceNotificationContract.extraTemplate:
          FinanceNotificationContract.templateSavingsGoal,
      FinanceNotificationContract.extraPriorityTier: priorityTier,
      FinanceNotificationContract.extraTargetEntityId: goal.id,
      FinanceNotificationContract.extraTargetDate: targetAt.toIso8601String(),
      FinanceNotificationContract.extraEntityKind: 'savings_goal',
    };

    return _SectionedRequest(
      section: FinanceNotificationContract.sectionSavingsGoals,
      request: NotificationHubScheduleRequest(
        moduleId: FinanceNotificationContract.moduleId,
        entityId: entityId,
        title: title,
        body: body,
        scheduledAt: scheduledAt,
        reminderType: 'deadline',
        reminderValue: daysBefore,
        reminderUnit: 'days',
        iconCodePoint: goal.iconCodePoint,
        iconFontFamily: goal.iconFontFamily,
        iconFontPackage: goal.iconFontPackage,
        colorValue: goal.colorValue,
        extras: extras,
        type: type,
        priority: priorityTier == 'high' ? 'High' : 'Medium',
      ),
    );
  }

  Future<List<_SectionedRequest>> _buildRecurringIncomeRequests(
    DateTime now,
    DateTime horizon,
    FinanceNotificationSettings settings,
    Set<String> triggeredOnceKeys,
  ) async {
    final requests = <_SectionedRequest>[];

    try {
      await _recurringIncomeRepository.init();
    } catch (error) {
      debugPrint(
        'FinanceNotificationScheduler: recurring income repo init failed: $error',
      );
      return requests;
    }

    // Cap occurrences per stream; OS alarms limited (~500 total).
    final maxOccurrences =
        settings.planningWindowDays.clamp(1, 200);

    final incomes = _recurringIncomeRepository.getCurrentlyActive();
    for (final income in incomes) {
      if (!income.reminderEnabled) continue;

      final reminders = income.reminders;
      final occurrences = income
          .occurrencesBetween(now, horizon)
          .take(maxOccurrences)
          .toList();

      for (final occurrence in occurrences) {
        final dueAt = _atReminderHour(
          occurrence,
          settings.defaultReminderHour,
        );

        for (final reminder in reminders) {
          if (!reminder.enabled) continue;

          final onceKey = _onceKeyForIncome(income, reminder, dueAt);
          if (_isOnceReminderConsumed(reminder, onceKey, triggeredOnceKeys)) {
            continue;
          }

          if (!_evaluateConditionForIncome(income, reminder, occurrence)) {
            continue;
          }

          final fireAt = reminder.calculateFireTime(occurrence);

          if (fireAt.isAfter(horizon)) continue;

          final dueDays = _daysUntil(now, dueAt);
          final isOverdue = dueDays < 0;
          if (fireAt.isBefore(now.subtract(const Duration(days: 1)))) {
            continue;
          }

          final effectiveFireAt = fireAt.isBefore(now)
              ? now.add(const Duration(minutes: 2))
              : fireAt;

          final priorityTier = _priorityTierForBill(
            isOverdue: isOverdue,
            dueDays: dueDays,
            type: reminder.typeId,
          );

          final message = _buildIncomeMessage(
            income: income,
            dueAt: dueAt,
            dueDays: dueDays,
            isOverdue: isOverdue,
            titleTemplate: reminder.titleTemplate,
            bodyTemplate: reminder.bodyTemplate,
          );

          final entityId =
              'income:${income.id}:${reminder.id}:${_dateKey(dueAt)}';
          final extras = <String, String>{
            FinanceNotificationContract.extraManagedBy:
                FinanceNotificationContract.managedBy,
            FinanceNotificationContract.extraSection:
                FinanceNotificationContract.sectionRecurringIncome,
            FinanceNotificationContract.extraScreen:
                FinanceNotificationContract.screenRecurringIncome,
            FinanceNotificationContract.extraSource:
                FinanceNotificationContract.sourceRecurringIncome,
            FinanceNotificationContract.extraTemplate:
                FinanceNotificationContract.templateRecurringIncome,
            FinanceNotificationContract.extraPriorityTier: priorityTier,
            FinanceNotificationContract.extraTargetEntityId: income.id,
            FinanceNotificationContract.extraTargetDate: dueAt.toIso8601String(),
            FinanceNotificationContract.extraEntityKind: 'recurring_income',
            'type': reminder.typeId,
            'reminderId': reminder.id,
            'condition': reminder.condition,
          };
          if (reminder.condition == FinanceNotificationContract.conditionOnce) {
            extras[FinanceNotificationContract.extraOnceKey] = onceKey;
          }

          requests.add(
            _SectionedRequest(
              section: FinanceNotificationContract.sectionRecurringIncome,
              request: NotificationHubScheduleRequest(
                moduleId: FinanceNotificationContract.moduleId,
                entityId: entityId,
                title: message.title,
                body: message.body,
                scheduledAt: effectiveFireAt,
                reminderType: reminder.timing,
                reminderValue: reminder.value,
                reminderUnit: reminder.unit,
                iconCodePoint: income.iconCodePoint,
                iconFontFamily: income.iconFontFamily,
                iconFontPackage: income.iconFontPackage,
                colorValue: income.colorValue,
                extras: extras,
                type: reminder.typeId,
                priority: _priorityLabel(priorityTier),
              ),
            ),
          );
        }
      }
    }

    return requests;
  }

  bool _evaluateConditionForIncome(
    RecurringIncome income,
    BillReminder reminder,
    DateTime occurrence,
  ) {
    switch (reminder.condition) {
      case FinanceNotificationContract.conditionAlways:
      case FinanceNotificationContract.conditionOnce:
        return true;
      case FinanceNotificationContract.conditionIfUnpaid:
      case FinanceNotificationContract.conditionIfOverdue:
        return true; // Income: no unpaid/overdue semantics; treat as always
      default:
        return true;
    }
  }

  _BillMessage _buildIncomeMessage({
    required RecurringIncome income,
    required DateTime dueAt,
    required int dueDays,
    required bool isOverdue,
    String? titleTemplate,
    String? bodyTemplate,
  }) {
    final amount =
        '${income.currency} ${income.amount.toStringAsFixed(2)}';
    final dueLabel = _dateLabel(dueAt);

    if (titleTemplate != null || bodyTemplate != null) {
      final variables = <String, String>{
        '{billName}': income.title,
        '{amount}': amount,
        '{dueDate}': dueLabel,
        '{daysLeft}': dueDays.abs().toString(),
        '{category}': income.categoryId,
      };
      String replaceVariables(String template) {
        var result = template;
        variables.forEach((key, value) {
          result = result.replaceAll(key, value);
        });
        return result;
      }
      final title = titleTemplate != null
          ? replaceVariables(titleTemplate)
          : _getDefaultIncomeTitle(income, dueDays, isOverdue);
      final body = bodyTemplate != null
          ? replaceVariables(bodyTemplate)
          : _getDefaultIncomeBody(amount, dueLabel, isOverdue);
      return _BillMessage(title: title, body: body);
    }

    return _BillMessage(
      title: _getDefaultIncomeTitle(income, dueDays, isOverdue),
      body: _getDefaultIncomeBody(amount, dueLabel, isOverdue),
    );
  }

  String _getDefaultIncomeTitle(
    RecurringIncome income,
    int dueDays,
    bool isOverdue,
  ) {
    if (isOverdue) {
      return '${income.title} income overdue';
    } else if (dueDays == 0) {
      return '${income.title} is due today';
    } else if (dueDays == 1) {
      return '${income.title} is due tomorrow';
    } else {
      return '${income.title} due in $dueDays days';
    }
  }

  String _getDefaultIncomeBody(String amount, String dueLabel, bool isOverdue) {
    return isOverdue
        ? '$amount was expected on $dueLabel'
        : '$amount - expected $dueLabel';
  }

  String _onceKeyForIncome(
    RecurringIncome income,
    BillReminder reminder,
    DateTime dueAt,
  ) {
    return 'income:${income.id}:${reminder.id}:${_dateKey(dueAt)}';
  }

  String _priorityTierForBill({
    required bool isOverdue,
    required int dueDays,
    required String type,
  }) {
    // Priority based on notification type
    switch (type) {
      case FinanceNotificationContract.typeBillOverdue:
        return 'high'; // Overdue - highest priority
      case FinanceNotificationContract.typePaymentDue:
        return 'high'; // Due today - urgent
      case FinanceNotificationContract.typeBillTomorrow:
        return 'medium'; // Due tomorrow - important
      case FinanceNotificationContract.typeBillUpcoming:
        return dueDays <= 3 ? 'medium' : 'low'; // Upcoming - varies
      case FinanceNotificationContract.typeSummary:
        return 'low'; // Summary - low priority
      default:
        return 'medium'; // Default fallback
    }
  }

  String _priorityLabel(String priorityTier) {
    switch (priorityTier) {
      case 'high':
        return 'High';
      case 'low':
        return 'Low';
      default:
        return 'Medium';
    }
  }

  /// Evaluate a bill reminder condition
  bool _evaluateCondition(Bill bill, BillReminder reminder) {
    switch (reminder.condition) {
      case FinanceNotificationContract.conditionAlways:
      case FinanceNotificationContract.conditionOnce:
        return true;
      case FinanceNotificationContract.conditionIfUnpaid:
        return !bill.isPaidForCurrentPeriod;
      case FinanceNotificationContract.conditionIfOverdue:
        return bill.isOverdue;
      default:
        return true; // Default to always if unknown condition
    }
  }

  _BillMessage _buildBillMessage({
    required Bill bill,
    required DateTime dueAt,
    required int dueDays,
    required bool isOverdue,
    required String templateKey,
    String? titleTemplate,
    String? bodyTemplate,
  }) {
    final amount = '${bill.currency} ${bill.defaultAmount.toStringAsFixed(2)}';
    final dueLabel = _dateLabel(dueAt);

    // If custom templates are provided, use them with variable replacement
    if (titleTemplate != null || bodyTemplate != null) {
      final variables = {
        '{billName}': bill.name,
        '{amount}': amount,
        '{dueDate}': dueLabel,
        '{daysLeft}': dueDays.abs().toString(),
        '{category}': bill.categoryId,
      };

      String replaceVariables(String template) {
        var result = template;
        variables.forEach((key, value) {
          result = result.replaceAll(key, value);
        });
        return result;
      }

      final title = titleTemplate != null
          ? replaceVariables(titleTemplate)
          : _getDefaultTitle(bill, dueDays, isOverdue);
      final body = bodyTemplate != null
          ? replaceVariables(bodyTemplate)
          : _getDefaultBody(bill, amount, dueLabel, isOverdue);

      return _BillMessage(title: title, body: body);
    }

    // Use standard templates
    switch (templateKey) {
      case FinanceNotificationContract.templateBillFriendly:
        final title = isOverdue
            ? 'Friendly reminder: ${bill.name} is overdue'
            : dueDays == 0
            ? 'Friendly reminder: ${bill.name} is due today'
            : 'Friendly reminder: ${bill.name} is due soon';
        final body = isOverdue
            ? '$amount was due on $dueLabel'
            : '$amount is due on $dueLabel';
        return _BillMessage(title: title, body: body);
      case FinanceNotificationContract.templateBillAction:
        final title = isOverdue
            ? 'Action needed: pay ${bill.name}'
            : dueDays == 0
            ? 'Action needed today: ${bill.name}'
            : 'Action needed soon: ${bill.name}';
        final body = '$amount - due $dueLabel. Tap to open bill details.';
        return _BillMessage(title: title, body: body);
      case FinanceNotificationContract.templateBillCompact:
        final title = isOverdue
            ? '${bill.name}: overdue'
            : dueDays == 0
            ? '${bill.name}: due today'
            : '${bill.name}: due in $dueDays day${dueDays == 1 ? '' : 's'}';
        final body = '$amount - due $dueLabel';
        return _BillMessage(title: title, body: body);
      case FinanceNotificationContract.templateBillDue:
      default:
        final title = isOverdue
            ? '${bill.name} payment overdue'
            : dueDays == 0
            ? '${bill.name} is due today'
            : '${bill.name} due in $dueDays day${dueDays == 1 ? '' : 's'}';
        final body = '$amount - due $dueLabel';
        return _BillMessage(title: title, body: body);
    }
  }

  String _getDefaultTitle(Bill bill, int dueDays, bool isOverdue) {
    if (isOverdue) {
      return '${bill.name} payment overdue';
    } else if (dueDays == 0) {
      return '${bill.name} is due today';
    } else if (dueDays == 1) {
      return '${bill.name} is due tomorrow';
    } else {
      return '${bill.name} due in $dueDays days';
    }
  }

  String _getDefaultBody(
    Bill bill,
    String amount,
    String dueLabel,
    bool isOverdue,
  ) {
    return isOverdue
        ? '$amount was due on $dueLabel'
        : '$amount - due $dueLabel';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Single-entity sync (call from bill detail on save/delete)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Reschedule notifications for a single bill.
  ///
  /// Call this when the user saves bill settings from the detail screen.
  /// It cancels old notifications for the bill, then schedules new ones
  /// if the bill has reminders enabled.
  Future<bool> syncBill(Bill bill) async {
    await _notificationHub.initialize();

    // Cancel any existing notification for this bill first
    await cancelBillNotifications(bill.id);

    if (!bill.reminderEnabled || bill.nextDueDate == null) {
      debugPrint('⊘ Bill "${bill.name}" has reminders off – skipped');
      return true;
    }

    final settings = await _settingsService.load();
    if (!settings.notificationsEnabled || !settings.billsEnabled) {
      return true;
    }

    final now = DateTime.now();
    final dueAt = _atReminderHour(
      bill.nextDueDate!,
      settings.defaultReminderHour,
    );
    final triggeredOnceKeys = await _loadTriggeredOnceKeys();

    // Schedule all enabled reminders for this bill
    final reminders = bill.reminders;
    var scheduledCount = 0;

    for (final reminder in reminders) {
      if (!reminder.enabled) {
        continue;
      }

      final onceKey = _onceKeyForBill(bill, reminder, dueAt);
      if (_isOnceReminderConsumed(reminder, onceKey, triggeredOnceKeys)) {
        continue;
      }

      // Evaluate condition
      if (!_evaluateCondition(bill, reminder)) {
        debugPrint('⊘ Reminder ${reminder.id} condition not met – skipped');
        continue;
      }

      // Calculate fire time
      final fireAt = reminder.calculateFireTime(bill.nextDueDate!);

      // Skip if too far in the past
      final dueDays = _daysUntil(now, dueAt);
      final isOverdue = dueDays < 0;
      if (fireAt.isBefore(now.subtract(const Duration(days: 1)))) {
        continue;
      }

      // If fire time is in the past but bill is still relevant, fire soon
      final effectiveFireAt = fireAt.isBefore(now)
          ? now.add(const Duration(minutes: 2))
          : fireAt;

      final priorityTier = _priorityTierForBill(
        isOverdue: isOverdue,
        dueDays: dueDays,
        type: reminder.typeId,
      );

      final message = _buildBillMessage(
        bill: bill,
        dueAt: dueAt,
        dueDays: dueDays,
        isOverdue: isOverdue,
        templateKey: FinanceNotificationContract.templateBillDue,
        titleTemplate: reminder.titleTemplate,
        bodyTemplate: reminder.bodyTemplate,
      );

      final entityId = 'bill:${bill.id}:${reminder.id}:${_dateKey(dueAt)}';
      final result = await _notificationHub.schedule(
        NotificationHubScheduleRequest(
          moduleId: FinanceNotificationContract.moduleId,
          entityId: entityId,
          title: message.title,
          body: message.body,
          scheduledAt: effectiveFireAt,
          type: reminder.typeId,
          priority: _priorityLabel(priorityTier),
          reminderType: reminder.timing,
          reminderValue: reminder.value,
          reminderUnit: reminder.unit,
          iconCodePoint: bill.iconCodePoint,
          iconFontFamily: bill.iconFontFamily,
          iconFontPackage: bill.iconFontPackage,
          colorValue: bill.colorValue,
          extras: {
            FinanceNotificationContract.extraManagedBy:
                FinanceNotificationContract.managedBy,
            FinanceNotificationContract.extraSection:
                FinanceNotificationContract.sectionBills,
            FinanceNotificationContract.extraScreen:
                FinanceNotificationContract.screenBills,
            FinanceNotificationContract.extraSource:
                FinanceNotificationContract.sourceBills,
            FinanceNotificationContract.extraTemplate:
                FinanceNotificationContract.templateBillDue,
            FinanceNotificationContract.extraPriorityTier: priorityTier,
            FinanceNotificationContract.extraTargetEntityId: bill.id,
            FinanceNotificationContract.extraTargetDate: dueAt
                .toIso8601String(),
            FinanceNotificationContract.extraEntityKind: bill.type,
            'type': reminder.typeId,
            'reminderId': reminder.id,
            'condition': reminder.condition,
            if (reminder.condition ==
                FinanceNotificationContract.conditionOnce)
              FinanceNotificationContract.extraOnceKey: onceKey,
          },
        ),
      );

      if (result.success) {
        scheduledCount++;
        debugPrint(
          '✓ Scheduled reminder ${reminder.id} for bill "${bill.name}" at $effectiveFireAt',
        );
      }
    }

    debugPrint('✓ Scheduled $scheduledCount reminders for bill "${bill.name}"');
    return true;
  }

  /// Cancel all scheduled notifications for a specific bill.
  ///
  /// Uses the Hub's entity-based cancellation which matches by entity prefix.
  Future<int> cancelBillNotifications(String billId) async {
    await _notificationHub.initialize();

    // The entityId pattern is 'bill:{billId}:{dateKey}'
    // cancelForEntity matches exact entityId, so we look up all pending for
    // this module and cancel any whose entityId starts with 'bill:{billId}:'.
    final all = await _notificationHub.getScheduledNotificationsForModule(
      FinanceNotificationContract.moduleId,
    );

    int cancelled = 0;
    for (final entry in all) {
      final entityId = entry['entityId'] as String? ?? '';
      if (entityId.startsWith('bill:$billId:')) {
        final notifId = entry['id'] as int?;
        if (notifId != null) {
          await _notificationHub.cancelByNotificationId(
            notificationId: notifId,
            entityId: entityId,
            payload: entry['payload'] as String?,
          );
          cancelled++;
        }
      }
    }

    if (cancelled > 0) {
      debugPrint('✓ Cancelled $cancelled notification(s) for bill $billId');
    }
    return cancelled;
  }

  /// Cancel all scheduled notifications for a specific debt (owed or lent).
  Future<int> cancelDebtNotifications(String debtId) async {
    await _notificationHub.initialize();

    final all = await _notificationHub.getScheduledNotificationsForModule(
      FinanceNotificationContract.moduleId,
    );

    int cancelled = 0;
    for (final entry in all) {
      final entityId = entry['entityId'] as String? ?? '';
      if (entityId.startsWith('debt:owed:$debtId:') ||
          entityId.startsWith('debt:lent:$debtId:')) {
        final notifId = entry['id'] as int?;
        if (notifId != null) {
          await _notificationHub.cancelByNotificationId(
            notificationId: notifId,
            entityId: entityId,
            payload: entry['payload'] as String?,
          );
          cancelled++;
        }
      }
    }

    if (cancelled > 0) {
      debugPrint('✓ Cancelled $cancelled notification(s) for debt $debtId');
    }
    return cancelled;
  }

  /// Cancel all scheduled notifications for a specific recurring income.
  Future<int> cancelRecurringIncomeNotifications(String incomeId) async {
    await _notificationHub.initialize();

    final all = await _notificationHub.getScheduledNotificationsForModule(
      FinanceNotificationContract.moduleId,
    );

    int cancelled = 0;
    for (final entry in all) {
      final entityId = entry['entityId'] as String? ?? '';
      if (entityId.startsWith('income:$incomeId:')) {
        final notifId = entry['id'] as int?;
        if (notifId != null) {
          await _notificationHub.cancelByNotificationId(
            notificationId: notifId,
            entityId: entityId,
            payload: entry['payload'] as String?,
          );
          cancelled++;
        }
      }
    }

    if (cancelled > 0) {
      debugPrint(
        '✓ Cancelled $cancelled notification(s) for recurring income $incomeId',
      );
    }
    return cancelled;
  }

  /// Sync notifications for a single debt (cancel existing, schedule from
  /// debt.reminders when enabled).
  Future<bool> syncDebt(Debt debt) async {
    await _notificationHub.initialize();

    await cancelDebtNotifications(debt.id);

    if (!debt.reminderEnabled || debt.dueDate == null) {
      debugPrint('⊘ Debt "${debt.name}" has reminders off – skipped');
      return true;
    }

    final settings = await _settingsService.load();
    if (!settings.notificationsEnabled ||
        (!settings.debtsEnabled && debt.isOwed) ||
        (!settings.lendingEnabled && debt.isLent)) {
      return true;
    }

    final now = DateTime.now();
    final dueAt = _atReminderHour(debt.dueDate!, settings.defaultReminderHour);
    final dueDays = _daysUntil(now, dueAt);
    final isOverdue = dueDays < 0;
    final triggeredOnceKeys = await _loadTriggeredOnceKeys();
    final direction = debt.debtDirection;
    final section = debt.isLent
        ? FinanceNotificationContract.sectionLending
        : FinanceNotificationContract.sectionDebts;
    final screen = debt.isLent
        ? FinanceNotificationContract.screenLending
        : FinanceNotificationContract.screenDebts;
    final template = debt.isLent
        ? FinanceNotificationContract.templateLendingDue
        : FinanceNotificationContract.templateDebtDue;

    var scheduledCount = 0;
    for (final reminder in debt.reminders) {
      if (!reminder.enabled) continue;
      final onceKey = _onceKeyForDebt(debt, reminder, direction);
      if (_isOnceReminderConsumed(reminder, onceKey, triggeredOnceKeys)) {
        continue;
      }
      if (!_evaluateConditionForDebt(debt, reminder)) continue;

      final fireAt = reminder.calculateFireTime(debt.dueDate!);
      if (fireAt.isBefore(now.subtract(const Duration(days: 1)))) continue;

      final effectiveFireAt = fireAt.isBefore(now)
          ? now.add(const Duration(minutes: 2))
          : fireAt;

      final priorityTier = _priorityTierForBill(
        isOverdue: isOverdue,
        dueDays: dueDays,
        type: reminder.typeId,
      );

      final title = isOverdue
          ? '${debt.name} ${debt.isLent ? 'collection' : 'payment'} overdue'
          : dueDays == 0
          ? '${debt.name} due today'
          : '${debt.name} due in $dueDays day${dueDays == 1 ? '' : 's'}';

      final body =
          'Remaining ${debt.currency} ${debt.currentBalance.toStringAsFixed(2)} - due ${_dateLabel(dueAt)}';

      final entityId =
          'debt:${direction.name}:${debt.id}:${reminder.id}:${_dateKey(dueAt)}';
      final extras = <String, String>{
        FinanceNotificationContract.extraManagedBy:
            FinanceNotificationContract.managedBy,
        FinanceNotificationContract.extraSection: section,
        FinanceNotificationContract.extraScreen: screen,
        FinanceNotificationContract.extraSource:
            FinanceNotificationContract.sourceDebts,
        FinanceNotificationContract.extraTemplate: template,
        FinanceNotificationContract.extraPriorityTier: priorityTier,
        FinanceNotificationContract.extraTargetEntityId: debt.id,
        FinanceNotificationContract.extraTargetDate: dueAt.toIso8601String(),
        FinanceNotificationContract.extraEntityKind: direction.name,
        'type': reminder.typeId,
        'reminderId': reminder.id,
        'condition': reminder.condition,
      };
      if (reminder.condition == FinanceNotificationContract.conditionOnce) {
        extras[FinanceNotificationContract.extraOnceKey] = onceKey;
      }

      await _notificationHub.schedule(
        NotificationHubScheduleRequest(
          moduleId: FinanceNotificationContract.moduleId,
          entityId: entityId,
          title: title,
          body: body,
          scheduledAt: effectiveFireAt,
          reminderType: reminder.timing,
          reminderValue: reminder.value,
          reminderUnit: reminder.unit,
          iconCodePoint: debt.iconCodePoint,
          iconFontFamily: debt.iconFontFamily,
          iconFontPackage: debt.iconFontPackage,
          colorValue: debt.colorValue,
          extras: extras,
          type: reminder.typeId,
          priority: _priorityLabel(priorityTier),
        ),
      );
      scheduledCount++;
    }

    if (scheduledCount > 0) {
      debugPrint(
        '✓ Scheduled $scheduledCount notification(s) for debt ${debt.name}',
      );
    }
    return true;
  }

  /// Sync notifications for a single recurring income (cancel existing,
  /// schedule from income.reminders when enabled).
  Future<bool> syncRecurringIncome(RecurringIncome income) async {
    await _notificationHub.initialize();

    await cancelRecurringIncomeNotifications(income.id);

    if (!income.reminderEnabled) {
      debugPrint('⊘ Recurring income "${income.title}" has reminders off – skipped');
      return true;
    }

    final reminders = income.reminders;
    if (reminders.isEmpty) {
      debugPrint('⊘ Recurring income "${income.title}" has no reminders – skipped');
      return true;
    }

    final settings = await _settingsService.load();
    if (!settings.notificationsEnabled || !settings.recurringIncomeEnabled) {
      return true;
    }

    final now = DateTime.now();
    final horizon = now.add(Duration(days: settings.planningWindowDays));
    final triggeredOnceKeys = await _loadTriggeredOnceKeys();
    final maxOccurrences = settings.planningWindowDays.clamp(1, 200);

    final occurrences = income
        .occurrencesBetween(now, horizon)
        .take(maxOccurrences)
        .toList();

    var scheduledCount = 0;

    for (final occurrence in occurrences) {
      final dueAt = _atReminderHour(
        occurrence,
        settings.defaultReminderHour,
      );

      for (final reminder in reminders) {
        if (!reminder.enabled) continue;

        final onceKey = _onceKeyForIncome(income, reminder, dueAt);
        if (_isOnceReminderConsumed(reminder, onceKey, triggeredOnceKeys)) {
          continue;
        }

        if (!_evaluateConditionForIncome(income, reminder, occurrence)) {
          continue;
        }

        final fireAt = reminder.calculateFireTime(occurrence);
        if (fireAt.isAfter(horizon)) continue;

        final dueDays = _daysUntil(now, dueAt);
        final isOverdue = dueDays < 0;
        if (fireAt.isBefore(now.subtract(const Duration(days: 1)))) {
          continue;
        }

        final effectiveFireAt = fireAt.isBefore(now)
            ? now.add(const Duration(minutes: 2))
            : fireAt;

        final priorityTier = _priorityTierForBill(
          isOverdue: isOverdue,
          dueDays: dueDays,
          type: reminder.typeId,
        );

        final message = _buildIncomeMessage(
          income: income,
          dueAt: dueAt,
          dueDays: dueDays,
          isOverdue: isOverdue,
          titleTemplate: reminder.titleTemplate,
          bodyTemplate: reminder.bodyTemplate,
        );

        final entityId =
            'income:${income.id}:${reminder.id}:${_dateKey(dueAt)}';
        final extras = <String, String>{
          FinanceNotificationContract.extraManagedBy:
              FinanceNotificationContract.managedBy,
          FinanceNotificationContract.extraSection:
              FinanceNotificationContract.sectionRecurringIncome,
          FinanceNotificationContract.extraScreen:
              FinanceNotificationContract.screenRecurringIncome,
          FinanceNotificationContract.extraSource:
              FinanceNotificationContract.sourceRecurringIncome,
          FinanceNotificationContract.extraTemplate:
              FinanceNotificationContract.templateRecurringIncome,
          FinanceNotificationContract.extraPriorityTier: priorityTier,
          FinanceNotificationContract.extraTargetEntityId: income.id,
          FinanceNotificationContract.extraTargetDate: dueAt.toIso8601String(),
          FinanceNotificationContract.extraEntityKind: 'recurring_income',
          'type': reminder.typeId,
          'reminderId': reminder.id,
          'condition': reminder.condition,
        };
        if (reminder.condition == FinanceNotificationContract.conditionOnce) {
          extras[FinanceNotificationContract.extraOnceKey] = onceKey;
        }

        await _notificationHub.schedule(
          NotificationHubScheduleRequest(
            moduleId: FinanceNotificationContract.moduleId,
            entityId: entityId,
            title: message.title,
            body: message.body,
            scheduledAt: effectiveFireAt,
            reminderType: reminder.timing,
            reminderValue: reminder.value,
            reminderUnit: reminder.unit,
            iconCodePoint: income.iconCodePoint,
            iconFontFamily: income.iconFontFamily,
            iconFontPackage: income.iconFontPackage,
            colorValue: income.colorValue,
            extras: extras,
            type: reminder.typeId,
            priority: _priorityLabel(priorityTier),
          ),
        );
        scheduledCount++;
      }
    }

    if (scheduledCount > 0) {
      debugPrint(
        '✓ Scheduled $scheduledCount notification(s) for recurring income ${income.title}',
      );
    }
    return true;
  }

  String _onceKeyForBill(Bill bill, BillReminder reminder, DateTime dueAt) {
    return 'bill:${bill.id}:${reminder.id}:${_dateKey(dueAt)}';
  }

  String _onceKeyForDebt(
    Debt debt,
    BillReminder reminder,
    DebtDirection direction,
  ) {
    return 'debt:${direction.name}:${debt.id}:${reminder.id}';
  }

  bool _isOnceReminderConsumed(
    BillReminder reminder,
    String onceKey,
    Set<String> triggeredOnceKeys,
  ) {
    if (reminder.condition != FinanceNotificationContract.conditionOnce) {
      return false;
    }
    return triggeredOnceKeys.contains(onceKey);
  }

  Future<Set<String>> _loadTriggeredOnceKeys() async {
    final history = await _notificationHub.getHistory(
      moduleId: FinanceNotificationContract.moduleId,
      limit: 1200,
    );

    final keys = <String>{};
    for (final entry in history) {
      if (!_isOnceTerminalEvent(entry.event)) {
        continue;
      }
      final parsed = NotificationHubPayload.tryParse(entry.payload);
      final onceKey = parsed?.extras[FinanceNotificationContract.extraOnceKey];
      if (onceKey != null && onceKey.isNotEmpty) {
        keys.add(onceKey);
      }
    }
    return keys;
  }

  bool _isOnceTerminalEvent(NotificationLifecycleEvent event) {
    switch (event) {
      case NotificationLifecycleEvent.scheduled:
        // Treat scheduled as consumed: we only schedule once reminders once.
        // "delivered" is never logged by the plugin, so without this, the
        // onceKey would never be recorded unless the user taps.
      case NotificationLifecycleEvent.delivered:
      case NotificationLifecycleEvent.tapped:
      case NotificationLifecycleEvent.action:
      case NotificationLifecycleEvent.missed:
        return true;
      case NotificationLifecycleEvent.snoozed:
      case NotificationLifecycleEvent.cancelled:
      case NotificationLifecycleEvent.failed:
        return false;
    }
  }

  /// When alarm budget is limited, keep highest-priority sections first.
  List<_SectionedRequest> _prioritizeRequests(
    List<_SectionedRequest> requests,
    int budget,
  ) {
    const priorityOrder = [
      FinanceNotificationContract.sectionBills,
      FinanceNotificationContract.sectionDebts,
      FinanceNotificationContract.sectionLending,
      FinanceNotificationContract.sectionBudgets,
      FinanceNotificationContract.sectionSavingsGoals,
      FinanceNotificationContract.sectionRecurringIncome,
    ];

    final bySection = <String, List<_SectionedRequest>>{};
    for (final r in requests) {
      bySection.putIfAbsent(r.section, () => []).add(r);
    }

    final result = <_SectionedRequest>[];
    for (final section in priorityOrder) {
      final list = bySection[section];
      if (list == null) continue;
      for (final r in list) {
        if (result.length >= budget) return result;
        result.add(r);
      }
    }
    return result;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Internal helpers
  // ═══════════════════════════════════════════════════════════════════════════

  DateTime _atReminderHour(DateTime date, int hour) {
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day, hour);
  }

  int _daysUntil(DateTime now, DateTime target) {
    final nowDate = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(target.year, target.month, target.day);
    return targetDate.difference(nowDate).inDays;
  }

  String _dateLabel(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}$month$day';
  }
}

class _SectionedRequest {
  final String section;
  final NotificationHubScheduleRequest request;

  const _SectionedRequest({required this.section, required this.request});
}

class _BillMessage {
  final String title;
  final String body;

  const _BillMessage({required this.title, required this.body});
}
