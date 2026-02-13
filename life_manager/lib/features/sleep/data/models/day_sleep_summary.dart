import 'package:flutter/material.dart';

/// Aggregated sleep data for a single calendar day.
/// Used by the Sleep Calendar to show day-level indicators.
class DaySleepSummary {
  /// Total main-sleep hours (excluding naps) for the day.
  final double totalHours;

  /// Average sleep score (0-100) across main-sleep records.
  final double avgScore;

  /// Letter grade (A-F) from the best-scored record, or derived from avgScore.
  final String grade;

  /// Quality string: 'poor' | 'fair' | 'good' | 'veryGood' | 'excellent'.
  final String quality;

  /// Color for quality (matches SleepRecord.qualityColor).
  final Color qualityColor;

  /// Whether the day includes any nap records.
  final bool hasNap;

  /// Whether the goal was met (within tolerance) for any main-sleep record.
  final bool goalMet;

  /// Number of sleep records (main + naps) for the day.
  final int recordCount;

  const DaySleepSummary({
    required this.totalHours,
    required this.avgScore,
    required this.grade,
    required this.quality,
    required this.qualityColor,
    required this.hasNap,
    required this.goalMet,
    required this.recordCount,
  });

  bool get hasData => recordCount > 0;
}
