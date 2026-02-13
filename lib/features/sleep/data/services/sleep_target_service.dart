import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';

/// Sleep status based on hours vs target thresholds
enum SleepStatus {
  dangerous,  // Very bad - below dangerousMax
  poor,       // Above dangerous, below poorMax (e.g. 4–6h)
  fair,       // Between poor and healthy (e.g. 6–7h)
  healthy,    // Meets target - healthyMin to healthyMax
  extended,   // Above healthy but below overslept (when manual and gap exists)
  overslept,  // Too much sleep - above oversleptAbove
}

/// Service for the single sleep target used across all records.
/// User sets target + thresholds; every record is compared against these.
class SleepTargetService {
  static const String _targetHoursKey = 'sleep_target_hours';
  static const String _dangerousMaxKey = 'sleep_dangerous_max';
  static const String _poorMaxKey = 'sleep_poor_max';
  static const String _fairMaxKey = 'sleep_fair_max';
  static const String _oversleptAboveKey = 'sleep_overslept_above';
  static const String _legacyHealthyMaxKey = 'sleep_healthy_max';
  static const String _autoCalculateHealthyKey = 'sleep_auto_calculate_healthy';
  static const String _healthyMinKey = 'sleep_healthy_min';
  static const String _healthyMaxKey = 'sleep_healthy_max';

  static const String _statusColorPrefix = 'sleep_status_color_';
  static const String _statusIconPrefix = 'sleep_status_icon_';

  static const double defaultTarget = 8.0;

  static int _defaultColor(SleepStatus s) {
    switch (s) {
      case SleepStatus.dangerous: return AppColors.error.value;
      case SleepStatus.poor: return AppColors.warning.value;
      case SleepStatus.fair: return AppColors.warning.value;
      case SleepStatus.healthy: return AppColors.success.value;
      case SleepStatus.extended: return AppColors.warning.value;
      case SleepStatus.overslept: return AppColors.warning.value;
    }
  }

  static int _defaultIcon(SleepStatus s) {
    switch (s) {
      case SleepStatus.dangerous: return Icons.dangerous_rounded.codePoint;
      case SleepStatus.poor: return Icons.sentiment_dissatisfied_rounded.codePoint;
      case SleepStatus.fair: return Icons.horizontal_rule_rounded.codePoint;
      case SleepStatus.healthy: return Icons.check_circle_rounded.codePoint;
      case SleepStatus.extended: return Icons.nightlight_rounded.codePoint;
      case SleepStatus.overslept: return Icons.bedtime_rounded.codePoint;
    }
  }

  /// Default style for a status (used when no custom style is stored).
  static SleepStatusStyle defaultStyleFor(SleepStatus s) {
    return SleepStatusStyle(
      colorValue: _defaultColor(s),
      iconCodePoint: _defaultIcon(s),
    );
  }

  /// Get target hours. Default 8 if not set.
  Future<double> getTargetHours() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_targetHoursKey) ?? defaultTarget;
  }

  /// Set target hours.
  Future<void> setTargetHours(double hours) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_targetHoursKey, hours);
  }

  /// Get dangerous max (below this = dangerous). Default target * 0.5
  Future<double> getDangerousMax() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getDouble(_dangerousMaxKey);
    if (stored != null) return stored;
    final target = await getTargetHours();
    return (target * 0.5).clamp(2.0, 5.0);
  }

  /// Set dangerous max.
  Future<void> setDangerousMax(double hours) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_dangerousMaxKey, hours);
  }

  /// Get poor max (below this but above dangerous = poor). Default target - 1
  Future<double> getPoorMax() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getDouble(_poorMaxKey);
    if (stored != null) return stored;
    final target = await getTargetHours();
    return (target - 1).clamp(4.0, 7.0);
  }

  /// Set poor max.
  Future<void> setPoorMax(double hours) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_poorMaxKey, hours);
  }

  /// Get fair max (between poor and healthy, e.g. 6–7h). Default target - 0.5
  Future<double> getFairMax() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getDouble(_fairMaxKey);
    if (stored != null) return stored;
    // Migrate from legacy healthyMax
    final legacy = prefs.getDouble(_legacyHealthyMaxKey);
    if (legacy != null) return legacy;
    final target = await getTargetHours();
    return (target - 0.5).clamp(5.0, 10.0);
  }

  /// Set fair max.
  Future<void> setFairMax(double hours) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fairMaxKey, hours);
  }

  /// Get overslept above (above this = overslept). Default target + 1
  Future<double> getOversleptAbove() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getDouble(_oversleptAboveKey);
    if (stored != null) return stored;
    final target = await getTargetHours();
    return (target + 1).clamp(7.0, 12.0);
  }

  /// Set overslept above.
  Future<void> setOversleptAbove(double hours) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_oversleptAboveKey, hours);
  }

  /// Get auto-calculate healthy (true = healthy from Fair to Oversleep).
  Future<bool> getAutoCalculateHealthy() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoCalculateHealthyKey) ?? true;
  }

  /// Set auto-calculate healthy.
  Future<void> setAutoCalculateHealthy(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoCalculateHealthyKey, value);
  }

  /// Get healthy min (start of healthy range). Used when auto = false.
  Future<double> getHealthyMin() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getDouble(_healthyMinKey);
    if (stored != null) return stored;
    return await getFairMax();
  }

  /// Get healthy max (end of healthy range). Used when auto = false.
  Future<double> getHealthyMax() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getDouble(_healthyMaxKey);
    if (stored != null) return stored;
    return await getOversleptAbove();
  }

  /// Set healthy min.
  Future<void> setHealthyMin(double hours) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_healthyMinKey, hours);
  }

  /// Set healthy max.
  Future<void> setHealthyMax(double hours) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_healthyMaxKey, hours);
  }

  /// Get status color for a given status.
  Future<int> getStatusColor(SleepStatus status) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_statusColorPrefix${status.name}') ?? _defaultColor(status);
  }

  /// Get status icon code point.
  Future<int> getStatusIcon(SleepStatus status) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_statusIconPrefix${status.name}') ?? _defaultIcon(status);
  }

  /// Set status color.
  Future<void> setStatusColor(SleepStatus status, int colorValue) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_statusColorPrefix${status.name}', colorValue);
  }

  /// Set status icon.
  Future<void> setStatusIcon(SleepStatus status, int codePoint) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_statusIconPrefix${status.name}', codePoint);
  }

  /// Get all settings at once.
  Future<SleepTargetSettings> getSettings() async {
    final auto = await getAutoCalculateHealthy();
    final statusStyles = <SleepStatus, SleepStatusStyle>{};
    for (final s in SleepStatus.values) {
      statusStyles[s] = SleepStatusStyle(
        colorValue: await getStatusColor(s),
        iconCodePoint: await getStatusIcon(s),
      );
    }
    return SleepTargetSettings(
      targetHours: await getTargetHours(),
      dangerousMax: await getDangerousMax(),
      poorMax: await getPoorMax(),
      fairMax: await getFairMax(),
      oversleptAbove: await getOversleptAbove(),
      autoCalculateHealthy: auto,
      healthyMin: await getHealthyMin(),
      healthyMax: await getHealthyMax(),
      statusStyles: statusStyles,
    );
  }

  /// Save all settings.
  Future<void> saveSettings(SleepTargetSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_targetHoursKey, s.targetHours);
    await prefs.setDouble(_dangerousMaxKey, s.dangerousMax);
    await prefs.setDouble(_poorMaxKey, s.poorMax);
    await prefs.setDouble(_fairMaxKey, s.fairMax);
    await prefs.setDouble(_oversleptAboveKey, s.oversleptAbove);
    await prefs.setBool(_autoCalculateHealthyKey, s.autoCalculateHealthy);
    await prefs.setDouble(_healthyMinKey, s.healthyMin);
    await prefs.setDouble(_healthyMaxKey, s.healthyMax);
    for (final entry in s.statusStyles.entries) {
      await prefs.setInt('$_statusColorPrefix${entry.key.name}', entry.value.colorValue);
      await prefs.setInt('$_statusIconPrefix${entry.key.name}', entry.value.iconCodePoint);
    }
  }

  /// Classify sleep hours into status.
  Future<SleepStatus> getStatusForHours(double hours) async {
    final s = await getSettings();
    return getStatusForHoursWithSettings(hours, s);
  }

  /// Classify using provided settings (avoids async when settings already loaded).
  static SleepStatus getStatusForHoursWithSettings(
    double hours,
    SleepTargetSettings s,
  ) {
    if (hours < s.dangerousMax) return SleepStatus.dangerous;
    if (hours < s.poorMax) return SleepStatus.poor;

    final healthyMin = s.effectiveHealthyMin;
    final healthyMax = s.effectiveHealthyMax;

    if (hours < healthyMin) return SleepStatus.fair;
    if (hours <= healthyMax) return SleepStatus.healthy;
    if (hours <= s.oversleptAbove) return SleepStatus.extended;
    return SleepStatus.overslept;
  }
}

/// Style (color + icon) for a sleep target status.
class SleepStatusStyle {
  final int colorValue;
  final int iconCodePoint;

  const SleepStatusStyle({
    required this.colorValue,
    required this.iconCodePoint,
  });

  Color get color => Color(colorValue);
  IconData get iconData => IconData(iconCodePoint, fontFamily: 'MaterialIcons');
}

/// Immutable settings for sleep target and thresholds.
class SleepTargetSettings {
  final double targetHours;
  final double dangerousMax;
  final double poorMax;
  final double fairMax;
  final double oversleptAbove;
  final bool autoCalculateHealthy;
  final double healthyMin;
  final double healthyMax;
  final Map<SleepStatus, SleepStatusStyle> statusStyles;

  const SleepTargetSettings({
    required this.targetHours,
    required this.dangerousMax,
    required this.poorMax,
    required this.fairMax,
    required this.oversleptAbove,
    this.autoCalculateHealthy = true,
    required this.healthyMin,
    required this.healthyMax,
    required this.statusStyles,
  });

  SleepStatusStyle getStatusStyle(SleepStatus status) =>
      statusStyles[status] ?? SleepStatusStyle(
        colorValue: 0xFFFFA726,
        iconCodePoint: Icons.warning_rounded.codePoint,
      );

  /// When auto: Fair to Oversleep. When manual: user's healthyMin/healthyMax.
  double get effectiveHealthyMin =>
      autoCalculateHealthy ? fairMax : healthyMin;

  double get effectiveHealthyMax =>
      autoCalculateHealthy ? oversleptAbove : healthyMax;

  SleepStatus getStatusForHours(double hours) {
    return SleepTargetService.getStatusForHoursWithSettings(hours, this);
  }
}
