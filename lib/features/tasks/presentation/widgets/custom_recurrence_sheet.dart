import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Custom Recurrence Bottom Sheet - For configuring custom recurrence patterns
class CustomRecurrenceSheet extends StatefulWidget {
  final int initialFrequency;
  final String initialUnit;
  final DateTime? initialStartDate;
  final String initialEndCondition;
  final DateTime? initialEndDate;
  final int initialOccurrences;
  final bool initialSkipWeekends;

  const CustomRecurrenceSheet({
    super.key,
    this.initialFrequency = 1,
    this.initialUnit = 'days',
    this.initialStartDate,
    this.initialEndCondition = 'Never',
    this.initialEndDate,
    this.initialOccurrences = 5,
    this.initialSkipWeekends = false,
  });

  @override
  State<CustomRecurrenceSheet> createState() => _CustomRecurrenceSheetState();
}

class _CustomRecurrenceSheetState extends State<CustomRecurrenceSheet> {
  late int _frequency;
  late String _unit;
  late DateTime _startDate;
  late String _endCondition;
  DateTime? _endDate;
  late int _occurrences;
  late bool _skipWeekends;

  late final TextEditingController _frequencyController;
  late final TextEditingController _occurrencesController;

  @override
  void initState() {
    super.initState();
    _frequency = widget.initialFrequency;
    _unit = widget.initialUnit;
    _startDate = widget.initialStartDate ?? DateTime.now();
    _endCondition = widget.initialEndCondition;
    _endDate = widget.initialEndDate;
    _occurrences = widget.initialOccurrences;
    _skipWeekends = widget.initialSkipWeekends;

    _frequencyController = TextEditingController(text: _frequency.toString());
    _occurrencesController = TextEditingController(text: _occurrences.toString());
  }

  @override
  void dispose() {
    _frequencyController.dispose();
    _occurrencesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D3139) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Custom Recurrence',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  color: isDark ? Colors.white : Colors.black,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Repeat Every
            Text(
              'Repeat every',
              style: textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Frequency Number Input
                Expanded(
                  flex: 2,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    controller: _frequencyController,
                    decoration: InputDecoration(
                      hintText: '1',
                      filled: true,
                      fillColor: isDark ? Colors.black.withOpacity(0.4) : Colors.grey[200],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCDAF56), width: 2),
                      ),
                    ),
                    style: textTheme.bodyLarge?.copyWith(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    onChanged: (value) {
                      _frequency = int.tryParse(value) ?? 1;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Unit Dropdown
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black.withOpacity(0.4) : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                    child: DropdownButtonFormField<String>(
                      value: _unit,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        border: InputBorder.none,
                      ),
                      dropdownColor: isDark ? const Color(0xFF2D3139) : Colors.white,
                      icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFFCDAF56)),
                      items: ['days', 'weeks', 'months'].map((unit) {
                        return DropdownMenuItem(
                          value: unit,
                          child: Text(
                            unit,
                            style: textTheme.bodyLarge?.copyWith(
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _unit = value ?? 'days';
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Start Date
            Text(
              'Start date',
              style: textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => _selectStartDate(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black.withOpacity(0.4) : Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, color: Color(0xFFCDAF56), size: 20),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('MMM d, yyyy').format(_startDate),
                      style: textTheme.bodyLarge?.copyWith(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // End Condition
            Text(
              'End condition',
              style: textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Never', label: Text('Never')),
                ButtonSegment(value: 'On specific date', label: Text('End Date')),
                ButtonSegment(value: 'After X occurrences', label: Text('After X')),
              ],
              selected: {_endCondition},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() {
                  _endCondition = newSelection.first;
                });
              },
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: const Color(0xFFCDAF56),
                selectedForegroundColor: const Color(0xFF1E1E1E),
                backgroundColor: isDark ? const Color(0xFF3E4148) : Colors.grey[200],
                foregroundColor: isDark ? Colors.white : Colors.black,
              ),
            ),

            // End Date Picker (shown when "On specific date" is selected)
            if (_endCondition == 'On specific date') ...[
              const SizedBox(height: 16),
              InkWell(
                onTap: () => _selectEndDate(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black.withOpacity(0.4) : Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_rounded, color: Color(0xFFCDAF56), size: 20),
                      const SizedBox(width: 12),
                      Text(
                        _endDate != null
                            ? DateFormat('MMM d, yyyy').format(_endDate!)
                            : 'Select end date',
                        style: textTheme.bodyLarge?.copyWith(
                          color: _endDate != null
                              ? (isDark ? Colors.white : Colors.black)
                              : (isDark ? Colors.grey[400] : Colors.grey[600]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Occurrences Input (shown when "After X occurrences" is selected)
            if (_endCondition == 'After X occurrences') ...[
              const SizedBox(height: 16),
              TextField(
                keyboardType: TextInputType.number,
                controller: _occurrencesController,
                decoration: InputDecoration(
                  labelText: 'Number of occurrences',
                  hintText: '5',
                  filled: true,
                  fillColor: isDark ? Colors.black.withOpacity(0.4) : Colors.grey[200],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFCDAF56), width: 2),
                  ),
                ),
                style: textTheme.bodyLarge?.copyWith(
                  color: isDark ? Colors.white : Colors.black,
                ),
                onChanged: (value) {
                  _occurrences = int.tryParse(value) ?? 5;
                },
              ),
            ],

            const SizedBox(height: 24),

            // Skip Weekends Toggle
            SwitchListTile(
              title: Text(
                'Skip weekends',
                style: textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              subtitle: Text(
                'Don\'t create tasks on Saturday and Sunday',
                style: textTheme.bodySmall?.copyWith(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              value: _skipWeekends,
              onChanged: (value) {
                setState(() {
                  _skipWeekends = value;
                });
              },
              activeColor: const Color(0xFFCDAF56),
              contentPadding: EdgeInsets.zero,
            ),

            const SizedBox(height: 24),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, {
                    'frequency': _frequency,
                    'unit': _unit,
                    'startDate': _startDate,
                    'endCondition': _endCondition,
                    'endDate': _endCondition == 'On specific date' ? _endDate : null,
                    'occurrences': _endCondition == 'After X occurrences' ? _occurrences : null,
                    'skipWeekends': _skipWeekends,
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCDAF56),
                  foregroundColor: const Color(0xFF1E1E1E),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Save',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E1E1E),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate.add(const Duration(days: 30)),
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }
}

