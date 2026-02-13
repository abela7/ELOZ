import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/models/vibration_pattern.dart';

class HabitVibrationPicker extends StatefulWidget {
  final String currentPatternId;
  final ValueChanged<String> onPatternSelected;

  const HabitVibrationPicker({
    super.key,
    required this.currentPatternId,
    required this.onPatternSelected,
  });

  static Future<String?> show(BuildContext context, String currentPatternId) async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _HabitVibrationPickerSheet(
        currentPatternId: currentPatternId,
      ),
    );
  }

  @override
  State<HabitVibrationPicker> createState() => _HabitVibrationPickerState();
}

class _HabitVibrationPickerState extends State<HabitVibrationPicker> {
  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _HabitVibrationPickerSheet extends StatefulWidget {
  final String currentPatternId;

  const _HabitVibrationPickerSheet({
    required this.currentPatternId,
  });

  @override
  State<_HabitVibrationPickerSheet> createState() => _HabitVibrationPickerSheetState();
}

class _HabitVibrationPickerSheetState extends State<_HabitVibrationPickerSheet> {
  late String _selectedPatternId;
  bool _isVibrating = false;
  String? _vibratingPatternId;

  static const _channel = MethodChannel('com.eloz.life_manager/native_alarm');

  @override
  void initState() {
    super.initState();
    _selectedPatternId = widget.currentPatternId;
  }

  Future<void> _previewVibration(String patternId) async {
    if (_isVibrating && _vibratingPatternId == patternId) {
      await _stopVibration();
      return;
    }

    if (_isVibrating) {
      await _stopVibration();
    }

    if (patternId == 'none') {
      return;
    }

    setState(() {
      _isVibrating = true;
      _vibratingPatternId = patternId;
    });

    try {
      await _channel.invokeMethod('previewVibration', {
        'patternId': patternId,
      });
    } catch (e) {
      debugPrint('Error previewing vibration: $e');
    }

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _vibratingPatternId == patternId) {
        _stopVibration();
      }
    });
  }

  Future<void> _stopVibration() async {
    try {
      await _channel.invokeMethod('stopVibration');
    } catch (e) {
      debugPrint('Error stopping vibration: $e');
    }

    if (mounted) {
      setState(() {
        _isVibrating = false;
        _vibratingPatternId = null;
      });
    }
  }

  @override
  void dispose() {
    _stopVibration();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final patterns = VibrationPattern.all;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.65,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              children: [
                Icon(
                  Icons.vibration_outlined,
                  color: theme.colorScheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Text(
                  'Vibration Pattern',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.3)),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: patterns.length,
              itemBuilder: (context, index) {
                final pattern = patterns[index];
                final isSelected = pattern.id == _selectedPatternId;
                final isVibrating = _vibratingPatternId == pattern.id;

                return _HabitPatternTile(
                  pattern: pattern,
                  isSelected: isSelected,
                  isVibrating: isVibrating,
                  onTap: () {
                    setState(() => _selectedPatternId = pattern.id);
                    Navigator.of(context).pop(pattern.id);
                  },
                  onPreviewTap: () => _previewVibration(pattern.id),
                );
              },
            ),
          ),
          const SafeArea(top: false, child: SizedBox(height: 8)),
        ],
      ),
    );
  }
}

class _HabitPatternTile extends StatelessWidget {
  final VibrationPattern pattern;
  final bool isSelected;
  final bool isVibrating;
  final VoidCallback onTap;
  final VoidCallback onPreviewTap;

  const _HabitPatternTile({
    required this.pattern,
    required this.isSelected,
    required this.isVibrating,
    required this.onTap,
    required this.onPreviewTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: isSelected
          ? theme.colorScheme.primary.withValues(alpha: 0.08)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    width: isSelected ? 6 : 2,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pattern.displayName,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pattern.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 40,
                height: 40,
                child: IconButton(
                  onPressed: onPreviewTap,
                  icon: Icon(
                    isVibrating ? Icons.stop_rounded : Icons.play_arrow_rounded,
                    color: isVibrating
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    size: 22,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: isVibrating
                        ? theme.colorScheme.error.withValues(alpha: 0.1)
                        : theme.colorScheme.onSurface.withValues(alpha: 0.05),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
