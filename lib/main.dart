import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'core/theme/app_theme.dart';
import 'routing/app_router.dart';
import 'data/local/hive/hive_service.dart';
import 'core/notifications/notification_hub.dart';
import 'core/notifications/services/notification_recovery_service.dart';
import 'core/notifications/services/notification_system_refresher.dart';
import 'core/services/android_system_status.dart';
import 'core/notifications/services/notification_workmanager_dispatcher.dart';
import 'core/notifications/services/universal_notification_scheduler.dart';
import 'core/services/reminder_manager.dart';
import 'core/services/notification_handler.dart';
import 'core/services/alarm_service.dart';
import 'features/tasks/presentation/screens/alarm_screen.dart';
import 'features/habits/presentation/services/quit_habit_report_access_guard.dart';
import 'features/habits/data/services/quit_habit_secure_storage_service.dart';
// Feature modules - each module handles its own initialization
import 'features/tasks/tasks_module.dart';
import 'features/habits/habits_module.dart';
import 'features/finance/finance_module.dart';
import 'features/sleep/sleep_module.dart';

// Theme mode provider
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

@pragma('vm:entry-point')
Future<void> homeWidgetBackgroundCallback(Uri? uri) async {
  // Simply trigger a widget refresh; data is written from the app side.
  await HomeWidget.updateWidget(name: 'HomeWidgetProvider');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HomeWidget.registerInteractivityCallback(homeWidgetBackgroundCallback);

  // WorkManager: safety net for notification recovery (nek12 Layer 3)
  await Workmanager().initialize(
    notificationWorkmanagerCallbackDispatcher,
    isInDebugMode: kDebugMode,
  );

  // Initialize Hive database
  await HiveService.init();

  // Initialize only the Home-critical module before first frame.
  // Other feature modules are initialized in the background post-frame.
  await TasksModule.init(preOpenBoxes: false);
  // Future modules:
  // await MoodModule.init();
  // await TimeManagementModule.init();

  // Initialize alarm service for special task alarms
  await AlarmService().initialize();

  // Default data initialization removed - app starts with empty database for testing

  runApp(const ProviderScope(child: LifeManagerApp()));

  // Defer heavy startup work until after first frame.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_runPostStartupInitialization());
  });
}

Future<void> _runPostStartupInitialization() async {
  try {
    await Future.wait([
      HabitsModule.init(preOpenBoxes: false),
      SleepModule.init(preOpenBoxes: false),
      FinanceModule.init(
        deferRecurringProcessing: true,
        preOpenBoxes: false,
        bootstrapDefaults: false,
      ),
    ]);
  } catch (e) {
    debugPrint('⚠️ Deferred module init failed: $e');
  }

  // Let first frame settle before background startup work.
  await Future<void>.delayed(const Duration(milliseconds: 350));

  try {
    // nek12 Layer 2: resync if timezone/time changed while app was closed
    final pendingResync =
        await AndroidSystemStatus.getAndClearPendingNotificationResync();
    if (pendingResync && kDebugMode) {
      debugPrint('NotificationHub: timezone/time changed – will resync');
    }

    // Initialize notification/reminder system in the background
    await ReminderManager().initialize(startupOptimized: true);
    // Clean legacy sleep_reminder notifications (migrated to Hub "sleep" module)
    final hub = NotificationHub();
    await hub.initialize();
    final cancelled = await hub.cancelForModule(moduleId: 'sleep_reminder');
    if (cancelled > 0 && kDebugMode) {
      debugPrint('Migrated: cancelled $cancelled legacy sleep_reminder notifications');
    }
    // Sync universal reminders to OS scheduler (includes resync if timezone changed)
    await UniversalNotificationScheduler().syncAll();

    // If timezone changed, run full recovery (Finance + Universal)
    if (pendingResync) {
      await NotificationRecoveryService.runRecovery(
        bootstrapForBackground: false,
      );
      if (kDebugMode) {
        debugPrint('NotificationHub: resynced after timezone/time change');
      }
    }

    // nek12 Layer 4: health check – if we expect notifications but OS has 0, resync
    unawaited(NotificationRecoveryService.runHealthCheckIfNeeded());

    // Register WorkManager periodic task (every 15 min) to reschedule
    // dropped notifications when app is killed (nek12 Layer 3)
    await Workmanager().registerPeriodicTask(
      'notification_recovery',
      NotificationRecoveryService.taskName,
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  } catch (e) {
    debugPrint('⚠️ ReminderManager init failed: $e');
  }

  // Stagger maintenance so it doesn't compete with launch rendering.
  await Future<void>.delayed(const Duration(milliseconds: 250));

  try {
    // Process recurring finance transactions after UI is up
    await FinanceModule.runPostStartupMaintenance();
  } catch (e) {
    debugPrint('⚠️ Finance maintenance failed: $e');
  }
}

class LifeManagerApp extends ConsumerStatefulWidget {
  const LifeManagerApp({super.key});

  @override
  ConsumerState<LifeManagerApp> createState() => _LifeManagerAppState();
}

class _LifeManagerAppState extends ConsumerState<LifeManagerApp>
    with WidgetsBindingObserver {
  bool _isShowingAlarm = false;
  Timer? _ringingAlarmCheckTimer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupAlarmListener();
    // Defer heavy startup tasks until after first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runPostFrameStartupTasks();
    });
  }

  /// Clear pending notification payloads in debug mode to prevent
  /// popups from appearing on every hot restart during development
  Future<void> _clearPendingNotificationsInDebug() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_notification_payload');
      await prefs.remove('pending_notification_action');
      await prefs.remove('pending_notification_id');
      debugPrint('🧹 Debug mode: Cleared pending notification payloads');
    } catch (e) {
      debugPrint('⚠️ Failed to clear pending notifications: $e');
    }
  }

  void _runPostFrameStartupTasks() {
    _checkForRingingAlarms();

    // Handle native one-shot reminder taps/actions on cold start.
    // In debug mode, clear pending notifications to avoid popup on hot restart
    if (kDebugMode) {
      _clearPendingNotificationsInDebug();
    } else {
      NotificationHandler().processPendingTapIfUnlocked();
      // Retry shortly to avoid race with native SharedPreferences commit.
      Future.delayed(const Duration(milliseconds: 600), () {
        NotificationHandler().processPendingTapIfUnlocked();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ringingAlarmCheckTimer?.cancel();
    _ringingAlarmCheckTimer = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state != AppLifecycleState.resumed) {
      // Track when app goes to background for debounced notification refresh.
      if (state == AppLifecycleState.inactive ||
          state == AppLifecycleState.paused) {
        NotificationSystemRefresher.instance.onAppPaused();
      }
      // Lock quit-habit security session whenever app leaves foreground.
      QuitHabitReportAccessGuard.clearAllSessions();
      unawaited(QuitHabitSecureStorageService().lockSession());
    }
    if (state == AppLifecycleState.resumed) {
      // Resume any deferred notification taps once the device is unlocked.
      NotificationHandler().processPendingTapIfUnlocked();
      // If an alarm is ringing (e.g., user just unlocked), show the AlarmScreen.
      _checkForRingingAlarms();
      // Refresh notification schedules if we were backgrounded long enough.
      unawaited(NotificationSystemRefresher.instance.onAppResumed());
    }
  }

  /// Set up listener for when alarms fire
  ///
  /// Note: This callback only fires when the app is in foreground.
  /// When the app is killed, the native service shows its own notification.
  void _setupAlarmListener() {
    AlarmService().onAlarmRing =
        (
          int alarmId,
          String title,
          String body,
          int? iconCodePoint,
          String? iconFontFamily,
          String? iconFontPackage,
        ) {
          _showAlarmScreen(
            alarmId,
            title,
            body,
            iconCodePoint: iconCodePoint,
            iconFontFamily: iconFontFamily,
            iconFontPackage: iconFontPackage,
          );
        };
  }

  /// Check if any alarms are currently ringing (app was launched by alarm)
  Future<void> _checkForRingingAlarms() async {
    // Wait for navigator to be ready.
    // Use a cancelable Timer so widget tests don't end with pending timers.
    final completer = Completer<void>();
    _ringingAlarmCheckTimer?.cancel();
    _ringingAlarmCheckTimer = Timer(const Duration(milliseconds: 500), () {
      if (!completer.isCompleted) completer.complete();
    });
    await completer.future;
    if (!mounted) return;

    try {
      final isRinging = await AlarmService().isRinging(0);
      if (isRinging) {
        // Get the actual ringing alarm data from native
        final alarmData = await AlarmService().getCurrentRingingAlarm();

        if (alarmData != null) {
          final alarmId = alarmData['alarmId'] as int? ?? 0;
          final title = alarmData['title'] as String? ?? 'Special Task';
          final body = alarmData['body'] as String? ?? '';

          // Get stored icon data using the ACTUAL alarm ID
          final iconData = await AlarmService().getStoredIconData(alarmId);

          debugPrint(
            '🔔 App launched by alarm $alarmId, icon: ${iconData['codePoint']}',
          );

          _showAlarmScreen(
            alarmId,
            title,
            body.isEmpty ? 'Tap Done when complete' : body,
            iconCodePoint: iconData['codePoint'] as int?,
            iconFontFamily: iconData['fontFamily'] as String?,
            iconFontPackage: iconData['fontPackage'] as String?,
          );
        } else {
          // Fallback - show generic alarm screen
          debugPrint('🔔 Alarm is ringing but no data available');
          _showAlarmScreen(0, 'Special Task', 'Tap Done when complete');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error checking for ringing alarms: $e');
    }
  }

  /// Show the full-screen alarm UI (covers entire screen including nav bar)
  /// Show the full-screen alarm UI (covers entire screen including nav bar)
  ///
  /// The AlarmScreen provides full functionality:
  /// - Done: Mark task as complete with points
  /// - Snooze: Multiple duration options with task persistence
  /// - Not Done: Mark with reason tracking
  /// - Postpone: Reschedule to another date
  void _showAlarmScreen(
    int alarmId,
    String title,
    String body, {
    int? iconCodePoint,
    String? iconFontFamily,
    String? iconFontPackage,
  }) {
    if (_isShowingAlarm) return;
    final context = rootNavigatorKey.currentContext;
    if (context == null) {
      // Retry after a delay if context not ready
      Future.delayed(const Duration(milliseconds: 500), () {
        _showAlarmScreen(
          alarmId,
          title,
          body,
          iconCodePoint: iconCodePoint,
          iconFontFamily: iconFontFamily,
          iconFontPackage: iconFontPackage,
        );
      });
      return;
    }

    debugPrint(
      '🔔 Showing AlarmScreen for alarm $alarmId with icon: $iconCodePoint',
    );

    // Clean up title (remove star prefix if present)
    final cleanTitle = title.replaceFirst('⭐ ', '');

    _isShowingAlarm = true;

    // Use AlarmScreen.show() to properly overlay everything
    // The AlarmScreen handles all actions internally
    AlarmScreen.show(
      context,
      title: cleanTitle,
      body: body,
      alarmId: alarmId,
      iconCodePoint: iconCodePoint,
      iconFontFamily: iconFontFamily ?? 'MaterialIcons',
      iconFontPackage: iconFontPackage,
      onDismiss: () async {
        // Basic dismiss callback - just update our tracking flag
        // The AlarmScreen handles stopping the alarm sound/vibration
        _isShowingAlarm = false;
        debugPrint('✅ Alarm $alarmId screen closed');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Life Manager',
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: themeMode,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: GlobalKey<ScaffoldMessengerState>(),
    );
  }
}
