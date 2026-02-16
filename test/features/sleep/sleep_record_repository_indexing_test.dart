import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:life_manager/features/sleep/data/models/sleep_record.dart';
import 'package:life_manager/features/sleep/data/repositories/sleep_record_repository.dart';
import 'package:life_manager/features/sleep/sleep_module.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;

  setUp(() async {
    hiveDir = await Directory.systemTemp.createTemp('sleep_repo_phase2_');
    Hive.init(hiveDir.path);
    _registerAdapters();
  });

  tearDown(() async {
    await Hive.close();
    if (await hiveDir.exists()) {
      await hiveDir.delete(recursive: true);
    }
  });

  group('SleepRecordRepository indexing', () {
    test(
      'rebuilds date indexes for existing records and reads by date',
      () async {
        final date = DateTime(2026, 2, 10);
        final recordsBox = await Hive.openBox<SleepRecord>(
          SleepModule.sleepRecordsBoxName,
        );

        await recordsBox.put(
          'legacy_sleep',
          SleepRecord(
            id: 'legacy_sleep',
            bedTime: DateTime(2026, 2, 10, 22),
            wakeTime: DateTime(2026, 2, 11, 6),
          ),
        );

        final repository = _buildRepository();
        final records = await repository.getByDate(date);

        expect(records.map((r) => r.id), contains('legacy_sleep'));

        final indexBox = await Hive.openBox<dynamic>(
          'sleep_records_date_index_v1',
        );
        final indexedIds =
            (indexBox.get('20260210') as List?)?.cast<String>() ??
            const <String>[];
        expect(indexedIds, contains('legacy_sleep'));
      },
    );

    test('rebuilds indexes when index state is corrupted', () async {
      final date = DateTime(2026, 2, 10);
      final recordsBox = await Hive.openBox<SleepRecord>(
        SleepModule.sleepRecordsBoxName,
      );
      await recordsBox.put(
        'corrupt_sleep',
        SleepRecord(
          id: 'corrupt_sleep',
          bedTime: DateTime(2026, 2, 10, 22),
          wakeTime: DateTime(2026, 2, 11, 6),
        ),
      );

      final initialRepo = _buildRepository();
      await initialRepo.getByDate(date); // Build indexes once.

      final indexBox = await Hive.openBox<dynamic>(
        'sleep_records_date_index_v1',
      );
      await indexBox.delete('20260210');

      final repairedRepo = _buildRepository();
      final repaired = await repairedRepo.getByDate(date);
      expect(repaired.map((r) => r.id), contains('corrupt_sleep'));
    });

    test(
      'daily summary matches raw recomputation and range queries stay correct',
      () async {
        final dateA = DateTime(2026, 2, 10);
        final dateB = DateTime(2026, 2, 11);

        final recordA = SleepRecord(
          id: 'sleep_a',
          bedTime: DateTime(2026, 2, 10, 22),
          wakeTime: DateTime(2026, 2, 11, 6),
          isNap: false,
        );
        final recordB = SleepRecord(
          id: 'sleep_b',
          bedTime: DateTime(2026, 2, 10, 13),
          wakeTime: DateTime(2026, 2, 10, 13, 30),
          isNap: true,
        );
        final recordC = SleepRecord(
          id: 'sleep_c',
          bedTime: DateTime(2026, 2, 11, 23),
          wakeTime: DateTime(2026, 2, 12, 6),
          isNap: false,
        );

        final repository = _buildRepository();
        await repository.create(recordA);
        await repository.create(recordB);
        await repository.create(recordC);

        final inRange = await repository.getByDateRange(dateA, dateB);
        expect(inRange.map((r) => r.id).toSet(), {
          'sleep_a',
          'sleep_b',
          'sleep_c',
        });

        final summaryA = await repository.getDailySummary(dateA);
        final allRecords = await repository.getAll();
        final rawSummaryA = _rawDailySummary(allRecords, dateA);
        expect(summaryA, rawSummaryA);

        expect(await repository.existsForDate(dateA), isTrue);
        expect(await repository.existsForDate(DateTime(2026, 2, 12)), isFalse);
      },
    );

    test(
      'range reads remain correct when only part of history is indexed',
      () async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final recordsBox = await Hive.openBox<SleepRecord>(
          SleepModule.sleepRecordsBoxName,
        );

        for (var i = 0; i < 75; i++) {
          final date = today.subtract(Duration(days: i));
          await recordsBox.put(
            'mixed_sleep_$i',
            SleepRecord(
              id: 'mixed_sleep_$i',
              bedTime: DateTime(date.year, date.month, date.day, 22),
              wakeTime: DateTime(date.year, date.month, date.day + 1, 6),
              isNap: i % 5 == 0,
            ),
          );
        }

        final repository = _buildRepository();
        // Triggers bootstrap window indexing (recent history only).
        await repository.getByDate(today);

        final status = await repository.getHistoryOptimizationStatus();
        expect(status.backfillComplete, isFalse);
        expect(status.indexedFromDate, isNotNull);

        final rangeStart = today.subtract(const Duration(days: 60));
        final rangeEnd = today.subtract(const Duration(days: 5));
        final records = await repository.getByDateRange(rangeStart, rangeEnd);

        // Inclusive date range [60..5] = 56 days.
        expect(records.length, 56);
        expect(records.map((r) => r.id), contains('mixed_sleep_60'));
        expect(records.map((r) => r.id), contains('mixed_sleep_5'));
      },
    );
  });
}

SleepRecordRepository _buildRepository() {
  return SleepRecordRepository(
    sleepBoxOpener: () =>
        Hive.openBox<SleepRecord>(SleepModule.sleepRecordsBoxName),
    dynamicBoxOpener: (boxName) => Hive.openBox<dynamic>(boxName),
  );
}

void _registerAdapters() {
  if (!Hive.isAdapterRegistered(50)) {
    Hive.registerAdapter(SleepRecordAdapter());
  }
}

Map<String, int> _rawDailySummary(
  Iterable<SleepRecord> records,
  DateTime date,
) {
  final summary = <String, int>{
    'total': 0,
    'mainSleep': 0,
    'nap': 0,
    'totalMinutes': 0,
  };

  for (final record in records.where((r) => _sameDay(r.bedTime, date))) {
    summary['total'] = (summary['total'] ?? 0) + 1;
    if (record.isNap) {
      summary['nap'] = (summary['nap'] ?? 0) + 1;
    } else {
      summary['mainSleep'] = (summary['mainSleep'] ?? 0) + 1;
    }
    summary['totalMinutes'] =
        (summary['totalMinutes'] ?? 0) + (record.totalSleepHours * 60).round();
  }

  return summary;
}

bool _sameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
