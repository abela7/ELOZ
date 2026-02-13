/// Entry for daily sleep debt breakdown.
class DailyDebtEntry {
  final DateTime date;
  final int debtMinutes;
  final int actualMinutes;
  final int targetMinutes;
  final bool hadData;

  const DailyDebtEntry({
    required this.date,
    required this.debtMinutes,
    required this.actualMinutes,
    required this.targetMinutes,
    required this.hadData,
  });

  String get formattedDebt {
    final h = debtMinutes ~/ 60;
    final m = debtMinutes % 60;
    return '${h}h ${m}m';
  }
}

/// Entry for weekly sleep debt (Mon–Sun).
class WeeklyDebtEntry {
  final DateTime weekStart; // Monday
  final int debtMinutes;
  final int nightsWithData;
  final int nightsMissing;

  const WeeklyDebtEntry({
    required this.weekStart,
    required this.debtMinutes,
    required this.nightsWithData,
    required this.nightsMissing,
  });

  String get formattedDebt {
    final h = debtMinutes ~/ 60;
    final m = debtMinutes % 60;
    return '${h}h ${m}m';
  }
}

/// Entry for monthly sleep debt.
class MonthlyDebtEntry {
  final int year;
  final int month;
  final int debtMinutes;
  final int nightsWithData;
  final int nightsInMonth;

  const MonthlyDebtEntry({
    required this.year,
    required this.month,
    required this.debtMinutes,
    required this.nightsWithData,
    required this.nightsInMonth,
  });

  String get formattedDebt {
    final h = debtMinutes ~/ 60;
    final m = debtMinutes % 60;
    return '${h}h ${m}m';
  }
}

/// Entry for yearly sleep debt.
class YearlyDebtEntry {
  final int year;
  final int debtMinutes;
  final int nightsWithData;

  const YearlyDebtEntry({
    required this.year,
    required this.debtMinutes,
    required this.nightsWithData,
  });

  String get formattedDebt {
    final h = debtMinutes ~/ 60;
    final m = debtMinutes % 60;
    return '${h}h ${m}m';
  }
}
