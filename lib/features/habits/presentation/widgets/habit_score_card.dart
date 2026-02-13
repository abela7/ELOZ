import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/habit.dart';
import '../../data/models/habit_score.dart';
import '../providers/habit_score_providers.dart';

/// A card widget that displays the habit score with a breakdown.
/// Shows overall score, grade, and key metrics.
class HabitScoreCard extends ConsumerWidget {
  final String habitId;
  final bool showBreakdown;
  final bool compact;

  const HabitScoreCard({
    super.key,
    required this.habitId,
    this.showBreakdown = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scoreAsync = ref.watch(habitScoreProvider(habitId));

    return scoreAsync.when(
      data: (score) => _buildScoreCard(context, score),
      loading: () => _buildLoadingCard(context),
      error: (error, _) => _buildErrorCard(context, error.toString()),
    );
  }

  Widget _buildScoreCard(BuildContext context, HabitScore score) {
    final theme = Theme.of(context);
    final scoreColor = Color(score.scoreColorValue);

    if (compact) {
      return _buildCompactCard(context, score, scoreColor);
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with score circle
            Row(
              children: [
                _buildScoreCircle(context, score, scoreColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Habit Score',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        score.scoreLabel,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scoreColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Grade: ${score.grade}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (showBreakdown) ...[
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Score breakdown
              _buildBreakdownSection(context, score),

              const SizedBox(height: 16),

              // Insights
              if (score.insights.isNotEmpty) ...[
                Text(
                  'Insights',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...score.insights.map((insight) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_outline_rounded,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          insight,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompactCard(BuildContext context, HabitScore score, Color scoreColor) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scoreColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scoreColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scoreColor,
            ),
            child: Center(
              child: Text(
                score.grade,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${score.overallScore.toStringAsFixed(0)}%',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                score.scoreLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCircle(BuildContext context, HabitScore score, Color scoreColor) {
    final theme = Theme.of(context);
    
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          CircularProgressIndicator(
            value: 1,
            strokeWidth: 8,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(
              theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          // Progress circle
          CircularProgressIndicator(
            value: score.overallScore / 100,
            strokeWidth: 8,
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation(scoreColor),
          ),
          // Score text
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${score.overallScore.toStringAsFixed(0)}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: scoreColor,
                ),
              ),
              Text(
                score.grade,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownSection(BuildContext context, HabitScore score) {
    return Column(
      children: [
        _buildBreakdownRow(
          context,
          'Completion Rate',
          score.completionRateScore,
          '${score.actualCompletions}/${score.expectedCompletions}',
          Icons.check_circle_outline_rounded,
        ),
        const SizedBox(height: 8),
        _buildBreakdownRow(
          context,
          'Streak',
          score.streakScore,
          '${score.currentStreak} days',
          Icons.local_fire_department_rounded,
        ),
        const SizedBox(height: 8),
        _buildBreakdownRow(
          context,
          'Consistency',
          score.consistencyScore,
          null,
          Icons.timeline_rounded,
        ),
        const SizedBox(height: 8),
        _buildBreakdownRow(
          context,
          'Trend',
          score.trendScore,
          _getTrendLabel(score.trendDirection),
          _getTrendIcon(score.trendDirection),
        ),
        if (score.averageCompletionPercent != null) ...[
          const SizedBox(height: 8),
          _buildBreakdownRow(
            context,
            'Quality',
            score.qualityScore,
            '${score.averageCompletionPercent!.toStringAsFixed(0)}% of target',
            Icons.star_outline_rounded,
          ),
        ],
      ],
    );
  }

  Widget _buildBreakdownRow(
    BuildContext context,
    String label,
    double score,
    String? subtitle,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    final barColor = _getColorForScore(score);

    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          flex: 3,
          child: Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: score / 100,
                    minHeight: 6,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(barColor),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 32,
                child: Text(
                  '${score.toStringAsFixed(0)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getColorForScore(double score) {
    if (score >= 80) return const Color(0xFF4CAF50);
    if (score >= 60) return const Color(0xFFFFC107);
    if (score >= 40) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }

  String _getTrendLabel(String direction) {
    switch (direction) {
      case 'improving':
        return 'Improving';
      case 'declining':
        return 'Declining';
      default:
        return 'Stable';
    }
  }

  IconData _getTrendIcon(String direction) {
    switch (direction) {
      case 'improving':
        return Icons.trending_up_rounded;
      case 'declining':
        return Icons.trending_down_rounded;
      default:
        return Icons.trending_flat_rounded;
    }
  }

  Widget _buildLoadingCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context, String error) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: theme.colorScheme.error,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              'Unable to calculate score',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// A small badge showing just the score grade
class HabitScoreBadge extends ConsumerWidget {
  final String habitId;
  final double size;

  const HabitScoreBadge({
    super.key,
    required this.habitId,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scoreAsync = ref.watch(habitScoreProvider(habitId));

    return scoreAsync.when(
      data: (score) {
        if (score.analysisDays < 3) {
          return const SizedBox.shrink();
        }
        
        final scoreColor = Color(score.scoreColorValue);
        
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scoreColor,
          ),
          child: Center(
            child: Text(
              score.grade.replaceAll('+', '').replaceAll('-', ''),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: size * 0.45,
              ),
            ),
          ),
        );
      },
      loading: () => SizedBox(width: size, height: size),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// Summary card showing overall habit performance
class HabitScoreSummaryCard extends ConsumerWidget {
  const HabitScoreSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(habitScoreSummaryProvider);
    final theme = Theme.of(context);

    return summaryAsync.when(
      data: (summary) {
        if (!summary.hasData) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'Complete habits for a few days to see your score summary',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final scoreColor = Color(
          HabitScore(
            habitId: '',
            overallScore: summary.averageScore,
            completionRateScore: 0,
            completionRatePercent: 0,
            streakScore: 0,
            consistencyScore: 0,
            trendScore: 50,
            recoveryScore: 50,
            qualityScore: 0,
            analysisDays: 0,
            expectedCompletions: 0,
            actualCompletions: 0,
            currentStreak: 0,
            bestStreak: 0,
            trendDirection: 'stable',
            grade: summary.overallGrade,
            scoreLabel: '',
            insights: [],
            calculatedAt: DateTime.now(),
          ).scoreColorValue,
        );

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.analytics_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Overall Performance',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Main stats row
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        context,
                        summary.averageScoreFormatted,
                        'Avg Score',
                        scoreColor,
                      ),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        context,
                        summary.overallGrade,
                        'Grade',
                        scoreColor,
                      ),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        context,
                        summary.completionRateFormatted,
                        'Completion',
                        null,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),
                
                // Trend indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildTrendChip(
                      context,
                      '${summary.improvingCount}',
                      'Improving',
                      Icons.trending_up_rounded,
                      Colors.green,
                    ),
                    _buildTrendChip(
                      context,
                      '${summary.stableCount}',
                      'Stable',
                      Icons.trending_flat_rounded,
                      Colors.blue,
                    ),
                    _buildTrendChip(
                      context,
                      '${summary.decliningCount}',
                      'Declining',
                      Icons.trending_down_rounded,
                      Colors.orange,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String value,
    String label,
    Color? color,
  ) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color ?? theme.colorScheme.onSurface,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildTrendChip(
    BuildContext context,
    String count,
    String label,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                count,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
