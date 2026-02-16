class ModuleHistoryOptimizationStatus {
  final String moduleId;
  final bool ready;
  final bool usingScanFallback;
  final bool backfillComplete;
  final bool paused;
  final String? indexedFromDateKey;
  final String? oldestDataDateKey;
  final String? lastIndexedDateKey;
  final int bootstrapWindowDays;

  const ModuleHistoryOptimizationStatus({
    required this.moduleId,
    required this.ready,
    required this.usingScanFallback,
    required this.backfillComplete,
    required this.paused,
    required this.indexedFromDateKey,
    required this.oldestDataDateKey,
    required this.lastIndexedDateKey,
    required this.bootstrapWindowDays,
  });

  DateTime? get indexedFromDate => parseDateKey(indexedFromDateKey);
  DateTime? get oldestDataDate => parseDateKey(oldestDataDateKey);
  DateTime? get lastIndexedDate => parseDateKey(lastIndexedDateKey);

  int? get remainingDays {
    final indexedFrom = indexedFromDate;
    final oldest = oldestDataDate;
    if (indexedFrom == null || oldest == null) return null;
    if (!indexedFrom.isAfter(oldest)) return 0;
    return indexedFrom.difference(oldest).inDays;
  }

  double get progressPercent {
    final indexedFrom = indexedFromDate;
    final oldest = oldestDataDate;
    if (indexedFrom == null || oldest == null) {
      return backfillComplete ? 100 : 0;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final totalSpan = today.difference(oldest).inDays + 1;
    if (totalSpan <= 0) return 100;
    final indexedSpan = today.difference(indexedFrom).inDays + 1;
    final ratio = indexedSpan / totalSpan;
    if (ratio < 0) return 0;
    if (ratio > 1) return 100;
    return ratio * 100;
  }

  static DateTime? parseDateKey(String? key) {
    if (key == null || key.length != 8) return null;
    final year = int.tryParse(key.substring(0, 4));
    final month = int.tryParse(key.substring(4, 6));
    final day = int.tryParse(key.substring(6, 8));
    if (year == null || month == null || day == null) {
      return null;
    }
    return DateTime(year, month, day);
  }
}

class HistoryOptimizationStatus {
  final List<ModuleHistoryOptimizationStatus> modules;

  const HistoryOptimizationStatus({required this.modules});

  bool get isComplete =>
      modules.isNotEmpty && modules.every((module) => module.backfillComplete);

  bool get isPaused =>
      modules.isNotEmpty && modules.every((module) => module.paused);

  double get overallPercent {
    if (modules.isEmpty) return 100;
    final total = modules.fold<double>(
      0,
      (sum, module) => sum + module.progressPercent,
    );
    return total / modules.length;
  }
}
