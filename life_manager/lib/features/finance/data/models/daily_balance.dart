import 'package:hive/hive.dart';
part 'daily_balance.g.dart';

/// Daily balance snapshot model with Hive persistence
/// Represents total balance per currency for a specific day
@HiveType(typeId: 24)
class DailyBalance extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  DateTime date;

  @HiveField(2)
  String currency;

  @HiveField(3)
  double totalBalance;

  @HiveField(4)
  DateTime createdAt;

  DailyBalance({
    String? id,
    required DateTime date,
    required this.currency,
    required this.totalBalance,
    DateTime? createdAt,
  }) : date = _normalizeDate(date),
       id = id ?? _buildId(date, currency),
       createdAt = createdAt ?? DateTime.now();

  /// Normalize a date to midnight for consistent daily keys
  static DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Build a stable ID from date and currency
  static String _buildId(DateTime date, String currency) {
    final normalized = _normalizeDate(date);
    return '${normalized.toIso8601String()}_$currency';
  }
}
