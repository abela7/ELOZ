import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../data/models/task.dart';
import '../providers/task_providers.dart';

/// Task Heatmap Widget - Shows real task activity data
/// Shows a monthly heatmap visualization
class TaskHeatmap extends ConsumerWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;

  const TaskHeatmap({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Use select to only rebuild when tasks data changes, not on any state change
    final tasksAsync = ref.watch(taskNotifierProvider.select((value) => value.value));
    
    if (tasksAsync == null) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return _buildHeatmap(context, isDark, tasksAsync);
  }

  Widget _buildHeatmap(BuildContext context, bool isDark, List<Task> tasks) {
    final now = selectedDate;
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    
    // Count net points per day for robust analysis
    final Map<int, int> dailyPoints = {};
    for (final task in tasks) {
      // Consider all tasks with a due date in this month
      // This includes completed, postponed, and failed tasks
      final taskDate = task.status == 'completed' && task.completedAt != null 
          ? task.completedAt! 
          : task.dueDate;
          
      if (taskDate.year == now.year && taskDate.month == now.month) {
        final day = taskDate.day;
        dailyPoints[day] = (dailyPoints[day] ?? 0) + task.pointsEarned;
      }
    }
    
    // Generate data for all days in month
    final List<int> heatmapData = List.generate(
      daysInMonth,
      (index) => dailyPoints[index + 1] ?? 0,
    );
    
    // Find max positive points for normalization
    final maxPoints = heatmapData.isEmpty 
        ? 1 
        : heatmapData.where((p) => p > 0).fold(1, (max, p) => p > max ? p : max);
    
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
              'Robust Activity Heatmap (${DateFormat('MMMM yyyy').format(now)})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: heatmapData.asMap().entries.map((entry) {
                final day = entry.key + 1;
                final points = entry.value;
                final isSelected = day == selectedDate.day;
                
                // Color intensity based on activity level and point balance
                Color getColor() {
                  if (points == 0) return Colors.grey.withOpacity(0.1);
                  if (points < 0) return Colors.redAccent.withOpacity(0.3); // Penalty day
                  
                  // Positive intensity
                  final intensity = ((points / maxPoints) * 4).round().clamp(1, 4);
                  switch (intensity) {
                    case 1:
                      return const Color(0xFFCDAF56).withOpacity(0.3);
                    case 2:
                      return const Color(0xFFCDAF56).withOpacity(0.5);
                    case 3:
                      return const Color(0xFFCDAF56).withOpacity(0.8);
                    case 4:
                      return const Color(0xFFCDAF56);
                    default:
                      return Colors.grey.withOpacity(0.1);
                  }
                }

                return Tooltip(
                  message: 'Day $day: $points points',
                  child: GestureDetector(
                    onTap: () {
                      final clickedDate = DateTime(selectedDate.year, selectedDate.month, day);
                      onDateSelected(clickedDate);
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: getColor(),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected 
                              ? const Color(0xFFCDAF56) 
                              : (points < 0 ? Colors.red.withOpacity(0.3) : Colors.white.withOpacity(0.05)),
                          width: isSelected ? 2.0 : 0.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$day',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: points != 0 ? Colors.white : Colors.grey[600],
                                fontSize: 9,
                                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                              ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _LegendItem(
                  color: Colors.redAccent.withOpacity(0.3),
                  label: 'Penalty',
                  isDark: isDark,
                ),
                const SizedBox(width: 12),
                _LegendItem(
                  color: const Color(0xFFCDAF56).withOpacity(0.3),
                  label: 'Low',
                  isDark: isDark,
                ),
                const SizedBox(width: 12),
                _LegendItem(
                  color: const Color(0xFFCDAF56),
                  label: 'High',
                  isDark: isDark,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Legend item widget for heatmap
class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool isDark;

  const _LegendItem({
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
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 0.5,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 10,
              ),
        ),
      ],
    );
  }
}
