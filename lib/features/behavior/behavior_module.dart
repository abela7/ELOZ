import 'package:hive/hive.dart';

import '../../core/notifications/notification_hub.dart';
import '../../data/local/hive/hive_service.dart';
import 'data/models/behavior.dart';
import 'data/models/behavior_log.dart';
import 'data/models/behavior_log_reason.dart';
import 'data/models/behavior_reason.dart';
import 'notifications/behavior_notification_adapter.dart';

class BehaviorModule {
  static bool _initialized = false;
  static bool _boxesPreopened = false;

  static const String behaviorsBoxName = 'behavior_behaviors_v1';
  static const String reasonsBoxName = 'behavior_reasons_v1';
  static const String logsBoxName = 'behavior_logs_v1';
  static const String logReasonsBoxName = 'behavior_log_reasons_v1';
  static const String logDateIndexBoxName = 'behavior_log_date_index_v1';
  static const String logBehaviorDateIndexBoxName =
      'behavior_log_behavior_date_index_v1';
  static const String logReasonByLogIndexBoxName =
      'behavior_log_reason_log_index_v1';
  static const String dailySummaryBoxName = 'behavior_daily_summary_v1';
  static const String indexMetaBoxName = 'behavior_index_meta_v1';

  static Future<void> init({bool preOpenBoxes = true}) async {
    if (!_initialized) {
      if (!Hive.isAdapterRegistered(63)) {
        Hive.registerAdapter(BehaviorAdapter());
      }
      if (!Hive.isAdapterRegistered(64)) {
        Hive.registerAdapter(BehaviorReasonAdapter());
      }
      if (!Hive.isAdapterRegistered(65)) {
        Hive.registerAdapter(BehaviorLogAdapter());
      }
      if (!Hive.isAdapterRegistered(66)) {
        Hive.registerAdapter(BehaviorLogReasonAdapter());
      }
      _initialized = true;
    }

    NotificationHub().registerAdapter(BehaviorNotificationAdapter());

    if (preOpenBoxes && !_boxesPreopened) {
      await HiveService.getBox<Behavior>(behaviorsBoxName);
      await HiveService.getBox<BehaviorReason>(reasonsBoxName);
      await HiveService.getBox<BehaviorLog>(logsBoxName);
      await HiveService.getBox<BehaviorLogReason>(logReasonsBoxName);
      await HiveService.getBox<dynamic>(logDateIndexBoxName);
      await HiveService.getBox<dynamic>(logBehaviorDateIndexBoxName);
      await HiveService.getBox<dynamic>(logReasonByLogIndexBoxName);
      await HiveService.getBox<dynamic>(dailySummaryBoxName);
      await HiveService.getBox<dynamic>(indexMetaBoxName);
      _boxesPreopened = true;
    }
  }

  static bool get isInitialized => _initialized;
}
