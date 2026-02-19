import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/dark_gradient.dart';
import '../../behavior_module.dart';
import '../../data/services/behavior_api_service.dart';

enum BehaviorReportRange { weekly, monthly, custom, lifetime }
enum BehaviorReportTypeFilter { all, good, bad }

class BehaviorReportScreen extends StatefulWidget {
  const BehaviorReportScreen({super.key});

  @override
  State<BehaviorReportScreen> createState() => _BehaviorReportScreenState();
}

class _BehaviorReportScreenState extends State<BehaviorReportScreen> {
  final BehaviorApiService _api = BehaviorApiService();

  bool _loading = true;
  String? _error;
  BehaviorReportRange _range = BehaviorReportRange.weekly;
  BehaviorReportTypeFilter _typeFilter = BehaviorReportTypeFilter.all;
  DateTime _customFrom = DateTime.now().subtract(const Duration(days: 6));
  DateTime _customTo = DateTime.now();

  BehaviorSummaryResponse? _summary;
  List<BehaviorTopReasonItem> _topReasons = const <BehaviorTopReasonItem>[];

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    await BehaviorModule.init(preOpenBoxes: true);
    await _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final range = _resolveRange();
      final type = _typeFilter == BehaviorReportTypeFilter.all
          ? null
          : _typeFilter.name;
      final summaryFuture = _api.getBehaviorSummary(
        from: range.$1,
        to: range.$2,
        type: type,
      );
      final reasonsFuture = _api.getBehaviorTopReasons(
        from: range.$1,
        to: range.$2,
        type: type,
      );
      final summary = await summaryFuture;
      final reasons = await reasonsFuture;
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _topReasons = reasons;
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

  (DateTime, DateTime) _resolveRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_range) {
      case BehaviorReportRange.weekly:
        return (today.subtract(const Duration(days: 6)), today);
      case BehaviorReportRange.monthly:
        return (today.subtract(const Duration(days: 29)), today);
      case BehaviorReportRange.custom:
        return (
          DateTime(_customFrom.year, _customFrom.month, _customFrom.day),
          DateTime(_customTo.year, _customTo.month, _customTo.day),
        );
      case BehaviorReportRange.lifetime:
        return (DateTime(2000, 1, 1), today);
    }
  }

  Future<void> _pickCustomDate({required bool isFrom}) async {
    final initial = isFrom ? _customFrom : _customTo;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000, 1, 1),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final content = Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Behavior Report'),
        actions: [
          IconButton(
            onPressed: _loading ? null : () => unawaited(_reload()),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        children: [
          _rangeSelector(isDark),
          if (_range == BehaviorReportRange.custom) ...[
            const SizedBox(height: 10),
            _customRangeRow(isDark),
          ],
          const SizedBox(height: 12),
          _typeSelector(isDark),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFFCDAF56)),
              ),
            )
          else ...[
            _overviewCard(isDark),
            const SizedBox(height: 12),
            _behaviorBreakdownCard(isDark),
            const SizedBox(height: 12),
            _topReasonsCard(isDark),
          ],
          if (_error?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
    return Scaffold(body: isDark ? DarkGradient.wrap(child: content) : content);
  }

  Widget _rangeSelector(bool isDark) {
    final options = <(BehaviorReportRange, String)>[
      (BehaviorReportRange.weekly, 'Weekly'),
      (BehaviorReportRange.monthly, 'Monthly'),
      (BehaviorReportRange.custom, 'Custom'),
      (BehaviorReportRange.lifetime, 'Lifetime'),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: options.map((option) {
          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (_range == option.$1) return;
                setState(() => _range = option.$1);
                unawaited(_reload());
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _range == option.$1
                      ? const Color(0xFFCDAF56)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  option.$2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: _range == option.$1
                        ? FontWeight.w800
                        : FontWeight.w600,
                    color: _range == option.$1
                        ? const Color(0xFF1E1E1E)
                        : (isDark ? Colors.white70 : Colors.black54),
                  ),
                ),
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }

  Widget _customRangeRow(bool isDark) {
    Widget button({
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
              color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFCDAF56),
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  DateFormat('MMM d, yyyy').format(value),
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
        button(
          label: 'FROM',
          value: _customFrom,
          onTap: () => _pickCustomDate(isFrom: true),
        ),
        const SizedBox(width: 8),
        button(
          label: 'TO',
          value: _customTo,
          onTap: () => _pickCustomDate(isFrom: false),
        ),
      ],
    );
  }

  Widget _typeSelector(bool isDark) {
    final options = <(BehaviorReportTypeFilter, String)>[
      (BehaviorReportTypeFilter.all, 'All'),
      (BehaviorReportTypeFilter.good, 'Good'),
      (BehaviorReportTypeFilter.bad, 'Bad'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        return ChoiceChip(
          selected: _typeFilter == option.$1,
          onSelected: (_) {
            setState(() => _typeFilter = option.$1);
            unawaited(_reload());
          },
          label: Text(option.$2),
        );
      }).toList(growable: false),
    );
  }

  Widget _overviewCard(bool isDark) {
    final summary = _summary;
    final totalCount = summary?.items.fold<int>(
          0,
          (sum, item) => sum + item.totalCount,
        ) ??
        0;
    final totalDuration = summary?.items.fold<int>(
          0,
          (sum, item) => sum + item.totalDurationMinutes,
        ) ??
        0;
    return _card(
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'OVERVIEW',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFFCDAF56),
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Logs: $totalCount',
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          ),
          const SizedBox(height: 4),
          Text(
            'Duration: ${totalDuration}m',
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _behaviorBreakdownCard(bool isDark) {
    final items = _summary?.items ?? const <BehaviorSummaryItem>[];
    return _card(
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'BEHAVIORS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFFCDAF56),
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Text(
              'No behavior activity in this range.',
              style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
            )
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${item.behaviorName}: ${item.totalCount} logs, ${item.totalDurationMinutes}m, avg I ${item.averageIntensity.toStringAsFixed(1)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _topReasonsCard(bool isDark) {
    return _card(
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TOP REASONS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFFCDAF56),
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          if (_topReasons.isEmpty)
            Text(
              'No reasons in this range.',
              style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
            )
          else
            ..._topReasons.take(8).map(
              (reason) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${reason.reasonName}: ${reason.usageCount}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
            ),
        ],
      ),
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
}
