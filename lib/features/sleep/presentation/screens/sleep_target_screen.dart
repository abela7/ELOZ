import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/dark_gradient.dart';
import '../../../../core/widgets/color_picker_widget.dart';
import '../../../../core/widgets/icon_picker_widget.dart';
import '../../data/services/sleep_target_service.dart';
import '../providers/sleep_providers.dart';

/// Screen to configure single sleep target and status thresholds.
/// All records are compared against these settings.
class SleepTargetScreen extends ConsumerStatefulWidget {
  const SleepTargetScreen({super.key});

  @override
  ConsumerState<SleepTargetScreen> createState() => _SleepTargetScreenState();
}

class _SleepTargetScreenState extends ConsumerState<SleepTargetScreen> {
  late double _targetHours;
  late double _dangerousMax;
  late double _poorMax;
  late double _fairMax;
  late double _oversleptAbove;
  late double _healthyMin;
  late double _healthyMax;
  bool _autoCalculateHealthy = true;
  bool _isLoading = true;
  Map<SleepStatus, SleepStatusStyle> _statusStyles = {};

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final service = ref.read(sleepTargetServiceProvider);
    final s = await service.getSettings();
    if (mounted) {
      setState(() {
        _targetHours = s.targetHours;
        _dangerousMax = s.dangerousMax;
        _poorMax = s.poorMax;
        _fairMax = s.fairMax;
        _oversleptAbove = s.oversleptAbove;
        _healthyMin = s.healthyMin;
        _healthyMax = s.healthyMax;
        _autoCalculateHealthy = s.autoCalculateHealthy;
        _statusStyles = Map.from(s.statusStyles);
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    HapticFeedback.mediumImpact();
    double d = _dangerousMax.clamp(2.0, 6.0);
    double p = _poorMax.clamp(4.0, 9.0);
    double f = _fairMax.clamp(5.0, 11.0);
    double o = _oversleptAbove.clamp(6.0, 12.0);
    double hm = _healthyMin.clamp(5.0, 12.0);
    double hx = _healthyMax.clamp(6.0, 12.0);
    if (d >= p) p = d + 0.5;
    if (p >= f) f = p + 0.5;
    if (d >= p) p = d + 0.5;
    if (f >= o) o = f + 0.5;
    if (p >= f) f = p + 0.5;
    if (!_autoCalculateHealthy) {
      if (hm < f) hm = f;
      if (hx <= hm) hx = hm + 0.5;
      if (o < hx) o = hx;
    } else {
      hm = f;
      hx = o;
    }
    final service = ref.read(sleepTargetServiceProvider);
    await service.saveSettings(SleepTargetSettings(
      targetHours: _targetHours.clamp(4.0, 12.0),
      dangerousMax: d,
      poorMax: p,
      fairMax: f,
      oversleptAbove: o,
      autoCalculateHealthy: _autoCalculateHealthy,
      healthyMin: hm,
      healthyMax: hx,
      statusStyles: _statusStyles,
    ));
    if (mounted) setState(() {
      _dangerousMax = d; _poorMax = p; _fairMax = f; _oversleptAbove = o;
      _healthyMin = hm; _healthyMax = hx;
    });
    ref.invalidate(sleepTargetSettingsProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sleep target saved'),
          backgroundColor: Color(0xFFCDAF56),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  String _fmt(double h) {
    final hi = h.floor();
    final m = ((h - hi) * 60).round();
    return m == 0 ? '${hi}h' : '${hi}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: isDark
          ? DarkGradient.wrap(child: _buildContent(context, isDark))
          : _buildContent(context, isDark),
    );
  }

  Widget _buildContent(BuildContext context, bool isDark) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Sleep Target'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Your sleep target is compared against every record.',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
                const SizedBox(height: 24),

                _buildSlider(isDark, 'Target', _targetHours, 4, 12, (v) {
                  setState(() => _targetHours = v);
                }),
                const SizedBox(height: 20),

                _buildSlider(isDark, 'Dangerous (below)', _dangerousMax, 2, 6, (v) {
                  setState(() => _dangerousMax = v);
                }),
                const SizedBox(height: 20),

                _buildSlider(isDark, 'Poor (below)', _poorMax, 4, 9, (v) {
                  setState(() => _poorMax = v);
                }),
                const SizedBox(height: 20),

                _buildSlider(isDark, 'Fair (below)', _fairMax, 5, 11, (v) {
                  setState(() => _fairMax = v);
                }),
                const SizedBox(height: 20),

                _buildAutoCalculateSwitch(isDark),
                const SizedBox(height: 8),

                if (_autoCalculateHealthy) ...[
                  _buildHealthyAutoCard(isDark),
                ] else ...[
                  _buildSlider(isDark, 'Healthy (from)', _healthyMin, _fairMax.clamp(5.0, 12.0), 12, (v) {
                    setState(() => _healthyMin = v);
                  }),
                  const SizedBox(height: 20),
                  _buildSlider(isDark, 'Healthy (to)', _healthyMax, _healthyMin.clamp(6.0, 12.0), 12, (v) {
                    setState(() => _healthyMax = v);
                  }),
                ],
                const SizedBox(height: 20),

                _buildOversleepCard(isDark),
                const SizedBox(height: 24),

                _buildStatusAppearanceSection(isDark),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFCDAF56),
                      foregroundColor: const Color(0xFF1E1E1E),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildAutoCalculateSwitch(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark ? null : [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Auto calculate healthy',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'When on: healthy = Fair to Oversleep (e.g. 7h–8h)',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _autoCalculateHealthy,
            onChanged: (v) => setState(() => _autoCalculateHealthy = v),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthyAutoCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark ? null : [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              'Healthy (auto: Fair → Oversleep)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${_fmt(_fairMax)} — ${_fmt(_oversleptAbove)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFFCDAF56),
            ),
          ),
        ],
      ),
    );
  }

  String _statusDisplayName(SleepStatus s) {
    switch (s) {
      case SleepStatus.dangerous: return 'Dangerous';
      case SleepStatus.poor: return 'Poor';
      case SleepStatus.fair: return 'Fair';
      case SleepStatus.healthy: return 'Healthy';
      case SleepStatus.extended: return 'Extended';
      case SleepStatus.overslept: return 'Overslept';
    }
  }

  Widget _buildStatusAppearanceSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark ? null : [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Status appearance',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Assign color and icon for each target status',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
          const SizedBox(height: 12),
          ...SleepStatus.values.map((s) {
            final style = _statusStyles[s] ?? SleepTargetService.defaultStyleFor(s);
            return _buildStatusStyleRow(isDark, s, style);
          }),
        ],
      ),
    );
  }

  Widget _buildStatusStyleRow(bool isDark, SleepStatus status, SleepStatusStyle style) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _showStatusStylePicker(context, isDark, status, style),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: style.color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(style.iconData, size: 18, color: style.color),
              ),
              const SizedBox(width: 12),
              Text(
                _statusDisplayName(status),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const Spacer(),
              Icon(Icons.edit_rounded, size: 16, color: isDark ? Colors.white38 : Colors.black38),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showStatusStylePicker(
    BuildContext context,
    bool isDark,
    SleepStatus status,
    SleepStatusStyle current,
  ) async {
    Color selectedColor = current.color;
    IconData selectedIcon = current.iconData;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text(_statusDisplayName(status)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: selectedColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: selectedColor, width: 2),
                      ),
                      child: Icon(selectedIcon, size: 48, color: selectedColor),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () async {
                    HapticFeedback.selectionClick();
                    final color = await showDialog<Color>(
                      context: ctx,
                      builder: (c) => ColorPickerWidget(
                        selectedColor: selectedColor,
                        isDark: isDark,
                      ),
                    );
                    if (color != null) {
                      setDialogState(() => selectedColor = color);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.white24 : Colors.black12,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: selectedColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: selectedColor.computeLuminance() > 0.5
                                  ? Colors.black26
                                  : Colors.white24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Change color',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.chevron_right_rounded,
                            color: isDark ? Colors.white38 : Colors.black38),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () async {
                    HapticFeedback.selectionClick();
                    final icon = await showDialog<IconData>(
                      context: ctx,
                      builder: (c) => IconPickerWidget(
                        selectedIcon: selectedIcon,
                        isDark: isDark,
                      ),
                    );
                    if (icon != null) {
                      setDialogState(() => selectedIcon = icon);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.white24 : Colors.black12,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: selectedColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(selectedIcon, size: 24, color: selectedColor),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Change icon',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.chevron_right_rounded,
                            color: isDark ? Colors.white38 : Colors.black38),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _statusStyles[status] = SleepStatusStyle(
          colorValue: selectedColor.value,
          iconCodePoint: selectedIcon.codePoint,
        );
      });
      // Persist immediately so dashboard/record cards stay in sync
      if (mounted) {
        final service = ref.read(sleepTargetServiceProvider);
        await service.saveSettings(SleepTargetSettings(
          targetHours: _targetHours,
          dangerousMax: _dangerousMax,
          poorMax: _poorMax,
          fairMax: _fairMax,
          oversleptAbove: _oversleptAbove,
          autoCalculateHealthy: _autoCalculateHealthy,
          healthyMin: _healthyMin,
          healthyMax: _healthyMax,
          statusStyles: _statusStyles,
        ));
        ref.invalidate(sleepTargetSettingsProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Status appearance saved'),
              backgroundColor: Color(0xFFCDAF56),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Widget _buildOversleepCard(bool isDark) {
    final minVal = (_autoCalculateHealthy ? _fairMax : _healthyMax).clamp(6.0, 12.0);
    final value = _oversleptAbove < minVal ? minVal : _oversleptAbove;
    return _buildSlider(
      isDark,
      'Oversleep (above)',
      value,
      minVal,
      12,
      (v) => setState(() => _oversleptAbove = v),
    );
  }

  Widget _buildSlider(
    bool isDark,
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark ? null : [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _fmt(value),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFCDAF56),
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: ((max - min) * 4).round().clamp(8, 40),
            activeColor: const Color(0xFFCDAF56),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
