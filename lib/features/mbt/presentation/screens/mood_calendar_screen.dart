import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../core/theme/dark_gradient.dart';
import '../../data/models/mood.dart';
import '../../data/models/mood_entry.dart';
import '../../data/services/mood_api_service.dart';
import '../../mbt_module.dart';
import 'mood_log_screen.dart';

const Color _kGold = Color(0xFFCDAF56);
const Color _kPositive = Color(0xFF4CAF50);
const Color _kNegative = Color(0xFFE53935);

/// Mood Calendar — heatmap view of mood history by day.
/// Mirrors SleepCalendarScreen with mood-specific data and visuals.
class MoodCalendarScreen extends StatefulWidget {
  const MoodCalendarScreen({super.key, this.initialDate});

  /// If provided, the calendar opens to this date's month and selects it.
  final DateTime? initialDate;

  @override
  State<MoodCalendarScreen> createState() => _MoodCalendarScreenState();
}

class _MoodCalendarScreenState extends State<MoodCalendarScreen> {
  final MoodApiService _api = MoodApiService();

  CalendarFormat _calendarFormat = CalendarFormat.month;
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  bool _showHeatmap = true;

  // month data
  Map<DateTime, MoodCalendarDaySummary> _monthDays = {};
  Map<String, Mood> _moodById = {};
  Map<String, String> _reasonNameById = {}; // reasonId → name
  bool _monthLoading = true;

  // selected-day entries
  List<MoodEntry> _dayEntries = [];
  bool _dayLoading = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialDate ?? DateTime.now();
    _focusedDay = DateTime(initial.year, initial.month, initial.day);
    _selectedDay = _focusedDay;
    unawaited(_init());
  }

  Future<void> _init() async {
    await MbtModule.init(preOpenBoxes: true);
    await Future.wait([
      _loadMonthData(_focusedDay.year, _focusedDay.month),
      _loadDayEntries(_selectedDay),
    ]);
  }

  Future<void> _loadMonthData(int year, int month) async {
    setState(() => _monthLoading = true);
    try {
      final dataFuture = _api.getMonthCalendarData(year, month);
      final reasonsFuture = _api.getReasons(includeInactive: true);
      final data = await dataFuture;
      final reasons = await reasonsFuture;
      if (!mounted) return;
      setState(() {
        _monthDays = data.days;
        _moodById = {for (final m in data.moods) m.id: m};
        _reasonNameById = {for (final r in reasons) r.id: r.name};
        _monthLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _monthLoading = false);
    }
  }

  Future<void> _loadDayEntries(DateTime date) async {
    setState(() => _dayLoading = true);
    try {
      final entries = await _api.getMoodEntriesForDate(date);
      if (!mounted) return;
      setState(() {
        _dayEntries = entries.where((e) => !e.isDeleted).toList();
        _dayLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _dayLoading = false);
    }
  }

  void _selectDay(DateTime day, DateTime focused) {
    final d = DateTime(day.year, day.month, day.day);
    if (isSameDay(d, _selectedDay)) return;
    HapticFeedback.lightImpact();
    setState(() {
      _selectedDay = d;
      _focusedDay = focused;
    });
    unawaited(_loadDayEntries(d));
  }

  void _changeMonth(DateTime focused) {
    setState(() => _focusedDay = focused);
    if (focused.year != _focusedDay.year ||
        focused.month != _focusedDay.month) {
      unawaited(_loadMonthData(focused.year, focused.month));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: isDark
          ? DarkGradient.wrap(child: _buildContent(isDark))
          : _buildContent(isDark),
    );
  }

  Widget _buildContent(bool isDark) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Mood Calendar'),
        actions: [
          IconButton(
            icon: Icon(
              _showHeatmap
                  ? Icons.gradient_rounded
                  : Icons.grid_view_rounded,
              color: _showHeatmap ? _kGold : null,
            ),
            tooltip: _showHeatmap ? 'Hide Heatmap' : 'Show Heatmap',
            onPressed: () {
              HapticFeedback.lightImpact();
              setState(() => _showHeatmap = !_showHeatmap);
            },
          ),
          IconButton(
            icon: const Icon(Icons.today_rounded),
            tooltip: 'Go to Today',
            onPressed: () {
              HapticFeedback.mediumImpact();
              final today = DateTime.now();
              final d = DateTime(today.year, today.month, today.day);
              setState(() {
                _focusedDay = d;
                _selectedDay = d;
              });
              unawaited(Future.wait([
                _loadMonthData(d.year, d.month),
                _loadDayEntries(d),
              ]));
            },
          ),
        ],
      ),
      body: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildCalendarCard(isDark)),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(child: _buildDayHeader(isDark)),
          SliverToBoxAdapter(child: _buildDaySummaryCard(isDark)),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          if (!_dayLoading && _dayEntries.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  'ENTRIES',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: isDark ? Colors.white30 : Colors.black38,
                  ),
                ),
              ),
            ),
          if (_dayLoading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_dayEntries.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyDayState(isDark),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _buildEntryTile(
                    ctx,
                    isDark,
                    _dayEntries[i],
                    isLast: i == _dayEntries.length - 1,
                  ),
                  childCount: _dayEntries.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Calendar card
  // ---------------------------------------------------------------------------

  Widget _buildCalendarCard(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF2D3139).withOpacity(0.5)
            : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TableCalendar(
            firstDay: DateTime.now().subtract(const Duration(days: 365 * 5)),
            lastDay: DateTime.now(),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            rowHeight: 60,
            daysOfWeekHeight: 40,
            startingDayOfWeek: StartingDayOfWeek.monday,
            onDaySelected: _selectDay,
            onFormatChanged: (format) {
              if (_calendarFormat != format) {
                setState(() => _calendarFormat = format);
              }
            },
            onPageChanged: (focused) {
              _changeMonth(focused);
            },
            headerStyle: HeaderStyle(
              titleCentered: true,
              formatButtonVisible: false,
              leftChevronIcon: const Icon(
                  Icons.chevron_left_rounded, color: _kGold),
              rightChevronIcon: const Icon(
                  Icons.chevron_right_rounded, color: _kGold),
              titleTextFormatter: (date, locale) => '',
              headerPadding: const EdgeInsets.symmetric(vertical: 4),
            ),
            calendarBuilders: CalendarBuilders(
              headerTitleBuilder: (context, date) => Column(
                children: [
                  Text(
                    DateFormat('MMMM').format(date),
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    DateFormat('yyyy').format(date),
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black54,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              dowBuilder: (context, day) {
                final text = DateFormat.E().format(day);
                final isWeekend = day.weekday == DateTime.saturday ||
                    day.weekday == DateTime.sunday;
                return Center(
                  child: Text(
                    text,
                    style: TextStyle(
                      color: isWeekend
                          ? _kGold
                          : (isDark ? Colors.white38 : Colors.black38),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                );
              },
              defaultBuilder: (context, day, _) =>
                  _buildDayCell(day, isDark),
              todayBuilder: (context, day, _) =>
                  _buildDayCell(day, isDark, isToday: true),
              selectedBuilder: (context, day, _) =>
                  _buildDayCell(day, isDark, isSelected: true),
              outsideBuilder: (context, day, _) =>
                  _buildDayCell(day, isDark, isOutside: true),
            ),
          ),
          if (_monthLoading)
            const LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation(_kGold),
            ),
          if (_showHeatmap) _buildHeatmapLegend(isDark),
        ],
      ),
    );
  }

  Widget _buildDayCell(
    DateTime date,
    bool isDark, {
    bool isSelected = false,
    bool isToday = false,
    bool isOutside = false,
  }) {
    final key = DateTime(date.year, date.month, date.day);
    final summary = isOutside ? null : _monthDays[key];
    final isFuture = date.isAfter(DateTime.now());
    final hasData = summary != null && summary.hasData && !isFuture;

    final mood =
        hasData && summary.topMoodId != null
            ? _moodById[summary.topMoodId]
            : null;
    final hasEmoji = mood?.emojiCodePoint != null;
    final moodColor =
        mood != null ? Color(mood.colorValue) : _kGold;

    // Border: selected > heatmap data > none
    Border? border;
    if (isSelected) {
      border = Border.all(color: _kGold, width: 2);
    } else if (_showHeatmap && hasData) {
      border = Border.all(color: summary.heatmapColor, width: 2);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D24) : Colors.grey[100],
        borderRadius: BorderRadius.circular(14),
        border: border,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                color: isOutside
                    ? (isDark ? Colors.white10 : Colors.black12)
                    : isFuture
                        ? (isDark ? Colors.white24 : Colors.black26)
                        : (isDark ? Colors.white : Colors.black87),
                fontWeight: isSelected || isToday
                    ? FontWeight.w900
                    : FontWeight.w600,
                fontSize: 15,
              ),
            ),
            if (hasData && mood != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: hasEmoji
                    ? Text(
                        mood.emojiCharacter,
                        style: const TextStyle(fontSize: 11),
                      )
                    : Icon(mood.icon, size: 11, color: moodColor),
              )
            else if (hasData && !_showHeatmap)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  summary.polarityLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: summary.heatmapColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeatmapLegend(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.03)
            : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _legendItem('Positive', _kPositive, isDark),
          _legendItem('Balanced', _kGold, isDark),
          _legendItem('Negative', _kNegative, isDark),
          _legendItem('No data', isDark ? Colors.white12 : Colors.black12,
              isDark),
        ],
      ),
    );
  }

  Widget _legendItem(String label, Color color, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Day header (nav arrows + date text)
  // ---------------------------------------------------------------------------

  Widget _buildDayHeader(bool isDark) {
    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);
    final canGoNext = _selectedDay.isBefore(todayOnly);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () {
              final prev = _selectedDay.subtract(const Duration(days: 1));
              HapticFeedback.lightImpact();
              setState(() {
                _selectedDay = prev;
                _focusedDay = prev;
              });
              // reload month if crossing month boundary
              if (prev.month != _selectedDay.month ||
                  prev.year != _selectedDay.year) {
                unawaited(_loadMonthData(prev.year, prev.month));
              }
              unawaited(_loadDayEntries(prev));
            },
            icon: Icon(
              Icons.chevron_left_rounded,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  DateFormat('EEEE').format(_selectedDay),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
                Text(
                  DateFormat('MMMM d, yyyy').format(_selectedDay),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: canGoNext
                ? () {
                    final next =
                        _selectedDay.add(const Duration(days: 1));
                    HapticFeedback.lightImpact();
                    setState(() {
                      _selectedDay = next;
                      _focusedDay = next;
                    });
                    if (next.month != _selectedDay.month ||
                        next.year != _selectedDay.year) {
                      unawaited(_loadMonthData(next.year, next.month));
                    }
                    unawaited(_loadDayEntries(next));
                  }
                : null,
            icon: Icon(
              Icons.chevron_right_rounded,
              color: canGoNext
                  ? (isDark ? Colors.white54 : Colors.black54)
                  : (isDark ? Colors.white12 : Colors.black12),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Day summary card
  // ---------------------------------------------------------------------------

  Widget _buildDaySummaryCard(bool isDark) {
    final isFuture = _selectedDay.isAfter(DateTime.now());
    if (isFuture) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _summaryPlaceholder(
            isDark, 'Future', Icons.schedule_rounded),
      );
    }

    final summary = _monthDays[_selectedDay];
    if (summary == null || !summary.hasData) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _summaryPlaceholder(
            isDark, 'No mood data', Icons.sentiment_neutral_rounded),
      );
    }

    final topMood = summary.topMoodId != null
        ? _moodById[summary.topMoodId]
        : null;
    final hasEmoji = topMood?.emojiCodePoint != null;
    final moodColor =
        topMood != null ? Color(topMood.colorValue) : _kGold;
    final totalPolarity =
        summary.positiveCount + summary.negativeCount;
    final posPct = totalPolarity == 0
        ? 0.0
        : summary.positiveCount / totalPolarity;

    String tendencyLabel;
    Color tendencyColor;
    if (totalPolarity == 0) {
      tendencyLabel = 'No polarity data';
      tendencyColor = _kGold;
    } else if ((posPct - 0.5).abs() < 0.15) {
      tendencyLabel = 'Balanced day';
      tendencyColor = _kGold;
    } else if (posPct >= 0.5) {
      tendencyLabel = 'Positive day';
      tendencyColor = _kPositive;
    } else {
      tendencyLabel = 'Negative day';
      tendencyColor = _kNegative;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF2D3139).withOpacity(0.6)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: moodColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Mood avatar
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: moodColor.withOpacity(isDark ? 0.2 : 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: hasEmoji
                  ? Text(topMood!.emojiCharacter,
                      style: const TextStyle(fontSize: 30))
                  : Icon(topMood?.icon ?? Icons.mood_rounded,
                      color: moodColor, size: 28),
            ),
          ),
          const SizedBox(width: 16),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  topMood?.name ?? '—',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.edit_note_rounded,
                        size: 13,
                        color: isDark ? Colors.white38 : Colors.black38),
                    const SizedBox(width: 4),
                    Text(
                      '${summary.entryCount} '
                      '${summary.entryCount == 1 ? 'entry' : 'entries'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: tendencyColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      tendencyLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: tendencyColor,
                      ),
                    ),
                  ],
                ),
                if (totalPolarity > 0) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 6,
                      child: Row(
                        children: [
                          if (summary.positiveCount > 0)
                            Expanded(
                              flex: summary.positiveCount,
                              child:
                                  Container(color: _kPositive),
                            ),
                          if (summary.negativeCount > 0)
                            Expanded(
                              flex: summary.negativeCount,
                              child:
                                  Container(color: _kNegative),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryPlaceholder(bool isDark, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon,
              size: 20,
              color: isDark ? Colors.white38 : Colors.black38),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Empty state
  // ---------------------------------------------------------------------------

  Widget _buildEmptyDayState(bool isDark) {
    final isFuture = _selectedDay.isAfter(DateTime.now());
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            isFuture ? '🔮' : '😶',
            style: const TextStyle(fontSize: 48),
          ),
          const SizedBox(height: 16),
          Text(
            isFuture
                ? 'This day hasn\'t happened yet'
                : 'No mood logged for this day',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
          if (!isFuture) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () async {
                final changed = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) =>
                        MoodLogScreen(initialDate: _selectedDay),
                  ),
                );
                if (changed == true && mounted) {
                  await Future.wait([
                    _loadMonthData(
                        _selectedDay.year, _selectedDay.month),
                    _loadDayEntries(_selectedDay),
                  ]);
                }
              },
              icon: const Icon(Icons.add_rounded,
                  size: 18, color: _kGold),
              label: const Text(
                'Log Mood',
                style: TextStyle(
                    color: _kGold, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Entry timeline tiles
  // ---------------------------------------------------------------------------

  Widget _buildEntryTile(
    BuildContext context,
    bool isDark,
    MoodEntry entry, {
    bool isLast = false,
  }) {
    final mood = _moodById[entry.moodId];
    final hasEmoji = mood?.emojiCodePoint != null;
    final moodColor =
        mood != null ? Color(mood.colorValue) : _kGold;
    final timeStr = DateFormat('h:mm a').format(entry.loggedAt);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline line + dot
        SizedBox(
          width: 40,
          child: Column(
            children: [
              const SizedBox(height: 18),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: moodColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: moodColor.withOpacity(0.35),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 52,
                  color: isDark
                      ? Colors.white10
                      : Colors.black.withOpacity(0.08),
                  margin: const EdgeInsets.only(top: 4),
                ),
            ],
          ),
        ),
        // Card
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 12, right: 4),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF2D3139).withOpacity(0.7)
                  : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: moodColor.withOpacity(isDark ? 0.15 : 0.1),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () async {
                  HapticFeedback.lightImpact();
                  final changed =
                      await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => MoodLogScreen(
                        initialDate: _selectedDay,
                        entryId: entry.id,
                      ),
                    ),
                  );
                  if (changed == true && mounted) {
                    await Future.wait([
                      _loadMonthData(
                          _selectedDay.year, _selectedDay.month),
                      _loadDayEntries(_selectedDay),
                    ]);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Mood icon/emoji
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: moodColor
                              .withOpacity(isDark ? 0.2 : 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: hasEmoji
                              ? Text(mood!.emojiCharacter,
                                  style:
                                      const TextStyle(fontSize: 24))
                              : Icon(
                                  mood?.icon ??
                                      Icons.mood_rounded,
                                  color: moodColor,
                                  size: 22,
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    mood?.name ?? '—',
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
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.black38,
                                  ),
                                ),
                              ],
                            ),
                            if (entry.reasonIds.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: entry.reasonIds
                                    .map((rid) =>
                                        _reasonChip(rid, isDark))
                                    .toList(),
                              ),
                            ],
                            if (entry.customNote != null &&
                                entry.customNote!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                entry.customNote!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.black54,
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: isDark
                            ? Colors.white24
                            : Colors.black26,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _reasonChip(String reasonId, bool isDark) {
    final name = _reasonNameById[reasonId] ?? reasonId;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.06)
            : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        name,
        style: TextStyle(
          fontSize: 10,
          color: isDark ? Colors.white54 : Colors.black54,
        ),
      ),
    );
  }
}
