import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:life_manager/features/mbt/data/models/mood.dart';
import 'package:life_manager/features/mbt/data/models/mood_entry.dart';
import 'package:life_manager/features/mbt/data/models/mood_reason.dart';
import 'package:life_manager/features/mbt/data/repositories/mood_repository.dart';
import 'package:life_manager/features/mbt/data/services/mood_api_service.dart';
import 'package:life_manager/features/mbt/mbt_module.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;
  late MoodApiService api;

  setUp(() async {
    hiveDir = await Directory.systemTemp.createTemp('mbt_mood_api_');
    Hive.init(hiveDir.path);
    _registerAdapters();

    final repository = MoodRepository(
      moodsBoxOpener: () => Hive.openBox<Mood>(MbtModule.moodsBoxName),
      reasonsBoxOpener: () =>
          Hive.openBox<MoodReason>(MbtModule.moodReasonsBoxName),
      entriesBoxOpener: () =>
          Hive.openBox<MoodEntry>(MbtModule.moodEntriesBoxName),
      dynamicBoxOpener: (boxName) => Hive.openBox<dynamic>(boxName),
    );
    api = MoodApiService(repository: repository);
  });

  tearDown(() async {
    await Hive.close();
    if (await hiveDir.exists()) {
      await hiveDir.delete(recursive: true);
    }
  });

  group('MoodApiService', () {
    test('enforces reasonRequired and polarity matching', () async {
      final goodMood = await api.postMood(
        name: 'Calm',
        iconCodePoint: Icons.sentiment_satisfied_rounded.codePoint,
        iconFontFamily: 'MaterialIcons',
        colorValue: const Color(0xFF2E7D32).toARGB32(),
        pointValue: 3,
        reasonRequired: true,
        polarity: 'good',
      );

      final goodReason = await api.postReason(name: 'Good sleep', type: 'good');
      final badReason = await api.postReason(name: 'Stress', type: 'bad');

      await expectLater(
        () => api.postMoodEntry(moodId: goodMood.id),
        throwsA(isA<FormatException>()),
      );

      await expectLater(
        () => api.postMoodEntry(moodId: goodMood.id, reasonId: badReason.id),
        throwsA(isA<FormatException>()),
      );

      final entry = await api.postMoodEntry(
        moodId: goodMood.id,
        reasonId: goodReason.id,
      );
      expect(entry.reasonId, goodReason.id);
    });

    test('enforces one-primary-entry-per-day as upsert', () async {
      final moodA = await api.postMood(
        name: 'Focused',
        iconCodePoint: Icons.psychology_alt_rounded.codePoint,
        iconFontFamily: 'MaterialIcons',
        colorValue: const Color(0xFF1976D2).toARGB32(),
        pointValue: 2,
        reasonRequired: false,
        polarity: 'good',
      );
      final moodB = await api.postMood(
        name: 'Tired',
        iconCodePoint: Icons.sentiment_dissatisfied_rounded.codePoint,
        iconFontFamily: 'MaterialIcons',
        colorValue: const Color(0xFFD32F2F).toARGB32(),
        pointValue: -2,
        reasonRequired: false,
        polarity: 'bad',
      );

      final date = DateTime(2026, 2, 17);
      final first = await api.postMoodEntry(
        moodId: moodA.id,
        loggedAt: DateTime(date.year, date.month, date.day, 9, 0),
      );
      final second = await api.postMoodEntry(
        moodId: moodB.id,
        loggedAt: DateTime(date.year, date.month, date.day, 21, 0),
      );

      expect(second.id, first.id);

      final byDate = await api.getMoodEntryByDate(date);
      expect(byDate, isNotNull);
      expect(byDate!.moodId, moodB.id);

      final range = await api.getMoodEntriesByRange(
        range: MoodRange.custom,
        from: date,
        to: date,
      );
      expect(range.length, 1);
      expect(range.first.id, first.id);
    });

    test('keeps entries readable when reason is deleted', () async {
      final mood = await api.postMood(
        name: 'Neutral',
        iconCodePoint: Icons.sentiment_neutral_rounded.codePoint,
        iconFontFamily: 'MaterialIcons',
        colorValue: const Color(0xFF6A1B9A).toARGB32(),
        pointValue: 0,
        reasonRequired: false,
        polarity: 'good',
      );
      final reason = await api.postReason(name: 'Routine', type: 'good');
      final day = DateTime(2026, 3, 2);

      await api.postMoodEntry(
        moodId: mood.id,
        reasonId: reason.id,
        loggedAt: day,
      );
      await api.deleteReason(reason.id);

      final entry = await api.getMoodEntryByDate(day);
      expect(entry, isNotNull);
      expect(entry!.reasonId, reason.id);

      final summary = await api.getMoodSummary(
        range: MoodRange.custom,
        from: day,
        to: day,
      );
      expect(summary.entriesCount, 1);
      expect(summary.mostFrequentReasonName, isNull);
    });

    test(
      'soft-deleted mood/reason stay readable for old entries and are blocked for new logs',
      () async {
        final moodA = await api.postMood(
          name: 'Trackable',
          iconCodePoint: Icons.mood_rounded.codePoint,
          iconFontFamily: 'MaterialIcons',
          colorValue: const Color(0xFF00897B).toARGB32(),
          pointValue: 1,
          reasonRequired: false,
          polarity: 'good',
        );
        final reasonA = await api.postReason(name: 'Routine', type: 'good');

        final day = DateTime(2026, 5, 7);
        await api.postMoodEntry(
          moodId: moodA.id,
          reasonId: reasonA.id,
          loggedAt: day,
        );

        await api.deleteMood(moodA.id);
        await api.deleteReason(reasonA.id);

        final oldEntry = await api.getMoodEntryByDate(day);
        expect(oldEntry, isNotNull);
        expect(oldEntry!.moodId, moodA.id);
        expect(oldEntry.reasonId, reasonA.id);

        final oldSummary = await api.getMoodSummary(
          range: MoodRange.custom,
          from: day,
          to: day,
        );
        expect(oldSummary.entriesCount, 1);
        expect(oldSummary.mostFrequentMoodName, isNull);
        expect(oldSummary.mostFrequentReasonName, isNull);

        await expectLater(
          () => api.postMoodEntry(
            moodId: moodA.id,
            loggedAt: DateTime(2026, 5, 8),
          ),
          throwsA(isA<StateError>()),
        );

        final moodB = await api.postMood(
          name: 'Second',
          iconCodePoint: Icons.sentiment_satisfied_rounded.codePoint,
          iconFontFamily: 'MaterialIcons',
          colorValue: const Color(0xFF43A047).toARGB32(),
          pointValue: 2,
          reasonRequired: false,
          polarity: 'good',
        );
        await expectLater(
          () => api.postMoodEntry(
            moodId: moodB.id,
            reasonId: reasonA.id,
            loggedAt: DateTime(2026, 5, 8),
          ),
          throwsA(isA<StateError>()),
        );
      },
    );

    test('returns summary and trends for custom range', () async {
      final goodMood = await api.postMood(
        name: 'Great',
        iconCodePoint: Icons.sentiment_very_satisfied_rounded.codePoint,
        iconFontFamily: 'MaterialIcons',
        colorValue: const Color(0xFF2E7D32).toARGB32(),
        pointValue: 4,
        reasonRequired: false,
        polarity: 'good',
      );
      final badMood = await api.postMood(
        name: 'Low',
        iconCodePoint: Icons.sentiment_very_dissatisfied_rounded.codePoint,
        iconFontFamily: 'MaterialIcons',
        colorValue: const Color(0xFFD32F2F).toARGB32(),
        pointValue: -3,
        reasonRequired: false,
        polarity: 'bad',
      );

      final from = DateTime(2026, 4, 1);
      final day2 = DateTime(2026, 4, 2);
      final day3 = DateTime(2026, 4, 3);

      await api.postMoodEntry(moodId: goodMood.id, loggedAt: from);
      await api.postMoodEntry(moodId: badMood.id, loggedAt: day2);
      await api.postMoodEntry(moodId: goodMood.id, loggedAt: day3);

      final summary = await api.getMoodSummary(
        range: MoodRange.custom,
        from: from,
        to: day3,
      );
      final trends = await api.getMoodTrends(
        range: MoodRange.custom,
        from: from,
        to: day3,
      );

      expect(summary.entriesCount, 3);
      expect(summary.mostFrequentMoodName, 'Great');
      expect(summary.positivePercent, closeTo(66.6, 0.6));
      expect(summary.negativePercent, closeTo(33.3, 0.6));

      expect(trends.dayScoreMap.length, 3);
      expect(trends.dayScoreMap['20260401'], 4);
      expect(trends.dayScoreMap['20260402'], -3);
      expect(trends.dayScoreMap['20260403'], 4);
    });

    test('weekly/monthly summary parity matches raw recomputation', () async {
      final goodMood = await api.postMood(
        name: 'Parity Good',
        iconCodePoint: Icons.sentiment_very_satisfied_rounded.codePoint,
        iconFontFamily: 'MaterialIcons',
        colorValue: const Color(0xFF2E7D32).toARGB32(),
        pointValue: 3,
        reasonRequired: false,
        polarity: 'good',
      );
      final badMood = await api.postMood(
        name: 'Parity Bad',
        iconCodePoint: Icons.sentiment_dissatisfied_rounded.codePoint,
        iconFontFamily: 'MaterialIcons',
        colorValue: const Color(0xFFD32F2F).toARGB32(),
        pointValue: -2,
        reasonRequired: false,
        polarity: 'bad',
      );
      final goodReason = await api.postReason(name: 'Productive', type: 'good');
      final badReason = await api.postReason(name: 'Stress', type: 'bad');

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final d1 = today;
      final d2 = today.subtract(const Duration(days: 1));
      final d3 = today.subtract(const Duration(days: 2));
      final d4 = today.subtract(const Duration(days: 4));

      await api.postMoodEntry(
        moodId: goodMood.id,
        reasonId: goodReason.id,
        loggedAt: d1,
      );
      await api.postMoodEntry(
        moodId: badMood.id,
        reasonId: badReason.id,
        loggedAt: d2,
      );
      await api.postMoodEntry(
        moodId: goodMood.id,
        reasonId: goodReason.id,
        loggedAt: d3,
      );
      await api.postMoodEntry(
        moodId: goodMood.id,
        reasonId: goodReason.id,
        loggedAt: d4,
      );

      // If possible, add one entry outside weekly but still in monthly range.
      if (today.day >= 8) {
        final outsideWeekly = today.subtract(const Duration(days: 7));
        await api.postMoodEntry(
          moodId: badMood.id,
          reasonId: badReason.id,
          loggedAt: outsideWeekly,
        );
      }

      final weeklySummary = await api.getMoodSummary(range: MoodRange.weekly);
      final monthlySummary = await api.getMoodSummary(range: MoodRange.monthly);

      final weeklyEntries = await api.getMoodEntriesByRange(
        range: MoodRange.weekly,
      );
      final monthlyEntries = await api.getMoodEntriesByRange(
        range: MoodRange.monthly,
      );

      final moodPoints = <String, int>{
        goodMood.id: goodMood.pointValue,
        badMood.id: badMood.pointValue,
      };
      final moodPolarity = <String, String>{
        goodMood.id: goodMood.polarity,
        badMood.id: badMood.polarity,
      };
      final moodNames = <String, String>{
        goodMood.id: goodMood.name,
        badMood.id: badMood.name,
      };
      final reasonNames = <String, String>{
        goodReason.id: goodReason.name,
        badReason.id: badReason.name,
      };

      final weeklyRaw = _rawStats(
        weeklyEntries,
        moodPoints: moodPoints,
        moodPolarity: moodPolarity,
      );
      final monthlyRaw = _rawStats(
        monthlyEntries,
        moodPoints: moodPoints,
        moodPolarity: moodPolarity,
      );
      final weeklyTopMood = _topKey(weeklyRaw.moodFrequency);
      final weeklyTopReason = _topKey(weeklyRaw.reasonFrequency);
      final monthlyTopMood = _topKey(monthlyRaw.moodFrequency);
      final monthlyTopReason = _topKey(monthlyRaw.reasonFrequency);

      expect(weeklySummary.entriesCount, weeklyEntries.length);
      expect(
        weeklySummary.dailyScore,
        moodPoints[weeklyEntries.last.moodId] ?? 0,
      );
      expect(
        weeklySummary.weeklyAverage,
        closeTo(weeklyRaw.averageScore, 0.0001),
      );
      expect(
        weeklySummary.positivePercent,
        closeTo(weeklyRaw.positivePercent, 0.0001),
      );
      expect(
        weeklySummary.negativePercent,
        closeTo(weeklyRaw.negativePercent, 0.0001),
      );
      expect(weeklySummary.mostFrequentMoodId, weeklyTopMood);
      expect(
        weeklySummary.mostFrequentMoodName,
        weeklyTopMood == null ? null : moodNames[weeklyTopMood],
      );
      expect(weeklySummary.mostFrequentReasonId, weeklyTopReason);
      expect(
        weeklySummary.mostFrequentReasonName,
        weeklyTopReason == null ? null : reasonNames[weeklyTopReason],
      );

      expect(monthlySummary.entriesCount, monthlyEntries.length);
      expect(
        monthlySummary.monthlyAverage,
        closeTo(monthlyRaw.averageScore, 0.0001),
      );
      expect(
        monthlySummary.positivePercent,
        closeTo(monthlyRaw.positivePercent, 0.0001),
      );
      expect(
        monthlySummary.negativePercent,
        closeTo(monthlyRaw.negativePercent, 0.0001),
      );
      expect(monthlySummary.mostFrequentMoodId, monthlyTopMood);
      expect(
        monthlySummary.mostFrequentMoodName,
        monthlyTopMood == null ? null : moodNames[monthlyTopMood],
      );
      expect(monthlySummary.mostFrequentReasonId, monthlyTopReason);
      expect(
        monthlySummary.mostFrequentReasonName,
        monthlyTopReason == null ? null : reasonNames[monthlyTopReason],
      );
    });
  });
}

_RawStats _rawStats(
  List<MoodEntry> entries, {
  required Map<String, int> moodPoints,
  required Map<String, String> moodPolarity,
}) {
  var scoreTotal = 0;
  var positive = 0;
  var negative = 0;
  final moodFrequency = <String, int>{};
  final reasonFrequency = <String, int>{};

  for (final entry in entries) {
    final points = moodPoints[entry.moodId] ?? 0;
    final polarity = moodPolarity[entry.moodId] ?? '';
    scoreTotal += points;
    if (polarity == 'good') {
      positive++;
    } else if (polarity == 'bad') {
      negative++;
    }
    moodFrequency[entry.moodId] = (moodFrequency[entry.moodId] ?? 0) + 1;
    if ((entry.reasonId ?? '').isNotEmpty) {
      final reasonId = entry.reasonId!;
      reasonFrequency[reasonId] = (reasonFrequency[reasonId] ?? 0) + 1;
    }
  }

  final totalPolarity = positive + negative;
  final averageScore = entries.isEmpty ? 0.0 : scoreTotal / entries.length;

  return _RawStats(
    averageScore: averageScore,
    positivePercent: totalPolarity == 0 ? 0 : (positive / totalPolarity) * 100,
    negativePercent: totalPolarity == 0 ? 0 : (negative / totalPolarity) * 100,
    moodFrequency: moodFrequency,
    reasonFrequency: reasonFrequency,
  );
}

String? _topKey(Map<String, int> frequency) {
  String? top;
  var max = 0;
  for (final entry in frequency.entries) {
    if (entry.value > max) {
      max = entry.value;
      top = entry.key;
    }
  }
  return top;
}

class _RawStats {
  const _RawStats({
    required this.averageScore,
    required this.positivePercent,
    required this.negativePercent,
    required this.moodFrequency,
    required this.reasonFrequency,
  });

  final double averageScore;
  final double positivePercent;
  final double negativePercent;
  final Map<String, int> moodFrequency;
  final Map<String, int> reasonFrequency;
}

void _registerAdapters() {
  if (!Hive.isAdapterRegistered(60)) {
    Hive.registerAdapter(MoodAdapter());
  }
  if (!Hive.isAdapterRegistered(61)) {
    Hive.registerAdapter(MoodReasonAdapter());
  }
  if (!Hive.isAdapterRegistered(62)) {
    Hive.registerAdapter(MoodEntryAdapter());
  }
}
