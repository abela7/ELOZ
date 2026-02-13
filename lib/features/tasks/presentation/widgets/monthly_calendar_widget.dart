import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../data/models/task.dart';

/// Monthly Calendar Widget - Full month calendar view
class MonthlyCalendarWidget extends StatelessWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;
  final List<Task>? tasks; // Optional: tasks to show counts on calendar

  const MonthlyCalendarWidget({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    this.tasks,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final firstDayOfMonth = DateTime(selectedDate.year, selectedDate.month, 1);
    final lastDayOfMonth = DateTime(selectedDate.year, selectedDate.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    final firstWeekday = firstDayOfMonth.weekday; // 1 = Monday, 7 = Sunday

    // Generate calendar days
    final List<DateTime> calendarDays = [];
    
    // Add empty cells for days before the first day of month
    for (int i = 1; i < firstWeekday; i++) {
      calendarDays.add(DateTime(selectedDate.year, selectedDate.month, 0 - (firstWeekday - i - 1)));
    }
    
    // Add all days of the month
    for (int i = 1; i <= daysInMonth; i++) {
      calendarDays.add(DateTime(selectedDate.year, selectedDate.month, i));
    }

    return Card(
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.15),
      color: isDark ? const Color(0xFF2D3139) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('MMMM yyyy').format(selectedDate),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
            ),
            const SizedBox(height: 20),
            // Weekday headers
            Row(
              children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((day) {
                return Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            // Calendar grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: calendarDays.length,
              itemBuilder: (context, index) {
                final day = calendarDays[index];
                final isCurrentMonth = day.month == selectedDate.month;
                final isToday = day.day == DateTime.now().day &&
                    day.month == DateTime.now().month &&
                    day.year == DateTime.now().year;
                final isSelected = day.day == selectedDate.day &&
                    day.month == selectedDate.month &&
                    day.year == selectedDate.year;

                // Calculate real task count for this day
                int taskCount = 0;
                if (tasks != null && isCurrentMonth) {
                  taskCount = tasks!.where((task) {
                    final taskDate = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
                    final dayDate = DateTime(day.year, day.month, day.day);
                    return taskDate == dayDate;
                  }).length;
                }

                return InkWell(
                  onTap: () => onDateSelected(day),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFCDAF56).withOpacity(0.3)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isToday
                            ? const Color(0xFFCDAF56)
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${day.day}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: isCurrentMonth
                                    ? (isDark ? Colors.white : Colors.black)
                                    : Colors.grey.withOpacity(0.5),
                                fontWeight: isToday || isSelected
                                    ? FontWeight.w700
                                    : FontWeight.normal,
                              ),
                        ),
                        if (taskCount > 0 && isCurrentMonth)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFCDAF56),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

