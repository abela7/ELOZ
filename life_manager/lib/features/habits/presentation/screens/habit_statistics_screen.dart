import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/habit.dart';
import '../../data/models/habit_score.dart';
import '../../data/models/habit_statistics.dart';
import '../providers/habit_providers.dart' hide habitStatisticsProvider;
import '../providers/habit_score_providers.dart';
import '../providers/habit_statistics_providers.dart';
import '../widgets/statistics_widgets.dart';
import '../widgets/quit_habit_statistics_widget.dart';
import '../widgets/quit_habit_calendar_view.dart';
import '../widgets/temptation_analytics_tab.dart';

/// Comprehensive Statistics Screen for a single habit
class HabitStatisticsScreen extends ConsumerStatefulWidget {
  final String habitId;

  const HabitStatisticsScreen({
    super.key,
    required this.habitId,
  });

  @override
  ConsumerState<HabitStatisticsScreen> createState() => _HabitStatisticsScreenState();
}

class _HabitStatisticsScreenState extends ConsumerState<HabitStatisticsScreen> {
  @override
  Widget build(BuildContext context) {
    final habitAsync = ref.watch(habitByIdProvider(widget.habitId));
    final statisticsAsync = ref.watch(habitStatisticsProvider(widget.habitId));
    final scoreAsync = ref.watch(habitScoreProvider(widget.habitId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return habitAsync.when(
      data: (habit) {
        if (habit == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Habit not found')),
            body: const Center(child: Text('Habit not found')),
          );
        }

        final tabs = <Widget>[
          const Tab(text: 'INSIGHTS'),
          const Tab(text: 'JOURNAL'),
          if (habit.isQuitHabit) const Tab(text: 'TEMPTATIONS'),
        ];

        final tabViews = <Widget>[
          // Statistics Tab
          statisticsAsync.when(
            data: (statistics) => _buildStatisticsTab(context, habit, statistics, scoreAsync, isDark),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('Error: $error')),
          ),
          // Calendar Tab
          statisticsAsync.when(
            data: (statistics) => _buildCalendarTab(context, habit, statistics, isDark),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('Error: $error')),
          ),
          if (habit.isQuitHabit)
            TemptationAnalyticsTab(
              habit: habit,
              isDark: isDark,
            ),
        ];

        return DefaultTabController(
          length: tabs.length,
          child: Scaffold(
            backgroundColor: isDark ? const Color(0xFF16181D) : const Color(0xFFF8F9FA),
            body: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                _buildSliverAppBar(context, habit, statisticsAsync, isDark, tabs),
              ],
              body: TabBarView(
                children: tabViews,
              ),
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildSliverAppBar(
    BuildContext context,
    Habit habit,
    AsyncValue<HabitStatistics> statisticsAsync,
    bool isDark,
    List<Widget> tabs,
  ) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      stretch: true,
      backgroundColor: isDark ? const Color(0xFF16181D) : Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, 
          color: isDark ? Colors.white : Colors.black87, size: 20),
        onPressed: () => Navigator.of(context).pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground, StretchMode.blurBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Background Pattern/Gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    habit.color.withOpacity(isDark ? 0.15 : 0.1),
                    isDark ? const Color(0xFF16181D) : Colors.white,
                  ],
                ),
              ),
            ),
            
            // Hero Content
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 80, 24, 60),
              child: Row(
                children: [
                  // Large Icon
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [habit.color, habit.color.withOpacity(0.7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: habit.color.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      habit.icon ?? Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          habit.title,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : Colors.black87,
                            letterSpacing: -0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        statisticsAsync.when(
                          data: (stats) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: (stats.allTimeCompletionRate >= 80 ? Colors.green : 
                                     stats.allTimeCompletionRate >= 50 ? Colors.orange : Colors.red)
                                     .withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${stats.allTimeCompletionRate.toStringAsFixed(0)}% Overall Success',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: stats.allTimeCompletionRate >= 80 ? Colors.green : 
                                       stats.allTimeCompletionRate >= 50 ? Colors.orange : Colors.red,
                              ),
                            ),
                          ),
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
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
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF16181D) : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                width: 1,
              ),
            ),
          ),
          child: TabBar(
            indicatorColor: habit.color,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: habit.color,
            labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5),
            unselectedLabelColor: isDark ? Colors.white38 : Colors.black38,
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            tabs: tabs,
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsTab(
    BuildContext context,
    Habit habit,
    HabitStatistics statistics,
    AsyncValue<HabitScore> scoreAsync,
    bool isDark,
  ) {
    if (!statistics.hasData) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.analytics_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'NO DATA YET',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Keep track of your habit for a few days to see detailed performance insights.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1) Strength Score
          scoreAsync.when(
            data: (score) {
              if (score.analysisDays >= 1) {
                return Column(
                  children: [
                    ScoreOverviewCard(score: score, habitColor: habit.color, isDark: isDark),
                    const SizedBox(height: 24),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // 2) Trends
          _buildSectionTitle('TRENDS', Icons.auto_graph_rounded, habit.color, isDark),
          const SizedBox(height: 16),
          TrendSection(statistics: statistics, habit: habit, isDark: isDark),
          const SizedBox(height: 24),

          // 3) Consistency and Streak
          _StreakSection(statistics: statistics, habit: habit, isDark: isDark),
          const SizedBox(height: 24),

          // 4) Score Breakdown
          scoreAsync.when(
            data: (score) {
              if (score.analysisDays >= 1) {
                return Column(
                  children: [
                    _ScoreBreakdownSection(
                      score: score,
                      habit: habit,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 24),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // 5) Performance Breakdown
          _buildSectionTitle('PERFORMANCE BREAKDOWN', Icons.donut_large_rounded, habit.color, isDark),
          const SizedBox(height: 16),
          SuccessFailChart(statistics: statistics, habit: habit, isDark: isDark),
          const SizedBox(height: 24),

          // 6) Weekly Distribution
          _buildSectionTitle('WEEKLY DISTRIBUTION', Icons.calendar_view_week_rounded, habit.color, isDark),
          const SizedBox(height: 16),
          WeekdayDistributionChart(statistics: statistics, habit: habit, isDark: isDark),
          const SizedBox(height: 24),

          // The rest
          if (habit.completionType == 'timer' || habit.completionType == 'numeric')
            ...[
              _buildSectionTitle('PROGRESS METRICS', Icons.insights_rounded, habit.color, isDark),
              const SizedBox(height: 16),
              if (habit.completionType == 'timer')
                _TimerStatisticsSection(statistics: statistics, habit: habit, isDark: isDark),
              if (habit.completionType == 'numeric')
                _NumericStatisticsSection(statistics: statistics, habit: habit, isDark: isDark),
              const SizedBox(height: 24),
            ],
          if (statistics.bestWeekStart != null || statistics.bestMonthStart != null)
            ...[
              _buildSectionTitle('MILESTONES', Icons.emoji_events_rounded, const Color(0xFF4CAF50), isDark),
              const SizedBox(height: 16),
              BestPeriodsSection(statistics: statistics, isDark: isDark),
              const SizedBox(height: 24),
            ],
          if (habit.isQuitHabit)
            ...[
              _buildSectionTitle('QUIT INSIGHTS', Icons.health_and_safety_rounded, habit.color, isDark),
              const SizedBox(height: 16),
              QuitHabitStatisticsWidget(
                habit: habit,
                statistics: statistics,
                isDark: isDark,
                showRecentActivity: false,
              ),
              const SizedBox(height: 24),
            ],

          // Keep completions near bottom
          const SizedBox(height: 8),
          _CompletionsSection(statistics: statistics, habit: habit, isDark: isDark),
          const SizedBox(height: 24),

          // Recent activity is always at the very bottom
          _buildSectionTitle('RECENT ACTIVITY', Icons.history_rounded, const Color(0xFF90A4AE), isDark),
          const SizedBox(height: 16),
          HistorySection(statistics: statistics, habit: habit, isDark: isDark),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Color color, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color.withOpacity(0.8)),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Divider(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
            thickness: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarTab(
    BuildContext context,
    Habit habit,
    HabitStatistics statistics,
    bool isDark,
  ) {
    // Use enhanced calendar for quit habits
    if (habit.isQuitHabit) {
      return QuitHabitCalendarView(
        habit: habit,
        statistics: statistics,
        isDark: isDark,
      );
    }
    
    // Regular calendar for normal habits
    return CalendarView(
      habit: habit,
      statistics: statistics,
      isDark: isDark,
    );
  }

}

/// Streak Section
class _StreakSection extends StatelessWidget {
  final HabitStatistics statistics;
  final Habit habit;
  final bool isDark;

  const _StreakSection({
    required this.statistics,
    required this.habit,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final score = statistics.consistencyScore.clamp(0.0, 100.0);
    final scoreColor = _scoreColor(score);
    final scoreLabel = _scoreLabel(score);

    return StatCard(
      title: 'Consistency & Streaks',
      icon: Icons.local_fire_department_rounded,
      iconColor: scoreColor,
      isDark: isDark,
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Consistency Score',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: scoreColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  scoreLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: scoreColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                '${score.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: score / 100,
                      child: Container(
                        height: 10,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [scoreColor.withOpacity(0.7), scoreColor],
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: StatItem(
                  label: 'Current',
                  value: '${statistics.currentStreak}',
                  unit: 'days',
                  color: const Color(0xFFFF6B6B),
                ),
              ),
              Container(
                width: 1.5,
                height: 30,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              Expanded(
                child: StatItem(
                  label: 'Best Ever',
                  value: '${statistics.bestStreak}',
                  unit: 'days',
                  color: const Color(0xFFFFB347),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _scoreColor(double score) {
    if (score >= 85) return const Color(0xFF4CAF50);
    if (score >= 70) return const Color(0xFFCDAF56);
    if (score >= 50) return const Color(0xFFFFB347);
    return const Color(0xFFFF6B6B);
  }

  String _scoreLabel(double score) {
    if (score >= 85) return 'Excellent';
    if (score >= 70) return 'Good';
    if (score >= 50) return 'Fair';
    return 'Needs Focus';
  }
}

class _ScoreBreakdownSection extends StatefulWidget {
  final HabitScore score;
  final Habit habit;
  final bool isDark;

  const _ScoreBreakdownSection({
    required this.score,
    required this.habit,
    required this.isDark,
  });
  @override
  State<_ScoreBreakdownSection> createState() => _ScoreBreakdownSectionState();
}

class _ScoreBreakdownSectionState extends State<_ScoreBreakdownSection> {
  final Set<int> _expanded = <int>{};

  void _toggleMetric(int index) {
    setState(() {
      if (_expanded.contains(index)) {
        _expanded.remove(index);
      } else {
        _expanded.add(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scoreColor = Color(widget.score.scoreColorValue);
    final metrics = <_ScoreMetric>[
      _ScoreMetric(
        label: 'Completion Rate',
        value: widget.score.completionRateScore,
        details: 'Successful logs vs expected schedule.',
      ),
      _ScoreMetric(
        label: 'Streak Power',
        value: widget.score.streakScore,
        details: 'Current streak strength vs your best streak.',
      ),
      _ScoreMetric(
        label: 'Consistency',
        value: widget.score.consistencyScore,
        details: 'How steadily you follow your planned frequency.',
      ),
      _ScoreMetric(
        label: 'Momentum',
        value: widget.score.trendScore,
        details: 'Recent period compared with earlier period.',
      ),
      if (widget.habit.frequencyType == 'daily')
        _ScoreMetric(
          label: 'Recovery',
          value: widget.score.recoveryScore,
          details: 'How quickly you bounce back after missed days.',
        ),
      _ScoreMetric(
        label: widget.habit.completionType == 'timer' || widget.habit.completionType == 'numeric'
            ? 'Target Quality'
            : 'Outcome Quality',
        value: widget.score.qualityScore,
        details: _qualityDetails(),
      ),
    ];

    return StatCard(
      title: 'Score Breakdown',
      icon: Icons.stacked_bar_chart_rounded,
      iconColor: scoreColor,
      isDark: widget.isDark,
      child: Column(
        children: metrics.asMap().entries.map((entry) {
          final index = entry.key;
          final metric = entry.value;
          final isLast = index == metrics.length - 1;
          final value = metric.value.clamp(0.0, 100.0);
          final color = _metricColor(value);
          final isExpanded = _expanded.contains(index);

          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      metric.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: widget.isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _toggleMetric(index),
                    icon: Icon(
                      Icons.help_outline_rounded,
                      size: 16,
                      color: widget.isDark ? Colors.white38 : Colors.black45,
                    ),
                    splashRadius: 16,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${value.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                ],
              ),
              if (isExpanded) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        metric.details,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: widget.isDark ? Colors.white38 : Colors.black45,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 6),
              Stack(
                children: [
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: widget.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: value / 100,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color.withOpacity(0.7), color],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
              ),
              if (!isLast) const SizedBox(height: 14),
            ],
          );
        }).toList(),
      ),
    );
  }

  Color _metricColor(double value) {
    if (value >= 80) return const Color(0xFF4CAF50);
    if (value >= 60) return const Color(0xFFCDAF56);
    if (value >= 40) return const Color(0xFFFFB347);
    return const Color(0xFFFF6B6B);
  }

  String _qualityDetails() {
    switch (widget.habit.completionType) {
      case 'numeric':
        return 'How often logged values reach the numeric target.';
      case 'timer':
        return 'How often logged duration reaches the time target.';
      case 'checklist':
        return 'How completely checklist items are finished per log.';
      case 'quit':
        return 'Resisted days compared with slip days.';
      case 'yesNo':
      case 'yes_no':
        return 'Share of positive outcomes in your tracked logs.';
      default:
        return 'Quality of tracked outcomes for this habit type.';
    }
  }
}

class _ScoreMetric {
  final String label;
  final double value;
  final String details;

  const _ScoreMetric({
    required this.label,
    required this.value,
    required this.details,
  });
}

/// Timer Statistics Section
class _TimerStatisticsSection extends StatelessWidget {
  final HabitStatistics statistics;
  final Habit habit;
  final bool isDark;

  const _TimerStatisticsSection({
    required this.statistics,
    required this.habit,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return StatCard(
      title: 'Time Tracking',
      icon: Icons.timer_rounded,
      iconColor: habit.color,
      isDark: isDark,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: StatItem(
                  label: 'This Week',
                  value: statistics.formatDuration(statistics.minutesThisWeek),
                  color: habit.color,
                ),
              ),
              Expanded(
                child: StatItem(
                  label: 'This Month',
                  value: statistics.formatDuration(statistics.minutesThisMonth),
                  color: habit.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: StatItem(
                  label: 'This Year',
                  value: statistics.formatDuration(statistics.minutesThisYear),
                  color: habit.color,
                ),
              ),
              Expanded(
                child: StatItem(
                  label: 'All Time',
                  value: statistics.formatDuration(statistics.minutesAllTime),
                  color: habit.color,
                ),
              ),
            ],
          ),
          if (statistics.averageMinutesPerCompletion != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome_rounded, color: habit.color, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Average session: ${statistics.formatDuration(statistics.averageMinutesPerCompletion!.toInt())}',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Numeric Statistics Section
class _NumericStatisticsSection extends StatelessWidget {
  final HabitStatistics statistics;
  final Habit habit;
  final bool isDark;

  const _NumericStatisticsSection({
    required this.statistics,
    required this.habit,
    required this.isDark,
  });

  String _formatValue(double? value) {
    if (value == null) return '0';
    if (value % 1 == 0) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final unit = habit.customUnitName ?? habit.unit ?? 'units';

    return StatCard(
      title: 'Value Progress',
      icon: Icons.analytics_rounded,
      iconColor: habit.color,
      isDark: isDark,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: StatItem(
                  label: 'This Week',
                  value: _formatValue(statistics.totalValueThisWeek),
                  unit: unit,
                  color: habit.color,
                ),
              ),
              Expanded(
                child: StatItem(
                  label: 'This Month',
                  value: _formatValue(statistics.totalValueThisMonth),
                  unit: unit,
                  color: habit.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: StatItem(
                  label: 'This Year',
                  value: _formatValue(statistics.totalValueThisYear),
                  unit: unit,
                  color: habit.color,
                ),
              ),
              Expanded(
                child: StatItem(
                  label: 'All Time',
                  value: _formatValue(statistics.totalValueAllTime),
                  unit: unit,
                  color: habit.color,
                ),
              ),
            ],
          ),
          if (statistics.averageValuePerCompletion != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome_rounded, color: habit.color, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Average: ${_formatValue(statistics.averageValuePerCompletion)} $unit per session',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black87,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Completions Section
class _CompletionsSection extends StatelessWidget {
  final HabitStatistics statistics;
  final Habit habit;
  final bool isDark;

  const _CompletionsSection({
    required this.statistics,
    required this.habit,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return StatCard(
      title: 'Completions',
      icon: Icons.check_circle_rounded,
      iconColor: const Color(0xFF4CAF50),
      isDark: isDark,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: StatItemWithRate(
                  label: 'This Week',
                  value: '${statistics.completionsThisWeek}/${statistics.expectedThisWeek}',
                  rate: statistics.weekCompletionRate,
                  color: const Color(0xFF4CAF50),
                ),
              ),
              Expanded(
                child: StatItemWithRate(
                  label: 'This Month',
                  value: '${statistics.completionsThisMonth}/${statistics.expectedThisMonth}',
                  rate: statistics.monthCompletionRate,
                  color: const Color(0xFF4CAF50),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: StatItemWithRate(
                  label: 'This Year',
                  value: '${statistics.completionsThisYear}/${statistics.expectedThisYear}',
                  rate: statistics.yearCompletionRate,
                  color: const Color(0xFF4CAF50),
                ),
              ),
              Expanded(
                child: StatItemWithRate(
                  label: 'All Time',
                  value: '${statistics.completionsAllTime}',
                  rate: statistics.allTimeCompletionRate,
                  color: const Color(0xFF4CAF50),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
