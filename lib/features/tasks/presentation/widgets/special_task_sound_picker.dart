import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/models/special_task_sound.dart';

/// Professional bottom sheet picker for special task alarm sounds
class SpecialTaskSoundPicker extends StatefulWidget {
  final String currentSoundId;
  final ValueChanged<String> onSoundSelected;

  const SpecialTaskSoundPicker({
    super.key,
    required this.currentSoundId,
    required this.onSoundSelected,
  });

  /// Show the picker as a bottom sheet
  static Future<String?> show(BuildContext context, String currentSoundId) async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SpecialTaskSoundPickerSheet(
        currentSoundId: currentSoundId,
      ),
    );
  }

  @override
  State<SpecialTaskSoundPicker> createState() => _SpecialTaskSoundPickerState();
}

class _SpecialTaskSoundPickerState extends State<SpecialTaskSoundPicker> {
  late String _selectedSoundId;
  bool _isPlaying = false;
  String? _playingSoundId;

  static const _channel = MethodChannel('com.eloz.life_manager/native_alarm');

  @override
  void initState() {
    super.initState();
    _selectedSoundId = widget.currentSoundId;
  }

  Future<void> _playSound(String soundId) async {
    if (_isPlaying) {
      await _stopSound();
    }

    setState(() {
      _isPlaying = true;
      _playingSoundId = soundId;
    });

    try {
      await _channel.invokeMethod('previewSound', {
        'soundId': soundId,
      });
    } catch (e) {
      debugPrint('Error playing sound preview: $e');
    }

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _playingSoundId == soundId) {
        _stopSound();
      }
    });
  }

  Future<void> _stopSound() async {
    try {
      await _channel.invokeMethod('stopAlarm');
    } catch (e) {
      debugPrint('Error stopping sound: $e');
    }

    if (mounted) {
      setState(() {
        _isPlaying = false;
        _playingSoundId = null;
      });
    }
  }

  @override
  void dispose() {
    _stopSound();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

/// Bottom sheet wrapper
class _SpecialTaskSoundPickerSheet extends StatefulWidget {
  final String currentSoundId;

  const _SpecialTaskSoundPickerSheet({
    required this.currentSoundId,
  });

  @override
  State<_SpecialTaskSoundPickerSheet> createState() => _SpecialTaskSoundPickerSheetState();
}

class _SpecialTaskSoundPickerSheetState extends State<_SpecialTaskSoundPickerSheet> {
  late String _selectedSoundId;
  bool _isPlaying = false;
  String? _playingSoundId;

  static const _channel = MethodChannel('com.eloz.life_manager/native_alarm');

  @override
  void initState() {
    super.initState();
    _selectedSoundId = widget.currentSoundId;
  }

  Future<void> _playSound(String soundId) async {
    if (_isPlaying && _playingSoundId == soundId) {
      await _stopSound();
      return;
    }
    
    if (_isPlaying) {
      await _stopSound();
    }

    setState(() {
      _isPlaying = true;
      _playingSoundId = soundId;
    });

    try {
      await _channel.invokeMethod('previewSound', {
        'soundId': soundId,
      });
    } catch (e) {
      debugPrint('Error playing sound preview: $e');
    }

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _playingSoundId == soundId) {
        _stopSound();
      }
    });
  }

  Future<void> _stopSound() async {
    try {
      await _channel.invokeMethod('stopAlarm');
    } catch (e) {
      debugPrint('Error stopping sound: $e');
    }

    if (mounted) {
      setState(() {
        _isPlaying = false;
        _playingSoundId = null;
      });
    }
  }

  @override
  void dispose() {
    _stopSound();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sounds = SpecialTaskSound.all;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
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

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              children: [
                Icon(
                  Icons.notifications_active_outlined,
                  color: theme.colorScheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Text(
                  'Special Task Tone',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.3)),

          // Sound list
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: sounds.length,
              itemBuilder: (context, index) {
                final sound = sounds[index];
                final isSelected = sound.id == _selectedSoundId;
                final isPlaying = _playingSoundId == sound.id;

                return _SoundTile(
                  sound: sound,
                  isSelected: isSelected,
                  isPlaying: isPlaying,
                  onTap: () {
                    setState(() => _selectedSoundId = sound.id);
                    Navigator.of(context).pop(sound.id);
                  },
                  onPlayTap: () => _playSound(sound.id),
                );
              },
            ),
          ),

          SafeArea(
            top: false,
            child: const SizedBox(height: 8),
          ),
        ],
      ),
    );
  }
}

/// Individual sound tile - clean professional design
class _SoundTile extends StatelessWidget {
  final SpecialTaskSound sound;
  final bool isSelected;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onPlayTap;

  const _SoundTile({
    required this.sound,
    required this.isSelected,
    required this.isPlaying,
    required this.onTap,
    required this.onPlayTap,
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
              // Radio indicator
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

              // Name
              Expanded(
                child: Text(
                  sound.displayName,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),

              // Play/Stop button
              SizedBox(
                width: 40,
                height: 40,
                child: IconButton(
                  onPressed: onPlayTap,
                  icon: Icon(
                    isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                    color: isPlaying 
                        ? theme.colorScheme.error 
                        : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    size: 22,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: isPlaying
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
