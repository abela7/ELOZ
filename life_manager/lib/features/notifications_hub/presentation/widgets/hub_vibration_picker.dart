import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/models/vibration_pattern.dart';

/// Unified vibration pattern picker for any module in the Notification Hub.
///
/// Usage:
/// ```dart
/// final selected = await HubVibrationPicker.show(
///   context,
///   currentPatternId: 'default',
///   title: 'Vibration Pattern',
/// );
/// ```
class HubVibrationPicker extends StatefulWidget {
  final String currentPatternId;
  final ValueChanged<String> onPatternSelected;

  const HubVibrationPicker({
    super.key,
    required this.currentPatternId,
    required this.onPatternSelected,
  });

  /// Shows the vibration picker bottom sheet and returns the selected pattern id.
  static Future<String?> show(
    BuildContext context, {
    required String currentPatternId,
    String title = 'Vibration Pattern',
  }) async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _HubVibrationPickerSheet(
        currentPatternId: currentPatternId,
        title: title,
      ),
    );
  }

  @override
  State<HubVibrationPicker> createState() => _HubVibrationPickerState();
}

class _HubVibrationPickerState extends State<HubVibrationPicker> {
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// ---------------------------------------------------------------------------
// Sheet
// ---------------------------------------------------------------------------

class _HubVibrationPickerSheet extends StatefulWidget {
  final String currentPatternId;
  final String title;

  const _HubVibrationPickerSheet({
    required this.currentPatternId,
    required this.title,
  });

  @override
  State<_HubVibrationPickerSheet> createState() =>
      _HubVibrationPickerSheetState();
}

class _HubVibrationPickerSheetState extends State<_HubVibrationPickerSheet> {
  late String _selectedPatternId;
  bool _isVibrating = false;
  String? _vibratingPatternId;

  static const _channel = MethodChannel('com.eloz.life_manager/native_alarm');

  @override
  void initState() {
    super.initState();
    _selectedPatternId = widget.currentPatternId;
  }

  @override
  void dispose() {
    _stopVibration();
    super.dispose();
  }

  Future<void> _previewVibration(String patternId) async {
    if (patternId == 'none') return;
    if (_isVibrating && _vibratingPatternId == patternId) {
      await _stopVibration();
      return;
    }
    try {
      await _stopVibration();
      setState(() {
        _isVibrating = true;
        _vibratingPatternId = patternId;
      });
      await _channel
          .invokeMethod('previewVibration', {'patternId': patternId});
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _isVibrating && _vibratingPatternId == patternId) {
          _stopVibration();
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isVibrating = false;
          _vibratingPatternId = null;
        });
      }
    }
  }

  Future<void> _stopVibration() async {
    try {
      await _channel.invokeMethod('stopVibration');
    } catch (_) {}
    if (mounted) {
      setState(() {
        _isVibrating = false;
        _vibratingPatternId = null;
      });
    }
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
          const SizedBox(height: 8),
          // Handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  Icons.vibration_outlined,
                  color: theme.colorScheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  widget.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Divider(
            height: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: patterns.length,
              itemBuilder: (context, index) {
                final pattern = patterns[index];
                final isSelected = pattern.id == _selectedPatternId;
                final isVibrating =
                    _isVibrating && _vibratingPatternId == pattern.id;
                return _PatternTile(
                  pattern: pattern,
                  isSelected: isSelected,
                  isVibrating: isVibrating,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedPatternId = pattern.id);
                    Navigator.of(context).pop(pattern.id);
                  },
                  onPreviewTap: () => _previewVibration(pattern.id),
                );
              },
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tile
// ---------------------------------------------------------------------------

class _PatternTile extends StatelessWidget {
  final VibrationPattern pattern;
  final bool isSelected;
  final bool isVibrating;
  final VoidCallback onTap;
  final VoidCallback onPreviewTap;

  const _PatternTile({
    required this.pattern,
    required this.isSelected,
    required this.isVibrating,
    required this.onTap,
    required this.onPreviewTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNone = pattern.id == 'none';

    return ListTile(
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
        size: 22,
      ),
      title: Text(
        pattern.displayName,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        pattern.description,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: isNone
          ? null
          : IconButton(
              icon: Icon(
                isVibrating ? Icons.stop_rounded : Icons.vibration,
                color: isVibrating
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant,
              ),
              onPressed: onPreviewTap,
              tooltip: isVibrating ? 'Stop' : 'Preview',
            ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }
}
