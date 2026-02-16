import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:life_manager/data/models/subtask.dart';
import 'package:life_manager/data/models/task.dart';
import 'package:life_manager/data/repositories/task_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;

  setUp(() async {
    hiveDir = await Directory.systemTemp.createTemp('task_repo_phase2_');
    Hive.init(hiveDir.path);
    _registerAdapters();
  });

  tearDown(() async {
    await Hive.close();
    if (await hiveDir.exists()) {
      await hiveDir.delete(recursive: true);
    }
  });

  group('TaskRepository indexing', () {
    test(
      'rebuilds due-date indexes for existing tasks and reads by date',
      () async {
        final date = DateTime(2026, 2, 10);
        final taskBox = await Hive.openBox<Task>(TaskRepository.boxName);
        await taskBox.put(
          'legacy_task',
          Task(id: 'legacy_task', title: 'Legacy Task', dueDate: date),
        );

        final repository = _buildRepository();
        final tasks = await repository.getTasksForDate(date);

        expect(tasks.map((t) => t.id), contains('legacy_task'));

        final indexBox = await Hive.openBox<dynamic>('task_due_date_index_v1');
        final indexedIds =
            (indexBox.get('20260210') as List?)?.cast<String>() ??
            const <String>[];
        expect(indexedIds, contains('legacy_task'));
      },
    );

    test('rebuilds indexes when index state is corrupted', () async {
      final date = DateTime(2026, 2, 10);
      final taskBox = await Hive.openBox<Task>(TaskRepository.boxName);
      await taskBox.put(
        'corrupt_task',
        Task(id: 'corrupt_task', title: 'Corrupt Task', dueDate: date),
      );

      final initialRepo = _buildRepository();
      await initialRepo.getTasksForDate(date); // Build indexes once.

      final indexBox = await Hive.openBox<dynamic>('task_due_date_index_v1');
      await indexBox.delete('20260210');

      final repairedRepo = _buildRepository();
      final repaired = await repairedRepo.getTasksForDate(date);
      expect(repaired.map((t) => t.id), contains('corrupt_task'));
    });

    test('keeps index and daily summary aligned with task writes', () async {
      final dateA = DateTime(2026, 2, 10);
      final dateB = DateTime(2026, 2, 11);

      final taskA = Task(
        id: 'task_a',
        title: 'Task A',
        dueDate: dateA,
        status: 'pending',
      );
      final taskB = Task(
        id: 'task_b',
        title: 'Task B',
        dueDate: dateA,
        status: 'completed',
      );
      final taskC = Task(
        id: 'task_c',
        title: 'Task C',
        dueDate: dateB,
        status: 'postponed',
      );

      final repository = _buildRepository();
      await repository.createTask(taskA);
      await repository.createTask(taskB);
      await repository.createTask(taskC);

      final tasksForDateA = await repository.getTasksForDate(dateA);
      expect(tasksForDateA.map((t) => t.id).toSet(), {'task_a', 'task_b'});

      final updatedTaskA = taskA.copyWith(dueDate: dateB, status: 'completed');
      await repository.updateTask(updatedTaskA);
      await repository.deleteTask('task_b');

      final updatedDateA = await repository.getTasksForDate(dateA);
      final updatedDateB = await repository.getTasksForDate(dateB);
      expect(updatedDateA, isEmpty);
      expect(updatedDateB.map((t) => t.id).toSet(), {'task_a', 'task_c'});

      final summaryB = await repository.getDailySummary(dateB);
      final allTasks = await repository.getAllTasks();
      final rawSummaryB = _rawDailySummary(allTasks, dateB);
      expect(summaryB, rawSummaryB);

      final stats = await repository.getTaskStatistics();
      final rawStats = _rawTaskStatistics(allTasks);
      expect(stats, rawStats);
    });

    test(
      'bootstrap indexes only recent 30 days and scans older dates safely',
      () async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final recentDate = today.subtract(const Duration(days: 3));
        final oldDate = today.subtract(const Duration(days: 95));

        final taskBox = await Hive.openBox<Task>(TaskRepository.boxName);
        await taskBox.put(
          'recent_task',
          Task(id: 'recent_task', title: 'Recent', dueDate: recentDate),
        );
        await taskBox.put(
          'old_task',
          Task(id: 'old_task', title: 'Old', dueDate: oldDate),
        );

        final repository = _buildRepository();
        final recent = await repository.getTasksForDate(recentDate);
        final old = await repository.getTasksForDate(oldDate);

        expect(recent.map((t) => t.id), contains('recent_task'));
        expect(old.map((t) => t.id), contains('old_task'));

        final indexBox = await Hive.openBox<dynamic>('task_due_date_index_v1');
        final recentIds =
            (indexBox.get(_dateKey(recentDate)) as List?)?.cast<String>() ??
            const <String>[];
        final oldIds =
            (indexBox.get(_dateKey(oldDate)) as List?)?.cast<String>() ??
            const <String>[];

        expect(recentIds, contains('recent_task'));
        expect(oldIds, isEmpty);
      },
    );

    test(
      'backfill resumes from saved meta progress across repository restart',
      () async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final taskBox = await Hive.openBox<Task>(TaskRepository.boxName);
        for (var i = 0; i < 130; i++) {
          final date = today.subtract(Duration(days: i));
          await taskBox.put(
            'task_$i',
            Task(id: 'task_$i', title: 'Task $i', dueDate: date),
          );
        }

        final firstRepo = _buildRepository();
        await firstRepo.getTasksForDate(today);
        final before = await firstRepo.getHistoryOptimizationStatus();
        expect(before.backfillComplete, isFalse);
        expect(before.indexedFromDate, isNotNull);

        final didProcessFirstChunk = await firstRepo.backfillNextChunk(
          chunkDays: 30,
        );
        expect(didProcessFirstChunk, isTrue);
        final afterFirstChunk = await firstRepo.getHistoryOptimizationStatus();
        expect(
          afterFirstChunk.indexedFromDate!.isBefore(before.indexedFromDate!),
          isTrue,
        );

        final restartedRepo = _buildRepository();
        final didProcessSecondChunk = await restartedRepo.backfillNextChunk(
          chunkDays: 30,
        );
        expect(didProcessSecondChunk, isTrue);
        final afterRestartChunk = await restartedRepo
            .getHistoryOptimizationStatus();
        expect(
          afterRestartChunk.indexedFromDate!.isBefore(
            afterFirstChunk.indexedFromDate!,
          ),
          isTrue,
        );
      },
    );

    test(
      'paused backfill skips work and resumes safely after restart',
      () async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final taskBox = await Hive.openBox<Task>(TaskRepository.boxName);
        for (var i = 0; i < 90; i++) {
          final date = today.subtract(Duration(days: i));
          await taskBox.put(
            'pause_task_$i',
            Task(id: 'pause_task_$i', title: 'Pause Task $i', dueDate: date),
          );
        }

        final repo = _buildRepository();
        await repo.getTasksForDate(today);
        final before = await repo.getHistoryOptimizationStatus();
        await repo.setBackfillPaused(true);
        final pausedChunk = await repo.backfillNextChunk(chunkDays: 20);
        final afterPaused = await repo.getHistoryOptimizationStatus();

        expect(pausedChunk, isFalse);
        expect(afterPaused.paused, isTrue);
        expect(afterPaused.indexedFromDate, before.indexedFromDate);

        final restartedRepo = _buildRepository();
        await restartedRepo.setBackfillPaused(false);
        final resumedChunk = await restartedRepo.backfillNextChunk(
          chunkDays: 20,
        );
        expect(resumedChunk, isTrue);
      },
    );
  });
}

TaskRepository _buildRepository() {
  return TaskRepository(
    taskBoxOpener: () => Hive.openBox<Task>(TaskRepository.boxName),
    dynamicBoxOpener: (boxName) => Hive.openBox<dynamic>(boxName),
  );
}

void _registerAdapters() {
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(TaskAdapter());
  }
  if (!Hive.isAdapterRegistered(4)) {
    Hive.registerAdapter(SubtaskAdapter());
  }
}

Map<String, int> _rawDailySummary(Iterable<Task> tasks, DateTime date) {
  final summary = <String, int>{
    'total': 0,
    'pending': 0,
    'completed': 0,
    'postponed': 0,
  };

  for (final task in tasks.where((t) => _sameDay(t.dueDate, date))) {
    summary['total'] = (summary['total'] ?? 0) + 1;
    if (task.status == 'pending') {
      summary['pending'] = (summary['pending'] ?? 0) + 1;
    } else if (task.status == 'completed') {
      summary['completed'] = (summary['completed'] ?? 0) + 1;
    } else if (task.status == 'postponed') {
      summary['postponed'] = (summary['postponed'] ?? 0) + 1;
    }
  }

  return summary;
}

Map<String, int> _rawTaskStatistics(Iterable<Task> tasks) {
  var total = 0;
  var pending = 0;
  var completed = 0;
  var postponed = 0;
  var overdue = 0;

  for (final task in tasks) {
    total++;
    if (task.status == 'pending') pending++;
    if (task.status == 'completed') completed++;
    if (task.status == 'postponed') postponed++;
    if (task.isOverdue) overdue++;
  }

  return {
    'total': total,
    'pending': pending,
    'completed': completed,
    'overdue': overdue,
    'postponed': postponed,
  };
}

bool _sameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _dateKey(DateTime date) {
  final yyyy = date.year.toString().padLeft(4, '0');
  final mm = date.month.toString().padLeft(2, '0');
  final dd = date.day.toString().padLeft(2, '0');
  return '$yyyy$mm$dd';
}
