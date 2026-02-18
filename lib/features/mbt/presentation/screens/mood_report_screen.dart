import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/dark_gradient.dart';
import '../../data/services/mood_api_service.dart';
import '../../mbt_module.dart';

enum MoodReportRangeOption { weekly, monthly, custom, lifetime }

class MoodReportScreen extends StatefulWidget {
  const MoodReportScreen({super.key});

  @override
  State<MoodReportScreen> createState() => _MoodReportScreenState();
}

class _MoodReportScreenState extends State<MoodReportScreen> {
  final MoodApiService _api = MoodApiService();

  bool _loading = true;
  String? _error;
  MoodReportRangeOption _rangeOption = MoodReportRangeOption.weekly;
  DateTime _customFrom = DateTime.now().subtract(const Duration(days: 6));
  DateTime _customTo = DateTime.now();

  MoodSummaryResponse? _summary;
  MoodTrendsResponse? _trends;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
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
      final summaryFuture = _api.getMoodSummary(
        range: request.range,
        from: request.from,
        to: request.to,
      );
      final trendsFuture = _api.getMoodTrends(
        range: request.range,
        from: request.from,
        to: request.to,
      );
      final summary = await summaryFuture;
      final trends = await trendsFuture;

      if (!mounted) return;
      setState(() {
        _summary = summary;
        _trends = trends;
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
      case MoodReportRangeOption.weekly:
        return (range: MoodRange.weekly, from: null, to: null);
      case MoodReportRangeOption.monthly:
        return (range: MoodRange.monthly, from: null, to: null);
      case MoodReportRangeOption.custom:
        return (range: MoodRange.custom, from: _customFrom, to: _customTo);
      case MoodReportRangeOption.lifetime:
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
        if (_customTo.isBefore(_customFrom)) {
          _customTo = _customFrom;
        }
      } else {
        _customTo = DateTime(picked.year, picked.month, picked.day);
        if (_customTo.isBefore(_customFrom)) {
          _customFrom = _customTo;
        }
      }
    });
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final content = _buildContent(context, isDark);
    return Scaffold(body: isDark ? DarkGradient.wrap(child: content) : content);
  }

  Widget _buildContent(BuildContext context, bool isDark) {
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
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          _buildRangeChips(isDark),
          if (_rangeOption == MoodReportRangeOption.custom) ...[
            const SizedBox(height: 12),
            _buildCustomRangeRow(isDark),
          ],
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            _buildOverviewCard(isDark),
            const SizedBox(height: 12),
            _buildAveragesCard(isDark),
            const SizedBox(height: 12),
            _buildPolarityCard(isDark),
            const SizedBox(height: 12),
            _buildFrequencyCard(isDark),
            const SizedBox(height: 12),
            _buildTrendCard(isDark),
          ],
          if (_error?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRangeChips(bool isDark) {
    final options = <(MoodReportRangeOption, String)>[
      (MoodReportRangeOption.weekly, 'Weekly'),
      (MoodReportRangeOption.monthly, 'Monthly'),
      (MoodReportRangeOption.custom, 'Custom'),
      (MoodReportRangeOption.lifetime, 'Lifetime'),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: options
            .map(
              (item) => Expanded(
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
                      color: _rangeOption == item.$1
                          ? const Color(0xFFCDAF56)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      item.$2,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: _rangeOption == item.$1
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: _rangeOption == item.$1
                            ? const Color(0xFF1E1E1E)
                            : (isDark ? Colors.white70 : Colors.black54),
                      ),
                    ),
                  ),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Widget _buildCustomRangeRow(bool isDark) {
    String format(DateTime date) => DateFormat('MMM d, yyyy').format(date);

    Widget rangeButton({
      required String label,
      required DateTime value,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFCDAF56),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  format(value),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        rangeButton(
          label: 'FROM',
          value: _customFrom,
          onTap: () => _pickCustomDate(isFrom: true),
        ),
        const SizedBox(width: 8),
        rangeButton(
          label: 'TO',
          value: _customTo,
          onTap: () => _pickCustomDate(isFrom: false),
        ),
      ],
    );
  }

  Widget _buildOverviewCard(bool isDark) {
    final summary = _summary;
    if (summary == null) return const SizedBox.shrink();

    return _card(
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('REPORT RANGE', style: _labelStyle()),
          const SizedBox(height: 8),
          Text(
            '${DateFormat('MMM d, yyyy').format(summary.from)} - ${DateFormat('MMM d, yyyy').format(summary.to)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Entries: ${summary.entriesCount}',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAveragesCard(bool isDark) {
    final summary = _summary;
    if (summary == null) return const SizedBox.shrink();
    return _card(
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AVERAGES', style: _labelStyle()),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _avgTile(
                  isDark: isDark,
                  label: 'Daily',
                  value: '${summary.dailyScore}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _avgTile(
                  isDark: isDark,
                  label: 'Weekly',
                  value: summary.weeklyAverage.toStringAsFixed(2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _avgTile(
                  isDark: isDark,
                  label: 'Monthly',
                  value: summary.monthlyAverage.toStringAsFixed(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _avgTile(
                  isDark: isDark,
                  label: 'Lifetime',
                  value: summary.lifetimeAverage.toStringAsFixed(2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPolarityCard(bool isDark) {
    final summary = _summary;
    if (summary == null) return const SizedBox.shrink();

    final positive = summary.positivePercent;
    final negative = summary.negativePercent;
    final total = (positive + negative).clamp(1, 100).toDouble();
    final positiveFlex = ((positive / total) * 100).round().clamp(1, 99);
    final negativeFlex = (100 - positiveFlex).clamp(1, 99);

    return _card(
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('POSITIVE VS NEGATIVE', style: _labelStyle()),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                Expanded(
                  flex: positiveFlex,
                  child: Container(height: 10, color: const Color(0xFF4CAF50)),
                ),
                Expanded(
                  flex: negativeFlex,
                  child: Container(height: 10, color: const Color(0xFFE53935)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Positive: ${positive.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF4CAF50),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'Negative: ${negative.toStringAsFixed(0)}%',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFE53935),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFrequencyCard(bool isDark) {
    final summary = _summary;
    if (summary == null) return const SizedBox.shrink();

    return _card(
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TOP PATTERNS', style: _labelStyle()),
          const SizedBox(height: 10),
          _frequencyRow(
            isDark,
            label: 'Most frequent mood',
            value: summary.mostFrequentMoodName ?? 'No data',
          ),
          const SizedBox(height: 8),
          _frequencyRow(
            isDark,
            label: 'Most frequent reason',
            value: summary.mostFrequentReasonName ?? 'No data',
          ),
        ],
      ),
    );
  }

  Widget _buildTrendCard(bool isDark) {
    final trends = _trends;
    if (trends == null || trends.dayScoreMap.isEmpty) {
      return _card(
        isDark,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('DAILY TREND', style: _labelStyle()),
            const SizedBox(height: 10),
            Text(
              'No trend points in this range.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      );
    }

    final points = trends.dayScoreMap.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final maxAbs = points
        .map((entry) => entry.value.abs())
        .fold<int>(1, (a, b) => math.max(a, b));
    final recent = points.length <= 21
        ? points
        : points.sublist(points.length - 21);

    return _card(
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('DAILY TREND', style: _labelStyle()),
          const SizedBox(height: 8),
          ...recent.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _trendRow(
                isDark: isDark,
                label: _formatDayKey(entry.key),
                value: entry.value,
                maxAbs: maxAbs,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avgTile({
    required bool isDark,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: const Color(0xFFCDAF56),
            ),
          ),
        ],
      ),
    );
  }

  Widget _frequencyRow(
    bool isDark, {
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _trendRow({
    required bool isDark,
    required String label,
    required int value,
    required int maxAbs,
  }) {
    final ratio = value.abs() / math.max(1, maxAbs);
    final widthFactor = ratio.clamp(0.05, 1.0).toDouble();
    final color = value >= 0
        ? const Color(0xFF4CAF50)
        : const Color(0xFFE53935);

    return Row(
      children: [
        SizedBox(
          width: 78,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: widthFactor,
              child: Container(
                height: 10,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 42,
          child: Text(
            '$value',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _card(bool isDark, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: child,
    );
  }

  TextStyle _labelStyle() {
    return const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w900,
      color: Color(0xFFCDAF56),
      letterSpacing: 1.1,
    );
  }

  String _formatDayKey(String dayKey) {
    if (dayKey.length != 8) return dayKey;
    final year = int.tryParse(dayKey.substring(0, 4));
    final month = int.tryParse(dayKey.substring(4, 6));
    final day = int.tryParse(dayKey.substring(6, 8));
    if (year == null || month == null || day == null) return dayKey;
    return DateFormat('MMM d').format(DateTime(year, month, day));
  }
}
