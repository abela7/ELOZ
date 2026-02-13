/// Result of [NotificationHub.schedule].
///
/// Use [success] to know if scheduling succeeded.
/// When [success] is false, [failureReason] contains a user-friendly message.
class NotificationHubScheduleResult {
  final bool success;
  final String? failureReason;

  const NotificationHubScheduleResult({
    required this.success,
    this.failureReason,
  });

  static const NotificationHubScheduleResult ok =
      NotificationHubScheduleResult(success: true);

  factory NotificationHubScheduleResult.failed(String reason) =>
      NotificationHubScheduleResult(success: false, failureReason: reason);
}
