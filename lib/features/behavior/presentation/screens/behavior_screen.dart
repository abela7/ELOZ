import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/dark_gradient.dart';
import '../../../../core/widgets/date_navigator_widget.dart';
import '../../behavior_module.dart';
import '../../data/models/behavior.dart';
import '../../data/models/behavior_log.dart';
import '../../data/models/behavior_reason.dart';
import '../../data/services/behavior_api_service.dart';
import 'behavior_log_screen.dart';
import 'behavior_report_screen.dart';
import 'behavior_settings_screen.dart';

class BehaviorScreen extends StatefulWidget {
  const BehaviorScreen({super.key});

  @override
  State<BehaviorScreen> createState() => _BehaviorScreenState();
}

class _BehaviorScreenState extends State<BehaviorScreen> {
  final BehaviorApiService _api = BehaviorApiService();

  bool _loading = true;
  String? _error;
  DateTime _selectedDate = DateTime.now();
  List<Behavior> _behaviors = const <Behavior>[];
  List<BehaviorReason> _reasons = const <BehaviorReason>[];
  List<BehaviorLogWithReasons> _logs = const <BehaviorLogWithReasons>[];
  BehaviorSummaryResponse? _summary;
  List<BehaviorTopReasonItem> _topReasons = const <BehaviorTopReasonItem>[];

  Map<String, Behavior> get _behaviorById => <String, Behavior>{
    for (final behavior in _behaviors) behavior.id: behavior,
  };

  Map<String, BehaviorReason> get _reasonById => <String, BehaviorReason>{
    for (final reason in _reasons) reason.id: reason,
  };

  List<Behavior> get _activeBehaviors => _behaviors
      .where((behavior) => behavior.isActive && !behavior.isDeleted)
      .toList(growable: false);

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
      final from = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      ).subtract(const Duration(days: 6));
      final to = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

      final behaviorsFuture = _api.getBehaviors(includeInactive: true);
      final reasonsFuture = _api.getBehaviorReasons(includeInactive: true);
      final logsFuture = _api.getBehaviorLogsByDate(_selectedDate);
      final summaryFuture = _api.getBehaviorSummary(from: from, to: to);
      final topReasonsFuture = _api.getBehaviorTopReasons(from: from, to: to);

      final behaviors = await behaviorsFuture;
      final reasons = await reasonsFuture;
      final logs = await logsFuture;
      final summary = await summaryFuture;
      final topReasons = await topReasonsFuture;

      if (!mounted) return;
      setState(() {
        _behaviors = behaviors;
        _reasons = reasons;
        _logs = logs;
        _summary = summary;
        _topReasons = topReasons;
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

  Future<void> _openLog({BehaviorLogWithReasons? existing}) async {
    if (existing == null && _activeBehaviors.isEmpty) {
      _showError('Create at least one active behavior in Settings first.');
      return;
    }
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => BehaviorLogScreen(
          initialDate: _selectedDate,
          existingLog: existing,
        ),
      ),
    );
    if (changed == true && mounted) {
      await _reload();
    }
  }

  Future<void> _deleteLog(String logId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Log'),
        content: const Text('Delete this behavior log?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.deleteBehaviorLog(logId);
      if (mounted) await _reload();
    } catch (error) {
      _showError('Failed to delete log: $error');
    }
  }

  Future<void> _openSettings() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const BehaviorSettingsScreen()));
    if (mounted) await _reload();
  }

  Future<void> _openReport() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const BehaviorReportScreen()));
    if (mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final content = Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('MBT Behavior'),
        actions: [
          IconButton(
            onPressed: _loading ? null : () => unawaited(_reload()),
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            onPressed: () => unawaited(_openSettings()),
            icon: const Icon(Icons.settings_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFCDAF56),
        foregroundColor: const Color(0xFF1E1E1E),
        onPressed: _loading ? null : () => unawaited(_openLog()),
        child: const Icon(Icons.add_rounded),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFCDAF56)),
            )
          : RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
                children: [
                  DateNavigatorWidget(
                    selectedDate: _selectedDate,
                    onDateChanged: (date) {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedDate = date);
                      unawaited(_reload());
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTodayCard(isDark),
                  const SizedBox(height: 16),
                  _buildQuickActions(isDark),
                  const SizedBox(height: 16),
                  _buildSummaryCard(isDark),
                  const SizedBox(height: 16),
                  _buildTopReasonsCard(isDark),
                  if (_error?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                ],
              ),
            ),
    );
    return Scaffold(body: isDark ? DarkGradient.wrap(child: content) : content);
  }

  Widget _buildTodayCard(bool isDark) {
    final dateLabel = DateFormat('EEE, MMM d').format(_selectedDate);
    return _card(
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'TODAY LOG',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFCDAF56),
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              Text(
                dateLabel,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_logs.isEmpty)
            Text(
              'No logs yet. Tap + to add one.',
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            )
          else
            ..._logs.map((entry) {
              final log = entry.log;
              final behavior = _behaviorById[log.behaviorId];
              final name = behavior?.name ?? 'Unknown behavior';
              final color = Color(behavior?.colorValue ?? 0xFFCDAF56);
              final reasonText = entry.reasonIds
                  .map((id) => _reasonById[id]?.name)
                  .where((name) => name != null)
                  .join(', ');
              return InkWell(
                onTap: () => _openLog(existing: entry),
                onLongPress: () => _deleteLog(log.id),
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: isDark ? 0.20 : 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          behavior?.icon ?? Icons.track_changes_rounded,
                          color: color,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            if (reasonText.trim().isNotEmpty)
                              Text(
                                reasonText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white54 : Colors.black54,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('h:mm a').format(log.occurredAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildQuickActions(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _quickAction(
            isDark,
            label: 'Log',
            icon: Icons.add_task_rounded,
            onTap: () => unawaited(_openLog()),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _quickAction(
            isDark,
            label: 'Report',
            icon: Icons.analytics_rounded,
            onTap: () => unawaited(_openReport()),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _quickAction(
            isDark,
            label: 'Settings',
            icon: Icons.tune_rounded,
            onTap: () => unawaited(_openSettings()),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(bool isDark) {
    final items = _summary?.items ?? const <BehaviorSummaryItem>[];
    final totalCount = items.fold<int>(0, (sum, item) => sum + item.totalCount);
    return _card(
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'WEEKLY SUMMARY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFFCDAF56),
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Total logs: $totalCount',
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          ),
          const SizedBox(height: 6),
          ...items.take(4).map(
            (item) => Text(
              '${item.behaviorName}: ${item.totalCount}',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopReasonsCard(bool isDark) {
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
          const SizedBox(height: 10),
          if (_topReasons.isEmpty)
            Text(
              'No reasons in this range.',
              style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
            )
          else
            ..._topReasons.take(5).map(
              (reason) => Text(
                '${reason.reasonName}: ${reason.usageCount}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black54,
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

  Widget _quickAction(
    bool isDark, {
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFFCDAF56)),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
