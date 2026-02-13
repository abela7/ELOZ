import 'package:flutter/material.dart';

import 'habit_report_screen.dart';

/// Dedicated report screen for quit/bad habits.
class QuitHabitReportScreen extends StatelessWidget {
  final DateTime? initialDate;

  const QuitHabitReportScreen({super.key, this.initialDate});

  @override
  Widget build(BuildContext context) {
    return HabitReportScreen(
      initialDate: initialDate,
      onlyQuitHabits: true,
      titleOverride: 'Quit Habit Report',
      subtitleOverride: 'Win, slip, and temptation analytics',
    );
  }
}
