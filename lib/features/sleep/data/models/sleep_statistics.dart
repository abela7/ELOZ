/// Sleep Statistics model
/// Non-persisted model for displaying sleep analytics
class SleepStatistics {
  final DateTime startDate;
  final DateTime endDate;
  final int totalRecords;
  final double averageSleepHours;
  final double averageSleepScore;
  final double totalSleepHours;
  final int goodSleepDays; // Days with quality >= 'good'
  final int poorSleepDays; // Days with quality <= 'fair'
  final double sleepEfficiency; // Percentage
  final Map<String, int> qualityDistribution; // quality -> count
  final Map<String, double> sleepByDayOfWeek; // dayName -> avgHours
  final double? averageFallAsleepMinutes;
  final double? averageTimesAwake;
  final String? mostCommonMood;
  final List<String> commonFactors;
  final double? averageDeepSleep;
  final double? averageRemSleep;
  final double? averageLightSleep;
  final int goalsMetCount; // Days that met sleep goals
  final double goalsMetPercentage;

  SleepStatistics({
    required this.startDate,
    required this.endDate,
    required this.totalRecords,
    required this.averageSleepHours,
    required this.averageSleepScore,
    required this.totalSleepHours,
    required this.goodSleepDays,
    required this.poorSleepDays,
    required this.sleepEfficiency,
    required this.qualityDistribution,
    required this.sleepByDayOfWeek,
    this.averageFallAsleepMinutes,
    this.averageTimesAwake,
    this.mostCommonMood,
    this.commonFactors = const [],
    this.averageDeepSleep,
    this.averageRemSleep,
    this.averageLightSleep,
    this.goalsMetCount = 0,
    this.goalsMetPercentage = 0,
  });

  /// Get formatted average sleep duration
  String get formattedAverageSleep {
    final hours = averageSleepHours.floor();
    final minutes = ((averageSleepHours - hours) * 60).round();
    return '${hours}h ${minutes}m';
  }

  /// Get formatted total sleep duration
  String get formattedTotalSleep {
    final hours = totalSleepHours.floor();
    final minutes = ((totalSleepHours - hours) * 60).round();
    return '${hours}h ${minutes}m';
  }

  /// Get sleep consistency rating
  String get consistencyRating {
    if (totalRecords < 7) return 'Insufficient data';

    // Calculate standard deviation of sleep hours
    // For now, simple heuristic based on efficiency
    if (sleepEfficiency >= 85) {
      return 'Excellent';
    } else if (sleepEfficiency >= 75) {
      return 'Good';
    } else if (sleepEfficiency >= 65) {
      return 'Fair';
    } else {
      return 'Poor';
    }
  }

  /// Get overall sleep health rating
  String get overallRating {
    if (averageSleepScore >= 80) {
      return 'Excellent';
    } else if (averageSleepScore >= 70) {
      return 'Good';
    } else if (averageSleepScore >= 60) {
      return 'Fair';
    } else {
      return 'Poor';
    }
  }

  /// Check if meeting recommended sleep duration
  bool get meetingRecommendedDuration {
    return averageSleepHours >= 7 && averageSleepHours <= 9;
  }

  /// Get sleep debt (hours below 8hr average)
  double get sleepDebt {
    final recommendedDaily = 8.0;
    final deficit = recommendedDaily - averageSleepHours;
    if (deficit <= 0) return 0;
    return deficit * totalRecords;
  }

  /// Get formatted sleep debt
  String get formattedSleepDebt {
    if (sleepDebt <= 0) return 'No sleep debt';
    final hours = sleepDebt.floor();
    final minutes = ((sleepDebt - hours) * 60).round();
    return '${hours}h ${minutes}m';
  }

  /// Get best day of week for sleep
  String? get bestDayOfWeek {
    if (sleepByDayOfWeek.isEmpty) return null;

    var maxHours = 0.0;
    String? bestDay;

    sleepByDayOfWeek.forEach((day, hours) {
      if (hours > maxHours) {
        maxHours = hours;
        bestDay = day;
      }
    });

    return bestDay;
  }

  /// Get worst day of week for sleep
  String? get worstDayOfWeek {
    if (sleepByDayOfWeek.isEmpty) return null;

    var minHours = double.infinity;
    String? worstDay;

    sleepByDayOfWeek.forEach((day, hours) {
      if (hours < minHours) {
        minHours = hours;
        worstDay = day;
      }
    });

    return worstDay;
  }
}
