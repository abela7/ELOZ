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
    final headerColor = isDark ? const Color(0xFF10141C) : const Color(0xFFF5F5F5);
    
    return Dialog(
      backgroundColor: backgroundColor,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Premium Header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              color: headerColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SELECT DATE',
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          DateFormat('EEE, MMM d').format(_selectedDate),
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.calendar_today_rounded, 
                        color: accentColor.withOpacity(0.4), 
                        size: 24
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Calendar Body with custom theme
            Flexible(
              child: Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: accentColor,
                    primary: accentColor,
                    onPrimary: isDark ? Colors.black : Colors.white,
                    surface: backgroundColor,
                    onSurface: isDark ? Colors.white : Colors.black,
                    brightness: isDark ? Brightness.dark : Brightness.light,
                  ),
                  textTheme: TextTheme(
                    bodyMedium: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w500,
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
            
            // Modern Actions Row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  // Elegant "Today" Chip-style Button
                  Material(
                    color: accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () {
                        final now = DateTime.now();
                        Navigator.of(context).pop(DateTime(now.year, now.month, now.day));
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.today_rounded, color: accentColor, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Today',
                              style: TextStyle(
                                color: accentColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: isDark ? Colors.grey[400] : Colors.grey[600],
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Text(
                      'CANCEL', 
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.8)
                    ),
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(_selectedDate),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'OK', 
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.8)
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
