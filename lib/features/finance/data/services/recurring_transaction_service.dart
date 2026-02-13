import '../models/transaction.dart';
import '../repositories/transaction_repository.dart';
import 'transaction_balance_service.dart';
import '../../../../core/models/recurrence_rule.dart';
import '../../../../core/services/recurrence_engine.dart';

/// Service responsible for automatically spawning instances of recurring transactions
class RecurringTransactionService {
  final TransactionRepository _transactionRepository;
  final TransactionBalanceService _balanceService;

  RecurringTransactionService(
    this._transactionRepository,
    this._balanceService,
  );

  /// Scans all transactions for recurring patterns and creates missing instances up to today
  /// Returns the number of new instances spawned
  Future<int> processRecurringTransactions() async {
    final allTransactions = await _transactionRepository.getAllTransactions();
    int spawnedCount = 0;
    int dateKey(DateTime date) =>
        (date.year * 10000) + (date.month * 100) + date.day;

    // Filter for transactions that are part of a recurring group
    final recurringTransactions = allTransactions
        .where(
          (t) =>
              t.isRecurring &&
              t.recurrenceRule != null &&
              t.recurringGroupId != null,
        )
        .toList();

    if (recurringTransactions.isEmpty) return 0;

    // Group by recurringGroupId to handle each schedule once
    final Map<String, Transaction> uniqueMasters = {};
    for (final t in recurringTransactions) {
      if (!uniqueMasters.containsKey(t.recurringGroupId)) {
        uniqueMasters[t.recurringGroupId!] = t;
      } else {
        // We use the earliest transaction in the group as the anchor for the recurrence engine
        if (t.transactionDate.isBefore(
          uniqueMasters[t.recurringGroupId!]!.transactionDate,
        )) {
          uniqueMasters[t.recurringGroupId!] = t;
        }
      }
    }

    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    for (final master in uniqueMasters.values) {
      try {
        final rule = RecurrenceRule.fromJson(master.recurrenceRule!);

        // Find all existing instances in this group to avoid duplicates
        final groupInstances = allTransactions
            .where((t) => t.recurringGroupId == master.recurringGroupId)
            .toList();
        final existingDates = <int>{};
        for (final instance in groupInstances) {
          existingDates.add(dateKey(instance.transactionDate));
        }

        // Generate potential occurrences from the master's start date
        // The engine includes the start date itself if it matches the rule
        final occurrences = RecurrenceEngine.generateNextOccurrences(
          rule,
          master.transactionDate,
          maxOccurrences: 500, // Reasonable safety limit for a single scan
        );

        for (final occurrenceDate in occurrences) {
          final normalizedOccurrence = DateTime(
            occurrenceDate.year,
            occurrenceDate.month,
            occurrenceDate.day,
          );

          // Don't spawn future transactions automatically
          if (normalizedOccurrence.isAfter(today)) continue;

          final occurrenceKey = dateKey(normalizedOccurrence);

          if (!existingDates.contains(occurrenceKey)) {
            // Create the auto-spawned transaction instance
            final newInstance = Transaction(
              title: master.title,
              amount: master.amount,
              type: master.type,
              categoryId: master.categoryId,
              accountId: master.accountId,
              toAccountId: master.toAccountId,
              transactionDate: normalizedOccurrence,
              transactionTime: master.transactionTime,
              description: master.description,
              isRecurring: true,
              recurrenceRule: master.recurrenceRule,
              recurringGroupId: master.recurringGroupId,
              currency: master.currency,
            );

            // 1. Apply financial impact to account balance
            await _balanceService.applyTransactionImpact(newInstance);

            // 2. Save the transaction to the database
            await _transactionRepository.createTransaction(newInstance);

            // Track to prevent duplicate spawns in this run
            existingDates.add(occurrenceKey);
            spawnedCount++;
          }
        }
        // Yield to UI to avoid long blocking work.
        await Future<void>.delayed(Duration.zero);
      } catch (e) {
        // Log error but continue processing other groups
        print(
          'Error processing recurring transaction group ${master.recurringGroupId}: $e',
        );
      }
    }

    return spawnedCount;
  }
}
