import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Gold accent used across finance report
const Color _kReportGold = Color(0xFFCDAF56);
const Color _kIncomeGreen = Color(0xFF4CAF50);
const Color _kExpenseRed = Color(0xFFFF5252);

/// Hero card for report headline metrics
class ReportHeroCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final double? delta;
  final bool isPositiveGood;
  final Color? accentColor;
  final bool isDark;

  const ReportHeroCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.delta,
    this.isPositiveGood = true,
    this.accentColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? _kReportGold;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withOpacity(0.12),
            accent.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (delta != null) ...[
                const SizedBox(width: 12),
                _ReportDeltaBadge(
                  delta: delta!,
                  isPositiveGood: isPositiveGood,
                  isDark: isDark,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ReportDeltaBadge extends StatelessWidget {
  final double delta;
  final bool isPositiveGood;
  final bool isDark;

  const _ReportDeltaBadge({
    required this.delta,
    required this.isPositiveGood,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isGood = (delta > 0 && isPositiveGood) || (delta < 0 && !isPositiveGood);
    final color = isGood ? _kIncomeGreen : _kExpenseRed;
    final arrow = delta > 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.2 : 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(arrow, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '${delta.abs().toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small stat card with icon
class ReportStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final double? deltaPercent;
  final bool isPositiveGood;
  final Color? iconColor;
  final bool isDark;

  const ReportStatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.deltaPercent,
    this.isPositiveGood = true,
    this.iconColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? _kReportGold;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (deltaPercent != null)
                _ReportDeltaBadge(
                  delta: deltaPercent!,
                  isPositiveGood: isPositiveGood,
                  isDark: isDark,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1E1E1E),
            ),
          ),
        ],
      ),
    );
  }
}

/// 2x2 grid of stat cards
class ReportStatGrid extends StatelessWidget {
  final List<ReportStatCard> children;
  final int crossAxisCount;

  const ReportStatGrid({
    super.key,
    required this.children,
    this.crossAxisCount = 2,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: children,
    );
  }
}

/// Comparison badge (vs previous period)
class ReportComparisonBadge extends StatelessWidget {
  final String label;
  final double? incomeChange;
  final double? expenseChange;
  final bool isDark;

  const ReportComparisonBadge({
    super.key,
    required this.label,
    this.incomeChange,
    this.expenseChange,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: _kReportGold,
            ),
          ),
          const SizedBox(height: 8),
          if (incomeChange != null)
            _ComparisonRow('Income', incomeChange!, true, isDark),
          if (expenseChange != null)
            _ComparisonRow('Expense', expenseChange!, false, isDark),
        ],
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  final String label;
  final double change;
  final bool isIncome;
  final bool isDark;

  const _ComparisonRow(this.label, this.change, this.isIncome, this.isDark);

  @override
  Widget build(BuildContext context) {
    final good = isIncome ? change > 0 : change < 0;
    final color = good ? _kIncomeGreen : _kExpenseRed;
    final arrow = change > 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
          Icon(arrow, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '${change.abs().toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Period navigator with prev/next arrows
class ReportPeriodNavigator extends StatelessWidget {
  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback? onToday;
  final bool isDark;

  const ReportPeriodNavigator({
    super.key,
    required this.label,
    required this.onPrev,
    required this.onNext,
    this.onToday,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, size: 22),
            onPressed: () {
              HapticFeedback.selectionClick();
              onPrev();
            },
            color: _kReportGold,
            splashRadius: 20,
          ),
          Expanded(
            child: GestureDetector(
              onTap: onToday,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, size: 22),
            onPressed: () {
              HapticFeedback.selectionClick();
              onNext();
            },
            color: _kReportGold,
            splashRadius: 20,
          ),
        ],
      ),
    );
  }
}

/// Section card wrapper for report content
class ReportSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final bool isDark;

  const ReportSectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: _kReportGold),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
