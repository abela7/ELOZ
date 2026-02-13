import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../data/models/task.dart';
import '../providers/task_providers.dart';

/// Productivity Line Chart Widget - Shows real task completion data
/// Shows a line chart for productivity over the last 7 days
class ProductivityLineChart extends ConsumerWidget {
  const ProductivityLineChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Use select to only rebuild when tasks data changes, not on any state change
    final tasksAsync = ref.watch(taskNotifierProvider.select((value) => value.value));
    
    if (tasksAsync == null) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return _buildChart(context, isDark, tasksAsync);
  }

  Widget _buildChart(BuildContext context, bool isDark, List<Task> tasks) {
    final now = DateTime.now();
    final List<Map<String, dynamic>> chartData = [];
    
    // Calculate productivity for last 7 days
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateOnly = DateTime(date.year, date.month, date.day);
      
      // Get tasks for this date
      final dayTasks = tasks.where((task) {
        if (task.dueDate.year == dateOnly.year &&
            task.dueDate.month == dateOnly.month &&
            task.dueDate.day == dateOnly.day) {
          return true;
        }
        // Also check completed tasks
        if (task.status == 'completed' && task.completedAt != null) {
          final completedDate = DateTime(
            task.completedAt!.year,
            task.completedAt!.month,
            task.completedAt!.day,
          );
          return completedDate == dateOnly;
        }
        return false;
      }).toList();
      
      final total = dayTasks.length;
      final completed = dayTasks.where((t) => t.status == 'completed').length;
      final productivity = total > 0 ? ((completed / total) * 100).round() : 0;
      
      final dayName = DateFormat('EEE').format(date);
      chartData.add({
        'day': dayName,
        'value': productivity,
      });
    }

    final maxValue = chartData.isEmpty 
        ? 100 
        : chartData.map((e) => e['value'] as int).reduce((a, b) => a > b ? a : b);
    final chartHeight = 150.0;

    return Card(
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.15),
      color: isDark ? const Color(0xFF2D3139) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Productivity Trend (Last 7 Days)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: chartHeight + 50, // Add extra height for labels
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: chartData.asMap().entries.map((entry) {
                  final data = entry.value;
                  final value = data['value'] as int;
                  final day = data['day'] as String;
                  final height = maxValue > 0 ? (value / maxValue) * chartHeight : 0.0;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Line chart point
                          Container(
                            height: height.clamp(20.0, chartHeight),
                            width: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFCDAF56), // Gold accent
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Flexible(
                            child: Text(
                              day,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                    fontSize: 10,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Flexible(
                            child: Text(
                              '$value%',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: isDark ? Colors.white : Colors.black,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 10,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
