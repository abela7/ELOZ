import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/habit.dart';
import '../../data/models/habit_statistics.dart';
import '../providers/temptation_log_providers.dart';
import 'log_temptation_modal.dart';
import 'statistics_widgets.dart';

/// Comprehensive statistics widget for Quit Bad Habits
/// QUIT HABIT SPECIFIC STATISTICS - separate from normal habits!
/// QUIT HABIT SPECIFIC - Uses WIN/SLIP terminology!
/// Shows: Days Won, Almost Days, Slips, Temptations, Money Saved, Triggers, Milestones
class QuitHabitStatisticsWidget extends ConsumerWidget {
  final Habit habit;
  final HabitStatistics statistics;
  final bool isDark;
  final bool showRecentActivity;

  const QuitHabitStatisticsWidget({
    super.key,
    required this.habit,
    required this.statistics,
    required this.isDark,
    this.showRecentActivity = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalTemptations = ref.watch(totalTemptationCountProvider(habit.id));
    final reasonStats = ref.watch(temptationReasonStatsProvider(habit.id));
    final intensityStats = ref.watch(temptationIntensityStatsProvider(habit.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        _buildSectionHeader(),
        const SizedBox(height: 16),

        // Main Stats Grid (2x2)
        _buildMainStatsGrid(),
        const SizedBox(height: 20),

        // Resistance Rate Gauge
        _buildResistanceRateGauge(),
        const SizedBox(height: 20),

        // Temptation Stats Card
        _buildTemptationStatsCard(
          context, 
          ref,
          totalTemptations,
          reasonStats,
          intensityStats,
        ),
        const SizedBox(height: 20),

        // Money Saved & Units Avoided
        if ((habit.costTrackingEnabled == true && statistics.moneySaved != null) ||
            statistics.unitsAvoided != null)
          _buildSavingsCard(),
        
        if ((habit.costTrackingEnabled == true && statistics.moneySaved != null) ||
            statistics.unitsAvoided != null)
          const SizedBox(height: 20),

        // Milestone Progress
        if (habit.goalType != null && habit.goalTarget != null)
          _buildMilestoneProgress(),

        if (habit.goalType != null && habit.goalTarget != null)
          const SizedBox(height: 20),

        // Recent Activity Timeline (conditionally shown)
        if (showRecentActivity)
          _buildRecentActivityTimeline(context, ref),
      ],
    );
  }

  Widget _buildSectionHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF4CAF50).withOpacity(0.15),
            const Color(0xFF4CAF50).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.celebration_rounded,
              color: const Color(0xFF4CAF50),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quit Progress',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                  ),
                ),
                Text(
                  'Tracking "${habit.quitActionName ?? 'bad habit'} ${habit.quitSubstance ?? ''}"',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainStatsGrid() {
    return Row(
      children: [
        Expanded(
          child: StatCard(
            title: 'Days Won',
            icon: Icons.local_fire_department_rounded,
            iconColor: const Color(0xFF4CAF50),
            isDark: isDark,
            child: StatItem(
              label: 'Current',
              value: '${statistics.currentStreak}',
              unit: 'days',
              color: const Color(0xFF4CAF50),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatCard(
            title: 'Best Streak',
            icon: Icons.emoji_events_rounded,
            iconColor: const Color(0xFFFFB347),
            isDark: isDark,
            child: StatItem(
              label: 'Record',
              value: '${statistics.bestStreak}',
              unit: 'days',
              color: const Color(0xFFFFB347),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResistanceRateGauge() {
    // Both "Win" and "Almost" days count as success (resistance)
    final daysWon = statistics.resistanceCount ?? 0;
    final slipDays = statistics.slipsCount ?? 0;
    final total = daysWon + slipDays;
    final rate = total > 0 
        ? (daysWon / total * 100) 
        : 100.0;
    
    Color rateColor;
    String rateLabel;
    IconData rateIcon;
    
    if (rate >= 90) {
      rateColor = const Color(0xFF4CAF50);
      rateLabel = 'Excellent!';
      rateIcon = Icons.star_rounded;
    } else if (rate >= 70) {
      rateColor = const Color(0xFFFFB347);
      rateLabel = 'Good Progress';
      rateIcon = Icons.thumb_up_rounded;
    } else if (rate >= 50) {
      rateColor = const Color(0xFFFFA726);
      rateLabel = 'Keep Trying';
      rateIcon = Icons.trending_up_rounded;
    } else {
      rateColor = const Color(0xFFEF5350);
      rateLabel = 'Need More Effort';
      rateIcon = Icons.fitness_center_rounded;
    }

    return StatCard(
      title: 'Resistance Rate',
      icon: Icons.shield_rounded,
      iconColor: rateColor,
      isDark: isDark,
      child: Column(
        children: [
          Row(
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: rateColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(rateIcon, color: rateColor, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      rateLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: rateColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          Stack(
            children: [
              Container(
                height: 12,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey[200],
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              FractionallySizedBox(
                widthFactor: rate / 100,
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [rateColor.withOpacity(0.7), rateColor],
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${rate.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black,
                  letterSpacing: -1,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _MiniLegend(color: const Color(0xFF4CAF50), label: '$daysWon days won', isDark: isDark),
                  const SizedBox(height: 4),
                  _MiniLegend(color: const Color(0xFFEF5350), label: '$slipDays slips', isDark: isDark),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTemptationStatsCard(
    BuildContext context, 
    WidgetRef ref,
    AsyncValue<int> totalTemptations,
    AsyncValue<Map<String, int>> reasonStats,
    AsyncValue<Map<int, int>> intensityStats,
  ) {
    return StatCard(
      title: 'Temptation Insights',
      icon: Icons.psychology_rounded,
      iconColor: habit.color,
      isDark: isDark,
      onExpand: () {
        // Option to log from here too
        LogTemptationModal.show(
          context,
          habit: habit,
          habitId: habit.id,
          habitTitle: habit.title,
          onLogged: () => ref.invalidate(habitTemptationLogsProvider(habit.id)),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          totalTemptations.when(
            data: (count) => Row(
              children: [
                Expanded(
                  child: _MiniStatBox(
                    label: 'Total Urges',
                    value: '$count',
                    color: const Color(0xFF9C27B0),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MiniStatBox(
                    label: 'Resisted',
                    value: '${statistics.resistanceCount ?? 0}',
                    color: const Color(0xFF4CAF50),
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const Text('Error loading'),
          ),
          const SizedBox(height: 24),
          
          // Top Triggers
          reasonStats.when(
            data: (reasons) {
              if (reasons.isEmpty) return _buildNoDataMessage('No triggers logged yet');

              final sortedReasons = reasons.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
              final topReasons = sortedReasons.take(3).toList();
              final maxCount = topReasons.first.value;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSubHeader('TOP TRIGGERS'),
                  const SizedBox(height: 12),
                  ...topReasons.map((entry) => _TriggerProgress(
                    label: entry.key,
                    count: entry.value,
                    percentage: entry.value / maxCount,
                    isDark: isDark,
                  )),
                ],
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          
          const SizedBox(height: 24),
          
          // Intensity distribution
          intensityStats.when(
            data: (intensities) {
              final total = intensities.values.fold<int>(0, (a, b) => a + b);
              if (total == 0) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSubHeader('INTENSITY LEVEL'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildIntensityChip('Mild', intensities[0] ?? 0, const Color(0xFF4CAF50), total, isDark),
                      _buildIntensityChip('Mod', intensities[1] ?? 0, const Color(0xFFFFB347), total, isDark),
                      _buildIntensityChip('Strong', intensities[2] ?? 0, const Color(0xFFFF6B6B), total, isDark),
                      _buildIntensityChip('Extreme', intensities[3] ?? 0, const Color(0xFFE53935), total, isDark),
                    ],
                  ),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildIntensityChip(String label, int count, Color color, int total, bool isDark) {
    final percentage = total > 0 ? (count / total * 100).round() : 0;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              '$percentage%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white54 : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavingsCard() {
    return StatCard(
      title: 'What You\'ve Saved',
      icon: Icons.savings_rounded,
      iconColor: const Color(0xFF4CAF50),
      isDark: isDark,
      child: Row(
        children: [
          if (habit.costTrackingEnabled == true &&
              statistics.moneySaved != null &&
              statistics.moneySaved! > 0)
            Expanded(
              child: Column(
                children: [
                  Text(
                    habit.formatCurrency(statistics.moneySaved!),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF4CAF50),
                      letterSpacing: -1,
                    ),
                  ),
                  _buildSubHeader('MONEY SAVED'),
                ],
              ),
            ),
          if (statistics.unitsAvoided != null && statistics.unitsAvoided! > 0)
            Expanded(
              child: Column(
                children: [
                  Text(
                    '${statistics.unitsAvoided}',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFCDAF56),
                      letterSpacing: -1,
                    ),
                  ),
                  _buildSubHeader('${(habit.unit ?? 'units').toUpperCase()} AVOIDED'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMilestoneProgress() {
    final target = habit.goalTarget ?? 0;
    final current = statistics.currentStreak;
    final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    final remaining = (target - current).clamp(0, target);

    return StatCard(
      title: 'Milestone Progress',
      icon: Icons.flag_rounded,
      iconColor: const Color(0xFFCDAF56),
      isDark: isDark,
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                height: 12,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey[200],
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFCDAF56), Color(0xFFFFB347)],
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$current / $target days',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (progress >= 1.0 ? Colors.green : const Color(0xFFCDAF56)).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  progress >= 1.0 ? 'GOAL REACHED! 🎉' : '$remaining DAYS LEFT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: progress >= 1.0 ? Colors.green : const Color(0xFFCDAF56),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubHeader(String text) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
        color: isDark ? Colors.white38 : Colors.black38,
      ),
    );
  }

  Widget _buildNoDataMessage(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[200]!),
      ),
      child: Text(
        message,
        style: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.grey[500]),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildRecentActivityTimeline(
    BuildContext context,
    WidgetRef ref,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline_rounded, color: habit.color, size: 20),
              const SizedBox(width: 8),
              Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Show recent completions (resists and slips)
          if (statistics.recentCompletions.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.hourglass_empty_rounded,
                      size: 40,
                      color: isDark ? Colors.white24 : Colors.grey[300],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No activity yet',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white38 : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...statistics.recentCompletions.take(5).map((completion) {
              final isSlip = completion.isSkipped;
              final date = completion.completedDate;
              final formattedDate = DateFormat('MMM d, h:mm a').format(date);
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: isSlip ? const Color(0xFFEF5350) : const Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isSlip ? 'Slipped' : 'Resisted',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isSlip 
                                  ? const Color(0xFFEF5350) 
                                  : const Color(0xFF4CAF50),
                            ),
                          ),
                          Text(
                            formattedDate,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white38 : Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (completion.skipReason != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          completion.skipReason!,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white54 : Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _MiniLegend extends StatelessWidget {
  final Color color;
  final String label;
  final bool isDark;

  const _MiniLegend({required this.color, required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey[600], fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _TriggerProgress extends StatelessWidget {
  final String label;
  final int count;
  final double percentage;
  final bool isDark;

  const _TriggerProgress({required this.label, required this.count, required this.percentage, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
              Text('${count}x', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF9C27B0))),
            ],
          ),
          const SizedBox(height: 6),
          Stack(
            children: [
              Container(height: 6, decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100], borderRadius: BorderRadius.circular(3))),
              FractionallySizedBox(
                widthFactor: percentage,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [const Color(0xFF9C27B0).withOpacity(0.7), const Color(0xFF9C27B0)]),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Stat box widget
class _StatBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;
  final bool highlight;

  const _StatBox({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: highlight 
            ? color.withOpacity(0.15)
            : (isDark ? Colors.white.withOpacity(0.05) : Colors.white),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlight ? color.withOpacity(0.3) : (isDark ? Colors.white.withOpacity(0.08) : Colors.grey[200]!),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

/// Mini stat box
class _MiniStatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _MiniStatBox({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
