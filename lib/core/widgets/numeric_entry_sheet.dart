import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Modern numeric entry sheet for habit logging (e.g., pages, reps).
/// Returns a double value or null if cancelled.
class NumericEntrySheet {
  static Future<double?> show(
    BuildContext context, {
    required String title,
    String? subtitle,
    String? unitLabel,
    double? targetValue,
    Color? accentColor,
    int? Function(double value)? pointsForValue,
  }) async {
    return showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _NumericEntryContent(
        title: title,
        subtitle: subtitle,
        unitLabel: unitLabel,
        targetValue: targetValue,
        accentColor: accentColor,
        pointsForValue: pointsForValue,
      ),
    );
  }
}

class _NumericEntryContent extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String? unitLabel;
  final double? targetValue;
  final Color? accentColor;
  final int? Function(double value)? pointsForValue;

  const _NumericEntryContent({
    required this.title,
    required this.subtitle,
    required this.unitLabel,
    required this.targetValue,
    required this.accentColor,
    required this.pointsForValue,
  });

  @override
  State<_NumericEntryContent> createState() => _NumericEntryContentState();
}

class _NumericEntryContentState extends State<_NumericEntryContent> {
  late final TextEditingController _valueController;
  String? _error;

  @override
  void initState() {
    super.initState();
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
    final value = _parsedValue;
    setState(() {
      _error = (value == null || value <= 0) ? 'Enter a value greater than 0' : null;
    });
  }

  double? get _parsedValue {
    final raw = _valueController.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  void _setPreset(double value) {
    HapticFeedback.selectionClick();
    final display = value == value.truncateToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
    _valueController.text = display;
    _valueController.selection = TextSelection.fromPosition(
      TextPosition(offset: _valueController.text.length),
    );
  }

  List<double> _buildPresets() {
    final target = widget.targetValue;
    if (target != null && target > 0) {
      return <double>[
        target * 0.25,
        target * 0.50,
        target * 0.75,
        target,
        target * 1.5,
      ];
    }
    return const <double>[1, 5, 10, 20, 30, 50];
  }

  bool _isSelected(double? value, double preset) {
    if (value == null) return false;
    return (value - preset).abs() < 0.001;
  }

  String _formatValue(double value) {
    if (value == value.truncateToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E2228) : Colors.white;
    final card = isDark ? const Color(0xFF252A31) : const Color(0xFFF7F7F8);
    final text = isDark ? Colors.white : const Color(0xFF1A1C1E);
    final sub = isDark ? Colors.white70 : const Color(0xFF44474E);
    final accent = widget.accentColor ?? const Color(0xFFCDAF56);
    final value = _parsedValue;
    final canSave = value != null && value > 0;
    final unit = (widget.unitLabel ?? '').trim();
    final unitSuffix = unit.isEmpty ? '' : ' $unit';
    final estimatedPoints = (canSave && widget.pointsForValue != null) ? widget.pointsForValue!(value!) : null;
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
                                  style: TextStyle(color: sub, fontSize: 14, fontWeight: FontWeight.w500),
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
                              Icon(Icons.numbers_rounded, size: 18, color: accent),
                              const SizedBox(width: 8),
                              Text(
                                'VALUE',
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
                              errorText: _error,
                              contentPadding: EdgeInsets.zero,
                              suffixIcon: unit.isEmpty
                                  ? null
                                  : Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: accent.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        unit,
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
                          if (widget.targetValue != null && widget.targetValue! > 0) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Target: ${_formatValue(widget.targetValue!)}$unitSuffix',
                              style: TextStyle(color: sub, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Info Card
                    if (value != null && value > 0)
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
                                  child: Text(
                                    'Logging ${_formatValue(value)}$unitSuffix',
                                    style: TextStyle(color: text, fontWeight: FontWeight.w800, fontSize: 15),
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
                                    style: TextStyle(color: text, fontWeight: FontWeight.w800, fontSize: 15),
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
                      children: presets.map((p) {
                        final label = widget.targetValue != null && widget.targetValue! > 0
                            ? (p == widget.targetValue ? 'Target' : '${((p / widget.targetValue!) * 100).round()}%')
                            : _formatValue(p);
                        final selected = _isSelected(value, p);
                        return InkWell(
                          onTap: () => _setPreset(p),
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
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                        color: accent.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                color: selected ? Colors.white : text,
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
                            child: Text('Cancel', style: TextStyle(color: sub, fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: canSave ? () => Navigator.pop(context, value) : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Save Value',
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
