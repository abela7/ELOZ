import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../core/models/recurrence_rule.dart';

/// Enhanced Recurrence Selector with full pattern support
class EnhancedRecurrenceSelector extends StatefulWidget {
  final RecurrenceRule? initialRule;
  final ValueChanged<RecurrenceRule?> onChanged;
  final DateTime? taskDueDate;

  const EnhancedRecurrenceSelector({
    super.key,
    this.initialRule,
    required this.onChanged,
    this.taskDueDate,
  });

  @override
  State<EnhancedRecurrenceSelector> createState() => _EnhancedRecurrenceSelectorState();
}

class _EnhancedRecurrenceSelectorState extends State<EnhancedRecurrenceSelector> {
  RecurrenceRule? _selectedRule;
  static const _accentColor = Color(0xFFCDAF56);

  @override
  void initState() {
    super.initState();
    _selectedRule = widget.initialRule;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.repeat_rounded, size: 16, color: _accentColor),
            ),
            const SizedBox(width: 10),
            Text(
              'Repeat',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
            if (_selectedRule != null) ...[
              const Spacer(),
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedRule = null);
                  widget.onChanged(null);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.close_rounded, size: 14, color: Colors.red),
                      SizedBox(width: 4),
                      Text('Clear', style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        
        // Recurrence Options Grid
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.4,
          children: [
            _RecurrenceChip(
              label: 'None',
              icon: Icons.block_rounded,
              isSelected: _selectedRule == null,
              isDark: isDark,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedRule = null);
                widget.onChanged(null);
              },
            ),
            _RecurrenceChip(
              label: 'Daily',
              icon: Icons.wb_sunny_rounded,
              isSelected: _selectedRule?.type == 'daily',
              isDark: isDark,
              onTap: () => _showRecurrenceSheet(context, 'daily'),
            ),
            _RecurrenceChip(
              label: 'Weekly',
              icon: Icons.date_range_rounded,
              isSelected: _selectedRule?.type == 'weekly',
              isDark: isDark,
              onTap: () => _showRecurrenceSheet(context, 'weekly'),
            ),
            _RecurrenceChip(
              label: 'Monthly',
              icon: Icons.calendar_month_rounded,
              isSelected: _selectedRule?.type == 'monthly',
              isDark: isDark,
              onTap: () => _showRecurrenceSheet(context, 'monthly'),
            ),
            _RecurrenceChip(
              label: 'Yearly',
              icon: Icons.cake_rounded,
              isSelected: _selectedRule?.type == 'yearly',
              isDark: isDark,
              onTap: () => _showRecurrenceSheet(context, 'yearly'),
            ),
            _RecurrenceChip(
              label: 'Custom',
              icon: Icons.tune_rounded,
              isSelected: _selectedRule?.type == 'custom',
              isDark: isDark,
              onTap: () => _showRecurrenceSheet(context, 'custom'),
            ),
          ],
        ),

        // Selection Summary
        if (_selectedRule != null) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _showRecurrenceSheet(context, _selectedRule!.type),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _accentColor.withValues(alpha: isDark ? 0.15 : 0.08),
                    _accentColor.withValues(alpha: isDark ? 0.08 : 0.04),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _accentColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _accentColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getTypeIcon(_selectedRule!.type),
                      size: 18,
                      color: _accentColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedRule!.getDescription(),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        if (_selectedRule!.endCondition != 'never') ...[
                          const SizedBox(height: 2),
                          Text(
                            _getEndConditionText(),
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white54 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    Icons.edit_rounded,
                    size: 16,
                    color: _accentColor.withValues(alpha: 0.7),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'daily': return Icons.wb_sunny_rounded;
      case 'weekly': return Icons.date_range_rounded;
      case 'monthly': return Icons.calendar_month_rounded;
      case 'yearly': return Icons.cake_rounded;
      case 'custom': return Icons.tune_rounded;
      default: return Icons.repeat_rounded;
    }
  }

  String _getEndConditionText() {
    if (_selectedRule == null) return '';
    switch (_selectedRule!.endCondition) {
      case 'on_date':
        if (_selectedRule!.endDate != null) {
          return 'Until ${DateFormat('MMM d, yyyy').format(_selectedRule!.endDate!)}';
        }
        return '';
      case 'after_occurrences':
        return '${_selectedRule!.occurrences ?? 0} times';
      default:
        return '';
    }
  }

  void _showRecurrenceSheet(BuildContext context, String type) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ModernRecurrenceSheet(
        type: type,
        initialRule: _selectedRule?.type == type ? _selectedRule : null,
        taskDueDate: widget.taskDueDate ?? DateTime.now(),
      ),
    ).then((result) {
      if (result != null) {
        setState(() => _selectedRule = result as RecurrenceRule);
        widget.onChanged(_selectedRule);
      }
    });
  }
}

/// Recurrence Type Chip
class _RecurrenceChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _RecurrenceChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  static const _accentColor = Color(0xFFCDAF56);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _accentColor.withValues(alpha: 0.25),
                    _accentColor.withValues(alpha: 0.15),
                  ],
                )
              : null,
          color: isSelected ? null : (isDark ? const Color(0xFF2D3139) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _accentColor : (isDark ? const Color(0xFF3E4148) : Colors.grey.shade200),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: _accentColor.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2))]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? _accentColor : (isDark ? Colors.white54 : Colors.grey.shade500),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? _accentColor : (isDark ? Colors.white70 : Colors.grey.shade600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Modern Unified Recurrence Sheet
class _ModernRecurrenceSheet extends StatefulWidget {
  final String type;
  final RecurrenceRule? initialRule;
  final DateTime taskDueDate;

  const _ModernRecurrenceSheet({
    required this.type,
    this.initialRule,
    required this.taskDueDate,
  });

  @override
  State<_ModernRecurrenceSheet> createState() => _ModernRecurrenceSheetState();
}

class _ModernRecurrenceSheetState extends State<_ModernRecurrenceSheet> {
  static const _accentColor = Color(0xFFCDAF56);
  
  late int _interval;
  late DateTime _startDate;
  late String _endCondition;
  DateTime? _endDate;
  late int _occurrences;
  late bool _skipWeekends;
  late bool _useCustomStartDate;
  
  // Weekly specific
  late Set<int> _selectedWeekDays;
  
  // Monthly specific
  late Set<int> _selectedMonthDays;
  
  // Yearly specific
  late int _selectedMonth;
  late int _selectedDay;
  
  // Custom specific
  late String _customUnit;

  late final TextEditingController _intervalController;
  late final TextEditingController _occurrencesController;

  final List<String> _dayNames = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
  final List<String> _fullDayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  final List<String> _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  void initState() {
    super.initState();
    final rule = widget.initialRule;
    
    _interval = rule?.interval ?? 1;
    _startDate = rule?.startDate ?? widget.taskDueDate;
    _useCustomStartDate = rule != null && rule.startDate != widget.taskDueDate;
    _endCondition = rule?.endCondition ?? 'never';
    _endDate = rule?.endDate;
    _occurrences = rule?.occurrences ?? 10;
    _skipWeekends = rule?.skipWeekends ?? false;
    
    // Weekly
    _selectedWeekDays = rule?.daysOfWeek?.toSet() ?? {widget.taskDueDate.weekday % 7};
    
    // Monthly
    _selectedMonthDays = rule?.daysOfMonth?.toSet() ?? {widget.taskDueDate.day};
    
    // Yearly
    _selectedMonth = rule?.dayOfYear?['month'] ?? widget.taskDueDate.month;
    _selectedDay = rule?.dayOfYear?['day'] ?? widget.taskDueDate.day;
    
    // Custom
    _customUnit = rule?.unit ?? 'days';

    _intervalController = TextEditingController(text: _interval.toString());
    _occurrencesController = TextEditingController(text: _occurrences.toString());
  }

  @override
  void dispose() {
    _intervalController.dispose();
    _occurrencesController.dispose();
    super.dispose();
  }

  String get _typeTitle {
    switch (widget.type) {
      case 'daily': return 'Daily Repeat';
      case 'weekly': return 'Weekly Repeat';
      case 'monthly': return 'Monthly Repeat';
      case 'yearly': return 'Yearly Repeat';
      case 'custom': return 'Custom Repeat';
      default: return 'Repeat';
    }
  }

  IconData get _typeIcon {
    switch (widget.type) {
      case 'daily': return Icons.wb_sunny_rounded;
      case 'weekly': return Icons.date_range_rounded;
      case 'monthly': return Icons.calendar_month_rounded;
      case 'yearly': return Icons.cake_rounded;
      case 'custom': return Icons.tune_rounded;
      default: return Icons.repeat_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2128) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _accentColor.withValues(alpha: 0.2),
                        _accentColor.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_typeIcon, size: 22, color: _accentColor),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _typeTitle,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      'Configure your repeat pattern',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: isDark ? Colors.white54 : Colors.grey),
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPadding + 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type-specific content
                  if (widget.type == 'weekly') _buildWeekDaySelector(isDark),
                  if (widget.type == 'monthly') _buildMonthDaySelector(isDark),
                  if (widget.type == 'yearly') _buildYearlySelector(isDark),
                  
                  // Interval Section
                  _buildIntervalSection(isDark),
                  
                  const SizedBox(height: 20),
                  
                  // Start Date Section
                  _buildStartDateSection(isDark),
                  
                  const SizedBox(height: 20),
                  
                  // End Condition Section
                  _buildEndConditionSection(isDark),
                  
                  // Skip Weekends (for daily only)
                  if (widget.type == 'daily') ...[
                    const SizedBox(height: 20),
                    _buildSkipWeekendsToggle(isDark),
                  ],
                  
                  const SizedBox(height: 24),
                  
                  // Preview
                  _buildPreview(isDark),
                  
                  const SizedBox(height: 24),
                  
                  // Save Button
                  _buildSaveButton(isDark),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: _accentColor),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekDaySelector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Repeat on days', Icons.view_week_rounded, isDark),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2D3139) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF3E4148) : Colors.grey.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (index) {
              final isSelected = _selectedWeekDays.contains(index);
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    if (isSelected && _selectedWeekDays.length > 1) {
                      _selectedWeekDays.remove(index);
                    } else if (!isSelected) {
                      _selectedWeekDays.add(index);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [_accentColor, _accentColor.withValues(alpha: 0.8)],
                          )
                        : null,
                    color: isSelected ? null : (isDark ? Colors.black26 : Colors.white),
                    shape: BoxShape.circle,
                    boxShadow: isSelected
                        ? [BoxShadow(color: _accentColor.withValues(alpha: 0.4), blurRadius: 8)]
                        : null,
                  ),
                  child: Text(
                    _dayNames[index],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.black : (isDark ? Colors.white70 : Colors.grey.shade600),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, left: 4),
          child: Text(
            'Selected: ${_selectedWeekDays.map((d) => _fullDayNames[d]).join(', ')}',
            style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey.shade500),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildMonthDaySelector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Repeat on day(s) of month', Icons.calendar_today_rounded, isDark),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2D3139) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF3E4148) : Colors.grey.shade200),
          ),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1,
            ),
            itemCount: 31,
            itemBuilder: (context, index) {
              final day = index + 1;
              final isSelected = _selectedMonthDays.contains(day);
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    if (isSelected && _selectedMonthDays.length > 1) {
                      _selectedMonthDays.remove(day);
                    } else if (!isSelected) {
                      _selectedMonthDays.add(day);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [_accentColor, _accentColor.withValues(alpha: 0.8)],
                          )
                        : null,
                    color: isSelected ? null : (isDark ? Colors.black26 : Colors.white),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: isSelected
                        ? [BoxShadow(color: _accentColor.withValues(alpha: 0.3), blurRadius: 6)]
                        : null,
                  ),
                  child: Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.black : (isDark ? Colors.white70 : Colors.grey.shade600),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, left: 4),
          child: Text(
            '${_selectedMonthDays.length} day(s) selected',
            style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey.shade500),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildYearlySelector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Repeat on date', Icons.event_rounded, isDark),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2D3139) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF3E4148) : Colors.grey.shade200),
          ),
          child: Column(
            children: [
              // Month selector
              Row(
                children: [
                  Icon(Icons.calendar_month_rounded, size: 18, color: isDark ? Colors.white54 : Colors.grey),
                  const SizedBox(width: 12),
                  Text('Month', style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.grey.shade700)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black26 : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _accentColor.withValues(alpha: 0.3)),
                    ),
                    child: DropdownButton<int>(
                      value: _selectedMonth,
                      isDense: true,
                      underline: const SizedBox(),
                      dropdownColor: isDark ? const Color(0xFF2D3139) : Colors.white,
                      items: List.generate(12, (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text(_monthNames[i], style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87)),
                      )),
                      onChanged: (v) {
                        if (v != null) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedMonth = v;
                            final maxDay = _getMaxDayForMonth(_selectedMonth);
                            if (_selectedDay > maxDay) _selectedDay = maxDay;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Day selector
              Row(
                children: [
                  Icon(Icons.today_rounded, size: 18, color: isDark ? Colors.white54 : Colors.grey),
                  const SizedBox(width: 12),
                  Text('Day', style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.grey.shade700)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black26 : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _accentColor.withValues(alpha: 0.3)),
                    ),
                    child: DropdownButton<int>(
                      value: _selectedDay,
                      isDense: true,
                      underline: const SizedBox(),
                      dropdownColor: isDark ? const Color(0xFF2D3139) : Colors.white,
                      items: List.generate(_getMaxDayForMonth(_selectedMonth), (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text('${i + 1}', style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87)),
                      )),
                      onChanged: (v) {
                        if (v != null) {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedDay = v);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, left: 4),
          child: Text(
            'Every year on ${_monthNames[_selectedMonth - 1]} $_selectedDay',
            style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey.shade500),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  int _getMaxDayForMonth(int month) {
    const daysInMonth = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return daysInMonth[month - 1];
  }

  Widget _buildIntervalSection(bool isDark) {
    final unitLabel = widget.type == 'custom' ? _customUnit : _getUnitLabel();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Frequency', Icons.sync_rounded, isDark),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2D3139) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF3E4148) : Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Text(
                'Every',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.grey.shade700,
                ),
              ),
              const SizedBox(width: 12),
              // Number input
              _buildMinimalNumberInput(
                controller: _intervalController,
                isDark: isDark,
                onChanged: (v) => setState(() => _interval = int.tryParse(v) ?? 1),
              ),
              const SizedBox(width: 12),
              // Unit selector (for custom) or label
              if (widget.type == 'custom')
                Expanded(
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black26 : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _accentColor.withValues(alpha: 0.3)),
                    ),
                    child: DropdownButton<String>(
                      value: _customUnit,
                      isExpanded: true,
                      underline: const SizedBox(),
                      dropdownColor: isDark ? const Color(0xFF2D3139) : Colors.white,
                      items: ['days', 'weeks', 'months', 'years'].map((u) => DropdownMenuItem(
                        value: u,
                        child: Text(u, style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
                      )).toList(),
                      onChanged: (v) {
                        if (v != null) {
                          HapticFeedback.selectionClick();
                          setState(() => _customUnit = v);
                        }
                      },
                    ),
                  ),
                )
              else
                Expanded(
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: _accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _interval == 1 ? unitLabel.replaceAll('(s)', '') : unitLabel.replaceAll('(s)', 's'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _accentColor,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _getUnitLabel() {
    switch (widget.type) {
      case 'daily': return 'day(s)';
      case 'weekly': return 'week(s)';
      case 'monthly': return 'month(s)';
      case 'yearly': return 'year(s)';
      default: return 'day(s)';
    }
  }

  Widget _buildStartDateSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Start date', Icons.play_arrow_rounded, isDark),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2D3139) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF3E4148) : Colors.grey.shade200),
          ),
          child: Column(
            children: [
              // Toggle for custom start date
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                child: Row(
                  children: [
                    Icon(
                      _useCustomStartDate ? Icons.calendar_today_rounded : Icons.event_available_rounded,
                      size: 18,
                      color: isDark ? Colors.white54 : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _useCustomStartDate ? 'Custom start date' : 'Use task due date',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            DateFormat('MMM d, yyyy').format(_useCustomStartDate ? _startDate : widget.taskDueDate),
                            style: TextStyle(
                              fontSize: 11,
                              color: _accentColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _useCustomStartDate,
                      onChanged: (v) {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _useCustomStartDate = v;
                          if (!v) _startDate = widget.taskDueDate;
                        });
                      },
                      activeColor: _accentColor,
                    ),
                  ],
                ),
              ),
              // Date picker (if custom)
              if (_useCustomStartDate) ...[
                const Divider(height: 1),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _startDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                    );
                    if (picked != null) {
                      HapticFeedback.selectionClick();
                      setState(() => _startDate = picked);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.edit_calendar_rounded, size: 18, color: _accentColor),
                        const SizedBox(width: 12),
                        Text(
                          'Change date',
                          style: TextStyle(
                            fontSize: 13,
                            color: _accentColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        const Icon(Icons.chevron_right_rounded, size: 20, color: _accentColor),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEndConditionSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('End condition', Icons.stop_circle_outlined, isDark),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2D3139) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              _buildEndConditionTab('Never', 'never', Icons.all_inclusive_rounded, isDark),
              _buildEndConditionTab('Until', 'on_date', Icons.event_rounded, isDark),
              _buildEndConditionTab('Count', 'after_occurrences', Icons.tag_rounded, isDark),
            ],
          ),
        ),
        
        // Conditional content
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: Column(
            children: [
              if (_endCondition == 'on_date') ...[
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _endDate ?? _startDate.add(const Duration(days: 30)),
                      firstDate: _startDate,
                      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                    );
                    if (picked != null) {
                      HapticFeedback.selectionClick();
                      setState(() => _endDate = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2D3139) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _accentColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event_rounded, size: 20, color: _accentColor),
                        const SizedBox(width: 12),
                        Text(
                          _endDate != null
                              ? DateFormat('EEEE, MMM d, yyyy').format(_endDate!)
                              : 'Select end date',
                          style: TextStyle(
                            fontSize: 14,
                            color: _endDate != null
                                ? (isDark ? Colors.white : Colors.black87)
                                : (isDark ? Colors.white54 : Colors.grey),
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.chevron_right_rounded, size: 20, color: isDark ? Colors.white38 : Colors.grey),
                      ],
                    ),
                  ),
                ),
              ],
              if (_endCondition == 'after_occurrences') ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2D3139) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _accentColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.numbers_rounded, size: 20, color: _accentColor),
                      const SizedBox(width: 12),
                      Text(
                        'After',
                        style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.grey.shade700),
                      ),
                      const SizedBox(width: 12),
                      _buildMinimalNumberInput(
                        controller: _occurrencesController,
                        isDark: isDark,
                        onChanged: (v) => setState(() => _occurrences = int.tryParse(v) ?? 10),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'occurrences',
                        style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEndConditionTab(String label, String value, IconData icon, bool isDark) {
    final isSelected = _endCondition == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _endCondition = value);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? _accentColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.black : (isDark ? Colors.white54 : Colors.grey),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.black : (isDark ? Colors.white70 : Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkipWeekendsToggle(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D3139) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF3E4148) : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.weekend_rounded, size: 18, color: Colors.orange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Skip weekends',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  'No tasks on Sat & Sun',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _skipWeekends,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              setState(() => _skipWeekends = v);
            },
            activeColor: Colors.orange,
          ),
        ],
      ),
    );
  }

  /// Minimal number input with underline only when focused
  Widget _buildMinimalNumberInput({
    required TextEditingController controller,
    required bool isDark,
    required ValueChanged<String> onChanged,
  }) {
    return SizedBox(
      width: 56,
      height: 44,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: _accentColor,
        ),
        cursorColor: _accentColor,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          filled: true,
          fillColor: isDark ? Colors.black26 : Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _accentColor, width: 2),
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildPreview(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _accentColor.withValues(alpha: isDark ? 0.15 : 0.1),
            _accentColor.withValues(alpha: isDark ? 0.08 : 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _accentColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.visibility_rounded, size: 18, color: _accentColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Preview',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _accentColor.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _getPreviewText(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getPreviewText() {
    switch (widget.type) {
      case 'daily':
        final skipText = _skipWeekends ? ' (weekdays only)' : '';
        if (_interval == 1) return 'Every day$skipText';
        return 'Every $_interval days$skipText';
      case 'weekly':
        final days = _selectedWeekDays.map((d) => _fullDayNames[d]).join(', ');
        if (_interval == 1) return 'Every week on $days';
        return 'Every $_interval weeks on $days';
      case 'monthly':
        final daysStr = _selectedMonthDays.toList()..sort();
        final daysList = daysStr.map((d) => _getOrdinal(d)).join(', ');
        if (_interval == 1) return 'Monthly on the $daysList';
        return 'Every $_interval months on the $daysList';
      case 'yearly':
        return 'Every year on ${_monthNames[_selectedMonth - 1]} $_selectedDay';
      case 'custom':
        if (_interval == 1) return 'Every ${_customUnit.replaceAll('s', '')}';
        return 'Every $_interval $_customUnit';
      default:
        return '';
    }
  }

  String _getOrdinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    switch (n % 10) {
      case 1: return '${n}st';
      case 2: return '${n}nd';
      case 3: return '${n}rd';
      default: return '${n}th';
    }
  }

  Widget _buildSaveButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _saveRule,
        style: ElevatedButton.styleFrom(
          backgroundColor: _accentColor,
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_rounded, size: 20),
            SizedBox(width: 8),
            Text(
              'Apply Recurrence',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  void _saveRule() {
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();
    
    RecurrenceRule rule;
    final actualStartDate = _useCustomStartDate ? _startDate : widget.taskDueDate;
    
    switch (widget.type) {
      case 'daily':
        rule = RecurrenceRule.daily(
          startDate: actualStartDate,
          interval: _interval,
          endCondition: _endCondition,
          endDate: _endCondition == 'on_date' ? _endDate : null,
          occurrences: _endCondition == 'after_occurrences' ? _occurrences : null,
          skipWeekends: _skipWeekends,
        );
        break;
      case 'weekly':
        rule = RecurrenceRule.weekly(
          startDate: actualStartDate,
          daysOfWeek: _selectedWeekDays.toList(),
          interval: _interval,
          endCondition: _endCondition,
          endDate: _endCondition == 'on_date' ? _endDate : null,
          occurrences: _endCondition == 'after_occurrences' ? _occurrences : null,
        );
        break;
      case 'monthly':
        rule = RecurrenceRule.monthly(
          startDate: actualStartDate,
          daysOfMonth: _selectedMonthDays.toList(),
          interval: _interval,
          endCondition: _endCondition,
          endDate: _endCondition == 'on_date' ? _endDate : null,
          occurrences: _endCondition == 'after_occurrences' ? _occurrences : null,
        );
        break;
      case 'yearly':
        rule = RecurrenceRule.yearly(
          startDate: actualStartDate,
          dayOfYear: {'month': _selectedMonth, 'day': _selectedDay},
          interval: _interval,
          endCondition: _endCondition,
          endDate: _endCondition == 'on_date' ? _endDate : null,
          occurrences: _endCondition == 'after_occurrences' ? _occurrences : null,
        );
        break;
      case 'custom':
      default:
        rule = RecurrenceRule.custom(
          startDate: actualStartDate,
          interval: _interval,
          unit: _customUnit,
          endCondition: _endCondition,
          endDate: _endCondition == 'on_date' ? _endDate : null,
          occurrences: _endCondition == 'after_occurrences' ? _occurrences : null,
          skipWeekends: _skipWeekends,
        );
        break;
    }
    
    Navigator.pop(context, rule);
  }
}
