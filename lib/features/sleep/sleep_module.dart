import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'data/models/sleep_record.dart';
import 'data/models/sleep_factor.dart';
import 'data/models/sleep_template.dart';
import 'data/repositories/sleep_factor_repository.dart';
import 'data/repositories/sleep_template_repository.dart';
import '../../core/notifications/notification_hub.dart';
import '../../data/local/hive/hive_service.dart';
import 'notifications/sleep_notification_adapter.dart';

/// Sleep Module - Handles all Sleep-related initialization
///
/// This module registers Hive adapters and opens database boxes
/// for the Sleep mini-app. Following the modular super-app pattern,
/// each feature module handles its own initialization.
///
/// TypeId Range: 50-59 (reserved for Sleep module)
class SleepModule {
  static bool _initialized = false;
  static bool _boxesPreopened = false;

  // Box name constants
  static const String sleepRecordsBoxName = 'sleepRecordsBox';
  static const String sleepFactorsBoxName = 'sleepFactorsBox';
  static const String sleepTemplatesBoxName = 'sleepTemplatesBox';

  static const String _deprecatedGoalsBox = 'sleepGoalsBox';
  static const String _deprecatedActivationsBox = 'sleepGoalActivationsBox';

  /// Initialize the Sleep module
  ///
  /// This should be called during app startup.
  /// It's safe to call multiple times (idempotent).
  static Future<void> init({bool preOpenBoxes = true}) async {
    try {
      if (!_initialized) {
        // Register Sleep-related Hive adapters
        // TypeIds 50-59 are reserved for Sleep module
        if (!Hive.isAdapterRegistered(50)) {
          Hive.registerAdapter(SleepRecordAdapter());
        }
        if (!Hive.isAdapterRegistered(52)) {
          Hive.registerAdapter(SleepFactorAdapter());
        }
        if (!Hive.isAdapterRegistered(53)) {
          Hive.registerAdapter(SleepTemplateAdapter());
        }

        NotificationHub().registerAdapter(SleepNotificationAdapter());
        _initialized = true;
        debugPrint('✓ Sleep module initialized (adapters registered)');
      }

      // One-time cleanup: remove deprecated goal boxes
      await _removeDeprecatedGoalBoxes();

      if (preOpenBoxes && !_boxesPreopened) {
        await HiveService.getBox<SleepRecord>(sleepRecordsBoxName);
        await HiveService.getBox<SleepFactor>(sleepFactorsBoxName);
        await HiveService.getBox<SleepTemplate>(sleepTemplatesBoxName);
        
        // Initialize default factors if needed
        final factorRepo = SleepFactorRepository();
        await factorRepo.initializeDefaultFactors();
        final templateRepo = SleepTemplateRepository();
        await templateRepo.warmCache();
        
        _boxesPreopened = true;
        debugPrint('✓ Sleep module boxes pre-opened');
      } else if (!preOpenBoxes && !_boxesPreopened) {
        // Even if preOpenBoxes is false, we should at least ensure
        // the factors box is opened and initialized for performance
        debugPrint('📦 Pre-opening factors box for performance...');
        await HiveService.getBox<SleepFactor>(sleepFactorsBoxName);
        await HiveService.getBox<SleepTemplate>(sleepTemplatesBoxName);
        final factorRepo = SleepFactorRepository();
        await factorRepo.initializeDefaultFactors();
        final templateRepo = SleepTemplateRepository();
        await templateRepo.warmCache();
        debugPrint('✓ Factors box ready');
      }
    } catch (e, stackTrace) {
      debugPrint('✗ Error initializing Sleep module: $e');
      debugPrint('Stack trace: $stackTrace');
      // Re-throw to allow app-level error handling
      rethrow;
    }
  }
  
  /// Check if the module is initialized
  static bool get isInitialized => _initialized;
  
  /// Hive typeId range reserved for Sleep module: 50-59
  /// - 50: SleepRecord
  /// - 51-54: Reserved (formerly SleepGoal, SleepGoalActivation)
  /// - 52: SleepFactor
  /// - 53: SleepTemplate
  /// - 55-59: Reserved for future Sleep-related models
  static const int typeIdRangeStart = 50;
  static const int typeIdRangeEnd = 59;

  static Future<void> _removeDeprecatedGoalBoxes() async {
    try {
      if (Hive.isBoxOpen(_deprecatedGoalsBox)) {
        await Hive.box(_deprecatedGoalsBox).close();
      }
      await Hive.deleteBoxFromDisk(_deprecatedGoalsBox);
      debugPrint('✓ Removed deprecated sleepGoalsBox');
    } catch (_) {}
    try {
      if (Hive.isBoxOpen(_deprecatedActivationsBox)) {
        await Hive.box(_deprecatedActivationsBox).close();
      }
      await Hive.deleteBoxFromDisk(_deprecatedActivationsBox);
      debugPrint('✓ Removed deprecated sleepGoalActivationsBox');
    } catch (_) {}
  }
}
