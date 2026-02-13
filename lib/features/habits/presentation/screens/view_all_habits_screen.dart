import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../../core/theme/dark_gradient.dart';
import '../../data/models/habit.dart';
import '../../data/services/quit_habit_report_security_service.dart';
import '../providers/habit_providers.dart';
import '../widgets/habit_detail_modal.dart';
import '../widgets/log_temptation_modal.dart';
import '../widgets/skip_reason_dialog.dart';
import '../widgets/habit_score_card.dart';
import '../services/quit_habit_report_access_guard.dart';
import 'create_habit_screen.dart';

/// View All Habits Screen - List and Grid view modes with advanced filtering and Calendar
class ViewAllHabitsScreen extends ConsumerStatefulWidget {
  const ViewAllHabitsScreen({super.key});

  @override
  ConsumerState<ViewAllHabitsScreen> createState() =>
      _ViewAllHabitsScreenState();
}

class _ViewAllHabitsScreenState extends ConsumerState<ViewAllHabitsScreen>
    with SingleTickerProviderStateMixin {
  // View mode: true = List, false = Grid
  bool _isListView = true;

  // Date selection
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  bool _showCalendar = false;
  final ScrollController _dateStripController = ScrollController();

  // Filters
  static const List<String> _subFilterOptions = [
    'Total',
    'Completed',
    'Pending',
    'Missed',
    'Skipped',
    'Streaks',
    'Special',
    'Quit',
  ];
  String _subFilter = 'Total';

  // Search state
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _searchQuery = '';
  final QuitHabitReportAccessGuard _quitAccessGuard =
      QuitHabitReportAccessGuard();
  final QuitHabitReportSecurityService _quitSecurityService =
      QuitHabitReportSecurityService();
  bool _requiresQuitUnlock = false;
  bool _quitPolicyLoaded = false;
  bool _isUnlockingQuitAccess = false;
  List<Habit>? _cachedAllHabitsRef;
  Map<String, HabitDayStatus>? _cachedStatusesRef;
  DateTime? _cachedFilterDateOnly;
  String? _cachedSubFilter;
  String? _cachedSearchKey;
  bool? _cachedRequiresQuitUnlock;
  bool? _cachedQuitPolicyLoaded;
  bool? _cachedSessionUnlocked;
  List<Habit> _cachedFilteredHabits = const <Habit>[];

  @override
  void initState() {
    super.initState();
    _refreshQuitProtectionPolicy();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Keep "today" visible and active on first load.
      _scrollDateStripToToday(jump: true);
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
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

  void _scrollDateStripToToday({bool jump = false}) {
    if (!_dateStripController.hasClients) return;
    // With startDate = today - 6, today's index is 6.
    const itemExtent = 72.0; // 60 width + 12 right margin
    const todayIndex = 6;
    final target = (todayIndex * itemExtent).toDouble().clamp(
      0.0,
      _dateStripController.position.maxScrollExtent,
    );

    if (jump) {
      _dateStripController.jumpTo(target);
    } else {
      _dateStripController.animateTo(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _syncPendingMissedFilterForDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);
    final isPastDay = dateOnly.isBefore(today);

    // Avoid "empty list" confusion when switching between past and today/future.
    if (isPastDay && _subFilter == 'Pending') {
      _subFilter = 'Missed';
    } else if (!isPastDay && _subFilter == 'Missed') {
      _subFilter = 'Pending';
    }
  }

  void _onSwipe(bool isRightSwipe) {
    if (_isSearching || _isSelectionMode || _isUnlockingQuitAccess) return;

    final currentIndex = _subFilterOptions.indexOf(_subFilter);
    int nextIndex;

    if (isRightSwipe) {
      nextIndex =
          (currentIndex - 1 + _subFilterOptions.length) %
          _subFilterOptions.length;
    } else {
      nextIndex = (currentIndex + 1) % _subFilterOptions.length;
    }

    final nextFilter = _subFilterOptions[nextIndex];
    _selectSubFilter(nextFilter);
  }

  Future<void> _selectSubFilter(String filter) async {
    if (filter == _subFilter || _isUnlockingQuitAccess) return;
    final wantsQuit = filter == 'Quit';
    if (wantsQuit) {
      // Obscure content immediately to avoid any visible flash while lock checks run.
      setState(() {
        _subFilter = 'Quit';
        _isUnlockingQuitAccess = true;
      });
    }

    if (!_quitPolicyLoaded) {
      await _refreshQuitProtectionPolicy();
      if (!mounted) return;
    }

    if (wantsQuit &&
        _requiresQuitUnlock &&
        !_quitAccessGuard.isSettingsSessionUnlocked) {
      final unlocked = await _quitAccessGuard.ensureQuitHabitsAccess(
        context,
        onSecurityEmergencyReset: () async {
          await ref.read(habitNotifierProvider.notifier).loadHabits();
        },
      );
      if (!mounted) return;
      if (!unlocked) {
        // Stay on locked Quit tab with blur so sensitive content is never shown.
        setState(() => _isUnlockingQuitAccess = false);
        return;
      }
      // Pre-open encrypted Hive boxes (I/O), then reload habits so quit
      // habits appear immediately. Skip background backfill to avoid a
      // redundant double-reload cycle.
      final notifier = ref.read(habitNotifierProvider.notifier);
      await notifier.warmUpSecureBoxes();
      unawaited(notifier.loadHabits(runBackgroundBackfill: false));
      _invalidateFilterCache();
      setState(() => _isUnlockingQuitAccess = false);
      HapticFeedback.selectionClick();
      return;
    }

    if (!mounted) return;
    setState(() {
      _subFilter = filter;
      _isUnlockingQuitAccess = false;
    });
    HapticFeedback.selectionClick();
  }

  Future<void> _refreshQuitProtectionPolicy() async {
    final settings = await _quitSecurityService.getSettings();
    final hasPasscode = await _quitSecurityService.hasPasscode();
    if (!mounted) return;
    setState(() {
      _requiresQuitUnlock = settings.enabled && hasPasscode;
      _quitPolicyLoaded = true;
    });
  }

  Future<void> _unlockQuitHabitsFromEmptyState() async {
    if (_isUnlockingQuitAccess) return;
    setState(() => _isUnlockingQuitAccess = true);
    final unlocked = await _quitAccessGuard.ensureQuitHabitsAccess(
      context,
      onSecurityEmergencyReset: () async {
        await ref.read(habitNotifierProvider.notifier).loadHabits();
      },
    );
    if (!mounted) return;
    if (!unlocked) {
      setState(() => _isUnlockingQuitAccess = false);
      return;
    }
    // Pre-open encrypted Hive boxes then reload habits.
    final notifier = ref.read(habitNotifierProvider.notifier);
    await notifier.warmUpSecureBoxes();
    unawaited(notifier.loadHabits(runBackgroundBackfill: false));
    _invalidateFilterCache();
    setState(() {
      _quitPolicyLoaded = true;
      _isUnlockingQuitAccess = false;
    });
  }

  /// Wipe the cached filter output so the next build() recomputes from fresh
  /// provider data. Call whenever the quit session state changes.
  void _invalidateFilterCache() {
    _cachedAllHabitsRef = null;
    _cachedStatusesRef = null;
    _cachedFilteredHabits = const <Habit>[];
  }

  // Selection Mode State
  bool _isSelectionMode = false;
  final Set<String> _selectedHabitIds = {};

  void _enterSelectionMode(String initialHabitId) {
    setState(() {
      _isSelectionMode = true;
      _selectedHabitIds.add(initialHabitId);
    });
    HapticFeedback.mediumImpact();
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedHabitIds.clear();
    });
  }

  void _toggleHabitSelection(String habitId) {
    setState(() {
      if (_selectedHabitIds.contains(habitId)) {
        _selectedHabitIds.remove(habitId);
        if (_selectedHabitIds.isEmpty) _exitSelectionMode();
      } else {
        _selectedHabitIds.add(habitId);
      }
    });
    HapticFeedback.lightImpact();
  }

  void _selectAll(List<Habit> habits) {
    setState(() {
      final allIds = habits.map((h) => h.id).toSet();
      final isAllSelected = allIds.every(
        (id) => _selectedHabitIds.contains(id),
      );

      if (isAllSelected) {
        _selectedHabitIds.removeAll(allIds);
        if (_selectedHabitIds.isEmpty) _exitSelectionMode();
      } else {
        _selectedHabitIds.addAll(allIds);
      }
    });
    HapticFeedback.mediumImpact();
  }

  Future<void> _performBulkAction(String action, List<Habit> habits) async {
    final selectedIds = _selectedHabitIds.toList();
    if (selectedIds.isEmpty) return;

    final notifier = ref.read(habitNotifierProvider.notifier);
    final habitsById = {for (final habit in habits) habit.id: habit};

    if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Habits'),
          content: Text(
            'Are you sure you want to delete ${selectedIds.length} habits? This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    // Handle skip action separately to show reason dialog
    if (action == 'skip') {
      if (selectedIds.length == 1) {
        // For single habit, show reason dialog
        final habit = ref
            .read(habitNotifierProvider)
            .value
            ?.firstWhere((h) => h.id == selectedIds.first);
        if (habit != null) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final String? reason = await showDialog<String>(
            context: context,
            builder: (context) =>
                SkipReasonDialog(isDark: isDark, habitName: habit.title),
          );

          if (reason != null) {
            await notifier.skipHabitForDate(
              selectedIds.first,
              _selectedDate,
              reason: reason,
            );
            _exitSelectionMode();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Habit skipped: $reason'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        }
        return;
      } else {
        // For multiple habits, skip with generic reason
        for (final id in selectedIds) {
          await notifier.skipHabitForDate(
            id,
            _selectedDate,
            reason: 'Bulk skip',
          );
        }
        _exitSelectionMode();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${selectedIds.length} habits skipped'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    }

    if (action == 'done') {
      int valueRequiredSkipped = 0;
      for (final id in selectedIds) {
        final habit = habitsById[id];
        if (habit == null) continue;
        if (habit.isNumeric || habit.isTimer) {
          valueRequiredSkipped++;
          if (selectedIds.length == 1) {
            _exitSelectionMode();
            _showHabitDetail(habit);
            return;
          }
          continue;
        }
        await notifier.completeHabitForDate(id, _selectedDate);
      }
      _exitSelectionMode();
      if (mounted) {
        String message;
        if (valueRequiredSkipped == selectedIds.length) {
          message =
              'Timer/numeric habits need a value. Open each habit to log.';
        } else if (valueRequiredSkipped > 0) {
          final completedCount = selectedIds.length - valueRequiredSkipped;
          message =
              '$completedCount habits marked as done • $valueRequiredSkipped need value';
        } else {
          message = '${selectedIds.length} habits marked as done';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
        );
      }
      return;
    }

    for (final id in selectedIds) {
      switch (action) {
        case 'done':
          await notifier.completeHabitForDate(id, _selectedDate);
          break;
        case 'skip':
          await notifier.skipHabitForDate(id, _selectedDate);
          break;
        case 'undo':
          await notifier.uncompleteHabitForDate(id, _selectedDate);
          break;
        case 'archive':
          await notifier.archiveHabit(id);
          break;
        case 'delete':
          await notifier.deleteHabit(id);
          break;
      }
    }

    _exitSelectionMode();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${selectedIds.length} habits ${action == 'done'
                ? 'marked as done'
                : action == 'skip'
                ? 'skipped'
                : action == 'archive'
                ? 'archived'
                : 'deleted'}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  List<Habit> _filterHabits(
    List<Habit> allHabits,
    Map<String, HabitDayStatus> statusesForSelectedDate,
  ) {
    final showHiddenQuit = _subFilter == 'Quit';
    final quitLocked =
        !_quitPolicyLoaded ||
        (_requiresQuitUnlock && !_quitAccessGuard.isSettingsSessionUnlocked);
    final query = _isSearching ? _searchQuery : '';
    final isSearchActive = query.isNotEmpty;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDateOnly = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final isPastDay = selectedDateOnly.isBefore(today);

    if (showHiddenQuit) {
      if (quitLocked) return const <Habit>[];

      final quitOnly = <Habit>[];
      for (final h in allHabits) {
        if (h.isArchived || !h.isQuitHabit) continue;
        if (!h.isDueOn(_selectedDate)) continue;

        if (isSearchActive) {
          final inTitle = h.title.toLowerCase().contains(query);
          final inDescription =
              h.description?.toLowerCase().contains(query) ?? false;
          if (!inTitle && !inDescription) continue;
        }

        quitOnly.add(h);
      }
      // Keep notifier order (sortOrder/createdAt) to avoid extra work.
      return quitOnly;
    }

    final filtered = <Habit>[];

    // Single-pass filter to reduce per-frame allocations on large habit lists.
    for (final h in allHabits) {
      if (h.isArchived) continue;

      if (h.shouldHideQuitHabit) continue;
      if (quitLocked && h.isQuitHabit) continue;

      // Only show habits relevant to the selected date.
      if (!h.isDueOn(_selectedDate)) continue;

      // When searching, skip status sub-filters and only match text.
      if (isSearchActive) {
        final inTitle = h.title.toLowerCase().contains(query);
        final inDescription =
            h.description?.toLowerCase().contains(query) ?? false;
        if (!inTitle && !inDescription) continue;
        filtered.add(h);
        continue;
      }

      final status = statusesForSelectedDate[h.id] ?? HabitDayStatus.empty;
      final isCompleted = status.isCompleted;
      final isDeferred = status.isDeferred;
      bool matchesSubFilter;
      switch (_subFilter) {
        case 'Completed':
          matchesSubFilter = isCompleted;
          break;
        case 'Pending':
          matchesSubFilter = !isPastDay && !isCompleted && !isDeferred;
          break;
        case 'Missed':
          matchesSubFilter = isPastDay && !isCompleted && !isDeferred;
          break;
        case 'Skipped':
          matchesSubFilter = isDeferred;
          break;
        case 'Streaks':
          matchesSubFilter = h.currentStreak > 0;
          break;
        case 'Special':
          matchesSubFilter = h.isSpecial;
          break;
        case 'Quit':
          matchesSubFilter = !quitLocked && h.isQuitHabit;
          break;
        case 'Total':
        default:
          matchesSubFilter = true;
          break;
      }
      if (matchesSubFilter) {
        filtered.add(h);
      }
    }

    // Sorting: special first, then streaks, then title
    filtered.sort((a, b) {
      if (a.isSpecial && !b.isSpecial) return -1;
      if (!a.isSpecial && b.isSpecial) return 1;
      if (a.currentStreak != b.currentStreak) {
        return b.currentStreak.compareTo(a.currentStreak);
      }
      return a.title.compareTo(b.title);
    });

    return filtered;
  }

  List<Habit> _getFilteredHabitsCached(
    List<Habit> allHabits,
    Map<String, HabitDayStatus> statusesForSelectedDate,
  ) {
    final selectedDateOnly = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final searchKey = _isSearching ? _searchQuery : '';
    final sessionUnlocked = _quitAccessGuard.isSettingsSessionUnlocked;
    final canReuse =
        identical(_cachedAllHabitsRef, allHabits) &&
        identical(_cachedStatusesRef, statusesForSelectedDate) &&
        _cachedFilterDateOnly == selectedDateOnly &&
        _cachedSubFilter == _subFilter &&
        _cachedSearchKey == searchKey &&
        _cachedRequiresQuitUnlock == _requiresQuitUnlock &&
        _cachedQuitPolicyLoaded == _quitPolicyLoaded &&
        _cachedSessionUnlocked == sessionUnlocked;
    if (canReuse) {
      return _cachedFilteredHabits;
    }

    final filtered = _filterHabits(allHabits, statusesForSelectedDate);
    _cachedAllHabitsRef = allHabits;
    _cachedStatusesRef = statusesForSelectedDate;
    _cachedFilterDateOnly = selectedDateOnly;
    _cachedSubFilter = _subFilter;
    _cachedSearchKey = searchKey;
    _cachedRequiresQuitUnlock = _requiresQuitUnlock;
    _cachedQuitPolicyLoaded = _quitPolicyLoaded;
    _cachedSessionUnlocked = sessionUnlocked;
    _cachedFilteredHabits = filtered;

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final habitsAsync = ref.watch(habitNotifierProvider);
    final isQuitTab = _subFilter == 'Quit';
    final dayStatusesAsync = isQuitTab
        ? const AsyncValue<Map<String, HabitDayStatus>>.data(
            <String, HabitDayStatus>{},
          )
        : ref.watch(
            habitStatusesOnDateProvider(
              DateTime(
                _selectedDate.year,
                _selectedDate.month,
                _selectedDate.day,
              ),
            ),
          );

    return Scaffold(
      body: isDark
          ? DarkGradient.wrap(
              child: _buildContent(
                context,
                isDark,
                habitsAsync,
                dayStatusesAsync,
              ),
            )
          : _buildContent(context, isDark, habitsAsync, dayStatusesAsync),
    );
  }

  Widget _buildContent(
    BuildContext context,
    bool isDark,
    AsyncValue<List<Habit>> habitsAsync,
    AsyncValue<Map<String, HabitDayStatus>> dayStatusesAsync,
  ) {
    final statusesForSelectedDate = dayStatusesAsync.maybeWhen(
      data: (statuses) => statuses,
      orElse: () => const <String, HabitDayStatus>{},
    );
    final filteredHabits = habitsAsync.maybeWhen(
      data: (allHabits) =>
          _getFilteredHabitsCached(allHabits, statusesForSelectedDate),
      orElse: () => const <Habit>[],
    );
    final showScoreBadges = _subFilter != 'Quit';
    final quitLockedOverlay =
        _subFilter == 'Quit' &&
        (!_quitPolicyLoaded ||
            (_requiresQuitUnlock &&
                !_quitAccessGuard.isSettingsSessionUnlocked));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: _isSelectionMode
          ? AppBar(
              backgroundColor: isDark ? Colors.black26 : Colors.white,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelectionMode,
              ),
              title: Text('${_selectedHabitIds.length} Selected'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.select_all),
                  tooltip: 'Select All',
                  onPressed: () => _selectAll(filteredHabits),
                ),
                IconButton(
                  icon: const Icon(Icons.check_circle_outlined),
                  tooltip: 'Mark Done',
                  onPressed: () => habitsAsync.whenData(
                    (habits) => _performBulkAction('done', habits),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.undo),
                  tooltip: 'Undo',
                  onPressed: () => habitsAsync.whenData(
                    (habits) => _performBulkAction('undo', habits),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete',
                  color: Colors.red[400],
                  onPressed: () => habitsAsync.whenData(
                    (habits) => _performBulkAction('delete', habits),
                  ),
                ),
              ],
            )
          : AppBar(
              title: _isSearching
                  ? TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search habits...',
                        hintStyle: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                        border: InputBorder.none,
                      ),
                      onChanged: _onSearchChanged,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Habits Manager'),
                        Text(
                          DateFormat('EEE, MMM d, yyyy').format(_selectedDate),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
              actions: [
                if (_isSearching)
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(() {
                      _isSearching = false;
                      _searchController.clear();
                      _searchDebounce?.cancel();
                      _searchQuery = '';
                    }),
                  )
                else ...[
                  IconButton(
                    icon: Icon(
                      _showCalendar
                          ? Icons.calendar_today
                          : Icons.calendar_month_rounded,
                    ),
                    onPressed: () =>
                        setState(() => _showCalendar = !_showCalendar),
                    tooltip: 'Show Calendar',
                    color: _showCalendar ? const Color(0xFFCDAF56) : null,
                  ),
                  if (!isSameDay(_selectedDate, DateTime.now()))
                    IconButton(
                      icon: const Icon(Icons.today_rounded),
                      onPressed: () {
                        setState(() {
                          _selectedDate = DateTime.now();
                          _focusedDay = DateTime.now();
                          _showCalendar = false;
                          _syncPendingMissedFilterForDate(_selectedDate);
                        });
                      },
                      tooltip: 'Jump to Today',
                    ),
                  IconButton(
                    icon: const Icon(Icons.search_rounded),
                    onPressed: () => setState(() => _isSearching = true),
                  ),
                ],
                if (!_isSearching)
                  IconButton(
                    icon: Icon(
                      _isListView
                          ? Icons.grid_view_rounded
                          : Icons.view_list_rounded,
                    ),
                    onPressed: () => setState(() => _isListView = !_isListView),
                    tooltip: _isListView ? 'Grid View' : 'List View',
                  ),
              ],
            ),
      body: Stack(
        children: [
          AbsorbPointer(
            absorbing: _isUnlockingQuitAccess,
            child: Column(
              children: [
                if (!_isSearching && !_isSelectionMode) ...[
                  if (_showCalendar) _buildCalendar(isDark),
                  _buildHorizontalDatePicker(isDark),
                  _buildSubFilters(context, isDark),
                ] else if (_isSearching)
                  const SizedBox(height: 12),

                Expanded(
                  child: GestureDetector(
                    onHorizontalDragEnd: (details) {
                      if (details.primaryVelocity == null) return;
                      if (details.primaryVelocity! > 500)
                        _onSwipe(true);
                      else if (details.primaryVelocity! < -500)
                        _onSwipe(false);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: habitsAsync.when(
                      data: (_) {
                        return _isListView
                            ? _buildListView(
                                context,
                                isDark,
                                filteredHabits,
                                statusesForSelectedDate,
                                showScoreBadges: showScoreBadges,
                              )
                            : _buildGridView(
                                context,
                                isDark,
                                filteredHabits,
                                statusesForSelectedDate,
                                showScoreBadges: showScoreBadges,
                              );
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, stack) =>
                          Center(child: Text('Error: $error')),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isUnlockingQuitAccess || quitLockedOverlay)
            Positioned.fill(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: 0.22),
                      ),
                    ),
                  ),
                  if (_isUnlockingQuitAccess)
                    const Center(
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  else
                    Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E2228).withValues(alpha: 0.9)
                              : Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(
                              0xFFCDAF56,
                            ).withValues(alpha: 0.35),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.lock_rounded,
                              color: Color(0xFFCDAF56),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Quit habits are locked',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            ElevatedButton.icon(
                              onPressed: _unlockQuitHabitsFromEmptyState,
                              icon: const Icon(Icons.lock_open_rounded),
                              label: const Text('Unlock'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFCDAF56),
                                foregroundColor: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCalendar(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D3139) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TableCalendar(
            firstDay: DateTime.now().subtract(const Duration(days: 365)),
            lastDay: DateTime.now().add(const Duration(days: 365)),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDate, day),
            calendarFormat: CalendarFormat.month,
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDate = selectedDay;
                _focusedDay = focusedDay;
                _showCalendar =
                    false; // Collapse calendar after selection to "activate" it
                _syncPendingMissedFilterForDate(selectedDay);
              });
              HapticFeedback.lightImpact();
            },
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
              leftChevronIcon: Icon(
                Icons.chevron_left,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
              rightChevronIcon: Icon(
                Icons.chevron_right,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            calendarStyle: CalendarStyle(
              selectedDecoration: const BoxDecoration(
                color: Color(0xFFCDAF56),
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: const Color(0xFFCDAF56).withOpacity(0.3),
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
          // Explicit "Apply" button to address user's "enter/right button" question
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Center(
              child: TextButton.icon(
                onPressed: () => setState(() => _showCalendar = false),
                icon: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFFCDAF56),
                  size: 18,
                ),
                label: const Text(
                  'Apply Selection',
                  style: TextStyle(
                    color: Color(0xFFCDAF56),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalDatePicker(bool isDark) {
    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);
    // 2-week window centered around TODAY. The user can scroll
    // backward/forward, and today stays visible by default.
    final startDate = todayOnly.subtract(const Duration(days: 6));

    return Container(
      height: 90,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        controller: _dateStripController,
        itemCount: 14,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) {
          final date = startDate.add(Duration(days: index));
          final isSelected = isSameDay(_selectedDate, date);
          final isToday = isSameDay(todayOnly, date);

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDate = date;
                _focusedDay = date;
                _syncPendingMissedFilterForDate(date);
              });
              HapticFeedback.lightImpact();
            },
            child: Container(
              width: 60,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFCDAF56)
                    : (isDark ? const Color(0xFF2D3139) : Colors.white),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFCDAF56)
                      : (isToday
                            ? const Color(0xFFCDAF56).withOpacity(0.5)
                            : Colors.transparent),
                  width: 1.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFFCDAF56).withOpacity(0.3),
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
                          ? Colors.white
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
                          ? Colors.white
                          : (isDark ? Colors.white : Colors.black),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSubFilters(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _subFilterOptions.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _subFilterOptions[index];
          final isSelected = _subFilter == filter;

          Color chipColor;
          switch (filter) {
            case 'Completed':
              chipColor = Colors.green;
              break;
            case 'Pending':
              chipColor = const Color(0xFFFFA726);
              break;
            case 'Missed':
              chipColor = const Color(0xFFFFB347);
              break;
            case 'Skipped':
              chipColor = Colors.orange;
              break;
            case 'Streaks':
              chipColor = Colors.red;
              break;
            case 'Special':
              chipColor = const Color(0xFFCDAF56);
              break;
            case 'Quit':
              chipColor = Colors.purple;
              break;
            default:
              chipColor = const Color(0xFFCDAF56);
          }

          return FilterChip(
            label: Text(filter),
            selected: isSelected,
            onSelected: (selected) => _selectSubFilter(filter),
            selectedColor: chipColor.withOpacity(0.25),
            backgroundColor: isDark ? const Color(0xFF2D3139) : Colors.white,
            labelStyle: TextStyle(
              color: isSelected
                  ? chipColor
                  : (isDark ? Colors.grey[400] : Colors.grey[700]),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            ),
            side: BorderSide(
              color: isSelected
                  ? chipColor
                  : (isDark ? const Color(0xFF3E4148) : Colors.grey[300]!),
              width: isSelected ? 1.5 : 1,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            showCheckmark: false,
            avatar: isSelected
                ? Icon(_getFilterIcon(filter), size: 14, color: chipColor)
                : null,
          );
        },
      ),
    );
  }

  IconData _getFilterIcon(String filter) {
    switch (filter) {
      case 'Completed':
        return Icons.check_circle_rounded;
      case 'Pending':
        return Icons.pending_rounded;
      case 'Missed':
        return Icons.error_outline_rounded;
      case 'Skipped':
        return Icons.skip_next_rounded;
      case 'Streaks':
        return Icons.local_fire_department_rounded;
      case 'Special':
        return Icons.star_rounded;
      case 'Quit':
        return Icons.block_rounded;
      default:
        return Icons.list_rounded;
    }
  }

  Widget _buildListView(
    BuildContext context,
    bool isDark,
    List<Habit> habits,
    Map<String, HabitDayStatus> statusesForSelectedDate, {
    required bool showScoreBadges,
  }) {
    if (habits.isEmpty) return _buildEmptyState(isDark);

    return ListView.builder(
      key: ValueKey('list_${_selectedDate.toIso8601String()}$_subFilter'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      itemCount: habits.length,
      itemBuilder: (context, index) {
        final habit = habits[index];
        final dayStatus =
            statusesForSelectedDate[habit.id] ?? HabitDayStatus.empty;
        final isSelected = _selectedHabitIds.contains(habit.id);

        return RepaintBoundary(
          child: _HabitListCard(
            habit: habit,
            dayStatus: dayStatus,
            selectedDate: _selectedDate,
            isDark: isDark,
            isSelectionMode: _isSelectionMode,
            isSelected: isSelected,
            showScoreBadge: showScoreBadges,
            onTap: () {
              if (_isSelectionMode)
                _toggleHabitSelection(habit.id);
              else
                _showHabitDetail(habit);
            },
            onLongPress: () {
              if (_isSelectionMode) {
                _toggleHabitSelection(habit.id);
              } else {
                _showHabitContextMenu(habit, isDark);
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildGridView(
    BuildContext context,
    bool isDark,
    List<Habit> habits,
    Map<String, HabitDayStatus> statusesForSelectedDate, {
    required bool showScoreBadges,
  }) {
    if (habits.isEmpty) return _buildEmptyState(isDark);

    return GridView.builder(
      key: ValueKey('grid_${_selectedDate.toIso8601String()}$_subFilter'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: habits.length,
      itemBuilder: (context, index) {
        final habit = habits[index];
        final dayStatus =
            statusesForSelectedDate[habit.id] ?? HabitDayStatus.empty;
        final isSelected = _selectedHabitIds.contains(habit.id);

        return RepaintBoundary(
          child: _HabitGridCard(
            habit: habit,
            dayStatus: dayStatus,
            selectedDate: _selectedDate,
            isDark: isDark,
            isSelectionMode: _isSelectionMode,
            isSelected: isSelected,
            showScoreBadge: showScoreBadges,
            onTap: () {
              if (_isSelectionMode)
                _toggleHabitSelection(habit.id);
              else
                _showHabitDetail(habit);
            },
            onLongPress: () {
              if (_isSelectionMode) {
                _toggleHabitSelection(habit.id);
              } else {
                _showHabitContextMenu(habit, isDark);
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final quitLocked =
        !_quitPolicyLoaded ||
        (_requiresQuitUnlock && !_quitAccessGuard.isSettingsSessionUnlocked);
    final showUnlockAction =
        quitLocked &&
        _requiresQuitUnlock &&
        (_subFilter == 'Quit' || _subFilter == 'Total');
    String message;
    switch (_subFilter) {
      case 'Completed':
        message = 'No completed habits for this date';
        break;
      case 'Pending':
        message = 'No pending habits for this date';
        break;
      case 'Missed':
        message = 'Nothing missed on this date';
        break;
      case 'Skipped':
        message = 'No skipped habits for this date';
        break;
      case 'Streaks':
        message = 'No streak habits for this date';
        break;
      case 'Special':
        message = 'No special habits for this date';
        break;
      case 'Quit':
        message = quitLocked
            ? 'Quit habits are locked. Unlock required.'
            : 'No quit habits for this date';
        break;
      default:
        message = showUnlockAction
            ? 'Quit habits are hidden until you unlock them'
            : 'No habits found for this date';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            size: 64,
            color: isDark ? Colors.white10 : Colors.grey[200],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          if (showUnlockAction) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _unlockQuitHabitsFromEmptyState,
              icon: const Icon(Icons.lock_open_rounded),
              label: const Text('Unlock Quit Habits'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFCDAF56),
                side: const BorderSide(color: Color(0xFFCDAF56)),
              ),
            ),
          ],
          if (_subFilter == 'Total' && _requiresQuitUnlock) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _selectSubFilter('Quit'),
              icon: const Icon(Icons.visibility_rounded),
              label: const Text('Open Quit Tab'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFCDAF56),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showHabitDetail(Habit habit) {
    HabitDetailModal.show(context, habit: habit, selectedDate: _selectedDate);
  }

  void _showHabitContextMenu(Habit habit, bool isDark) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final mediaQuery = MediaQuery.of(ctx);
        final keyboardInset = mediaQuery.viewInsets.bottom;
        final maxHeight = (mediaQuery.size.height - keyboardInset - 32).clamp(
          240.0,
          mediaQuery.size.height * 0.85,
        );
        return SafeArea(
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(bottom: keyboardInset),
            child: Container(
              margin: const EdgeInsets.all(16),
              constraints: BoxConstraints(maxHeight: maxHeight),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF252A31) : Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: Text(
                        habit.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(
                        habit.isSpecial
                            ? Icons.star_outline_rounded
                            : Icons.star_rounded,
                        color: const Color(0xFFCDAF56),
                      ),
                      title: Text(
                        habit.isSpecial ? 'Unstar Habit' : 'Star Habit',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      subtitle: Text(
                        habit.isSpecial
                            ? 'Remove from special habits'
                            : 'Make this a special habit',
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                      onTap: () async {
                        Navigator.pop(ctx);
                        final updated = habit.copyWith(
                          isSpecial: !habit.isSpecial,
                        );
                        await ref
                            .read(habitNotifierProvider.notifier)
                            .updateHabit(updated);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              updated.isSpecial
                                  ? 'Habit marked as special'
                                  : 'Habit removed from special',
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.edit_rounded,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                      title: Text(
                        'Edit Habit',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      onTap: () async {
                        Navigator.pop(ctx);
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CreateHabitScreen(habit: habit),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.check_circle_outline_rounded,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                      title: Text(
                        'Select Habit',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      subtitle: Text(
                        'Enter selection mode for bulk actions',
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        _enterSelectionMode(habit.id);
                      },
                    ),
                    if (habit.isQuitHabit)
                      ListTile(
                        leading: const Icon(
                          Icons.psychology_rounded,
                          color: Color(0xFF9C27B0),
                        ),
                        title: Text(
                          'Log Temptation',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        subtitle: Text(
                          'Record a temptation for this habit',
                          style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          LogTemptationModal.show(
                            context,
                            habit: habit,
                            habitId: habit.id,
                            habitTitle: habit.title,
                            defaultDate: _selectedDate,
                            onLogged: () {
                              ref
                                  .read(habitNotifierProvider.notifier)
                                  .loadHabits();
                            },
                          );
                        },
                      ),
                    ListTile(
                      leading: Icon(
                        Icons.delete_rounded,
                        color: Colors.red[400],
                      ),
                      title: Text(
                        'Delete Habit',
                        style: TextStyle(color: Colors.red[400]),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showHabitDeleteConfirmation(habit, isDark);
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showHabitDeleteConfirmation(Habit habit, bool isDark) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF2D3139) : Colors.white,
        title: const Text('Delete Habit'),
        content: Text('Delete "${habit.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(habitNotifierProvider.notifier).deleteHabit(habit.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Habit deleted'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _HabitListCard extends ConsumerWidget {
  final Habit habit;
  final HabitDayStatus dayStatus;
  final DateTime selectedDate;
  final bool isDark;
  final bool isSelectionMode;
  final bool isSelected;
  final bool showScoreBadge;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _HabitListCard({
    required this.habit,
    required this.dayStatus,
    required this.selectedDate,
    required this.isDark,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.showScoreBadge = true,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeColor = habit.color;
    final notifier = ref.read(habitNotifierProvider.notifier);
    final isCompleted = dayStatus.isCompleted;
    final isSkipped = dayStatus.isSkipped;
    final isPostponed = dayStatus.isPostponed;
    final isDeferred = isSkipped || isPostponed;

    Future<void> onSwipeDone() async {
      if (isCompleted) return;
      if (habit.hasSubtasks && !habit.isChecklistFullyCompleted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please finish all subtasks first!'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      if (habit.isNumeric || habit.isTimer) {
        HapticFeedback.selectionClick();
        onTap();
        return;
      }
      await notifier.completeHabitForDate(habit.id, selectedDate);
      HapticFeedback.lightImpact();
    }

    Future<void> onSwipeNotDone() async {
      if (habit.isQuitHabit) {
        await showHabitSlipTrackingModal(
          context,
          habit: habit,
          selectedDate: selectedDate,
        );
        return;
      }

      final reason = await showDialog<String>(
        context: context,
        builder: (_) => SkipReasonDialog(
          isDark: Theme.of(context).brightness == Brightness.dark,
          habitName: habit.title,
        ),
      );
      if (reason == null || !context.mounted) return;

      if (isCompleted || isDeferred) {
        await notifier.uncompleteHabitForDate(habit.id, selectedDate);
      }
      await notifier.skipHabitForDate(habit.id, selectedDate, reason: reason);
      HapticFeedback.mediumImpact();
    }

    return Dismissible(
      key: ValueKey('list-${habit.id}-${selectedDate.toIso8601String()}'),
      direction: isSelectionMode
          ? DismissDirection.none
          : DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await onSwipeDone();
          return false;
        }
        if (direction == DismissDirection.endToStart) {
          await onSwipeNotDone();
          return false;
        }
        return false;
      },
      background: _buildSwipeBackground(
        icon: Icons.check_rounded,
        label: habit.isNumeric || habit.isTimer ? 'Log Value' : 'Mark Done',
        alignment: Alignment.centerLeft,
        color: const Color(0xFF2E7D32),
      ),
      secondaryBackground: _buildSwipeBackground(
        icon: Icons.close_rounded,
        label: 'Not Done',
        alignment: Alignment.centerRight,
        color: const Color(0xFFD84315),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark
              ? (isSelected
                    ? const Color(0xFFCDAF56).withOpacity(0.15)
                    : const Color(0xFF2D3139))
              : (isSelected
                    ? const Color(0xFFCDAF56).withOpacity(0.1)
                    : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFCDAF56)
                : themeColor.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (isSelectionMode)
                  Container(
                    margin: const EdgeInsets.only(right: 16),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? const Color(0xFFCDAF56)
                          : Colors.transparent,
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFCDAF56)
                            : Colors.grey,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  )
                else
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isCompleted
                            ? [
                                Colors.green.withOpacity(0.2),
                                Colors.green.withOpacity(0.1),
                              ]
                            : (isDeferred
                                  ? [
                                      Colors.orange.withOpacity(0.2),
                                      Colors.orange.withOpacity(0.1),
                                    ]
                                  : [
                                      themeColor.withOpacity(0.2),
                                      themeColor.withOpacity(0.1),
                                    ]),
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      isCompleted
                          ? Icons.check_circle_rounded
                          : (isDeferred
                                ? Icons.schedule_rounded
                                : (habit.icon ?? Icons.auto_awesome_rounded)),
                      color: isCompleted
                          ? Colors.green
                          : (isDeferred ? Colors.orange : themeColor),
                      size: 24,
                    ),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              habit.title,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF1E1E1E),
                                    decoration: isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (habit.isSpecial) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFCDAF56,
                                ).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(
                                    0xFFCDAF56,
                                  ).withOpacity(0.35),
                                  width: 1,
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.star_rounded,
                                    size: 10,
                                    color: Color(0xFFCDAF56),
                                  ),
                                  SizedBox(width: 3),
                                  Text(
                                    'SPECIAL',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFCDAF56),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.repeat_rounded,
                            size: 12,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              habit.frequencyDescription,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white54 : Colors.black54,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (habit.hasSpecificTime &&
                              habit.habitTime != null) ...[
                            const SizedBox(width: 12),
                            Icon(
                              Icons.access_time_rounded,
                              size: 12,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              habit.habitTime!.format(context),
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white54 : Colors.black54,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          if (habit.currentStreak > 0) ...[
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.local_fire_department_rounded,
                                    size: 10,
                                    color: Colors.red[400],
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${habit.currentStreak}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.red[400],
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (showScoreBadge) ...[
                  const SizedBox(width: 8),
                  HabitScoreBadge(habitId: habit.id, size: 28),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwipeBackground({
    required IconData icon,
    required String label,
    required Alignment alignment,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.25 : 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: alignment,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HabitGridCard extends ConsumerWidget {
  final Habit habit;
  final HabitDayStatus dayStatus;
  final DateTime selectedDate;
  final bool isDark;
  final bool isSelectionMode;
  final bool isSelected;
  final bool showScoreBadge;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _HabitGridCard({
    required this.habit,
    required this.dayStatus,
    required this.selectedDate,
    required this.isDark,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.showScoreBadge = true,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeColor = habit.color;
    final notifier = ref.read(habitNotifierProvider.notifier);
    final isCompleted = dayStatus.isCompleted;
    final isSkipped = dayStatus.isSkipped;
    final isPostponed = dayStatus.isPostponed;
    final isDeferred = isSkipped || isPostponed;

    final cardColor = isSelected
        ? const Color(0xFFCDAF56).withOpacity(isDark ? 0.2 : 0.1)
        : (isDark ? const Color(0xFF2D3139) : Colors.white);

    Future<void> onSwipeDone() async {
      if (isCompleted) return;
      if (habit.hasSubtasks && !habit.isChecklistFullyCompleted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please finish all subtasks first!'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      if (habit.isNumeric || habit.isTimer) {
        HapticFeedback.selectionClick();
        onTap();
        return;
      }
      await notifier.completeHabitForDate(habit.id, selectedDate);
      HapticFeedback.lightImpact();
    }

    Future<void> onSwipeNotDone() async {
      if (habit.isQuitHabit) {
        await showHabitSlipTrackingModal(
          context,
          habit: habit,
          selectedDate: selectedDate,
        );
        return;
      }

      final reason = await showDialog<String>(
        context: context,
        builder: (_) => SkipReasonDialog(
          isDark: Theme.of(context).brightness == Brightness.dark,
          habitName: habit.title,
        ),
      );
      if (reason == null || !context.mounted) return;

      if (isCompleted || isDeferred) {
        await notifier.uncompleteHabitForDate(habit.id, selectedDate);
      }
      await notifier.skipHabitForDate(habit.id, selectedDate, reason: reason);
      HapticFeedback.mediumImpact();
    }

    return Dismissible(
      key: ValueKey('grid-${habit.id}-${selectedDate.toIso8601String()}'),
      direction: isSelectionMode
          ? DismissDirection.none
          : DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await onSwipeDone();
          return false;
        }
        if (direction == DismissDirection.endToStart) {
          await onSwipeNotDone();
          return false;
        }
        return false;
      },
      background: _buildSwipeBackground(
        icon: Icons.check_rounded,
        label: habit.isNumeric || habit.isTimer ? 'Log' : 'Done',
        alignment: Alignment.centerLeft,
        color: const Color(0xFF2E7D32),
      ),
      secondaryBackground: _buildSwipeBackground(
        icon: Icons.close_rounded,
        label: 'Not Done',
        alignment: Alignment.centerRight,
        color: const Color(0xFFD84315),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFCDAF56)
                : (isCompleted
                      ? Colors.green.withOpacity(0.3)
                      : (isDeferred
                            ? Colors.orange.withOpacity(0.3)
                            : themeColor.withOpacity(0.15))),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFCDAF56).withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Stack(
              children: [
                // Background Pattern/Icon
                Positioned(
                  right: -15,
                  top: -15,
                  child: Opacity(
                    opacity: 0.04,
                    child: Icon(
                      habit.icon ?? Icons.auto_awesome_rounded,
                      size: 100,
                      color: themeColor,
                    ),
                  ),
                ),
                if (habit.isSpecial)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCDAF56).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFCDAF56).withOpacity(0.35),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.star_rounded,
                        size: 14,
                        color: Color(0xFFCDAF56),
                      ),
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row: Status Icon & Score
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (isSelectionMode)
                            _buildSelectionIndicator()
                          else
                            _buildStatusIcon(
                              isCompleted,
                              isSkipped,
                              isPostponed,
                              themeColor,
                            ),
                          if (showScoreBadge)
                            HabitScoreBadge(habitId: habit.id, size: 22)
                          else
                            const SizedBox(width: 22, height: 22),
                        ],
                      ),

                      const Spacer(),

                      // Habit Info
                      Text(
                        habit.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1E1E1E),
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: isDark
                              ? Colors.white38
                              : Colors.black38,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 8),

                      // Stats & Frequency Row
                      Row(
                        children: [
                          if (habit.currentStreak > 0) ...[
                            Icon(
                              Icons.local_fire_department_rounded,
                              size: 14,
                              color: Colors.red[400],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${habit.currentStreak}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red[400],
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(
                              habit.frequencyDescription,
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? Colors.white54 : Colors.black54,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      if (habit.hasSpecificTime && habit.habitTime != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 12,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              habit.habitTime!.format(context),
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? Colors.white54 : Colors.black54,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Bottom Progress Bar (Visual touch)
                if (isCompleted)
                  Positioned(
                    bottom: 0,
                    left: 20,
                    right: 20,
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(3),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.5),
                            blurRadius: 4,
                          ),
                        ],
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

  Widget _buildSelectionIndicator() {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? const Color(0xFFCDAF56) : Colors.transparent,
        border: Border.all(
          color: isSelected ? const Color(0xFFCDAF56) : Colors.grey,
          width: 2,
        ),
      ),
      child: isSelected
          ? const Icon(Icons.check, size: 16, color: Colors.white)
          : null,
    );
  }

  Widget _buildStatusIcon(
    bool isCompleted,
    bool isSkipped,
    bool isPostponed,
    Color themeColor,
  ) {
    final statusColor = isCompleted
        ? Colors.green
        : (isSkipped || isPostponed ? Colors.orange : themeColor);
    final icon = isCompleted
        ? Icons.check_circle_rounded
        : (isPostponed
              ? Icons.schedule_rounded
              : (isSkipped
                    ? Icons.skip_next_rounded
                    : (habit.icon ?? Icons.auto_awesome_rounded)));

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 18, color: statusColor),
    );
  }

  Widget _buildSwipeBackground({
    required IconData icon,
    required String label,
    required Alignment alignment,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.25 : 0.15),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: alignment,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
