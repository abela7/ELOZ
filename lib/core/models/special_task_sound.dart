/// Model for special task alarm sounds
/// 
/// These sounds are stored in android/app/src/main/res/raw/
/// and played by the native AlarmPlayerService on the ALARM stream.
class SpecialTaskSound {
  final String id;
  final String displayName;

  const SpecialTaskSound({
    required this.id,
    required this.displayName,
  });

  /// All available special task sounds
  /// Note: sound_1 is identical to alarm (both are the original Alarm.mp3)
  /// sound_5 and sound_6 were duplicates, so sound_6 is removed
  static const List<SpecialTaskSound> all = [
    SpecialTaskSound(
      id: 'alarm',
      displayName: 'Default',
    ),
    SpecialTaskSound(
      id: 'sound_2',
      displayName: 'Sound 1',
    ),
    SpecialTaskSound(
      id: 'sound_3',
      displayName: 'Sound 2',
    ),
    SpecialTaskSound(
      id: 'sound_4',
      displayName: 'Sound 3',
    ),
    SpecialTaskSound(
      id: 'sound_5',
      displayName: 'Sound 4',
    ),
    SpecialTaskSound(
      id: 'sound_7',
      displayName: 'Sound 5',
    ),
    SpecialTaskSound(
      id: 'sound_8',
      displayName: 'Sound 6',
    ),
    SpecialTaskSound(
      id: 'sound_9',
      displayName: 'Sound 7',
    ),
    SpecialTaskSound(
      id: 'sound_10',
      displayName: 'Sound 8',
    ),
  ];

  /// Get sound by ID
  static SpecialTaskSound? getById(String id) {
    try {
      return all.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Get display name for a sound ID
  static String getDisplayName(String id) {
    return getById(id)?.displayName ?? 'Default';
  }

  /// Get the default sound
  static SpecialTaskSound get defaultSound => all.first;
}
