import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/dark_gradient.dart';
import '../../behavior_module.dart';
import '../../data/models/behavior.dart';
import '../../data/models/behavior_reason.dart';
import '../../data/services/behavior_api_service.dart';
import 'behavior_settings_screen.dart';

class BehaviorLogScreen extends StatefulWidget {
  const BehaviorLogScreen({
    super.key,
    required this.initialDate,
    this.existingLog,
  });

  final DateTime initialDate;
  final BehaviorLogWithReasons? existingLog;

  @override
  State<BehaviorLogScreen> createState() => _BehaviorLogScreenState();
}

class _BehaviorLogScreenState extends State<BehaviorLogScreen> {
  final BehaviorApiService _api = BehaviorApiService();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  late DateTime _selectedDate;
  TimeOfDay _selectedTime = TimeOfDay.now();
  List<Behavior> _behaviors = const <Behavior>[];
  List<BehaviorReason> _reasons = const <BehaviorReason>[];
  String? _selectedBehaviorId;
  final Set<String> _selectedReasonIds = <String>{};
  int? _selectedIntensity;

  Map<String, Behavior> get _behaviorById => <String, Behavior>{
    for (final behavior in _behaviors) behavior.id: behavior,
  };

  Behavior? get _selectedBehavior =>
      _selectedBehaviorId == null ? null : _behaviorById[_selectedBehaviorId!];

  List<Behavior> get _activeBehaviors => _behaviors
      .where((behavior) => behavior.isActive && !behavior.isDeleted)
      .toList(growable: false);

  List<Behavior> get _selectableBehaviors {
    final out = <String, Behavior>{
      for (final behavior in _activeBehaviors) behavior.id: behavior,
    };
    final selectedId = widget.existingLog?.log.behaviorId;
    if (selectedId != null) {
      final existing = _behaviors.where((behavior) => behavior.id == selectedId);
      if (existing.isNotEmpty) {
        out[selectedId] = existing.first;
      }
    }
    return out.values.toList(growable: false);
  }

  List<BehaviorReason> get _filteredReasons {
    final behavior = _selectedBehavior;
    if (behavior == null) return const <BehaviorReason>[];
    final active = _reasons
        .where(
          (reason) =>
              reason.type == behavior.type &&
              reason.isActive &&
              !reason.isDeleted,
        )
        .toList(growable: false);
    final selected = _reasons
        .where(
          (reason) =>
              reason.type == behavior.type &&
              _selectedReasonIds.contains(reason.id),
        )
        .toList(growable: false);
    final out = <String, BehaviorReason>{for (final reason in active) reason.id: reason};
    for (final reason in selected) {
      out[reason.id] = reason;
    }
    return out.values.toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );
    final existing = widget.existingLog?.log;
    if (existing != null) {
      _selectedDate = DateTime(
        existing.occurredAt.year,
        existing.occurredAt.month,
        existing.occurredAt.day,
      );
      _selectedTime = TimeOfDay(
        hour: existing.occurredAt.hour,
        minute: existing.occurredAt.minute,
      );
    }
    unawaited(_initialize());
  }

  @override
  void dispose() {
    _durationController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    await BehaviorModule.init(preOpenBoxes: true);
    await _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final behaviorsFuture = _api.getBehaviors(includeInactive: true);
      final reasonsFuture = _api.getBehaviorReasons(includeInactive: true);

      final behaviors = await behaviorsFuture;
      final reasons = await reasonsFuture;
      final existing = widget.existingLog;

      String? selectedBehaviorId = existing?.log.behaviorId;
      if (selectedBehaviorId == null) {
        final active = behaviors
            .where((behavior) => behavior.isActive && !behavior.isDeleted)
            .toList(growable: false);
        selectedBehaviorId = active.isEmpty ? null : active.first.id;
      }

      if (!mounted) return;
      setState(() {
        _behaviors = behaviors;
        _reasons = reasons;
        _selectedBehaviorId = selectedBehaviorId;
        _selectedReasonIds
          ..clear()
          ..addAll(existing?.reasonIds ?? const <String>[]);
        _selectedIntensity = existing?.log.intensity;
        _durationController.text = existing?.log.durationMinutes == null
            ? ''
            : '${existing!.log.durationMinutes}';
        _noteController.text = existing?.log.note ?? '';
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  DateTime _buildOccurredAt() {
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
  }

  Future<void> _save() async {
    final behavior = _selectedBehavior;
    if (behavior == null) {
      _showError('Select a behavior to continue.');
      return;
    }
    if (behavior.reasonRequired && _selectedReasonIds.isEmpty) {
      _showError('This behavior requires at least one reason.');
      return;
    }

    final rawDuration = _durationController.text.trim();
    int? duration;
    if (rawDuration.isNotEmpty) {
      duration = int.tryParse(rawDuration);
      if (duration == null || duration < 0) {
        _showError('Duration must be a positive number.');
        return;
      }
    }

    final note = _noteController.text.trim();
    setState(() => _saving = true);
    try {
      final existing = widget.existingLog;
      if (existing == null) {
        await _api.postBehaviorLog(
          behaviorId: behavior.id,
          occurredAt: _buildOccurredAt(),
          reasonIds: _selectedReasonIds.toList(),
          durationMinutes: duration,
          intensity: _selectedIntensity,
          note: note.isEmpty ? null : note,
        );
      } else {
        await _api.putBehaviorLog(
          existing.log.id,
          behaviorId: behavior.id,
          occurredAt: _buildOccurredAt(),
          reasonIds: _selectedReasonIds.toList(),
          durationMinutes: duration,
          intensity: _selectedIntensity,
          note: note.isEmpty ? null : note,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      _showError('Failed to save log: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const BehaviorSettingsScreen()),
    );
    if (mounted) await _reload();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 3650)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked == null) return;
    setState(() => _selectedTime = picked);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final content = Scaffold(
      backgroundColor: isDark ? Colors.transparent : const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: Text(widget.existingLog == null ? 'Log Behavior' : 'Edit Behavior'),
        actions: [
          IconButton(
            onPressed: () => unawaited(_openSettings()),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFCDAF56)),
            )
          : _selectableBehaviors.isEmpty && widget.existingLog == null
          ? _emptyState(isDark)
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                _dateTimeRow(isDark),
                const SizedBox(height: 16),
                _behaviorPicker(isDark),
                const SizedBox(height: 16),
                _reasonPicker(isDark),
                const SizedBox(height: 16),
                _detailsCard(isDark),
                if (_error?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _saving ? null : () => unawaited(_save()),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFCDAF56),
                      foregroundColor: const Color(0xFF1E1E1E),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Color(0xFF1E1E1E),
                            ),
                          )
                        : Text(widget.existingLog == null ? 'Save Log' : 'Update Log'),
                  ),
                ),
              ],
            ),
    );
    return Scaffold(body: isDark ? DarkGradient.wrap(child: content) : content);
  }

  Widget _emptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.track_changes_rounded,
              size: 52,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
            const SizedBox(height: 12),
            Text(
              'No active behaviors',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Create behaviors in Settings before logging.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateTimeRow(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _chipButton(
            isDark: isDark,
            icon: Icons.calendar_today_rounded,
            label: DateFormat('EEE, MMM d').format(_selectedDate),
            onTap: () => unawaited(_pickDate()),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _chipButton(
            isDark: isDark,
            icon: Icons.schedule_rounded,
            label: _formatTime(_selectedTime),
            onTap: () => unawaited(_pickTime()),
          ),
        ),
      ],
    );
  }

  Widget _behaviorPicker(bool isDark) {
    return _card(
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'BEHAVIOR',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFFCDAF56),
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectableBehaviors.map((behavior) {
              final selected = behavior.id == _selectedBehaviorId;
              final color = Color(behavior.colorValue);
              return ChoiceChip(
                selected: selected,
                onSelected: (_) {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _selectedBehaviorId = behavior.id;
                    _selectedReasonIds.removeWhere(
                      (id) => !_reasons.any(
                        (reason) => reason.id == id && reason.type == behavior.type,
                      ),
                    );
                  });
                },
                avatar: Icon(
                  behavior.icon,
                  size: 16,
                  color: selected ? color : (isDark ? Colors.white54 : Colors.black54),
                ),
                label: Text(behavior.name),
              );
            }).toList(growable: false),
          ),
        ],
      ),
    );
  }

  Widget _reasonPicker(bool isDark) {
    final behavior = _selectedBehavior;
    if (behavior == null) return const SizedBox.shrink();
    final reasons = _filteredReasons;
    return _card(
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'REASONS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFCDAF56),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(width: 8),
              if (behavior.reasonRequired)
                Text(
                  '(required)',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (reasons.isEmpty)
            Text(
              'No active reasons for this type.',
              style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: reasons.map((reason) {
                final selected = _selectedReasonIds.contains(reason.id);
                return FilterChip(
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      if (selected) {
                        _selectedReasonIds.remove(reason.id);
                      } else {
                        _selectedReasonIds.add(reason.id);
                      }
                    });
                  },
                  label: Text(reason.name),
                );
              }).toList(growable: false),
            ),
        ],
      ),
    );
  }

  Widget _detailsCard(bool isDark) {
    return _card(
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DETAILS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFFCDAF56),
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _durationController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Duration (minutes)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(5, (i) => i + 1).map((value) {
              return ChoiceChip(
                selected: _selectedIntensity == value,
                onSelected: (_) => setState(() => _selectedIntensity = value),
                label: Text('Intensity $value'),
              );
            }).toList(growable: false),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Note',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipButton({
    required bool isDark,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFFCDAF56)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(bool isDark, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: child,
    );
  }

  String _formatTime(TimeOfDay value) {
    final h = value.hourOfPeriod == 0 ? 12 : value.hourOfPeriod;
    final m = value.minute.toString().padLeft(2, '0');
    return value.period == DayPeriod.am ? '$h:$m AM' : '$h:$m PM';
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
