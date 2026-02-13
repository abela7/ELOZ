import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../data/models/habit.dart';
import '../../data/models/habit_completion.dart';
import '../../data/models/habit_statistics.dart';
import 'modern_trend_section.dart';

part 'statistics_widgets_trends.dart';

/// Success/Fail Pie Chart
class SuccessFailChart extends StatelessWidget {
  final HabitStatistics statistics;
  final Habit habit;
  final bool isDark;

  const SuccessFailChart({
    super.key,
    required this.statistics,
    required this.habit,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final total =
        statistics.successCount +
        statistics.failCount +
        statistics.skipCount +
        statistics.postponeCount;

    if (total == 0) {
      return const SizedBox.shrink();
    }

    final isQuit = habit.isQuitHabit;
    final successLabel = isQuit ? 'Resisted' : 'Success';
    final failLabel = isQuit ? 'Slipped' : 'Failed';

    return StatCard(
      title: 'Performance Breakdown',
      icon: Icons.donut_large_rounded,
      iconColor: habit.color,
      isDark: isDark,
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sections: [
                      if (statistics.successCount > 0)
                        PieChartSectionData(
                          value: statistics.successCount.toDouble(),
                          title: '',
                          color: const Color(0xFF4CAF50),
                          radius: 25,
                          showTitle: false,
                          badgeWidget: _buildBadge(
                            Icons.check_rounded,
                            const Color(0xFF4CAF50),
                          ),
                          badgePositionPercentageOffset: 1.2,
                        ),
                      if (statistics.failCount > 0)
                        PieChartSectionData(
                          value: statistics.failCount.toDouble(),
                          title: '',
                          color: const Color(0xFFFF6B6B),
                          radius: 25,
                          showTitle: false,
                          badgeWidget: _buildBadge(
                            Icons.close_rounded,
                            const Color(0xFFFF6B6B),
                          ),
                          badgePositionPercentageOffset: 1.2,
                        ),
                      if (statistics.skipCount > 0)
                        PieChartSectionData(
                          value: statistics.skipCount.toDouble(),
                          title: '',
                          color: const Color(0xFFFFB347),
                          radius: 25,
                          showTitle: false,
                          badgeWidget: _buildBadge(
                            Icons.forward_rounded,
                            const Color(0xFFFFB347),
                          ),
                          badgePositionPercentageOffset: 1.2,
                        ),
                      if (statistics.postponeCount > 0)
                        PieChartSectionData(
                          value: statistics.postponeCount.toDouble(),
                          title: '',
                          color: const Color(0xFF90A4AE),
                          radius: 25,
                          showTitle: false,
                          badgeWidget: _buildBadge(
                            Icons.pause_rounded,
                            const Color(0xFF90A4AE),
                          ),
                          badgePositionPercentageOffset: 1.2,
                        ),
                    ],
                    sectionsSpace: 6,
                    centerSpaceRadius: 55,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$total',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    Text(
                      'TOTAL',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 3.8,
            mainAxisSpacing: 10,
            crossAxisSpacing: 12,
            children: [
              if (statistics.successCount > 0)
                _LegendItem(
                  color: const Color(0xFF4CAF50),
                  label: successLabel,
                  count: statistics.successCount,
                  isDark: isDark,
                ),
              if (statistics.failCount > 0)
                _LegendItem(
                  color: const Color(0xFFFF6B6B),
                  label: failLabel,
                  count: statistics.failCount,
                  isDark: isDark,
                ),
              if (statistics.skipCount > 0)
                _LegendItem(
                  color: const Color(0xFFFFB347),
                  label: 'Skipped',
                  count: statistics.skipCount,
                  isDark: isDark,
                ),
              if (statistics.postponeCount > 0)
                _LegendItem(
                  color: const Color(0xFF90A4AE),
                  label: 'Postponed',
                  count: statistics.postponeCount,
                  isDark: isDark,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 10),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final int count;
  final bool isDark;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.count,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.03)
            : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
          Text(
            '$count',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

/// Tags Section
class TagsSection extends StatelessWidget {
  final List<String> tags;
  final Color color;
  final bool isDark;

  const TagsSection({
    super.key,
    required this.tags,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();

    return StatCard(
      title: 'Tags',
      icon: Icons.local_offer_rounded,
      iconColor: color,
      isDark: isDark,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: tags.map((tag) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Text(
              '#$tag',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// History & Reasons Section
class HistorySection extends StatelessWidget {
  final HabitStatistics statistics;
  final Habit habit;
  final bool isDark;

  const HistorySection({
    super.key,
    required this.statistics,
    required this.habit,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final recent = statistics.recentCompletions.take(8).toList();
    if (recent.isEmpty) return const SizedBox.shrink();

    return StatCard(
      title: 'Recent Activity',
      icon: Icons.history_toggle_off_rounded,
      iconColor: const Color(0xFF90A4AE),
      isDark: isDark,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          ...recent.asMap().entries.map((entry) {
            final isLast = entry.key == recent.length - 1;
            return Column(
              children: [
                _HistoryItem(
                  completion: entry.value,
                  habit: habit,
                  isDark: isDark,
                ),
                if (!isLast)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: isDark
                          ? Colors.white.withOpacity(0.03)
                          : Colors.black.withOpacity(0.03),
                    ),
                  ),
              ],
            );
          }),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final HabitCompletion completion;
  final Habit habit;
  final bool isDark;

  const _HistoryItem({
    required this.completion,
    required this.habit,
    required this.isDark,
  });

  /// Format numeric value realistically (integer if whole, 1 decimal otherwise)
  String _formatNumericValue(double value) {
    if (value % 1 == 0) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    IconData icon;

    if (completion.isSkipped) {
      statusColor = const Color(0xFFFFB347);
      icon = Icons.forward_rounded;
    } else if (completion.answer == false) {
      statusColor = const Color(0xFFFF6B6B);
      icon = Icons.close_rounded;
    } else {
      statusColor = const Color(0xFF4CAF50);
      icon = Icons.check_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: statusColor, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEEE, MMM d').format(completion.completedDate),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: isDark
                        ? Colors.white.withOpacity(0.9)
                        : Colors.black.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 2),
                if (completion.skipReason != null || completion.note != null)
                  Text(
                    completion.skipReason ?? completion.note!,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : Colors.black38,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                else if (completion.actualValue == null &&
                    completion.actualDurationMinutes == null)
                  Text(
                    completion.statusDescription,
                    style: TextStyle(
                      fontSize: 11,
                      color: statusColor.withOpacity(0.8),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
              ],
            ),
          ),
          if (completion.actualDurationMinutes != null)
            _SmallStat(
              label: 'TIME',
              value: '${completion.actualDurationMinutes}m',
              isDark: isDark,
            )
          else if (completion.actualValue != null)
            _SmallStat(
              label: 'VALUE',
              value: _formatNumericValue(completion.actualValue!),
              isDark: isDark,
            ),
        ],
      ),
    );
  }
}

class _SmallStat extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;

  const _SmallStat({
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white24 : Colors.black26,
            letterSpacing: 0.5,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
      ],
    );
  }
}

/// Weekday Distribution Bar Chart
class WeekdayDistributionChart extends StatelessWidget {
  final HabitStatistics statistics;
  final Habit habit;
  final bool isDark;

  const WeekdayDistributionChart({
    super.key,
    required this.statistics,
    required this.habit,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final maxValue = statistics.weekdayDistribution.reduce(
      (a, b) => a > b ? a : b,
    );
    if (maxValue == 0) {
      return const SizedBox.shrink();
    }

    return StatCard(
      title: 'Weekly Distribution',
      icon: Icons.bar_chart_rounded,
      iconColor: habit.color,
      isDark: isDark,
      child: SizedBox(
        height: 180,
        child: BarChart(
          BarChartData(
            maxY: maxValue.toDouble() + 1,
            barGroups: List.generate(7, (index) {
              final isToday = DateTime.now().weekday % 7 == index;
              return BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: statistics.weekdayDistribution[index].toDouble(),
                    color: isToday ? habit.color : habit.color.withOpacity(0.4),
                    width: 16,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6),
                    ),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: maxValue.toDouble() + 1,
                      color: isDark
                          ? Colors.white.withOpacity(0.03)
                          : Colors.black.withOpacity(0.03),
                    ),
                  ),
                ],
              );
            }),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
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
                  getTitlesWidget: (value, meta) {
                    const days = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
                    return Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        days[value.toInt()],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
          ),
        ),
      ),
    );
  }
}
