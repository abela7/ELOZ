import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:life_manager/features/mbt/data/models/mood.dart';
import 'package:life_manager/features/mbt/data/models/mood_entry.dart';
import 'package:life_manager/features/mbt/data/repositories/mood_repository.dart';
import 'package:life_manager/features/mbt/mbt_module.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;

  setUp(() async {
    hiveDir = await Directory.systemTemp.createTemp('mbt_mood_repo_');
    Hive.init(hiveDir.path);
    _registerAdapters();
  });

  tearDown(() async {
    await Hive.close();
    if (await hiveDir.exists()) {
      await hiveDir.delete(recursive: true);
    }
  });

  group('MoodRepository indexing', () {
    test('adds multiple entries per day', () async {
      final repository = _buildRepository();
      final moodA = await repository.createMood(
        _buildMood(name: 'Good', polarity: 'good', points: 2),
      );
      final moodB = await repository.createMood(
        _buildMood(name: 'Bad', polarity: 'bad', points: -1),
      );

      final now = DateTime.now();
      final dayMorning = DateTime(now.year, now.month, now.day, 9, 0);
      final dayEvening = DateTime(now.year, now.month, now.day, 20, 0);

      final first = await repository.addMoodEntry(
        loggedAt: dayMorning,
        moodId: moodA.id,
      );
      final second = await repository.addMoodEntry(
        loggedAt: dayEvening,
        moodId: moodB.id,
        customNote: 'Updated later',
      );

      expect(second.id, isNot(first.id));

      final byDate = await repository.getMoodEntryForDate(dayMorning);
      expect(byDate, isNotNull);
      expect(byDate!.moodId, moodB.id);
      expect(byDate.customNote, 'Updated later');

      final dayEntries = await repository.getMoodEntriesForDate(dayMorning);
      expect(dayEntries.length, 2);
      expect(dayEntries[0].id, first.id);
      expect(dayEntries[1].id, second.id);

      final rangeEntries = await repository.getMoodEntriesInRange(
        dayMorning,
        dayMorning,
      );
      expect(rangeEntries.length, 2);

      final indexBox = await Hive.openBox<dynamic>(
        MbtModule.moodEntryDateIndexBoxName,
      );
      final indexedIds = indexBox.get(_dateKey(dayMorning));
      expect(indexedIds, isA<List>());
      expect((indexedIds as List).length, 2);

      final summary = await repository.getDailySummary(dayMorning);
      expect(summary['entryCount'], 2);
      expect(summary['score'], 1); // avg of 2 and -1
      expect(summary['negativeCount'], 1);
      expect(summary['positiveCount'], 1);
    });

    test(
      'bootstraps recent index window and scans older dates safely',
      () async {
        final repository = _buildRepository();
        final mood = await repository.createMood(
          _buildMood(name: 'Steady', polarity: 'good', points: 1),
        );

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final recentDate = today.subtract(const Duration(days: 2));
        final oldDate = today.subtract(const Duration(days: 88));

        final entriesBox = await Hive.openBox<MoodEntry>(
          MbtModule.moodEntriesBoxName,
        );
        await entriesBox.put(
          'recent_entry',
          MoodEntry(
            id: 'recent_entry',
            moodId: mood.id,
            loggedAt: recentDate,
            createdAt: recentDate,
          ),
        );
        await entriesBox.put(
          'old_entry',
          MoodEntry(
            id: 'old_entry',
            moodId: mood.id,
            loggedAt: oldDate,
            createdAt: oldDate,
          ),
        );

        final recent = await repository.getMoodEntryForDate(recentDate);
        final old = await repository.getMoodEntryForDate(oldDate);

        expect(recent?.id, 'recent_entry');
        expect(old?.id, 'old_entry');

        final indexBox = await Hive.openBox<dynamic>(
          MbtModule.moodEntryDateIndexBoxName,
        );
        final recentIndexed = indexBox.get(_dateKey(recentDate));
        expect(recentIndexed, isA<List>());
        expect((recentIndexed as List), contains('recent_entry'));
        expect(indexBox.get(_dateKey(oldDate)), isNull);

        final status = await repository.getHistoryOptimizationStatus();
        expect(status.usingScanFallback, isFalse);
        expect(status.backfillComplete, isFalse);
      },
    );

    test(
      'backfill resumes from saved progress across repository restart',
      () async {
        final repository = _buildRepository();
        final mood = await repository.createMood(
          _buildMood(name: 'Backfill', polarity: 'good', points: 1),
        );

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final entriesBox = await Hive.openBox<MoodEntry>(
          MbtModule.moodEntriesBoxName,
        );
        for (var i = 0; i < 140; i++) {
          final day = today.subtract(Duration(days: i));
          await entriesBox.put(
            'entry_$i',
            MoodEntry(
              id: 'entry_$i',
              moodId: mood.id,
              loggedAt: day,
              createdAt: day,
            ),
          );
        }

        await repository.getMoodEntryForDate(today);
        final before = await repository.getHistoryOptimizationStatus();
        expect(before.backfillComplete, isFalse);
        expect(before.indexedFromDate, isNotNull);

        final didFirstChunk = await repository.backfillNextChunk(chunkDays: 30);
        expect(didFirstChunk, isTrue);
        final afterFirstChunk = await repository.getHistoryOptimizationStatus();
        expect(
          afterFirstChunk.indexedFromDate!.isBefore(before.indexedFromDate!),
          isTrue,
        );

        final restarted = _buildRepository();
        final didSecondChunk = await restarted.backfillNextChunk(chunkDays: 30);
        expect(didSecondChunk, isTrue);
        final afterRestartChunk = await restarted
            .getHistoryOptimizationStatus();
        expect(
          afterRestartChunk.indexedFromDate!.isBefore(
            afterFirstChunk.indexedFromDate!,
          ),
          isTrue,
        );
      },
    );

    test('soft delete removes day index entry and clears summary', () async {
      final repository = _buildRepository();
      final mood = await repository.createMood(
        _buildMood(name: 'Delete Check', polarity: 'good', points: 3),
      );
      final day = DateTime(2026, 2, 20, 10, 0);

      final entry = await repository.addMoodEntry(
        loggedAt: day,
        moodId: mood.id,
      );

      final indexBox = await Hive.openBox<dynamic>(
        MbtModule.moodEntryDateIndexBoxName,
      );
      final indexed = indexBox.get(_dateKey(day));
      expect(indexed, isA<List>());
      expect((indexed as List), contains(entry.id));

      final deleted = await repository.softDeleteMoodEntry(entry.id);
      expect(deleted, isTrue);

      expect(indexBox.get(_dateKey(day)), isNull);

      final summary = await repository.getDailySummary(day);
      expect(summary['entryCount'], 0);
      expect(summary['score'], 0);
      expect(summary['positiveCount'], 0);
      expect(summary['negativeCount'], 0);
      expect(summary['moodId'], '');
      expect(summary['reasonId'], '');

      final byDate = await repository.getMoodEntryForDate(day);
      expect(byDate, isNull);
    });

    test(
      'indexes multiple entries per day during bootstrap',
      () async {
        final repository = _buildRepository();
        final mood = await repository.createMood(
          _buildMood(name: 'Multi Entry', polarity: 'good', points: 2),
        );
        final day = DateTime(2026, 6, 9);

        final entriesBox = await Hive.openBox<MoodEntry>(
          MbtModule.moodEntriesBoxName,
        );
        await entriesBox.put(
          'dup_a',
          MoodEntry(
            id: 'dup_a',
            moodId: mood.id,
            loggedAt: DateTime(day.year, day.month, day.day, 9, 0),
            createdAt: DateTime(day.year, day.month, day.day, 9, 0),
          ),
        );
        await entriesBox.put(
          'dup_b',
          MoodEntry(
            id: 'dup_b',
            moodId: mood.id,
            loggedAt: DateTime(day.year, day.month, day.day, 20, 0),
            createdAt: DateTime(day.year, day.month, day.day, 20, 0),
          ),
        );

        final latest = await repository.getMoodEntryForDate(day);
        expect(latest, isNotNull);
        expect(latest!.id, 'dup_b');

        final dayEntries = await repository.getMoodEntriesForDate(day);
        expect(dayEntries.length, 2);
        expect(dayEntries[0].id, 'dup_a');
        expect(dayEntries[1].id, 'dup_b');

        final indexBox = await Hive.openBox<dynamic>(
          MbtModule.moodEntryDateIndexBoxName,
        );
        final indexed = indexBox.get(_dateKey(day));
        expect(indexed, isA<List>());
        expect((indexed as List).length, 2);
        expect((indexed as List), contains('dup_a'));
        expect((indexed as List), contains('dup_b'));
      },
    );

    test(
      'keeps entry/index/summary consistent when backfill overlaps with live add',
      () async {
        final repository = _buildRepository();
        final mood = await repository.createMood(
          _buildMood(name: 'Overlap Safe', polarity: 'good', points: 1),
        );

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final entriesBox = await Hive.openBox<MoodEntry>(
          MbtModule.moodEntriesBoxName,
        );
        for (var i = 0; i < 180; i++) {
          final day = today.subtract(Duration(days: i));
          await entriesBox.put(
            'hist_$i',
            MoodEntry(
              id: 'hist_$i',
              moodId: mood.id,
              loggedAt: DateTime(day.year, day.month, day.day, 8, 0),
              createdAt: DateTime(day.year, day.month, day.day, 8, 0),
            ),
          );
        }

        // Build initial bootstrap window so a large chunk remains for backfill.
        await repository.getMoodEntryForDate(today);
        final targetDay = today.subtract(const Duration(days: 75));

        final backfillFuture = repository.backfillNextChunk(chunkDays: 120);
        final readDuringBackfill = repository.getMoodEntriesInRange(
          targetDay,
          targetDay,
        );
        final addFuture = repository.addMoodEntry(
          loggedAt: DateTime(
            targetDay.year,
            targetDay.month,
            targetDay.day,
            21,
          ),
          moodId: mood.id,
          customNote: 'live update',
        );

        final didBackfill = await backfillFuture;
        final rangeEntries = await readDuringBackfill;
        final added = await addFuture;

        expect(didBackfill, isTrue);
        expect(rangeEntries, isNotEmpty);

        final byDate = await repository.getMoodEntryForDate(targetDay);
        expect(byDate, isNotNull);
        expect(byDate!.id, added.id);
        expect(byDate.customNote, 'live update');

        final indexBox = await Hive.openBox<dynamic>(
          MbtModule.moodEntryDateIndexBoxName,
        );
        final indexed = indexBox.get(_dateKey(targetDay));
        expect(indexed, isA<List>());
        expect((indexed as List), contains(added.id));

        final summary = await repository.getDailySummary(targetDay);
        expect(summary['entryCount'], 2); // hist_75 + added
        expect(summary['moodId'], mood.id);
      },
    );
  });
}

MoodRepository _buildRepository() {
  return MoodRepository(
    moodsBoxOpener: () => Hive.openBox<Mood>(MbtModule.moodsBoxName),
    entriesBoxOpener: () =>
        Hive.openBox<MoodEntry>(MbtModule.moodEntriesBoxName),
    dynamicBoxOpener: (boxName) => Hive.openBox<dynamic>(boxName),
  );
}

void _registerAdapters() {
  if (!Hive.isAdapterRegistered(60)) {
    Hive.registerAdapter(MoodAdapter());
  }
  if (!Hive.isAdapterRegistered(62)) {
    Hive.registerAdapter(MoodEntryAdapter());
  }
}

Mood _buildMood({
  required String name,
  required String polarity,
  required int points,
}) {
  return Mood(
    name: name,
    iconCodePoint: Icons.mood_rounded.codePoint,
    iconFontFamily: 'MaterialIcons',
    colorValue: const Color(0xFF1976D2).toARGB32(),
    pointValue: points,
    reasonRequired: false,
    polarity: polarity,
  );
}

String _dateKey(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  final yyyy = day.year.toString().padLeft(4, '0');
  final mm = day.month.toString().padLeft(2, '0');
  final dd = day.day.toString().padLeft(2, '0');
  return '$yyyy$mm$dd';
}
