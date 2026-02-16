import 'dart:async';

import '../../../../core/data/history_optimization_models.dart';
import '../../../../data/repositories/task_repository.dart';
import '../../../finance/data/repositories/transaction_repository.dart';
import '../../../habits/data/repositories/habit_repository.dart';
import '../../../sleep/data/repositories/sleep_record_repository.dart';

/// Coordinates phased history optimization:
/// - bootstrap window is prepared by each repository during first access
/// - older history is backfilled incrementally in short background sessions
class HistoryOptimizationService {
  HistoryOptimizationService._();

  static final HistoryOptimizationService instance =
      HistoryOptimizationService._();

  final TaskRepository _taskRepository = TaskRepository();
  final HabitRepository _habitRepository = HabitRepository();
  final SleepRecordRepository _sleepRepository = SleepRecordRepository();
  final TransactionRepository _financeRepository = TransactionRepository();

  final StreamController<HistoryOptimizationStatus> _statusController =
      StreamController<HistoryOptimizationStatus>.broadcast();

  bool _sessionRunning = false;

  Stream<HistoryOptimizationStatus> get statusStream =>
      _statusController.stream;

  Future<HistoryOptimizationStatus> getStatus() async {
    final taskStatus = await _taskRepository.getHistoryOptimizationStatus();
    final habitStatus = await _habitRepository.getHistoryOptimizationStatus();
    final sleepStatus = await _sleepRepository.getHistoryOptimizationStatus();
    final financeStatus = await _financeRepository
        .getHistoryOptimizationStatus();
    return HistoryOptimizationStatus(
      modules: <ModuleHistoryOptimizationStatus>[
        taskStatus,
        habitStatus,
        sleepStatus,
        financeStatus,
      ],
    );
  }

  Future<void> refreshStatus() async {
    final status = await getStatus();
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  Future<void> setPaused(bool paused) async {
    await Future.wait<void>(<Future<void>>[
      _taskRepository.setBackfillPaused(paused),
      _habitRepository.setBackfillPaused(paused),
      _sleepRepository.setBackfillPaused(paused),
      _financeRepository.setBackfillPaused(paused),
    ]);
    await refreshStatus();
  }

  Future<void> runSessionBackfill({
    int maxChunksPerSession = 6,
    Duration interChunkDelay = const Duration(milliseconds: 180),
  }) async {
    if (_sessionRunning) return;
    _sessionRunning = true;
    try {
      await refreshStatus();

      var processedChunks = 0;
      while (processedChunks < maxChunksPerSession) {
        var progressed = false;

        if (await _taskRepository.backfillNextChunk()) {
          progressed = true;
          processedChunks++;
          await refreshStatus();
          await Future<void>.delayed(interChunkDelay);
          if (processedChunks >= maxChunksPerSession) break;
        }

        if (await _habitRepository.backfillNextChunk()) {
          progressed = true;
          processedChunks++;
          await refreshStatus();
          await Future<void>.delayed(interChunkDelay);
          if (processedChunks >= maxChunksPerSession) break;
        }

        if (await _sleepRepository.backfillNextChunk()) {
          progressed = true;
          processedChunks++;
          await refreshStatus();
          await Future<void>.delayed(interChunkDelay);
          if (processedChunks >= maxChunksPerSession) break;
        }

        if (await _financeRepository.backfillNextChunk()) {
          progressed = true;
          processedChunks++;
          await refreshStatus();
          await Future<void>.delayed(interChunkDelay);
          if (processedChunks >= maxChunksPerSession) break;
        }

        if (!progressed) {
          break;
        }
      }
    } finally {
      _sessionRunning = false;
      await refreshStatus();
    }
  }

  void dispose() {
    if (!_statusController.isClosed) {
      _statusController.close();
    }
  }
}
