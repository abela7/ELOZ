import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'sleep_record.g.dart';

/// Sleep quality rating enum
enum SleepQuality {
  poor,       // 1 star
  fair,       // 2 stars
  good,       // 3 stars
  veryGood,   // 4 stars
  excellent,  // 5 stars
}

/// Sleep Record model with Hive persistence
/// Represents a single sleep session
/// 
/// Schema Version: 2
/// - v1: Initial schema with 31 fields (HiveField 0-30)
/// - v2: Goal-aware scoring snapshot fields (HiveField 32-40)
@HiveType(typeId: 50)
class SleepRecord extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  DateTime bedTime;

  @HiveField(2)
  DateTime wakeTime;

  @HiveField(3)
  DateTime createdAt;

  @HiveField(4)
  DateTime? updatedAt;

  @HiveField(5)
  String quality; // 'poor', 'fair', 'good', 'veryGood', 'excellent'

  @HiveField(6)
  int? sleepScore; // 0-100 calculated score

  @HiveField(7)
  String? notes;

  @HiveField(8)
  List<String>? tags; // Tags like 'nap', 'jet-lagged', 'stressed', etc.

  @HiveField(9)
  int? fellAsleepMinutes; // How long it took to fall asleep

  @HiveField(10)
  int? timesAwake; // Number of times woken up during sleep

  @HiveField(11)
  int? minutesAwake; // Total minutes awake during sleep

  @HiveField(12)
  String? mood; // Mood upon waking: 'refreshed', 'tired', 'groggy', etc.

  @HiveField(13)
  bool? hadDreams;

  @HiveField(14)
  bool? hadNightmares;

  @HiveField(15)
  String? dreamNotes;

  @HiveField(16)
  List<String>? factorsBeforeSleep; // 'caffeine', 'alcohol', 'exercise', 'screen-time', etc.

  @HiveField(17)
  String? sleepEnvironment; // 'quiet', 'noisy', 'dark', 'bright', 'comfortable', etc.

  @HiveField(18)
  double? roomTemperature; // in Celsius

  @HiveField(19)
  bool isNap; // Whether this is a nap (not main sleep)

  @HiveField(20)
  String? sleepLocationId; // Reference to sleep location (bedroom, hotel, etc.)

  @HiveField(21)
  int? heartRateAvg; // Average heart rate during sleep (from wearables)

  @HiveField(22)
  int? heartRateMin; // Minimum heart rate during sleep

  @HiveField(23)
  int? heartRateMax; // Maximum heart rate during sleep

  @HiveField(24)
  double? deepSleepHours; // Hours of deep sleep (from wearables)

  @HiveField(25)
  double? lightSleepHours; // Hours of light sleep

  @HiveField(26)
  double? remSleepHours; // Hours of REM sleep

  @HiveField(27)
  int? snoringMinutes; // Minutes of snoring detected

  @HiveField(28)
  bool syncedFromDevice; // Whether synced from wearable device

  @HiveField(29)
  String? deviceName; // Name of the wearable device

  @HiveField(30)
  Map<String, dynamic>? rawDeviceData; // Raw data from device (JSON)

  @HiveField(31)
  int schemaVersion; // Schema version for migrations (current: 2)

  /// Goal used for scoring at log time.
  @HiveField(32)
  String? scoredGoalId;

  /// Goal name snapshot used when this record was scored.
  @HiveField(33)
  String? scoredGoalName;

  /// Goal target hours snapshot used when this record was scored.
  @HiveField(34)
  double? scoredGoalTargetHours;

  /// Actual - target duration in minutes.
  @HiveField(35)
  int? scoredDurationDifferenceMinutes;

  /// Duration component score (0-100).
  @HiveField(36)
  int? scoredDurationScore;

  /// Consistency component score (0-100).
  @HiveField(37)
  int? scoredConsistencyScore;

  /// Letter grade derived from scored sleep score.
  @HiveField(38)
  String? scoredGrade;

  /// Whether the goal target was met within tolerance.
  @HiveField(39)
  bool? scoredGoalMet;

  /// True when scoring used a manual daily goal override.
  @HiveField(40)
  bool usedManualGoalOverride;

  SleepRecord({
    String? id,
    required this.bedTime,
    required this.wakeTime,
    DateTime? createdAt,
    this.updatedAt,
    this.quality = 'good',
    this.sleepScore,
    this.notes,
    this.tags,
    this.fellAsleepMinutes,
    this.timesAwake,
    this.minutesAwake,
    this.mood,
    this.hadDreams,
    this.hadNightmares,
    this.dreamNotes,
    this.factorsBeforeSleep,
    this.sleepEnvironment,
    this.roomTemperature,
    this.isNap = false,
    this.sleepLocationId,
    this.heartRateAvg,
    this.heartRateMin,
    this.heartRateMax,
    this.deepSleepHours,
    this.lightSleepHours,
    this.remSleepHours,
    this.snoringMinutes,
    this.syncedFromDevice = false,
    this.deviceName,
    this.rawDeviceData,
    this.schemaVersion = 2,
    this.scoredGoalId,
    this.scoredGoalName,
    this.scoredGoalTargetHours,
    this.scoredDurationDifferenceMinutes,
    this.scoredDurationScore,
    this.scoredConsistencyScore,
    this.scoredGrade,
    this.scoredGoalMet,
    this.usedManualGoalOverride = false,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  /// Current schema version constant
  static const int currentSchemaVersion = 2;

  /// Get sleep quality enum
  SleepQuality get sleepQuality {
    switch (quality) {
      case 'poor':
        return SleepQuality.poor;
      case 'fair':
        return SleepQuality.fair;
      case 'veryGood':
        return SleepQuality.veryGood;
      case 'excellent':
        return SleepQuality.excellent;
      case 'good':
      default:
        return SleepQuality.good;
    }
  }

  /// Set sleep quality from enum
  set sleepQuality(SleepQuality value) {
    quality = value.name;
  }

  /// Calculate total sleep duration in hours
  double get totalSleepHours {
    final duration = wakeTime.difference(bedTime);
    return duration.inMinutes / 60.0;
  }

  /// Calculate actual sleep time (excluding time awake)
  double get actualSleepHours {
    final total = totalSleepHours;
    final awake = (minutesAwake ?? 0) / 60.0;
    return (total - awake).clamp(0, total);
  }

  /// Calculate sleep efficiency percentage
  double get sleepEfficiency {
    if (totalSleepHours == 0) return 0;
    return (actualSleepHours / totalSleepHours * 100).clamp(0, 100);
  }

  /// Get formatted sleep duration
  String get formattedDuration {
    final hours = totalSleepHours.floor();
    final minutes = ((totalSleepHours - hours) * 60).round();
    return '${hours}h ${minutes}m';
  }

  /// Get formatted actual sleep time
  String get formattedActualSleep {
    final hours = actualSleepHours.floor();
    final minutes = ((actualSleepHours - hours) * 60).round();
    return '${hours}h ${minutes}m';
  }

  /// Get sleep date (date of bedtime)
  DateTime get sleepDate {
    return DateTime(bedTime.year, bedTime.month, bedTime.day);
  }

  /// Get wake date
  DateTime get wakeDate {
    return DateTime(wakeTime.year, wakeTime.month, wakeTime.day);
  }

  /// Check if sleep crossed midnight
  bool get crossedMidnight {
    return sleepDate != wakeDate;
  }

  /// Get color based on quality
  Color get qualityColor {
    switch (sleepQuality) {
      case SleepQuality.poor:
        return Colors.red;
      case SleepQuality.fair:
        return Colors.orange;
      case SleepQuality.good:
        return Colors.yellow.shade700;
      case SleepQuality.veryGood:
        return Colors.lightGreen;
      case SleepQuality.excellent:
        return Colors.green;
    }
  }

  /// Get icon based on quality
  IconData get qualityIcon {
    switch (sleepQuality) {
      case SleepQuality.poor:
        return Icons.sentiment_very_dissatisfied;
      case SleepQuality.fair:
        return Icons.sentiment_dissatisfied;
      case SleepQuality.good:
        return Icons.sentiment_neutral;
      case SleepQuality.veryGood:
        return Icons.sentiment_satisfied;
      case SleepQuality.excellent:
        return Icons.sentiment_very_satisfied;
    }
  }

  /// Get emoji used when logging quality (matches sleep_history_screen picker)
  String get qualityEmoji {
    switch (quality) {
      case 'poor':
        return '😫';
      case 'fair':
        return '🥱';
      case 'good':
        return '🙂';
      case 'veryGood':
        return '🤩';
      case 'excellent':
        return '💪';
      default:
        return '🙂';
    }
  }

  /// Get quality display name
  String get qualityDisplayName {
    switch (sleepQuality) {
      case SleepQuality.poor:
        return 'Poor';
      case SleepQuality.fair:
        return 'Fair';
      case SleepQuality.good:
        return 'Good';
      case SleepQuality.veryGood:
        return 'Very Good';
      case SleepQuality.excellent:
        return 'Excellent';
    }
  }

  String get scoreGradeDisplay {
    if (scoredGrade != null && scoredGrade!.isNotEmpty) {
      return scoredGrade!;
    }
    final score = sleepScore ?? calculateSleepScore();
    if (score >= 90) return 'A';
    if (score >= 80) return 'B';
    if (score >= 70) return 'C';
    if (score >= 60) return 'D';
    if (score >= 50) return 'E';
    return 'F';
  }

  /// Calculate automatic sleep score (0-100)
  int calculateSleepScore() {
    int score = 50; // Base score

    // Duration score (max 25 points)
    final hours = actualSleepHours;
    if (hours >= 7 && hours <= 9) {
      score += 25; // Ideal range
    } else if (hours >= 6 && hours < 7) {
      score += 20;
    } else if (hours >= 9 && hours < 10) {
      score += 20;
    } else if (hours >= 5 && hours < 6) {
      score += 10;
    } else if (hours >= 10 && hours < 11) {
      score += 10;
    }

    // Efficiency score (max 25 points)
    final efficiency = sleepEfficiency;
    if (efficiency >= 90) {
      score += 25;
    } else if (efficiency >= 80) {
      score += 20;
    } else if (efficiency >= 70) {
      score += 15;
    } else if (efficiency >= 60) {
      score += 10;
    } else if (efficiency >= 50) {
      score += 5;
    }

    // Quality rating impact (max 25 points)
    switch (sleepQuality) {
      case SleepQuality.excellent:
        score += 25;
        break;
      case SleepQuality.veryGood:
        score += 20;
        break;
      case SleepQuality.good:
        score += 15;
        break;
      case SleepQuality.fair:
        score += 10;
        break;
      case SleepQuality.poor:
        score += 5;
        break;
    }

    // Deduct points for interruptions
    if (timesAwake != null && timesAwake! > 0) {
      score -= timesAwake! * 2;
    }

    // Time to fall asleep penalty
    if (fellAsleepMinutes != null) {
      if (fellAsleepMinutes! > 45) {
        score -= 10;
      } else if (fellAsleepMinutes! > 30) {
        score -= 5;
      }
    }

    return score.clamp(0, 100);
  }

  /// Check if sleep timing is in healthy range
  bool get isHealthyTiming {
    final bedHour = bedTime.hour;
    final wakeHour = wakeTime.hour;

    // Healthy bed time: 9 PM - 12 AM (21:00 - 00:00)
    final healthyBedTime = bedHour >= 21 || bedHour <= 1;

    // Healthy wake time: 5 AM - 8 AM (05:00 - 08:00)
    final healthyWakeTime = wakeHour >= 5 && wakeHour <= 8;

    return healthyBedTime && healthyWakeTime;
  }

  /// Create a copy with updated fields
  SleepRecord copyWith({
    String? id,
    DateTime? bedTime,
    DateTime? wakeTime,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? quality,
    int? sleepScore,
    String? notes,
    List<String>? tags,
    int? fellAsleepMinutes,
    int? timesAwake,
    int? minutesAwake,
    String? mood,
    bool? hadDreams,
    bool? hadNightmares,
    String? dreamNotes,
    List<String>? factorsBeforeSleep,
    String? sleepEnvironment,
    double? roomTemperature,
    bool? isNap,
    String? sleepLocationId,
    int? heartRateAvg,
    int? heartRateMin,
    int? heartRateMax,
    double? deepSleepHours,
    double? lightSleepHours,
    double? remSleepHours,
    int? snoringMinutes,
    bool? syncedFromDevice,
    String? deviceName,
    Map<String, dynamic>? rawDeviceData,
    int? schemaVersion,
    String? scoredGoalId,
    String? scoredGoalName,
    double? scoredGoalTargetHours,
    int? scoredDurationDifferenceMinutes,
    int? scoredDurationScore,
    int? scoredConsistencyScore,
    String? scoredGrade,
    bool? scoredGoalMet,
    bool? usedManualGoalOverride,
  }) {
    return SleepRecord(
      id: id ?? this.id,
      bedTime: bedTime ?? this.bedTime,
      wakeTime: wakeTime ?? this.wakeTime,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      quality: quality ?? this.quality,
      sleepScore: sleepScore ?? this.sleepScore,
      notes: notes ?? this.notes,
      tags: tags ?? this.tags,
      fellAsleepMinutes: fellAsleepMinutes ?? this.fellAsleepMinutes,
      timesAwake: timesAwake ?? this.timesAwake,
      minutesAwake: minutesAwake ?? this.minutesAwake,
      mood: mood ?? this.mood,
      hadDreams: hadDreams ?? this.hadDreams,
      hadNightmares: hadNightmares ?? this.hadNightmares,
      dreamNotes: dreamNotes ?? this.dreamNotes,
      factorsBeforeSleep: factorsBeforeSleep ?? this.factorsBeforeSleep,
      sleepEnvironment: sleepEnvironment ?? this.sleepEnvironment,
      roomTemperature: roomTemperature ?? this.roomTemperature,
      isNap: isNap ?? this.isNap,
      sleepLocationId: sleepLocationId ?? this.sleepLocationId,
      heartRateAvg: heartRateAvg ?? this.heartRateAvg,
      heartRateMin: heartRateMin ?? this.heartRateMin,
      heartRateMax: heartRateMax ?? this.heartRateMax,
      deepSleepHours: deepSleepHours ?? this.deepSleepHours,
      lightSleepHours: lightSleepHours ?? this.lightSleepHours,
      remSleepHours: remSleepHours ?? this.remSleepHours,
      snoringMinutes: snoringMinutes ?? this.snoringMinutes,
      syncedFromDevice: syncedFromDevice ?? this.syncedFromDevice,
      deviceName: deviceName ?? this.deviceName,
      rawDeviceData: rawDeviceData ?? this.rawDeviceData,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      scoredGoalId: scoredGoalId ?? this.scoredGoalId,
      scoredGoalName: scoredGoalName ?? this.scoredGoalName,
      scoredGoalTargetHours: scoredGoalTargetHours ?? this.scoredGoalTargetHours,
      scoredDurationDifferenceMinutes:
          scoredDurationDifferenceMinutes ?? this.scoredDurationDifferenceMinutes,
      scoredDurationScore: scoredDurationScore ?? this.scoredDurationScore,
      scoredConsistencyScore: scoredConsistencyScore ?? this.scoredConsistencyScore,
      scoredGrade: scoredGrade ?? this.scoredGrade,
      scoredGoalMet: scoredGoalMet ?? this.scoredGoalMet,
      usedManualGoalOverride:
          usedManualGoalOverride ?? this.usedManualGoalOverride,
    );
  }
}
