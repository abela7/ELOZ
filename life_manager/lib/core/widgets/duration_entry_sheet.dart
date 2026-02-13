import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/time_utils.dart';

/// A modern, reusable duration entry sheet.
///
/// Returns duration in **minutes** (int), or null if cancelled.
class DurationEntrySheet {
  static Future<int?> show(
    BuildContext context, {
    required String title,
    String? subtitle,
    int? targetMinutes,
    String initialUnit = TimeUtils.unitMinute,
    Color? accentColor,
    int? Function(int minutes)? pointsForMinutes,
  }) async {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DurationEntryContent(
        title: title,
        subtitle: subtitle,
        targetMinutes: targetMinutes,
        initialUnit: initialUnit,
        accentColor: accentColor,
        pointsForMinutes: pointsForMinutes,
      ),
    );
  }
}

class _DurationEntryContent extends StatefulWidget {
  final String title;
  final String? subtitle;
  final int? targetMinutes;
  final String initialUnit;
  final Color? accentColor;
  final int? Function(int minutes)? pointsForMinutes;

  const _DurationEntryContent({
    required this.title,
    required this.subtitle,
    required this.targetMinutes,
    required this.initialUnit,
    required this.accentColor,
    required this.pointsForMinutes,
  });

  @override
  State<_DurationEntryContent> createState() => _DurationEntryContentState();
}

class _DurationEntryContentState extends State<_DurationEntryContent> {
  late final TextEditingController _valueController;
  late String _unit;
  String? _error;

  @override
  void initState() {
    super.initState();
    _unit = widget.initialUnit;
    _valueController = TextEditingController();
    _valueController.addListener(_recompute);
  }

  @override
  void dispose() {
    _valueController.removeListener(_recompute);
    _valueController.dispose();
    super.dispose();
  }

  void _recompute() {
    final minutes = _computedMinutes;
    setState(() {
      _error = (minutes == null || minutes <= 0) ? 'Enter a duration greater than 0' : null;
    });
  }

  double? get _parsedValue {
    final raw = _valueController.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  int? get _computedMinutes {
    final v = _parsedValue;
    if (v == null || v.isNaN || v.isInfinite) return null;
    if (v <= 0) return 0;
    final minutesDouble = TimeUtils.toMinutes(v, _unit);
    // Use ceil to avoid losing partial minutes (consistent with stopwatch logging).
    final minutes = minutesDouble.ceil();
    return minutes <= 0 ? 0 : minutes;
  }

  void _setPresetMinutes(int minutes) {
    HapticFeedback.selectionClick();
    // Keep the selected unit, but convert minutes into that unit for display.
    final v = TimeUtils.fromMinutes(minutes.toDouble(), _unit);
    _valueController.text = v == v.truncateToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
    _valueController.selection = TextSelection.fromPosition(
      TextPosition(offset: _valueController.text.length),
    );
  }

  List<int> _buildPresets() {
    final target = widget.targetMinutes;
    if (target != null && target > 0) {
      return <int>[
        (target * 0.25).round().clamp(1, 24 * 60),
        (target * 0.50).round().clamp(1, 24 * 60),
        (target * 0.75).round().clamp(1, 24 * 60),
        target.clamp(1, 24 * 60),
      ].toSet().toList();
    }
    return const <int>[5, 10, 15, 20, 30, 45, 60, 90];
  }

  String _unitLabel(String unit) {
    switch (unit) {
      case TimeUtils.unitHour:
        return 'Hours';
      case TimeUtils.unitSecond:
        return 'Seconds';
      case TimeUtils.unitMinute:
      default:
        return 'Minutes';
    }
  }

  Widget _unitChip(String unit, bool isDark, Color accent, Color subtext) {
    final selected = _unit == unit;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _unit = unit);
        _recompute();
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? accent : (isDark ? Colors.white10 : Colors.black12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? accent : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: selected ? [
            BoxShadow(
              color: accent.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ] : [],
        ),
        child: Text(
          _unitLabel(unit),
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: selected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E2228) : Colors.white;
    final card = isDark ? const Color(0xFF252A31) : const Color(0xFFF7F7F8);
    final text = isDark ? Colors.white : const Color(0xFF1A1C1E);
    final sub = isDark ? Colors.white70 : const Color(0xFF44474E);
    final accent = widget.accentColor ?? const Color(0xFFCDAF56);
    final minutes = _computedMinutes;
    final canSave = minutes != null && minutes > 0;
    final estimatedPoints = (canSave && widget.pointsForMinutes != null) ? widget.pointsForMinutes!(minutes!) : null;

    final presets = _buildPresets();

    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: text,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              if (widget.subtitle != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  widget.subtitle!,
                                  style: TextStyle(
                                    color: sub,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton.filledTonal(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded, size: 20),
                          style: IconButton.styleFrom(
                            backgroundColor: isDark ? Colors.white10 : Colors.black12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Main Input Section
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.black12,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.timer_outlined, size: 18, color: accent),
                              const SizedBox(width: 8),
                              Text(
                                'DURATION',
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _valueController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: text,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d*$')),
                            ],
                            decoration: InputDecoration(
                              hintText: '0',
                              hintStyle: TextStyle(color: sub.withOpacity(0.3)),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              suffixIcon: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: accent.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _unit == TimeUtils.unitHour
                                      ? 'hrs'
                                      : _unit == TimeUtils.unitSecond
                                          ? 'sec'
                                          : 'min',
                                  style: TextStyle(
                                    color: accent,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              suffixIconConstraints: const BoxConstraints(),
                            ),
                            autofocus: true,
                          ),
                          const SizedBox(height: 20),
                          
                          // Unit Selector
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _unitChip(TimeUtils.unitHour, isDark, accent, sub),
                                const SizedBox(width: 8),
                                _unitChip(TimeUtils.unitMinute, isDark, accent, sub),
                                const SizedBox(width: 8),
                                _unitChip(TimeUtils.unitSecond, isDark, accent, sub),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Info Card (Will Log + Points)
                    if (minutes != null && minutes > 0)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark 
                              ? [accent.withOpacity(0.15), accent.withOpacity(0.05)]
                              : [accent.withOpacity(0.1), accent.withOpacity(0.02)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: accent.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(Icons.check_circle_rounded, color: accent, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Logging ${TimeUtils.formatMinutes(minutes, compact: false)}',
                                        style: TextStyle(
                                          color: text,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                        ),
                                      ),
                                      Text(
                                        'Total: $minutes minutes',
                                        style: TextStyle(
                                          color: sub,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (estimatedPoints != null) ...[
                              const Divider(height: 24, thickness: 0.5),
                              Row(
                                children: [
                                  Icon(Icons.stars_rounded, color: accent, size: 20),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Earns ${estimatedPoints >= 0 ? '+' : ''}$estimatedPoints points',
                                    style: TextStyle(
                                      color: text,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    
                    const SizedBox(height: 24),
                    
                    // Quick Picks
                    Row(
                      children: [
                        Icon(Icons.bolt_rounded, size: 16, color: sub),
                        const SizedBox(width: 8),
                        Text(
                          'QUICK PICKS',
                          style: TextStyle(
                            color: sub,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: presets.map((m) {
                        final isTarget = widget.targetMinutes != null && m == widget.targetMinutes;
                        final label = (widget.targetMinutes != null && widget.targetMinutes! > 0)
                            ? (isTarget
                                ? 'Target'
                                : '${((m / widget.targetMinutes!) * 100).round()}%')
                            : TimeUtils.formatMinutes(m, compact: true);
                        
                        // Check if this preset matches the current input
                        final isSelected = _computedMinutes == m;

                        return InkWell(
                          onTap: () => _setPresetMinutes(m),
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected 
                                ? accent 
                                : (isTarget ? accent.withOpacity(0.1) : (isDark ? Colors.white10 : Colors.black12)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? accent : (isTarget ? accent.withOpacity(0.3) : Colors.transparent),
                                width: 1.5,
                              ),
                              boxShadow: isSelected ? [
                                BoxShadow(
                                  color: accent.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                )
                              ] : [],
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                color: isSelected ? Colors.white : (isTarget ? accent : text),
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),
                    
                    // Actions
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(color: sub, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: canSave ? () => Navigator.pop(context, minutes) : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Save Duration',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

