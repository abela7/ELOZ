import 'dart:async';
import 'dart:math' as math;

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
import '../../notifications/mbt_mood_notification_service.dart';
import 'mood_log_screen.dart';
import 'mood_report_screen.dart';
import 'mood_settings_screen.dart';

class MoodScreen extends StatefulWidget {
  const MoodScreen({super.key});

  @override
  State<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends State<MoodScreen> {
  final MoodApiService _api = MoodApiService();
  final MbtMoodNotificationService _notificationService =
      MbtMoodNotificationService();

  bool _loading = true;
  bool _savingReminder = false;
  String? _error;
  int _moodFlowActiveIndex = 0;
  late final PageController _moodFlowController;

  DateTime _selectedDate = DateTime.now();
  List<Mood> _moods = const <Mood>[];
  List<MoodReason> _reasons = const <MoodReason>[];
  List<MoodEntry> _selectedEntries = const [];
  MoodSummaryResponse? _weeklySummary;
  MoodSummaryResponse? _monthlySummary;
  MoodTrendsResponse? _monthlyTrends;
  MbtMoodReminderSettings _reminderSettings = const MbtMoodReminderSettings(
    enabled: false,
    hour: 20,
    minute: 30,
  );

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
      final monthlyTrendsFuture = _api.getMoodTrends(range: MoodRange.monthly);
      final reminderFuture = _notificationService.loadSettings();

      final moods = await moodsFuture;
      final reasons = await reasonsFuture;
      final selectedEntries = await selectedEntriesFuture;
      final weeklySummary = await weeklySummaryFuture;
      final monthlySummary = await monthlySummaryFuture;
      final monthlyTrends = await monthlyTrendsFuture;
      final reminderSettings = await reminderFuture;

      if (!mounted) return;
      setState(() {
        _moods = moods;
        _reasons = reasons;
        _selectedEntries = selectedEntries;
        _weeklySummary = weeklySummary;
        _monthlySummary = monthlySummary;
        _monthlyTrends = monthlyTrends;
        _reminderSettings = reminderSettings;
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
      MaterialPageRoute(builder: (context) => const MoodReportScreen()),
    );
    if (mounted) {
      await _loadSelectedDateEntries();
    }
  }

  Future<void> _setReminderEnabled(bool enabled) async {
    if (_savingReminder) return;
    setState(() => _savingReminder = true);
    try {
      await _notificationService.setDailyReminder(
        enabled: enabled,
        time: _reminderSettings.time,
      );
      final updated = await _notificationService.loadSettings();
      if (!mounted) return;
      setState(() => _reminderSettings = updated);
    } catch (error) {
      _showError('Failed to update reminder: $error');
    } finally {
      if (mounted) {
        setState(() => _savingReminder = false);
      }
    }
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderSettings.time,
    );
    if (picked == null) return;

    setState(() => _savingReminder = true);
    try {
      await _notificationService.setDailyReminder(
        enabled: _reminderSettings.enabled,
        time: picked,
      );
      final updated = await _notificationService.loadSettings();
      if (!mounted) return;
      setState(() => _reminderSettings = updated);
    } catch (error) {
      _showError('Failed to update reminder time: $error');
    } finally {
      if (mounted) {
        setState(() => _savingReminder = false);
      }
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
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildQuickActions(context, isDark),
                    ),
                    const SizedBox(height: 24),
                    _buildSectionHeader("MOOD SNAPSHOT"),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildSummaryCard(context, isDark),
                    ),
                    const SizedBox(height: 24),
                    _buildSectionHeader("LAST 12 DAYS"),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildTrendCard(context, isDark),
                    ),
                    const SizedBox(height: 24),
                    _buildSectionHeader("REMINDER"),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildReminderCard(context, isDark),
                    ),
                    const SizedBox(height: 24),
                    _buildSectionHeader("ACTIVE MOODS"),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildMoodPaletteCard(context, isDark),
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

    return _cardShell(
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  isDark: isDark,
                  label: 'This Week',
                  value: weekly.mostFrequentMoodName ?? '—',
                  valueColor: const Color(0xFFCDAF56),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  isDark: isDark,
                  label: 'This Month',
                  value: monthly.mostFrequentMoodName ?? '—',
                  valueColor: const Color(0xFFCDAF56),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  isDark: isDark,
                  label: 'Tendency',
                  value: _tendencyLabel(
                    weekly.positivePercent,
                    weekly.negativePercent,
                  ),
                  valueColor: _tendencyColor(
                    weekly.positivePercent,
                    weekly.negativePercent,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  isDark: isDark,
                  label: 'Top Reason',
                  value: weekly.mostFrequentReasonName ?? '—',
                  valueColor: const Color(0xFFCDAF56),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrendCard(BuildContext context, bool isDark) {
    final trends = _monthlyTrends;
    if (trends == null || trends.dayScoreMap.isEmpty) {
      return const SizedBox.shrink();
    }
    final entries = trends.dayScoreMap.entries.toList();
    final recent = entries.length <= 12
        ? entries
        : entries.sublist(entries.length - 12);
    final maxAbs = recent
        .map((entry) => entry.value.abs())
        .fold<int>(1, (a, b) => math.max(a, b));

    return _cardShell(
      isDark,
      child: Container(
        height: 120,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final item in recent)
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

  Widget _buildReminderCard(BuildContext context, bool isDark) {
    final subtitle = _reminderSettings.enabled
        ? 'Daily at ${_formatTime(_reminderSettings.time)}'
        : 'Disabled';

    return _cardShell(
      isDark,
      child: Column(
        children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _reminderSettings.enabled,
            activeColor: const Color(0xFFCDAF56),
            title: Text(
              'Daily reminder',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            subtitle: Text(
              'How was your day today?',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white38 : Colors.black45,
              ),
            ),
            onChanged: _savingReminder ? null : _setReminderEnabled,
          ),
          const SizedBox(height: 4),
          Divider(
            height: 1,
            thickness: 0.5,
            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
          ),
          const SizedBox(height: 4),
          ListTile(
            contentPadding: EdgeInsets.zero,
            enabled: _reminderSettings.enabled && !_savingReminder,
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFCDAF56).withOpacity(isDark ? 0.15 : 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.schedule_rounded,
                size: 20,
                color: Color(0xFFCDAF56),
              ),
            ),
            title: const Text(
              'Reminder time',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.chevron_right_rounded, size: 20),
            onTap: _reminderSettings.enabled ? _pickReminderTime : null,
          ),
        ],
      ),
    );
  }

  Widget _buildMoodPaletteCard(BuildContext context, bool isDark) {
    final moods = _activeMoods;
    return _cardShell(
      isDark,
      child: moods.isEmpty
          ? Text(
              'No active moods. Add moods in Settings.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white38 : Colors.black45,
              ),
            )
          : Wrap(
              spacing: 10,
              runSpacing: 10,
              children: moods
                  .map(
                    (mood) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Color(
                          mood.colorValue,
                        ).withOpacity(isDark ? 0.12 : 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Color(
                            mood.colorValue,
                          ).withOpacity(isDark ? 0.3 : 0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          mood.emojiCodePoint != null
                              ? Text(
                                  mood.emojiCharacter,
                                  style: const TextStyle(fontSize: 16),
                                )
                              : Icon(
                                  mood.icon,
                                  size: 16,
                                  color: Color(mood.colorValue),
                                ),
                          const SizedBox(width: 8),
                          Text(
                            mood.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(mood.colorValue),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(growable: false),
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

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.isDark,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final bool isDark;
  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.03)
            : const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.03),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white38 : Colors.black45,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: valueColor,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
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
