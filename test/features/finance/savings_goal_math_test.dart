import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/finance/data/models/savings_goal.dart';

void main() {
  group('SavingsGoal cadence', () {
    test('derives cadence amounts from daily requirement', () {
      final now = DateTime.now();
      final goal = SavingsGoal(
        name: 'Car Fund',
        targetAmount: 3600,
        savedAmount: 0,
        startDate: now,
        targetDate: now.add(const Duration(days: 359)),
      );

      expect(goal.daysRemaining, greaterThan(0));
      expect(goal.requiredPerWeek, closeTo(goal.requiredPerDay * 7, 1e-9));
      expect(
        goal.requiredPerMonth,
        closeTo(goal.requiredPerDay * 30.4375, 1e-9),
      );
      expect(
        goal.requiredPerQuarter,
        closeTo(goal.requiredPerDay * 91.3125, 1e-9),
      );
      expect(
        goal.requiredPerHalfYear,
        closeTo(goal.requiredPerDay * 182.625, 1e-9),
      );
      expect(goal.requiredPerYear, closeTo(goal.requiredPerDay * 365.25, 1e-9));
    });
  });

  group('SavingsGoal contribution history', () {
    test('keeps baseline amount when editing and undoing contribution log', () {
      final now = DateTime.now();
      final goal = SavingsGoal(
        name: 'House Deposit',
        targetAmount: 1000,
        savedAmount: 200,
        startDate: now,
        targetDate: now.add(const Duration(days: 30)),
      );

      final didAdd = goal.addContribution(100);
      expect(didAdd, isTrue);
      expect(goal.savedAmount, closeTo(300, 1e-9));

      final entryId = goal.contributionHistory.first.id;
      final didEdit = goal.updateContribution(
        contributionId: entryId,
        amount: 50,
      );
      expect(didEdit, isTrue);
      expect(goal.savedAmount, closeTo(250, 1e-9));

      final didUndo = goal.undoContribution(entryId);
      expect(didUndo, isTrue);
      expect(goal.savedAmount, closeTo(200, 1e-9));
    });

    test(
      'switches between completed and active based on contribution changes',
      () {
        final now = DateTime.now();
        final goal = SavingsGoal(
          name: 'Laptop',
          targetAmount: 100,
          startDate: now,
          targetDate: now.add(const Duration(days: 10)),
        );

        goal.addContribution(100);
        expect(goal.isCompleted, isTrue);

        final entryId = goal.contributionHistory.first.id;
        goal.updateContribution(contributionId: entryId, amount: 40);
        expect(goal.isActive, isTrue);
        expect(goal.isCompleted, isFalse);
      },
    );
  });
}
