import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Structured debug tracing for notification scheduling/cancellation flows.
///
/// Output format:
/// `NOTIF_TRACE {"event":"...","sourceFlow":"...","..."}`
class NotificationFlowTrace {
  NotificationFlowTrace._();

  static const int _maxBufferedEvents = 500;
  static final List<Map<String, dynamic>> _recentEvents =
      <Map<String, dynamic>>[];

  static void log({
    required String event,
    String sourceFlow = 'unknown',
    String? moduleId,
    String? entityId,
    String? reason,
    int? notificationId,
    List<int>? notificationIds,
    Map<String, dynamic>? details,
  }) {
    if (!kDebugMode) return;

    final payload = <String, dynamic>{
      'event': event,
      'sourceFlow': sourceFlow,
      'timestamp': DateTime.now().toIso8601String(),
      if (moduleId != null && moduleId.isNotEmpty) 'moduleId': moduleId,
      if (entityId != null && entityId.isNotEmpty) 'entityId': entityId,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
      if (notificationId != null) 'notificationId': notificationId,
      if (notificationIds != null && notificationIds.isNotEmpty)
        'notificationIds': notificationIds,
      if (details != null && details.isNotEmpty) 'details': details,
    };

    _recentEvents.add(Map<String, dynamic>.from(payload));
    if (_recentEvents.length > _maxBufferedEvents) {
      _recentEvents.removeRange(0, _recentEvents.length - _maxBufferedEvents);
    }

    debugPrint('NOTIF_TRACE ${jsonEncode(payload)}');
  }

  static List<Map<String, dynamic>> recentEvents({
    String? event,
    String? moduleId,
    String? entityId,
    int limit = 100,
  }) {
    if (!kDebugMode) {
      return const <Map<String, dynamic>>[];
    }

    final filtered = _recentEvents.where((entry) {
      if (event != null && entry['event'] != event) {
        return false;
      }
      if (moduleId != null && entry['moduleId'] != moduleId) {
        return false;
      }
      if (entityId != null && entry['entityId'] != entityId) {
        return false;
      }
      return true;
    }).toList();

    final safeLimit = limit <= 0 ? 1 : limit;
    if (filtered.length <= safeLimit) {
      return filtered
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    }
    return filtered
        .sublist(filtered.length - safeLimit)
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }

  static void clearRecentEvents() {
    if (!kDebugMode) return;
    _recentEvents.clear();
  }
}
