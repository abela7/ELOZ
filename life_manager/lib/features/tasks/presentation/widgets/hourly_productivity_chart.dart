import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/models/task.dart';
import '../providers/task_providers.dart';

/// Hourly Productivity Chart Widget - Shows real task completion data
/// Shows productivity by hour of the day FOR THE SELECTED DATE
/// Supports pinch-to-zoom to expand/shrink the time axis
class HourlyProductivityChart extends ConsumerStatefulWidget {
  final DateTime selectedDate;
  
  const HourlyProductivityChart({
    super.key,
    required this.selectedDate,
  });

  @override
  ConsumerState<HourlyProductivityChart> createState() => _HourlyProductivityChartState();
}

class _HourlyProductivityChartState extends ConsumerState<HourlyProductivityChart> {
  double _scale = 1.0;
  double _baseScale = 1.0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tasksAsync = ref.watch(taskNotifierProvider.select((value) => value.value));
    
    if (tasksAsync == null) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return _buildChart(context, isDark, tasksAsync);
  }

  Widget _buildChart(BuildContext context, bool isDark, List<Task> tasks) {
    // FILTER: Only get completed tasks for the selected date
    final tasksForDate = tasks.where((task) {
      if (task.status != 'completed' || task.completedAt == null) return false;
      
      final completedDate = task.completedAt!;
      return completedDate.year == widget.selectedDate.year &&
             completedDate.month == widget.selectedDate.month &&
             completedDate.day == widget.selectedDate.day;
    }).toList();
    
    // Count completed tasks by hour (Full 24 hours)
    final Map<int, int> hourlyCounts = {};
    for (int hour = 0; hour <= 23; hour++) {
      hourlyCounts[hour] = 0;
    }
    
    for (final task in tasksForDate) {
      final hour = task.completedAt!.hour;
      if (hour >= 0 && hour <= 23) {
        hourlyCounts[hour] = (hourlyCounts[hour] ?? 0) + 1;
      }
    }
    
    // Convert to list format
    final List<Map<String, dynamic>> hourlyData = [];
    for (int hour = 0; hour <= 23; hour++) {
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      final hourLabel = '$displayHour $period';
      hourlyData.add({
        'hour': hourLabel,
        'value': hourlyCounts[hour] ?? 0,
      });
    }

    final maxValue = hourlyData.isEmpty 
        ? 1 
        : hourlyData.map((e) => e['value'] as int).reduce((a, b) => a > b ? a : b);
    
    final normalizedMaxValue = maxValue < 3 ? 3 : maxValue;
    final chartHeight = 200.0;
    
    // Zoomable dimensions
    final barWidth = 40.0 * _scale;
    final barPadding = 12.0 * _scale;
    final labelWidth = 50.0 * _scale;

    return Card(
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.15),
      color: isDark ? const Color(0xFF2D3139) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Productivity by Hour',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 18,
                      ),
                ),
                if (tasksForDate.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCDAF56).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${tasksForDate.length} tasks',
                      style: const TextStyle(
                        color: Color(0xFFCDAF56),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Pinch to zoom time axis',
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white38 : Colors.black38,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onScaleStart: (details) {
                _baseScale = _scale;
              },
              onScaleUpdate: (details) {
                setState(() {
                  _scale = (_baseScale * details.horizontalScale).clamp(0.5, 3.0);
                });
              },
              child: SizedBox(
                height: chartHeight + 60,
                child: tasksForDate.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.bar_chart_rounded,
                              size: 48,
                              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No completions on this day',
                              style: TextStyle(
                                color: isDark ? Colors.grey[600] : Colors.grey[400],
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: hourlyData.map((data) {
                            final value = data['value'] as int;
                            final hour = data['hour'] as String;
                            final height = value > 0 
                                ? ((value / normalizedMaxValue) * chartHeight).clamp(12.0, chartHeight)
                                : 12.0;

                            return Padding(
                              padding: EdgeInsets.symmetric(horizontal: barPadding),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (value > 0)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Text(
                                        '$value',
                                        style: TextStyle(
                                          color: const Color(0xFFCDAF56),
                                          fontSize: (12 * _scale).clamp(8.0, 16.0),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  Container(
                                    width: barWidth,
                                    height: height,
                                    decoration: BoxDecoration(
                                      gradient: value > 0 
                                          ? LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                const Color(0xFFCDAF56),
                                                const Color(0xFFCDAF56).withOpacity(0.7),
                                              ],
                                            )
                                          : null,
                                      color: value > 0 
                                          ? null 
                                          : (isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03)),
                                      borderRadius: BorderRadius.circular(8 * _scale).copyWith(
                                        topLeft: const Radius.circular(8),
                                        topRight: const Radius.circular(8),
                                      ),
                                      boxShadow: value > 0 ? [
                                        BoxShadow(
                                          color: const Color(0xFFCDAF56).withOpacity(0.3),
                                          blurRadius: 8 * _scale,
                                          offset: Offset(0, 4 * _scale),
                                        ),
                                      ] : null,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: labelWidth,
                                    child: Text(
                                      hour,
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                                            fontSize: (10 * _scale).clamp(7.0, 14.0),
                                            fontWeight: value > 0 ? FontWeight.bold : FontWeight.normal,
                                          ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.visible,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
