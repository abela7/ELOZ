import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../data/models/task.dart';

/// Updates the Android home-screen widget with today's tasks.
/// This writes a compact summary (title, subtitle, up to 3 tasks) that the
/// native layout reads via SharedPreferences.
Future<void> updateTodayHomeWidget({
  required List<Task> tasks,
}) async {
  try {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final todayTasks = tasks.where((t) {
      final d = DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day);
      return d == today;
    }).toList();

    final completed = todayTasks.where((t) => t.status == 'completed').length;
    final pending = todayTasks.where((t) => t.status == 'pending').length;
    final overdue = todayTasks
        .where((t) => t.isOverdue && t.status != 'completed' && t.status != 'not_done')
        .length;

    final subtitle =
        '${DateFormat('EEE, MMM d').format(today)} • $pending pending • $completed done${overdue > 0 ? ' • $overdue overdue' : ''}';

    // Save to SharedPreferences that the native widget reads
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('title', "Today's Tasks");
    await prefs.setString('subtitle', subtitle);

    // Serialize up to 3 tasks
    final items = todayTasks.take(3).map(_serializeTask).toList();
    for (var i = 0; i < 3; i++) {
      final key = 'task_$i';
      await prefs.setString(key, i < items.length ? items[i] : '');
    }

    // Trigger widget update via platform channel
    const platform = MethodChannel('com.eloz.life_manager/widget');
    await platform.invokeMethod('updateWidget');
  } catch (e) {
    debugPrint('Home widget update failed: $e');
  }
}

String _serializeTask(Task task) {
  final hasTime = task.dueTimeHour != null && task.dueTimeMinute != null;
  final timeLabel = hasTime
      ? DateFormat('h:mm a').format(DateTime(
          task.dueDate.year,
          task.dueDate.month,
          task.dueDate.day,
          task.dueTimeHour!,
          task.dueTimeMinute!,
        ))
      : 'All day';

  final priority = task.priority ?? 'Medium';
  final tag = (task.tags != null && task.tags!.isNotEmpty) ? '#${task.tags!.first}' : '';

  // Compact one-liner: Title • time • priority • tag
  final parts = [
    task.title,
    timeLabel,
    priority,
    if (tag.isNotEmpty) tag,
  ];

  return parts.join(' • ');
}

