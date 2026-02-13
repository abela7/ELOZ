import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../data/models/task.dart';

/// Daily Points Chart Widget
/// Shows a simple bar chart for the last 7 days
class DailyPointsChart extends StatelessWidget {
  final List<Task> tasks;
  
  const DailyPointsChart({
    super.key,
    required this.tasks,
  });

  Map<String, int> _calculateDailyPoints() {
    final now = DateTime.now();
    final Map<String, int> dailyPoints = {};
    
    // Initialize last 7 days
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dayKey = DateFormat('EEE').format(date);
      dailyPoints[dayKey] = 0;
    }
    
    // Calculate points for completed tasks
    for (final task in tasks) {
      if (task.status == 'completed' && task.completedAt != null) {
        final completedDate = task.completedAt!;
        final dayKey = DateFormat('EEE').format(completedDate);
        final daysDiff = now.difference(completedDate).inDays;
        
        if (daysDiff >= 0 && daysDiff < 7) {
          dailyPoints[dayKey] = (dailyPoints[dayKey] ?? 0) + (task.pointsEarned > 0 ? task.pointsEarned : 0);
        }
      }
    }
    
    return dailyPoints;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dailyPoints = _calculateDailyPoints();
    
    // Create ordered list for last 7 days
    final now = DateTime.now();
    final List<Map<String, dynamic>> chartData = [];
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dayKey = DateFormat('EEE').format(date);
      chartData.add({
        'day': dayKey,
        'points': dailyPoints[dayKey] ?? 0,
      });
    }

    final maxPoints = chartData.isEmpty 
        ? 1 
        : chartData.map((e) => e['points'] as int).reduce((a, b) => a > b ? a : b);
    final maxPointsForDisplay = maxPoints == 0 ? 10 : maxPoints;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: chartData.map((data) {
        final points = data['points'] as int;
        final day = data['day'] as String;
        
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Points text above bar
                Text(
                  '$points',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: points > 0 ? (isDark ? Colors.white : Colors.black) : Colors.grey.withOpacity(0.5),
                        fontWeight: FontWeight.w700,
                        fontSize: 9,
                      ),
                ),
                const SizedBox(height: 4),
                // The Bar
                Container(
                  width: 20,
                  height: maxPointsForDisplay > 0 
                      ? ((points / maxPointsForDisplay) * 100).clamp(4.0, 100.0) 
                      : 4.0,
                  decoration: BoxDecoration(
                    color: points > 0 
                        ? const Color(0xFFCDAF56) 
                        : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                // Day label
                Text(
                  day,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

