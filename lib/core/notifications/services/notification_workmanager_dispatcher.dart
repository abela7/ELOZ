import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import 'notification_recovery_service.dart';

/// Top-level callback for WorkManager (nek12 Layer 3 – recovery mechanism).
///
/// Must be a top-level or static function for isolate entry point.
/// Runs when the periodic notification recovery task is due.
@pragma('vm:entry-point')
void notificationWorkmanagerCallbackDispatcher() {
  WidgetsFlutterBinding.ensureInitialized();
  Workmanager().executeTask((taskName, inputData) async {
    if (kDebugMode) {
      debugPrint(
        'NotificationWorkmanager: received task "$taskName" '
        '(expected: "${NotificationRecoveryService.taskName}")',
      );
    }
    if (taskName != NotificationRecoveryService.taskName) {
      return true;
    }
    final result = await NotificationRecoveryService.runRecovery(
      bootstrapForBackground: true,
      sourceFlow: 'workmanager',
    );
    if (kDebugMode) {
      debugPrint(
        'NotificationWorkmanager: recovery finished - success=${result.success} '
        'durationMs=${result.durationMs} '
        'financeScheduled=${result.financeScheduled} financeCancelled=${result.financeCancelled} '
        'universalScheduled=${result.universalScheduled} universalFailed=${result.universalFailed}',
      );
    }
    return result.success;
  });
}
