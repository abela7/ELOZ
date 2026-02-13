class NotificationHubUpcomingNotification {
  final String moduleId;
  final String title;
  final DateTime scheduledAt;

  const NotificationHubUpcomingNotification({
    required this.moduleId,
    required this.title,
    required this.scheduledAt,
  });
}

class NotificationHubDashboardSummary {
  final int totalPending;
  final Map<String, int> pendingByModule;
  final NotificationHubUpcomingNotification? nextUpcoming;
  final int scheduledToday;
  final int tappedToday;
  final int actionToday;
  final int cancelledToday;
  final int failedToday;

  const NotificationHubDashboardSummary({
    required this.totalPending,
    required this.pendingByModule,
    required this.nextUpcoming,
    required this.scheduledToday,
    required this.tappedToday,
    required this.actionToday,
    required this.cancelledToday,
    required this.failedToday,
  });
}
