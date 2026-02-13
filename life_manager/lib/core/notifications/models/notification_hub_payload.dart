class NotificationHubPayload {
  final String moduleId;
  final String entityId;
  final String reminderType;
  final String reminderValue;
  final String reminderUnit;
  final Map<String, String> extras;

  const NotificationHubPayload({
    required this.moduleId,
    required this.entityId,
    this.reminderType = 'at_time',
    this.reminderValue = '0',
    this.reminderUnit = 'minutes',
    this.extras = const <String, String>{},
  });

  bool get isValid => moduleId.isNotEmpty && entityId.isNotEmpty;

  String toRaw() {
    final parts = <String>[
      moduleId,
      entityId,
      reminderType,
      reminderValue,
      reminderUnit,
    ];

    if (extras.isNotEmpty) {
      final sortedKeys = extras.keys.toList()..sort();
      for (final key in sortedKeys) {
        final value = extras[key];
        if (value == null || key.isEmpty) {
          continue;
        }
        parts.add('$key:$value');
      }
    }

    return parts.join('|');
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'moduleId': moduleId,
      'entityId': entityId,
      'reminderType': reminderType,
      'reminderValue': reminderValue,
      'reminderUnit': reminderUnit,
      'extras': extras,
      'raw': toRaw(),
    };
  }

  static NotificationHubPayload? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final parts = raw.split('|');
    if (parts.length < 2) {
      return null;
    }

    final moduleId = parts[0].trim();
    final entityId = parts[1].trim();
    if (moduleId.isEmpty || entityId.isEmpty) {
      return null;
    }

    final reminderType = parts.length >= 3 && parts[2].trim().isNotEmpty
        ? parts[2].trim()
        : 'at_time';
    final reminderValue = parts.length >= 4 && parts[3].trim().isNotEmpty
        ? parts[3].trim()
        : '0';
    final reminderUnit = parts.length >= 5 && parts[4].trim().isNotEmpty
        ? parts[4].trim()
        : 'minutes';

    final extras = <String, String>{};
    if (parts.length > 5) {
      for (final token in parts.sublist(5)) {
        if (token.trim().isEmpty) {
          continue;
        }
        final separatorIndex = token.indexOf(':');
        if (separatorIndex <= 0) {
          continue;
        }
        final key = token.substring(0, separatorIndex).trim();
        final value = token.substring(separatorIndex + 1).trim();
        if (key.isEmpty) {
          continue;
        }
        extras[key] = value;
      }
    }

    return NotificationHubPayload(
      moduleId: moduleId,
      entityId: entityId,
      reminderType: reminderType,
      reminderValue: reminderValue,
      reminderUnit: reminderUnit,
      extras: extras,
    );
  }
}
