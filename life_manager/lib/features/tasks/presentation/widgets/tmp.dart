import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Reusable Date Navigator Widget
/// Used for date navigation with previous/next arrows and calendar picker
class DateNavigatorWidget extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;

  const DateNavigatorWidget({
    super.key,
    required this.selectedDate,
    required this.onDateChanged,
  });

  /// Formats the date text (e.g., "Today — Nov 24" or "Mon — Nov 24")
  String _formatDateText(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(date.year, date.month, date.day);

    if (selected == today) {
      return 'Today — ${DateFormat('MMM d').format(date)}';
    } else if (selected == today.subtract(const Duration(days: 1))) {
      return 'Yesterday — ${DateFormat('MMM d').format(date)}';
    } else if (selected == today.add(const Duration(days: 1))) {
      return 'Tomorrow — ${DateFormat('MMM d').format(date)}';
    } else {
      return '${DateFormat('EEE').format(date)} — ${DateFormat('MMM d').format(date)}';
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (context) => _ModernDatePickerDialog(
        initialDate: selectedDate,
        firstDate: DateTime.now().subtract(const Duration(days: 365 * 10)), // 10 years back
        lastDate: DateTime.now().add(const Duration(days: 365 * 10)), // 10 years forward
      ),
    );
    
    if (picked != null && picked != selectedDate) {
      onDateChanged(picked);
    }
  }

  void _goToPreviousDay() {
    onDateChanged(selectedDate.subtract(const Duration(days: 1)));
  }

  void _goToNextDay() {
    onDateChanged(selectedDate.add(const Duration(days: 1)));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF10141C), // Dark background as specified
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Left arrow - Previous day
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded),
            onPressed: _goToPreviousDay,
            color: const Color(0xFFCDAF56), // Gold accent
            iconSize: 20,
          ),
          
          // Center date text
          Expanded(
            child: Center(
              child: Text(
                _formatDateText(selectedDate),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
              ),
            ),
          ),
          
          // Right arrow - Next day
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios_rounded),
            onPressed: _goToNextDay,
            color: const Color(0xFFCDAF56), // Gold accent
            iconSize: 20,
          ),
          
          // Calendar icon - Open date picker
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded),
            onPressed: () => _selectDate(context),
            color: const Color(0xFFCDAF56), // Gold accent
            iconSize: 24,
          ),
        ],
      ),
    );
  }
}

/// Custom Modern Date Picker Dialog following the app's premium theme
class _ModernDatePickerDialog extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  const _ModernDatePickerDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<_ModernDatePickerDialog> createState() => _ModernDatePickerDialogState();
}

class _ModernDatePickerDialogState extends State<_ModernDatePickerDialog> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = const Color(0xFFCDAF56);
    final backgroundColor = isDark ? const Color(0xFF1A1D23) : Colors.white;
    final headerColor = isDark ? const Color(0xFF10141C) : const Color(0xFFF8F8F8);
    
    return Dialog(
      backgroundColor: backgroundColor,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 350),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Premium Header with Animation
            Container(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              decoration: BoxDecoration(
                color: headerColor,
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.calendar_today_rounded, color: accentColor, size: 14),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'SELECT DATE',
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.1),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: Text(
                      DateFormat('EEEE, MMM d').format(_selectedDate),
                      key: ValueKey(_selectedDate),
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Calendar Body with enhanced theming
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.fromSeed(
                      seedColor: accentColor,
                      primary: accentColor,
                      onPrimary: Colors.black,
                      surface: backgroundColor,
                      onSurface: isDark ? Colors.white : Colors.black,
                      brightness: isDark ? Brightness.dark : Brightness.light,
                    ),
                    textTheme: TextTheme(
                      bodyMedium: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  child: CalendarDatePicker(
                    initialDate: _selectedDate,
                    firstDate: widget.firstDate,
                    lastDate: widget.lastDate,
                    onDateChanged: (date) {
                      setState(() => _selectedDate = date);
                    },
                  ),
                ),
              ),
            ),
            
            // Modern Action Row
            Container(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Row(
                children: [
                  // Clean "Today" Action
                  Material(
                    color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: () {
                        final now = DateTime.now();
                        Navigator.of(context).pop(DateTime(now.year, now.month, now.day));
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Text(
                          'Today',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: isDark ? Colors.white60 : Colors.black54,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Text(
                      'CANCEL', 
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 1)
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(_selectedDate),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text(
                      'CONFIRM', 
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
