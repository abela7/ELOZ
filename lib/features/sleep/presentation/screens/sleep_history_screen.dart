import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/dark_gradient.dart';
import '../../data/models/sleep_record.dart';
import '../../data/models/sleep_factor.dart';
import '../../data/models/sleep_template.dart';
import '../providers/sleep_providers.dart';

/// Screen to view sleep history and manually log sleep
class SleepHistoryScreen extends ConsumerStatefulWidget {
  const SleepHistoryScreen({
    super.key,
    this.openNewLogOnMount = false,
    this.initialDateForNewLog,
    this.recordIdToEditOnMount,
  });

  /// When true, automatically opens the new sleep log form on first frame
  final bool openNewLogOnMount;

  /// When opening a new log, use this date for bedtime (defaults to today).
  /// Passed from SleepScreen when user has selected a calendar date.
  final DateTime? initialDateForNewLog;

  /// When set, opens the edit form for this record on mount (e.g. from Sleep Calendar).
  final String? recordIdToEditOnMount;

  @override
  ConsumerState<SleepHistoryScreen> createState() => _SleepHistoryScreenState();
}

enum _GroupBy { daily, weekly, monthly, yearly }

enum _FilterType { all, main, naps }

class _SleepHistoryScreenState extends ConsumerState<SleepHistoryScreen> {
  bool _showCalendar = false;
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  _GroupBy _groupBy = _GroupBy.monthly;
  _FilterType _filterType = _FilterType.all;
  bool _sortNewestFirst = true;
  bool _isListView = true;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _listScrollController = ScrollController();
  final ScrollController _dateStripController = ScrollController();
  Timer? _searchDebounce;
  String _searchQuery = '';
  bool _isSearching = false;
  bool _isFilterExpanded = false;

  static const _groupOptions = [
    (_GroupBy.daily, 'Daily'),
    (_GroupBy.weekly, 'Weekly'),
    (_GroupBy.monthly, 'Monthly'),
    (_GroupBy.yearly, 'Yearly'),
  ];

  static const _filterOptions = [
    (_FilterType.all, 'All'),
    (_FilterType.main, 'Main'),
    (_FilterType.naps, 'Naps'),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.openNewLogOnMount) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (mounted) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          await _showLogForm(
            context,
            isDark,
            initialDateForNewLog: widget.initialDateForNewLog,
            parentContextForReturn: widget.initialDateForNewLog != null
                ? context
                : null,
          );
        }
      });
    }
    if (widget.recordIdToEditOnMount != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final record = await ref.read(
          sleepRecordByIdProvider(widget.recordIdToEditOnMount!).future,
        );
        if (!mounted || record == null) return;
        setState(() {
          _selectedDate = record.sleepDate;
          _focusedDay = record.sleepDate;
        });
        final isDark = Theme.of(context).brightness == Brightness.dark;
        await _showLogForm(context, isDark, record: record);
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollDateStripToSelected();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _listScrollController.dispose();
    _dateStripController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      setState(() => _searchQuery = value.trim().toLowerCase());
    });
  }

  void _scrollDateStripToSelected() {
    if (!_dateStripController.hasClients) return;
    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);
    final startDate = todayOnly.subtract(const Duration(days: 90));
    final daysDiff = _selectedDate.difference(startDate).inDays;
    final itemExtent = 72.0;
    final target = (daysDiff * itemExtent).clamp(
      0.0,
      _dateStripController.position.maxScrollExtent,
    );
    _dateStripController.animateTo(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Preload factors and templates so the log form opens fast.
    ref.watch(sleepFactorsStreamProvider);
    ref.watch(sleepTemplatesStreamProvider);
    final recordsAsync = ref.watch(sleepRecordsProvider);

    return Scaffold(
      body: isDark
          ? DarkGradient.wrap(
              child: _buildContent(context, isDark, recordsAsync),
            )
          : _buildContent(context, isDark, recordsAsync),
    );
  }

  Widget _buildContent(
    BuildContext context,
    bool isDark,
    AsyncValue<List<SleepRecord>> recordsAsync,
  ) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'Search in notes...',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                  border: InputBorder.none,
                ),
                onChanged: _onSearchChanged,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Sleep History'),
                  Text(
                    DateFormat('EEE, MMM d, yyyy').format(_selectedDate),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black54,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchController.clear();
                  _searchDebounce?.cancel();
                  _searchQuery = '';
                });
              },
            )
          else ...[
            IconButton(
              icon: Icon(
                _showCalendar
                    ? Icons.calendar_today
                    : Icons.calendar_month_rounded,
              ),
              onPressed: () => setState(() => _showCalendar = !_showCalendar),
              tooltip: 'Calendar',
              color: _showCalendar ? AppColors.gold : null,
            ),
            if (!_isSameDay(_selectedDate, DateTime.now()))
              IconButton(
                icon: const Icon(Icons.today_rounded),
                onPressed: () {
                  setState(() {
                    _selectedDate = DateTime.now();
                    _focusedDay = DateTime.now();
                    _showCalendar = false;
                  });
                  _scrollDateStripToSelected();
                },
                tooltip: 'Today',
              ),
            IconButton(
              icon: const Icon(Icons.search_rounded),
              onPressed: () => setState(() => _isSearching = true),
              tooltip: 'Search',
            ),
            IconButton(
              icon: Icon(
                _isListView ? Icons.grid_view_rounded : Icons.view_list_rounded,
              ),
              onPressed: () => setState(() => _isListView = !_isListView),
              tooltip: _isListView ? 'Grid View' : 'List View',
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          if (!_isSearching) ...[
            if (_showCalendar) _buildCalendar(isDark),
            _buildDateStrip(isDark),
            _buildFilterAccordion(isDark),
          ] else
            const SizedBox(height: 12),
          Expanded(
            child: recordsAsync.when(
              data: (records) {
                final filtered = _filterAndSortRecords(records);
                if (filtered.isEmpty) {
                  return _buildEmptyState(context, isDark);
                }
                final grouped = _getGroupedRecords(filtered);
                if (_isListView) {
                  return _buildGroupedListView(context, isDark, grouped);
                }
                return _buildGroupedGridView(context, isDark, grouped);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<SleepRecord> _filterAndSortRecords(List<SleepRecord> records) {
    var list = records.toList();

    // Filter by type (all, main, naps)
    if (_filterType == _FilterType.main) {
      list = list.where((r) => !r.isNap).toList();
    } else if (_filterType == _FilterType.naps) {
      list = list.where((r) => r.isNap).toList();
    }

    // Filter by selected date if grouping is daily
    if (_groupBy == _GroupBy.daily) {
      list = list.where((r) {
        final bedDate = DateTime(
          r.bedTime.year,
          r.bedTime.month,
          r.bedTime.day,
        );
        return _isSameDay(bedDate, _selectedDate);
      }).toList();
    }

    // Search filter
    if (_searchQuery.isNotEmpty) {
      list = list.where((r) {
        final notes = (r.notes ?? '').toLowerCase();
        return notes.contains(_searchQuery);
      }).toList();
    }

    // Sort
    list.sort((a, b) {
      final cmp = b.bedTime.compareTo(a.bedTime);
      return _sortNewestFirst ? cmp : -cmp;
    });
    return list;
  }

  Map<String, List<SleepRecord>> _getGroupedRecords(List<SleepRecord> records) {
    final grouped = <String, List<SleepRecord>>{};

    for (final r in records) {
      final bedDate = DateTime(r.bedTime.year, r.bedTime.month, r.bedTime.day);
      String key;

      switch (_groupBy) {
        case _GroupBy.daily:
          key = DateFormat('EEE, MMM d, yyyy').format(bedDate);
          break;
        case _GroupBy.weekly:
          final monday = bedDate.subtract(Duration(days: bedDate.weekday - 1));
          final sun = monday.add(const Duration(days: 6));
          key =
              'Week ${DateFormat('MMM d').format(monday)} – ${DateFormat('MMM d, yyyy').format(sun)}';
          break;
        case _GroupBy.monthly:
          key = DateFormat('MMMM yyyy').format(bedDate);
          break;
        case _GroupBy.yearly:
          key = '${bedDate.year}';
          break;
      }
      grouped.putIfAbsent(key, () => []).add(r);
    }

    // Sort groups
    final sortedKeys = grouped.keys.toList();
    sortedKeys.sort((a, b) {
      final ra = grouped[a]!.first;
      final rb = grouped[b]!.first;
      return _sortNewestFirst
          ? rb.bedTime.compareTo(ra.bedTime)
          : ra.bedTime.compareTo(rb.bedTime);
    });

    return Map.fromEntries(sortedKeys.map((k) => MapEntry(k, grouped[k]!)));
  }

  /// Get hierarchical subgroups for yearly/monthly/weekly views
  Map<String, List<SleepRecord>> _getSubGroups(
    List<SleepRecord> records,
    _GroupBy parentGroup,
  ) {
    final subGrouped = <String, List<SleepRecord>>{};

    for (final r in records) {
      final bedDate = DateTime(r.bedTime.year, r.bedTime.month, r.bedTime.day);
      String key;

      switch (parentGroup) {
        case _GroupBy.yearly:
          // Subgroup by month
          key = DateFormat('MMM yyyy').format(bedDate);
          break;
        case _GroupBy.monthly:
          // Subgroup by week
          final monday = bedDate.subtract(Duration(days: bedDate.weekday - 1));
          final sun = monday.add(const Duration(days: 6));
          key =
              '${DateFormat('MMM d').format(monday)} – ${DateFormat('d').format(sun)}';
          break;
        case _GroupBy.weekly:
          // Subgroup by day
          key = DateFormat('EEE, MMM d').format(bedDate);
          break;
        case _GroupBy.daily:
          // No subgrouping for daily
          key = DateFormat('h:mm a').format(r.bedTime);
          break;
      }
      subGrouped.putIfAbsent(key, () => []).add(r);
    }

    // Sort subgroups
    final sortedKeys = subGrouped.keys.toList();
    sortedKeys.sort((a, b) {
      final ra = subGrouped[a]!.first;
      final rb = subGrouped[b]!.first;
      return _sortNewestFirst
          ? rb.bedTime.compareTo(ra.bedTime)
          : ra.bedTime.compareTo(rb.bedTime);
    });

    return Map.fromEntries(sortedKeys.map((k) => MapEntry(k, subGrouped[k]!)));
  }

  Widget _buildCalendar(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.blackOpacity004,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TableCalendar(
            firstDay: DateTime.now().subtract(const Duration(days: 730)),
            lastDay: DateTime.now().add(const Duration(days: 365)),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => _isSameDay(_selectedDate, day),
            calendarFormat: CalendarFormat.month,
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDate = selectedDay;
                _focusedDay = focusedDay;
                _showCalendar = false;
              });
              HapticFeedback.lightImpact();
              _scrollDateStripToSelected();
            },
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              leftChevronIcon: Icon(
                Icons.chevron_left_rounded,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
              rightChevronIcon: Icon(
                Icons.chevron_right_rounded,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            calendarStyle: CalendarStyle(
              selectedDecoration: const BoxDecoration(
                color: AppColors.gold,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              defaultTextStyle: TextStyle(
                color: isDark ? Colors.white : Colors.black,
              ),
              weekendTextStyle: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
              ),
              outsideDaysVisible: false,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextButton.icon(
              onPressed: () => setState(() => _showCalendar = false),
              icon: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.gold,
                size: 18,
              ),
              label: const Text(
                'Apply Selection',
                style: TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateStrip(bool isDark) {
    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);
    final startDate = todayOnly.subtract(const Duration(days: 90));
    const itemCount = 181;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        height: 90,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          controller: _dateStripController,
          itemCount: itemCount,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemBuilder: (context, index) {
            final date = startDate.add(Duration(days: index));
            final isSelected = _isSameDay(_selectedDate, date);
            final isToday = _isSameDay(todayOnly, date);

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedDate = date;
                  _focusedDay = date;
                });
                HapticFeedback.lightImpact();
              },
              child: Container(
                width: 60,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.gold
                      : (isDark ? AppColors.cardDark : Colors.white),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.gold
                        : (isToday
                              ? AppColors.gold.withOpacity(0.5)
                              : Colors.transparent),
                    width: 1.5,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.gold.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('EEE').format(date).toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? Colors.black87
                            : (isDark ? Colors.white54 : Colors.black54),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      date.day.toString(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? Colors.black87
                            : (isDark ? Colors.white : Colors.black),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGroupingChips(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _groupOptions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (group, label) = _groupOptions[index];
          final isSelected = _groupBy == group;
          return FilterChip(
            label: Text(label, style: const TextStyle(fontSize: 12)),
            selected: isSelected,
            onSelected: (_) {
              setState(() => _groupBy = group);
              HapticFeedback.lightImpact();
            },
            selectedColor: AppColors.goldOpacity03,
            backgroundColor: isDark ? AppColors.cardDark : Colors.white,
            labelStyle: TextStyle(
              color: isSelected
                  ? AppColors.gold
                  : (isDark ? Colors.white70 : Colors.black54),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
            side: BorderSide(
              color: isSelected
                  ? AppColors.gold
                  : (isDark ? Colors.white24 : Colors.black12),
              width: isSelected ? 1.5 : 1,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            showCheckmark: false,
          );
        },
      ),
    );
  }

  Widget _buildFilterAndSortChips(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      height: 48,
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _filterOptions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final (filter, label) = _filterOptions[index];
                final isSelected = _filterType == filter;
                return FilterChip(
                  label: Text(label, style: const TextStyle(fontSize: 12)),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() => _filterType = filter);
                    HapticFeedback.lightImpact();
                  },
                  selectedColor: AppColors.goldOpacity03,
                  backgroundColor: isDark ? AppColors.cardDark : Colors.white,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? AppColors.gold
                        : (isDark ? Colors.white54 : Colors.black54),
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? AppColors.gold
                        : (isDark ? Colors.white12 : Colors.black12),
                    width: isSelected ? 1.5 : 1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  showCheckmark: false,
                );
              },
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() => _sortNewestFirst = !_sortNewestFirst);
              HapticFeedback.lightImpact();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _sortNewestFirst
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_upward_rounded,
                    size: 16,
                    color: AppColors.gold,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _sortNewestFirst ? 'Newest' : 'Oldest',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterAccordion(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        children: [
          // Accordion Header
          InkWell(
            onTap: () {
              setState(() => _isFilterExpanded = !_isFilterExpanded);
              HapticFeedback.lightImpact();
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.filter_list_rounded,
                    size: 20,
                    color: AppColors.gold,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Filter & Group',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _isFilterExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 24,
                      color: AppColors.gold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Accordion Content
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _isFilterExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Group By Section
                  Text(
                    'Group By',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white54 : Colors.black54,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _groupOptions.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final (group, label) = _groupOptions[index];
                        final isSelected = _groupBy == group;
                        return FilterChip(
                          label: Text(
                            label,
                            style: const TextStyle(fontSize: 12),
                          ),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() => _groupBy = group);
                            HapticFeedback.lightImpact();
                          },
                          selectedColor: AppColors.goldOpacity03,
                          backgroundColor: isDark
                              ? Colors.black26
                              : Colors.grey[100],
                          labelStyle: TextStyle(
                            color: isSelected
                                ? AppColors.gold
                                : (isDark ? Colors.white70 : Colors.black54),
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.gold
                                : (isDark ? Colors.white12 : Colors.black12),
                            width: isSelected ? 1.5 : 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          showCheckmark: false,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Filter & Sort Section
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Filter',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white54 : Colors.black54,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 36,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _filterOptions.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  final (filter, label) = _filterOptions[index];
                                  final isSelected = _filterType == filter;
                                  return FilterChip(
                                    label: Text(
                                      label,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    selected: isSelected,
                                    onSelected: (_) {
                                      setState(() => _filterType = filter);
                                      HapticFeedback.lightImpact();
                                    },
                                    selectedColor: AppColors.goldOpacity03,
                                    backgroundColor: isDark
                                        ? Colors.black26
                                        : Colors.grey[100],
                                    labelStyle: TextStyle(
                                      color: isSelected
                                          ? AppColors.gold
                                          : (isDark
                                                ? Colors.white70
                                                : Colors.black54),
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                    side: BorderSide(
                                      color: isSelected
                                          ? AppColors.gold
                                          : (isDark
                                                ? Colors.white12
                                                : Colors.black12),
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    showCheckmark: false,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Sort Button
                      GestureDetector(
                        onTap: () {
                          setState(() => _sortNewestFirst = !_sortNewestFirst);
                          HapticFeedback.lightImpact();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black26 : Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? Colors.white12 : Colors.black12,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _sortNewestFirst
                                    ? Icons.arrow_downward_rounded
                                    : Icons.arrow_upward_rounded,
                                size: 16,
                                color: AppColors.gold,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _sortNewestFirst ? 'Newest' : 'Oldest',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedListView(
    BuildContext context,
    bool isDark,
    Map<String, List<SleepRecord>> grouped,
  ) {
    final showHierarchy =
        _groupBy == _GroupBy.yearly ||
        _groupBy == _GroupBy.monthly ||
        _groupBy == _GroupBy.weekly;

    return ListView.builder(
      controller: _listScrollController,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final key = grouped.keys.elementAt(index);
        final groupRecords = grouped[key]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          key: ValueKey(key),
          children: [
            // Main group header
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 20, bottom: 12),
              child: Row(
                children: [
                  Text(
                    key.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: AppColors.gold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.goldOpacity02,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${groupRecords.length} ${groupRecords.length == 1 ? 'record' : 'records'}',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppColors.gold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Divider(color: AppColors.gold.withOpacity(0.2)),
                  ),
                ],
              ),
            ),

            // Show hierarchical subgroups or flat list
            if (showHierarchy)
              _buildHierarchicalSubGroups(context, isDark, groupRecords)
            else
              ...groupRecords.map((r) => _buildHistoryCard(context, isDark, r)),
          ],
        );
      },
    );
  }

  Widget _buildHierarchicalSubGroups(
    BuildContext context,
    bool isDark,
    List<SleepRecord> records,
  ) {
    final subGroups = _getSubGroups(records, _groupBy);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: subGroups.entries.map((entry) {
        final subKey = entry.key;
        final subRecords = entry.value;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subgroup header
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 12, bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.gold.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    subKey,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : Colors.black87,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '(${subRecords.length})',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
              ),
            ),
            // Records in this subgroup
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Column(
                children: subRecords
                    .map((r) => _buildHistoryCard(context, isDark, r))
                    .toList(),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildGroupedGridView(
    BuildContext context,
    bool isDark,
    Map<String, List<SleepRecord>> grouped,
  ) {
    final showHierarchy =
        _groupBy == _GroupBy.yearly ||
        _groupBy == _GroupBy.monthly ||
        _groupBy == _GroupBy.weekly;
    final entries = grouped.entries.toList();

    return ListView.builder(
      controller: _listScrollController,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final key = entry.key;
        final groupRecords = entry.value;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          key: ValueKey(key),
          children: [
            // Main group header
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 20, bottom: 12),
              child: Row(
                children: [
                  Text(
                    key.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: AppColors.gold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.goldOpacity02,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${groupRecords.length} ${groupRecords.length == 1 ? 'record' : 'records'}',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppColors.gold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Divider(color: AppColors.gold.withOpacity(0.2)),
                  ),
                ],
              ),
            ),

            // Show hierarchical subgroups or flat grid
            if (showHierarchy)
              _buildHierarchicalSubGroupsGrid(context, isDark, groupRecords)
            else
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.1,
                children: groupRecords
                    .map(
                      (SleepRecord r) =>
                          _buildCompactHistoryCard(context, isDark, r),
                    )
                    .toList(),
              ),
          ],
        );
      },
    );
  }

  Widget _buildHierarchicalSubGroupsGrid(
    BuildContext context,
    bool isDark,
    List<SleepRecord> records,
  ) {
    final subGroups = _getSubGroups(records, _groupBy);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: subGroups.entries.map((entry) {
        final subKey = entry.key;
        final subRecords = entry.value;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subgroup header
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 12, bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.gold.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    subKey,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : Colors.black87,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '(${subRecords.length})',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
              ),
            ),
            // Grid of records in this subgroup
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.1,
                children: subRecords
                    .map(
                      (SleepRecord r) =>
                          _buildCompactHistoryCard(context, isDark, r),
                    )
                    .toList(),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildCompactHistoryCard(
    BuildContext context,
    bool isDark,
    SleepRecord record,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          await _showLogForm(context, isDark, record: record);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.blackOpacity004,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(
                    record.isNap ? Icons.bolt_rounded : Icons.bedtime_rounded,
                    size: 14,
                    color: AppColors.gold,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('EEE').format(record.bedTime),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                record.formattedDuration,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                record.scoreGradeDisplay,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: record.qualityColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCard(
    BuildContext context,
    bool isDark,
    SleepRecord record,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D3139) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.grey.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            await _showLogForm(context, isDark, record: record);
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Date Column
                Column(
                  children: [
                    Text(
                      DateFormat('dd').format(record.bedTime),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                        color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                      ),
                    ),
                    Text(
                      DateFormat('EEE').format(record.bedTime).toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white38 : Colors.black38,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Container(
                  width: 1,
                  height: 36,
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
                const SizedBox(width: 14),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(
                            record.isNap
                                ? Icons.bolt_rounded
                                : Icons.bedtime_rounded,
                            size: 14,
                            color: const Color(0xFFCDAF56),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              record.formattedDuration,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                                letterSpacing: -0.4,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${DateFormat('h:mm a').format(record.bedTime)} - ${DateFormat('h:mm a').format(record.wakeTime)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Pre-Sleep Factors
                      if (record.factorsBeforeSleep != null &&
                          record.factorsBeforeSleep!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        _buildFactorChips(
                          context,
                          isDark,
                          record.factorsBeforeSleep!,
                        ),
                      ],
                      if (record.scoredGoalName != null &&
                          record.scoredGoalName!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Flexible(
                          child: Text(
                            'Goal: ${record.scoredGoalName} • ${record.scoredGoalTargetHours?.toStringAsFixed(1) ?? '-'}h',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFCDAF56),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // Quality Indicator
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: record.qualityColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: record.qualityColor.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        record.scoreGradeDisplay,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: record.qualityColor,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'GRADE',
                        style: TextStyle(
                          fontSize: 7,
                          fontWeight: FontWeight.w900,
                          color: record.qualityColor.withOpacity(0.7),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getQualityEmoji(record.quality),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getQualityEmoji(String quality) {
    switch (quality) {
      case 'poor':
        return '😫';
      case 'fair':
        return '🥱';
      case 'good':
        return '🙂';
      case 'veryGood':
        return '🤩';
      case 'excellent':
        return '💪';
      default:
        return '🙂';
    }
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFFCDAF56).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.history_rounded,
                  size: 64,
                  color: const Color(0xFFCDAF56).withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Your sleep journey starts here',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Log your first sleep to see patterns and scores',
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showLogForm(
    BuildContext context,
    bool isDark, {
    SleepRecord? record,
    DateTime? initialDateForNewLog,
    BuildContext? parentContextForReturn,
  }) async {
    DateTime bedTime;
    double durationHours;
    bool isNap;

    if (record != null) {
      bedTime = record.bedTime;
      durationHours =
          record.wakeTime.difference(record.bedTime).inMinutes / 60.0;
      isNap = record.isNap;
    } else {
      final defaultTemplate = await ref
          .read(sleepTemplateRepositoryProvider)
          .getDefaultTemplate();
      final anchor = initialDateForNewLog ?? DateTime.now();
      final anchorDate = DateTime(anchor.year, anchor.month, anchor.day);
      if (defaultTemplate != null) {
        bedTime = DateTime(
          anchorDate.year,
          anchorDate.month,
          anchorDate.day,
          defaultTemplate.bedHour,
          defaultTemplate.bedMinute,
        );
        durationHours = defaultTemplate.durationMinutes / 60.0;
        isNap = defaultTemplate.isNap;
      } else {
        bedTime = DateTime(
          anchorDate.year,
          anchorDate.month,
          anchorDate.day,
          22,
          0,
        );
        durationHours = 8.0;
        isNap = false;
      }
    }
    String quality = record?.quality ?? 'good';
    final notesController = TextEditingController(text: record?.notes ?? '');
    List<String> selectedFactorIds = record?.factorsBeforeSleep ?? [];
    bool goodFactorsExpanded = false;
    bool badFactorsExpanded = false;

    // Real-time calculation helper (from duration slider)
    String calculateDuration() {
      final hours = durationHours.floor();
      final minutes = ((durationHours % 1) * 60).round();
      return "${hours}h ${minutes}m";
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2228) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            left: 20,
            right: 20,
            top: 12,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white12
                          : Colors.black.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Header row: title + type pills + delete
                Row(
                  children: [
                    Text(
                      record == null ? 'Log Sleep' : 'Edit',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        letterSpacing: -0.5,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 16),
                    _buildTypePill(
                      isDark,
                      'Night',
                      Icons.nightlight_rounded,
                      !isNap,
                      () => setSheetState(() {
                        isNap = false;
                        if (durationHours < 1) durationHours = 1;
                      }),
                    ),
                    const SizedBox(width: 8),
                    _buildTypePill(
                      isDark,
                      'Nap',
                      Icons.bolt_rounded,
                      isNap,
                      () => setSheetState(() {
                        isNap = true;
                        if (durationHours > 4) durationHours = 4;
                      }),
                    ),
                    const Spacer(),
                    if (record != null)
                      GestureDetector(
                        onTap: () async {
                          await ref
                              .read(sleepRecordRepositoryProvider)
                              .delete(record.id);
                          ref.invalidate(sleepRecordsProvider);
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.error,
                          size: 20,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                // Date + Templates – modern unified card
                _buildDateAndTemplatesCard(
                  context,
                  isDark,
                  bedTime: bedTime,
                  onDateTap: () async {
                    final dt = await _pickDateTime(context, bedTime);
                    if (dt != null) setSheetState(() => bedTime = dt);
                  },
                  onTemplateApply: (newBedTime, newWakeTime, templateIsNap) {
                    setSheetState(() {
                      bedTime = newBedTime;
                      durationHours =
                          newWakeTime.difference(newBedTime).inMinutes / 60.0;
                      isNap = templateIsNap;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Hero: Sleep Timeline Card
                _buildSleepTimelineCard(
                  context,
                  isDark,
                  bedTime: bedTime,
                  durationHours: durationHours,
                  isNap: isNap,
                  calculateDuration: calculateDuration,
                  onBedTimeTap: () async {
                    final dt = await _pickDateTime(context, bedTime);
                    if (dt != null) setSheetState(() => bedTime = dt);
                  },
                  onDurationChanged: (h) =>
                      setSheetState(() => durationHours = h),
                ),
                const SizedBox(height: 24),

                // Quality Selector with label
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 12),
                      child: Text(
                        'How was your sleep?',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white70 : Colors.black54,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _buildQualityChip(
                            'poor',
                            '😫',
                            quality,
                            (v) => setSheetState(() => quality = v),
                            isDark,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildQualityChip(
                            'fair',
                            '🥱',
                            quality,
                            (v) => setSheetState(() => quality = v),
                            isDark,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildQualityChip(
                            'good',
                            '🙂',
                            quality,
                            (v) => setSheetState(() => quality = v),
                            isDark,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildQualityChip(
                            'veryGood',
                            '🤩',
                            quality,
                            (v) => setSheetState(() => quality = v),
                            isDark,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildQualityChip(
                            'excellent',
                            '💪',
                            quality,
                            (v) => setSheetState(() => quality = v),
                            isDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Pre-Sleep Factors
                _buildFactorsSelector(
                  context,
                  isDark,
                  selectedIds: selectedFactorIds,
                  goodExpanded: goodFactorsExpanded,
                  badExpanded: badFactorsExpanded,
                  onToggleGood: () => setSheetState(
                    () => goodFactorsExpanded = !goodFactorsExpanded,
                  ),
                  onToggleBad: () => setSheetState(
                    () => badFactorsExpanded = !badFactorsExpanded,
                  ),
                  onChanged: (factors) =>
                      setSheetState(() => selectedFactorIds = factors),
                ),
                const SizedBox(height: 20),

                // Notes
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Notes (optional)',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black38,
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withOpacity(0.04)
                        : AppColors.backgroundLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        HapticFeedback.heavyImpact();
                        final bedDate = DateTime(
                          bedTime.year,
                          bedTime.month,
                          bedTime.day,
                          bedTime.hour,
                          bedTime.minute,
                        );
                        final wakeTime = bedDate.add(
                          Duration(
                            hours: durationHours.floor(),
                            minutes: ((durationHours % 1) * 60).round(),
                          ),
                        );
                        var newRecord =
                            (record ??
                                    SleepRecord(
                                      bedTime: bedDate,
                                      wakeTime: wakeTime,
                                    ))
                                .copyWith(
                                  bedTime: bedDate,
                                  wakeTime: wakeTime,
                                  quality: quality,
                                  notes: notesController.text.trim(),
                                  isNap: isNap,
                                  factorsBeforeSleep: selectedFactorIds.isEmpty
                                      ? null
                                      : selectedFactorIds,
                                  updatedAt: DateTime.now(),
                                );

                        final targetService = ref.read(
                          sleepTargetServiceProvider,
                        );
                        final scoringService = ref.read(
                          sleepScoringServiceProvider,
                        );
                        final settings = await targetService.getSettings();
                        final scoreResult = scoringService.scoreRecord(
                          record: newRecord,
                          targetHours: settings.targetHours,
                        );
                        newRecord = newRecord.copyWith(
                          sleepScore: scoreResult.overallScore,
                          scoredGoalId: null,
                          scoredGoalName: null,
                          scoredGoalTargetHours: settings.targetHours,
                          scoredDurationDifferenceMinutes:
                              scoreResult.durationDifferenceMinutes,
                          scoredDurationScore: scoreResult.durationScore,
                          scoredConsistencyScore: scoreResult.consistencyScore,
                          scoredGrade: scoreResult.grade,
                          scoredGoalMet: scoreResult.goalMet,
                          usedManualGoalOverride: false,
                          schemaVersion: SleepRecord.currentSchemaVersion,
                        );

                        if (record == null) {
                          await ref
                              .read(sleepRecordRepositoryProvider)
                              .create(newRecord);
                        } else {
                          await ref
                              .read(sleepRecordRepositoryProvider)
                              .update(newRecord);
                        }

                        ref.invalidate(sleepRecordsProvider);
                        if (context.mounted) Navigator.pop(context);
                        final loggedDate = DateTime(
                          bedDate.year,
                          bedDate.month,
                          bedDate.day,
                        );
                        if (parentContextForReturn != null &&
                            parentContextForReturn.mounted) {
                          Navigator.of(parentContextForReturn).pop(loggedDate);
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Ink(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [AppColors.gold, Color(0xFFB8963E)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.goldOpacity02,
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Container(
                          alignment: Alignment.center,
                          child: Text(
                            record == null ? 'Save Sleep Log' : 'Update',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypePill(
    bool isDark,
    String label,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [AppColors.gold, Color(0xFFB8963E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: !isSelected
                ? (isDark
                      ? Colors.white.withOpacity(0.06)
                      : Colors.black.withOpacity(0.04))
                : null,
            borderRadius: BorderRadius.circular(22),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.gold.withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? Colors.black87
                    : (isDark ? Colors.white54 : Colors.black54),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? Colors.black87
                      : (isDark ? Colors.white70 : Colors.black54),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSleepTimelineCard(
    BuildContext context,
    bool isDark, {
    required DateTime bedTime,
    required double durationHours,
    required bool isNap,
    required String Function() calculateDuration,
    required VoidCallback onBedTimeTap,
    required ValueChanged<double> onDurationChanged,
  }) {
    const double minNap = 0.25;
    const double maxNap = 4.0;
    const double minNight = 1.0;
    const double maxNight = 14.0;
    final min = isNap ? minNap : minNight;
    final max = isNap ? maxNap : maxNight;
    final value = durationHours.clamp(min, max);
    final wakeTime = bedTime.add(
      Duration(hours: value.floor(), minutes: ((value % 1) * 60).round()),
    );

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  const Color(0xFF2D3139).withOpacity(0.6),
                  const Color(0xFF1E2228),
                ]
              : [Colors.white, const Color(0xFFFFFBF5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.goldOpacity02, width: 1),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : AppColors.blackOpacity005,
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Bed / Wake row
          Row(
            children: [
              // Bedtime (tappable)
              Expanded(
                child: GestureDetector(
                  onTap: onBedTimeTap,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.nightlight_round,
                          size: 22,
                          color: AppColors.gold,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          DateFormat('h:mm').format(bedTime),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          DateFormat('a').format(bedTime),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.gold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('EEE, MMM d').format(bedTime),
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Arrow + duration
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: AppColors.gold,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.gold, Color(0xFFB8963E)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        calculateDuration(),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Wake (auto)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.wb_sunny_rounded,
                        size: 22,
                        color: AppColors.gold,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        DateFormat('h:mm').format(wakeTime),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        DateFormat('a').format(wakeTime),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.gold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('EEE, MMM d').format(wakeTime),
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Duration picker (scrollable hour:minute)
          _buildDurationPickerWheel(
            context,
            isDark,
            durationHours: value,
            isNap: isNap,
            onChanged: onDurationChanged,
          ),
        ],
      ),
    );
  }

  /// Custom scrollable duration picker (hour and minute wheels)
  Widget _buildDurationPickerWheel(
    BuildContext context,
    bool isDark, {
    required double durationHours,
    required bool isNap,
    required ValueChanged<double> onChanged,
  }) {
    final minHours = isNap ? 0 : 1;
    final maxHours = isNap ? 4 : 14;
    final currentHour = durationHours.floor();
    final currentMinute = ((durationHours % 1) * 60).round();

    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withOpacity(0.2)
            : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Hour wheel
          Expanded(
            child: ListWheelScrollView.useDelegate(
              controller: FixedExtentScrollController(
                initialItem: (currentHour - minHours).clamp(
                  0,
                  maxHours - minHours,
                ),
              ),
              itemExtent: 50,
              diameterRatio: 1.5,
              perspective: 0.003,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: (index) {
                final newHour = minHours + index;
                final newDuration = newHour + (currentMinute / 60.0);
                onChanged(newDuration);
              },
              childDelegate: ListWheelChildBuilderDelegate(
                builder: (context, index) {
                  final hour = minHours + index;
                  final isSelected = hour == currentHour;
                  return Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontSize: isSelected ? 32 : 20,
                        fontWeight: isSelected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: isSelected
                            ? AppColors.gold
                            : (isDark ? Colors.white24 : Colors.black26),
                        letterSpacing: -0.5,
                      ),
                      child: Text('$hour'),
                    ),
                  );
                },
                childCount: maxHours - minHours + 1,
              ),
            ),
          ),
          // Separator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'h',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.gold,
              ),
            ),
          ),
          // Minute wheel (0, 15, 30, 45)
          Expanded(
            child: ListWheelScrollView.useDelegate(
              controller: FixedExtentScrollController(
                initialItem: (currentMinute / 15).round().clamp(0, 3),
              ),
              itemExtent: 50,
              diameterRatio: 1.5,
              perspective: 0.003,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: (index) {
                final newMinute = index * 15;
                final newDuration = currentHour + (newMinute / 60.0);
                onChanged(newDuration);
              },
              childDelegate: ListWheelChildBuilderDelegate(
                builder: (context, index) {
                  final minute = index * 15;
                  final isSelected = minute == currentMinute;
                  return Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontSize: isSelected ? 32 : 20,
                        fontWeight: isSelected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: isSelected
                            ? AppColors.gold
                            : (isDark ? Colors.white24 : Colors.black26),
                        letterSpacing: -0.5,
                      ),
                      child: Text(minute.toString().padLeft(2, '0')),
                    ),
                  );
                },
                childCount: 4,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16, left: 8),
            child: Text(
              'm',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.gold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQualityChip(
    String value,
    String emoji,
    String selected,
    Function(String) onSelected,
    bool isDark,
  ) {
    final isSelected = value == selected;
    final label = switch (value) {
      'poor' => 'Poor',
      'fair' => 'Fair',
      'good' => 'Good',
      'veryGood' => 'Great',
      'excellent' => 'Best',
      _ => value,
    };

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onSelected(value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    AppColors.goldOpacity02,
                    AppColors.goldOpacity02.withOpacity(0.5),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
              : null,
          color: !isSelected
              ? (isDark
                    ? Colors.white.withOpacity(0.06)
                    : Colors.black.withOpacity(0.04))
              : null,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.gold
                : (isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.06)),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.gold.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.25 : 1.0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.elasticOut,
              child: Text(emoji, style: const TextStyle(fontSize: 26)),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? AppColors.gold
                    : (isDark ? Colors.white54 : Colors.black45),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<DateTime?> _pickDateTime(
    BuildContext context,
    DateTime current,
  ) async {
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null) return null;

    if (!context.mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Widget _buildFactorChips(
    BuildContext context,
    bool isDark,
    List<String> factorIds,
  ) {
    final factorsAsync = ref.watch(sleepFactorsStreamProvider);

    return factorsAsync.when(
      data: (allFactors) {
        final factors = allFactors
            .where((f) => factorIds.contains(f.id))
            .toList();
        if (factors.isEmpty) return const SizedBox.shrink();

        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: factors.map((factor) {
            final isGood = factor.isGood;
            final accentColor = isGood
                ? const Color(0xFF4CAF50)
                : const Color(0xFFEF5350);
            final bgColor = isGood
                ? accentColor.withOpacity(isDark ? 0.15 : 0.1)
                : accentColor.withOpacity(isDark ? 0.15 : 0.1);
            final textColor = isGood
                ? const Color(0xFF2E7D32)
                : const Color(0xFFC62828);

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: accentColor.withOpacity(isDark ? 0.3 : 0.2),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(factor.icon, size: 11, color: accentColor),
                  const SizedBox(width: 3),
                  Text(
                    factor.name,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }

  Widget _buildFactorsSelector(
    BuildContext context,
    bool isDark, {
    required List<String> selectedIds,
    required bool goodExpanded,
    required bool badExpanded,
    required VoidCallback onToggleGood,
    required VoidCallback onToggleBad,
    required Function(List<String>) onChanged,
  }) {
    final factorsAsync = ref.watch(sleepFactorsStreamProvider);

    return factorsAsync.when(
      data: (factors) {
        if (factors.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withOpacity(0.2) : Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No factors available. Add them in Settings → Pre-Sleep Factors.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
          );
        }

        final goodFactors = factors.where((factor) => factor.isGood).toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
        final badFactors = factors.where((factor) => factor.isBad).toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

        return Column(
          children: [
            _buildFactorAccordionCard(
              isDark: isDark,
              title: 'Good Habits',
              subtitle: '${goodFactors.length} factors',
              icon: Icons.thumb_up_alt_rounded,
              accent: const Color(0xFF4CAF50),
              expanded: goodExpanded,
              onToggle: onToggleGood,
              child: _buildSelectableFactorChips(
                factors: goodFactors,
                selectedIds: selectedIds,
                isDark: isDark,
                onChanged: onChanged,
              ),
            ),
            const SizedBox(height: 10),
            _buildFactorAccordionCard(
              isDark: isDark,
              title: 'Bad Habits',
              subtitle: '${badFactors.length} factors',
              icon: Icons.warning_amber_rounded,
              accent: const Color(0xFFEF5350),
              expanded: badExpanded,
              onToggle: onToggleBad,
              child: _buildSelectableFactorChips(
                factors: badFactors,
                selectedIds: selectedIds,
                isDark: isDark,
                onChanged: onChanged,
              ),
            ),
          ],
        );
      },
      loading: () {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
      error: (error, stack) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Error loading factors: $error',
                style: TextStyle(fontSize: 12, color: Colors.red),
              ),
              const SizedBox(height: 8),
              Text(
                'Try restarting the app or check Settings → Pre-Sleep Factors',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.red.withOpacity(0.7),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFactorAccordionCard({
    required bool isDark,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
    required bool expanded,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withOpacity(0.2) : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.35)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(icon, color: accent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectableFactorChips({
    required List<SleepFactor> factors,
    required List<String> selectedIds,
    required bool isDark,
    required Function(List<String>) onChanged,
  }) {
    if (factors.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          'No factors in this section yet.',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: factors.map((factor) {
        final isSelected = selectedIds.contains(factor.id);
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            final newIds = List<String>.from(selectedIds);
            if (isSelected) {
              newIds.remove(factor.id);
            } else {
              newIds.add(factor.id);
            }
            onChanged(newIds);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? factor.color.withOpacity(0.2)
                  : (isDark ? Colors.black.withOpacity(0.2) : Colors.white),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? factor.color : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  factor.isGood
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 12,
                  color: factor.isGood
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFEF5350),
                ),
                const SizedBox(width: 4),
                Icon(
                  factor.icon,
                  size: 16,
                  color: isSelected ? factor.color : Colors.grey,
                ),
                const SizedBox(width: 6),
                Text(
                  factor.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? factor.color : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDateAndTemplatesCard(
    BuildContext context,
    bool isDark, {
    required DateTime bedTime,
    required VoidCallback onDateTap,
    required void Function(DateTime bed, DateTime wake, bool isNap)
    onTemplateApply,
  }) {
    final now = DateTime.now();
    final logDate = DateTime(bedTime.year, bedTime.month, bedTime.day);
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateLabel = logDate == today
        ? 'Today'
        : logDate == yesterday
        ? 'Yesterday'
        : DateFormat('EEE, MMM d').format(logDate);
    final anchorDate = DateTime(bedTime.year, bedTime.month, bedTime.day);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.04)
            : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.goldOpacity02 : AppColors.blackOpacity005,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onDateTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.goldOpacity02,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 18,
                        color: AppColors.gold,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        dateLabel,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black87,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.edit_rounded, size: 14, color: AppColors.gold),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildTemplateQuickApply(
            context,
            isDark,
            anchorDate: anchorDate,
            onApply: onTemplateApply,
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateQuickApply(
    BuildContext context,
    bool isDark, {
    required DateTime anchorDate,
    required void Function(DateTime bed, DateTime wake, bool isNap) onApply,
  }) {
    final templatesAsync = ref.watch(sleepTemplatesStreamProvider);
    return templatesAsync.when(
      data: (templates) {
        if (templates.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick presets',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white54 : Colors.black45,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: templates.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final t = templates[index];
                  final accent = t.isNap
                      ? const Color(0xFF9C27B0)
                      : const Color(0xFF42A5F5);
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      final applied = _resolveTemplateDateTimes(t, anchorDate);
                      onApply(applied.bedTime, applied.wakeTime, t.isNap);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.06)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? accent.withOpacity(0.2)
                              : accent.withOpacity(0.15),
                        ),
                        boxShadow: isDark
                            ? null
                            : [
                                BoxShadow(
                                  color: AppColors.blackOpacity005,
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            t.isNap
                                ? Icons.bolt_rounded
                                : Icons.nightlight_round,
                            size: 14,
                            color: accent,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            t.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  /// Resolve template times using the user's selected date (anchorDate).
  /// Templates keep the selected day; cross-midnight templates add a day for wake.
  ({DateTime bedTime, DateTime wakeTime}) _resolveTemplateDateTimes(
    SleepTemplate template,
    DateTime anchorDate,
  ) {
    if (template.crossesMidnight) {
      final bedTime = DateTime(
        anchorDate.year,
        anchorDate.month,
        anchorDate.day,
        template.bedHour,
        template.bedMinute,
      );
      final wakeTime = bedTime.add(
        Duration(
          hours: template.durationMinutes ~/ 60,
          minutes: template.durationMinutes % 60,
        ),
      );
      return (bedTime: bedTime, wakeTime: wakeTime);
    }
    final bedTime = DateTime(
      anchorDate.year,
      anchorDate.month,
      anchorDate.day,
      template.bedHour,
      template.bedMinute,
    );
    final wakeTime = DateTime(
      anchorDate.year,
      anchorDate.month,
      anchorDate.day,
      template.wakeHour,
      template.wakeMinute,
    );
    return (bedTime: bedTime, wakeTime: wakeTime);
  }
}
