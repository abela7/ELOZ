import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/recurrence_rule.dart';

class RecurrencePickerSheet extends StatefulWidget {
  final RecurrenceRule? initialRule;
  final bool isDark;

  const RecurrencePickerSheet({
    super.key,
    this.initialRule,
    this.isDark = false,
  });

  @override
  State<RecurrencePickerSheet> createState() => _RecurrencePickerSheetState();
}

class _RecurrencePickerSheetState extends State<RecurrencePickerSheet> {
  late String _type;
  late int _interval;
  late int _frequency;
  late String _unit;
  late String _endCondition;
  late DateTime? _endDate;
  late int? _occurrences;
  late List<int> _daysOfWeek;

  final TextEditingController _intervalController = TextEditingController();
  final TextEditingController _frequencyController = TextEditingController();
  final TextEditingController _occurrencesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final rule = widget.initialRule;
    _type = rule?.type ?? 'daily';
    _interval = rule?.interval ?? 1;
    _frequency = rule?.frequency ?? 1;
    _unit = rule?.unit ?? 'days';
    _endCondition = rule?.endCondition ?? 'never';
    _endDate = rule?.endDate;
    _occurrences = rule?.occurrences;
    _daysOfWeek = rule?.daysOfWeek ?? [];

    _intervalController.text = _interval.toString();
    _frequencyController.text = _frequency.toString();
    _occurrencesController.text = _occurrences?.toString() ?? '';
  }

  @override
  void dispose() {
    _intervalController.dispose();
    _frequencyController.dispose();
    _occurrencesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1E1E);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D23) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHandle(isDark),
          const SizedBox(height: 24),
          _buildHeader(isDark, textColor),
          const SizedBox(height: 32),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildFrequencySection(isDark, textColor),
                  const SizedBox(height: 24),
                  _buildPeriodSection(isDark, textColor),
                  const SizedBox(height: 24),
                  if (_type == 'weekly') _buildDaysOfWeekSection(isDark, textColor),
                  const SizedBox(height: 24),
                  _buildEndConditionSection(isDark, textColor),
                  const SizedBox(height: 40),
                  _buildApplyButton(isDark),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandle(bool isDark) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: isDark ? Colors.white12 : Colors.black12,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recurring Payment',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: textColor,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Set up a custom schedule',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ],
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded),
          color: isDark ? Colors.white38 : Colors.black38,
        ),
      ],
    );
  }

  Widget _buildFrequencySection(bool isDark, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('FREQUENCY'),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildNumberInput(
                controller: _frequencyController,
                label: 'Times',
                onChanged: (val) => setState(() => _frequency = int.tryParse(val) ?? 1),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 16),
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Text(
                'per',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildNumberInput(
                controller: _intervalController,
                label: 'Every',
                onChanged: (val) => setState(() => _interval = int.tryParse(val) ?? 1),
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPeriodSection(bool isDark, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('PERIOD'),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildPeriodChip('daily', 'Day', isDark),
            const SizedBox(width: 8),
            _buildPeriodChip('weekly', 'Week', isDark),
            const SizedBox(width: 8),
            _buildPeriodChip('monthly', 'Month', isDark),
            const SizedBox(width: 8),
            _buildPeriodChip('yearly', 'Year', isDark),
          ],
        ),
      ],
    );
  }

  Widget _buildPeriodChip(String type, String label, bool isDark) {
    final isSelected = _type == type;
    final color = const Color(0xFFCDAF56);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _type = type;
            if (type == 'daily') _unit = 'days';
            if (type == 'weekly') _unit = 'weeks';
            if (type == 'monthly') _unit = 'months';
            if (type == 'yearly') _unit = 'years';
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color : (isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? color : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                color: isSelected ? Colors.black87 : (isDark ? Colors.white38 : Colors.black38),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDaysOfWeekSection(bool isDark, Color textColor) {
    final days = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('ON SPECIFIC DAYS'),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (index) {
            final isSelected = _daysOfWeek.contains(index);
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  if (isSelected) {
                    _daysOfWeek.remove(index);
                  } else {
                    _daysOfWeek.add(index);
                  }
                });
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFCDAF56) : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? const Color(0xFFCDAF56) : (isDark ? Colors.white12 : Colors.black12),
                  ),
                ),
                child: Center(
                  child: Text(
                    days[index],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.black : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildEndConditionSection(bool isDark, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('ENDS'),
        const SizedBox(height: 16),
        _buildEndConditionTile('never', 'Never', Icons.all_inclusive, isDark),
        const SizedBox(height: 12),
        _buildEndConditionTile('on_date', 'On specific date', Icons.calendar_today_rounded, isDark),
        const SizedBox(height: 12),
        _buildEndConditionTile('after_occurrences', 'After several times', Icons.numbers_rounded, isDark),
      ],
    );
  }

  Widget _buildEndConditionTile(String condition, String label, IconData icon, bool isDark) {
    final isSelected = _endCondition == condition;
    final color = const Color(0xFFCDAF56);

    return InkWell(
      onTap: () async {
        HapticFeedback.selectionClick();
        if (condition == 'on_date') {
          final picked = await showDatePicker(
            context: context,
            initialDate: _endDate ?? DateTime.now().add(const Duration(days: 30)),
            firstDate: DateTime.now(),
            lastDate: DateTime(2100),
          );
          if (picked != null) {
            setState(() {
              _endCondition = condition;
              _endDate = picked;
            });
          }
        } else {
          setState(() {
            _endCondition = condition;
          });
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.01),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isSelected ? color : (isDark ? Colors.white24 : Colors.black26)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? (isDark ? Colors.white : Colors.black87) : (isDark ? Colors.white38 : Colors.black38),
                ),
              ),
            ),
            if (condition == 'on_date' && _endDate != null)
              Text(
                '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
              ),
            if (condition == 'after_occurrences')
              SizedBox(
                width: 60,
                child: TextField(
                  controller: _occurrencesController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                  decoration: const InputDecoration(border: InputBorder.none, hintText: '0'),
                  onChanged: (val) => setState(() => _occurrences = int.tryParse(val)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildApplyButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: () {
          HapticFeedback.mediumImpact();
          final rule = RecurrenceRule(
            type: _type,
            interval: _interval,
            frequency: _frequency,
            unit: _unit,
            startDate: widget.initialRule?.startDate ?? DateTime.now(),
            endCondition: _endCondition,
            endDate: _endDate,
            occurrences: _occurrences,
            daysOfWeek: _type == 'weekly' ? _daysOfWeek : null,
          );
          Navigator.pop(context, rule);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFCDAF56),
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: const Text(
          'APPLY SCHEDULE',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: Color(0xFFCDAF56),
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildNumberInput({
    required TextEditingController controller,
    required String label,
    required Function(String) onChanged,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white38 : Colors.black38,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          onChanged: onChanged,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFCDAF56), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
