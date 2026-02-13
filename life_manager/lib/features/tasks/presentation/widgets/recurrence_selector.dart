import 'package:flutter/material.dart';
import 'custom_recurrence_sheet.dart';

/// Recurrence Selector Widget - UI for configuring recurring tasks
class RecurrenceSelector extends StatefulWidget {
  const RecurrenceSelector({super.key});

  @override
  State<RecurrenceSelector> createState() => _RecurrenceSelectorState();
}

class _RecurrenceSelectorState extends State<RecurrenceSelector> {
  String? _selectedRepeat; // None, Daily, Weekly, Monthly, Custom
  Map<String, dynamic>? _customRecurrenceData;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF10141C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Repeat',
            style: textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedRepeat,
            decoration: InputDecoration(
              hintText: 'Select repeat option',
              filled: true,
              fillColor: isDark ? Colors.black.withOpacity(0.4) : Colors.grey[200],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFCDAF56), width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            ),
            dropdownColor: isDark ? const Color(0xFF2D3139) : Colors.white,
            icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFFCDAF56)),
            items: ['None', 'Daily', 'Weekly', 'Monthly', 'Custom…'].map((option) {
              return DropdownMenuItem(
                value: option,
                child: Text(
                  option,
                  style: textTheme.bodyLarge?.copyWith(
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedRepeat = value;
                if (value == 'Custom…') {
                  _showCustomRecurrenceSheet(context);
                } else {
                  _customRecurrenceData = null;
                }
              });
            },
          ),
        ],
      ),
    );
  }

  void _showCustomRecurrenceSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CustomRecurrenceSheet(
        initialFrequency: _customRecurrenceData?['frequency'] ?? 1,
        initialUnit: _customRecurrenceData?['unit'] ?? 'days',
        initialStartDate: _customRecurrenceData?['startDate'] as DateTime?,
        initialEndCondition: _customRecurrenceData?['endCondition'] ?? 'Never',
        initialEndDate: _customRecurrenceData?['endDate'] as DateTime?,
        initialOccurrences: _customRecurrenceData?['occurrences'] ?? 5,
        initialSkipWeekends: _customRecurrenceData?['skipWeekends'] ?? false,
      ),
    ).then((result) {
      if (result != null) {
        setState(() {
          _customRecurrenceData = result as Map<String, dynamic>;
        });
      } else {
        // If user cancelled, reset to None
        setState(() {
          _selectedRepeat = null;
          _customRecurrenceData = null;
        });
      }
    });
  }
}
