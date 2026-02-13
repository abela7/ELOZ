import 'package:flutter/foundation.dart';

import 'notification_recovery_service.dart';

/// Central service to refresh notification schedules when the app resumes
/// from background. Debounces to avoid excessive sync (e.g. user quickly
/// switching apps). Only syncs if app was backgrounded for at least
/// [minBackgroundDuration] so that Finance bills/income and Universal
/// reminders stay current without draining battery.
class NotificationSystemRefresher {
  NotificationSystemRefresher._();
  static final NotificationSystemRefresher instance =
      NotificationSystemRefresher._();

  static const Duration minBackgroundDuration = Duration(minutes: 15);

  DateTime? _lastBackgroundAt;

  /// Call when app goes to background (inactive or paused).
  void onAppPaused() {
    _lastBackgroundAt = DateTime.now();
  }

  /// Call when app resumes. Triggers sync only if backgrounded long enough.
  Future<void> onAppResumed() async {
    final backgroundedAt = _lastBackgroundAt;
    if (backgroundedAt == null) return;

    final elapsed = DateTime.now().difference(backgroundedAt);
    if (elapsed < minBackgroundDuration) return;

    _lastBackgroundAt = null;

    try {
      await _refreshSchedules();
    } catch (e, st) {
      debugPrint('NotificationSystemRefresher: refresh failed: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  Future<void> _refreshSchedules() async {
    debugPrint(
      'NotificationSystemRefresher: refreshing schedules (resumed after '
      '${minBackgroundDuration.inMinutes}+ min in background)',
    );

    final result = await NotificationRecoveryService.runRecovery(
      bootstrapForBackground: false,
    );

    if (kDebugMode && result.success) {
      debugPrint(
        'NotificationSystemRefresher: sync complete – '
        'Finance: ${result.financeScheduled} scheduled, '
        '${result.financeCancelled} cleared',
      );
    }
  }
}
