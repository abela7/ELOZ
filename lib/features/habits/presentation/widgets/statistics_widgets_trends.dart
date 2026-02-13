part of 'statistics_widgets.dart';

class TrendSection extends StatefulWidget {
  final HabitStatistics statistics;
  final Habit habit;
  final bool isDark;

  const TrendSection({
    super.key,
    required this.statistics,
    required this.habit,
    required this.isDark,
  });

  @override
  State<TrendSection> createState() => _TrendSectionState();
}

/// Simple 7-Day Progress Bar Chart
/// Clean, minimal design showing completion status for each day
class SimpleWeeklyBarChart extends StatelessWidget {
  final HabitStatistics statistics;
  final Habit habit;
  final bool isDark;

  const SimpleWeeklyBarChart({
    super.key,
    required this.statistics,
    required this.habit,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final last7Days = <DateTime>[];
    for (int i = 6; i >= 0; i--) {
      last7Days.add(
        DateTime(now.year, now.month, now.day).subtract(Duration(days: i)),
      );
    }

    // Get data for each day
    final dayData = last7Days.map((date) {
      final key = DateFormat('yyyy-MM-dd').format(date);
      final count = statistics.dailyCompletions[key] ?? 0;
      return (date: date, count: count);
    }).toList();

    final maxCount = dayData
        .map((d) => d.count)
        .fold(0, (a, b) => a > b ? a : b);
    final effectiveMax = maxCount < 1 ? 1 : maxCount;
    final totalCompletions = dayData.fold(0, (sum, d) => sum + d.count);

    return StatCard(
      title: 'Last 7 Days',
      icon: Icons.calendar_view_week_rounded,
      iconColor: habit.color,
      isDark: isDark,
      child: Column(
        children: [
          // Summary row
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSummaryChip(
                  icon: Icons.check_circle_rounded,
                  value: '$totalCompletions',
                  label: 'completions',
                  color: const Color(0xFF4CAF50),
                ),
                const SizedBox(width: 16),
                _buildSummaryChip(
                  icon: Icons.local_fire_department_rounded,
                  value: '${statistics.currentStreak}',
                  label: 'streak',
                  color: const Color(0xFFFF6B6B),
                ),
              ],
            ),
          ),

          // Bar chart - Fixed height to prevent overflow
          SizedBox(
            height: 160,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: dayData.map((data) {
                    final isToday =
                        data.date.day == now.day &&
                        data.date.month == now.month &&
                        data.date.year == now.year;
                    final hasCompletion = data.count > 0;
                    // Calculate bar height with proper constraints
                    final maxBarHeight =
                        constraints.maxHeight -
                        50; // Reserve space for label + day
                    final barHeight = hasCompletion
                        ? ((data.count / effectiveMax) * (maxBarHeight - 20))
                              .clamp(15.0, maxBarHeight - 20)
                        : 8.0;

                    return SizedBox(
                      width: 38,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Count label
                          if (hasCompletion)
                            Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '${data.count}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: habit.color,
                                ),
                              ),
                            ),

                          // Bar
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOutCubic,
                            width: 28,
                            height: barHeight,
                            decoration: BoxDecoration(
                              gradient: hasCompletion
                                  ? LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        habit.color.withOpacity(0.7),
                                        habit.color,
                                      ],
                                    )
                                  : null,
                              color: hasCompletion
                                  ? null
                                  : (isDark
                                        ? Colors.white.withOpacity(0.08)
                                        : Colors.black.withOpacity(0.06)),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: hasCompletion
                                  ? [
                                      BoxShadow(
                                        color: habit.color.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                          ),

                          const SizedBox(height: 6),

                          // Day label
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: isToday
                                ? BoxDecoration(
                                    color: habit.color.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(
                                      color: habit.color,
                                      width: 1.5,
                                    ),
                                  )
                                : null,
                            child: Text(
                              DateFormat('E').format(data.date).substring(0, 2),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: isToday
                                    ? FontWeight.w900
                                    : FontWeight.w700,
                                color: isToday
                                    ? habit.color
                                    : (isDark
                                          ? Colors.white54
                                          : Colors.black54),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryChip({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple 30-Day Trend Line Chart
/// Clean, minimal line chart with gradient fill
class SimpleMonthlyTrendChart extends StatelessWidget {
  final HabitStatistics statistics;
  final Habit habit;
  final bool isDark;

  const SimpleMonthlyTrendChart({
    super.key,
    required this.statistics,
    required this.habit,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final last30Days = <DateTime>[];
    for (int i = 29; i >= 0; i--) {
      last30Days.add(
        DateTime(now.year, now.month, now.day).subtract(Duration(days: i)),
      );
    }

    final spots = last30Days.asMap().entries.map((entry) {
      final key = DateFormat('yyyy-MM-dd').format(entry.value);
      final count = statistics.dailyCompletions[key] ?? 0;
      return FlSpot(entry.key.toDouble(), count.toDouble());
    }).toList();

    final maxY = spots.map((s) => s.y).fold(0.0, (a, b) => a > b ? a : b);
    final effectiveMaxY = maxY < 1 ? 1.0 : maxY + 1;

    // Calculate totals for summary
    final totalCompletions = spots.fold(0.0, (sum, s) => sum + s.y).toInt();
    final daysWithActivity = spots.where((s) => s.y > 0).length;

    return StatCard(
      title: 'Monthly Progress',
      icon: Icons.trending_up_rounded,
      iconColor: habit.color,
      isDark: isDark,
      child: Column(
        children: [
          // Summary stats
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatBadge('$totalCompletions', 'total', habit.color),
                _buildStatBadge(
                  '$daysWithActivity',
                  'active days',
                  const Color(0xFF4CAF50),
                ),
                _buildStatBadge(
                  daysWithActivity > 0
                      ? '${(daysWithActivity / 30 * 100).toStringAsFixed(0)}%'
                      : '0%',
                  'consistency',
                  const Color(0xFFFFB347),
                ),
              ],
            ),
          ),

          // Chart
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                maxY: effectiveMaxY,
                minY: 0,
                clipData: const FlClipData.all(),
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: isDark
                        ? const Color(0xFF2C3138)
                        : Colors.white,
                    tooltipRoundedRadius: 10,
                    tooltipPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final date = last30Days[spot.x.toInt()];
                        return LineTooltipItem(
                          '${DateFormat('MMM d').format(date)}\n',
                          TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                          children: [
                            TextSpan(
                              text: '${spot.y.toInt()}',
                              style: TextStyle(
                                color: habit.color,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        );
                      }).toList();
                    },
                  ),
                  handleBuiltInTouches: true,
                  getTouchedSpotIndicator: (barData, spotIndexes) {
                    return spotIndexes.map((index) {
                      return TouchedSpotIndicatorData(
                        FlLine(
                          color: habit.color.withOpacity(0.4),
                          strokeWidth: 1,
                        ),
                        FlDotData(
                          getDotPainter: (spot, _, __, ___) =>
                              FlDotCirclePainter(
                                radius: 5,
                                color: habit.color,
                                strokeWidth: 2,
                                strokeColor: Colors.white,
                              ),
                        ),
                      );
                    }).toList();
                  },
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.25,
                    preventCurveOverShooting: true,
                    color: habit.color,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, _, __, ___) {
                        if (spot.y == 0) {
                          return FlDotCirclePainter(
                            radius: 0,
                            color: Colors.transparent,
                          );
                        }
                        // Highlight today
                        final isToday = spot.x.toInt() == 29;
                        return FlDotCirclePainter(
                          radius: isToday ? 4 : 2.5,
                          color: isToday ? habit.color : Colors.white,
                          strokeWidth: isToday ? 2 : 1.5,
                          strokeColor: habit.color,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          habit.color.withOpacity(0.3),
                          habit.color.withOpacity(0.05),
                          habit.color.withOpacity(0.0),
                        ],
                        stops: const [0.0, 0.6, 1.0],
                      ),
                    ),
                  ),
                ],
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: effectiveMaxY > 4
                          ? (effectiveMaxY / 4).ceilToDouble()
                          : 1,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(
                            value.toInt().toString(),
                            style: TextStyle(
                              color: isDark ? Colors.white38 : Colors.black38,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: 7,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= last30Days.length)
                          return const SizedBox.shrink();
                        // Show every week (7 days)
                        if (index != 0 &&
                            index != 7 &&
                            index != 14 &&
                            index != 21 &&
                            index != 29) {
                          return const SizedBox.shrink();
                        }
                        final date = last30Days[index];
                        return Text(
                          DateFormat('d/M').format(date),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white38 : Colors.black45,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: effectiveMaxY > 4
                      ? (effectiveMaxY / 4).ceilToDouble()
                      : 1,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.05),
                      strokeWidth: 1,
                      dashArray: [5, 5],
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white38 : Colors.black45,
          ),
        ),
      ],
    );
  }
}

class _TrendSectionState extends State<TrendSection> {
  @override
  Widget build(BuildContext context) {
    return ModernTrendSection(
      statistics: widget.statistics,
      habit: widget.habit,
      isDark: widget.isDark,
    );
  }
}

/// Full Screen Trend Modal
class FullScreenTrendModal extends StatefulWidget {
  final HabitStatistics statistics;
  final Habit habit;
  final bool isDark;
  final int initialPage;

  const FullScreenTrendModal({
    super.key,
    required this.statistics,
    required this.habit,
    required this.isDark,
    required this.initialPage,
  });

  @override
  State<FullScreenTrendModal> createState() => _FullScreenTrendModalState();
}

class _FullScreenTrendModalState extends State<FullScreenTrendModal> {
  @override
  void initState() {
    super.initState();
    // Allow landscape orientation for deep analysis
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    // Reset to portrait only when closing
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDark ? const Color(0xFF0D0F12) : Colors.white;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      height: screenHeight,
      width: screenWidth,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: isLandscape
            ? null
            : const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            if (!isLandscape) ...[
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: widget.isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
            _buildHeader(isLandscape),
            Expanded(
              child: DefaultTabController(
                initialIndex: widget.initialPage,
                length: 3,
                child: Column(
                  children: [
                    // Compact tab bar
                    Container(
                      margin: EdgeInsets.symmetric(
                        horizontal: isLandscape ? 40 : 20,
                        vertical: isLandscape ? 8 : 12,
                      ),
                      decoration: BoxDecoration(
                        color: widget.isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.black.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TabBar(
                        indicator: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: LinearGradient(
                            colors: [
                              widget.habit.color.withOpacity(0.3),
                              widget.habit.color.withOpacity(0.15),
                            ],
                          ),
                        ),
                        dividerColor: Colors.transparent,
                        indicatorColor: Colors.transparent,
                        labelColor: widget.habit.color,
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        unselectedLabelColor: widget.isDark
                            ? Colors.white38
                            : Colors.black38,
                        tabs: const [
                          Tab(text: 'DAILY'),
                          Tab(text: 'WEEKLY'),
                          Tab(text: 'MONTHLY'),
                        ],
                      ),
                    ),
                    // Maximized chart area
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isLandscape ? 24 : 12,
                          vertical: isLandscape ? 8 : 12,
                        ),
                        child: TabBarView(
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _buildInteractiveChart(
                              DailyTrendChart(
                                statistics: widget.statistics,
                                habit: widget.habit,
                                isDark: widget.isDark,
                                isLarge: true,
                              ),
                              isLandscape,
                            ),
                            _buildInteractiveChart(
                              WeeklyTrendChart(
                                statistics: widget.statistics,
                                habit: widget.habit,
                                isDark: widget.isDark,
                                isLarge: true,
                              ),
                              isLandscape,
                            ),
                            _buildInteractiveChart(
                              MonthlyTrendChart(
                                statistics: widget.statistics,
                                habit: widget.habit,
                                isDark: widget.isDark,
                                isLarge: true,
                              ),
                              isLandscape,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Compact hint
                    if (!isLandscape)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16, top: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.zoom_in_rounded,
                              size: 14,
                              color: widget.habit.color.withOpacity(0.5),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Pinch to zoom â€¢ Rotate for landscape',
                              style: TextStyle(
                                fontSize: 10,
                                color: widget.isDark
                                    ? Colors.white38
                                    : Colors.black38,
                                fontWeight: FontWeight.w600,
                              ),
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

  Widget _buildHeader(bool isLandscape) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isLandscape ? 24 : 20,
        vertical: isLandscape ? 8 : 16,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: widget.habit.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.insights_rounded,
              size: isLandscape ? 20 : 24,
              color: widget.habit.color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'DEEP ANALYSIS',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: widget.habit.color.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.habit.title,
                  style: TextStyle(
                    fontSize: isLandscape ? 16 : 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, size: 24),
            style: IconButton.styleFrom(
              backgroundColor: widget.isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.05),
              padding: const EdgeInsets.all(8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveChart(Widget chart, bool isLandscape) {
    final availableHeight =
        MediaQuery.of(context).size.height * (isLandscape ? 0.6 : 0.5);

    return InteractiveViewer(
      boundaryMargin: const EdgeInsets.all(40),
      minScale: 1.0,
      maxScale: 4.0,
      constrained: true, // Let it fit the parent Expanded, then zoom
      child: Container(
        height: double.infinity,
        width: double.infinity,
        padding: EdgeInsets.all(isLandscape ? 24 : 16),
        child: ExcludeSemantics(child: chart),
      ),
    );
  }
}

/// Daily Trend Line Chart (Last 30 days)
class DailyTrendChart extends StatelessWidget {
  final HabitStatistics statistics;
  final Habit habit;
  final bool isDark;
  final bool isLarge;

  const DailyTrendChart({
    super.key,
    required this.statistics,
    required this.habit,
    required this.isDark,
    this.isLarge = false,
  });

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final last30Days = <DateTime>[];
    for (int i = 29; i >= 0; i--) {
      last30Days.add(
        DateTime(now.year, now.month, now.day).subtract(Duration(days: i)),
      );
    }

    final spots = last30Days.asMap().entries.map((entry) {
      final key = DateFormat('yyyy-MM-dd').format(entry.value);
      final count = statistics.dailyCompletions[key] ?? 0;
      return FlSpot(entry.key.toDouble(), count.toDouble());
    }).toList();

    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) + 1;

    return LineChart(
      LineChartData(
        maxY: maxY < 2 ? 2 : maxY,
        minY: 0,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: isDark ? const Color(0xFF2C3138) : Colors.white,
            tooltipRoundedRadius: 12,
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final date = last30Days[spot.x.toInt()];
                return LineTooltipItem(
                  '${DateFormat('MMM d').format(date)}\n',
                  TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  children: [
                    TextSpan(
                      text: '${spot.y.toInt()}',
                      style: TextStyle(
                        color: habit.color,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                    TextSpan(
                      text: ' times',
                      style: TextStyle(
                        color: habit.color.withOpacity(0.7),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                );
              }).toList();
            },
          ),
          handleBuiltInTouches: true,
          getTouchedSpotIndicator:
              (LineChartBarData barData, List<int> spotIndexes) {
                return spotIndexes.map((spotIndex) {
                  return TouchedSpotIndicatorData(
                    FlLine(
                      color: habit.color.withOpacity(0.3),
                      strokeWidth: 2,
                      dashArray: [5, 5],
                    ),
                    FlDotData(
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                            radius: 6,
                            color: habit.color,
                            strokeWidth: 3,
                            strokeColor: Colors.white,
                          ),
                    ),
                  );
                }).toList();
              },
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            preventCurveOverShooting: true,
            color: habit.color,
            barWidth: isLarge ? 4 : 3.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                // Only show dots for non-zero values
                if (spot.y == 0)
                  return FlDotCirclePainter(
                    radius: 0,
                    color: Colors.transparent,
                  );
                return FlDotCirclePainter(
                  radius: isLarge ? 4 : 3,
                  color: isDark ? const Color(0xFF16181D) : Colors.white,
                  strokeWidth: 2,
                  strokeColor: habit.color,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  habit.color.withOpacity(0.35),
                  habit.color.withOpacity(0.05),
                  habit.color.withOpacity(0.0),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ],
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: isLarge ? 40 : 32,
              interval: 1,
              getTitlesWidget: (value, meta) {
                if (value == 0 && !isLarge) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      color: isDark ? Colors.white30 : Colors.black38,
                      fontSize: isLarge ? 12 : 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: isLarge ? 36 : 28,
              interval: isLarge ? 2 : 5,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= last30Days.length)
                  return const Text('');
                if (!isLarge && index % 5 != 0) return const SizedBox.shrink();
                if (isLarge && index % 2 != 0) return const SizedBox.shrink();

                final date = last30Days[index];
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    DateFormat(isLarge ? 'd\nMMM' : 'd\nMMM').format(date),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isLarge ? 11 : 10,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? (_isToday(date) ? habit.color : Colors.white38)
                          : (_isToday(date) ? habit.color : Colors.black45),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: isLarge,
          horizontalInterval: 1,
          verticalInterval: isLarge ? 2 : 5,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.05),
              strokeWidth: 1,
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: isDark
                  ? Colors.white.withOpacity(0.03)
                  : Colors.black.withOpacity(0.03),
              strokeWidth: 1,
            );
          },
        ),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}

/// Weekly Trend Line Chart
class WeeklyTrendChart extends StatelessWidget {
  final HabitStatistics statistics;
  final Habit habit;
  final bool isDark;
  final bool isLarge;

  const WeeklyTrendChart({
    super.key,
    required this.statistics,
    required this.habit,
    required this.isDark,
    this.isLarge = false,
  });

  bool _isCurrentWeek(DateTime weekStart) {
    final now = DateTime.now();
    final daysSinceSunday = now.weekday % 7;
    final currentWeekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: daysSinceSunday));
    return weekStart.year == currentWeekStart.year &&
        weekStart.month == currentWeekStart.month &&
        weekStart.day == currentWeekStart.day;
  }

  @override
  Widget build(BuildContext context) {
    // Get last 12 weeks
    final now = DateTime.now();
    final last12Weeks = <String>[];
    final last12WeekDates = <DateTime>[];
    for (int i = 11; i >= 0; i--) {
      final date = now.subtract(Duration(days: i * 7));
      final daysSinceSunday = date.weekday % 7;
      final weekStart = DateTime(
        date.year,
        date.month,
        date.day,
      ).subtract(Duration(days: daysSinceSunday));

      final firstDayOfYear = DateTime(weekStart.year, 1, 1);
      final daysSinceFirstDay = weekStart.difference(firstDayOfYear).inDays;
      final weekNum = (daysSinceFirstDay / 7).floor() + 1;

      final key = '${weekStart.year}-W${weekNum.toString().padLeft(2, '0')}';
      last12Weeks.add(key);
      last12WeekDates.add(weekStart);
    }

    final spots = last12Weeks.asMap().entries.map((entry) {
      final count = statistics.weeklyCompletions[entry.value] ?? 0;
      return FlSpot(entry.key.toDouble(), count.toDouble());
    }).toList();

    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) + 1;

    return LineChart(
      LineChartData(
        maxY: maxY < 2 ? 2 : maxY,
        minY: 0,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: isDark ? const Color(0xFF2C3138) : Colors.white,
            tooltipRoundedRadius: 12,
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final date = last12WeekDates[spot.x.toInt()];
                return LineTooltipItem(
                  'Week of ${DateFormat('MMM d').format(date)}\n',
                  TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  children: [
                    TextSpan(
                      text: '${spot.y.toInt()}',
                      style: TextStyle(
                        color: habit.color,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                    TextSpan(
                      text: ' times',
                      style: TextStyle(
                        color: habit.color.withOpacity(0.7),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                );
              }).toList();
            },
          ),
          handleBuiltInTouches: true,
          getTouchedSpotIndicator:
              (LineChartBarData barData, List<int> spotIndexes) {
                return spotIndexes.map((spotIndex) {
                  return TouchedSpotIndicatorData(
                    FlLine(
                      color: habit.color.withOpacity(0.3),
                      strokeWidth: 2,
                      dashArray: [5, 5],
                    ),
                    FlDotData(
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                            radius: 6,
                            color: habit.color,
                            strokeWidth: 3,
                            strokeColor: Colors.white,
                          ),
                    ),
                  );
                }).toList();
              },
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.35,
            preventCurveOverShooting: true,
            color: habit.color,
            barWidth: isLarge ? 4.5 : 4,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                if (spot.y == 0)
                  return FlDotCirclePainter(
                    radius: 0,
                    color: Colors.transparent,
                  );
                return FlDotCirclePainter(
                  radius: isLarge ? 5 : 4,
                  color: isDark ? const Color(0xFF16181D) : Colors.white,
                  strokeWidth: 2.5,
                  strokeColor: habit.color,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  habit.color.withOpacity(0.35),
                  habit.color.withOpacity(0.05),
                  habit.color.withOpacity(0.0),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ],
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: isLarge ? 40 : 32,
              interval: 1,
              getTitlesWidget: (value, meta) {
                if (value == 0 && !isLarge) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      color: isDark ? Colors.white30 : Colors.black38,
                      fontSize: isLarge ? 12 : 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: isLarge ? 36 : 28,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= last12Weeks.length)
                  return const Text('');

                final date = last12WeekDates[index];
                final isCurrentWeek = _isCurrentWeek(date);

                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    isLarge
                        ? '${DateFormat('MMM d').format(date)}'
                        : 'W${index + 1}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isLarge ? 10 : 11,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? (isCurrentWeek ? habit.color : Colors.white38)
                          : (isCurrentWeek ? habit.color : Colors.black45),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: isLarge,
          horizontalInterval: 1,
          verticalInterval: 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.05),
              strokeWidth: 1,
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: isDark
                  ? Colors.white.withOpacity(0.03)
                  : Colors.black.withOpacity(0.03),
              strokeWidth: 1,
            );
          },
        ),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}

/// Monthly Trend Line Chart
class MonthlyTrendChart extends StatelessWidget {
  final HabitStatistics statistics;
  final Habit habit;
  final bool isDark;
  final bool isLarge;

  const MonthlyTrendChart({
    super.key,
    required this.statistics,
    required this.habit,
    required this.isDark,
    this.isLarge = false,
  });

  bool _isCurrentMonth(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month;
  }

  @override
  Widget build(BuildContext context) {
    final sortedEntries = statistics.monthlyCompletions.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    if (sortedEntries.length < 2) {
      return Center(
        child: Text(
          'Need at least 2 months of data',
          style: TextStyle(
            color: isDark ? Colors.white38 : Colors.black38,
            fontSize: 12,
          ),
        ),
      );
    }

    final maxY =
        sortedEntries
            .map((e) => e.value)
            .reduce((a, b) => a > b ? a : b)
            .toDouble() +
        1;

    return LineChart(
      LineChartData(
        maxY: maxY,
        minY: 0,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: isDark ? const Color(0xFF2C3138) : Colors.white,
            tooltipRoundedRadius: 12,
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final monthKey = sortedEntries[spot.x.toInt()].key;
                final parts = monthKey.split('-');
                final date = DateTime(int.parse(parts[0]), int.parse(parts[1]));
                return LineTooltipItem(
                  '${DateFormat('MMMM yyyy').format(date)}\n',
                  TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  children: [
                    TextSpan(
                      text: '${spot.y.toInt()}',
                      style: TextStyle(
                        color: habit.color,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                    TextSpan(
                      text: ' times',
                      style: TextStyle(
                        color: habit.color.withOpacity(0.7),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                );
              }).toList();
            },
          ),
          handleBuiltInTouches: true,
          getTouchedSpotIndicator:
              (LineChartBarData barData, List<int> spotIndexes) {
                return spotIndexes.map((spotIndex) {
                  return TouchedSpotIndicatorData(
                    FlLine(
                      color: habit.color.withOpacity(0.3),
                      strokeWidth: 2,
                      dashArray: [5, 5],
                    ),
                    FlDotData(
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                            radius: 6,
                            color: habit.color,
                            strokeWidth: 3,
                            strokeColor: Colors.white,
                          ),
                    ),
                  );
                }).toList();
              },
        ),
        lineBarsData: [
          LineChartBarData(
            spots: sortedEntries.asMap().entries.map((entry) {
              return FlSpot(entry.key.toDouble(), entry.value.value.toDouble());
            }).toList(),
            isCurved: true,
            curveSmoothness: 0.35,
            preventCurveOverShooting: true,
            color: habit.color,
            barWidth: isLarge ? 4.5 : 4,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                if (spot.y == 0)
                  return FlDotCirclePainter(
                    radius: 0,
                    color: Colors.transparent,
                  );
                return FlDotCirclePainter(
                  radius: isLarge ? 5 : 4.5,
                  color: isDark ? const Color(0xFF16181D) : Colors.white,
                  strokeWidth: 2.5,
                  strokeColor: habit.color,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  habit.color.withOpacity(0.35),
                  habit.color.withOpacity(0.05),
                  habit.color.withOpacity(0.0),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ],
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: isLarge ? 40 : 32,
              interval: 1,
              getTitlesWidget: (value, meta) {
                if (value == 0 && !isLarge) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      color: isDark ? Colors.white30 : Colors.black38,
                      fontSize: isLarge ? 12 : 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: isLarge ? 36 : 28,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= sortedEntries.length)
                  return const Text('');

                final monthKey = sortedEntries[index].key;
                final parts = monthKey.split('-');
                final date = DateTime(int.parse(parts[0]), int.parse(parts[1]));
                final isCurrent = _isCurrentMonth(date);
                final label = isLarge
                    ? DateFormat('MMM\nyy').format(date).toUpperCase()
                    : DateFormat('MMM').format(date).toUpperCase();

                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
                      color: isDark
                          ? (isCurrent ? habit.color : Colors.white38)
                          : (isCurrent ? habit.color : Colors.black45),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: isLarge,
          horizontalInterval: 1,
          verticalInterval: 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.05),
              strokeWidth: 1,
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: isDark
                  ? Colors.white.withOpacity(0.03)
                  : Colors.black.withOpacity(0.03),
              strokeWidth: 1,
            );
          },
        ),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}

/// Stat Card Container
class StatCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final bool isDark;
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onExpand;
  final bool expand;

  const StatCard({
    super.key,
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.isDark,
    required this.child,
    this.padding,
    this.onExpand,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = child;
    if (expand) {
      content = Expanded(child: content);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF24282F) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.05),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            iconColor.withOpacity(0.25),
                            iconColor.withOpacity(0.1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: iconColor.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Icon(icon, color: iconColor, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                          color: isDark
                              ? Colors.white.withOpacity(0.95)
                              : Colors.black.withOpacity(0.85),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (onExpand != null)
                IconButton(
                  onPressed: onExpand,
                  icon: const Icon(Icons.open_in_full_rounded, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
            ],
          ),
          const SizedBox(height: 24),
          content,
        ],
      ),
    );
  }
}

/// Score Overview Card
class ScoreOverviewCard extends StatelessWidget {
  final dynamic
  score; // Using dynamic to avoid strict typing issues during refactor
  final Color habitColor;
  final bool isDark;

  const ScoreOverviewCard({
    super.key,
    required this.score,
    required this.habitColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final scoreColor = Color(score.scoreColorValue);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [scoreColor.withOpacity(0.18), scoreColor.withOpacity(0.05)]
              : [scoreColor.withOpacity(0.12), scoreColor.withOpacity(0.03)],
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: scoreColor.withOpacity(0.35), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Score Circle
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 85,
                height: 85,
                child: CircularProgressIndicator(
                  value: score.overallScore / 100,
                  strokeWidth: 10,
                  strokeCap: StrokeCap.round,
                  backgroundColor: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.05),
                  valueColor: AlwaysStoppedAnimation(scoreColor),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${score.overallScore.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    score.grade,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: scoreColor,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STRENGTH SCORE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: scoreColor.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  score.scoreLabel,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 14),
                _TrendIndicator(
                  direction: score.trendDirection,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendIndicator extends StatelessWidget {
  final String direction;
  final bool isDark;

  const _TrendIndicator({required this.direction, required this.isDark});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    String label;

    if (direction == 'improving') {
      color = Colors.green;
      icon = Icons.trending_up_rounded;
      label = 'IMPROVING';
    } else if (direction == 'declining') {
      color = const Color(0xFFFF6B6B);
      icon = Icons.trending_down_rounded;
      label = 'DECLINING';
    } else {
      color = const Color(0xFF4DB6AC);
      icon = Icons.trending_flat_rounded;
      label = 'STABLE';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 10,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Stat Item
class StatItem extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final Color color;

  const StatItem({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black,
                letterSpacing: -0.5,
              ),
            ),
            if (unit != null) ...[
              const SizedBox(width: 4),
              Text(
                unit!,
                style: TextStyle(
                  fontSize: 12,
                  color: color.withOpacity(0.8),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Stat Item with Rate
class StatItemWithRate extends StatelessWidget {
  final String label;
  final String value;
  final double rate;
  final Color color;

  const StatItemWithRate({
    super.key,
    required this.label,
    required this.value,
    required this.rate,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : Colors.black,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getRateColor(rate).withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${rate.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: _getRateColor(rate),
            ),
          ),
        ),
      ],
    );
  }

  Color _getRateColor(double rate) {
    if (rate >= 80) return const Color(0xFF4CAF50);
    if (rate >= 60) return const Color(0xFFCDAF56);
    if (rate >= 40) return const Color(0xFFFFB347);
    return const Color(0xFFFF6B6B);
  }
}

/// Best Periods Section
class BestPeriodsSection extends StatelessWidget {
  final HabitStatistics statistics;
  final bool isDark;

  const BestPeriodsSection({
    super.key,
    required this.statistics,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return StatCard(
      title: 'Best Periods',
      icon: Icons.emoji_events_rounded,
      iconColor: const Color(0xFFCDAF56),
      isDark: isDark,
      child: Column(
        children: [
          if (statistics.bestWeekStart != null)
            _BestPeriodItem(
              label: 'Best Week',
              date: DateFormat('MMM d, yyyy').format(statistics.bestWeekStart!),
              count: statistics.bestWeekCompletions!,
              icon: Icons.calendar_view_week_rounded,
            ),
          if (statistics.bestWeekStart != null &&
              statistics.bestMonthStart != null)
            const SizedBox(height: 12),
          if (statistics.bestMonthStart != null)
            _BestPeriodItem(
              label: 'Best Month',
              date: DateFormat('MMMM yyyy').format(statistics.bestMonthStart!),
              count: statistics.bestMonthCompletions!,
              icon: Icons.calendar_month_rounded,
            ),
        ],
      ),
    );
  }
}

class _BestPeriodItem extends StatelessWidget {
  final String label;
  final String date;
  final int count;
  final IconData icon;

  const _BestPeriodItem({
    required this.label,
    required this.date,
    required this.count,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFCDAF56).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCDAF56).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFCDAF56)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFCDAF56),
                  ),
                ),
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFCDAF56),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count times',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Quit Habit Section
class QuitHabitSection extends StatelessWidget {
  final HabitStatistics statistics;
  final Habit habit;
  final bool isDark;

  const QuitHabitSection({
    super.key,
    required this.statistics,
    required this.habit,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return StatCard(
      title: 'Quit Progress',
      icon: Icons.block_rounded,
      iconColor: const Color(0xFFEF5350),
      isDark: isDark,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: StatItem(
                  label: 'Days Resisted',
                  value: '${statistics.resistanceCount}',
                  color: const Color(0xFF4CAF50),
                ),
              ),
              Expanded(
                child: StatItem(
                  label: 'Slips',
                  value: '${statistics.slipsCount ?? 0}',
                  color: const Color(0xFFEF5350),
                ),
              ),
            ],
          ),
          if (habit.costTrackingEnabled == true &&
              statistics.moneySaved != null &&
              statistics.moneySaved! > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF4CAF50).withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.savings_rounded,
                    color: Color(0xFF4CAF50),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Money Saved',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        habit.formatCurrency(statistics.moneySaved!),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4CAF50),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          if (statistics.unitsAvoided != null &&
              statistics.unitsAvoided! > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFCDAF56).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFCDAF56).withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.block_rounded,
                    color: Color(0xFFCDAF56),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${statistics.unitsAvoided} ${habit.unit ?? 'units'} avoided',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFCDAF56),
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

/// Calendar View
class CalendarView extends StatefulWidget {
  final Habit habit;
  final HabitStatistics statistics;
  final bool isDark;

  const CalendarView({
    super.key,
    required this.habit,
    required this.statistics,
    required this.isDark,
  });

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  late DateTime _focusedMonth;
  late DateTime _focusedWeekStart;
  late Map<int, HabitCompletion> _completionByDateKey;
  bool _isWeeklyView = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = now;
    _focusedWeekStart = _getWeekStart(now);
    _rebuildCompletionIndex();
  }

  @override
  void didUpdateWidget(covariant CalendarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.statistics, widget.statistics)) {
      _rebuildCompletionIndex();
    }
  }

  DateTime _getWeekStart(DateTime date) {
    final weekday = date.weekday % 7;
    return DateTime(date.year, date.month, date.day - weekday);
  }

  List<DateTime> _getWeekDays(DateTime weekStart) {
    return List.generate(7, (i) => weekStart.add(Duration(days: i)));
  }

  int _dateKey(DateTime date) =>
      DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;

  HabitCompletion? _completionForDate(DateTime date) {
    return _completionByDateKey[_dateKey(date)];
  }

  void _rebuildCompletionIndex() {
    final indexed = <int, HabitCompletion>{};
    for (final completion in widget.statistics.recentCompletions) {
      final key = _dateKey(completion.completedDate);
      final existing = indexed[key];
      if (existing == null ||
          completion.completedAt.isAfter(existing.completedAt)) {
        indexed[key] = completion;
      }
    }
    _completionByDateKey = indexed;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // View mode toggle
        _buildViewModeToggle(),
        const SizedBox(height: 8),
        // Header
        _isWeeklyView ? _buildWeeklyHeader() : _buildMonthlyHeader(),
        // Legend for colors
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _CalendarLegendItem(
                color: const Color(0xFF4CAF50),
                label: 'Done',
                isDark: widget.isDark,
              ),
              const SizedBox(width: 16),
              _CalendarLegendItem(
                color: const Color(0xFFFFB347),
                label: 'Missed',
                isDark: widget.isDark,
              ),
              const SizedBox(width: 16),
              _CalendarLegendItem(
                color: const Color(0xFFFF5252),
                label: 'Skipped',
                isDark: widget.isDark,
              ),
            ],
          ),
        ),
        // Calendar content
        Expanded(
          child: _isWeeklyView
              ? _buildWeeklyCalendar()
              : _buildMonthlyCalendar(),
        ),
        // Weekly stats summary (monthly stats are inside the scrollable calendar)
        if (_isWeeklyView) _buildWeeklyStats(),
      ],
    );
  }

  Widget _buildViewModeToggle() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isWeeklyView = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !_isWeeklyView
                      ? widget.habit.color.withOpacity(0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: !_isWeeklyView
                      ? Border.all(color: widget.habit.color, width: 1.5)
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_month_rounded,
                      size: 16,
                      color: !_isWeeklyView
                          ? widget.habit.color
                          : (widget.isDark ? Colors.white54 : Colors.black45),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Monthly',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: !_isWeeklyView
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: !_isWeeklyView
                            ? widget.habit.color
                            : (widget.isDark ? Colors.white54 : Colors.black45),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isWeeklyView = true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _isWeeklyView
                      ? widget.habit.color.withOpacity(0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: _isWeeklyView
                      ? Border.all(color: widget.habit.color, width: 1.5)
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.view_week_rounded,
                      size: 16,
                      color: _isWeeklyView
                          ? widget.habit.color
                          : (widget.isDark ? Colors.white54 : Colors.black45),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Weekly',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _isWeeklyView
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: _isWeeklyView
                            ? widget.habit.color
                            : (widget.isDark ? Colors.white54 : Colors.black45),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _CalendarNavButton(
            icon: Icons.chevron_left_rounded,
            onPressed: () => setState(() {
              _focusedMonth = DateTime(
                _focusedMonth.year,
                _focusedMonth.month - 1,
              );
            }),
            isDark: widget.isDark,
          ),
          Text(
            DateFormat('MMMM yyyy').format(_focusedMonth).toUpperCase(),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          _CalendarNavButton(
            icon: Icons.chevron_right_rounded,
            onPressed: () => setState(() {
              _focusedMonth = DateTime(
                _focusedMonth.year,
                _focusedMonth.month + 1,
              );
            }),
            isDark: widget.isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyHeader() {
    final weekDays = _getWeekDays(_focusedWeekStart);
    final weekEnd = weekDays.last;
    final isSameMonth = _focusedWeekStart.month == weekEnd.month;

    String dateRangeText;
    if (isSameMonth) {
      dateRangeText =
          '${DateFormat('MMM d').format(_focusedWeekStart)} - ${weekEnd.day}';
    } else {
      dateRangeText =
          '${DateFormat('MMM d').format(_focusedWeekStart)} - ${DateFormat('MMM d').format(weekEnd)}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _CalendarNavButton(
            icon: Icons.chevron_left_rounded,
            onPressed: () => setState(() {
              _focusedWeekStart = _focusedWeekStart.subtract(
                const Duration(days: 7),
              );
            }),
            isDark: widget.isDark,
          ),
          Column(
            children: [
              Text(
                dateRangeText.toUpperCase(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _focusedWeekStart.year.toString(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: widget.isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
          _CalendarNavButton(
            icon: Icons.chevron_right_rounded,
            onPressed: () => setState(() {
              _focusedWeekStart = _focusedWeekStart.add(
                const Duration(days: 7),
              );
            }),
            isDark: widget.isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyCalendar() {
    final firstDayOfMonth = DateTime(
      _focusedMonth.year,
      _focusedMonth.month,
      1,
    );
    final lastDayOfMonth = DateTime(
      _focusedMonth.year,
      _focusedMonth.month + 1,
      0,
    );
    final daysInMonth = lastDayOfMonth.day;
    final startWeekday = firstDayOfMonth.weekday % 7;

    // Calculate rows needed for the calendar grid
    final totalCells = startWeekday + daysInMonth;
    final rowsNeeded = (totalCells / 7).ceil();

    return SingleChildScrollView(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _WeekdayHeader(label: 'S'),
                _WeekdayHeader(label: 'M'),
                _WeekdayHeader(label: 'T'),
                _WeekdayHeader(label: 'W'),
                _WeekdayHeader(label: 'T'),
                _WeekdayHeader(label: 'F'),
                _WeekdayHeader(label: 'S'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              itemCount: rowsNeeded * 7,
              itemBuilder: (context, index) {
                final dayOffset = index - startWeekday;
                if (dayOffset < 0 || dayOffset >= daysInMonth) {
                  return const SizedBox.shrink();
                }
                return _buildDayCell(
                  DateTime(
                    _focusedMonth.year,
                    _focusedMonth.month,
                    dayOffset + 1,
                  ),
                );
              },
            ),
          ),
          // Monthly stats summary - scrolls with calendar
          _buildMonthlyStats(),
        ],
      ),
    );
  }

  Widget _buildWeeklyCalendar() {
    final weekDays = _getWeekDays(_focusedWeekStart);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: weekDays.map((date) {
          return Expanded(child: _buildWeeklyDayCell(date));
        }).toList(),
      ),
    );
  }

  Widget _buildDayCell(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isToday =
        date.day == now.day && date.month == now.month && date.year == now.year;
    final isPastDay = date.isBefore(today);

    final habitStartDate = DateTime(
      widget.habit.startDate.year,
      widget.habit.startDate.month,
      widget.habit.startDate.day,
    );
    final isAfterStart = !date.isBefore(habitStartDate);
    final isFutureDay = date.isAfter(today);

    final completion = _completionForDate(date);
    final isLogged = completion != null;
    final isCompleted = completion != null && _isSuccessful(completion);
    final isMissedDay = isPastDay && isAfterStart && !isLogged;

    Color? borderColor;
    Color? bgColor;
    double borderWidth = 1.5;
    Color textColor = widget.isDark ? Colors.white70 : Colors.black87;

    if (!isAfterStart) {
      textColor = widget.isDark ? Colors.white12 : Colors.black12;
    } else if (isCompleted) {
      borderColor = const Color(0xFF4CAF50).withOpacity(0.8);
      bgColor = const Color(0xFF4CAF50).withOpacity(widget.isDark ? 0.15 : 0.1);
      borderWidth = 2.5;
      textColor = widget.isDark ? Colors.white : Colors.green[800]!;
    } else if (isLogged) {
      borderColor = const Color(0xFFFF5252).withOpacity(0.8);
      bgColor = const Color(0xFFFF5252).withOpacity(widget.isDark ? 0.15 : 0.1);
      borderWidth = 2.5;
      textColor = widget.isDark ? Colors.white : Colors.red[800]!;
    } else if (isMissedDay) {
      borderColor = const Color(0xFFFFB347).withOpacity(0.8);
      bgColor = const Color(
        0xFFFFB347,
      ).withOpacity(widget.isDark ? 0.12 : 0.08);
      borderWidth = 2.0;
      textColor = widget.isDark ? Colors.white70 : Colors.orange[800]!;
    } else if (isFutureDay) {
      textColor = widget.isDark ? Colors.white24 : Colors.black26;
    }

    return GestureDetector(
      onTap: completion != null
          ? () => _showDayDetails(context, completion)
          : null,
      child: Container(
        decoration: BoxDecoration(
          color:
              bgColor ??
              (widget.isDark
                  ? Colors.white.withOpacity(0.03)
                  : Colors.black.withOpacity(0.03)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isToday
                ? widget.habit.color
                : (borderColor ??
                      (widget.isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.05))),
            width: isToday ? 3.0 : borderWidth,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          '${date.day}',
          style: TextStyle(
            fontWeight: isToday || isLogged ? FontWeight.w900 : FontWeight.w700,
            fontSize: 13,
            color: isToday && !isLogged ? widget.habit.color : textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklyDayCell(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isToday =
        date.day == now.day && date.month == now.month && date.year == now.year;
    final isPastDay = date.isBefore(today);

    final habitStartDate = DateTime(
      widget.habit.startDate.year,
      widget.habit.startDate.month,
      widget.habit.startDate.day,
    );
    final isAfterStart = !date.isBefore(habitStartDate);
    final isFutureDay = date.isAfter(today);

    final completion = _completionForDate(date);
    final isLogged = completion != null;
    final isCompleted = completion != null && _isSuccessful(completion);
    final isMissedDay = isPastDay && isAfterStart && !isLogged;
    final isSkipped = completion?.isSkipped ?? false;

    Color bgColor;
    Color borderColor;
    Color accentColor;
    Color textColor;
    double borderWidth = 1.0;
    IconData? statusIcon;

    if (!isAfterStart) {
      accentColor = widget.isDark ? Colors.white24 : Colors.black26;
      bgColor = widget.isDark
          ? Colors.white.withOpacity(0.02)
          : Colors.black.withOpacity(0.02);
      borderColor = Colors.transparent;
      textColor = widget.isDark ? Colors.white12 : Colors.black12;
    } else if (isCompleted) {
      accentColor = const Color(0xFF4CAF50);
      bgColor = accentColor.withOpacity(widget.isDark ? 0.12 : 0.08);
      borderColor = accentColor.withOpacity(0.8);
      textColor = widget.isDark ? Colors.white : Colors.green[800]!;
      statusIcon = Icons.check_circle_rounded;
    } else if (isSkipped) {
      accentColor = const Color(0xFFFF5252);
      bgColor = accentColor.withOpacity(widget.isDark ? 0.12 : 0.08);
      borderColor = accentColor.withOpacity(0.8);
      textColor = widget.isDark ? Colors.white : Colors.red[800]!;
      statusIcon = Icons.cancel_rounded;
    } else if (isMissedDay) {
      accentColor = const Color(0xFFFFB347);
      bgColor = accentColor.withOpacity(widget.isDark ? 0.12 : 0.08);
      borderColor = accentColor.withOpacity(0.8);
      textColor = widget.isDark ? Colors.white : Colors.orange[800]!;
      statusIcon = Icons.remove_circle_outline_rounded;
    } else if (isFutureDay) {
      accentColor = widget.isDark ? Colors.white24 : Colors.black26;
      bgColor = widget.isDark
          ? Colors.white.withOpacity(0.03)
          : Colors.black.withOpacity(0.03);
      borderColor = widget.isDark
          ? Colors.white.withOpacity(0.1)
          : Colors.black.withOpacity(0.1);
      textColor = widget.isDark ? Colors.white24 : Colors.black26;
    } else {
      accentColor = widget.isDark ? Colors.white38 : Colors.black45;
      bgColor = widget.isDark
          ? Colors.white.withOpacity(0.03)
          : Colors.black.withOpacity(0.03);
      borderColor = widget.isDark
          ? Colors.white.withOpacity(0.15)
          : Colors.black.withOpacity(0.15);
      textColor = widget.isDark ? Colors.white70 : Colors.black87;
    }

    if (isToday) {
      borderWidth = 2.0;
      borderColor = widget.habit.color;
      if (!isCompleted && !isLogged && !isMissedDay) {
        textColor = widget.habit.color;
      }
    }

    return GestureDetector(
      onTap: completion != null
          ? () => _showDayDetails(context, completion)
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: isToday
              ? [
                  BoxShadow(
                    color: widget.habit.color.withOpacity(0.15),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              DateFormat('EEE').format(date).toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: textColor.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: isToday ? FontWeight.w900 : FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 10),
            if (statusIcon != null)
              Icon(statusIcon, size: 16, color: accentColor)
            else
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: textColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyStats() {
    final weekDays = _getWeekDays(_focusedWeekStart);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final habitStartDate = DateTime(
      widget.habit.startDate.year,
      widget.habit.startDate.month,
      widget.habit.startDate.day,
    );

    int completed = 0;
    int missed = 0;
    int skipped = 0;
    int total = 0;

    for (final date in weekDays) {
      final isPastDay = date.isBefore(today);
      final isToday =
          date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
      final isAfterStart = !date.isBefore(habitStartDate);

      if (!isAfterStart || date.isAfter(today)) continue;

      total++;

      final completion = _completionForDate(date);
      final isCompleted = completion != null && _isSuccessful(completion);
      final isLogged = completion != null;
      final isSkipped = completion?.isSkipped ?? false;

      if (isCompleted) {
        completed++;
      } else if (isSkipped) {
        skipped++;
      } else if (isPastDay && !isToday && !isLogged) {
        missed++;
      }
    }

    final successRate = total > 0
        ? (completed / total * 100).toStringAsFixed(0)
        : '0';

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            widget.isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.03),
            widget.isDark
                ? Colors.white.withOpacity(0.02)
                : Colors.black.withOpacity(0.01),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Column(
        children: [
          Text(
            'WEEK SUMMARY',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: widget.isDark ? Colors.white38 : Colors.black38,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('$completed', 'Done', const Color(0xFF4CAF50)),
              _buildStatDivider(),
              _buildStatItem('$missed', 'Missed', const Color(0xFFFFB347)),
              _buildStatDivider(),
              _buildStatItem('$skipped', 'Skipped', const Color(0xFFFF5252)),
              _buildStatDivider(),
              _buildStatItem(
                '$successRate%',
                'Success',
                int.parse(successRate) >= 80
                    ? const Color(0xFF4CAF50)
                    : int.parse(successRate) >= 50
                    ? const Color(0xFFFFB347)
                    : const Color(0xFFEF5350),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyStats() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final habitStartDate = DateTime(
      widget.habit.startDate.year,
      widget.habit.startDate.month,
      widget.habit.startDate.day,
    );

    // Get all days in the focused month
    final lastDayOfMonth = DateTime(
      _focusedMonth.year,
      _focusedMonth.month + 1,
      0,
    );
    final daysInMonth = lastDayOfMonth.day;

    int completed = 0;
    int missed = 0;
    int skipped = 0;
    int total = 0;

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_focusedMonth.year, _focusedMonth.month, day);
      final isPastDay = date.isBefore(today);
      final isToday =
          date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
      final isAfterStart = !date.isBefore(habitStartDate);

      // Skip days before habit start or future days
      if (!isAfterStart || date.isAfter(today)) continue;

      total++;

      final completion = _completionForDate(date);
      final isCompleted = completion != null && _isSuccessful(completion);
      final isLogged = completion != null;
      final isSkippedDay = completion?.isSkipped ?? false;

      if (isCompleted) {
        completed++;
      } else if (isSkippedDay) {
        skipped++;
      } else if (isPastDay && !isToday && !isLogged) {
        missed++;
      }
    }

    final successRate = total > 0
        ? (completed / total * 100).toStringAsFixed(0)
        : '0';

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            widget.isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.03),
            widget.isDark
                ? Colors.white.withOpacity(0.02)
                : Colors.black.withOpacity(0.01),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Column(
        children: [
          Text(
            'MONTH SUMMARY',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: widget.isDark ? Colors.white38 : Colors.black38,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('$completed', 'Done', const Color(0xFF4CAF50)),
              _buildStatDivider(),
              _buildStatItem('$missed', 'Missed', const Color(0xFFFFB347)),
              _buildStatDivider(),
              _buildStatItem('$skipped', 'Skipped', const Color(0xFFFF5252)),
              _buildStatDivider(),
              _buildStatItem(
                '$successRate%',
                'Success',
                int.parse(successRate) >= 80
                    ? const Color(0xFF4CAF50)
                    : int.parse(successRate) >= 50
                    ? const Color(0xFFFFB347)
                    : const Color(0xFFEF5350),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: widget.isDark ? Colors.white38 : Colors.black38,
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      height: 30,
      width: 1,
      color: widget.isDark ? Colors.white12 : Colors.black12,
    );
  }

  bool _isSuccessful(HabitCompletion completion) {
    if (completion.isSkipped || completion.isPostponed) return false;

    switch (widget.habit.completionType) {
      case 'yesNo': // NOTE: Must match Habit.completionType (camelCase)
      case 'yes_no': // Keep for backward compatibility
        // Success if answer is true OR count > 0
        return completion.answer == true || completion.count > 0;
      case 'numeric':
        if (completion.actualValue == null) {
          // Fallback: check if count > 0 (basic completion)
          return completion.count > 0 || completion.answer == true;
        }
        return completion.actualValue! >= (widget.habit.targetValue ?? 0);
      case 'timer':
        if (completion.actualDurationMinutes == null) {
          // Fallback: check if count > 0 (basic completion)
          return completion.count > 0 || completion.answer == true;
        }
        return completion.actualDurationMinutes! >=
            (widget.habit.targetDurationMinutes ?? 0);
      case 'checklist':
        return completion.count >= (widget.habit.checklist?.length ?? 1);
      case 'quit':
        // For quit habits, success means resisting (answer == true)
        return completion.answer == true;
      default:
        // Default: count > 0 or answer == true
        return completion.answer == true || completion.count > 0;
    }
  }

  /// Format numeric value realistically (integer if whole, 1 decimal otherwise)
  String _formatNumericValue(double value) {
    if (value % 1 == 0) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  void _showDayDetails(BuildContext context, HabitCompletion completion) {
    // Format numeric value if present
    String? formattedValueText;
    if (completion.actualValue != null) {
      final formattedValue = _formatNumericValue(completion.actualValue!);
      final unit = widget.habit.customUnitName ?? widget.habit.unit ?? '';
      final unitLabel = unit.isNotEmpty ? ' $unit' : '';
      formattedValueText = '$formattedValue$unitLabel'.toUpperCase();
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: widget.isDark ? const Color(0xFF1E2127) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(32, 12, 32, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                DateFormat(
                  'EEEE, MMMM d',
                ).format(completion.completedDate).toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Activity Details',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 24),
              _DetailRow(
                label: 'STATUS',
                value: completion.statusDescription.toUpperCase(),
                valueColor: completion.isSkipped
                    ? const Color(0xFFFFB347)
                    : (completion.answer == false
                          ? const Color(0xFFFF6B6B)
                          : const Color(0xFF4CAF50)),
              ),
              if (completion.skipReason != null)
                _DetailRow(label: 'REASON', value: completion.skipReason!),
              if (completion.note != null)
                _DetailRow(label: 'NOTE', value: completion.note!),
              if (completion.actualDurationMinutes != null)
                _DetailRow(
                  label: 'DURATION',
                  value: '${completion.actualDurationMinutes} MINUTES',
                ),
              if (formattedValueText != null)
                _DetailRow(label: 'VALUE', value: formattedValueText),
            ],
          ),
        );
      },
    );
  }
}

class _CalendarNavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isDark;

  const _CalendarNavButton({
    required this.icon,
    required this.onPressed,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: Icon(icon, size: 20),
        onPressed: onPressed,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

/// Simple legend item for calendar color coding (no count)
class _CalendarLegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool isDark;

  const _CalendarLegendItem({
    required this.color,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withOpacity(isDark ? 0.3 : 0.2),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withOpacity(0.8), width: 2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
      ],
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  final String label;
  const _WeekdayHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontWeight: FontWeight.w900,
        fontSize: 11,
        color: Colors.grey,
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
