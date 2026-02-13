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
    if (taskName != NotificationRecoveryService.taskName) {
      return true;
    }
    final result = await NotificationRecoveryService.runRecovery(
      bootstrapForBackground: true,
    );
    return result.success;
  });
}
