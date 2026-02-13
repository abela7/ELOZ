import 'package:flutter/material.dart';
import '../models/sleep_record.dart';

class SleepScoreResult {
  final int overallScore;
  final int durationScore;
  final int consistencyScore;
  final String grade;
  final bool goalMet;
  final int durationDifferenceMinutes;
  final int? bedtimeDeviationMinutes;
  final int? wakeDeviationMinutes;

  const SleepScoreResult({
    required this.overallScore,
    required this.durationScore,
    required this.consistencyScore,
    required this.grade,
    required this.goalMet,
    required this.durationDifferenceMinutes,
    required this.bedtimeDeviationMinutes,
    required this.wakeDeviationMinutes,
  });
}

/// Target-aware sleep scoring.
///
/// Score dimensions:
/// - Duration vs target hours (70%)
/// - Bed/wake consistency vs ideal times (30%), if provided
class SleepScoringService {
  SleepScoreResult scoreRecord({
    required SleepRecord record,
    double? targetHours,
    TimeOfDay? idealBedTime,
    TimeOfDay? idealWakeTime,
  }) {
    if (targetHours == null) {
      final score = record.sleepScore ?? record.calculateSleepScore();
      return SleepScoreResult(
        overallScore: score,
        durationScore: score,
        consistencyScore: 100,
        grade: _gradeForScore(score),
        goalMet: false,
        durationDifferenceMinutes: 0,
        bedtimeDeviationMinutes: null,
        wakeDeviationMinutes: null,
      );
    }

    final actualMinutes = (record.actualSleepHours * 60).round();
    final targetMinutes = (targetHours * 60).round();
    final durationDiff = actualMinutes - targetMinutes;
    final durationScore = _durationScore(durationDiff.abs());

    final bedDeviation = idealBedTime == null
        ? null
        : _clockDiffMinutes(
            record.bedTime.hour * 60 + record.bedTime.minute,
            idealBedTime.hour * 60 + idealBedTime.minute,
          );
    final wakeDeviation = idealWakeTime == null
        ? null
        : _clockDiffMinutes(
            record.wakeTime.hour * 60 + record.wakeTime.minute,
            idealWakeTime.hour * 60 + idealWakeTime.minute,
          );

    final consistencyScore = _consistencyScore(
      bedtimeDeviationMinutes: bedDeviation,
      wakeDeviationMinutes: wakeDeviation,
    );

    final weighted =
        ((durationScore * 0.7) + (consistencyScore * 0.3)).round().clamp(0, 100);
    final goalMet = durationDiff.abs() <= 30;

    return SleepScoreResult(
      overallScore: weighted,
      durationScore: durationScore,
      consistencyScore: consistencyScore,
      grade: _gradeForScore(weighted),
      goalMet: goalMet,
      durationDifferenceMinutes: durationDiff,
      bedtimeDeviationMinutes: bedDeviation,
      wakeDeviationMinutes: wakeDeviation,
    );
  }

  int _durationScore(int absoluteDifferenceMinutes) {
    if (absoluteDifferenceMinutes <= 15) return 100;
    if (absoluteDifferenceMinutes <= 30) return 92;
    if (absoluteDifferenceMinutes <= 45) return 84;
    if (absoluteDifferenceMinutes <= 60) return 76;
    if (absoluteDifferenceMinutes <= 90) return 62;
    if (absoluteDifferenceMinutes <= 120) return 48;
    if (absoluteDifferenceMinutes <= 180) return 30;
    return 15;
  }

  int _consistencyScore({
    required int? bedtimeDeviationMinutes,
    required int? wakeDeviationMinutes,
  }) {
    if (bedtimeDeviationMinutes == null && wakeDeviationMinutes == null) {
      return 100;
    }

    final parts = <int>[];
    if (bedtimeDeviationMinutes != null) {
      parts.add(_timingScore(bedtimeDeviationMinutes.abs()));
    }
    if (wakeDeviationMinutes != null) {
      parts.add(_timingScore(wakeDeviationMinutes.abs()));
    }

    if (parts.isEmpty) return 100;
    final total = parts.reduce((a, b) => a + b);
    return (total / parts.length).round();
  }

  int _timingScore(int absoluteDifferenceMinutes) {
    if (absoluteDifferenceMinutes <= 15) return 100;
    if (absoluteDifferenceMinutes <= 30) return 90;
    if (absoluteDifferenceMinutes <= 60) return 75;
    if (absoluteDifferenceMinutes <= 90) return 60;
    if (absoluteDifferenceMinutes <= 120) return 45;
    return 30;
  }

  /// Smallest difference on a 24h clock in minutes.
  int _clockDiffMinutes(int actualMinutes, int targetMinutes) {
    var diff = (actualMinutes - targetMinutes).abs();
    if (diff > 720) {
      diff = 1440 - diff;
    }
    return diff;
  }

  String _gradeForScore(int score) {
    if (score >= 90) return 'A';
    if (score >= 80) return 'B';
    if (score >= 70) return 'C';
    if (score >= 60) return 'D';
    return 'F';
  }
}
