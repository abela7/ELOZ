import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/sleep_correlation_insight.dart';
import '../../data/models/sleep_factor.dart';
import '../providers/sleep_providers.dart';

/// Reusable body content for factor insights. Used in full screen and Report tab.
/// When [dateRange] is provided (from Report Factors tab), insights use that period.
class SleepFactorInsightsContent extends ConsumerWidget {
  const SleepFactorInsightsContent({super.key, this.dateRange});

  final ({DateTime start, DateTime end})? dateRange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final insightsAsync = dateRange != null
        ? ref.watch(sleepCorrelationInsightsForRangeProvider(dateRange!))
        : ref.watch(sleepCorrelationInsightsProvider);
    final factorsAsync = ref.watch(sleepFactorsStreamProvider);
    return _SleepFactorInsightsBody.buildBody(
      context,
      isDark,
      insightsAsync,
      factorsAsync,
    );
  }
}

class _SleepFactorInsightsBody {
  _SleepFactorInsightsBody._();

  static const _gold = AppColors.gold;

  static Widget buildBody(
    BuildContext context,
    bool isDark,
    AsyncValue<SleepCorrelationInsights> insightsAsync,
    AsyncValue<List<SleepFactor>> factorsAsync,
  ) {
    final theme = Theme.of(context);
    return insightsAsync.when(
      data: (insights) {
        final factors = factorsAsync.valueOrNull ?? [];
        final factorMap = {for (final f in factors) f.id: f};

        if (!insights.hasEnoughData) {
          return _insufficientData(
            isDark,
            insights.totalNightsAnalyzed,
            insights.rangeStart,
            insights.rangeEnd,
          );
        }

        if (insights.positive.isEmpty && insights.negative.isEmpty) {
          return _noInsightsYet(
            isDark,
            insights.totalNightsAnalyzed,
            insights.rangeStart,
            insights.rangeEnd,
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _headerCard(
                isDark,
                insights.totalNightsAnalyzed,
                insights.nightsWithFactors,
                insights.rangeStart,
                insights.rangeEnd,
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'We compared nights with vs without each factor to discover patterns in your sleep quality and duration.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              if (insights.positive.isNotEmpty) ...[
                const SizedBox(height: 16),
                _sectionTitle(
                  isDark,
                  'Factors Improving Sleep',
                  Icons.trending_up_rounded,
                  AppColors.success,
                ),
                ...insights.positive.map(
                  (i) => _insightCard(theme, isDark, i, factorMap[i.factorId], true),
                ),
              ],
              if (insights.negative.isNotEmpty) ...[
                const SizedBox(height: 16),
                _sectionTitle(
                  isDark,
                  'Factors Harming Sleep',
                  Icons.trending_down_rounded,
                  AppColors.error,
                ),
                ...insights.negative.map(
                  (i) => _insightCard(theme, isDark, i, factorMap[i.factorId], false),
                ),
              ],
              if (insights.neutral.isNotEmpty) ...[
                const SizedBox(height: 16),
                _sectionTitle(
                  isDark,
                  'Neutral / Insufficient Data',
                  Icons.horizontal_rule_rounded,
                  isDark ? Colors.white54 : Colors.black45,
                ),
                ...insights.neutral
                    .take(5)
                    .map(
                      (i) =>
                          _insightCard(theme, isDark, i, factorMap[i.factorId], null),
                    ),
              ],
              const SizedBox(height: 16),
              _aboutSection(isDark),
            ],
          ),
        );
      },
      loading: () => Center(
        child: Padding(
          padding: const EdgeInsets.all(80),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: _gold, strokeWidth: 2),
              const SizedBox(height: 16),
              Text(
                'Analyzing your sleep patterns...',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
        ),
      ),
      error: (_, __) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(isDark ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  size: 32,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Could not load insights',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Please try again later',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _headerCard(
    bool isDark,
    int nights,
    int nightsWithFactors, [
    DateTime? rangeStart,
    DateTime? rangeEnd,
  ]) {
    final periodLabel = rangeStart != null && rangeEnd != null
        ? '${DateFormat('MMM d').format(rangeStart)} – ${DateFormat('MMM d').format(rangeEnd)}'
        : 'Last 30 nights';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [AppColors.goldOpacity02, AppColors.whiteOpacity004]
              : [AppColors.goldOpacity02, Colors.white],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppColors.gold.withOpacity(0.15)
              : AppColors.gold.withOpacity(0.1),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: AppColors.gold.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _gold.withOpacity(isDark ? 0.2 : 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.insights_rounded, size: 20, color: _gold),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  periodLabel.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: _gold,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$nights',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                        height: 1,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'nights',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Compact stat chips
          _headerMiniChip(isDark, '$nightsWithFactors', 'with', AppColors.gold),
          const SizedBox(width: 8),
          _headerMiniChip(
            isDark,
            '${nights - nightsWithFactors}',
            'without',
            isDark ? Colors.white54 : Colors.black45,
          ),
        ],
      ),
    );
  }

  static Widget _headerMiniChip(
    bool isDark,
    String value,
    String label,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.whiteOpacity006 : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _sectionTitle(
    bool isDark,
    String title,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(isDark ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _insightCard(
    ThemeData theme,
    bool isDark,
    FactorCorrelationInsight insight,
    SleepFactor? factor,
    bool? isPositive,
  ) {
    final name = factor?.name ?? insight.factorId;
    final color = factor?.color ??
        (isPositive == true
            ? AppColors.success
            : isPositive == false
                ? AppColors.error
                : (isDark ? Colors.white54 : Colors.black45));
    final scoreWith = insight.avgScoreWith.round();
    final scoreWithout = insight.avgScoreWithout.round();
    final hrsWith = insight.avgHoursWith;
    final hrsWithout = insight.avgHoursWithout;
    final hrsWithStr = _formatHours(hrsWith);
    final hrsWithoutStr = _formatHours(hrsWithout);
    final scoreDiff = scoreWith - scoreWithout;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surfaceContainerLow : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.05),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {}, // Dummy onTap for InkWell, actual onTap is inside Builder
          borderRadius: BorderRadius.circular(20),
          child: Builder(
            builder: (context) => InkWell(
              onTap: () {
                HapticFeedback.mediumImpact();
                _showFactorDetailSheet(
                  context,
                  isDark,
                  insight,
                  factor,
                  isPositive,
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    // Icon container
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withOpacity(isDark ? 0.15 : 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        factor?.icon ?? Icons.category_rounded,
                        size: 22,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Title and subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Text(
                                '${insight.countWith + insight.countWithout} nights',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color:
                                      isDark ? Colors.white38 : Colors.black45,
                                ),
                              ),
                              if (scoreDiff != 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: (isPositive == true
                                            ? AppColors.success
                                            : AppColors.error)
                                        .withOpacity(isDark ? 0.12 : 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isPositive == true
                                            ? Icons.arrow_upward_rounded
                                            : Icons.arrow_downward_rounded,
                                        size: 10,
                                        color: isPositive == true
                                            ? AppColors.success
                                            : AppColors.error,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        '${scoreDiff.abs()} pts',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: isPositive == true
                                              ? AppColors.success
                                              : AppColors.error,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Compact stats
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _compactStatPill(
                          isDark,
                          scoreWith,
                          hrsWithStr,
                          isPositive == true,
                          'With',
                        ),
                        const SizedBox(width: 6),
                        _compactStatPill(
                          isDark,
                          scoreWithout,
                          hrsWithoutStr,
                          isPositive == false,
                          'No',
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: isDark ? Colors.white24 : Colors.black26,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Show detailed bottom sheet for a factor
  static void _showFactorDetailSheet(
    BuildContext context,
    bool isDark,
    FactorCorrelationInsight insight,
    SleepFactor? factor,
    bool? isPositive,
  ) {
    final name = factor?.name ?? insight.factorId;
    final color =
        factor?.color ??
        (isPositive == true
            ? AppColors.success
            : isPositive == false
            ? AppColors.error
            : (isDark ? Colors.white54 : Colors.black45));
    final scoreWith = insight.avgScoreWith.round();
    final scoreWithout = insight.avgScoreWithout.round();
    final hrsWith = insight.avgHoursWith;
    final hrsWithout = insight.avgHoursWithout;
    final scoreDiff = scoreWith - scoreWithout;
    final hrsDiff = hrsWith - hrsWithout;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2128) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? [
                                  color.withOpacity(0.25),
                                  color.withOpacity(0.12),
                                ]
                              : [
                                  color.withOpacity(0.2),
                                  color.withOpacity(0.08),
                                ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        factor?.icon ?? Icons.category_rounded,
                        size: 28,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${insight.countWith + insight.countWithout} nights tracked',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Impact badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isPositive == true
                            ? AppColors.success.withOpacity(isDark ? 0.15 : 0.1)
                            : isPositive == false
                            ? AppColors.error.withOpacity(isDark ? 0.15 : 0.1)
                            : (isDark
                                  ? Colors.white10
                                  : Colors.black.withOpacity(0.05)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPositive == true
                                ? Icons.trending_up_rounded
                                : isPositive == false
                                ? Icons.trending_down_rounded
                                : Icons.horizontal_rule_rounded,
                            size: 16,
                            color: isPositive == true
                                ? AppColors.success
                                : isPositive == false
                                ? AppColors.error
                                : (isDark ? Colors.white54 : Colors.black45),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isPositive == true
                                ? 'HELPS'
                                : isPositive == false
                                ? 'HURTS'
                                : 'NEUTRAL',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isPositive == true
                                  ? AppColors.success
                                  : isPositive == false
                                  ? AppColors.error
                                  : (isDark ? Colors.white54 : Colors.black45),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Impact Summary Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [
                              (isPositive == true
                                      ? AppColors.success
                                      : isPositive == false
                                      ? AppColors.error
                                      : _gold)
                                  .withOpacity(0.12),
                              (isPositive == true
                                      ? AppColors.success
                                      : isPositive == false
                                      ? AppColors.error
                                      : _gold)
                                  .withOpacity(0.04),
                            ]
                          : [
                              (isPositive == true
                                      ? AppColors.success
                                      : isPositive == false
                                      ? AppColors.error
                                      : _gold)
                                  .withOpacity(0.08),
                              (isPositive == true
                                      ? AppColors.success
                                      : isPositive == false
                                      ? AppColors.error
                                      : _gold)
                                  .withOpacity(0.02),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color:
                          (isPositive == true
                                  ? AppColors.success
                                  : isPositive == false
                                  ? AppColors.error
                                  : _gold)
                              .withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.insights_rounded,
                            size: 18,
                            color: isPositive == true
                                ? AppColors.success
                                : isPositive == false
                                ? AppColors.error
                                : _gold,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'IMPACT SUMMARY',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isPositive == true
                                  ? AppColors.success
                                  : isPositive == false
                                  ? AppColors.error
                                  : _gold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _getImpactSummary(
                          name,
                          isPositive,
                          scoreDiff,
                          hrsDiff,
                          insight,
                        ),
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Score Comparison Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'SLEEP QUALITY COMPARISON',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _gold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: _detailStatCard(
                        isDark,
                        'With Factor',
                        scoreWith,
                        _formatHours(hrsWith),
                        insight.countWith,
                        isPositive == true,
                        color,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _detailStatCard(
                        isDark,
                        'Without Factor',
                        scoreWithout,
                        _formatHours(hrsWithout),
                        insight.countWithout,
                        isPositive == false,
                        color,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Difference Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.03)
                        : Colors.black.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _diffColumn(
                            isDark,
                            'Score Difference',
                            '${scoreDiff >= 0 ? '+' : ''}$scoreDiff',
                            scoreDiff >= 0
                                ? AppColors.success
                                : AppColors.error,
                            Icons.score_rounded,
                          ),
                          Container(
                            width: 1,
                            height: 50,
                            color: isDark
                                ? Colors.white10
                                : Colors.black.withOpacity(0.06),
                          ),
                          _diffColumn(
                            isDark,
                            'Sleep Duration',
                            '${hrsDiff >= 0 ? '+' : ''}${hrsDiff.toStringAsFixed(1)}h',
                            hrsDiff >= 0 ? AppColors.success : AppColors.error,
                            Icons.bedtime_rounded,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Recommendations Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'RECOMMENDATIONS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _gold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _recommendationCard(isDark, isPositive, name, insight),
              ),

              const SizedBox(height: 20),

              // Data Confidence
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _confidenceCard(isDark, insight),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  static String _getImpactSummary(
    String name,
    bool? isPositive,
    int scoreDiff,
    double hrsDiff,
    FactorCorrelationInsight insight,
  ) {
    if (isPositive == true) {
      return 'On nights when you had $name, your sleep quality score was ${scoreDiff.abs()} points higher on average. '
          'You also slept ${hrsDiff.abs().toStringAsFixed(1)} hours ${hrsDiff >= 0 ? 'longer' : 'shorter'}. '
          'This factor appears to benefit your sleep.';
    } else if (isPositive == false) {
      return 'On nights when you had $name, your sleep quality score was ${scoreDiff.abs()} points lower on average. '
          'You also slept ${hrsDiff.abs().toStringAsFixed(1)} hours ${hrsDiff >= 0 ? 'longer' : 'shorter'}. '
          'Consider reducing or avoiding this factor before bed.';
    } else {
      return 'This factor doesn\'t show a significant impact on your sleep quality. '
          'More data may be needed to determine its effect.';
    }
  }

  static Widget _detailStatCard(
    bool isDark,
    String label,
    int score,
    String hours,
    int nights,
    bool? isHighlighted,
    Color factorColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted == true
              ? AppColors.success.withOpacity(0.3)
              : isHighlighted == false
              ? AppColors.error.withOpacity(0.3)
              : (isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
          const SizedBox(height: 12),
          // Score circle
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isHighlighted == true
                    ? [
                        AppColors.success.withOpacity(0.2),
                        AppColors.success.withOpacity(0.1),
                      ]
                    : isHighlighted == false
                    ? [
                        AppColors.error.withOpacity(0.2),
                        AppColors.error.withOpacity(0.1),
                      ]
                    : [
                        factorColor.withOpacity(0.15),
                        factorColor.withOpacity(0.08),
                      ],
              ),
            ),
            child: Center(
              child: Text(
                '$score',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: isHighlighted == true
                      ? AppColors.success
                      : isHighlighted == false
                      ? AppColors.error
                      : (isDark ? Colors.white : Colors.black87),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            hours,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$nights nights',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _diffColumn(
    bool isDark,
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  static Widget _recommendationCard(
    bool isDark,
    bool? isPositive,
    String name,
    FactorCorrelationInsight insight,
  ) {
    final recommendations = <Widget>[];

    if (isPositive == true) {
      recommendations.add(
        _recommendationItem(
          isDark,
          Icons.check_circle_rounded,
          AppColors.success,
          'Keep it up!',
          'Continue including $name in your pre-sleep routine. It appears to improve your sleep quality.',
        ),
      );
      recommendations.add(const SizedBox(height: 12));
      recommendations.add(
        _recommendationItem(
          isDark,
          Icons.science_rounded,
          _gold,
          'Experiment further',
          'Try varying the timing or amount to find the optimal approach.',
        ),
      );
    } else if (isPositive == false) {
      recommendations.add(
        _recommendationItem(
          isDark,
          Icons.warning_amber_rounded,
          AppColors.error,
          'Consider avoiding',
          'Try reducing or eliminating $name before bedtime for better sleep quality.',
        ),
      );
      recommendations.add(const SizedBox(height: 12));
      recommendations.add(
        _recommendationItem(
          isDark,
          Icons.schedule_rounded,
          AppColors.info,
          'Timing matters',
          'If you can\'t avoid it entirely, try having it earlier in the day, at least 3-4 hours before bed.',
        ),
      );
    } else {
      recommendations.add(
        _recommendationItem(
          isDark,
          Icons.info_outline_rounded,
          _gold,
          'More data needed',
          'Continue tracking to see if a pattern emerges. Try to log at least 10 nights with and without this factor.',
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.03)
            : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: recommendations,
      ),
    );
  }

  static Widget _recommendationItem(
    bool isDark,
    IconData icon,
    Color color,
    String title,
    String description,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(isDark ? 0.15 : 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _confidenceCard(bool isDark, FactorCorrelationInsight insight) {
    final totalNights = insight.countWith + insight.countWithout;
    String confidenceLevel;
    Color confidenceColor;
    String confidenceDesc;

    if (totalNights >= 20 &&
        insight.countWith >= 5 &&
        insight.countWithout >= 5) {
      confidenceLevel = 'High';
      confidenceColor = AppColors.success;
      confidenceDesc =
          'Based on sufficient data, this insight is statistically reliable.';
    } else if (totalNights >= 10 &&
        insight.countWith >= 3 &&
        insight.countWithout >= 3) {
      confidenceLevel = 'Moderate';
      confidenceColor = _gold;
      confidenceDesc =
          'More data would improve reliability. Continue tracking this factor.';
    } else {
      confidenceLevel = 'Low';
      confidenceColor = AppColors.info;
      confidenceDesc =
          'Limited data available. Results may change with more tracking.';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: confidenceColor.withOpacity(isDark ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: confidenceColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_outlined, size: 20, color: confidenceColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Confidence: ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                    Text(
                      confidenceLevel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: confidenceColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  confidenceDesc,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.3,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Compact stat pill for inline display
  static Widget _compactStatPill(
    bool isDark,
    int score,
    String hours,
    bool? isHighlighted,
    String label,
  ) {
    final highlightColor = isHighlighted == true
        ? AppColors.success
        : isHighlighted == false
            ? AppColors.error
            : (isDark ? Colors.white38 : Colors.black38);

    return Container(
      width: 62,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: isHighlighted == true
            ? AppColors.success.withOpacity(isDark ? 0.1 : 0.06)
            : isHighlighted == false
                ? AppColors.error.withOpacity(isDark ? 0.1 : 0.06)
                : (isDark
                    ? Colors.white.withOpacity(0.03)
                    : Colors.black.withOpacity(0.02)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlighted != null
              ? highlightColor.withOpacity(0.15)
              : Colors.transparent,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 7,
              fontWeight: FontWeight.w900,
              color: highlightColor.withOpacity(0.6),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            '$score',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: isHighlighted != null
                  ? highlightColor
                  : (isDark ? Colors.white : Colors.black87),
              height: 1.1,
            ),
          ),
          Text(
            hours,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatHours(double h) {
    if (h >= 1) {
      final hrs = h.floor();
      final mins = ((h % 1) * 60).round();
      return mins > 0 ? '$hrs h $mins m' : '$hrs h';
    }
    return '${(h * 60).round()} min';
  }

  static Widget _insufficientData(
    bool isDark,
    int nights, [
    DateTime? rangeStart,
    DateTime? rangeEnd,
  ]) {
    final periodText = rangeStart != null && rangeEnd != null
        ? '${DateFormat('MMM yyyy').format(rangeStart)}'
        : 'this period';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _gold.withOpacity(isDark ? 0.1 : 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.analytics_outlined, size: 40, color: _gold),
            ),
            const SizedBox(height: 20),
            Text(
              'Need more data',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'For $periodText you have $nights nights logged.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.02)
                    : Colors.black.withOpacity(0.02),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'We need at least 5–10 nights with and without factors to find patterns. Try a longer period or log more sleep with pre-sleep factors.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _noInsightsYet(
    bool isDark,
    int nights, [
    DateTime? rangeStart,
    DateTime? rangeEnd,
  ]) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.04)
                    : Colors.black.withOpacity(0.03),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.insights_rounded,
                size: 40,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No clear patterns yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We analyzed $nights nights in this period.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.02)
                    : Colors.black.withOpacity(0.02),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Log sleep with factors on some nights and omit them on others to discover what helps or hurts your sleep.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _aboutSection(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.whiteOpacity004 : AppColors.cardLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.03),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _gold.withOpacity(isDark ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.info_outline_rounded, size: 14, color: _gold),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Compares sleep with vs without each factor. Need 2+ nights each for results.',
              style: TextStyle(
                fontSize: 11,
                height: 1.4,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
