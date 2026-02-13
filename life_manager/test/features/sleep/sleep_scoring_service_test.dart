import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/sleep/data/models/sleep_record.dart';
import 'package:life_manager/features/sleep/data/services/sleep_scoring_service.dart';

void main() {
  group('SleepScoringService', () {
    final service = SleepScoringService();

    test('gives high score when record matches target duration and timing', () {
      final record = SleepRecord(
        bedTime: DateTime(2026, 2, 10, 22, 35),
        wakeTime: DateTime(2026, 2, 11, 6, 32),
        quality: 'good',
      );

      final result = service.scoreRecord(
        record: record,
        targetHours: 8,
        idealBedTime: const TimeOfDay(hour: 22, minute: 30),
        idealWakeTime: const TimeOfDay(hour: 6, minute: 30),
      );

      expect(result.overallScore, greaterThanOrEqualTo(90));
      expect(result.grade, equals('A'));
      expect(result.goalMet, isTrue);
    });

    test('penalizes major duration mismatch and schedule inconsistency', () {
      final record = SleepRecord(
        bedTime: DateTime(2026, 2, 10, 1, 30),
        wakeTime: DateTime(2026, 2, 10, 6, 0),
        quality: 'fair',
      );

      final result = service.scoreRecord(
        record: record,
        targetHours: 8,
        idealBedTime: const TimeOfDay(hour: 22, minute: 0),
        idealWakeTime: const TimeOfDay(hour: 6, minute: 0),
      );

      expect(result.overallScore, lessThan(60));
      expect(result.grade, anyOf(equals('D'), equals('F')));
      expect(result.goalMet, isFalse);
      expect(result.durationDifferenceMinutes.abs(), greaterThan(120));
    });

    test('falls back to record scoring when no target is provided', () {
      final record = SleepRecord(
        bedTime: DateTime(2026, 2, 10, 22, 0),
        wakeTime: DateTime(2026, 2, 11, 6, 0),
        quality: 'veryGood',
      );

      final result = service.scoreRecord(record: record, targetHours: null);

      expect(result.overallScore, equals(record.calculateSleepScore()));
      expect(result.grade, isNotEmpty);
      expect(result.goalMet, isFalse);
    });
  });
}
