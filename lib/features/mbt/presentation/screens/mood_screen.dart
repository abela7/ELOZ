import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/dark_gradient.dart';
import '../../../../core/widgets/date_navigator_widget.dart';
import '../../data/models/mood.dart';
import '../../data/models/mood_entry.dart';
import '../../data/models/mood_reason.dart';
import '../../data/services/mood_api_service.dart';
import '../../mbt_module.dart';
import 'mood_log_screen.dart';
import 'mood_report_screen.dart';
import 'mood_settings_screen.dart';

const Color _kGold = Color(0xFFCDAF56);
const Color _kPositive = Color(0xFF4CAF50);
const Color _kNegative = Color(0xFFE53935);

class MoodScreen extends StatefulWidget {
  const MoodScreen({super.key});

  @override
  State<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends State<MoodScreen> {
  final MoodApiService _api = MoodApiService();

  bool _loading = true;
  String? _error;
  int _moodFlowActiveIndex = 0;
  late final PageController _moodFlowController;

  DateTime _selectedDate = DateTime.now();
  List<Mood> _moods = const <Mood>[];
  List<MoodReason> _reasons = const <MoodReason>[];
  List<MoodEntry> _selectedEntries = const [];
  MoodSummaryResponse? _weeklySummary;
  MoodSummaryResponse? _monthlySummary;
  MoodTrendsResponse? _weeklyTrends;

  Map<String, Mood> get _moodById => <String, Mood>{
    for (final mood in _moods) mood.id: mood,
  };

  Map<String, MoodReason> get _reasonById => <String, MoodReason>{
    for (final reason in _reasons) reason.id: reason,
  };

  List<Mood> get _activeMoods => _moods
      .where((mood) => mood.isActive && !mood.isDeleted)
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _moodFlowController = PageController(viewportFraction: 0.22);
    unawaited(_initialize());
  }

  @override
  void dispose() {
    _moodFlowController.dispose();
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
      final moodsFuture = _api.getMoods(includeInactive: true);
      final reasonsFuture = _api.getReasons(includeInactive: true);
      final selectedEntriesFuture = _api.getMoodEntriesForDate(_selectedDate);
      final weeklySummaryFuture = _api.getMoodSummary(range: MoodRange.weekly);
      final monthlySummaryFuture = _api.getMoodSummary(
        range: MoodRange.monthly,
      );
      final weeklyTrendsFuture = _api.getMoodTrends(range: MoodRange.weekly);

      final moods = await moodsFuture;
      final reasons = await reasonsFuture;
      final selectedEntries = await selectedEntriesFuture;
      final weeklySummary = await weeklySummaryFuture;
      final monthlySummary = await monthlySummaryFuture;
      final weeklyTrends = await weeklyTrendsFuture;

      if (!mounted) return;
      setState(() {
        _moods = moods;
        _reasons = reasons;
        _selectedEntries = selectedEntries;
        _weeklySummary = weeklySummary;
        _monthlySummary = monthlySummary;
        _weeklyTrends = weeklyTrends;
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

  Future<void> _loadSelectedDateEntries() async {
    try {
      final entries = await _api.getMoodEntriesForDate(_selectedDate);
      if (!mounted) return;
      setState(() {
        _selectedEntries = entries;
        _moodFlowActiveIndex = 0;
      });
      if (_moodFlowController.hasClients) {
        _moodFlowController.jumpToPage(0);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    }
  }

  Future<void> _openLogScreen({String? entryId}) async {
    if (_activeMoods.isEmpty) {
      _showError('Add at least one active mood in Settings before logging.');
      return;
    }
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) =>
            MoodLogScreen(initialDate: _selectedDate, entryId: entryId),
      ),
    );
    if (changed == true && mounted) {
      await _reload();
    }
  }

  Future<void> _deleteEntry(MoodEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text('Remove this mood entry? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await _api.deleteMoodEntry(entry.id);
      if (mounted) await _loadSelectedDateEntries();
    } catch (error) {
      if (mounted) _showError('Failed to delete: $error');
    }
  }

  Future<void> _openSettingsScreen() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => const MoodSettingsScreen()),
    );
    if (mounted) {
      await _reload();
    }
  }

  Future<void> _openReportScreen() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) =>
            MoodReportScreen(initialDate: _selectedDate),
      ),
    );
    if (mounted) {
      await _loadSelectedDateEntries();
    }
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'MBT Mood',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: isDark ? Colors.white : const Color(0xFF1E1E1E),
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _reload,
            tooltip: 'Refresh',
            icon: Icon(
              Icons.refresh_rounded,
              color: isDark ? Colors.white54 : Colors.black38,
              size: 22,
            ),
          ),
          IconButton(
            onPressed: _openSettingsScreen,
            tooltip: 'Settings',
            icon: Icon(
              Icons.settings_rounded,
              color: isDark ? Colors.white54 : Colors.black38,
              size: 22,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFCDAF56)),
            )
          : RefreshIndicator(
              onRefresh: _reload,
              displacement: 20,
              color: const Color(0xFFCDAF56),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragEnd: (details) {
                  if (details.primaryVelocity != null &&
                      details.primaryVelocity! > 500) {
                    HapticFeedback.selectionClick();
                    setState(
                      () => _selectedDate = _selectedDate.subtract(
                        const Duration(days: 1),
                      ),
                    );
                    unawaited(_loadSelectedDateEntries());
                  } else if (details.primaryVelocity != null &&
                      details.primaryVelocity! < -500) {
                    HapticFeedback.selectionClick();
                    setState(
                      () => _selectedDate = _selectedDate.add(
                        const Duration(days: 1),
                      ),
                    );
                    unawaited(_loadSelectedDateEntries());
                  }
                },
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 100),
                  children: [
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: DateNavigatorWidget(
                        selectedDate: _selectedDate,
                        onDateChanged: (date) {
                          setState(() => _selectedDate = date);
                          unawaited(_loadSelectedDateEntries());
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildTodayCard(context, isDark),
                    ),
                    const SizedBox(height: 12),
                    _buildMoodFlowSection(context, isDark),
                    const SizedBox(height: 12),
                    if (_selectedEntries.where((e) => !e.isDeleted).length >= 2)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildDashboardMoodGraph(isDark),
                      ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildQuickActions(context, isDark),
                    ),
                    const SizedBox(height: 24),
                    _buildSectionHeader("TODAY SO FAR"),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildDailyAverageMoodCard(context, isDark),
                    ),
                    const SizedBox(height: 24),
                    _buildSectionHeader("WEEKLY"),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildTrendCard(context, isDark),
                    ),
                    if (_error?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    _buildSectionHeader("MOOD SNAPSHOT"),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildSummaryCard(context, isDark),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: Color(0xFFCDAF56),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildTodayCard(BuildContext context, bool isDark) {
    final entries = _selectedEntries;

    return _cardShell(
      isDark,
      onTap: entries.isEmpty ? _openLogScreen : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(
                    0xFFCDAF56,
                  ).withOpacity(isDark ? 0.15 : 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'TODAY\'S LOG',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFCDAF56),
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const Spacer(),
              if (entries.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.06)
                        : Colors.black.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${entries.length} ${entries.length == 1 ? 'entry' : 'entries'}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                )
              else
                Text(
                  DateFormat('EEE, MMM d').format(_selectedDate),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (entries.isEmpty)
            _buildEmptyLogState(isDark)
          else
            _buildFilledLogState(context, isDark, entries),
        ],
      ),
    );
  }

  Widget _buildEmptyLogState(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(
                  0xFFCDAF56,
                ).withOpacity(isDark ? 0.08 : 0.06),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text('😶', style: const TextStyle(fontSize: 30)),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'How are you feeling?',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap to log your mood',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilledLogState(
    BuildContext context,
    bool isDark,
    List<MoodEntry> entries,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < entries.length; i++)
          _buildTimelineEntry(
            context,
            isDark,
            entries[i],
            isFirst: i == 0,
            isLast: i == entries.length - 1,
          ),
        const SizedBox(height: 12),
        Center(
          child: GestureDetector(
            onTap: () => _openLogScreen(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(
                  0xFFCDAF56,
                ).withOpacity(isDark ? 0.12 : 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add_rounded,
                    size: 16,
                    color: const Color(0xFFCDAF56),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Log mood',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFCDAF56),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineEntry(
    BuildContext context,
    bool isDark,
    MoodEntry entry, {
    bool isFirst = false,
    bool isLast = false,
  }) {
    final mood = _moodById[entry.moodId];
    final moodColor = Color(mood?.colorValue ?? 0xFFCDAF56);
    final timeStr = DateFormat('h:mm a').format(entry.loggedAt);
    final hasEmoji = mood?.emojiCodePoint != null;
    final lineColor = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.06);

    return GestureDetector(
      onTap: () => _openLogScreen(entryId: entry.id),
      onLongPress: () => _deleteEntry(entry),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 24,
              child: Column(
                children: [
                  if (!isFirst)
                    Expanded(
                      child: Center(
                        child: Container(width: 2, color: lineColor),
                      ),
                    )
                  else
                    const Spacer(),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: moodColor.withOpacity(isDark ? 0.5 : 0.35),
                      border: Border.all(
                        color: moodColor.withOpacity(isDark ? 0.8 : 0.6),
                        width: 2.5,
                      ),
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Center(
                        child: Container(width: 2, color: lineColor),
                      ),
                    )
                  else
                    const Spacer(),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                margin: EdgeInsets.only(bottom: isLast ? 0 : 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.03)
                      : const Color(0xFFF9F7F2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: moodColor.withOpacity(isDark ? 0.12 : 0.08),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            moodColor.withOpacity(isDark ? 0.20 : 0.12),
                            moodColor.withOpacity(isDark ? 0.10 : 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Center(
                        child: hasEmoji
                            ? Text(
                                mood!.emojiCharacter,
                                style: const TextStyle(fontSize: 24),
                              )
                            : Icon(
                                mood?.icon ?? Icons.mood_rounded,
                                color: moodColor,
                                size: 24,
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  mood?.name ?? 'Unknown',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                              Text(
                                timeStr,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white30
                                      : Colors.black38,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _formatReasons(entry, _reasonById),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white38 : Colors.black45,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodFlowSection(BuildContext context, bool isDark) {
    final entries = _selectedEntries;
    if (entries.isEmpty) return const SizedBox.shrink();

    final safeIndex = _moodFlowActiveIndex.clamp(0, entries.length - 1);
    final activeMood = _moodById[entries[safeIndex].moodId];
    final activeColor = Color(activeMood?.colorValue ?? 0xFFCDAF56);
    final activeTime = DateFormat('h:mm a').format(entries[safeIndex].loggedAt);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? activeColor.withOpacity(0.08)
            : activeColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: activeColor.withOpacity(isDark ? 0.18 : 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.timeline_rounded,
                size: 14,
                color: activeColor.withOpacity(0.6),
              ),
              const SizedBox(width: 6),
              Text(
                'MOOD FLOW',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white38 : Colors.black38,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(
                  activeTime,
                  key: ValueKey(activeTime),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: activeColor.withOpacity(0.7),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 72,
            child: PageView.builder(
              controller: _moodFlowController,
              itemCount: entries.length,
              onPageChanged: (index) {
                setState(() => _moodFlowActiveIndex = index);
              },
              itemBuilder: (context, index) {
                final entry = entries[index];
                final mood = _moodById[entry.moodId];
                final moodColor = Color(mood?.colorValue ?? 0xFFCDAF56);
                final hasEmoji = mood?.emojiCodePoint != null;
                final isActive = index == safeIndex;

                return AnimatedScale(
                  scale: isActive ? 1.0 : 0.75,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  child: AnimatedOpacity(
                    opacity: isActive ? 1.0 : 0.4,
                    duration: const Duration(milliseconds: 250),
                    child: GestureDetector(
                      onTap: () => _openLogScreen(entryId: entry.id),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: moodColor.withOpacity(
                                isDark ? 0.18 : 0.12,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: isActive
                                  ? Border.all(
                                      color: moodColor.withOpacity(0.4),
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: Center(
                              child: hasEmoji
                                  ? Text(
                                      mood!.emojiCharacter,
                                      style: const TextStyle(fontSize: 26),
                                    )
                                  : Icon(
                                      mood?.icon ?? Icons.mood_rounded,
                                      color: moodColor,
                                      size: 24,
                                    ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 250),
                            style: TextStyle(
                              fontSize: isActive ? 11 : 9,
                              fontWeight: isActive
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isActive
                                  ? (isDark ? Colors.white70 : Colors.black54)
                                  : (isDark ? Colors.white24 : Colors.black26),
                            ),
                            child: Text(mood?.name ?? ''),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          if (entries.length > 1)
            Center(
              child: entries.length <= 10
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        entries.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == safeIndex ? 16 : 5,
                          height: 5,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            color: i == safeIndex
                                ? activeColor.withOpacity(0.7)
                                : (isDark
                                      ? Colors.white.withOpacity(0.1)
                                      : Colors.black.withOpacity(0.08)),
                          ),
                        ),
                      ),
                    )
                  : Text(
                      '${safeIndex + 1} / ${entries.length}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white30 : Colors.black38,
                      ),
                    ),
            ),
        ],
      ),
    );
  }

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

  Widget _moodEmojiWidget(Mood? mood, {double size = 28}) {
    if (mood == null) {
      return Icon(Icons.remove_rounded, size: size,
          color: Colors.grey.withValues(alpha: 0.5));
    }
    if (mood.emojiCodePoint != null) {
      return Text(mood.emojiCharacter, style: TextStyle(fontSize: size));
    }
    return Icon(mood.icon, color: Color(mood.colorValue), size: size);
  }

  /// Smart label picker for the dashboard graph.
  Map<int, String> _dashSmartLabels(int count,
      String Function(int) labelOf, {int maxLabels = 5}) {
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

  LineChartData _dashChartData(bool isDark, List<MoodEntry> entries,
      List<FlSpot> spots, Map<int, String> labels,
      Map<int, Mood?> moodAtIndex, double yBound,
      LinearGradient lineGradient) {
    return LineChartData(
      minX: 0, maxX: (entries.length - 1).toDouble(),
      minY: -yBound, maxY: yBound,
      clipData: const FlClipData.all(),
      lineBarsData: [LineChartBarData(
        spots: spots,
        isCurved: true,
        preventCurveOverShooting: true,
        curveSmoothness: 0.35,
        gradient: lineGradient,
        barWidth: 3,
        isStrokeCapRound: true,
        shadow: Shadow(color: _kGold.withValues(alpha: 0.25),
            blurRadius: 6, offset: const Offset(0, 3)),
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, _, __, ___) {
            final mood = moodAtIndex[spot.x.toInt()];
            final c = mood != null ? Color(mood.colorValue) : _kGold;
            return FlDotCirclePainter(
              radius: 4.5, color: c, strokeWidth: 2,
              strokeColor: isDark ? const Color(0xFF1E2030) : Colors.white,
            );
          },
        ),
        belowBarData: BarAreaData(
          show: true, applyCutOffY: true, cutOffY: 0,
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [
              _kPositive.withValues(alpha: 0.16),
              _kPositive.withValues(alpha: 0.02),
            ],
          ),
        ),
        aboveBarData: BarAreaData(
          show: true, applyCutOffY: true, cutOffY: 0,
          gradient: LinearGradient(
            begin: Alignment.bottomCenter, end: Alignment.topCenter,
            colors: [
              _kNegative.withValues(alpha: 0.16),
              _kNegative.withValues(alpha: 0.02),
            ],
          ),
        ),
      )],
      extraLinesData: ExtraLinesData(horizontalLines: [
        HorizontalLine(
          y: 0,
          color: (isDark ? Colors.white : Colors.black)
              .withValues(alpha: 0.10),
          strokeWidth: 1,
          dashArray: [6, 4],
        ),
      ]),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          tooltipBgColor: isDark ? const Color(0xFF2E3142) : Colors.white,
          tooltipRoundedRadius: 12,
          tooltipPadding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 6),
          getTooltipItems: (touched) => touched.map((s) {
            final idx = s.spotIndex;
            final mood = moodAtIndex[idx];
            final time = DateFormat('h:mm a')
                .format(entries[idx].loggedAt);
            final emojiStr = mood?.emojiCharacter ?? '';
            return LineTooltipItem(
              '$emojiStr ${mood?.name ?? '?'}\n$time',
              TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87),
            );
          }).toList(),
        ),
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 30,
          interval: yBound > 3 ? (yBound / 3).ceilToDouble() : 1,
          getTitlesWidget: (val, _) {
            if (val == 0) return const SizedBox.shrink();
            final mood = _moodForScore(val);
            if (mood == null) return const SizedBox.shrink();
            return SizedBox(
              width: 26,
              child: Center(child: _moodEmojiWidget(mood, size: 13)),
            );
          },
        )),
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 36, interval: 1,
          getTitlesWidget: (val, _) {
            final label = labels[val.toInt()];
            if (label == null) return const SizedBox.shrink();
            return SideTitleWidget(
              axisSide: AxisSide.bottom,
              angle: -0.55,
              child: Text(label, style: TextStyle(fontSize: 8,
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
          strokeWidth: 0.6,
        ),
      ),
      borderData: FlBorderData(show: false),
    );
  }

  Widget _buildDashboardMoodGraph(bool isDark) {
    final entries = _selectedEntries
        .where((e) => !e.isDeleted).toList()
      ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
    if (entries.length < 2) return const SizedBox.shrink();

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

    final labels = _dashSmartLabels(entries.length,
        (i) => DateFormat('h:mm a').format(entries[i].loggedAt));
    final chartData = _dashChartData(isDark, entries, spots, labels,
        moodAtIndex, yBound, lineGradient);

    final needsScroll = entries.length > 8;
    final chartW = needsScroll
        ? (entries.length * 52.0).clamp(300.0, 3000.0) : double.infinity;

    Widget chart;
    if (!needsScroll) {
      chart = SizedBox(height: 200, child: LineChart(chartData));
    } else {
      chart = SizedBox(
        height: 200,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: SizedBox(
            width: chartW, height: 200,
            child: LineChart(chartData),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark ? null : [BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.show_chart_rounded, size: 14,
                color: _kGold.withValues(alpha: 0.6)),
            const SizedBox(width: 6),
            Text('MOOD GRAPH', style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w900,
              color: isDark ? Colors.white38 : Colors.black38,
              letterSpacing: 1.2,
            )),
            const Spacer(),
            GestureDetector(
              onTap: () => _openDashboardGraphFullscreen(isDark, entries,
                  spots, moodAtIndex, yBound, lineGradient),
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: _kGold.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.fullscreen_rounded, size: 16,
                    color: _kGold),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          chart,
        ],
      ),
    );
  }

  void _openDashboardGraphFullscreen(bool isDark, List<MoodEntry> entries,
      List<FlSpot> spots, Map<int, Mood?> moodAtIndex,
      double yBound, LinearGradient lineGradient) {
    final allLabels = <int, String>{};
    for (var i = 0; i < entries.length; i++) {
      allLabels[i] = DateFormat('h:mm a').format(entries[i].loggedAt);
    }

    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);
    final isToday = _selectedDate.year == todayOnly.year &&
        _selectedDate.month == todayOnly.month &&
        _selectedDate.day == todayOnly.day;
    final dateLabel = isToday
        ? 'Today'
        : DateFormat('EEE, MMM d, yyyy').format(_selectedDate);

    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    final chartH = screenH * 0.6;
    final chartW = (entries.length * 72.0).clamp(screenW - 40, 6000.0);

    Navigator.of(context).push<void>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) {
        final chartData = _dashChartData(isDark, entries, spots, allLabels,
            moodAtIndex, yBound, lineGradient);
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

  Widget _buildQuickActions(BuildContext context, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionButton(
            isDark: isDark,
            icon: Icons.add_rounded,
            label: 'Log',
            onTap: _openLogScreen,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QuickActionButton(
            isDark: isDark,
            icon: Icons.assessment_rounded,
            label: 'Report',
            onTap: _openReportScreen,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QuickActionButton(
            isDark: isDark,
            icon: Icons.settings_rounded,
            label: 'Settings',
            onTap: _openSettingsScreen,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QuickActionButton(
            isDark: isDark,
            icon: Icons.sync_rounded,
            label: 'Refresh',
            onTap: _reload,
          ),
        ),
      ],
    );
  }

  String _tendencyLabel(double positivePercent, double negativePercent) {
    if (positivePercent + negativePercent < 1) return '—';
    final diff = (positivePercent - negativePercent).abs();
    if (diff < 15) return 'Balanced';
    return positivePercent > negativePercent
        ? 'Mostly positive'
        : 'Mostly negative';
  }

  Color _tendencyColor(double positivePercent, double negativePercent) {
    if (positivePercent + negativePercent < 1) return const Color(0xFFCDAF56);
    final diff = (positivePercent - negativePercent).abs();
    if (diff < 15) return const Color(0xFFCDAF56);
    return positivePercent > negativePercent
        ? const Color(0xFF4CAF50)
        : const Color(0xFFE53935);
  }

  Widget _buildSummaryCard(BuildContext context, bool isDark) {
    final weekly = _weeklySummary;
    final monthly = _monthlySummary;
    if (weekly == null || monthly == null) {
      return const SizedBox.shrink();
    }

    final weekMood = weekly.mostFrequentMoodId != null
        ? _moodById[weekly.mostFrequentMoodId]
        : null;
    final monthMood = monthly.mostFrequentMoodId != null
        ? _moodById[monthly.mostFrequentMoodId]
        : null;
    final tendencyLabel = _tendencyLabel(
      weekly.positivePercent,
      weekly.negativePercent,
    );
    final tendencyColor = _tendencyColor(
      weekly.positivePercent,
      weekly.negativePercent,
    );
    final tendencyEmoji = _tendencyEmoji(
      weekly.positivePercent,
      weekly.negativePercent,
    );
    final topReasonMood = weekly.mostFrequentReasonId != null
        ? _reasonById[weekly.mostFrequentReasonId]
        : null;
    final topReasonName = weekly.mostFrequentReasonName ?? '—';

    return _cardShell(
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _SnapshotMoodTile(
                  isDark: isDark,
                  label: 'This Week',
                  moodName: weekly.mostFrequentMoodName ?? '—',
                  mood: weekMood,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SnapshotMoodTile(
                  isDark: isDark,
                  label: 'This Month',
                  moodName: monthly.mostFrequentMoodName ?? '—',
                  mood: monthMood,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SnapshotTendencyTile(
                  isDark: isDark,
                  label: 'Tendency',
                  value: tendencyLabel,
                  valueColor: tendencyColor,
                  emoji: tendencyEmoji,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SnapshotReasonTile(
                  isDark: isDark,
                  label: 'Top Reason',
                  value: topReasonName,
                  reason: topReasonMood,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _tendencyEmoji(double positive, double negative) {
    final total = positive + negative;
    if (total <= 0) return '😶';
    final pRatio = positive / total;
    if (pRatio >= 0.65) return '😊';
    if (pRatio <= 0.35) return '😔';
    return '😐';
  }

  Widget _buildTrendCard(BuildContext context, bool isDark) {
    final trends = _weeklyTrends;
    if (trends == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final days = List.generate(7, (i) => startOfWeek.add(Duration(days: i)));
    final dateFormat = DateFormat('yyyyMMdd');

    final items = days.map((d) {
      final key = dateFormat.format(d);
      final score = trends.dayScoreMap[key] ?? 0;
      return MapEntry(key, score);
    }).toList();

    final maxAbs = items
        .map((e) => e.value.abs())
        .fold<int>(1, (a, b) => math.max(a, b));

    return _cardShell(
      isDark,
      child: Container(
        height: 120,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final item in items)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: _TrendBar(
                    isDark: isDark,
                    label: _labelForDayKey(item.key),
                    score: item.value,
                    maxAbs: maxAbs,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Time-weighted average: recent entries matter more for "day so far".
  Mood? _resolveDailyAverageMood(List<MoodEntry> entries) {
    if (entries.isEmpty) return null;
    final sorted = List<MoodEntry>.from(entries)
      ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
    var weightedSum = 0.0;
    var weightSum = 0.0;
    for (var i = 0; i < sorted.length; i++) {
      final mood = _moodById[sorted[i].moodId];
      final pv = mood?.pointValue ?? 0;
      final w = math.pow(0.75, sorted.length - 1 - i).toDouble();
      weightedSum += pv * w;
      weightSum += w;
    }
    if (weightSum <= 0) return null;
    final avgPoint = (weightedSum / weightSum).round();
    final candidates = _activeMoods;
    if (candidates.isEmpty) return null;
    Mood? best;
    var bestDist = 999999;
    for (final m in candidates) {
      final dist = (m.pointValue - avgPoint).abs();
      if (dist < bestDist) {
        bestDist = dist;
        best = m;
      }
    }
    return best;
  }

  Widget _buildDailyAverageMoodCard(BuildContext context, bool isDark) {
    final entries = _selectedEntries;
    final mood = _resolveDailyAverageMood(entries);
    final now = DateTime.now();
    final isToday = _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
    final label = isToday ? 'Your day so far' : 'Day average';
    final emptyHint = isToday ? 'Log mood to see your day' : 'No entries';

    return _cardShell(
      isDark,
      onTap: _openLogScreen,
      child: mood == null
          ? Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCDAF56)
                        .withOpacity(isDark ? 0.1 : 0.06),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text('😶', style: TextStyle(fontSize: 28)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        emptyHint,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white38 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Color(mood.colorValue)
                        .withOpacity(isDark ? 0.15 : 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: mood.emojiCodePoint != null
                        ? Text(
                            mood.emojiCharacter,
                            style: const TextStyle(fontSize: 28),
                          )
                        : Icon(
                            mood.icon,
                            color: Color(mood.colorValue),
                            size: 28,
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        mood.name,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _cardShell(bool isDark, {required Widget child, VoidCallback? onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(padding: const EdgeInsets.all(18), child: child),
        ),
      ),
    );
  }

  String _formatReasons(MoodEntry entry, Map<String, MoodReason> byId) {
    if (entry.reasonIds.isEmpty) return 'No reason added';
    final names = entry.reasonIds
        .map((id) => byId[id]?.name)
        .where((n) => n != null)
        .cast<String>()
        .toList();
    if (names.isEmpty) return 'Reason: unknown';
    return names.join(' · ');
  }

  String _labelForDayKey(String dayKey) {
    if (dayKey.length != 8) return dayKey;
    final year = int.tryParse(dayKey.substring(0, 4));
    final month = int.tryParse(dayKey.substring(4, 6));
    final day = int.tryParse(dayKey.substring(6, 8));
    if (year == null || month == null || day == null) return dayKey;
    final date = DateTime(year, month, day);
    return DateFormat('EEE').format(date);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _TrendBar extends StatelessWidget {
  const _TrendBar({
    required this.isDark,
    required this.label,
    required this.score,
    required this.maxAbs,
  });

  final bool isDark;
  final String label;
  final int score;
  final int maxAbs;

  @override
  Widget build(BuildContext context) {
    final positive = score >= 0;
    final color = positive ? const Color(0xFF4CAF50) : const Color(0xFFE53935);
    final rawHeight = (score.abs() / math.max(1, maxAbs)) * 60;
    final barHeight = rawHeight.clamp(6, 60).toDouble();

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 10,
          height: barHeight,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withOpacity(isDark ? 0.8 : 0.7),
                color.withOpacity(isDark ? 0.4 : 0.3),
              ],
            ),
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white24 : Colors.black38,
          ),
        ),
      ],
    );
  }
}

class _SnapshotMoodTile extends StatelessWidget {
  const _SnapshotMoodTile({
    required this.isDark,
    required this.label,
    required this.moodName,
    required this.mood,
  });

  final bool isDark;
  final String label;
  final String moodName;
  final Mood? mood;

  @override
  Widget build(BuildContext context) {
    final color =
        mood != null ? Color(mood!.colorValue) : const Color(0xFFCDAF56);
    final hasEmoji = mood?.emojiCodePoint != null;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(isDark ? 0.12 : 0.08),
            color.withOpacity(isDark ? 0.04 : 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: color.withOpacity(isDark ? 0.15 : 0.1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: isDark ? Colors.white30 : Colors.black38,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(isDark ? 0.25 : 0.15),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(isDark ? 0.1 : 0.05),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: hasEmoji
                  ? Text(
                      mood!.emojiCharacter,
                      style: const TextStyle(fontSize: 32),
                    )
                  : Icon(
                      mood?.icon ?? Icons.mood_rounded,
                      color: color,
                      size: 28,
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            moodName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: isDark ? Colors.white : Colors.black87,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}

class _SnapshotTendencyTile extends StatelessWidget {
  const _SnapshotTendencyTile({
    required this.isDark,
    required this.label,
    required this.value,
    required this.valueColor,
    required this.emoji,
  });

  final bool isDark;
  final String label;
  final String value;
  final Color valueColor;
  final String emoji;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: valueColor.withOpacity(isDark ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: valueColor.withOpacity(isDark ? 0.12 : 0.08),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: isDark ? Colors.white30 : Colors.black38,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: valueColor.withOpacity(isDark ? 0.2 : 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 32)),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: valueColor,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}

class _SnapshotReasonTile extends StatelessWidget {
  const _SnapshotReasonTile({
    required this.isDark,
    required this.label,
    required this.value,
    required this.reason,
  });

  final bool isDark;
  final String label;
  final String value;
  final MoodReason? reason;

  @override
  Widget build(BuildContext context) {
    final accent = reason != null
        ? Color(reason!.colorValue)
        : const Color(0xFFCDAF56);
    final hasIcon = (reason?.iconCodePoint ?? 0) > 0;
    final hasEmoji = reason?.emojiCharacter.isNotEmpty ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withOpacity(isDark ? 0.1 : 0.06),
            accent.withOpacity(isDark ? 0.04 : 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: accent.withOpacity(isDark ? 0.12 : 0.08),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: isDark ? Colors.white30 : Colors.black38,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: accent.withOpacity(isDark ? 0.2 : 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: hasIcon
                  ? Icon(
                      reason?.icon ?? Icons.help_outline_rounded,
                      color: accent,
                      size: 28,
                    )
                  : hasEmoji
                      ? Text(
                          reason!.emojiCharacter,
                          style: const TextStyle(fontSize: 28),
                        )
                      : Icon(
                          Icons.help_outline_rounded,
                          color: accent,
                          size: 28,
                        ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: isDark ? Colors.white : Colors.black87,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.isDark,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool isDark;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFCDAF56).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: const Color(0xFFCDAF56)),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : Colors.black54,
                letterSpacing: -0.2,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}
