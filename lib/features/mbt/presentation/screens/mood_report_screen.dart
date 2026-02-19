import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/dark_gradient.dart';
import '../../data/models/mood.dart';
import '../../data/models/mood_entry.dart';
import '../../data/models/mood_reason.dart';
import '../../data/services/mood_api_service.dart';
import '../../mbt_module.dart';

enum _RangeOption { daily, weekly, monthly, custom, lifetime }

const Color _kGold = Color(0xFFCDAF56);
const Color _kPositive = Color(0xFF4CAF50);
const Color _kNegative = Color(0xFFE53935);

class MoodReportScreen extends StatefulWidget {
  const MoodReportScreen({super.key, this.initialDate});

  /// Date to open in the Daily view. Defaults to today if omitted.
  final DateTime? initialDate;

  @override
  State<MoodReportScreen> createState() => _MoodReportScreenState();
}

class _MoodReportScreenState extends State<MoodReportScreen>
    with SingleTickerProviderStateMixin {
  final MoodApiService _api = MoodApiService();

  late final TabController _tabController;

  bool _loading = true;
  String? _error;
  _RangeOption _rangeOption = _RangeOption.daily;
  late DateTime _selectedDailyDate;
  DateTime _customFrom = DateTime.now().subtract(const Duration(days: 6));
  DateTime _customTo = DateTime.now();

  // Data -- loaded lazily per range
  MoodSummaryResponse? _summary;
  MoodAnalyticsResponse? _analytics;
  List<MoodEntry> _dailyEntries = const [];
  List<Mood> _moods = const [];
  List<MoodReason> _reasons = const [];

  Map<String, Mood> get _moodById => {for (final m in _moods) m.id: m};
  Map<String, MoodReason> get _reasonById =>
      {for (final r in _reasons) r.id: r};
  List<Mood> get _activeMoods =>
      _moods.where((m) => m.isActive && !m.isDeleted).toList();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final raw = widget.initialDate ?? DateTime.now();
    _selectedDailyDate = DateTime(raw.year, raw.month, raw.day);
    unawaited(_initialize());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    await MbtModule.init(preOpenBoxes: true);
    await _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final request = _resolveRequest();

      // Always load moods + reasons (cheap, needed everywhere)
      final configResults = await Future.wait([
        _api.getMoods(includeInactive: true),
        _api.getReasons(includeInactive: true),
      ]);
      final moods = configResults[0] as List<Mood>;
      final reasons = configResults[1] as List<MoodReason>;

      MoodSummaryResponse? summary;
      MoodAnalyticsResponse? analytics;
      List<MoodEntry> dailyEntries = const [];

      if (_rangeOption == _RangeOption.daily) {
        // Daily: only fetch selected day's entries + summary (fast)
        final results = await Future.wait([
          _api.getMoodEntriesForDate(_selectedDailyDate),
          _api.getMoodSummary(range: MoodRange.custom,
              from: _selectedDailyDate, to: _selectedDailyDate),
        ]);
        dailyEntries = results[0] as List<MoodEntry>;
        summary = results[1] as MoodSummaryResponse;
      } else {
        // Weekly/Monthly/etc: fetch summary + analytics for charts
        final results = await Future.wait([
          _api.getMoodSummary(range: request.range, from: request.from,
              to: request.to),
          _api.getMoodAnalytics(range: request.range, from: request.from,
              to: request.to),
        ]);
        summary = results[0] as MoodSummaryResponse;
        analytics = results[1] as MoodAnalyticsResponse;
      }

      if (!mounted) return;
      setState(() {
        _moods = moods;
        _reasons = reasons;
        _summary = summary;
        _analytics = analytics;
        _dailyEntries = dailyEntries;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  ({MoodRange range, DateTime? from, DateTime? to}) _resolveRequest() {
    switch (_rangeOption) {
      case _RangeOption.daily:
        return (range: MoodRange.daily, from: null, to: null);
      case _RangeOption.weekly:
        return (range: MoodRange.weekly, from: null, to: null);
      case _RangeOption.monthly:
        return (range: MoodRange.monthly, from: null, to: null);
      case _RangeOption.custom:
        return (range: MoodRange.custom, from: _customFrom, to: _customTo);
      case _RangeOption.lifetime:
        return (range: MoodRange.lifetime, from: null, to: null);
    }
  }

  Future<void> _pickCustomDate({required bool isFrom}) async {
    final initial = isFrom ? _customFrom : _customTo;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _customFrom = DateTime(picked.year, picked.month, picked.day);
        if (_customTo.isBefore(_customFrom)) _customTo = _customFrom;
      } else {
        _customTo = DateTime(picked.year, picked.month, picked.day);
        if (_customTo.isBefore(_customFrom)) _customFrom = _customTo;
      }
    });
    await _reload();
  }

  /// Resolves a score to the nearest mood by pointValue.
  Mood? _moodForScore(double score) {
    final candidates = _activeMoods;
    if (candidates.isEmpty) return null;
    Mood? best;
    var bestDist = 999999.0;
    for (final m in candidates) {
      final dist = (m.pointValue - score).abs();
      if (dist < bestDist) {
        bestDist = dist;
        best = m;
      }
    }
    return best;
  }

  Widget _moodEmoji(Mood? mood, {double size = 28}) {
    if (mood == null) {
      return Icon(Icons.remove_rounded, size: size,
          color: Colors.grey.withValues(alpha: 0.5));
    }
    if (mood.emojiCodePoint != null) {
      return Text(mood.emojiCharacter, style: TextStyle(fontSize: size));
    }
    return Icon(mood.icon, color: Color(mood.colorValue), size: size);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final content = _buildContent(context, isDark);
    return Scaffold(body: isDark ? DarkGradient.wrap(child: content) : content);
  }

  Widget _buildContent(BuildContext context, bool isDark) {
    final showTabs = _rangeOption != _RangeOption.daily;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Mood Report'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _reload,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        bottom: showTabs
            ? PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: _buildTabBar(isDark),
              )
            : null,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: _buildRangeChips(isDark),
          ),
          if (_rangeOption == _RangeOption.custom)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: _buildCustomRangeRow(isDark),
            ),
          const SizedBox(height: 12),
          if (_error?.trim().isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(_error!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w600)),
            ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: _kGold))
                : _rangeOption == _RangeOption.daily
                    ? _buildDailyReport(isDark)
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildOverviewTab(isDark),
                          _buildReasonsTab(isDark),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(bool isDark) {
    return TabBar(
      controller: _tabController,
      indicatorColor: _kGold,
      indicatorWeight: 3,
      labelColor: _kGold,
      unselectedLabelColor: isDark ? Colors.white54 : Colors.black45,
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
          letterSpacing: 0.5),
      unselectedLabelStyle: const TextStyle(fontSize: 13,
          fontWeight: FontWeight.w600),
      tabs: const [Tab(text: 'Overview'), Tab(text: 'Reasons')],
    );
  }

  // ---------------------------------------------------------------------------
  // Range chips
  // ---------------------------------------------------------------------------

  Widget _buildRangeChips(bool isDark) {
    const options = <(_RangeOption, String)>[
      (_RangeOption.daily, 'Daily'),
      (_RangeOption.weekly, 'Weekly'),
      (_RangeOption.monthly, 'Monthly'),
      (_RangeOption.custom, 'Custom'),
      (_RangeOption.lifetime, 'All'),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: options.map((item) => Expanded(
          child: GestureDetector(
            onTap: () {
              if (_rangeOption == item.$1) return;
              setState(() => _rangeOption = item.$1);
              unawaited(_reload());
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: _rangeOption == item.$1 ? _kGold : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                item.$2,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: _rangeOption == item.$1
                      ? FontWeight.w800 : FontWeight.w600,
                  color: _rangeOption == item.$1
                      ? const Color(0xFF1E1E1E)
                      : (isDark ? Colors.white70 : Colors.black54),
                ),
              ),
            ),
          ),
        )).toList(growable: false),
      ),
    );
  }

  Widget _buildCustomRangeRow(bool isDark) {
    String format(DateTime date) => DateFormat('MMM d, yyyy').format(date);
    Widget btn({required String label, required DateTime value,
        required VoidCallback onTap}) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.04)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10,
                    fontWeight: FontWeight.w700, color: _kGold,
                    letterSpacing: 0.8)),
                const SizedBox(height: 2),
                Text(format(value), style: TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87)),
              ],
            ),
          ),
        ),
      );
    }
    return Row(children: [
      btn(label: 'FROM', value: _customFrom,
          onTap: () => _pickCustomDate(isFrom: true)),
      const SizedBox(width: 8),
      btn(label: 'TO', value: _customTo,
          onTap: () => _pickCustomDate(isFrom: false)),
    ]);
  }

  // ===================================================================
  //  DAILY REPORT
  // ===================================================================

  Future<void> _shiftDailyDate(int days) async {
    final next = _selectedDailyDate.add(Duration(days: days));
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    if (next.isAfter(todayOnly)) return; // don't go into the future
    setState(() => _selectedDailyDate = next);
    await _reload();
  }

  Future<void> _pickDailyDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDailyDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: today,
    );
    if (picked == null) return;
    setState(() =>
        _selectedDailyDate = DateTime(picked.year, picked.month, picked.day));
    await _reload();
  }

  Widget _buildDailyReport(bool isDark) {
    final entries = _dailyEntries.where((e) => !e.isDeleted).toList()
      ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
    final summary = _summary;
    final avgMood = _computeAverageMood(entries);
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final isToday = _selectedDailyDate == todayOnly;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        // Date navigator
        _buildDailyDateNav(isDark, isToday),
        const SizedBox(height: 16),

        if (entries.isEmpty)
          _buildDailyEmptyHero(isDark, isToday)
        else ...[
          _buildDailyHero(isDark, entries, avgMood, summary),
          const SizedBox(height: 16),
          _section(isDark, icon: Icons.timeline_rounded, title: 'MOOD FLOW',
              onExpand: entries.length >= 2
                  ? () => _openMoodFlowFullscreen(isDark, entries)
                  : null,
              child: _buildMoodFlow(isDark, entries)),
          const SizedBox(height: 16),
          _section(isDark, icon: Icons.list_alt_rounded, title: 'ENTRY LOG',
              child: _buildEntryTimeline(isDark, entries)),
          if (summary != null && summary.entriesCount > 0) ...[
            const SizedBox(height: 16),
            _section(isDark, icon: Icons.balance_rounded, title: 'POLARITY',
                child: _buildPolarityBar(isDark, summary)),
          ],
        ],
      ],
    );
  }

  Widget _buildDailyDateNav(bool isDark, bool isToday) {
    final label = isToday
        ? 'Today'
        : DateFormat('EEE, MMM d, yyyy').format(_selectedDailyDate);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark ? null : [BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _shiftDailyDate(-1),
            icon: const Icon(Icons.chevron_left_rounded, size: 22),
            color: isDark ? Colors.white70 : Colors.black54,
            splashRadius: 20,
          ),
          Expanded(
            child: GestureDetector(
              onTap: _pickDailyDate,
              child: Column(
                children: [
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  if (!isToday)
                    Text(
                      'Tap to pick a date',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: isToday ? null : () => _shiftDailyDate(1),
            icon: const Icon(Icons.chevron_right_rounded, size: 22),
            color: isToday
                ? (isDark ? Colors.white24 : Colors.black12)
                : (isDark ? Colors.white70 : Colors.black54),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildDailyEmptyHero(bool isDark, bool isToday) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text('😶', style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            isToday ? 'No entries today' : 'No entries for this day',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87),
          ),
          const SizedBox(height: 4),
          Text(
            isToday ? 'Log a mood to see your daily report'
                : 'No mood was logged on this day',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13,
                color: isDark ? Colors.white38 : Colors.black38),
          ),
        ],
      ),
    );
  }

  Mood? _computeAverageMood(List<MoodEntry> entries) {
    if (entries.isEmpty) return null;
    final sorted = List<MoodEntry>.from(entries)
      ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
    var weightedSum = 0.0;
    var weightSum = 0.0;
    for (var i = 0; i < sorted.length; i++) {
      final mood = _moodById[sorted[i].moodId];
      final pv = mood?.pointValue ?? 0;
      final w = 0.75;
      final weight = _pow(w, sorted.length - 1 - i);
      weightedSum += pv * weight;
      weightSum += weight;
    }
    if (weightSum <= 0) return null;
    return _moodForScore(weightedSum / weightSum);
  }

  double _pow(double base, int exp) {
    var result = 1.0;
    for (var i = 0; i < exp; i++) result *= base;
    return result;
  }

  Widget _buildDailyHero(bool isDark, List<MoodEntry> entries,
      Mood? avgMood, MoodSummaryResponse? summary) {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final isToday = _selectedDailyDate == todayOnly;
    final dateLabel = DateFormat('EEEE, MMM d').format(_selectedDailyDate);
    final subLabel = isToday ? 'Your day so far' : 'Day summary';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF2E3142), const Color(0xFF252836)]
              : [const Color(0xFFFBF8F0), const Color(0xFFF5F0E4)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kGold.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(dateLabel, style: TextStyle(fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.black45)),
          const SizedBox(height: 12),
          _moodEmoji(avgMood, size: 56),
          const SizedBox(height: 8),
          Text(
            avgMood?.name ?? 'No mood',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
                color: avgMood != null
                    ? Color(avgMood.colorValue) : _kGold),
          ),
          const SizedBox(height: 4),
          Text(subLabel, style: TextStyle(fontSize: 12,
              color: isDark ? Colors.white38 : Colors.black38)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _dailyStat(isDark, '${entries.length}', 'Entries'),
              _dailyStat(isDark,
                  '${summary?.positivePercent.toStringAsFixed(0) ?? '0'}%',
                  'Positive'),
              _dailyStat(isDark,
                  '${summary?.negativePercent.toStringAsFixed(0) ?? '0'}%',
                  'Negative'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dailyStat(bool isDark, String value, String label) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
            color: _kGold)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
            color: isDark ? Colors.white38 : Colors.black38)),
      ],
    );
  }

  Widget _buildMoodFlow(bool isDark, List<MoodEntry> entries) {
    if (entries.length < 2) {
      final single = entries.isNotEmpty ? entries.first : null;
      final mood = single != null ? _moodById[single.moodId] : null;
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 28),
        alignment: Alignment.center,
        child: Column(
          children: [
            _moodEmoji(mood, size: 44),
            if (single != null) ...[
              const SizedBox(height: 8),
              Text(mood?.name ?? 'Unknown',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 2),
              Text(DateFormat('h:mm a').format(single.loggedAt),
                  style: TextStyle(fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.black38)),
            ],
            if (single == null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Log at least 2 entries to see the graph',
                    style: TextStyle(fontSize: 12,
                        color: isDark ? Colors.white38 : Colors.black38)),
              ),
          ],
        ),
      );
    }

    // Build spots from entries
    final spots = <FlSpot>[];
    final timeLabels = <int, String>{};
    final moodAtIndex = <int, Mood?>{};
    var yMax = 0.0;
    var yMin = 0.0;

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final mood = _moodById[entry.moodId];
      final score = (mood?.pointValue ?? 0).toDouble();
      spots.add(FlSpot(i.toDouble(), score));
      moodAtIndex[i] = mood;
      if (score > yMax) yMax = score;
      if (score < yMin) yMin = score;

      if (entries.length <= 10 || i == 0 || i == entries.length - 1 ||
          i % (entries.length ~/ 6).clamp(1, 999) == 0) {
        timeLabels[i] = DateFormat('h:mm a').format(entry.loggedAt);
      }
    }

    // Symmetric Y-axis centred on 0
    final absMax = yMax.abs() > yMin.abs() ? yMax.abs() : yMin.abs();
    final yBound = (absMax + 1).ceilToDouble();

    // Gradient colours: positive zone uses green tint, negative uses red
    final lineGradient = LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [_kPositive, _kGold, _kNegative],
      stops: const [0.0, 0.5, 1.0],
    );

    return _buildMoodFlowChart(isDark, entries, spots, timeLabels,
        moodAtIndex, yBound, lineGradient, height: 280);
  }

  /// Core line chart data (shared between inline and fullscreen).
  LineChartData _moodFlowChartData(bool isDark, int count,
      List<FlSpot> spots, Map<int, String> timeLabels,
      Map<int, Mood?> moodAtIndex, double yBound,
      LinearGradient lineGradient,
      {required String Function(int idx) tooltipLabel}) {
    return LineChartData(
      minX: 0, maxX: (count - 1).toDouble(),
      minY: -yBound, maxY: yBound,
      clipData: const FlClipData.all(),
      lineBarsData: [LineChartBarData(
        spots: spots,
        isCurved: true,
        preventCurveOverShooting: true,
        curveSmoothness: 0.35,
        gradient: lineGradient,
        barWidth: 3.5,
        isStrokeCapRound: true,
        shadow: Shadow(color: _kGold.withValues(alpha: 0.3),
            blurRadius: 8, offset: const Offset(0, 4)),
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, _, __, ___) {
            final mood = moodAtIndex[spot.x.toInt()];
            final c = mood != null ? Color(mood.colorValue) : _kGold;
            return FlDotCirclePainter(
              radius: 5, color: c,
              strokeWidth: 2.5,
              strokeColor: isDark ? const Color(0xFF1E2030) : Colors.white,
            );
          },
        ),
        belowBarData: BarAreaData(
          show: true, applyCutOffY: true, cutOffY: 0,
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [
              _kPositive.withValues(alpha: 0.18),
              _kPositive.withValues(alpha: 0.03),
            ],
          ),
        ),
        aboveBarData: BarAreaData(
          show: true, applyCutOffY: true, cutOffY: 0,
          gradient: LinearGradient(
            begin: Alignment.bottomCenter, end: Alignment.topCenter,
            colors: [
              _kNegative.withValues(alpha: 0.18),
              _kNegative.withValues(alpha: 0.03),
            ],
          ),
        ),
      )],
      extraLinesData: ExtraLinesData(horizontalLines: [
        HorizontalLine(
          y: 0,
          color: (isDark ? Colors.white : Colors.black)
              .withValues(alpha: 0.12),
          strokeWidth: 1.2,
          dashArray: [6, 4],
        ),
      ]),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          tooltipBgColor: isDark ? const Color(0xFF2E3142) : Colors.white,
          tooltipRoundedRadius: 12,
          tooltipPadding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 8),
          getTooltipItems: (touched) => touched.map((s) {
            final idx = s.spotIndex;
            final mood = moodAtIndex[idx];
            final emojiStr = mood?.emojiCharacter ?? '';
            final extra = tooltipLabel(idx);
            return LineTooltipItem(
              '$emojiStr ${mood?.name ?? '?'}\n$extra',
              TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87),
            );
          }).toList(),
        ),
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 32,
          interval: yBound > 3 ? (yBound / 3).ceilToDouble() : 1,
          getTitlesWidget: (val, _) {
            if (val == 0) return const SizedBox.shrink();
            final mood = _moodForScore(val);
            if (mood == null) return const SizedBox.shrink();
            return SizedBox(
              width: 28,
              child: Center(child: _moodEmoji(mood, size: 16)),
            );
          },
        )),
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 40,
          interval: 1,
          getTitlesWidget: (val, _) {
            final label = timeLabels[val.toInt()];
            if (label == null) return const SizedBox.shrink();
            return SideTitleWidget(
              axisSide: AxisSide.bottom,
              angle: -0.55,
              child: Text(label, style: TextStyle(fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white38 : Colors.black38)),
            );
          },
        )),
        topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: FlGridData(
        show: true, drawVerticalLine: false,
        horizontalInterval:
            yBound > 3 ? (yBound / 3).ceilToDouble() : 1,
        getDrawingHorizontalLine: (_) => FlLine(
          color: (isDark ? Colors.white : Colors.black)
              .withValues(alpha: 0.04),
          strokeWidth: 0.8,
        ),
      ),
      borderData: FlBorderData(show: false),
    );
  }

  /// Smart label picker: ensures labels never overlap by spacing them
  /// at least [minGap] indices apart.
  Map<int, String> _smartLabels(int count,
      String Function(int) labelOf, {int maxLabels = 6}) {
    final labels = <int, String>{};
    if (count <= maxLabels) {
      for (var i = 0; i < count; i++) labels[i] = labelOf(i);
      return labels;
    }
    labels[0] = labelOf(0);
    labels[count - 1] = labelOf(count - 1);
    final step = (count / (maxLabels - 1)).ceil().clamp(2, count);
    for (var i = step; i < count - 1; i += step) {
      labels[i] = labelOf(i);
    }
    return labels;
  }

  Widget _buildMoodFlowChart(bool isDark, List<MoodEntry> entries,
      List<FlSpot> spots, Map<int, String> _,
      Map<int, Mood?> moodAtIndex, double yBound,
      LinearGradient lineGradient, {double height = 280}) {
    final labels = _smartLabels(entries.length,
        (i) => DateFormat('h:mm a').format(entries[i].loggedAt));
    final chartData = _moodFlowChartData(isDark, entries.length, spots,
        labels, moodAtIndex, yBound, lineGradient,
        tooltipLabel: (i) =>
            DateFormat('h:mm a').format(entries[i].loggedAt));

    final needsScroll = entries.length > 8;
    final chartWidth = needsScroll
        ? (entries.length * 56.0).clamp(300.0, 4000.0) : double.infinity;

    if (!needsScroll) {
      return SizedBox(height: height, child: LineChart(chartData));
    }
    return SizedBox(
      height: height,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: SizedBox(
          width: chartWidth,
          height: height,
          child: LineChart(chartData),
        ),
      ),
    );
  }

  void _openMoodFlowFullscreen(bool isDark, List<MoodEntry> entries) {
    final spots = <FlSpot>[];
    final moodAtIndex = <int, Mood?>{};
    var yMax = 0.0;
    var yMin = 0.0;

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final mood = _moodById[entry.moodId];
      final score = (mood?.pointValue ?? 0).toDouble();
      spots.add(FlSpot(i.toDouble(), score));
      moodAtIndex[i] = mood;
      if (score > yMax) yMax = score;
      if (score < yMin) yMin = score;
    }

    final absMax = yMax.abs() > yMin.abs() ? yMax.abs() : yMin.abs();
    final yBound = (absMax + 1).ceilToDouble();
    final lineGradient = LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [_kPositive, _kGold, _kNegative],
      stops: const [0.0, 0.5, 1.0],
    );

    // In fullscreen, show ALL labels -- the wider chart has room
    final allLabels = <int, String>{};
    for (var i = 0; i < entries.length; i++) {
      allLabels[i] = DateFormat('h:mm a').format(entries[i].loggedAt);
    }

    final dateLabel =
        DateFormat('EEE, MMM d, yyyy').format(_selectedDailyDate);
    final screenH = MediaQuery.of(context).size.height;
    final chartH = screenH * 0.6;
    final chartW = (entries.length * 72.0).clamp(
        MediaQuery.of(context).size.width - 40, 6000.0);

    Navigator.of(context).push<void>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) {
        final chartData = _moodFlowChartData(isDark, entries.length, spots,
            allLabels, moodAtIndex, yBound, lineGradient,
            tooltipLabel: (i) =>
                DateFormat('h:mm a').format(entries[i].loggedAt));

        return Scaffold(
          backgroundColor: isDark
              ? const Color(0xFF1A1D2E) : const Color(0xFFF8F6F1),
          appBar: AppBar(
            backgroundColor: Colors.transparent, elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.close_rounded,
                  color: isDark ? Colors.white70 : Colors.black54),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Column(children: [
              Text('Mood Flow',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87)),
              Text(dateLabel,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white38 : Colors.black38)),
            ]),
            centerTitle: true,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(Icons.pinch_rounded, size: 18,
                    color: isDark ? Colors.white24 : Colors.black26),
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
              child: InteractiveViewer(
                boundaryMargin: const EdgeInsets.all(40),
                minScale: 0.8,
                maxScale: 4.0,
                child: SizedBox(
                  width: chartW,
                  height: chartH,
                  child: LineChart(chartData),
                ),
              ),
            ),
          ),
        );
      },
    ));
  }

  Widget _buildEntryTimeline(bool isDark, List<MoodEntry> entries) {
    return Column(
      children: entries.map((entry) {
        final mood = _moodById[entry.moodId];
        final time = DateFormat('h:mm a').format(entry.loggedAt);
        final reasonNames = entry.reasonIds
            .map((rid) => _reasonById[rid]?.name)
            .where((n) => n != null)
            .join(', ');

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.03)
                  : const Color(0xFFF5F5F7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: mood != null
                    ? Color(mood.colorValue).withValues(alpha: 0.2)
                    : Colors.transparent),
            ),
            child: Row(
              children: [
                _moodEmoji(mood, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(mood?.name ?? 'Unknown',
                          style: TextStyle(fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black87)),
                      if (reasonNames.isNotEmpty)
                        Text(reasonNames, style: TextStyle(fontSize: 11,
                            color: isDark ? Colors.white38 : Colors.black38),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (entry.customNote?.isNotEmpty == true)
                        Text(entry.customNote!, style: TextStyle(fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: isDark ? Colors.white30 : Colors.black26),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Text(time, style: TextStyle(fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white38 : Colors.black38)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ===================================================================
  //  TAB 1 - OVERVIEW (non-daily)
  // ===================================================================

  Widget _buildOverviewTab(bool isDark) {
    final summary = _summary;
    final analytics = _analytics;
    if (summary == null || analytics == null) {
      return _emptyState(isDark, 'No data available');
    }
    if (analytics.entriesCount == 0) {
      return _emptyState(isDark, 'No mood entries in this range');
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        _buildHeroCard(isDark, summary, analytics),
        const SizedBox(height: 16),
        _section(isDark, icon: Icons.show_chart_rounded, title: 'MOOD TREND',
            onExpand: analytics.scoreTimeline.length >= 2
                ? () => _openTimelineFullscreen(isDark, analytics)
                : null,
            child: _buildScoreLineChart(isDark, analytics)),
        const SizedBox(height: 16),
        _section(isDark, icon: Icons.pie_chart_rounded,
            title: 'MOOD DISTRIBUTION',
            child: _buildMoodPieChart(isDark, analytics)),
        const SizedBox(height: 16),
        _section(isDark, icon: Icons.balance_rounded,
            title: 'POSITIVE VS NEGATIVE',
            child: _buildPolarityBar(isDark, summary)),
        const SizedBox(height: 16),
        _section(isDark, icon: Icons.star_rounded, title: 'TOP PATTERNS',
            child: _buildTopPatterns(isDark, summary)),
      ],
    );
  }

  Widget _buildHeroCard(bool isDark, MoodSummaryResponse summary,
      MoodAnalyticsResponse analytics) {
    final dateRange =
        '${DateFormat('MMM d').format(summary.from)} – '
        '${DateFormat('MMM d, yyyy').format(summary.to)}';
    final topMood = summary.mostFrequentMoodId != null
        ? _moodById[summary.mostFrequentMoodId] : null;

    // Resolve high/low to moods
    final highMood = analytics.highPoint != null
        ? _moodForScore(analytics.highPoint!.score) : null;
    final lowMood = analytics.lowPoint != null
        ? _moodForScore(analytics.lowPoint!.score) : null;
    final avgMood = _moodForScore(
        analytics.scoreTimeline.isNotEmpty
            ? analytics.scoreTimeline.map((s) => s.score).reduce((a, b) =>
                a + b) / analytics.scoreTimeline.length
            : 0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF2E3142), const Color(0xFF252836)]
              : [const Color(0xFFFBF8F0), const Color(0xFFF5F0E4)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kGold.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dateRange, style: TextStyle(fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white54 : Colors.black45)),
                    const SizedBox(height: 4),
                    Text('${analytics.entriesCount} entries',
                        style: TextStyle(fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : Colors.black87)),
                  ],
                ),
              ),
              if (topMood != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(topMood.colorValue).withValues(alpha: 0.15),
                    shape: BoxShape.circle),
                  child: _moodEmoji(topMood, size: 28),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _heroMoodStat(isDark, 'Average', avgMood),
              _heroMoodStat(isDark, 'Best', highMood, color: _kPositive),
              _heroMoodStat(isDark, 'Lowest', lowMood, color: _kNegative),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroMoodStat(bool isDark, String label, Mood? mood,
      {Color? color}) {
    return Expanded(
      child: Column(
        children: [
          _moodEmoji(mood, size: 24),
          const SizedBox(height: 4),
          Text(mood?.name ?? '—', style: TextStyle(fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color ?? (mood != null
                  ? Color(mood.colorValue) : _kGold)),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 9,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white38 : Colors.black38)),
        ],
      ),
    );
  }

  // -- Score line chart (mood-flow style for weekly/monthly/custom/lifetime) --

  Widget _buildScoreLineChart(bool isDark, MoodAnalyticsResponse analytics) {
    final timeline = analytics.scoreTimeline;
    if (timeline.isEmpty) return _chartEmpty(isDark, 'No trend data');

    final spots = <FlSpot>[];
    final xLabels = <int, String>{};
    final moodAtIndex = <int, Mood?>{};
    var yMax = 0.0;
    var yMin = 0.0;

    for (var i = 0; i < timeline.length; i++) {
      final score = timeline[i].score;
      spots.add(FlSpot(i.toDouble(), score));
      moodAtIndex[i] = _moodForScore(score);
      if (score > yMax) yMax = score;
      if (score < yMin) yMin = score;

      if (timeline.length <= 10 || i == 0 || i == timeline.length - 1 ||
          i % (timeline.length ~/ 6).clamp(1, 999) == 0) {
        xLabels[i] = timeline[i].label;
      }
    }

    final absMax = yMax.abs() > yMin.abs() ? yMax.abs() : yMin.abs();
    final yBound = (absMax + 1).ceilToDouble();
    final lineGradient = LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [_kPositive, _kGold, _kNegative],
      stops: const [0.0, 0.5, 1.0],
    );

    return _buildMoodFlowChartFromTimeline(isDark, spots, xLabels,
        moodAtIndex, yBound, lineGradient, timeline, height: 280);
  }

  Widget _buildMoodFlowChartFromTimeline(bool isDark, List<FlSpot> spots,
      Map<int, String> xLabels, Map<int, Mood?> moodAtIndex,
      double yBound, LinearGradient lineGradient,
      List<({String label, double score})> timeline,
      {double height = 280}) {
    final chartData = _moodFlowChartData(isDark, spots.length, spots,
        xLabels, moodAtIndex, yBound, lineGradient,
        tooltipLabel: (i) => timeline[i].label);

    final needsScroll = spots.length > 10;
    final chartW = needsScroll
        ? (spots.length * 56.0).clamp(300.0, 4000.0) : double.infinity;

    if (!needsScroll) {
      return SizedBox(height: height, child: LineChart(chartData));
    }
    return SizedBox(
      height: height,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: SizedBox(
          width: chartW,
          height: height,
          child: LineChart(chartData),
        ),
      ),
    );
  }

  void _openTimelineFullscreen(bool isDark, MoodAnalyticsResponse analytics) {
    final timeline = analytics.scoreTimeline;
    if (timeline.isEmpty) return;

    final spots = <FlSpot>[];
    final moodAtIndex = <int, Mood?>{};
    var yMax = 0.0;
    var yMin = 0.0;

    for (var i = 0; i < timeline.length; i++) {
      final score = timeline[i].score;
      spots.add(FlSpot(i.toDouble(), score));
      moodAtIndex[i] = _moodForScore(score);
      if (score > yMax) yMax = score;
      if (score < yMin) yMin = score;
    }

    final absMax = yMax.abs() > yMin.abs() ? yMax.abs() : yMin.abs();
    final yBound = (absMax + 1).ceilToDouble();
    final lineGradient = LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [_kPositive, _kGold, _kNegative],
      stops: const [0.0, 0.5, 1.0],
    );

    // All labels visible in fullscreen
    final allLabels = <int, String>{};
    for (var i = 0; i < timeline.length; i++) {
      allLabels[i] = timeline[i].label;
    }

    final rangeLabel = _rangeOption == _RangeOption.weekly ? 'Weekly'
        : _rangeOption == _RangeOption.monthly ? 'Monthly'
        : _rangeOption == _RangeOption.lifetime ? 'Lifetime'
        : 'Custom';

    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    final chartH = screenH * 0.6;
    final chartW = (timeline.length * 72.0).clamp(screenW - 40, 6000.0);

    Navigator.of(context).push<void>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) {
        final chartData = _moodFlowChartData(isDark, spots.length, spots,
            allLabels, moodAtIndex, yBound, lineGradient,
            tooltipLabel: (i) => timeline[i].label);

        return Scaffold(
          backgroundColor:
              isDark ? const Color(0xFF1A1D2E) : const Color(0xFFF8F6F1),
          appBar: AppBar(
            backgroundColor: Colors.transparent, elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.close_rounded,
                  color: isDark ? Colors.white70 : Colors.black54),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Column(children: [
              Text('Mood Trend',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87)),
              Text(rangeLabel,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white38 : Colors.black38)),
            ]),
            centerTitle: true,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(Icons.pinch_rounded, size: 18,
                    color: isDark ? Colors.white24 : Colors.black26),
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
              child: InteractiveViewer(
                boundaryMargin: const EdgeInsets.all(40),
                minScale: 0.8,
                maxScale: 4.0,
                child: SizedBox(
                  width: chartW,
                  height: chartH,
                  child: LineChart(chartData),
                ),
              ),
            ),
          ),
        );
      },
    ));
  }

  // -- Mood distribution pie --

  Widget _buildMoodPieChart(bool isDark, MoodAnalyticsResponse analytics) {
    if (analytics.moodDistribution.isEmpty) {
      return _chartEmpty(isDark, 'No mood data');
    }
    final sorted = analytics.moodDistribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = sorted.fold<int>(0, (s, e) => s + e.value).clamp(1, 999999);

    final sections = <PieChartSectionData>[];
    final legend = <({String name, Color color, double pct, Widget icon})>[];

    for (final entry in sorted) {
      final mood = _moodById[entry.key];
      final color = mood != null ? Color(mood.colorValue) : Colors.grey;
      final pct = entry.value / total * 100;
      sections.add(PieChartSectionData(value: entry.value.toDouble(),
          title: '', color: color, radius: 28, showTitle: false));
      legend.add((name: mood?.name ?? '?', color: color, pct: pct,
          icon: _moodEmoji(mood, size: 14)));
    }

    return SizedBox(
      height: 220,
      child: Row(children: [
        Expanded(flex: 4, child: PieChart(PieChartData(
            sections: sections, sectionsSpace: 3, centerSpaceRadius: 36))),
        const SizedBox(width: 12),
        Expanded(flex: 6, child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: legend.take(8).map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(
                    color: item.color, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                item.icon,
                const SizedBox(width: 4),
                Expanded(child: Text(item.name, style: TextStyle(fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black54),
                    overflow: TextOverflow.ellipsis)),
                Text('${item.pct.toStringAsFixed(0)}%', style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87)),
              ]),
            )).toList(),
          ),
        )),
      ]),
    );
  }

  // -- Polarity bar --

  Widget _buildPolarityBar(bool isDark, MoodSummaryResponse summary) {
    final pos = summary.positivePercent;
    final neg = summary.negativePercent;
    final total = (pos + neg).clamp(1, 100).toDouble();
    final pf = ((pos / total) * 100).round().clamp(1, 99);
    final nf = (100 - pf).clamp(1, 99);
    return Column(children: [
      ClipRRect(borderRadius: BorderRadius.circular(8),
        child: Row(children: [
          Expanded(flex: pf, child: Container(height: 14, color: _kPositive)),
          Expanded(flex: nf, child: Container(height: 14, color: _kNegative)),
        ])),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: Text('Positive: ${pos.toStringAsFixed(0)}%',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                color: _kPositive))),
        Expanded(child: Text('Negative: ${neg.toStringAsFixed(0)}%',
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                color: _kNegative))),
      ]),
    ]);
  }

  // -- Top patterns --

  Widget _buildTopPatterns(bool isDark, MoodSummaryResponse summary) {
    return Column(children: [
      _patternRow(isDark, label: 'Most frequent mood',
          value: summary.mostFrequentMoodName ?? 'No data',
          mood: summary.mostFrequentMoodId != null
              ? _moodById[summary.mostFrequentMoodId] : null),
      const SizedBox(height: 8),
      _patternRow(isDark, label: 'Most frequent reason',
          value: summary.mostFrequentReasonName ?? 'No data',
          reason: summary.mostFrequentReasonId != null
              ? _reasonById[summary.mostFrequentReasonId] : null),
    ]);
  }

  Widget _patternRow(bool isDark, {required String label,
      required String value, Mood? mood, MoodReason? reason}) {
    Widget? iconW;
    if (mood != null) {
      iconW = _moodEmoji(mood, size: 20);
    } else if (reason != null) {
      final hasEmoji = reason.emojiCharacter.isNotEmpty;
      iconW = hasEmoji
          ? Text(reason.emojiCharacter, style: const TextStyle(fontSize: 20))
          : (reason.iconCodePoint > 0
              ? Icon(reason.icon, color: Color(reason.colorValue), size: 20)
              : Icon(Icons.help_outline_rounded,
                  color: Color(reason.colorValue), size: 20));
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03)
            : const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Expanded(child: Text(label, style: TextStyle(fontSize: 12,
            color: isDark ? Colors.white60 : Colors.black54))),
        if (iconW != null) ...[iconW, const SizedBox(width: 8)],
        Flexible(child: Text(value, textAlign: TextAlign.right,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87))),
      ]),
    );
  }

  // ===================================================================
  //  TAB 2 - REASONS
  // ===================================================================

  Widget _buildReasonsTab(bool isDark) {
    final analytics = _analytics;
    if (analytics == null || analytics.entriesCount == 0) {
      return _emptyState(isDark, 'No reason data available');
    }
    if (analytics.reasonDistribution.isEmpty) {
      return _emptyState(isDark, 'No reasons logged in this range');
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        _section(isDark, icon: Icons.bar_chart_rounded,
            title: 'REASON FREQUENCY',
            child: _buildReasonRanking(isDark, analytics)),
        const SizedBox(height: 16),
        if (analytics.reasonTimeline.isNotEmpty) ...[
          _section(isDark, icon: Icons.timeline_rounded,
              title: 'REASONS OVER TIME',
              child: _buildReasonTimeline(isDark, analytics)),
          const SizedBox(height: 16),
        ],
        _section(isDark, icon: Icons.grid_view_rounded,
            title: 'REASON-MOOD MATRIX',
            child: _buildReasonMoodMatrix(isDark, analytics)),
        const SizedBox(height: 16),
        _section(isDark, icon: Icons.sentiment_satisfied_alt_rounded,
            title: 'REASON POLARITY',
            child: _buildReasonPolarity(isDark, analytics)),
      ],
    );
  }

  Widget _buildReasonRanking(bool isDark, MoodAnalyticsResponse analytics) {
    final sorted = analytics.reasonDistribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final display = sorted.take(10).toList();
    final maxCount = display.isNotEmpty ? display.first.value.toDouble() : 1.0;

    return Column(children: display.map((entry) {
      final reason = _reasonById[entry.key];
      final name = reason?.name ?? 'Unknown';
      final color = reason != null ? Color(reason.colorValue) : Colors.grey;
      final pct = maxCount > 0 ? entry.value / maxCount : 0.0;

      Widget? icon;
      if (reason != null) {
        icon = reason.emojiCharacter.isNotEmpty
            ? Text(reason.emojiCharacter, style: const TextStyle(fontSize: 16))
            : (reason.iconCodePoint > 0
                ? Icon(reason.icon, color: color, size: 16) : null);
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (icon != null) ...[icon, const SizedBox(width: 6)],
            Expanded(child: Text(name, style: TextStyle(fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black54),
                overflow: TextOverflow.ellipsis)),
            Text('${entry.value}x', style: TextStyle(fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: pct.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: (isDark ? Colors.white : Colors.black)
                  .withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation(color))),
        ]),
      );
    }).toList());
  }

  Widget _buildReasonTimeline(bool isDark, MoodAnalyticsResponse analytics) {
    final timeline = analytics.reasonTimeline;
    if (timeline.isEmpty) return _chartEmpty(isDark, 'No timeline data');

    const colorPalette = [_kGold, _kPositive, Color(0xFF2196F3),
        Color(0xFF9C27B0), _kNegative];
    final allLabels = <String>[];
    for (final list in timeline.values) {
      for (final pt in list) {
        if (!allLabels.contains(pt.label)) allLabels.add(pt.label);
      }
    }
    final labelIdx = <int, String>{};
    for (var i = 0; i < allLabels.length; i++) {
      if (allLabels.length <= 7 || i == 0 || i == allLabels.length - 1 ||
          i % (allLabels.length ~/ 5).clamp(1, 999) == 0) {
        labelIdx[i] = allLabels[i];
      }
    }
    var maxCount = 1.0;
    final lineBars = <LineChartBarData>[];
    final legendItems = <({String name, Color color})>[];
    var ci = 0;
    for (final rid in timeline.keys) {
      final data = timeline[rid]!;
      final color = colorPalette[ci % colorPalette.length];
      ci++;
      legendItems.add((name: _reasonById[rid]?.name ?? '?', color: color));
      final spots = <FlSpot>[];
      for (var i = 0; i < allLabels.length; i++) {
        final match = data.where((d) => d.label == allLabels[i]);
        final count = match.isNotEmpty ? match.first.count.toDouble() : 0.0;
        if (count > maxCount) maxCount = count;
        spots.add(FlSpot(i.toDouble(), count));
      }
      lineBars.add(LineChartBarData(spots: spots, isCurved: true,
          preventCurveOverShooting: true, color: color, barWidth: 2.5,
          isStrokeCapRound: true,
          dotData: FlDotData(show: allLabels.length <= 14),
          belowBarData: BarAreaData(show: false)));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(height: 200, child: LineChart(LineChartData(
        minX: 0, maxX: (allLabels.length - 1).toDouble().clamp(0, 9999),
        minY: 0, maxY: maxCount * 1.2, lineBarsData: lineBars,
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (val, _) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(val.toStringAsFixed(0), style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white38 : Colors.black38))))),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (val, _) {
                final label = labelIdx[val.toInt()];
                if (label == null) return const SizedBox.shrink();
                return Padding(padding: const EdgeInsets.only(top: 8),
                    child: Text(label, style: TextStyle(fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white38 : Colors.black38)));
              })),
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(show: true, drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
                color: (isDark ? Colors.white : Colors.black)
                    .withValues(alpha: 0.06), strokeWidth: 1)),
        borderData: FlBorderData(show: false),
      ))),
      const SizedBox(height: 12),
      Wrap(spacing: 16, runSpacing: 6, children: legendItems.map((e) =>
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(
                color: e.color, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(e.name, style: TextStyle(fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white60 : Colors.black54)),
          ])).toList()),
    ]);
  }

  Widget _buildReasonMoodMatrix(bool isDark, MoodAnalyticsResponse analytics) {
    final matrix = analytics.reasonMoodMatrix;
    if (matrix.isEmpty) return _chartEmpty(isDark, 'No co-occurrence data');
    final moodIds = <String>{};
    for (final m in matrix.values) moodIds.addAll(m.keys);
    final moodList = moodIds.where((id) => _moodById.containsKey(id)).toList();
    final reasonEntries = matrix.entries.toList()..sort((a, b) {
      final at = a.value.values.fold<int>(0, (s, v) => s + v);
      final bt = b.value.values.fold<int>(0, (s, v) => s + v);
      return bt.compareTo(at);
    });
    final display = reasonEntries.take(8).toList();
    var maxVal = 1;
    for (final e in display) {
      for (final c in e.value.values) { if (c > maxVal) maxVal = c; }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const SizedBox(width: 100),
          ...moodList.map((id) {
            final mood = _moodById[id]!;
            return SizedBox(width: 48, child: Center(
                child: _moodEmoji(mood, size: 16)));
          }),
        ]),
        const SizedBox(height: 6),
        ...display.map((entry) {
          final name = _reasonById[entry.key]?.name ?? '?';
          return Padding(padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [
              SizedBox(width: 100, child: Text(name, style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white60 : Colors.black54),
                  overflow: TextOverflow.ellipsis)),
              ...moodList.map((moodId) {
                final count = entry.value[moodId] ?? 0;
                final intensity = maxVal > 0
                    ? (count / maxVal).clamp(0.0, 1.0) : 0.0;
                final baseColor = Color(_moodById[moodId]!.colorValue);
                return Container(width: 44, height: 32,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: count > 0
                        ? baseColor.withValues(alpha: 0.15 + intensity * 0.65)
                        : (isDark ? Colors.white.withValues(alpha: 0.03)
                            : Colors.black.withValues(alpha: 0.03)),
                    borderRadius: BorderRadius.circular(6)),
                  child: Center(child: Text(count > 0 ? '$count' : '',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                          color: count > 0
                              ? (isDark ? Colors.white : Colors.black87)
                              : Colors.transparent))));
              }),
            ]),
          );
        }),
      ]),
    );
  }

  Widget _buildReasonPolarity(bool isDark, MoodAnalyticsResponse analytics) {
    var goodCount = 0, badCount = 0;
    final goodReasons = <String, int>{};
    final badReasons = <String, int>{};
    for (final e in analytics.reasonDistribution.entries) {
      final r = _reasonById[e.key];
      if (r == null) continue;
      if (r.isGood) { goodCount += e.value; goodReasons[e.key] = e.value; }
      else { badCount += e.value; badReasons[e.key] = e.value; }
    }
    final total = (goodCount + badCount).clamp(1, 999999);
    final gp = (goodCount / total * 100).round();
    final bp = 100 - gp;

    return Column(children: [
      ClipRRect(borderRadius: BorderRadius.circular(8),
        child: Row(children: [
          Expanded(flex: gp.clamp(1, 99),
              child: Container(height: 14, color: _kPositive)),
          Expanded(flex: bp.clamp(1, 99),
              child: Container(height: 14, color: _kNegative)),
        ])),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: Text('Positive: $gp%', style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700, color: _kPositive))),
        Expanded(child: Text('Negative: $bp%', textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                color: _kNegative))),
      ]),
      const SizedBox(height: 14),
      if (goodReasons.isNotEmpty)
        _polarityList(isDark, 'Top positive', goodReasons, _kPositive),
      if (badReasons.isNotEmpty) ...[
        const SizedBox(height: 10),
        _polarityList(isDark, 'Top negative', badReasons, _kNegative),
      ],
    ]);
  }

  Widget _polarityList(bool isDark, String heading,
      Map<String, int> reasons, Color color) {
    final sorted = reasons.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(heading, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
          color: color.withValues(alpha: 0.8), letterSpacing: 0.5)),
      const SizedBox(height: 6),
      ...sorted.take(5).map((e) {
        final r = _reasonById[e.key];
        return Padding(padding: const EdgeInsets.only(bottom: 4),
          child: Row(children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(
                color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(child: Text(r?.name ?? '?', style: TextStyle(fontSize: 12,
                color: isDark ? Colors.white60 : Colors.black54),
                overflow: TextOverflow.ellipsis)),
            Text('${e.value}x', style: TextStyle(fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87)),
          ]));
      }),
    ]);
  }

  // ===================================================================
  //  SHARED HELPERS
  // ===================================================================

  Widget _section(bool isDark, {required IconData icon,
      required String title, required Widget child,
      VoidCallback? onExpand}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark ? null : [BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 16, color: _kGold),
          const SizedBox(width: 8),
          Text(title, style: _labelStyle()),
          if (onExpand != null) ...[
            const Spacer(),
            GestureDetector(
              onTap: onExpand,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _kGold.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.fullscreen_rounded, size: 18,
                    color: _kGold),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }

  Widget _emptyState(bool isDark, String message) {
    return Center(child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.mood_rounded, size: 48,
            color: isDark ? Colors.white24 : Colors.black12),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14,
                color: isDark ? Colors.white38 : Colors.black38)),
      ]),
    ));
  }

  Widget _chartEmpty(bool isDark, String message) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(child: Text(message, style: TextStyle(fontSize: 13,
          color: isDark ? Colors.white38 : Colors.black38))));
  }

  TextStyle _labelStyle() => const TextStyle(fontSize: 11,
      fontWeight: FontWeight.w900, color: _kGold, letterSpacing: 1.2);
}
