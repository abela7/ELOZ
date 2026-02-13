part of 'habit_report_screen.dart';

class _InsightCard extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;

  const _InsightCard({
    required this.isDark,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.03),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white54 : Colors.black54,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black87,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportDatePickerDialog extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  const _ReportDatePickerDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<_ReportDatePickerDialog> createState() =>
      _ReportDatePickerDialogState();
}

class _ReportDatePickerDialogState extends State<_ReportDatePickerDialog> {
  static const _accentColor = Color(0xFFCDAF56);
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF1A1D23) : Colors.white;
    final headerColor = isDark
        ? const Color(0xFF10141C)
        : const Color(0xFFF8F8F8);

    return Dialog(
      backgroundColor: backgroundColor,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 350),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              color: headerColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SELECT DATE',
                    style: TextStyle(
                      color: _accentColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          DateFormat('EEE, MMM d').format(_selectedDate),
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.calendar_today_rounded,
                        color: _accentColor.withValues(alpha: 0.45),
                        size: 24,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Flexible(
              child: Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: _accentColor,
                    primary: _accentColor,
                    onPrimary: Colors.black,
                    surface: backgroundColor,
                    onSurface: isDark ? Colors.white : Colors.black,
                    brightness: isDark ? Brightness.dark : Brightness.light,
                  ),
                ),
                child: CalendarDatePicker(
                  initialDate: _selectedDate,
                  firstDate: widget.firstDate,
                  lastDate: widget.lastDate,
                  onDateChanged: (date) {
                    setState(() => _selectedDate = date);
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Material(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () {
                        final now = DateTime.now();
                        Navigator.of(
                          context,
                        ).pop(DateTime(now.year, now.month, now.day));
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.today_rounded,
                              color: _accentColor,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Today',
                              style: TextStyle(
                                color: _accentColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: isDark ? Colors.white60 : Colors.black54,
                    ),
                    child: const Text(
                      'CANCEL',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(_selectedDate),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentColor,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'OK',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodRange {
  final DateTime start;
  final DateTime end;
  final HabitReportPeriod period;

  const _PeriodRange({
    required this.start,
    required this.end,
    required this.period,
  });

  int get dayCount => end.difference(start).inDays + 1;
}

class _DayReport {
  final DateTime date;
  final int due;
  final int completed;
  final int skipped;
  final int missed;
  final int pending;
  final int pointsEarned;
  final int pointsLost;
  final Set<String> dueHabitIds;
  final Set<String> completedHabitIds;
  final Map<String, int> reasonCounts;
  final Map<String, int> skipCountByHabit;
  final int temptationTotal;
  final int temptationResisted;
  final int temptationSlipped;
  final Map<String, int> temptationReasonCounts;
  final Map<String, int> temptationSlipReasonCounts;
  final Map<String, int> temptationIntensityCounts;

  const _DayReport({
    required this.date,
    required this.due,
    required this.completed,
    required this.skipped,
    required this.missed,
    required this.pending,
    required this.pointsEarned,
    required this.pointsLost,
    required this.dueHabitIds,
    required this.completedHabitIds,
    required this.reasonCounts,
    required this.skipCountByHabit,
    required this.temptationTotal,
    required this.temptationResisted,
    required this.temptationSlipped,
    required this.temptationReasonCounts,
    required this.temptationSlipReasonCounts,
    required this.temptationIntensityCounts,
  });
}

class _TemptationDayData {
  final int totalCount;
  final int resistedCount;
  final int slippedCount;
  final Map<String, int> reasonCounts;
  final Map<String, int> slipReasonCounts;
  final Map<String, int> intensityCounts;

  const _TemptationDayData({
    required this.totalCount,
    required this.resistedCount,
    required this.slippedCount,
    required this.reasonCounts,
    required this.slipReasonCounts,
    required this.intensityCounts,
  });
}

class _TemptationDayDataBuilder {
  int totalCount = 0;
  int resistedCount = 0;
  int slippedCount = 0;
  final Map<String, int> reasonCounts = <String, int>{};
  final Map<String, int> slipReasonCounts = <String, int>{};
  final Map<String, int> intensityCounts = <String, int>{};

  _TemptationDayData build() {
    return _TemptationDayData(
      totalCount: totalCount,
      resistedCount: resistedCount,
      slippedCount: slippedCount,
      reasonCounts: Map<String, int>.unmodifiable(reasonCounts),
      slipReasonCounts: Map<String, int>.unmodifiable(slipReasonCounts),
      intensityCounts: Map<String, int>.unmodifiable(intensityCounts),
    );
  }
}

class _PeriodReportData {
  final _PeriodRange currentRange;
  final _PeriodRange previousRange;
  final List<_DayReport> currentDays;
  final List<_DayReport> previousDays;
  final Map<String, Habit> habitsById;
  final bool isQuitMode;
  final List<Habit> availableQuitHabits;
  final String? selectedQuitHabitId;

  const _PeriodReportData({
    required this.currentRange,
    required this.previousRange,
    required this.currentDays,
    required this.previousDays,
    required this.habitsById,
    required this.isQuitMode,
    required this.availableQuitHabits,
    required this.selectedQuitHabitId,
  });

  int get totalDue => _sum(currentDays, (d) => d.due);
  int get completed => _sum(currentDays, (d) => d.completed);
  int get skipped => _sum(currentDays, (d) => d.skipped);
  int get missed => _sum(currentDays, (d) => d.missed);
  int get pending => _sum(currentDays, (d) => d.pending);
  int get pointsEarned => _sum(currentDays, (d) => d.pointsEarned);
  int get pointsLost => _sum(currentDays, (d) => d.pointsLost);
  int get netPoints => pointsEarned - pointsLost;

  int get previousTotalDue => _sum(previousDays, (d) => d.due);
  int get previousCompleted => _sum(previousDays, (d) => d.completed);
  int get previousPointsEarned => _sum(previousDays, (d) => d.pointsEarned);
  int get previousPointsLost => _sum(previousDays, (d) => d.pointsLost);
  int get previousNetPoints => previousPointsEarned - previousPointsLost;

  double get completionRate => totalDue == 0 ? 0.0 : completed / totalDue;
  double get previousCompletionRate =>
      previousTotalDue == 0 ? 0.0 : previousCompleted / previousTotalDue;
  double get completionDelta => completionRate - previousCompletionRate;
  int get temptationTotal => _sum(currentDays, (d) => d.temptationTotal);
  int get temptationResisted => _sum(currentDays, (d) => d.temptationResisted);
  int get temptationSlipped => _sum(currentDays, (d) => d.temptationSlipped);
  int get previousTemptationTotal =>
      _sum(previousDays, (d) => d.temptationTotal);
  int get previousTemptationResisted =>
      _sum(previousDays, (d) => d.temptationResisted);
  int get previousTemptationSlipped =>
      _sum(previousDays, (d) => d.temptationSlipped);
  double get resistanceRate =>
      temptationTotal == 0 ? 0.0 : temptationResisted / temptationTotal;
  double get previousResistanceRate => previousTemptationTotal == 0
      ? 0.0
      : previousTemptationResisted / previousTemptationTotal;
  double get resistanceRateDelta => resistanceRate - previousResistanceRate;
  double get quitPerformanceScore => _averageQuitPerformance(currentDays);
  double get previousQuitPerformanceScore =>
      _averageQuitPerformance(previousDays);
  double get quitPerformanceDelta =>
      quitPerformanceScore - previousQuitPerformanceScore;

  Map<String, int> get skipReasonCounts =>
      _merge(currentDays.map((d) => d.reasonCounts));
  Map<String, int> get temptationReasonCounts =>
      _merge(currentDays.map((d) => d.temptationReasonCounts));
  Map<String, int> get temptationSlipReasonCounts =>
      _merge(currentDays.map((d) => d.temptationSlipReasonCounts));
  Map<String, int> get temptationIntensityCounts =>
      _merge(currentDays.map((d) => d.temptationIntensityCounts));
  Map<String, int> get blockerReasonCounts => isQuitMode
      ? _merge([skipReasonCounts, temptationSlipReasonCounts])
      : skipReasonCounts;
  Map<String, int> get skipCountByHabit =>
      _merge(currentDays.map((d) => d.skipCountByHabit));

  int get totalReasonEntries =>
      blockerReasonCounts.values.fold<int>(0, (sum, value) => sum + value);

  Set<String> get completedHabitIds =>
      currentDays.fold<Set<String>>(<String>{}, (acc, day) {
        acc.addAll(day.completedHabitIds);
        return acc;
      });

  int get uniqueCompletedHabits => completedHabitIds.length;

  Habit? get selectedQuitHabit {
    final selectedId = selectedQuitHabitId;
    if (selectedId == null) return null;
    final inActive = habitsById[selectedId];
    if (inActive != null) return inActive;
    for (final habit in availableQuitHabits) {
      if (habit.id == selectedId) return habit;
    }
    return null;
  }

  List<_DayReport> get temptationDaysWithEvents =>
      currentDays.where((d) => d.temptationTotal > 0).toList()
        ..sort((a, b) => a.date.compareTo(b.date));

  _DayReport? get peakTemptationDay {
    final days = temptationDaysWithEvents;
    if (days.isEmpty) return null;
    days.sort((a, b) {
      final totalCompare = b.temptationTotal.compareTo(a.temptationTotal);
      if (totalCompare != 0) return totalCompare;
      final slippedCompare = b.temptationSlipped.compareTo(a.temptationSlipped);
      if (slippedCompare != 0) return slippedCompare;
      return a.date.compareTo(b.date);
    });
    return days.first;
  }

  double get averageTemptationsPerTrackedDay =>
      currentDays.isEmpty ? 0.0 : temptationTotal / currentDays.length;

  _DayReport? get bestDay {
    _DayReport? best;
    var bestRate = -1.0;
    for (final day in currentDays) {
      if (day.due == 0) continue;
      final rate = day.completed / day.due;
      if (rate > bestRate) {
        bestRate = rate;
        best = day;
      }
    }
    return best;
  }

  MapEntry<String, int>? get topReason {
    final entries = blockerReasonCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) return null;
    return entries.first;
  }

  MapEntry<String, int>? get topSkippedHabit {
    final entries = skipCountByHabit.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) return null;
    return entries.first;
  }

  MapEntry<String, int>? get topTemptationReason {
    final entries = temptationReasonCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) return null;
    return entries.first;
  }

  MapEntry<String, int>? get topSlipTemptationTrigger {
    final entries = temptationSlipReasonCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) return null;
    return entries.first;
  }

  List<_TemptationTriggerInsight> get temptationTriggerInsights {
    final keys = <String>{
      ...temptationReasonCounts.keys,
      ...temptationSlipReasonCounts.keys,
    };
    final insights = <_TemptationTriggerInsight>[];
    for (final trigger in keys) {
      final total = temptationReasonCounts[trigger] ?? 0;
      final rawSlipped = temptationSlipReasonCounts[trigger] ?? 0;
      final resolvedTotal = total > 0 ? total : rawSlipped;
      if (resolvedTotal <= 0) continue;
      final slipped = math.min(rawSlipped, resolvedTotal);
      final resisted = math.max(0, resolvedTotal - slipped);
      insights.add(
        _TemptationTriggerInsight(
          trigger: trigger,
          total: resolvedTotal,
          resisted: resisted,
          slipped: slipped,
        ),
      );
    }
    insights.sort((a, b) {
      final totalCompare = b.total.compareTo(a.total);
      if (totalCompare != 0) return totalCompare;
      final slippedCompare = b.slipped.compareTo(a.slipped);
      if (slippedCompare != 0) return slippedCompare;
      return a.trigger.compareTo(b.trigger);
    });
    return insights;
  }

  _TemptationTriggerInsight? get highestRiskTrigger {
    final insights = temptationTriggerInsights;
    if (insights.isEmpty) return null;
    final candidates = insights.where((item) => item.total >= 2).toList();
    final list = candidates.isEmpty ? insights : candidates;
    list.sort((a, b) {
      final riskCompare = b.slipRate.compareTo(a.slipRate);
      if (riskCompare != 0) return riskCompare;
      final totalCompare = b.total.compareTo(a.total);
      if (totalCompare != 0) return totalCompare;
      return b.slipped.compareTo(a.slipped);
    });
    return list.first;
  }

  _TemptationTriggerInsight? get strongestResistedTrigger {
    final insights = temptationTriggerInsights
        .where((item) => item.resisted > 0)
        .toList();
    if (insights.isEmpty) return null;
    insights.sort((a, b) {
      final resistedCompare = b.resisted.compareTo(a.resisted);
      if (resistedCompare != 0) return resistedCompare;
      final totalCompare = b.total.compareTo(a.total);
      if (totalCompare != 0) return totalCompare;
      return a.trigger.compareTo(b.trigger);
    });
    return insights.first;
  }

  double get triggerControlScore {
    final total = temptationTriggerInsights.fold<int>(
      0,
      (sum, item) => sum + item.total,
    );
    if (total == 0) return resistanceRate;
    final resisted = temptationTriggerInsights.fold<int>(
      0,
      (sum, item) => sum + item.resisted,
    );
    return resisted / total;
  }

  MapEntry<String, int>? get peakTemptationIntensity {
    final entries = temptationIntensityCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) return null;
    return entries.first;
  }

  List<_CompletionTypeStats> get completionTypeBreakdown {
    final bucket = <String, _CompletionTypeStats>{};

    for (final habit in habitsById.values) {
      final typeKey = habit.isQuitHabit
          ? 'quit'
          : _normalizeCompletionType(habit.completionType);
      final label = _completionTypeLabel(typeKey);
      var dueDays = 0;
      var completedDays = 0;

      for (final day in currentDays) {
        if (day.dueHabitIds.contains(habit.id)) {
          dueDays++;
          if (day.completedHabitIds.contains(habit.id)) {
            completedDays++;
          }
        }
      }

      final entry = bucket.putIfAbsent(
        typeKey,
        () => _CompletionTypeStats(key: typeKey, label: label),
      );
      entry.totalHabitCount += 1;
      if (dueDays > 0) {
        entry.activeHabitCount += 1;
        entry.dueDays += dueDays;
        entry.completedDays += completedDays;
      }
    }

    final list = bucket.values.toList()
      ..sort((a, b) {
        final dueCompare = b.dueDays.compareTo(a.dueDays);
        if (dueCompare != 0) return dueCompare;
        return b.activeHabitCount.compareTo(a.activeHabitCount);
      });
    return list;
  }

  static int _sum(List<_DayReport> days, int Function(_DayReport) getter) {
    return days.fold<int>(0, (sum, day) => sum + getter(day));
  }

  static Map<String, int> _merge(Iterable<Map<String, int>> maps) {
    final merged = <String, int>{};
    for (final map in maps) {
      for (final entry in map.entries) {
        merged[entry.key] = (merged[entry.key] ?? 0) + entry.value;
      }
    }
    return merged;
  }

  static double _averageQuitPerformance(List<_DayReport> days) {
    if (days.isEmpty) return 0.0;
    final total = days.fold<double>(
      0,
      (sum, day) => sum + _quitPerformanceScoreForDay(day),
    );
    return total / days.length;
  }
}

class _CompletionTypeStats {
  final String key;
  final String label;
  int totalHabitCount;
  int activeHabitCount;
  int dueDays;
  int completedDays;

  _CompletionTypeStats({required this.key, required this.label})
    : totalHabitCount = 0,
      activeHabitCount = 0,
      dueDays = 0,
      completedDays = 0;

  double get completionRate => dueDays == 0 ? 0.0 : completedDays / dueDays;
}

class _TemptationTriggerInsight {
  final String trigger;
  final int total;
  final int resisted;
  final int slipped;

  const _TemptationTriggerInsight({
    required this.trigger,
    required this.total,
    required this.resisted,
    required this.slipped,
  });

  double get slipRate => total == 0 ? 0.0 : slipped / total;
}

String _normalizeCompletionType(String raw) {
  final normalized = raw.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
  if (normalized == 'yesno') return 'yes_no';
  if (normalized == 'numeric') return 'numeric';
  if (normalized == 'timer') return 'timer';
  if (normalized == 'checklist') return 'checklist';
  if (normalized == 'quit') return 'quit';
  return 'other';
}

String _completionTypeLabel(String key) {
  switch (key) {
    case 'yes_no':
      return 'Yes/No';
    case 'numeric':
      return 'Numeric';
    case 'timer':
      return 'Timer';
    case 'checklist':
      return 'Checklist';
    case 'quit':
      return 'Quit';
    default:
      return 'Other';
  }
}

IconData _completionTypeIcon(String key) {
  switch (key) {
    case 'yes_no':
      return Icons.check_circle_outline;
    case 'numeric':
      return Icons.functions_rounded;
    case 'timer':
      return Icons.timer_outlined;
    case 'checklist':
      return Icons.checklist_rounded;
    case 'quit':
      return Icons.shield_outlined;
    default:
      return Icons.category_outlined;
  }
}

Color _completionTypeColor(String key) {
  switch (key) {
    case 'yes_no':
      return const Color(0xFF4CAF50); // Success green
    case 'numeric':
      return const Color(0xFFCDAF56); // Gold accent
    case 'timer':
      return const Color(0xFFFFA726); // Warning orange
    case 'checklist':
      return const Color(0xFF2196F3); // Info blue
    case 'quit':
      return const Color(0xFFF44336); // Error red
    default:
      return const Color(0xFF9E9E9E);
  }
}

double _quitPerformanceScoreForDay(_DayReport day) {
  final winRate = day.due == 0
      ? 1.0
      : (day.completed / day.due).clamp(0.0, 1.0);
  final resistanceRate = day.temptationTotal > 0
      ? (day.temptationResisted / day.temptationTotal).clamp(0.0, 1.0)
      : winRate;
  final pointsTotal = day.pointsEarned + day.pointsLost;
  final pointsSignal = pointsTotal > 0
      ? (day.pointsEarned / pointsTotal).clamp(0.0, 1.0)
      : winRate;

  final weighted =
      (winRate * 0.55) + (resistanceRate * 0.25) + (pointsSignal * 0.20);
  return (weighted * 100).clamp(0.0, 100.0);
}

class _VisualProgressRing extends StatelessWidget {
  final double progress;
  final double size;
  final double strokeWidth;
  final Color color;
  final Color backgroundColor;
  final Widget? child;

  const _VisualProgressRing({
    required this.progress,
    this.size = 120,
    this.strokeWidth = 12,
    required this.color,
    required this.backgroundColor,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: 1.0,
            strokeWidth: strokeWidth,
            color: backgroundColor,
            strokeCap: StrokeCap.round,
          ),
          CircularProgressIndicator(
            value: progress,
            strokeWidth: strokeWidth,
            color: color,
            strokeCap: StrokeCap.round,
          ),
          if (child != null) Center(child: child),
        ],
      ),
    );
  }
}

class _CompletionRateTrendChart extends StatelessWidget {
  final bool isDark;
  final List<_DayReport> days;

  const _CompletionRateTrendChart({required this.isDark, required this.days});

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const Center(child: Text('No data'));

    final spots = <FlSpot>[];
    for (var i = 0; i < days.length; i++) {
      final rate = days[i].due == 0 ? 0.0 : days[i].completed / days[i].due;
      spots.add(FlSpot(i.toDouble(), rate * 100)); // percentage
    }

    // Determine trend: compare first half average vs second half average
    final midpoint = days.length ~/ 2;
    double firstHalfCompleted = 0, firstHalfDue = 0;
    double secondHalfCompleted = 0, secondHalfDue = 0;
    for (var i = 0; i < days.length; i++) {
      if (i < midpoint) {
        firstHalfCompleted += days[i].completed;
        firstHalfDue += days[i].due;
      } else {
        secondHalfCompleted += days[i].completed;
        secondHalfDue += days[i].due;
      }
    }
    final firstHalfRate = firstHalfDue == 0
        ? 0.0
        : firstHalfCompleted / firstHalfDue;
    final secondHalfRate = secondHalfDue == 0
        ? 0.0
        : secondHalfCompleted / secondHalfDue;
    final isDeclining = secondHalfRate < firstHalfRate - 0.02;

    final chartColor = isDeclining
        ? const Color(0xFFFF5252)
        : const Color(0xFF448AFF);

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (value) => FlLine(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05),
            strokeWidth: 1,
            dashArray: [5, 5],
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: math.max(1, (days.length / 5).floor()).toDouble(),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= days.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    DateFormat(
                      days.length > 7 ? 'd' : 'E',
                    ).format(days[index].date),
                    style: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black38,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: 25,
              getTitlesWidget: (value, meta) {
                if (value < 0 || value > 100) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    '${value.toInt()}%',
                    style: TextStyle(
                      color: isDark ? Colors.white24 : Colors.black26,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (days.length - 1).toDouble(),
        minY: 0,
        maxY: 100,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.35,
            preventCurveOverShooting: true,
            color: chartColor,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  chartColor.withValues(alpha: 0.25),
                  chartColor.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: isDark ? const Color(0xFF2C2C3E) : Colors.white,
            tooltipRoundedRadius: 8,
            tooltipPadding: const EdgeInsets.all(8),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final day = days[spot.x.toInt()];
                return LineTooltipItem(
                  '${DateFormat('MMM d').format(day.date)}\n',
                  TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  children: [
                    TextSpan(
                      text: '${spot.y.round()}%',
                      style: TextStyle(
                        color: chartColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    TextSpan(
                      text: '  (${day.completed}/${day.due})',
                      style: TextStyle(
                        color: isDark ? Colors.white38 : Colors.black38,
                        fontSize: 10,
                      ),
                    ),
                  ],
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }
}

class _QuitPerformanceLineChart extends StatelessWidget {
  final bool isDark;
  final List<_DayReport> days;

  const _QuitPerformanceLineChart({required this.isDark, required this.days});

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const Center(child: Text('No data'));

    final scores = days.map(_quitPerformanceScoreForDay).toList();
    final spots = <FlSpot>[
      for (var i = 0; i < scores.length; i++) FlSpot(i.toDouble(), scores[i]),
    ];

    final midpoint = scores.length ~/ 2;
    final firstHalfAvg = midpoint == 0
        ? scores.first
        : scores.take(midpoint).reduce((a, b) => a + b) / midpoint;
    final secondHalfCount = scores.length - midpoint;
    final secondHalfAvg = secondHalfCount <= 0
        ? scores.last
        : scores.skip(midpoint).reduce((a, b) => a + b) / secondHalfCount;
    final improving = secondHalfAvg >= firstHalfAvg;
    final color = improving ? const Color(0xFF00C853) : const Color(0xFFFF5252);

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (value) => FlLine(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05),
            strokeWidth: 1,
            dashArray: [5, 5],
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: math.max(1, (days.length / 5).floor()).toDouble(),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= days.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    DateFormat(
                      days.length > 7 ? 'd' : 'E',
                    ).format(days[index].date),
                    style: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black38,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: 25,
              getTitlesWidget: (value, meta) {
                if (value < 0 || value > 100) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    '${value.toInt()}%',
                    style: TextStyle(
                      color: isDark ? Colors.white24 : Colors.black26,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (days.length - 1).toDouble(),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.35,
            preventCurveOverShooting: true,
            color: color,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withValues(alpha: 0.24),
                  color.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: isDark ? const Color(0xFF2C2C3E) : Colors.white,
            tooltipRoundedRadius: 8,
            tooltipPadding: const EdgeInsets.all(8),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final day = days[spot.x.toInt()];
                final score = _quitPerformanceScoreForDay(day);
                return LineTooltipItem(
                  '${DateFormat('MMM d').format(day.date)}\n',
                  TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  children: [
                    TextSpan(
                      text: '${score.round()}%',
                      style: TextStyle(
                        color: score >= 65
                            ? const Color(0xFF00C853)
                            : const Color(0xFFFF5252),
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    TextSpan(
                      text: '  W:${day.completed} S:${day.skipped}',
                      style: TextStyle(
                        color: isDark ? Colors.white38 : Colors.black38,
                        fontSize: 10,
                      ),
                    ),
                  ],
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final bool isDark;
  final bool alignCenter;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.isDark,
    this.alignCenter = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: alignCenter
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

// _DayPointsSummary removed â€” daily view now uses inline stats in _buildTrendChartCard

class _WeeklyCompletionBarChart extends StatelessWidget {
  final bool isDark;
  final List<_DayReport> days;

  const _WeeklyCompletionBarChart({required this.isDark, required this.days});

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const Center(child: Text('No data'));

    // Convert to completion rate percentages (0-100)
    final rates = days
        .map((d) => d.due == 0 ? 0.0 : (d.completed / d.due * 100))
        .toList();

    return BarChart(
      BarChartData(
        minY: 0,
        maxY: 100,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (value) => FlLine(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05),
            strokeWidth: 1,
            dashArray: [5, 5],
          ),
        ),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= days.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    DateFormat('E').format(days[index].date),
                    style: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black38,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: 25,
              getTitlesWidget: (value, meta) {
                if (value < 0 || value > 100) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    '${value.toInt()}%',
                    style: TextStyle(
                      color: isDark ? Colors.white24 : Colors.black26,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: [
          for (var i = 0; i < rates.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: rates[i],
                  width: 20,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: rates[i] >= 50
                        ? [
                            const Color(0xFF00C853).withValues(alpha: 0.7),
                            const Color(0xFF00C853),
                          ]
                        : [
                            const Color(0xFFFF5252).withValues(alpha: 0.7),
                            const Color(0xFFFF5252),
                          ],
                  ),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: 100,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.03)
                        : Colors.black.withValues(alpha: 0.03),
                  ),
                ),
              ],
            ),
        ],
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: isDark ? const Color(0xFF2C2C3E) : Colors.white,
            tooltipRoundedRadius: 8,
            tooltipPadding: const EdgeInsets.all(8),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final day = days[group.x.toInt()];
              final pct = rates[group.x.toInt()];
              return BarTooltipItem(
                '${DateFormat('MMM d').format(day.date)}\n',
                TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
                children: [
                  TextSpan(
                    text: '${pct.round()}%',
                    style: TextStyle(
                      color: pct >= 50
                          ? const Color(0xFF00C853)
                          : const Color(0xFFFF5252),
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  TextSpan(
                    text: '  (${day.completed}/${day.due})',
                    style: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black38,
                      fontSize: 10,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CompletionTypeRow extends StatelessWidget {
  final bool isDark;
  final _CompletionTypeStats stats;

  const _CompletionTypeRow({required this.isDark, required this.stats});

  @override
  Widget build(BuildContext context) {
    final rate = stats.completionRate;
    final percent = (rate * 100).round();
    final color = _completionTypeColor(stats.key);
    final icon = _completionTypeIcon(stats.key);
    final habitLabel = stats.totalHabitCount == 0
        ? '0 habits'
        : stats.activeHabitCount == stats.totalHabitCount
        ? '${stats.totalHabitCount} habits'
        : '${stats.activeHabitCount} of ${stats.totalHabitCount} active';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      stats.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF2D3436),
                      ),
                    ),
                    Text(
                      '$percent%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: rate,
                    minHeight: 8,
                    backgroundColor: isDark
                        ? Colors.white10
                        : Colors.black.withValues(alpha: 0.05),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      habitLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white38 : Colors.black45,
                      ),
                    ),
                    Text(
                      stats.dueDays == 0
                          ? 'No due days'
                          : '${stats.completedDays}/${stats.dueDays} days',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final bool isDark;
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.isDark,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: color.withValues(alpha: 0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF2D3436),
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final bool isDark;
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;
  final Widget? trailing;

  const _InfoCard({
    required this.isDark,
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF2D3436),
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}
