/// Time utility class for handling duration conversions and calculations
/// Used across the app for timer habits, time management, etc.
class TimeUtils {
  TimeUtils._();

  // ============ Time Units ============
  static const String unitHour = 'hour';
  static const String unitMinute = 'minute';
  static const String unitSecond = 'second';

  // ============ Conversion to Minutes (base unit) ============

  /// Convert hours to minutes
  static double hoursToMinutes(double hours) => hours * 60;

  /// Convert seconds to minutes
  static double secondsToMinutes(double seconds) => seconds / 60;

  /// Convert any time value to minutes based on unit
  static double toMinutes(double value, String unit) {
    switch (unit) {
      case unitHour:
        return hoursToMinutes(value);
      case unitSecond:
        return secondsToMinutes(value);
      case unitMinute:
      default:
        return value;
    }
  }

  // ============ Conversion from Minutes ============

  /// Convert minutes to hours
  static double minutesToHours(double minutes) => minutes / 60;

  /// Convert minutes to seconds
  static double minutesToSeconds(double minutes) => minutes * 60;

  /// Convert minutes to any unit
  static double fromMinutes(double minutes, String unit) {
    switch (unit) {
      case unitHour:
        return minutesToHours(minutes);
      case unitSecond:
        return minutesToSeconds(minutes);
      case unitMinute:
      default:
        return minutes;
    }
  }

  // ============ Formatting ============

  /// Format minutes as "Xh Ym" or "X hours Y minutes"
  static String formatMinutes(int minutes, {bool compact = true}) {
    if (minutes < 0) return compact ? '0m' : '0 minutes';
    
    if (minutes < 60) {
      return compact ? '${minutes}m' : '$minutes ${minutes == 1 ? 'minute' : 'minutes'}';
    }

    final hours = minutes ~/ 60;
    final mins = minutes % 60;

    if (mins == 0) {
      return compact ? '${hours}h' : '$hours ${hours == 1 ? 'hour' : 'hours'}';
    }

    return compact 
        ? '${hours}h ${mins}m' 
        : '$hours ${hours == 1 ? 'hour' : 'hours'} $mins ${mins == 1 ? 'minute' : 'minutes'}';
  }

  /// Format seconds as "Xh Ym Zs"
  static String formatSeconds(int seconds, {bool compact = true}) {
    if (seconds < 0) return compact ? '0s' : '0 seconds';
    
    if (seconds < 60) {
      return compact ? '${seconds}s' : '$seconds ${seconds == 1 ? 'second' : 'seconds'}';
    }

    if (seconds < 3600) {
      final mins = seconds ~/ 60;
      final secs = seconds % 60;
      if (secs == 0) {
        return compact ? '${mins}m' : '$mins ${mins == 1 ? 'minute' : 'minutes'}';
      }
      return compact ? '${mins}m ${secs}s' : '$mins min $secs sec';
    }

    final hours = seconds ~/ 3600;
    final remaining = seconds % 3600;
    final mins = remaining ~/ 60;
    final secs = remaining % 60;

    if (compact) {
      if (mins == 0 && secs == 0) return '${hours}h';
      if (secs == 0) return '${hours}h ${mins}m';
      if (mins == 0) return '${hours}h ${secs}s';
      return '${hours}h ${mins}m ${secs}s';
    } else {
      return '$hours hr $mins min $secs sec';
    }
  }

  /// Format duration based on unit preference
  static String formatDuration(double value, String unit, {bool compact = true}) {
    final minutes = toMinutes(value, unit).round();
    return formatMinutes(minutes, compact: compact);
  }

  // ============ Parsing ============

  /// Parse time string like "1h 30m" or "90m" to minutes
  static int? parseToMinutes(String input) {
    final cleanInput = input.trim().toLowerCase();
    
    // Try parsing as just a number (assume minutes)
    final simple = double.tryParse(cleanInput);
    if (simple != null) return simple.round();

    int totalMinutes = 0;

    // Match hours: "1h", "1hr", "1 hour", "1hours"
    final hourRegex = RegExp(r'(\d+(?:\.\d+)?)\s*(?:h|hr|hour|hours)');
    final hourMatch = hourRegex.firstMatch(cleanInput);
    if (hourMatch != null) {
      totalMinutes += (double.parse(hourMatch.group(1)!) * 60).round();
    }

    // Match minutes: "30m", "30min", "30 minutes"
    final minRegex = RegExp(r'(\d+(?:\.\d+)?)\s*(?:m|min|minute|minutes)');
    final minMatch = minRegex.firstMatch(cleanInput);
    if (minMatch != null) {
      totalMinutes += double.parse(minMatch.group(1)!).round();
    }

    // Match seconds: "30s", "30sec", "30 seconds"
    final secRegex = RegExp(r'(\d+(?:\.\d+)?)\s*(?:s|sec|second|seconds)');
    final secMatch = secRegex.firstMatch(cleanInput);
    if (secMatch != null) {
      totalMinutes += (double.parse(secMatch.group(1)!) / 60).round();
    }

    return totalMinutes > 0 ? totalMinutes : null;
  }

  // ============ Point Calculation ============

  /// Calculate completion ratio between actual and target (both in same unit)
  static double calculateRatio(double actual, double target) {
    if (target <= 0) return 0;
    return actual / target;
  }

  /// Calculate timer points based on actual vs target
  /// 
  /// [actualMinutes] - actual time spent in minutes
  /// [targetMinutes] - target time in minutes
  /// [timerType] - 'target' or 'minimum'
  /// [basePoints] - points for reaching goal
  /// [bonusPerMinute] - bonus for extra time
  /// [allowOvertimeBonus] - whether to give bonus for exceeding target
  static double calculateTimerPoints({
    required int actualMinutes,
    required int targetMinutes,
    required String timerType,
    required int basePoints,
    double bonusPerMinute = 0,
    bool allowOvertimeBonus = false,
    int notDonePoints = -10,
  }) {
    if (targetMinutes <= 0) return 0;
    if (actualMinutes <= 0) return notDonePoints.toDouble();

    final ratio = actualMinutes / targetMinutes;

    if (timerType == 'minimum') {
      // Minimum mode: full points at minimum, bonus for extra
      if (actualMinutes >= targetMinutes) {
        // Reached minimum
        double points = basePoints.toDouble();
        // Add bonus for extra time
        final extraMinutes = actualMinutes - targetMinutes;
        if (extraMinutes > 0 && bonusPerMinute > 0) {
          points += extraMinutes * bonusPerMinute;
        }
        return points;
      } else {
        // Below minimum - proportional
        return basePoints * ratio;
      }
    } else {
      // Target mode: proportional to completion
      if (ratio >= 1.0) {
        // Met or exceeded target
        double points = basePoints.toDouble();
        if (allowOvertimeBonus && actualMinutes > targetMinutes) {
          final extraMinutes = actualMinutes - targetMinutes;
          points += extraMinutes * bonusPerMinute;
        }
        return points;
      } else {
        return basePoints * ratio;
      }
    }
  }

  // ============ Display Helpers ============

  /// Get unit display name
  static String getUnitName(String unit, {bool plural = false}) {
    switch (unit) {
      case unitHour:
        return plural ? 'hours' : 'hour';
      case unitSecond:
        return plural ? 'seconds' : 'second';
      case unitMinute:
      default:
        return plural ? 'minutes' : 'minute';
    }
  }

  /// Get short unit name
  static String getUnitShort(String unit) {
    switch (unit) {
      case unitHour:
        return 'h';
      case unitSecond:
        return 's';
      case unitMinute:
      default:
        return 'm';
    }
  }

  /// Create a display string for target with unit
  /// e.g., "1 hour" or "30 minutes"
  static String formatTarget(double value, String unit) {
    final isPlural = value != 1;
    final unitName = getUnitName(unit, plural: isPlural);
    
    // Format value nicely (no decimals if whole number)
    final valueStr = value == value.roundToDouble() 
        ? value.round().toString() 
        : value.toStringAsFixed(1);
    
    return '$valueStr $unitName';
  }
}

/// Extension on Duration for easy formatting
extension DurationFormatting on Duration {
  /// Format as "Xh Ym" compact
  String toCompact() {
    return TimeUtils.formatMinutes(inMinutes, compact: true);
  }

  /// Format as "X hours Y minutes" verbose
  String toVerbose() {
    return TimeUtils.formatMinutes(inMinutes, compact: false);
  }

  /// Format with seconds as "Xh Ym Zs"
  String toCompactWithSeconds() {
    return TimeUtils.formatSeconds(inSeconds, compact: true);
  }
}
