import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'completion_type_config.g.dart';

/// Configuration for a habit completion type
/// Stores default values and settings for each completion type
@HiveType(typeId: 14)
class CompletionTypeConfig extends HiveObject {
  @HiveField(0)
  String id;

  /// Type identifier: 'yesNo', 'numeric', 'timer', 'checklist', 'quit'
  @HiveField(1)
  String typeId;

  /// Display name
  @HiveField(2)
  String name;

  /// Whether this type is enabled
  @HiveField(3)
  bool isEnabled;

  // For Yes/No type
  @HiveField(4)
  int? defaultYesPoints;

  @HiveField(5)
  int? defaultNoPoints;

  @HiveField(6)
  int? defaultPostponePoints;

  // For Numeric type
  @HiveField(7)
  String? defaultCalculationMethod; // 'proportional', 'threshold', 'perUnit'

  @HiveField(8)
  double? defaultThresholdPercent;

  // For Timer type
  @HiveField(9)
  int? defaultPointsPerMinute;

  /// Timer type: 'target' (max goal) or 'minimum' (min required)
  @HiveField(14)
  String? defaultTimerType;

  /// Bonus points per minute when exceeding minimum (for minimum type)
  @HiveField(15)
  double? defaultBonusPerMinute;

  /// Default target duration in minutes
  @HiveField(16)
  int? defaultTargetMinutes;

  /// Whether to allow overtime bonus for target type
  @HiveField(17)
  bool? allowOvertimeBonus;

  // For Quit type
  @HiveField(10)
  int? defaultDailyReward;

  @HiveField(11)
  int? defaultSlipPenalty;

  /// Slip calculation: 'fixed' (same penalty) or 'perUnit' (penalty per unit)
  @HiveField(18)
  String? defaultSlipCalculation;

  /// Penalty per unit consumed (for perUnit calculation)
  @HiveField(19)
  int? defaultPenaltyPerUnit;

  /// Streak protection: allowed slips before breaking streak (0 = immediate)
  @HiveField(20)
  int? defaultStreakProtection;

  /// Cost per unit for money tracking (e.g., 0.50 for $0.50/cigarette)
  @HiveField(21)
  double? defaultCostPerUnit;

  /// Whether temptation tracking is enabled
  @HiveField(22)
  bool? enableTemptationTracking;

  /// Whether quit habits are hidden by default on dashboard
  @HiveField(23)
  bool? defaultHideQuitHabit;

  @HiveField(12)
  DateTime createdAt;

  @HiveField(13)
  DateTime? updatedAt;

  CompletionTypeConfig({
    String? id,
    required this.typeId,
    required this.name,
    this.isEnabled = true,
    this.defaultYesPoints,
    this.defaultNoPoints,
    this.defaultPostponePoints,
    this.defaultCalculationMethod,
    this.defaultThresholdPercent,
    this.defaultPointsPerMinute,
    this.defaultTimerType,
    this.defaultBonusPerMinute,
    this.defaultTargetMinutes,
    this.allowOvertimeBonus,
    this.defaultDailyReward,
    this.defaultSlipPenalty,
    this.defaultSlipCalculation,
    this.defaultPenaltyPerUnit,
    this.defaultStreakProtection,
    this.defaultCostPerUnit,
    this.enableTemptationTracking,
    this.defaultHideQuitHabit,
    DateTime? createdAt,
    this.updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  CompletionTypeConfig copyWith({
    String? id,
    String? typeId,
    String? name,
    bool? isEnabled,
    int? defaultYesPoints,
    int? defaultNoPoints,
    int? defaultPostponePoints,
    String? defaultCalculationMethod,
    double? defaultThresholdPercent,
    int? defaultPointsPerMinute,
    String? defaultTimerType,
    double? defaultBonusPerMinute,
    int? defaultTargetMinutes,
    bool? allowOvertimeBonus,
    int? defaultDailyReward,
    int? defaultSlipPenalty,
    String? defaultSlipCalculation,
    int? defaultPenaltyPerUnit,
    int? defaultStreakProtection,
    double? defaultCostPerUnit,
    bool? enableTemptationTracking,
    bool? defaultHideQuitHabit,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CompletionTypeConfig(
      id: id ?? this.id,
      typeId: typeId ?? this.typeId,
      name: name ?? this.name,
      isEnabled: isEnabled ?? this.isEnabled,
      defaultYesPoints: defaultYesPoints ?? this.defaultYesPoints,
      defaultNoPoints: defaultNoPoints ?? this.defaultNoPoints,
      defaultPostponePoints: defaultPostponePoints ?? this.defaultPostponePoints,
      defaultCalculationMethod: defaultCalculationMethod ?? this.defaultCalculationMethod,
      defaultThresholdPercent: defaultThresholdPercent ?? this.defaultThresholdPercent,
      defaultPointsPerMinute: defaultPointsPerMinute ?? this.defaultPointsPerMinute,
      defaultTimerType: defaultTimerType ?? this.defaultTimerType,
      defaultBonusPerMinute: defaultBonusPerMinute ?? this.defaultBonusPerMinute,
      defaultTargetMinutes: defaultTargetMinutes ?? this.defaultTargetMinutes,
      allowOvertimeBonus: allowOvertimeBonus ?? this.allowOvertimeBonus,
      defaultDailyReward: defaultDailyReward ?? this.defaultDailyReward,
      defaultSlipPenalty: defaultSlipPenalty ?? this.defaultSlipPenalty,
      defaultSlipCalculation: defaultSlipCalculation ?? this.defaultSlipCalculation,
      defaultPenaltyPerUnit: defaultPenaltyPerUnit ?? this.defaultPenaltyPerUnit,
      defaultStreakProtection: defaultStreakProtection ?? this.defaultStreakProtection,
      defaultCostPerUnit: defaultCostPerUnit ?? this.defaultCostPerUnit,
      enableTemptationTracking: enableTemptationTracking ?? this.enableTemptationTracking,
      defaultHideQuitHabit: defaultHideQuitHabit ?? this.defaultHideQuitHabit,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Create default config for Yes/No type
  factory CompletionTypeConfig.yesNoDefault() {
    return CompletionTypeConfig(
      typeId: 'yesNo',
      name: 'Yes or No',
      isEnabled: true,
      defaultYesPoints: 10,
      defaultNoPoints: -10,
      defaultPostponePoints: -5,
    );
  }

  /// Create default config for Numeric type
  factory CompletionTypeConfig.numericDefault() {
    return CompletionTypeConfig(
      typeId: 'numeric',
      name: 'Numeric Value',
      isEnabled: true,
      defaultCalculationMethod: 'proportional',
      defaultThresholdPercent: 80,
      defaultYesPoints: 10,     // Full completion points
      defaultNoPoints: -10,     // No completion penalty
      defaultPostponePoints: -5, // Postpone penalty
    );
  }

  /// Create default config for Timer type
  factory CompletionTypeConfig.timerDefault() {
    return CompletionTypeConfig(
      typeId: 'timer',
      name: 'Timer',
      isEnabled: true,
      defaultTimerType: 'target', // 'target' or 'minimum'
      defaultYesPoints: 10,       // Full completion points (target reached)
      defaultNoPoints: -10,       // Not done penalty
      defaultPostponePoints: -5,  // Postpone penalty
      defaultBonusPerMinute: 0.1, // Bonus for extra time (minimum type)
      defaultTargetMinutes: 60,   // Default 1 hour target
      allowOvertimeBonus: true,   // Allow bonus for exceeding target
    );
  }

  /// Create default config for Quit type
  factory CompletionTypeConfig.quitDefault() {
    return CompletionTypeConfig(
      typeId: 'quit',
      name: 'Quit Bad Habit',
      isEnabled: true,
      defaultDailyReward: 10,          // Points earned each day you resist
      defaultSlipPenalty: -20,         // Fixed penalty for a slip
      defaultSlipCalculation: 'fixed', // 'fixed' or 'perUnit'
      defaultPenaltyPerUnit: -5,       // If perUnit: -5 per cigarette/drink
      defaultStreakProtection: 0,      // 0 = streak breaks immediately
      defaultCostPerUnit: 0,           // Optional: cost per unit ($)
      enableTemptationTracking: true,  // Track temptations
      defaultHideQuitHabit: true,      // Hide from dashboard by default
    );
  }
}
