import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/dark_gradient.dart';
import '../../../../core/widgets/date_navigator_widget.dart';
import '../../data/models/habit.dart';
import '../../data/services/quit_habit_report_security_service.dart';
import '../providers/habit_providers.dart';
import '../providers/habit_statistics_providers.dart';
import '../widgets/habit_score_card.dart';
import 'habit_settings_screen.dart';
import 'create_habit_screen.dart';
import 'view_all_habits_screen.dart';
import 'habit_calendar_screen.dart';
import 'habit_report_screen.dart';
import 'quit_habit_report_screen.dart';
import '../services/quit_habit_report_access_guard.dart';
import '../widgets/habit_detail_modal.dart';
import '../widgets/log_temptation_modal.dart';
import '../widgets/skip_reason_dialog.dart';

/// Habits Screen - Habit Mini-App Dashboard (matching Tasks dashboard structure)
class HabitsScreen extends ConsumerStatefulWidget {
  const HabitsScreen({super.key});

  @override
  ConsumerState<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends ConsumerState<HabitsScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _isSearching = false;
  bool _showCompletedHabits = false; // Accordion state for completed habits
  bool _showSkippedHabits = false; // Accordion state for skipped habits
  bool _showNotDueHabits = false; // Accordion state for not-due habits
  String _selectedFilter =
      'total'; // Filter: 'total', 'completed', 'pending', 'streak'
  String _sortBy = 'priority'; // 'priority', 'alphabetical', 'streak', 'newest'
  final List<String> _activeCategories = [];
  bool _showOnlySpecial = false;
  final TextEditingController _searchController = TextEditingController();
  final QuitHabitReportAccessGuard _quitAccessGuard =
      QuitHabitReportAccessGuard();
  final QuitHabitReportSecurityService _quitSecurityService =
      QuitHabitReportSecurityService();
  bool _requiresQuitUnlock = true;
  bool _quitPolicyLoaded = false;

  bool get _quitHabitsLocked =>
      !_quitPolicyLoaded ||
      (_requiresQuitUnlock && !_quitAccessGuard.isSettingsSessionUnlocked);

  @override
  void initState() {
    super.initState();
    _refreshQuitProtectionPolicy();
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
    final unlocked = await _quitAccessGuard.ensureQuitHabitsAccess(
      context,
      onSecurityEmergencyReset: () async {
        await ref.read(habitNotifierProvider.notifier).loadHabits();
      },
    );
    if (!mounted || !unlocked) return;
    // Unlock only changes session visibility, not habit records.
    setState(() {
      _quitPolicyLoaded = true;
    });
  }

  void _showFilterSortModal(BuildContext context, bool isDark) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bg = isDark ? const Color(0xFF1E2228) : Colors.white;
            final text = isDark ? Colors.white : const Color(0xFF1A1C1E);
            final accent = const Color(0xFFCDAF56);

            Widget sectionTitle(String title) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  title,
                  style: TextStyle(
                    color: text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              );
            }

            Widget filterChip(
              String label,
              bool isSelected,
              VoidCallback onTap,
            ) {
              return Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 8),
                child: InkWell(
                  onTap: () {
                    onTap();
                    setModalState(() {});
                    setState(() {});
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? accent
                          : (isDark
                                ? Colors.white.withOpacity(0.05)
                                : Colors.black.withOpacity(0.05)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? accent
                            : (isDark ? Colors.white12 : Colors.black12),
                      ),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? Colors.black : text,
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            }

            return Container(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white12 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Advanced Filters',
                          style: TextStyle(
                            color: text,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedFilter = 'total';
                            _sortBy = 'priority';
                            _activeCategories.clear();
                            _showOnlySpecial = false;
                          });
                          setModalState(() {});
                        },
                        child: Text(
                          'Clear All',
                          style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  sectionTitle('STATUS'),
                  Wrap(
                    children: [
                      filterChip(
                        'All Pending',
                        _selectedFilter == 'total',
                        () => _selectedFilter = 'total',
                      ),
                      filterChip(
                        'Completed',
                        _selectedFilter == 'completed',
                        () => _selectedFilter = 'completed',
                      ),
                      filterChip(
                        'Pending Only',
                        _selectedFilter == 'pending',
                        () => _selectedFilter = 'pending',
                      ),
                      filterChip(
                        'With Streaks',
                        _selectedFilter == 'streak',
                        () => _selectedFilter = 'streak',
                      ),
                    ],
                  ),

                  sectionTitle('SORT BY'),
                  Wrap(
                    children: [
                      filterChip(
                        'Priority',
                        _sortBy == 'priority',
                        () => _sortBy = 'priority',
                      ),
                      filterChip(
                        'Alphabetical',
                        _sortBy == 'alphabetical',
                        () => _sortBy = 'alphabetical',
                      ),
                      filterChip(
                        'Highest Streak',
                        _sortBy == 'streak',
                        () => _sortBy = 'streak',
                      ),
                      filterChip(
                        'Newest First',
                        _sortBy == 'newest',
                        () => _sortBy = 'newest',
                      ),
                    ],
                  ),

                  sectionTitle('PREFERENCES'),
                  Wrap(
                    children: [
                      filterChip(
                        'Special Only Ô¡É',
                        _showOnlySpecial,
                        () => _showOnlySpecial = !_showOnlySpecial,
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Apply Filters',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final habitsAsync = ref.watch(habitNotifierProvider);

    return Scaffold(
      body: isDark
          ? DarkGradient.wrap(
              child: _buildContent(context, isDark, habitsAsync),
            )
          : _buildContent(context, isDark, habitsAsync),
    );
  }

  Widget _buildContent(
    BuildContext context,
    bool isDark,
    AsyncValue<List<Habit>> habitsAsync,
  ) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: isDark ? Colors.white : Colors.black,
                ),
                decoration: InputDecoration(
                  hintText: 'Search habits...',
                  hintStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() {});
                },
              )
            : const Text('Habits'),
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchController.clear();
                });
              },
              tooltip: 'Close Search',
            )
          else
            IconButton(
              icon: const Icon(Icons.search_rounded),
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
              tooltip: 'Search Habits',
            ),
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.add_rounded),
              onPressed: () {
                _showAddHabitPlaceholder(context);
              },
              tooltip: 'New Habit',
            ),
        ],
      ),
      body: SafeArea(
        child: habitsAsync.when(
          data: (habits) {
            if (_isSearching && _searchController.text.isNotEmpty) {
              return _buildSearchResults(context, isDark, habits);
            }
            return _buildHabitsContent(context, isDark);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) =>
              Center(child: Text('Error loading habits: $error')),
        ),
      ),
    );
  }

  Widget _buildSearchResults(
    BuildContext context,
    bool isDark,
    List<Habit> allHabits,
  ) {
    final quitLocked = _quitHabitsLocked;
    final searchQuery = _searchController.text.toLowerCase();
    final filteredHabits = allHabits
        .where((h) => !h.shouldHideQuitHabit)
        .where((h) => !(quitLocked && h.isQuitHabit))
        .where(
          (h) =>
              h.title.toLowerCase().contains(searchQuery) ||
              (h.description?.toLowerCase().contains(searchQuery) ?? false),
        )
        .toList();
    filteredHabits.sort((a, b) {
      if (a.isSpecial != b.isSpecial) {
        return a.isSpecial ? -1 : 1;
      }
      return a.title.compareTo(b.title);
    });

    if (filteredHabits.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: isDark ? Colors.white10 : Colors.grey[200],
            ),
            const SizedBox(height: 16),
            Text(
              'No habits match your search',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 100),
      itemCount: filteredHabits.length,
      itemBuilder: (context, index) {
        final habit = filteredHabits[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _HabitCard(
            habit: habit,
            isDark: isDark,
            selectedDate: _selectedDate,
            onTap: () {
              // TODO: Open habit detail modal
              _showHabitDetailPlaceholder(context, habit);
            },
            onLongPress: () => _showHabitContextMenu(context, habit, isDark),
          ),
        );
      },
    );
  }

  Widget _buildHabitsContent(
    BuildContext context,
    bool isDark,
  ) {
    final quitLocked = _quitHabitsLocked;
    final selectedDateOnly = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final dailyStatsAsync = ref.watch(dailyHabitStatsProvider(selectedDateOnly));
    final dashboardLists = ref.watch(
      habitsDashboardListsProvider((
        date: selectedDateOnly,
        quitLocked: quitLocked,
        selectedFilter: _selectedFilter,
        sortBy: _sortBy,
        showOnlySpecial: _showOnlySpecial,
      )),
    );

    return dailyStatsAsync.when(
      data: (stats) {
        final displayHabits = dashboardLists.displayHabits;
        final completedHabitsList = dashboardLists.completedHabits;
        final skippedHabitsList = dashboardLists.skippedHabits;
        final notDueHabits = dashboardLists.notDueHabits;

        final hasHabitsToShow =
            displayHabits.isNotEmpty ||
            (_selectedFilter == 'total' &&
                (completedHabitsList.isNotEmpty ||
                    skippedHabitsList.isNotEmpty ||
                    notDueHabits.isNotEmpty));

        // Calculate progress percentage
        final progress = stats.total > 0 ? stats.completed / stats.total : 0.0;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity != null &&
                details.primaryVelocity! > 500) {
              HapticFeedback.selectionClick();
              setState(() {
                _selectedDate = _selectedDate.subtract(const Duration(days: 1));
              });
            } else if (details.primaryVelocity != null &&
                details.primaryVelocity! < -500) {
              HapticFeedback.selectionClick();
              setState(() {
                _selectedDate = _selectedDate.add(const Duration(days: 1));
              });
            }
          },
          child: ListView(
            padding: const EdgeInsets.only(bottom: 100),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: DateNavigatorWidget(
                  selectedDate: _selectedDate,
                  onDateChanged: (newDate) {
                    setState(() {
                      _selectedDate = newDate;
                    });
                  },
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.5,
                  children: [
                    _StatCard(
                      label: 'Total',
                      value: stats.total.toString(),
                      icon: Icons.auto_awesome_rounded,
                      accentColor: const Color(0xFFCDAF56),
                      isDark: isDark,
                      isSelected: _selectedFilter == 'total',
                      onTap: () => setState(() => _selectedFilter = 'total'),
                    ),
                    _StatCard(
                      label: 'Completed',
                      value: stats.completed.toString(),
                      icon: Icons.check_circle_rounded,
                      accentColor: const Color(0xFF4CAF50),
                      isDark: isDark,
                      isSelected: _selectedFilter == 'completed',
                      onTap: () =>
                          setState(() => _selectedFilter = 'completed'),
                    ),
                    _StatCard(
                      label: 'Pending',
                      value: stats.pending.toString(),
                      icon: Icons.pending_rounded,
                      accentColor: const Color(0xFFFFA726),
                      isDark: isDark,
                      isSelected: _selectedFilter == 'pending',
                      onTap: () => setState(() => _selectedFilter = 'pending'),
                    ),
                    _StatCard(
                      label: 'Streaks',
                      value: stats.streaks.toString(),
                      icon: Icons.local_fire_department_rounded,
                      accentColor: const Color(0xFFEF5350),
                      isDark: isDark,
                      isSelected: _selectedFilter == 'streak',
                      onTap: () => setState(() => _selectedFilter = 'streak'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Habits for the Day',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? const Color(0xFFFFFFFF)
                                    : const Color(0xFF1E1E1E),
                              ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.filter_list,
                            color: isDark
                                ? const Color(0xFFBDBDBD)
                                : const Color(0xFF6E6E6E),
                            size: 24,
                          ),
                          onPressed: () =>
                              _showFilterSortModal(context, isDark),
                          tooltip: 'Filter & Sort Habits',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (!hasHabitsToShow)
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Center(
                          child: Column(
                            children: [
                              Text(
                                _selectedFilter == 'total'
                                    ? (quitLocked && _requiresQuitUnlock
                                          ? 'Quit habits are hidden until you unlock them'
                                          : (_requiresQuitUnlock
                                                ? 'No dashboard habits for this day. Quit habits are shown in the Quit view.'
                                                : 'No habits for this day'))
                                    : 'No ${_selectedFilter} habits found',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: isDark
                                          ? const Color(0xFFBDBDBD)
                                          : const Color(0xFF6E6E6E),
                                    ),
                              ),
                              if (_selectedFilter == 'total' &&
                                  quitLocked &&
                                  _requiresQuitUnlock) ...[
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: _unlockQuitHabitsFromEmptyState,
                                  icon: const Icon(Icons.lock_open_rounded),
                                  label: const Text('Unlock Quit Habits'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFCDAF56),
                                    side: const BorderSide(
                                      color: Color(0xFFCDAF56),
                                    ),
                                  ),
                                ),
                              ],
                              if (_selectedFilter == 'total' &&
                                  _requiresQuitUnlock) ...[
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: () =>
                                      _showViewAllPlaceholder(context),
                                  icon: const Icon(Icons.list_rounded),
                                  label: const Text('Open View All'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFFCDAF56),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    else if (displayHabits.isNotEmpty)
                      ...displayHabits.map(
                        (habit) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _HabitCard(
                            habit: habit,
                            isDark: isDark,
                            selectedDate: _selectedDate,
                            onTap: () {
                              _showHabitDetailPlaceholder(context, habit);
                            },
                            onLongPress: () =>
                                _showHabitContextMenu(context, habit, isDark),
                          ),
                        ),
                      ),
                    if (displayHabits.isEmpty &&
                        notDueHabits.isNotEmpty &&
                        _selectedFilter == 'total') ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No habits due today',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: isDark
                                    ? const Color(0xFFBDBDBD)
                                    : const Color(0xFF6E6E6E),
                              ),
                        ),
                      ),
                    ],
                    if (notDueHabits.isNotEmpty &&
                        _selectedFilter == 'total') ...[
                      const SizedBox(height: 16),
                      _NotDueHabitsAccordion(
                        habits: notDueHabits,
                        isDark: isDark,
                        isExpanded: _showNotDueHabits,
                        selectedDate: _selectedDate,
                        onExpansionChanged: (expanded) {
                          setState(() {
                            _showNotDueHabits = expanded;
                          });
                        },
                        onHabitTap: (habit) {
                          _showHabitDetailPlaceholder(context, habit);
                        },
                        onHabitLongPress: (habit) {
                          _showHabitContextMenu(context, habit, isDark);
                        },
                      ),
                    ],
                    if (completedHabitsList.isNotEmpty &&
                        _selectedFilter == 'total') ...[
                      const SizedBox(height: 24),
                      _CompletedHabitsAccordion(
                        completedHabits: completedHabitsList,
                        isDark: isDark,
                        isExpanded: _showCompletedHabits,
                        onExpansionChanged: (expanded) {
                          setState(() {
                            _showCompletedHabits = expanded;
                          });
                        },
                        onHabitTap: (habit) {
                          _showHabitDetailPlaceholder(context, habit);
                        },
                      ),
                    ],
                    if (skippedHabitsList.isNotEmpty &&
                        _selectedFilter == 'total') ...[
                      const SizedBox(height: 16),
                      _SkippedHabitsAccordion(
                        skippedHabits: skippedHabitsList,
                        isDark: isDark,
                        isExpanded: _showSkippedHabits,
                        onExpansionChanged: (expanded) {
                          setState(() {
                            _showSkippedHabits = expanded;
                          });
                        },
                        onHabitTap: (habit) {
                          _showHabitDetailPlaceholder(context, habit);
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF2D3139)
                        : const Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Day's Progress",
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? const Color(0xFFFFFFFF)
                                      : const Color(0xFF1E1E1E),
                                ),
                          ),
                          Text(
                            '${(progress * 100).toStringAsFixed(0)}%',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFCDAF56),
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 10,
                          backgroundColor: isDark
                              ? const Color(0xFF3E4148)
                              : const Color(0xFFEDE9E0),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFFCDAF56),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${stats.completed} of ${stats.total} habits completed',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? const Color(0xFFBDBDBD)
                              : const Color(0xFF6E6E6E),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildQuickActions(context, isDark),
              const SizedBox(height: 16),
              _buildReportButton(context, isDark),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildQuickActions(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFFFFFFF) : const Color(0xFF1E1E1E),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.add_rounded,
                  label: 'Add Habit',
                  isDark: isDark,
                  onTap: () => _showAddHabitPlaceholder(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.list_rounded,
                  label: 'View All',
                  isDark: isDark,
                  onTap: () => _showViewAllPlaceholder(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.calendar_month_rounded,
                  label: 'Calendar',
                  isDark: isDark,
                  onTap: () => _showCalendarPlaceholder(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.settings_rounded,
                  label: 'Settings',
                  isDark: isDark,
                  onTap: () => _showSettingsPlaceholder(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReportButton(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _buildReportActionCard(
            context: context,
            isDark: isDark,
            title: 'Habit Report',
            icon: Icons.assessment_rounded,
            color: const Color(0xFFCDAF56),
            onTap: () => _showReportPlaceholder(context),
          ),
        ],
      ),
    );
  }

  Widget _buildReportActionCard({
    required BuildContext context,
    required bool isDark,
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    String? subtitle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D3139) : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: color.withOpacity(0.15),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 12),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Placeholder functions for screens to be built
  void _showAddHabitPlaceholder(BuildContext context) {
    HapticFeedback.mediumImpact();
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const CreateHabitScreen()));
  }

  void _showHabitDetailPlaceholder(BuildContext context, Habit habit) {
    HabitDetailModal.show(context, habit: habit, selectedDate: _selectedDate);
  }

  void _showHabitContextMenu(BuildContext context, Habit habit, bool isDark) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF252A31) : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
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
                final updated = habit.copyWith(isSpecial: !habit.isSpecial);
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
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
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
            if (habit.isQuitHabit)
              ListTile(
                leading: const Icon(
                  Icons.psychology_rounded,
                  color: Color(0xFF9C27B0),
                ),
                title: Text(
                  'Log Temptation',
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
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
                      ref.read(habitNotifierProvider.notifier).loadHabits();
                    },
                  );
                },
              ),
            ListTile(
              leading: Icon(Icons.delete_rounded, color: Colors.red[400]),
              title: Text(
                'Delete Habit',
                style: TextStyle(color: Colors.red[400]),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showHabitDeleteConfirmation(context, habit, isDark);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _showHabitDeleteConfirmation(
    BuildContext context,
    Habit habit,
    bool isDark,
  ) async {
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

  void _showViewAllPlaceholder(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const ViewAllHabitsScreen()),
    );
  }

  void _showCalendarPlaceholder(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const HabitCalendarScreen()),
    );
  }

  void _showSettingsPlaceholder(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const HabitSettingsScreen()),
    );
  }

  void _showReportPlaceholder(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => HabitReportScreen(initialDate: _selectedDate),
      ),
    );
  }

  Future<void> _showSecureQuitReport(BuildContext context) async {
    final guard = QuitHabitReportAccessGuard();
    final unlocked = await guard.ensureAccess(
      context,
      onSecurityEmergencyReset: () async {
        await ref.read(habitNotifierProvider.notifier).loadHabits();
      },
    );
    if (!context.mounted || !unlocked) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => QuitHabitReportScreen(initialDate: _selectedDate),
      ),
    );
  }
}

/// Stat Card Widget (matching Tasks design exactly)
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;
  final bool isDark;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
    required this.isDark,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    Color.lerp(
                      const Color(0xFF2D3139),
                      accentColor,
                      isSelected ? 0.12 : 0.08,
                    )!,
                    Color.lerp(
                      const Color(0xFF2D3139),
                      accentColor,
                      isSelected ? 0.10 : 0.05,
                    )!,
                  ]
                : [
                    isSelected
                        ? Color.lerp(Colors.white, accentColor, 0.10)!
                        : Colors.white,
                    Color.lerp(
                      Colors.white,
                      accentColor,
                      isSelected ? 0.08 : 0.06,
                    )!,
                  ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? accentColor
                : accentColor.withOpacity(isDark ? 0.3 : 0.2),
            width: 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              // Large watermark icon in background
              Positioned(
                right: -12,
                bottom: -12,
                child: Icon(
                  icon,
                  size: 70,
                  color: accentColor.withOpacity(
                    isSelected
                        ? (isDark ? 0.12 : 0.10)
                        : (isDark ? 0.08 : 0.06),
                  ),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(
                          isSelected
                              ? (isDark ? 0.20 : 0.18)
                              : (isDark ? 0.15 : 0.12),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        color: isSelected
                            ? accentColor
                            : accentColor.withOpacity(0.8),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            value,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1E1E1E),
                                  height: 1.0,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            label,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? Colors.white70
                                      : const Color(0xFF6E6E6E),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quick Action Button (matching Tasks design)
class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D3139) : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCDAF56), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: const Color(0xFFCDAF56).withOpacity(0.2),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: const Color(0xFFCDAF56), size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFFFFFFFF)
                          : const Color(0xFF1E1E1E),
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Habit Card Widget (matching Tasks card structure)
class _HabitCard extends ConsumerWidget {
  final Habit habit;
  final bool isDark;
  final DateTime selectedDate;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _HabitCard({
    required this.habit,
    required this.isDark,
    required this.selectedDate,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCompletedAsync = ref.watch(
      isHabitCompletedOnDateProvider((habitId: habit.id, date: selectedDate)),
    );
    final isSkipped = ref
        .watch(
          isHabitSkippedOnDateProvider((habitId: habit.id, date: selectedDate)),
        )
        .maybeWhen(data: (v) => v, orElse: () => false);
    final isPostponed = ref
        .watch(
          isHabitPostponedOnDateProvider((
            habitId: habit.id,
            date: selectedDate,
          )),
        )
        .maybeWhen(data: (v) => v, orElse: () => false);
    final isDeferred = isSkipped || isPostponed;
    final themeColor = habit.color;

    return isCompletedAsync.maybeWhen(
      data: (isCompleted) {
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
            onTap?.call();
            return;
          }
          await ref
              .read(habitNotifierProvider.notifier)
              .completeHabitForDate(habit.id, selectedDate);
          HapticFeedback.lightImpact();
        }

        Future<void> onSwipeNotDone() async {
          final notifier = ref.read(habitNotifierProvider.notifier);
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
          await notifier.skipHabitForDate(
            habit.id,
            selectedDate,
            reason: reason,
          );
          HapticFeedback.mediumImpact();
        }

        return Dismissible(
          key: ValueKey('${habit.id}-${selectedDate.toIso8601String()}'),
          direction: DismissDirection.horizontal,
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
          background: _buildSwipeActionBackground(
            icon: Icons.check_rounded,
            label: habit.isNumeric || habit.isTimer ? 'Log Value' : 'Mark Done',
            alignment: Alignment.centerLeft,
            color: const Color(0xFF2E7D32),
            isDark: isDark,
          ),
          secondaryBackground: _buildSwipeActionBackground(
            icon: Icons.close_rounded,
            label: 'Not Done',
            alignment: Alignment.centerRight,
            color: const Color(0xFFD84315),
            isDark: isDark,
          ),
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF2D3139)
                        : const Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: themeColor.withOpacity(0.5),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Icon Section - Toggle Button
                        InkWell(
                          onTap: () {
                            if (isCompleted) {
                              ref
                                  .read(habitNotifierProvider.notifier)
                                  .uncompleteHabitForDate(
                                    habit.id,
                                    selectedDate,
                                  );
                            } else {
                              // Check if checklist is completed first
                              if (habit.hasSubtasks &&
                                  !habit.isChecklistFullyCompleted) {
                                HapticFeedback.heavyImpact();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Please finish all subtasks first!',
                                    ),
                                    backgroundColor: Colors.orange,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                return;
                              }
                              if (habit.isNumeric || habit.isTimer) {
                                onTap?.call();
                                return;
                              }
                              ref
                                  .read(habitNotifierProvider.notifier)
                                  .completeHabitForDate(habit.id, selectedDate);
                            }
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: 44,
                            height: 44,
                            margin: const EdgeInsets.only(right: 16),
                            decoration: BoxDecoration(
                              color: themeColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              isCompleted
                                  ? Icons.check_rounded
                                  : (habit.icon ?? Icons.auto_awesome_rounded),
                              color: themeColor,
                              size: 22,
                            ),
                          ),
                        ),

                        // Content Section
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      habit.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                            color: isDark
                                                ? Colors.white
                                                : const Color(0xFF1E1E1E),
                                          ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (habit.isSpecial) ...[
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.star_rounded,
                                      size: 16,
                                      color: Color(0xFFCDAF56),
                                    ),
                                  ],
                                ],
                              ),

                              // Status Badge (mini)
                              if (habit.habitStatus != 'active') ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: habit.statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: habit.statusColor.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        habit.statusIcon,
                                        size: 10,
                                        color: habit.statusColor,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        habit.statusDisplayName,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: habit.statusColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // The Why Quote (Small snippet)
                              if (habit.motivation != null &&
                                  habit.motivation!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '"${habit.motivation}"',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.grey.shade500,
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],

                              // Checklist Progress
                              if (habit.hasSubtasks) ...[
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: habit.checklistProgress,
                                          backgroundColor: themeColor
                                              .withOpacity(0.1),
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                themeColor,
                                              ),
                                          minHeight: 6,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${(habit.checklistProgress * 100).toInt()}%',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: isDark
                                                ? Colors.white54
                                                : Colors.grey.shade600,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      habit.checklistCountString,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: isDark
                                                ? Colors.white38
                                                : Colors.grey.shade400,
                                            fontSize: 10,
                                          ),
                                    ),
                                  ],
                                ),
                              ],

                              const SizedBox(height: 10),

                              // Tags Row
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  // Frequency tag (small size)
                                  _SmartTag.small(
                                    label: habit.frequencyDescription,
                                    color: isDark
                                        ? const Color(0xFFBDBDBD)
                                        : const Color(0xFF6E6E6E),
                                    isDark: isDark,
                                    icon: Icons.repeat_rounded,
                                  ),
                                  if (habit.hasSpecificTime &&
                                      habit.habitTime != null)
                                    _SmartTag.small(
                                      label: habit.habitTime!.format(context),
                                      color: themeColor,
                                      isDark: isDark,
                                      icon: Icons.access_time_rounded,
                                    ),
                                  if (habit.isTimer &&
                                      habit.targetDurationMinutes != null)
                                    _SmartTag.medium(
                                      label:
                                          'Target: ${habit.formatDuration(habit.targetDurationMinutes!, compact: true)}',
                                      color: themeColor,
                                      isDark: isDark,
                                      icon: Icons.timer_rounded,
                                    ),

                                  // Streak tag (small size)
                                  if (habit.currentStreak > 0)
                                    _SmartTag.small(
                                      label: '${habit.currentStreak} streak',
                                      color: const Color(0xFFFF6B6B),
                                      isDark: isDark,
                                      icon: Icons.local_fire_department_rounded,
                                    ),

                                  // Score Badge
                                  HabitScoreBadge(habitId: habit.id, size: 22),

                                  // Completion status (medium size)
                                  if (isCompleted)
                                    _SmartTag.medium(
                                      label: 'Done',
                                      color: const Color(0xFF4CAF50),
                                      isDark: isDark,
                                      icon: Icons.check_circle_rounded,
                                    ),
                                ],
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
      },
      orElse: () => InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2D3139) : const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: themeColor.withOpacity(0.5), width: 1.5),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  color: themeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  habit.icon ?? Icons.auto_awesome_rounded,
                  color: themeColor,
                  size: 22,
                ),
              ),
              Expanded(
                child: Text(
                  habit.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwipeActionBackground({
    required IconData icon,
    required String label,
    required Alignment alignment,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.25 : 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
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

/// Modern Smart Tag Widget with enhanced styling and size variants
class _SmartTag extends StatelessWidget {
  final String label;
  final Color color;
  final bool isDark;
  final IconData? icon;
  final TagSize size;

  const _SmartTag.small({
    required this.label,
    required this.color,
    required this.isDark,
    this.icon,
  }) : size = TagSize.small;

  const _SmartTag.medium({
    required this.label,
    required this.color,
    required this.isDark,
    this.icon,
  }) : size = TagSize.medium;

  @override
  Widget build(BuildContext context) {
    // Size-based styling
    final tagScale = size == TagSize.small ? 0.75 : 1.0;
    final horizontalPadding = 10.0 * tagScale;
    final verticalPadding = 5.0 * tagScale;
    final iconSize = 12.0 * tagScale;
    final fontSize = 11.0 * tagScale;
    final borderRadius = BorderRadius.circular(8.0 * tagScale);
    final borderWidth = 1.0 * tagScale;
    final spacing = 4.0 * tagScale;

    // Modern color palette
    final backgroundColor = _getEnhancedBackgroundColor(color, isDark);
    final borderColor = _getEnhancedBorderColor(color, isDark);
    final textColor = _getEnhancedTextColor(color, isDark);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isDark ? 0.1 : 0.15),
            blurRadius: 3 * tagScale,
            offset: Offset(0, 1 * tagScale),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: iconSize, color: textColor),
            SizedBox(width: spacing),
          ],
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: fontSize,
              fontWeight: size == TagSize.small
                  ? FontWeight.w500
                  : FontWeight.w600,
              letterSpacing: size == TagSize.small ? 0.2 : 0.15,
            ),
          ),
        ],
      ),
    );
  }

  Color _getEnhancedBackgroundColor(Color baseColor, bool isDark) {
    if (isDark) {
      return baseColor.withValues(alpha: 0.15);
    } else {
      return baseColor.withValues(alpha: 0.08);
    }
  }

  Color _getEnhancedBorderColor(Color baseColor, bool isDark) {
    if (isDark) {
      return baseColor.withValues(alpha: 0.25);
    } else {
      return baseColor.withValues(alpha: 0.2);
    }
  }

  Color _getEnhancedTextColor(Color baseColor, bool isDark) {
    if (isDark) {
      return baseColor.withValues(alpha: 0.9);
    } else {
      return baseColor.withValues(alpha: 0.85);
    }
  }
}

enum TagSize {
  small, // 0.75x size for frequency and streak tags
  medium, // 1x size for Done and Target tags
}

/// Completed Habits Accordion (matching Tasks completed accordion)
class _CompletedHabitsAccordion extends StatelessWidget {
  final List<Habit> completedHabits;
  final bool isDark;
  final bool isExpanded;
  final ValueChanged<bool> onExpansionChanged;
  final ValueChanged<Habit> onHabitTap;

  const _CompletedHabitsAccordion({
    required this.completedHabits,
    required this.isDark,
    required this.isExpanded,
    required this.onExpansionChanged,
    required this.onHabitTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D3139) : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF4CAF50).withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Accordion Header
          InkWell(
            onTap: () => onExpansionChanged(!isExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF4CAF50),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Completed Habits',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? const Color(0xFFFFFFFF)
                                    : const Color(0xFF1E1E1E),
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${completedHabits.length} habit${completedHabits.length != 1 ? 's' : ''} completed',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: isDark
                                    ? const Color(0xFFBDBDBD)
                                    : const Color(0xFF6E6E6E),
                              ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: isDark
                          ? const Color(0xFFBDBDBD)
                          : const Color(0xFF6E6E6E),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Accordion Content
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: completedHabits
                    .map(
                      (habit) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _CompletedHabitCard(
                          habit: habit,
                          isDark: isDark,
                          onTap: () => onHabitTap(habit),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }
}

/// Completed Habit Card (simplified for accordion)
class _CompletedHabitCard extends StatelessWidget {
  final Habit habit;
  final bool isDark;
  final VoidCallback onTap;

  const _CompletedHabitCard({
    required this.habit,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF4CAF50).withOpacity(isDark ? 0.1 : 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF4CAF50).withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                habit.icon ?? Icons.check_rounded,
                color: const Color(0xFF4CAF50),
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                habit.title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? const Color(0xFFFFFFFF)
                      : const Color(0xFF1E1E1E),
                  decoration: TextDecoration.lineThrough,
                  decorationColor: isDark
                      ? const Color(0xFFBDBDBD)
                      : const Color(0xFF6E6E6E),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (habit.hasSpecificTime && habit.habitTime != null) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.access_time_rounded,
                size: 12,
                color: isDark
                    ? const Color(0xFFBDBDBD)
                    : const Color(0xFF6E6E6E),
              ),
              const SizedBox(width: 4),
              Text(
                habit.habitTime!.format(context),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: isDark
                      ? const Color(0xFFBDBDBD)
                      : const Color(0xFF6E6E6E),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (habit.currentStreak > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B6B).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.local_fire_department_rounded,
                      size: 12,
                      color: Color(0xFFFF6B6B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${habit.currentStreak}',
                      style: const TextStyle(
                        color: Color(0xFFFF6B6B),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
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

/// Skipped Habits Accordion
class _SkippedHabitsAccordion extends StatelessWidget {
  final List<Habit> skippedHabits;
  final bool isDark;
  final bool isExpanded;
  final ValueChanged<bool> onExpansionChanged;
  final ValueChanged<Habit> onHabitTap;

  const _SkippedHabitsAccordion({
    required this.skippedHabits,
    required this.isDark,
    required this.isExpanded,
    required this.onExpansionChanged,
    required this.onHabitTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D3139) : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFFB347).withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Accordion Header
          InkWell(
            onTap: () => onExpansionChanged(!isExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB347).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.skip_next_rounded,
                      color: Color(0xFFFFB347),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Skipped / Postponed Habits',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? const Color(0xFFFFFFFF)
                                    : const Color(0xFF1E1E1E),
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${skippedHabits.length} habit${skippedHabits.length != 1 ? 's' : ''} skipped or postponed',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: isDark
                                    ? const Color(0xFFBDBDBD)
                                    : const Color(0xFF6E6E6E),
                              ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: isDark
                          ? const Color(0xFFBDBDBD)
                          : const Color(0xFF6E6E6E),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Accordion Content
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: skippedHabits
                    .map(
                      (habit) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _SkippedHabitCard(
                          habit: habit,
                          isDark: isDark,
                          onTap: () => onHabitTap(habit),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }
}

/// Not Due Habits Accordion
class _NotDueHabitsAccordion extends StatelessWidget {
  final List<Habit> habits;
  final bool isDark;
  final bool isExpanded;
  final DateTime selectedDate;
  final ValueChanged<bool> onExpansionChanged;
  final ValueChanged<Habit> onHabitTap;
  final ValueChanged<Habit>? onHabitLongPress;

  const _NotDueHabitsAccordion({
    required this.habits,
    required this.isDark,
    required this.isExpanded,
    required this.selectedDate,
    required this.onExpansionChanged,
    required this.onHabitTap,
    this.onHabitLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D3139) : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF42A5F5).withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Accordion Header
          InkWell(
            onTap: () => onExpansionChanged(!isExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF42A5F5).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.schedule_rounded,
                      color: Color(0xFF42A5F5),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Not Due Today',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? const Color(0xFFFFFFFF)
                                    : const Color(0xFF1E1E1E),
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${habits.length} habit${habits.length != 1 ? 's' : ''} scheduled later',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: isDark
                                    ? const Color(0xFFBDBDBD)
                                    : const Color(0xFF6E6E6E),
                              ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: isDark
                          ? const Color(0xFFBDBDBD)
                          : const Color(0xFF6E6E6E),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Accordion Content
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: habits
                    .map(
                      (habit) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _HabitCard(
                          habit: habit,
                          isDark: isDark,
                          selectedDate: selectedDate,
                          onTap: () => onHabitTap(habit),
                          onLongPress: onHabitLongPress != null
                              ? () => onHabitLongPress!(habit)
                              : null,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }
}

/// Skipped Habit Card (simplified for accordion)
class _SkippedHabitCard extends StatelessWidget {
  final Habit habit;
  final bool isDark;
  final VoidCallback onTap;

  const _SkippedHabitCard({
    required this.habit,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFB347).withOpacity(isDark ? 0.1 : 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFFFB347).withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFFFB347).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                habit.icon ?? Icons.skip_next_rounded,
                color: const Color(0xFFFFB347),
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                habit.title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? const Color(0xFFFFFFFF)
                      : const Color(0xFF1E1E1E),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (habit.hasSpecificTime && habit.habitTime != null) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.access_time_rounded,
                size: 12,
                color: isDark
                    ? const Color(0xFFBDBDBD)
                    : const Color(0xFF6E6E6E),
              ),
              const SizedBox(width: 4),
              Text(
                habit.habitTime!.format(context),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: isDark
                      ? const Color(0xFFBDBDBD)
                      : const Color(0xFF6E6E6E),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const Icon(
              Icons.info_outline_rounded,
              size: 16,
              color: Color(0xFFFFB347),
            ),
          ],
        ),
      ),
    );
  }
}
