import 'notification_lifecycle_event.dart';

class NotificationLogEntry {
  static int _sequence = 0;

  final String id;
  final String moduleId;
  final String entityId;
  final int? notificationId;
  final String title;
  final String body;
  final String? payload;
  final String? channelKey;
  final String? soundKey;
  final String? actionId;
  final NotificationLifecycleEvent event;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  const NotificationLogEntry({
    required this.id,
    required this.moduleId,
    required this.entityId,
    required this.notificationId,
    required this.title,
    required this.body,
    required this.payload,
    required this.channelKey,
    required this.soundKey,
    required this.actionId,
    required this.event,
    required this.timestamp,
    this.metadata = const <String, dynamic>{},
  });

  factory NotificationLogEntry.create({
    required String moduleId,
    required String entityId,
    int? notificationId,
    String title = '',
    String body = '',
    String? payload,
    String? channelKey,
    String? soundKey,
    String? actionId,
    required NotificationLifecycleEvent event,
    DateTime? timestamp,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) {
    final eventTime = timestamp ?? DateTime.now();
    _sequence = (_sequence + 1) % 1000000;
    final id = '${eventTime.microsecondsSinceEpoch}-$_sequence';

    return NotificationLogEntry(
      id: id,
      moduleId: moduleId,
      entityId: entityId,
      notificationId: notificationId,
      title: title,
      body: body,
      payload: payload,
      channelKey: channelKey,
      soundKey: soundKey,
      actionId: actionId,
      event: event,
      timestamp: eventTime,
      metadata: metadata,
    );
  }

  factory NotificationLogEntry.fromJson(Map<String, dynamic> json) {
    final event =
        notificationLifecycleEventFromStorage(json['event'] as String?) ??
        NotificationLifecycleEvent.failed;

    DateTime timestamp;
    final rawTimestamp = json['timestamp'];
    if (rawTimestamp is String && rawTimestamp.isNotEmpty) {
      timestamp = DateTime.tryParse(rawTimestamp) ?? DateTime.now();
    } else if (rawTimestamp is int) {
      timestamp = DateTime.fromMillisecondsSinceEpoch(rawTimestamp);
    } else {
      timestamp = DateTime.now();
    }

    return NotificationLogEntry(
      id: json['id'] as String? ?? '${timestamp.microsecondsSinceEpoch}',
      moduleId: json['moduleId'] as String? ?? 'unknown',
      entityId: json['entityId'] as String? ?? '',
      notificationId: (json['notificationId'] as num?)?.toInt(),
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      payload: json['payload'] as String?,
      channelKey: json['channelKey'] as String?,
      soundKey: json['soundKey'] as String?,
      actionId: json['actionId'] as String?,
      event: event,
      timestamp: timestamp,
      metadata: json['metadata'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['metadata'] as Map<String, dynamic>)
          : const <String, dynamic>{},
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'moduleId': moduleId,
      'entityId': entityId,
      'notificationId': notificationId,
      'title': title,
      'body': body,
      'payload': payload,
      'channelKey': channelKey,
      'soundKey': soundKey,
      'actionId': actionId,
      'event': event.name,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
    };
  }
}
