import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/habit.dart';
import '../../data/models/temptation_log.dart';
import '../../data/models/habit_reason.dart';
import '../providers/temptation_log_providers.dart';
import '../providers/habit_reason_providers.dart';

/// Beautiful step-by-step modal for logging temptations
class LogTemptationModal extends ConsumerStatefulWidget {
  final Habit habit;
  final String habitId;
  final String habitTitle;
  final DateTime? defaultDate; // The date to default to (e.g., selected date from calendar)
  final VoidCallback? onLogged;

  const LogTemptationModal({
    super.key,
    required this.habit,
    required this.habitId,
    required this.habitTitle,
    this.defaultDate,
    this.onLogged,
  });

  /// Show the modal
  static Future<void> show(
    BuildContext context, {
    required Habit habit,
    required String habitId,
    required String habitTitle,
    DateTime? defaultDate,
    VoidCallback? onLogged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LogTemptationModal(
        habit: habit,
        habitId: habitId,
        habitTitle: habitTitle,
        defaultDate: defaultDate,
        onLogged: onLogged,
      ),
    );
  }

  @override
  ConsumerState<LogTemptationModal> createState() => _LogTemptationModalState();
}

class _LogTemptationModalState extends ConsumerState<LogTemptationModal>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  int _count = 1;
  late DateTime _occurredAt;
  HabitReason? _selectedReason;
  int _intensityIndex = 1; // Default: moderate
  String _customNote = '';
  bool _isQuickLog = false;
  
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  // Intensity options
  static const List<Map<String, dynamic>> _intensityOptions = [
    {'index': 0, 'name': 'Mild', 'desc': 'Easy to resist', 'icon': Icons.sentiment_satisfied_rounded, 'color': Color(0xFF4CAF50)},
    {'index': 1, 'name': 'Moderate', 'desc': 'Took some effort', 'icon': Icons.sentiment_neutral_rounded, 'color': Color(0xFFFFB347)},
    {'index': 2, 'name': 'Strong', 'desc': 'Very hard to resist', 'icon': Icons.sentiment_dissatisfied_rounded, 'color': Color(0xFFFF6B6B)},
    {'index': 3, 'name': 'Extreme', 'desc': 'Almost gave in', 'icon': Icons.sentiment_very_dissatisfied_rounded, 'color': Color(0xFFE53935)},
  ];

  @override
  void initState() {
    super.initState();
    // Use the provided default date, or fallback to now
    // Keep the current time if viewing today, otherwise use noon on the selected date
    if (widget.defaultDate != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final selectedDay = DateTime(widget.defaultDate!.year, widget.defaultDate!.month, widget.defaultDate!.day);
      
      if (selectedDay == today) {
        // Viewing today - use current time
        _occurredAt = now;
      } else {
        // Viewing past day - use noon on that day
        _occurredAt = DateTime(selectedDay.year, selectedDay.month, selectedDay.day, 12, 0);
      }
    } else {
      _occurredAt = DateTime.now();
    }
    
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 2) {
      setState(() => _currentStep++);
      _animController.reset();
      _animController.forward();
    } else {
      _saveLog();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _animController.reset();
      _animController.forward();
    }
  }

  void _quickLog() {
    setState(() => _isQuickLog = true);
    _saveLog();
  }

  void _saveLog() {
    HapticFeedback.mediumImpact();
    
    final log = TemptationLog(
      habitId: widget.habitId,
      occurredAt: _occurredAt,
      count: _count,
      reasonId: _selectedReason?.id,
      reasonText: _selectedReason?.text,
      customNote: _customNote.isNotEmpty ? _customNote : null,
      intensityIndex: _intensityIndex,
      didResist: true,
      iconCodePoint: _selectedReason?.iconCodePoint,
      colorValue: _selectedReason?.colorValue,
    );

    ref.read(temptationLogNotifierProvider.notifier).addLog(log);
    ref.invalidate(habitTemptationLogsProvider(widget.habitId));
    ref.invalidate(todayTemptationCountProvider(widget.habitId));
    ref.invalidate(totalTemptationCountProvider(widget.habitId));

    Navigator.pop(context);
    widget.onLogged?.call();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _count == 1 
                    ? 'Temptation logged. You resisted! 💪'
                    : '$_count temptations logged. Stay strong! 💪',
              ),
            ),
          ],
        ),
        backgroundColor: widget.habit.color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D21) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.grey[300],
              borderRadius: BorderRadius.circular(3),
            ),
          ),

          // Header
          _buildHeader(isDark),

          // Quick log option (step 0 only)
          if (_currentStep == 0) _buildQuickLogOption(isDark),

          // Progress indicator (not on quick log)
          if (!_isQuickLog) _buildProgressIndicator(isDark),

          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                24, 
                16, 
                24, 
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: _buildStepContent(isDark),
              ),
            ),
          ),

          // Footer
          _buildFooter(isDark),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    final stepTitles = [
      'How many times?',
      'What triggered it?',
      'How strong was it?',
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.habit.color,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: widget.habit.color.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.psychology_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stepTitles[_currentStep],
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                  ),
                ),
                Text(
                  widget.habitTitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.close_rounded,
              color: isDark ? Colors.white38 : Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickLogOption(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: GestureDetector(
        onTap: _quickLog,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: widget.habit.color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: widget.habit.color.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.bolt_rounded, color: widget.habit.color, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Log',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                      ),
                    ),
                    Text(
                      'Log 1 temptation now, add details later',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: widget.habit.color, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: List.generate(3, (index) {
          final isActive = index <= _currentStep;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
              height: 4,
              decoration: BoxDecoration(
                color: isActive
                    ? widget.habit.color
                    : (isDark ? Colors.white12 : Colors.grey[200]),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent(bool isDark) {
    switch (_currentStep) {
      case 0:
        return _buildCountStep(isDark);
      case 1:
        return _buildReasonStep(isDark);
      case 2:
        return _buildIntensityStep(isDark);
      default:
        return const SizedBox();
    }
  }

  Widget _buildCountStep(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Count selector
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Text(
                'Times felt tempted',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.grey[700],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildCountButton(isDark, Icons.remove_rounded, () {
                    if (_count > 1) setState(() => _count--);
                    HapticFeedback.selectionClick();
                  }),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _count.toString(),
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        color: widget.habit.color,
                      ),
                    ),
                  ),
                  _buildCountButton(isDark, Icons.add_rounded, () {
                    if (_count < 99) setState(() => _count++);
                    HapticFeedback.selectionClick();
                  }),
                ],
              ),
              const SizedBox(height: 16),
              // Quick count buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [1, 2, 3, 5, 10].map((num) {
                  final isSelected = _count == num;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _count = num);
                        HapticFeedback.selectionClick();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? widget.habit.color
                              : (isDark ? Colors.white.withOpacity(0.1) : Colors.grey[200]),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          num.toString(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isSelected 
                                ? Colors.white 
                                : (isDark ? Colors.white70 : Colors.grey[700]),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Date/Time picker
        _buildDateTimePicker(isDark),
      ],
    );
  }

  Widget _buildCountButton(bool isDark, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: widget.habit.color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: widget.habit.color.withOpacity(0.3)),
        ),
        child: Icon(icon, color: widget.habit.color, size: 28),
      ),
    );
  }

  Widget _buildDateTimePicker(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Date
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _occurredAt,
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  setState(() {
                    _occurredAt = DateTime(
                      date.year, date.month, date.day,
                      _occurredAt.hour, _occurredAt.minute,
                    );
                  });
                }
              },
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded, 
                       color: isDark ? Colors.white54 : Colors.grey[600], size: 20),
                  const SizedBox(width: 10),
                  Text(
                    DateFormat('MMM d, yyyy').format(_occurredAt),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: 1,
            height: 24,
            color: isDark ? Colors.white12 : Colors.grey[300],
          ),
          // Time
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(_occurredAt),
                );
                if (time != null) {
                  setState(() {
                    _occurredAt = DateTime(
                      _occurredAt.year, _occurredAt.month, _occurredAt.day,
                      time.hour, time.minute,
                    );
                  });
                }
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.access_time_rounded, 
                       color: isDark ? Colors.white54 : Colors.grey[600], size: 20),
                  const SizedBox(width: 10),
                  Text(
                    DateFormat('h:mm a').format(_occurredAt),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReasonStep(bool isDark) {
    final reasonsAsync = ref.watch(habitActiveTemptationReasonsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What triggered the urge?',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : Colors.grey[700],
          ),
        ),
        const SizedBox(height: 16),

        reasonsAsync.when(
          data: (reasons) {
            if (reasons.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(Icons.info_outline_rounded, 
                         color: isDark ? Colors.white38 : Colors.grey[400], size: 32),
                    const SizedBox(height: 12),
                    Text(
                      'No temptation reasons yet',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white54 : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Add reasons in Habit Settings → Reasons',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white38 : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              );
            }

            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: reasons.map((reason) {
                final isSelected = _selectedReason?.id == reason.id;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedReason = isSelected ? null : reason);
                    HapticFeedback.selectionClick();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? reason.color.withOpacity(0.15)
                          : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100]),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected 
                            ? reason.color 
                            : (isDark ? Colors.white.withOpacity(0.1) : Colors.grey[300]!),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(reason.icon ?? Icons.note_rounded, 
                             color: reason.color, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          reason.text,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.check_rounded, color: reason.color, size: 16),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Text('Error loading reasons'),
        ),

        const SizedBox(height: 20),

        // Optional note
        TextField(
          maxLines: 2,
          maxLength: 150,
          onChanged: (value) => _customNote = value,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF1E1E1E),
          ),
          decoration: InputDecoration(
            labelText: 'Additional notes (optional)',
            labelStyle: TextStyle(
              color: isDark ? Colors.white54 : Colors.grey[600],
            ),
            hintText: 'What was happening? Where were you?',
            hintStyle: TextStyle(
              color: isDark ? Colors.white30 : Colors.grey[400],
            ),
            filled: true,
            fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: widget.habit.color, width: 2),
            ),
            counterStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey[500]),
          ),
        ),
      ],
    );
  }

  Widget _buildIntensityStep(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How strong was the urge?',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : Colors.grey[700],
          ),
        ),
        const SizedBox(height: 16),

        ...List.generate(_intensityOptions.length, (index) {
          final option = _intensityOptions[index];
          final isSelected = _intensityIndex == option['index'];
          final color = option['color'] as Color;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: () {
                setState(() => _intensityIndex = option['index'] as int);
                HapticFeedback.selectionClick();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? color.withOpacity(0.12)
                      : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100]),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? color : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withOpacity(isSelected ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        option['icon'] as IconData,
                        color: color,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            option['name'] as String,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                            ),
                          ),
                          Text(
                            option['desc'] as String,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white54 : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),

        const SizedBox(height: 16),

        // Summary preview
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.habit.color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: widget.habit.color.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Summary',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.psychology_rounded, color: widget.habit.color, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$_count temptation${_count > 1 ? 's' : ''} • ${_selectedReason?.text ?? 'No reason selected'} • ${_intensityOptions[_intensityIndex]['name']}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).viewInsets.bottom > 0 ? 16 : 24,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D21) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey[200]!,
          ),
        ),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _prevStep,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(
                    color: isDark ? Colors.white24 : Colors.grey[300]!,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Back',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.grey[700],
                  ),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: _currentStep > 0 ? 2 : 1,
            child: ElevatedButton(
              onPressed: _nextStep,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: widget.habit.color,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _currentStep == 2 ? 'Log Temptation' : 'Continue',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _currentStep == 2 ? Icons.check_rounded : Icons.arrow_forward_rounded,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
