import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:life_manager/data/models/subtask.dart';
import 'package:life_manager/features/habits/data/models/habit.dart';
import 'package:life_manager/features/habits/data/models/habit_completion.dart';
import 'package:life_manager/features/habits/data/repositories/habit_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;

  setUp(() async {
    hiveDir = await Directory.systemTemp.createTemp('habit_repo_phase2_');
    Hive.init(hiveDir.path);
    _registerAdapters();
  });

  tearDown(() async {
    await Hive.close();
    if (await hiveDir.exists()) {
      await hiveDir.delete(recursive: true);
    }
  });

  group('HabitRepository regular completion indexing', () {
    test(
      'rebuilds completion indexes for existing records and reads by date',
      () async {
        final date = DateTime(2026, 2, 10);
        final habitsBox = await Hive.openBox<Habit>(
          HabitRepository.habitsBoxName,
        );
        final completionsBox = await Hive.openBox<HabitCompletion>(
          HabitRepository.completionsBoxName,
        );

        await habitsBox.put(
          'legacy_habit',
          Habit(id: 'legacy_habit', title: 'Legacy Habit'),
        );
        await completionsBox.put(
          'legacy_completion',
          HabitCompletion(
            id: 'legacy_completion',
            habitId: 'legacy_habit',
            completedDate: date,
            count: 1,
          ),
        );

        final repository = _buildRepository();
        final completions = await repository.getCompletionsForDate(
          'legacy_habit',
          date,
        );

        expect(completions.map((c) => c.id), contains('legacy_completion'));

        final dateIndexBox = await Hive.openBox<dynamic>(
          'habit_completions_date_index_v1',
        );
        final habitIndexBox = await Hive.openBox<dynamic>(
          'habit_completions_habit_index_v1',
        );

        final dateIds =
            (dateIndexBox.get('20260210') as List?)?.cast<String>() ??
            const <String>[];
        final habitIds =
            (habitIndexBox.get('legacy_habit') as List?)?.cast<String>() ??
            const <String>[];

        expect(dateIds, contains('legacy_completion'));
        expect(habitIds, contains('legacy_completion'));
      },
    );

    test('rebuilds indexes when index state is corrupted', () async {
      final date = DateTime(2026, 2, 10);
      final habitsBox = await Hive.openBox<Habit>(
        HabitRepository.habitsBoxName,
      );
      final completionsBox = await Hive.openBox<HabitCompletion>(
        HabitRepository.completionsBoxName,
      );

      await habitsBox.put(
        'corrupt_habit',
        Habit(id: 'corrupt_habit', title: 'Corrupt Habit'),
      );
      await completionsBox.put(
        'corrupt_completion',
        HabitCompletion(
          id: 'corrupt_completion',
          habitId: 'corrupt_habit',
          completedDate: date,
          count: 1,
        ),
      );

      final initialRepo = _buildRepository();
      await initialRepo.getCompletionsForDate('corrupt_habit', date);

      final dateIndexBox = await Hive.openBox<dynamic>(
        'habit_completions_date_index_v1',
      );
      await dateIndexBox.delete('20260210');

      final repairedRepo = _buildRepository();
      final repaired = await repairedRepo.getCompletionsForDate(
        'corrupt_habit',
        date,
      );
      expect(repaired.map((c) => c.id), contains('corrupt_completion'));
    });

    test('daily completion summary matches raw recomputation', () async {
      final dateA = DateTime(2026, 2, 10);
      final dateB = DateTime(2026, 2, 11);

      final habit = Habit(id: 'habit_main', title: 'Main Habit');
      final repository = _buildRepository();
      await repository.createHabit(habit);

      final completions = <HabitCompletion>[
        HabitCompletion(
          id: 'c_success',
          habitId: habit.id,
          completedDate: dateA,
          count: 1,
        ),
        HabitCompletion(
          id: 'c_skip',
          habitId: habit.id,
          completedDate: dateA,
          isSkipped: true,
          count: 0,
        ),
        HabitCompletion(
          id: 'c_postpone',
          habitId: habit.id,
          completedDate: dateA,
          isPostponed: true,
          count: 0,
        ),
        HabitCompletion(
          id: 'c_next_day',
          habitId: habit.id,
          completedDate: dateB,
          count: 2,
        ),
      ];

      await repository.addCompletionsBulk(completions);

      final summaryA = await repository.getDailyCompletionSummary(dateA);
      final rawSummaryA = _rawDailySummary(completions, dateA);
      expect(summaryA, rawSummaryA);

      final inRange = await repository.getCompletionsInRange(
        habit.id,
        dateA,
        dateB,
      );
      expect(inRange.map((c) => c.id).toSet(), {
        'c_success',
        'c_skip',
        'c_postpone',
        'c_next_day',
      });
    });
  });
}

HabitRepository _buildRepository() {
  return HabitRepository(
    habitsBoxOpener: () => Hive.openBox<Habit>(HabitRepository.habitsBoxName),
    completionsBoxOpener: () =>
        Hive.openBox<HabitCompletion>(HabitRepository.completionsBoxName),
    dynamicBoxOpener: (boxName) => Hive.openBox<dynamic>(boxName),
  );
}

void _registerAdapters() {
  if (!Hive.isAdapterRegistered(4)) {
    Hive.registerAdapter(SubtaskAdapter());
  }
  if (!Hive.isAdapterRegistered(10)) {
    Hive.registerAdapter(HabitAdapter());
  }
  if (!Hive.isAdapterRegistered(11)) {
    Hive.registerAdapter(HabitCompletionAdapter());
  }
}

Map<String, int> _rawDailySummary(
  Iterable<HabitCompletion> completions,
  DateTime date,
) {
  final summary = <String, int>{
    'entries': 0,
    'successfulEntries': 0,
    'skippedEntries': 0,
    'postponedEntries': 0,
    'totalCount': 0,
  };

  for (final completion in completions.where(
    (c) => _sameDay(c.completedDate, date),
  )) {
    summary['entries'] = (summary['entries'] ?? 0) + 1;
    if (completion.isPostponed) {
      summary['postponedEntries'] = (summary['postponedEntries'] ?? 0) + 1;
    } else if (completion.isSkipped) {
      summary['skippedEntries'] = (summary['skippedEntries'] ?? 0) + 1;
    } else if (completion.count > 0) {
      summary['successfulEntries'] = (summary['successfulEntries'] ?? 0) + 1;
    }
    summary['totalCount'] = (summary['totalCount'] ?? 0) + completion.count;
  }

  return summary;
}

bool _sameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
