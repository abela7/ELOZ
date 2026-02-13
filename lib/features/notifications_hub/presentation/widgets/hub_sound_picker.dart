import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/models/notification_settings.dart';
import '../../../../core/models/special_task_sound.dart';
import '../../../../core/services/android_system_status.dart';
import '../../../../core/theme/color_schemes.dart';

/// Full-featured sound picker for the Notification Hub.
///
/// Two modes, exactly like the Task notification settings:
///   1. **Device Tones** – opens the native Android RingtoneManager picker
///      and returns a `content://` URI.
///   2. **App Sounds** – pre-uploaded alarm/notification sounds stored in
///      `res/raw/`, played via native AlarmPlayerService.
///
/// The picked value is returned as a `String`:
///   - `content://…` for device tones
///   - Sound ID (e.g. `'alarm'`, `'sound_2'`) for app sounds
///   - `'default'` for the system default
///   - `'silent'` for no sound
///   - `null` if cancelled
class HubSoundPicker extends StatefulWidget {
  final String currentSoundId;
  final ValueChanged<String> onSoundSelected;

  const HubSoundPicker({
    super.key,
    required this.currentSoundId,
    required this.onSoundSelected,
  });

  /// Shows the sound picker and returns the selected sound id/URI.
  static Future<String?> show(
    BuildContext context, {
    required String currentSoundId,
    String title = 'Notification Tone',
  }) async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _HubSoundPickerSheet(
        currentSoundId: currentSoundId,
        title: title,
      ),
    );
  }

  @override
  State<HubSoundPicker> createState() => _HubSoundPickerState();
}

class _HubSoundPickerState extends State<HubSoundPicker> {
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// ═══════════════════════════════════════════════════════════════════════════════
// Sheet
// ═══════════════════════════════════════════════════════════════════════════════

class _HubSoundPickerSheet extends StatefulWidget {
  final String currentSoundId;
  final String title;

  const _HubSoundPickerSheet({
    required this.currentSoundId,
    required this.title,
  });

  @override
  State<_HubSoundPickerSheet> createState() => _HubSoundPickerSheetState();
}

class _HubSoundPickerSheetState extends State<_HubSoundPickerSheet>
    with SingleTickerProviderStateMixin {
  late String _selectedSoundId;
  bool _isPlaying = false;
  String? _playingSoundId;
  late TabController _tabController;

  static const _channel = MethodChannel('com.eloz.life_manager/native_alarm');
  static const _gold = AppColorSchemes.primaryGold;

  @override
  void initState() {
    super.initState();
    _selectedSoundId = widget.currentSoundId;
    // Auto-select tab: if current sound is a content:// URI, show Device tab
    final isDeviceTone = _selectedSoundId.startsWith('content://') ||
        _selectedSoundId == 'default' ||
        _selectedSoundId == 'silent';
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: isDeviceTone ? 0 : 1,
    );
  }

  @override
  void dispose() {
    _stopSound();
    _tabController.dispose();
    super.dispose();
  }

  // ── Sound playback ──────────────────────────────────────────────────────

  Future<void> _playSound(String soundId) async {
    if (_isPlaying && _playingSoundId == soundId) {
      await _stopSound();
      return;
    }
    try {
      await _stopSound();
      setState(() {
        _isPlaying = true;
        _playingSoundId = soundId;
      });
      await _channel.invokeMethod('previewSound', {'soundId': soundId});
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted && _isPlaying && _playingSoundId == soundId) {
          _stopSound();
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _playingSoundId = null;
        });
      }
    }
  }

  Future<void> _stopSound() async {
    try {
      await _channel.invokeMethod('stopAlarm');
    } catch (_) {}
    if (mounted) {
      setState(() {
        _isPlaying = false;
        _playingSoundId = null;
      });
    }
  }

  // ── Device tone picker (native Android) ─────────────────────────────────

  Future<void> _pickDeviceTone() async {
    if (!Platform.isAndroid) return;

    final currentUri = _selectedSoundId.startsWith('content://')
        ? _selectedSoundId
        : null;

    final picked = await AndroidSystemStatus.pickNotificationSound(
      currentUri: currentUri,
    );
    final uri = picked['uri'] as String?;

    if (uri == null || uri.isEmpty) return; // user cancelled

    if (mounted) {
      setState(() => _selectedSoundId = uri);
      Navigator.of(context).pop(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D23) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _gold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.music_note_rounded, color: _gold, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Tab bar: Device Tones / App Sounds
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: _gold.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _gold, width: 1),
              ),
              labelColor: _gold,
              unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              dividerHeight: 0,
              tabs: const [
                Tab(text: 'Device Tones'),
                Tab(text: 'App Sounds'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Divider(
            height: 1,
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDeviceTonesTab(isDark),
                _buildAppSoundsTab(isDark),
              ],
            ),
          ),

          // Bottom safe area
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  // ── Device Tones tab ────────────────────────────────────────────────────

  Widget _buildDeviceTonesTab(bool isDark) {
    final isDeviceSelected = _selectedSoundId.startsWith('content://');
    final deviceSoundName = isDeviceSelected
        ? NotificationSettings.getSoundDisplayName(_selectedSoundId)
        : null;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Current device tone (if set)
        if (isDeviceSelected) ...[
          _buildCurrentDeviceTone(deviceSoundName ?? 'Custom Tone', isDark),
          const SizedBox(height: 16),
        ],

        // Open system picker button
        _buildActionButton(
          icon: Icons.phone_android_rounded,
          title: 'Choose from device',
          subtitle: 'Open system notification sound picker',
          color: Colors.blue,
          isDark: isDark,
          onTap: _pickDeviceTone,
        ),
        const SizedBox(height: 12),

        // Quick options
        _buildQuickOption(
          id: 'default',
          title: 'System Default',
          subtitle: 'Use device default notification tone',
          icon: Icons.notifications_rounded,
          isDark: isDark,
        ),
        const SizedBox(height: 8),
        _buildQuickOption(
          id: 'silent',
          title: 'Silent',
          subtitle: 'No sound',
          icon: Icons.volume_off_rounded,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildCurrentDeviceTone(String name, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _gold.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _gold.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _gold.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.graphic_eq_rounded, color: _gold, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Tone',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _gold.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _gold,
                  ),
                ),
              ],
            ),
          ),
          // Preview button
          IconButton(
            onPressed: () => _playSound(_selectedSoundId),
            icon: Icon(
              _isPlaying && _playingSoundId == _selectedSoundId
                  ? Icons.stop_rounded
                  : Icons.play_arrow_rounded,
              color: _gold,
            ),
            style: IconButton.styleFrom(
              backgroundColor: _gold.withOpacity(0.15),
              padding: const EdgeInsets.all(8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickOption({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isDark,
  }) {
    final isSelected = _selectedSoundId == id;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedSoundId = id);
        Navigator.of(context).pop(id);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? _gold.withOpacity(0.1)
              : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.025)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _gold : (isDark ? Colors.white12 : Colors.black12),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20,
              color: isSelected ? _gold : (isDark ? Colors.white54 : Colors.black54)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: isSelected ? _gold : (isDark ? Colors.white : Colors.black87),
                  )),
                  Text(subtitle, style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.black38,
                  )),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, size: 20, color: _gold),
          ],
        ),
      ),
    );
  }

  // ── App Sounds tab ──────────────────────────────────────────────────────

  Widget _buildAppSoundsTab(bool isDark) {
    final sounds = SpecialTaskSound.all;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: sounds.length,
      itemBuilder: (context, index) {
        final sound = sounds[index];
        final isSelected = sound.id == _selectedSoundId;
        final isPlaying = _isPlaying && _playingSoundId == sound.id;
        return _AppSoundTile(
          sound: sound,
          isSelected: isSelected,
          isPlaying: isPlaying,
          isDark: isDark,
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _selectedSoundId = sound.id);
            Navigator.of(context).pop(sound.id);
          },
          onPlayTap: () => _playSound(sound.id),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// App Sound Tile
// ═══════════════════════════════════════════════════════════════════════════════

class _AppSoundTile extends StatelessWidget {
  final SpecialTaskSound sound;
  final bool isSelected;
  final bool isPlaying;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onPlayTap;

  const _AppSoundTile({
    required this.sound,
    required this.isSelected,
    required this.isPlaying,
    required this.isDark,
    required this.onTap,
    required this.onPlayTap,
  });

  static const _gold = AppColorSchemes.primaryGold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? _gold.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(color: _gold, width: 1.5)
                : null,
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: isSelected ? _gold : (isDark ? Colors.white38 : Colors.black38),
                size: 22,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  sound.displayName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? _gold : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
              ),
              // Preview button
              IconButton(
                icon: Icon(
                  isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                  color: isPlaying ? Colors.red : (isDark ? Colors.white54 : Colors.black54),
                  size: 22,
                ),
                onPressed: onPlayTap,
                tooltip: isPlaying ? 'Stop' : 'Preview',
                style: IconButton.styleFrom(
                  backgroundColor: (isPlaying ? Colors.red : (isDark ? Colors.white : Colors.black))
                      .withOpacity(0.08),
                  padding: const EdgeInsets.all(6),
                  minimumSize: const Size(34, 34),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
