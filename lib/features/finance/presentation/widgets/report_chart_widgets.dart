import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../data/services/finance_report_models.dart';

const Color _kGold = Color(0xFFCDAF56);
const Color _kIncomeGreen = Color(0xFF4CAF50);
const Color _kExpenseRed = Color(0xFFFF5252);

/// Grouped bar chart (e.g. income + expense per day/week/month)
class ReportBarChart extends StatelessWidget {
  final List<BarChartGroup> groups;
  final List<String> labels;
  final bool showIncome;
  final bool showExpense;
  final double? maxY;
  final bool isDark;

  const ReportBarChart({
    super.key,
    required this.groups,
    required this.labels,
    this.showIncome = true,
    this.showExpense = true,
    this.maxY,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) return const SizedBox.shrink();

    var maxVal = maxY ?? 0.0;
    if (maxVal <= 0) {
      for (final g in groups) {
        final total = (g.income ?? 0) + (g.expense ?? 0);
        if (total > maxVal) maxVal = total;
      }
      maxVal = maxVal > 0 ? maxVal * 1.2 : 1;
    }

    final barGroups = groups.asMap().entries.map((e) {
      final i = e.key;
      final g = e.value;
      final rods = <BarChartRodData>[];
      if (showIncome && (g.income ?? 0) > 0) {
        rods.add(BarChartRodData(
          toY: g.income!,
          color: _kIncomeGreen,
          width: 10,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        ));
      }
      if (showExpense && (g.expense ?? 0) > 0) {
        rods.add(BarChartRodData(
          toY: g.expense!,
          color: _kExpenseRed,
          width: 10,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        ));
      }
      if (rods.isEmpty) {
        rods.add(BarChartRodData(toY: 0.01, color: Colors.transparent, width: 10));
      }
      return BarChartGroupData(
        x: i,
        barRods: rods,
        barsSpace: 4,
        showingTooltipIndicators: [],
      );
    }).toList();

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxVal,
          minY: 0,
          barGroups: barGroups,
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (val, meta) {
                  if (val == 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      val.abs() >= 1000
                          ? '${(val / 1000).toStringAsFixed(1)}k'
                          : val.abs().toStringAsFixed(0),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, meta) {
                  final i = val.toInt();
                  if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxVal / 4,
            getDrawingHorizontalLine: (_) => FlLine(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }
}

/// Data for a single bar group
class BarChartGroup {
  final double? income;
  final double? expense;

  const BarChartGroup({this.income, this.expense});
}

/// Line chart for balance/trend
class ReportLineChart extends StatelessWidget {
  final List<double> values;
  final List<String>? labels;
  final Color? lineColor;
  final bool isDark;

  const ReportLineChart({
    super.key,
    required this.values,
    this.labels,
    this.lineColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();

    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final minVal = values.reduce((a, b) => a < b ? a : b);
    final range = (maxVal - minVal).abs();
    final padding = range > 0 ? range * 0.1 : 1;

    final spots = values.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    final color = lineColor ?? _kGold;

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (values.length - 1).toDouble(),
          minY: minVal - padding,
          maxY: maxVal + padding,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: color,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: color.withOpacity(0.15),
              ),
            ),
          ],
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (val, meta) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    val >= 1000 ? '${(val / 1000).toStringAsFixed(1)}k' : val.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ),
              ),
            ),
            bottomTitles: labels != null
                ? AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        final i = val.toInt();
                        if (i < 0 || i >= labels!.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            labels![i],
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        );
                      },
                    ),
                  )
                : const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }
}

/// Pie chart for category breakdown
class ReportPieChart extends StatelessWidget {
  final List<ReportCategoryItem> items;
  final double total;
  final bool isDark;

  const ReportPieChart({
    super.key,
    required this.items,
    required this.total,
    required this.isDark,
  });

  static const List<Color> _kChartColors = [
    Color(0xFFCDAF56),
    Color(0xFF4CAF50),
    Color(0xFFFF5252),
    Color(0xFF2196F3),
    Color(0xFF9C27B0),
    Color(0xFFFF9800),
    Color(0xFF00BCD4),
    Color(0xFF795548),
  ];

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty || total <= 0) return const SizedBox.shrink();

    final sections = items.asMap().entries.map((e) {
      final i = e.key;
      final item = e.value;
      final color = _kChartColors[i % _kChartColors.length];
      return PieChartSectionData(
        value: item.amount,
        title: '',
        color: color,
        radius: 24,
        showTitle: false,
      );
    }).toList();

    return SizedBox(
      height: 220,
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: PieChart(
              PieChartData(
                sections: sections,
                sectionsSpace: 4,
                centerSpaceRadius: 40,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 5,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items.asMap().entries.map((e) {
                final i = e.key;
                final item = e.value;
                final color = _kChartColors[i % _kChartColors.length];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.categoryName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${item.percentage.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Category ranking with horizontal bars
class ReportCategoryRanking extends StatelessWidget {
  final List<ReportCategoryItem> items;
  final String currencySymbol;
  final int maxItems;
  final bool isDark;

  const ReportCategoryRanking({
    super.key,
    required this.items,
    required this.currencySymbol,
    this.maxItems = 10,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final display = items.take(maxItems).toList();
    final maxAmount = display.isEmpty ? 1.0 : display.first.amount;

    return Column(
      children: display.map((item) {
        final pct = maxAmount > 0 ? (item.amount / maxAmount) : 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.categoryName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '$currencySymbol${item.amount.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: (isDark ? Colors.white : Colors.black).withOpacity(0.08),
                  valueColor: AlwaysStoppedAnimation(_kGold),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// Budget progress bar
class ReportBudgetProgress extends StatelessWidget {
  final String name;
  final double limit;
  final double spent;
  final bool isExceeded;
  final String currencySymbol;
  final bool isDark;

  const ReportBudgetProgress({
    super.key,
    required this.name,
    required this.limit,
    required this.spent,
    required this.isExceeded,
    required this.currencySymbol,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final pct = limit > 0 ? (spent / limit).clamp(0.0, 1.5) : 0.0;
    Color barColor;
    if (isExceeded) {
      barColor = _kExpenseRed;
    } else if (pct >= 0.8) {
      barColor = Colors.amber;
    } else {
      barColor = _kIncomeGreen;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '$currencySymbol${spent.toStringAsFixed(0)} / $currencySymbol${limit.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: (isDark ? Colors.white : Colors.black).withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
        ],
      ),
    );
  }
}
