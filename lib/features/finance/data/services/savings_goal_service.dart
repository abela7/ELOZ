import '../models/savings_goal.dart';
import '../repositories/savings_goal_repository.dart';

class SavingsGoalService {
  final SavingsGoalRepository _repository;

  SavingsGoalService(this._repository);

  Future<List<SavingsGoal>> getAllGoals() => _repository.getAllGoals();

  Future<List<SavingsGoal>> getActiveGoals() => _repository.getActiveGoals();

  Future<List<SavingsGoal>> getArchivedGoals() =>
      _repository.getArchivedGoals();

  Future<Map<String, dynamic>> getSummary() => _repository.getSummary();

  Map<String, double> buildCadencePlan(SavingsGoal goal) {
    return {
      'day': goal.requiredPerDay,
      'week': goal.requiredPerWeek,
      'month': goal.requiredPerMonth,
      'quarter': goal.requiredPerQuarter,
      'halfYear': goal.requiredPerHalfYear,
      'year': goal.requiredPerYear,
    };
  }

  Map<String, dynamic> getPerformanceSnapshot(SavingsGoal goal) {
    final totalDays = goal.totalDays;
    final elapsedDays = goal.elapsedDays;
    final expectedProgress = totalDays <= 0 ? 0 : (elapsedDays / totalDays);
    final expectedSaved = goal.targetAmount * expectedProgress.clamp(0.0, 1.0);
    final delta = goal.savedAmount - expectedSaved;
    return {
      'expectedSaved': expectedSaved,
      'delta': delta,
      'isOnTrack': delta >= -0.01,
      'expectedProgress': expectedProgress,
    };
  }
}
