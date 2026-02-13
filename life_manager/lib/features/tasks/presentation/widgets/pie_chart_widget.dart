import 'package:flutter/material.dart';

/// Pie Chart Widget - Placeholder UI only
/// Shows a pie chart with Done/Postponed/Failed segments
class PieChartWidget extends StatelessWidget {
  final int completed;
  final int postponed;
  final int failed;

  const PieChartWidget({
    super.key,
    required this.completed,
    required this.postponed,
    required this.failed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = completed + postponed + failed;
    
    if (total == 0) {
      return Card(
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.15),
        color: isDark ? const Color(0xFF2D3139) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: const Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: Text('No data available')),
        ),
      );
    }

    final completedPercent = (completed / total) * 100;
    final postponedPercent = (postponed / total) * 100;
    final failedPercent = (failed / total) * 100;

    return Card(
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.15),
      color: isDark ? const Color(0xFF2D3139) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Task Breakdown',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                // Pie chart visualization (simplified as circles)
                Expanded(
                  child: Column(
                    children: [
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Completed (Green) - largest segment
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: const Color(0xFF4CAF50).withOpacity(0.3),
                                shape: BoxShape.circle,
                              ),
                            ),
                            // Postponed (Gold) - medium segment
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: const Color(0xFFCDAF56).withOpacity(0.3),
                                shape: BoxShape.circle,
                              ),
                            ),
                            // Failed (Red) - smallest segment
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.3),
                                shape: BoxShape.circle,
                              ),
                            ),
                            // Center text
                            Text(
                              '$total',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Legend
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LegendItem(
                        color: const Color(0xFF4CAF50),
                        label: 'Done',
                        value: '$completed (${completedPercent.toStringAsFixed(0)}%)',
                        isDark: isDark,
                      ),
                      const SizedBox(height: 12),
                      _LegendItem(
                        color: const Color(0xFFCDAF56),
                        label: 'Postponed',
                        value: '$postponed (${postponedPercent.toStringAsFixed(0)}%)',
                        isDark: isDark,
                      ),
                      const SizedBox(height: 12),
                      _LegendItem(
                        color: Colors.red,
                        label: 'Failed',
                        value: '$failed (${failedPercent.toStringAsFixed(0)}%)',
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  final bool isDark;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

