import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../../utils/currency_utils.dart';
import '../services/finance_settings_service.dart';

part 'savings_goal.g.dart';

enum SavingsGoalStatus { active, completed, failed, closed }

class SavingsContributionEntry {
  final String id;
  final double amount;
  final DateTime contributedAt;
  final double savedAfter;
  final String? note;

  const SavingsContributionEntry({
    required this.id,
    required this.amount,
    required this.contributedAt,
    required this.savedAfter,
    this.note,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'amount': amount,
    'contributedAt': contributedAt.toIso8601String(),
    'savedAfter': savedAfter,
    'note': note,
  };

  factory SavingsContributionEntry.fromJson(Map<String, dynamic> json) {
    final amount = (json['amount'] as num?)?.toDouble() ?? 0;
    final contributedAtRaw = json['contributedAt'] as String? ?? '';
    final contributedAt = DateTime.tryParse(contributedAtRaw) ?? DateTime.now();
    final savedAfter = (json['savedAfter'] as num?)?.toDouble() ?? 0;
    final note = (json['note'] as String?)?.trim();
    final encodedId = (json['id'] as String?)?.trim();
    final fallbackId =
        '${contributedAtRaw}_${amount.toStringAsFixed(4)}_${savedAfter.toStringAsFixed(4)}';

    return SavingsContributionEntry(
      id: (encodedId == null || encodedId.isEmpty) ? fallbackId : encodedId,
      amount: amount,
      contributedAt: contributedAt,
      savedAfter: savedAfter,
      note: (note == null || note.isEmpty) ? null : note,
    );
  }

  static SavingsContributionEntry? tryParseEncoded(String encoded) {
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is Map<String, dynamic>) {
        return SavingsContributionEntry.fromJson(decoded);
      }
      if (decoded is Map) {
        return SavingsContributionEntry.fromJson(
          decoded.cast<String, dynamic>(),
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  String encode() => jsonEncode(toJson());

  SavingsContributionEntry copyWith({
    String? id,
    double? amount,
    DateTime? contributedAt,
    double? savedAfter,
    String? note,
  }) {
    return SavingsContributionEntry(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      contributedAt: contributedAt ?? this.contributedAt,
      savedAfter: savedAfter ?? this.savedAfter,
      note: note ?? this.note,
    );
  }
}

@HiveType(typeId: 30)
class SavingsGoal extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String? description;

  @HiveField(3, defaultValue: 0.0)
  double targetAmount;

  @HiveField(4, defaultValue: 0.0)
  double savedAmount;

  @HiveField(5, defaultValue: 'ETB')
  String currency;

  @HiveField(6)
  DateTime startDate;

  @HiveField(7)
  DateTime targetDate;

  @HiveField(8, defaultValue: 'active')
  String status;

  @HiveField(9)
  DateTime createdAt;

  @HiveField(10)
  DateTime? updatedAt;

  @HiveField(11)
  DateTime? closedAt;

  @HiveField(12)
  String? accountId;

  @HiveField(13)
  int? iconCodePoint;

  @HiveField(14)
  String? iconFontFamily;

  @HiveField(15)
  String? iconFontPackage;

  @HiveField(16, defaultValue: 0xFFCDAF56)
  int colorValue;

  @HiveField(17)
  List<String> contributionLogJson;

  @HiveField(18)
  String? failureReason;

  SavingsGoal({
    String? id,
    required this.name,
    this.description,
    required this.targetAmount,
    this.savedAmount = 0,
    this.currency = FinanceSettingsService.fallbackCurrency,
    DateTime? startDate,
    required DateTime targetDate,
    this.status = 'active',
    DateTime? createdAt,
    this.updatedAt,
    this.closedAt,
    this.accountId,
    this.iconCodePoint,
    this.iconFontFamily,
    this.iconFontPackage,
    int? colorValue,
    List<String>? contributionLogJson,
    this.failureReason,
    IconData? icon,
  }) : id = id ?? const Uuid().v4(),
       startDate = _normalizeDate(startDate ?? DateTime.now()),
       targetDate = _normalizeDate(targetDate),
       createdAt = createdAt ?? DateTime.now(),
       colorValue = colorValue ?? const Color(0xFF00BFA5).toARGB32(),
       contributionLogJson = contributionLogJson ?? <String>[] {
    if (icon != null) {
      iconCodePoint = icon.codePoint;
      iconFontFamily = icon.fontFamily;
      iconFontPackage = icon.fontPackage;
    }
    targetAmount = targetAmount.clamp(0.0, double.infinity).toDouble();
    savedAmount = savedAmount.clamp(0.0, double.infinity).toDouble();
    if (savedAmount > targetAmount && targetAmount > 0) {
      savedAmount = targetAmount;
    }
  }

  static DateTime _normalizeDate(DateTime date) {
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  IconData? get icon {
    if (iconCodePoint == null) return null;
    return IconData(
      iconCodePoint!,
      fontFamily: iconFontFamily ?? 'MaterialIcons',
      fontPackage: iconFontPackage,
    );
  }

  set icon(IconData? value) {
    iconCodePoint = value?.codePoint;
    iconFontFamily = value?.fontFamily;
    iconFontPackage = value?.fontPackage;
  }

  Color get color => Color(colorValue);

  set color(Color value) {
    colorValue = value.toARGB32();
  }

  SavingsGoalStatus get goalStatus {
    switch (status) {
      case 'completed':
        return SavingsGoalStatus.completed;
      case 'failed':
        return SavingsGoalStatus.failed;
      case 'closed':
        return SavingsGoalStatus.closed;
      case 'active':
      default:
        return SavingsGoalStatus.active;
    }
  }

  set goalStatus(SavingsGoalStatus value) {
    status = value.name;
  }

  bool get isActive => goalStatus == SavingsGoalStatus.active;
  bool get isCompleted => goalStatus == SavingsGoalStatus.completed;
  bool get isFailed => goalStatus == SavingsGoalStatus.failed;
  bool get isClosed => goalStatus == SavingsGoalStatus.closed;
  bool get isArchived => isFailed || isClosed;

  double get remainingAmount =>
      (targetAmount - savedAmount).clamp(0.0, double.infinity).toDouble();

  double get progressFraction {
    if (targetAmount <= 0) return 0;
    return (savedAmount / targetAmount).clamp(0.0, 1.0).toDouble();
  }

  double get progressPercentage => progressFraction * 100;

  int get totalDays {
    final start = _normalizeDate(startDate);
    final end = _normalizeDate(targetDate);
    final diff = end.difference(start).inDays + 1;
    return diff <= 0 ? 1 : diff;
  }

  int get elapsedDays {
    final now = _normalizeDate(DateTime.now());
    if (now.isBefore(startDate)) return 0;
    final diff = now.difference(startDate).inDays + 1;
    return diff.clamp(0, totalDays).toInt();
  }

  int get daysRemaining {
    final now = _normalizeDate(DateTime.now());
    if (now.isAfter(targetDate)) return 0;
    return targetDate.difference(now).inDays + 1;
  }

  bool get isOverdue => daysRemaining == 0 && remainingAmount > 0;

  double _requiredByDays(double days) {
    if (remainingAmount <= 0) return 0;
    return remainingAmount / days;
  }

  double get requiredPerDay =>
      _requiredByDays(math.max(daysRemaining, 1).toDouble());

  double get requiredPerWeek => requiredPerDay * 7;

  double get requiredPerMonth => requiredPerDay * 30.4375;

  double get requiredPerQuarter => requiredPerDay * 91.3125;

  double get requiredPerHalfYear => requiredPerDay * 182.625;

  double get requiredPerYear => requiredPerDay * 365.25;

  String get formattedSaved {
    final symbol = CurrencyUtils.getCurrencySymbol(currency);
    return '$symbol${savedAmount.toStringAsFixed(2)}';
  }

  String get formattedTarget {
    final symbol = CurrencyUtils.getCurrencySymbol(currency);
    return '$symbol${targetAmount.toStringAsFixed(2)}';
  }

  String get formattedRemaining {
    final symbol = CurrencyUtils.getCurrencySymbol(currency);
    return '$symbol${remainingAmount.toStringAsFixed(2)}';
  }

  List<SavingsContributionEntry> get contributionHistory {
    final entries = _contributionEntriesAscending();
    entries.sort((a, b) => b.contributedAt.compareTo(a.contributedAt));
    return entries;
  }

  List<SavingsContributionEntry> _contributionEntriesAscending() {
    final entries = contributionLogJson
        .map(SavingsContributionEntry.tryParseEncoded)
        .whereType<SavingsContributionEntry>()
        .toList();

    entries.sort((a, b) {
      final byDate = a.contributedAt.compareTo(b.contributedAt);
      if (byDate != 0) return byDate;
      return a.id.compareTo(b.id);
    });
    return entries;
  }

  void _syncCompletionStatus() {
    if (targetAmount > 0 && savedAmount >= targetAmount) {
      goalStatus = SavingsGoalStatus.completed;
      closedAt ??= DateTime.now();
      failureReason = null;
      return;
    }

    if (goalStatus == SavingsGoalStatus.completed) {
      goalStatus = SavingsGoalStatus.active;
      closedAt = null;
    }
  }

  void _applyContributionEntries(List<SavingsContributionEntry> rawEntries) {
    final currentLogSum = _contributionEntriesAscending().fold<double>(
      0,
      (sum, entry) => sum + entry.amount.clamp(0.0, double.infinity).toDouble(),
    );
    final baselineSaved = (savedAmount - currentLogSum)
        .clamp(0.0, double.infinity)
        .toDouble();

    final entries = [...rawEntries]
      ..sort((a, b) {
        final byDate = a.contributedAt.compareTo(b.contributedAt);
        if (byDate != 0) return byDate;
        return a.id.compareTo(b.id);
      });

    double runningSaved = baselineSaved;
    final normalized = <SavingsContributionEntry>[];
    for (final entry in entries) {
      final amount = entry.amount.clamp(0.0, double.infinity).toDouble();
      runningSaved += amount;
      normalized.add(entry.copyWith(amount: amount, savedAfter: runningSaved));
    }

    contributionLogJson = normalized.map((entry) => entry.encode()).toList();
    savedAmount = runningSaved.clamp(0.0, double.infinity).toDouble();
    updatedAt = DateTime.now();
    _syncCompletionStatus();
  }

  bool addContribution(double amount, {DateTime? contributedAt, String? note}) {
    if (amount <= 0) return false;

    final entries = _contributionEntriesAscending();
    entries.add(
      SavingsContributionEntry(
        id: const Uuid().v4(),
        amount: amount,
        contributedAt: contributedAt ?? DateTime.now(),
        savedAfter: savedAmount,
        note: note?.trim().isEmpty ?? true ? null : note?.trim(),
      ),
    );
    _applyContributionEntries(entries);
    return true;
  }

  bool undoContribution(String contributionId) {
    final entries = _contributionEntriesAscending();
    final index = entries.indexWhere((entry) => entry.id == contributionId);
    if (index < 0) return false;
    entries.removeAt(index);
    _applyContributionEntries(entries);
    return true;
  }

  bool updateContribution({
    required String contributionId,
    required double amount,
    DateTime? contributedAt,
    String? note,
  }) {
    if (amount <= 0) return false;

    final entries = _contributionEntriesAscending();
    final index = entries.indexWhere((entry) => entry.id == contributionId);
    if (index < 0) return false;

    final existing = entries[index];
    entries[index] = existing.copyWith(
      amount: amount,
      contributedAt: contributedAt ?? existing.contributedAt,
      note: note ?? existing.note,
    );

    _applyContributionEntries(entries);
    return true;
  }

  void markFailed({String? reason}) {
    goalStatus = SavingsGoalStatus.failed;
    failureReason = reason?.trim().isEmpty ?? true ? null : reason?.trim();
    closedAt = DateTime.now();
    updatedAt = DateTime.now();
  }

  void closeGoal({String? reason}) {
    goalStatus = SavingsGoalStatus.closed;
    failureReason = reason?.trim().isEmpty ?? true ? null : reason?.trim();
    closedAt = DateTime.now();
    updatedAt = DateTime.now();
  }

  void reopenGoal() {
    if (goalStatus == SavingsGoalStatus.completed) return;
    goalStatus = SavingsGoalStatus.active;
    failureReason = null;
    closedAt = null;
    updatedAt = DateTime.now();
  }

  SavingsGoal copyWith({
    String? id,
    String? name,
    String? description,
    double? targetAmount,
    double? savedAmount,
    String? currency,
    DateTime? startDate,
    DateTime? targetDate,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? closedAt,
    String? accountId,
    int? iconCodePoint,
    String? iconFontFamily,
    String? iconFontPackage,
    int? colorValue,
    List<String>? contributionLogJson,
    String? failureReason,
  }) {
    return SavingsGoal(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      targetAmount: targetAmount ?? this.targetAmount,
      savedAmount: savedAmount ?? this.savedAmount,
      currency: currency ?? this.currency,
      startDate: startDate ?? this.startDate,
      targetDate: targetDate ?? this.targetDate,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      closedAt: closedAt ?? this.closedAt,
      accountId: accountId ?? this.accountId,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      iconFontFamily: iconFontFamily ?? this.iconFontFamily,
      iconFontPackage: iconFontPackage ?? this.iconFontPackage,
      colorValue: colorValue ?? this.colorValue,
      contributionLogJson:
          contributionLogJson ?? List<String>.from(this.contributionLogJson),
      failureReason: failureReason ?? this.failureReason,
    );
  }
}
