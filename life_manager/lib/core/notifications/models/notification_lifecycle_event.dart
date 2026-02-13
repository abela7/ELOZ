enum NotificationLifecycleEvent {
  scheduled,
  delivered,
  tapped,
  action,
  snoozed,
  cancelled,
  missed,
  failed,
}

NotificationLifecycleEvent? notificationLifecycleEventFromStorage(String? raw) {
  if (raw == null || raw.isEmpty) {
    return null;
  }
  for (final value in NotificationLifecycleEvent.values) {
    if (value.name == raw) {
      return value;
    }
  }
  return null;
}

extension NotificationLifecycleEventX on NotificationLifecycleEvent {
  String get label {
    switch (this) {
      case NotificationLifecycleEvent.scheduled:
        return 'Scheduled';
      case NotificationLifecycleEvent.delivered:
        return 'Delivered';
      case NotificationLifecycleEvent.tapped:
        return 'Tapped';
      case NotificationLifecycleEvent.action:
        return 'Action';
      case NotificationLifecycleEvent.snoozed:
        return 'Snoozed';
      case NotificationLifecycleEvent.cancelled:
        return 'Cancelled';
      case NotificationLifecycleEvent.missed:
        return 'Missed';
      case NotificationLifecycleEvent.failed:
        return 'Failed';
    }
  }
}
