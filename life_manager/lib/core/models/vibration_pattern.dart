/// Model for vibration patterns
/// 
/// Vibration patterns are defined as [pause, vibrate, pause, vibrate...] in milliseconds.
/// The native AlarmPlayerService uses these patterns for special task alarms.
class VibrationPattern {
  final String id;
  final String displayName;
  final String description;
  
  /// Pattern in milliseconds: [pause, vibrate, pause, vibrate...]
  final List<int> pattern;

  const VibrationPattern({
    required this.id,
    required this.displayName,
    required this.description,
    required this.pattern,
  });

  /// All available vibration patterns
  static const List<VibrationPattern> all = [
    VibrationPattern(
      id: 'default',
      displayName: 'Gentle Wave',
      description: 'Smooth flowing rhythm',
      pattern: [0, 100, 200, 200, 200, 400, 200, 200, 200, 100, 1000],
    ),
    VibrationPattern(
      id: 'echo',
      displayName: 'Echo Beat',
      description: 'Melodic triple-pulse echo',
      pattern: [0, 300, 150, 100, 100, 100, 800],
    ),
    VibrationPattern(
      id: 'rise',
      displayName: 'Soft Rise',
      description: 'Gradually intensifying rhythm',
      pattern: [0, 50, 200, 100, 200, 200, 200, 400, 800],
    ),
    VibrationPattern(
      id: 'dance',
      displayName: 'Rhythmic Dance',
      description: 'Modern syncopated melody',
      pattern: [0, 150, 100, 150, 200, 300, 100, 150, 800],
    ),
    VibrationPattern(
      id: 'serene',
      displayName: 'Serene Pulse',
      description: 'Calm and steady breathing',
      pattern: [0, 600, 400, 600, 400, 1000],
    ),
    VibrationPattern(
      id: 'chime',
      displayName: 'Modern Chime',
      description: 'Musical three-tone haptic',
      pattern: [0, 100, 200, 150, 200, 200, 1000],
    ),
    VibrationPattern(
      id: 'accent',
      displayName: 'Elegant Accent',
      description: 'Minimalist melodic touch',
      pattern: [0, 100, 150, 100, 800],
    ),
    VibrationPattern(
      id: 'none',
      displayName: 'None',
      description: 'No vibration',
      pattern: [],
    ),
  ];

  /// Get pattern by ID
  static VibrationPattern? getById(String id) {
    try {
      return all.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Get display name for a pattern ID
  static String getDisplayName(String id) {
    return getById(id)?.displayName ?? 'Default';
  }

  /// Get description for a pattern ID
  static String getDescription(String id) {
    return getById(id)?.description ?? 'Standard vibration pattern';
  }

  /// Get pattern array for a pattern ID
  static List<int> getPattern(String id) {
    return getById(id)?.pattern ?? all.first.pattern;
  }

  /// Get the default pattern
  static VibrationPattern get defaultPattern => all.first;
}
