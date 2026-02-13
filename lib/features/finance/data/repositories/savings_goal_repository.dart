import 'package:hive_flutter/hive_flutter.dart';

import '../../../../data/local/hive/hive_service.dart';
import '../models/savings_goal.dart';

class SavingsGoalRepository {
  static const String boxName = 'savingsGoalsBox';

  Box<SavingsGoal>? _cachedBox;

  Future<Box<SavingsGoal>> _getBox() async {
    if (_cachedBox != null && _cachedBox!.isOpen) {
      return _cachedBox!;
    }
    _cachedBox = await HiveService.getBox<SavingsGoal>(boxName);
    return _cachedBox!;
  }

  Future<void> createGoal(SavingsGoal goal) async {
    final box = await _getBox();
    await box.put(goal.id, goal);
  }

  Future<List<SavingsGoal>> getAllGoals() async {
    final box = await _getBox();
    return box.values.toList();
  }

  Future<SavingsGoal?> getGoalById(String id) async {
    final box = await _getBox();
    return box.get(id);
  }

  Future<void> updateGoal(SavingsGoal goal) async {
    final box = await _getBox();
    goal.updatedAt = DateTime.now();
    await box.put(goal.id, goal);
    if (goal.isInBox) {
      await goal.save();
    }
  }

  Future<void> deleteGoal(String id) async {
    final box = await _getBox();
    await box.delete(id);
  }

  Future<List<SavingsGoal>> getActiveGoals() async {
    final goals = await getAllGoals();
    return goals.where((goal) => goal.isActive || goal.isCompleted).toList();
  }

  Future<List<SavingsGoal>> getArchivedGoals() async {
    final goals = await getAllGoals();
    return goals.where((goal) => goal.isArchived).toList();
  }

  Future<List<SavingsGoal>> getGoalsByAccount(String accountId) async {
    final goals = await getAllGoals();
    return goals.where((goal) => goal.accountId == accountId).toList();
  }

  Future<void> addContribution({
    required String goalId,
    required double amount,
    DateTime? contributedAt,
    String? note,
  }) async {
    final goal = await getGoalById(goalId);
    if (goal == null) return;

    final applied = goal.addContribution(
      amount,
      contributedAt: contributedAt,
      note: note,
    );
    if (!applied) return;

    await updateGoal(goal);
  }

  Future<bool> undoContribution({
    required String goalId,
    required String contributionId,
  }) async {
    final goal = await getGoalById(goalId);
    if (goal == null) return false;

    final didUndo = goal.undoContribution(contributionId);
    if (!didUndo) return false;

    await updateGoal(goal);
    return true;
  }

  Future<bool> updateContribution({
    required String goalId,
    required String contributionId,
    required double amount,
    DateTime? contributedAt,
    String? note,
  }) async {
    final goal = await getGoalById(goalId);
    if (goal == null) return false;

    final didUpdate = goal.updateContribution(
      contributionId: contributionId,
      amount: amount,
      contributedAt: contributedAt,
      note: note,
    );
    if (!didUpdate) return false;

    await updateGoal(goal);
    return true;
  }

  Future<void> markGoalFailed(String goalId, {String? reason}) async {
    final goal = await getGoalById(goalId);
    if (goal == null) return;
    goal.markFailed(reason: reason);
    await updateGoal(goal);
  }

  Future<void> closeGoal(String goalId, {String? reason}) async {
    final goal = await getGoalById(goalId);
    if (goal == null) return;
    goal.closeGoal(reason: reason);
    await updateGoal(goal);
  }

  Future<void> reopenGoal(String goalId) async {
    final goal = await getGoalById(goalId);
    if (goal == null) return;
    goal.reopenGoal();
    await updateGoal(goal);
  }

  Future<void> deleteAllGoals() async {
    final box = await _getBox();
    await box.clear();
  }

  Future<Map<String, dynamic>> getSummary() async {
    final goals = await getAllGoals();

    final active = goals.where((goal) => goal.isActive).toList();
    final completed = goals.where((goal) => goal.isCompleted).toList();
    final failed = goals.where((goal) => goal.isFailed).toList();
    final closed = goals.where((goal) => goal.isClosed).toList();

    final targetByCurrency = <String, double>{};
    final savedByCurrency = <String, double>{};
    final remainingByCurrency = <String, double>{};

    for (final goal in goals) {
      targetByCurrency[goal.currency] =
          (targetByCurrency[goal.currency] ?? 0) + goal.targetAmount;
      savedByCurrency[goal.currency] =
          (savedByCurrency[goal.currency] ?? 0) + goal.savedAmount;
      remainingByCurrency[goal.currency] =
          (remainingByCurrency[goal.currency] ?? 0) + goal.remainingAmount;
    }

    return {
      'totalGoals': goals.length,
      'activeGoals': active.length,
      'completedGoals': completed.length,
      'failedGoals': failed.length,
      'closedGoals': closed.length,
      'targetByCurrency': targetByCurrency,
      'savedByCurrency': savedByCurrency,
      'remainingByCurrency': remainingByCurrency,
    };
  }
}
