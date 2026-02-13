import 'package:flutter/foundation.dart';

import '../../../data/local/hive/hive_service.dart';
import '../../../features/finance/data/services/finance_notification_settings_service.dart';
import '../../../features/finance/finance_module.dart';
import '../../../core/services/notification_service.dart';
import '../../../features/finance/notifications/finance_notification_scheduler.dart';
import '../../../features/habits/habits_module.dart';
import '../../../features/sleep/sleep_module.dart';
import '../../../features/tasks/tasks_module.dart';
import '../notification_hub.dart';
import 'universal_notification_repository.dart';
import 'universal_notification_scheduler.dart';

/// Recovery service for notification schedules (nek12.dev "100% reliable" Layer 3).
///
/// Runs a full resync of Finance + Universal notifications. Used by:
/// - WorkManager periodic task (safety net when app is killed)
/// - App-open health check (Layer 4)
/// - NotificationSystemRefresher (resume-after-15min)
///
/// When invoked from WorkManager, the app may be killed – this service performs
/// a minimal bootstrap (Hive + modules) before syncing.
class NotificationRecoveryService {
  NotificationRecoveryService._();

  static const String _taskName = 'notificationRecovery';

  /// Performs full notification schedule sync.
  ///
  /// Call from WorkManager callback or app context. If [bootstrapForBackground]
  /// is true, initializes Hive and modules first (required when app was killed).
  static Future<NotificationRecoveryResult> runRecovery({
    bool bootstrapForBackground = false,
  }) async {
    try {
      if (bootstrapForBackground) {
        await _bootstrapForBackground();
      }

      final hub = NotificationHub();
      await hub.initialize();

      var financeScheduled = 0;
      var financeCancelled = 0;

      final settingsService = FinanceNotificationSettingsService();
      final settings = await settingsService.load();
      if (settings.notificationsEnabled) {
        final financeResult =
            await FinanceNotificationScheduler().syncSchedules();
        financeScheduled = financeResult.scheduled;
        financeCancelled = financeResult.cancelled;
      }

      await UniversalNotificationScheduler().syncAll();

      if (kDebugMode) {
        debugPrint(
          'NotificationRecoveryService: sync complete – '
          'Finance: $financeScheduled scheduled, $financeCancelled cleared',
        );
      }

      return NotificationRecoveryResult(
        success: true,
        financeScheduled: financeScheduled,
        financeCancelled: financeCancelled,
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('NotificationRecoveryService: recovery failed: $e');
        debugPrintStack(stackTrace: st);
      }
      return NotificationRecoveryResult(success: false, error: e.toString());
    }
  }

  /// Minimal bootstrap when running in background (e.g. WorkManager).
  ///
  /// Initializes Hive and modules required for notification sync.
  static Future<void> _bootstrapForBackground() async {
    // Flutter bindings for plugins (path_provider, shared_preferences, etc.)
    // WidgetsFlutterBinding is done by WorkManager before invoking callback.

    if (!HiveService.isInitialized) {
      await HiveService.init();
    }

    await TasksModule.init(preOpenBoxes: true);
    await HabitsModule.init(preOpenBoxes: true);
    await SleepModule.init(preOpenBoxes: true);
    await FinanceModule.init(
      deferRecurringProcessing: true,
      preOpenBoxes: true,
      bootstrapDefaults: false,
    );
  }

  /// Task name for WorkManager registration.
  static String get taskName => _taskName;

  /// Lightweight health check (nek12 Layer 4): if we expect notifications but
  /// OS has none, resync. Call after normal sync on app open.
  static Future<void> runHealthCheckIfNeeded() async {
    try {
      final hub = NotificationHub();
      await hub.initialize();

      final pending = await NotificationService().getPendingNotifications();
      if (pending.isNotEmpty) return;

      // We have 0 pending. Check if we should have some.
      final hasUniversal = await _hasEnabledUniversalNotifications();
      final hasFinance = await _hasEnabledFinanceNotifications();
      if (!hasUniversal && !hasFinance) return;

      if (kDebugMode) {
        debugPrint(
          'NotificationRecoveryService: health check – 0 pending but '
          'expect notifications (universal=$hasUniversal, finance=$hasFinance), resyncing',
        );
      }
      await runRecovery(bootstrapForBackground: false);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NotificationRecoveryService: health check failed: $e');
      }
    }
  }

  static Future<bool> _hasEnabledUniversalNotifications() async {
    final repo = UniversalNotificationRepository();
    await repo.init();
    final all = await repo.getAll(enabledOnly: true);
    return all.isNotEmpty;
  }

  static Future<bool> _hasEnabledFinanceNotifications() async {
    final settings = await FinanceNotificationSettingsService().load();
    if (!settings.notificationsEnabled) return false;
    return settings.billsEnabled ||
        settings.debtsEnabled ||
        settings.budgetsEnabled ||
        settings.savingsGoalsEnabled ||
        settings.recurringIncomeEnabled;
  }
}

/// Result of a notification recovery run.
class NotificationRecoveryResult {
  final bool success;
  final int financeScheduled;
  final int financeCancelled;
  final String? error;

  const NotificationRecoveryResult({
    required this.success,
    this.financeScheduled = 0,
    this.financeCancelled = 0,
    this.error,
  });
}
