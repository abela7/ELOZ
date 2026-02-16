import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/notification_settings.dart';
import '../models/pending_notification_info.dart';
import '../services/notification_service.dart';
import 'adapters/mini_app_notification_adapter.dart';
import 'models/hub_module_notification_settings.dart';
import 'models/notification_hub_dashboard_summary.dart';
import 'models/notification_hub_module.dart';
import 'models/notification_hub_payload.dart';
import 'models/notification_hub_schedule_request.dart';
import 'models/notification_hub_schedule_result.dart';
import 'models/notification_lifecycle_event.dart';
import 'models/notification_log_entry.dart';
import 'models/universal_notification.dart';
import 'services/custom_notification_type_store.dart';
import 'services/notification_source_resolver.dart';
import 'services/universal_notification_repository.dart';
import 'services/notification_hub_log_store.dart';
import 'services/notification_hub_module_settings_store.dart';
import 'services/notification_type_registry.dart';

class NotificationHub {
  static final NotificationHub _instance = NotificationHub._internal();
  factory NotificationHub() => _instance;
  NotificationHub._internal();

  final NotificationService _notificationService = NotificationService();
  final NotificationHubLogStore _logStore = NotificationHubLogStore();
  final NotificationHubModuleSettingsStore _moduleSettingsStore =
      NotificationHubModuleSettingsStore();
  final CustomNotificationTypeStore _customTypeStore =
      CustomNotificationTypeStore();

  final Map<String, MiniAppNotificationAdapter> _adapters =
      <String, MiniAppNotificationAdapter>{};

  bool _initialized = false;
  bool _moduleStatesLoaded = false;
  Map<String, bool> _moduleEnabledStates = <String, bool>{};
  Completer<void>? _initializeCompleter;

  /// Tracks (notificationId → scheduledAt ISO) so we only log "scheduled"
  /// when something actually changes. Prevents log spam from repeated syncs.
  final Map<int, String> _lastScheduledAt = <int, String>{};
  static const Duration _adapterLookupTimeout = Duration(seconds: 2);
  static const Duration _adapterLookupPollInterval = Duration(
    milliseconds: 50,
  );

  Future<void> initialize({bool startupOptimized = true}) async {
    if (_initialized) {
      return;
    }

    if (_initializeCompleter != null) {
      return _initializeCompleter!.future;
    }

    _initializeCompleter = Completer<void>();
    try {
      await _notificationService.initialize(startupOptimized: startupOptimized);
      await _ensureModuleStatesLoaded();

      // Rebuild registry with adapter types + persisted custom types.
      await reloadCustomTypes();

      _initialized = true;
      _initializeCompleter!.complete();
    } catch (error, stackTrace) {
      _initializeCompleter!.completeError(error, stackTrace);
      rethrow;
    } finally {
      _initializeCompleter = null;
    }
  }

  final NotificationTypeRegistry _typeRegistry = NotificationTypeRegistry();

  void registerAdapter(MiniAppNotificationAdapter adapter) {
    final moduleId = adapter.module.moduleId;
    if (moduleId.isEmpty) {
      return;
    }

    _adapters[moduleId] = adapter;
    _moduleEnabledStates.putIfAbsent(
      moduleId,
      () => adapter.module.defaultEnabled,
    );

    // Register any custom notification types from this adapter.
    final customTypes = adapter.customNotificationTypes;
    if (customTypes.isNotEmpty) {
      _typeRegistry.registerCustomTypes(customTypes);
    }

    // If hub is already initialized and a module is registering lazily,
    // re-apply persisted custom overrides so they still win by type ID.
    if (_initialized) {
      unawaited(reloadCustomTypes());
    }
  }

  void unregisterAdapter(String moduleId) {
    _adapters.remove(moduleId);
    _typeRegistry.unregisterModuleTypes(moduleId);
  }

  /// Returns the type registry for querying available notification types.
  NotificationTypeRegistry get typeRegistry => _typeRegistry;

  /// Returns the custom type store for CRUD operations.
  CustomNotificationTypeStore get customTypeStore => _customTypeStore;

  /// Reloads custom types from storage (call after creating/editing/deleting types).
  Future<void> reloadCustomTypes() async {
    // 1) Clear all module-scoped types (keep built-ins).
    final moduleIds = _adapters.keys.toList(growable: false);
    for (final moduleId in moduleIds) {
      _typeRegistry.unregisterModuleTypes(moduleId);
    }

    // 2) Re-register adapter-defined types.
    for (final adapter in _adapters.values) {
      final adapterTypes = adapter.customNotificationTypes;
      if (adapterTypes.isNotEmpty) {
        _typeRegistry.registerCustomTypes(adapterTypes);
      }
    }

    // 3) Overlay persisted custom types (these win by ID).
    await _loadCustomTypes();
  }

  Future<void> _loadCustomTypes() async {
    try {
      final customTypes = await _customTypeStore.getAll();
      if (customTypes.isNotEmpty) {
        _typeRegistry.loadCustomTypes(customTypes);
      }
    } catch (e) {
      // Silent fail - custom types are optional
    }
  }

  bool isRegistered(String moduleId) => _adapters.containsKey(moduleId);

  MiniAppNotificationAdapter? adapterFor(String moduleId) =>
      _adapters[moduleId];

  List<NotificationHubModule> getRegisteredModules() {
    final modules = _adapters.values.map((adapter) => adapter.module).toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
    return modules;
  }

  Future<Map<String, bool>> getModuleEnabledStates() async {
    await _ensureModuleStatesLoaded();
    final result = <String, bool>{};
    for (final module in getRegisteredModules()) {
      result[module.moduleId] =
          _moduleEnabledStates[module.moduleId] ?? module.defaultEnabled;
    }
    return result;
  }

  Future<bool> isModuleEnabled(String moduleId) async {
    await _ensureModuleStatesLoaded();
    final module = _adapters[moduleId]?.module;
    return _moduleEnabledStates[moduleId] ?? module?.defaultEnabled ?? true;
  }

  Future<void> setModuleEnabled(String moduleId, bool enabled) async {
    await _ensureModuleStatesLoaded();
    _moduleEnabledStates[moduleId] = enabled;
    await _moduleSettingsStore.saveEnabledStates(_moduleEnabledStates);
  }

  int generateNotificationId({
    required String moduleId,
    required String entityId,
    String reminderType = 'at_time',
    int reminderValue = 0,
    String reminderUnit = 'minutes',
    DateTime? scheduledAt,
  }) {
    final signature = <String>[
      moduleId,
      entityId,
      reminderType,
      '$reminderValue',
      reminderUnit,
      if (scheduledAt != null)
        '${scheduledAt.year.toString().padLeft(4, '0')}${scheduledAt.month.toString().padLeft(2, '0')}${scheduledAt.day.toString().padLeft(2, '0')}',
    ].join('|');

    final hash = signature.hashCode.abs();
    final module = _adapters[moduleId]?.module;
    if (module == null || module.rangeSize <= 0) {
      return hash % 2147483647;
    }

    return module.idRangeStart + (hash % module.rangeSize);
  }

  // ---------------------------------------------------------------------------
  // Per-module settings
  // ---------------------------------------------------------------------------

  /// Loads the per-module notification overrides for [moduleId].
  Future<HubModuleNotificationSettings> getModuleSettings(
    String moduleId,
  ) async {
    return _moduleSettingsStore.loadModuleSettings(moduleId);
  }

  /// Saves per-module notification overrides for [moduleId].
  Future<void> setModuleSettings(
    String moduleId,
    HubModuleNotificationSettings settings,
  ) async {
    await _moduleSettingsStore.saveModuleSettings(moduleId, settings);
  }

  /// Returns a fully-resolved [NotificationSettings] for [moduleId] by
  /// layering module overrides on top of the global settings.
  Future<NotificationSettings> getEffectiveSettings(String moduleId) async {
    final global = await _notificationService.loadCurrentSettings();
    final moduleSettings = await getModuleSettings(moduleId);
    return moduleSettings.mergeWithGlobal(global);
  }

  // ---------------------------------------------------------------------------
  // Schedule (enhanced – type-based pipeline)
  // ---------------------------------------------------------------------------

  Future<NotificationHubScheduleResult> schedule(
    NotificationHubScheduleRequest request,
  ) async {
    await initialize();

    final adapter = _adapters[request.moduleId];
    if (adapter == null) {
      if (kDebugMode) {
        debugPrint(
          'NotificationHub.schedule: FAILED – module "${request.moduleId}" '
          'not registered (adapter missing). Registered: ${_adapters.keys.toList()}',
        );
      }
      // Do not log: intentional config (module not registered). Avoids hundreds
      // of redundant entries when sync runs repeatedly (app start, resume, etc.)
      return NotificationHubScheduleResult.failed(
        'Module "${request.moduleId}" is not registered. Restart the app.',
      );
    }

    if (!await isModuleEnabled(request.moduleId)) {
      if (kDebugMode) {
        debugPrint(
          'NotificationHub.schedule: FAILED – module "${request.moduleId}" '
          'is disabled in hub',
        );
      }
      // Do not log: user disabled the module. Every sync would log 1 per reminder
      // (e.g. 6 wind-down × ~27 syncs = 162 entries). Skip to avoid log spam.
      final name = request.moduleId.isNotEmpty
          ? '${request.moduleId[0].toUpperCase()}${request.moduleId.substring(1)}'
          : 'Module';
      return NotificationHubScheduleResult.failed(
        '$name is disabled. Enable it in Notification Hub.',
      );
    }

    // ── Load per-module settings and merge with global ──
    final moduleSettings = await getModuleSettings(request.moduleId);

    // Module-level enabled check
    if (moduleSettings.notificationsEnabled == false) {
      if (kDebugMode) {
        debugPrint(
          'NotificationHub.schedule: FAILED – notifications disabled for '
          'module "${request.moduleId}" (Hub > Finance Manager settings)',
        );
      }
      // Do not log: same reason as module_disabled – avoid log spam.
      final name = request.moduleId.isNotEmpty
          ? '${request.moduleId[0].toUpperCase()}${request.moduleId.substring(1)}'
          : 'Module';
      return NotificationHubScheduleResult.failed(
        'Notifications are off for $name. Enable them in Notification Hub.',
      );
    }

    final globalSettings = await _notificationService.loadCurrentSettings();
    final effectiveSettings = moduleSettings.mergeWithGlobal(globalSettings);

    final notificationId =
        request.notificationId ??
        generateNotificationId(
          moduleId: request.moduleId,
          entityId: request.entityId,
          reminderType: request.reminderType,
          reminderValue: request.reminderValue,
          reminderUnit: request.reminderUnit,
          scheduledAt: request.scheduledAt,
        );

    // Ensure core diagnostic keys are always available in payload extras.
    // Mini-app schedulers can still override these explicitly.
    final payloadExtras = <String, String>{...request.extras};
    if (request.type.isNotEmpty && !payloadExtras.containsKey('type')) {
      payloadExtras['type'] = request.type;
    }

    final payload = NotificationHubPayload(
      moduleId: request.moduleId,
      entityId: request.entityId,
      reminderType: request.reminderType,
      reminderValue: '${request.reminderValue}',
      reminderUnit: request.reminderUnit,
      extras: payloadExtras,
    );

    // ── Resolve delivery config from notification type ──
    final moduleDefaultChannel =
        moduleSettings.defaultChannel ?? 'task_reminders';
    final deliveryConfig = _typeRegistry.resolve(
      typeId: request.type,
      maxAllowedType: moduleSettings.maxAllowedType,
      moduleDefaultChannel: moduleDefaultChannel,
    );
    final typeOverride = moduleSettings.overrideForType(request.type);

    // Apply request-level overrides on top of type's config.
    // Non-null request fields override the type defaults.
    final effectiveChannelKey =
        request.channelKey ??
        typeOverride.channelKey ??
        deliveryConfig.channelKey;

    final effectiveSoundKey =
        request.soundKey ??
        typeOverride.soundKey ??
        deliveryConfig.soundKey ??
        moduleSettings.defaultSound ??
        'default';

    final effectiveVibrationId =
        request.vibrationPatternId ??
        typeOverride.vibrationPatternId ??
        deliveryConfig.vibrationPatternId ??
        moduleSettings.defaultVibrationPattern ??
        'default';

    final effectiveAudioStream =
        request.audioStream ??
        typeOverride.audioStream ??
        deliveryConfig.audioStream;

    final shouldUseAlarmMode =
        request.useAlarmMode ??
        typeOverride.useAlarmMode ??
        deliveryConfig.useAlarmMode;

    final shouldUseFullScreen =
        request.useFullScreenIntent ??
        typeOverride.useFullScreenIntent ??
        deliveryConfig.useFullScreenIntent;

    // Quiet-hours privilege for this specific notification.
    // Request-level override wins, then falls back to the type default.
    final effectiveBypassQuietHours =
        request.bypassQuietHours ??
        typeOverride.bypassQuietHours ??
        deliveryConfig.bypassQuietHours;

    final isSpecial = request.isSpecial || request.type == 'special';

    // ── Delegate to full-featured hub scheduling ──
    final success = await _notificationService.scheduleHubReminder(
      notificationId: notificationId,
      title: request.title,
      body: request.body,
      scheduledAt: request.scheduledAt,
      payload: payload.toRaw(),
      channelKey: effectiveChannelKey,
      soundKey: effectiveSoundKey,
      vibrationPatternId: effectiveVibrationId,
      audioStream: effectiveAudioStream,
      useAlarmMode: shouldUseAlarmMode,
      bypassQuietHours: effectiveBypassQuietHours,
      isSpecial: isSpecial,
      useFullScreenIntent: shouldUseFullScreen,
      priority: request.priority,
      iconCodePoint: request.iconCodePoint,
      iconFontFamily: request.iconFontFamily,
      iconFontPackage: request.iconFontPackage,
      colorValue: request.colorValue,
      actionButtons: request.actionButtons,
      settingsOverride: effectiveSettings,
      useAlarmClockScheduleMode: request.useAlarmClockScheduleMode ?? false,
    );

    if (!success && kDebugMode) {
      debugPrint(
        'NotificationHub.schedule: FAILED – scheduleHubReminder returned false '
        '(${request.moduleId}, scheduledAt: ${request.scheduledAt}). '
        'Check global notifications, time in past, or quiet hours.',
      );
    }

    // ── Deduplicate schedule logs ──
    // Only log when something actually changes. If the same notificationId
    // was already scheduled to the exact same time, skip. This prevents
    // hundreds of duplicate "scheduled" entries from repeated sync cycles
    // (app start, resume, screen open, etc.).
    final scheduledAtIso = request.scheduledAt.toIso8601String();
    final bool isRedundant = success &&
        _lastScheduledAt[notificationId] == scheduledAtIso;

    if (success) {
      _lastScheduledAt[notificationId] = scheduledAtIso;
    }

    if (!isRedundant) {
      await _logStore.append(
        NotificationLogEntry.create(
          moduleId: request.moduleId,
          entityId: request.entityId,
          notificationId: notificationId,
          title: request.title,
          body: request.body,
          payload: payload.toRaw(),
          channelKey: effectiveChannelKey,
          soundKey: effectiveSoundKey,
          event: success
              ? NotificationLifecycleEvent.scheduled
              : NotificationLifecycleEvent.failed,
          metadata: <String, dynamic>{
            'scheduledAt': scheduledAtIso,
            'type': request.type,
            'channelKey': effectiveChannelKey,
            'soundKey': effectiveSoundKey,
            'vibrationPatternId': effectiveVibrationId,
            'audioStream': effectiveAudioStream,
            'useAlarmMode': shouldUseAlarmMode,
            'bypassQuietHours': effectiveBypassQuietHours,
            'moduleAllowsQuietHours':
                effectiveSettings.allowUrgentDuringQuietHours,
            'isSpecial': isSpecial,
            'useFullScreenIntent': shouldUseFullScreen,
            if (moduleSettings.maxAllowedType != null)
              'maxAllowedType': moduleSettings.maxAllowedType,
            if (typeOverride.hasOverrides) 'typeOverride': typeOverride.toJson(),
            if (request.priority != null) 'priority': request.priority,
            if (payloadExtras.isNotEmpty) 'extras': payloadExtras,
          },
        ),
      );
    }

    if (success) {
      return NotificationHubScheduleResult.ok;
    }
    return NotificationHubScheduleResult.failed(
      'Could not schedule. Check app notification settings, '
      'time (must be in future), or quiet hours.',
    );
  }

  // ---------------------------------------------------------------------------
  // Snooze
  // ---------------------------------------------------------------------------

  /// Snoozes a hub notification by rescheduling it with the module's snooze
  /// settings. Returns `true` if rescheduled successfully.
  Future<bool> snooze({
    required String payload,
    required String title,
    required String body,
    int? notificationId,
    int? customDurationMinutes,
  }) async {
    await initialize();

    final parsed = NotificationHubPayload.tryParse(payload);
    if (parsed == null) return false;

    final moduleId = parsed.moduleId;

    // Load module settings for snooze duration.
    final moduleSettings = await getModuleSettings(moduleId);
    final globalSettings = await _notificationService.loadCurrentSettings();
    final effectiveSettings = moduleSettings.mergeWithGlobal(globalSettings);

    final snoozeDuration =
        customDurationMinutes ?? effectiveSettings.defaultSnoozeDuration;

    await _notificationService.snoozeNotification(
      taskId: parsed.entityId,
      title: title,
      body: body,
      payload: payload,
      customDurationMinutes: snoozeDuration,
      originalNotificationId: notificationId,
      settingsOverride: effectiveSettings,
      notificationKindLabel: 'Hub',
    );

    await _logStore.append(
      NotificationLogEntry.create(
        moduleId: moduleId,
        entityId: parsed.entityId,
        notificationId: notificationId,
        title: title,
        body: body,
        payload: payload,
        event: NotificationLifecycleEvent.snoozed,
        metadata: <String, dynamic>{'snoozeDurationMinutes': snoozeDuration},
      ),
    );

    return true;
  }

  Future<int> cancelForEntity({
    required String moduleId,
    required String entityId,
  }) async {
    await initialize();

    final pending = await _notificationService
        .getDetailedPendingNotifications();
    final cancelledIds = <int>{};

    for (final info in pending) {
      final parsed = NotificationHubPayload.tryParse(info.payload);
      final pendingModuleId = parsed?.moduleId ?? _moduleIdForPendingInfo(info);
      final pendingEntityId = parsed?.entityId ?? info.entityId;
      if (pendingModuleId != moduleId || pendingEntityId != entityId) {
        continue;
      }
      if (!cancelledIds.add(info.id)) {
        continue;
      }

      await _notificationService.cancelPendingNotificationById(
        notificationId: info.id,
        entityId: pendingEntityId,
      );
      _forgetScheduledAtFor(info.id);

      await _logStore.append(
        NotificationLogEntry.create(
          moduleId: moduleId,
          entityId: pendingEntityId,
          notificationId: info.id,
          title: info.title,
          body: info.body,
          payload: info.payload,
          event: NotificationLifecycleEvent.cancelled,
          metadata: const <String, dynamic>{'source': 'cancel_for_entity'},
        ),
      );
    }

    return cancelledIds.length;
  }

  /// Cancels all pending notifications belonging to [moduleId].
  ///
  /// This uses detailed pending entries so both plugin-scheduled notifications
  /// and tracked native alarms are included.
  Future<int> cancelForModule({required String moduleId}) async {
    await initialize();

    final pending = await _notificationService
        .getDetailedPendingNotifications();
    final cancelledIds = <int>{};

    for (final info in pending) {
      final parsed = NotificationHubPayload.tryParse(info.payload);
      final pendingModuleId = parsed?.moduleId ?? _moduleIdForPendingInfo(info);
      if (pendingModuleId != moduleId) {
        continue;
      }
      if (!cancelledIds.add(info.id)) {
        continue;
      }
      final pendingEntityId = parsed?.entityId ?? info.entityId;

      await _notificationService.cancelPendingNotificationById(
        notificationId: info.id,
        entityId: pendingEntityId,
      );
      _forgetScheduledAtFor(info.id);

      await _logStore.append(
        NotificationLogEntry.create(
          moduleId: moduleId,
          entityId: pendingEntityId,
          notificationId: info.id,
          payload: info.payload,
          title: info.title,
          body: info.body,
          event: NotificationLifecycleEvent.cancelled,
          metadata: const <String, dynamic>{'source': 'cancel_for_module'},
        ),
      );
    }

    return cancelledIds.length;
  }

  /// Gets the count of scheduled notifications for a specific module.
  Future<int> getScheduledCountForModule(String moduleId) async {
    await initialize();

    final pending = await _notificationService
        .getDetailedPendingNotifications();
    int count = 0;

    for (final info in pending) {
      final parsed = NotificationHubPayload.tryParse(info.payload);
      if (parsed != null && parsed.moduleId == moduleId) {
        count++;
      }
    }

    return count;
  }

  /// Gets ALL scheduled notifications across all modules, sorted by fire time.
  /// Useful for the Overview "upcoming" list when user taps Active Reminders.
  Future<List<Map<String, dynamic>>> getAllScheduledNotifications() async {
    await initialize();

    final pending = await _notificationService
        .getDetailedPendingNotifications();
    final notifications = <Map<String, dynamic>>[];

    final universalRepo = UniversalNotificationRepository();
    await universalRepo.init();

    for (final info in pending) {
      final parsed = NotificationHubPayload.tryParse(info.payload);
      final moduleId = parsed?.moduleId ?? _moduleIdForPendingInfo(info);
      final fireAt = info.scheduledAt ?? info.willFireAt;
      final universalId = parsed?.extras['universalId'];
      UniversalNotification? universal;

      if (universalId != null && universalId.isNotEmpty) {
        universal = await universalRepo.getById(universalId);
      }

      final map = <String, dynamic>{
        'id': info.id,
        'title': info.title,
        'body': info.body,
        'scheduledAt': fireAt,
        'moduleId': moduleId,
        'type': parsed?.extras['type'] ?? '',
        'entityId': parsed?.entityId ?? '',
        'payload': info.payload,
        'targetEntityId': parsed?.extras['targetEntityId'],
        'condition': parsed?.extras['condition'],
        'section': parsed?.extras['section'],
        'channelKey': info.channelKey,
        'channelName': info.channelName,
        'soundKey': info.soundKey,
        'soundName': info.soundName,
        'vibrationPattern': info.vibrationPattern,
        'audioStream': info.audioStream,
        'useAlarmMode': info.useAlarmMode,
        'universalId': universalId,
        'reminderType': parsed?.reminderType ?? 'at_time',
        'reminderValue': parsed?.reminderValue ?? '0',
        'reminderUnit': parsed?.reminderUnit ?? 'minutes',
      };

      if (universal != null) {
        map['iconCodePoint'] = universal.iconCodePoint;
        map['iconFontFamily'] = universal.iconFontFamily;
        map['iconFontPackage'] = universal.iconFontPackage;
        map['colorValue'] = universal.colorValue;
        map['actionsEnabled'] = universal.actionsEnabled;
        map['actionsJson'] = universal.actionsJson;
        map['typeId'] = universal.typeId;
        map['timing'] = universal.timing;
        map['timingValue'] = universal.timingValue;
        map['timingUnit'] = universal.timingUnit;
        map['hour'] = universal.hour;
        map['minute'] = universal.minute;
        map['entityName'] = universal.entityName;
      }

      notifications.add(map);
    }

    notifications.sort((a, b) {
      final aTime = a['scheduledAt'] as DateTime?;
      final bTime = b['scheduledAt'] as DateTime?;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return aTime.compareTo(bTime);
    });

    return notifications;
  }

  /// Gets all scheduled notifications for a specific module with details.
  Future<List<Map<String, dynamic>>> getScheduledNotificationsForModule(
    String moduleId,
  ) async {
    await initialize();
    final all = await getAllScheduledNotifications();
    return all
        .where((n) => (n['moduleId'] as String? ?? '') == moduleId)
        .toList();
  }

  Future<void> cancelByNotificationId({
    required int notificationId,
    String? entityId,
    String? payload,
    String? title,
    String? body,
    Map<String, dynamic>? metadata,
    /// When payload is null or unparseable, use these for correct source tracking.
    String? moduleId,
    String? section,
  }) async {
    await initialize();
    await _notificationService.cancelPendingNotificationById(
      notificationId: notificationId,
      entityId: entityId,
    );
    _forgetScheduledAtFor(notificationId);

    final parsed = NotificationHubPayload.tryParse(payload);
    var logModuleId = parsed?.moduleId ?? moduleId;
    var finalEntityId = entityId ?? parsed?.entityId ?? '';

    if (logModuleId == null || logModuleId.isEmpty || logModuleId == 'unknown') {
      final resolved = await NotificationSourceResolver().resolve(notificationId);
      if (resolved != null) {
        logModuleId = resolved.moduleId;
        if (finalEntityId.isEmpty) finalEntityId = resolved.entityId;
        if ((payload ?? '').isEmpty) {
          payload = NotificationSourceResolver.buildPayloadFromResolved(resolved);
        }
      } else {
        logModuleId = 'unknown';
      }
    }
    await _logStore.append(
      NotificationLogEntry.create(
        moduleId: logModuleId,
        entityId: finalEntityId,
        notificationId: notificationId,
        title: title ?? '',
        body: body ?? '',
        payload: payload,
        event: NotificationLifecycleEvent.cancelled,
        metadata: metadata ?? const <String, dynamic>{},
      ),
    );
  }

  /// Cancels the notification and notifies the owning module so it can
  /// permanently remove the reminder from its entity.
  ///
  /// Use when user explicitly deletes from the Hub UI.
  Future<bool> deleteAndNotifyModule({
    required int notificationId,
    required String entityId,
    required String payload,
  }) async {
    await initialize();

    final parsed = NotificationHubPayload.tryParse(payload);
    final moduleId = parsed?.moduleId ?? 'unknown';

    // Cancel platform notification
    await _notificationService.cancelPendingNotificationById(
      notificationId: notificationId,
      entityId: entityId,
    );
    _forgetScheduledAtFor(notificationId);

    final adapter = parsed != null ? _adapters[parsed.moduleId] : null;
    if (adapter != null && parsed != null) {
      try {
        await adapter.onNotificationDeleted(parsed);
      } catch (error) {
        await _logStore.append(
          NotificationLogEntry.create(
            moduleId: moduleId,
            entityId: entityId,
            notificationId: notificationId,
            payload: payload,
            event: NotificationLifecycleEvent.failed,
            metadata: <String, dynamic>{
              'reason': 'delete_notify_error',
              'error': '$error',
            },
          ),
        );
        return false;
      }
    }

    await _logStore.append(
      NotificationLogEntry.create(
        moduleId: moduleId,
        entityId: entityId,
        notificationId: notificationId,
        payload: payload,
        event: NotificationLifecycleEvent.cancelled,
        metadata: const <String, dynamic>{'source': 'hub_delete_permanent'},
      ),
    );
    return true;
  }

  Future<bool> handleNotificationTap(String payload) async {
    final parsed = NotificationHubPayload.tryParse(payload);
    if (parsed == null) {
      return false;
    }

    await initialize();

    final adapter = await _waitForAdapter(parsed.moduleId);
    if (adapter == null) {
      await _logStore.append(
        NotificationLogEntry.create(
          moduleId: parsed.moduleId,
          entityId: parsed.entityId,
          payload: payload,
          event: NotificationLifecycleEvent.failed,
          metadata: const <String, dynamic>{
            'reason': 'adapter_not_registered_for_tap',
          },
        ),
      );
      return false;
    }

    try {
      await adapter.onNotificationTapped(parsed);
      await _logStore.append(
        NotificationLogEntry.create(
          moduleId: parsed.moduleId,
          entityId: parsed.entityId,
          payload: payload,
          event: NotificationLifecycleEvent.tapped,
        ),
      );
      return true;
    } catch (error) {
      await _logStore.append(
        NotificationLogEntry.create(
          moduleId: parsed.moduleId,
          entityId: parsed.entityId,
          payload: payload,
          event: NotificationLifecycleEvent.failed,
          metadata: <String, dynamic>{
            'reason': 'tap_handler_error',
            'error': '$error',
          },
        ),
      );
      return false;
    }
  }

  /// Canonical action ID aliases – maps common variants to canonical form.
  /// Adapters handle canonical IDs; this ensures robust routing.
  static const Map<String, String> _actionAliases = <String, String>{
    'done': 'mark_done',
    'open': 'view',
  };

  Future<bool> handleNotificationAction({
    required String actionId,
    required String payload,
    int? notificationId,
  }) async {
    final parsed = NotificationHubPayload.tryParse(payload);
    if (parsed == null) {
      return false;
    }

    await initialize();

    final adapter = await _waitForAdapter(parsed.moduleId);
    if (adapter == null) {
      if (kDebugMode) {
        debugPrint(
          'NotificationHub: No adapter for module "${parsed.moduleId}" '
          '(registered: ${_adapters.keys.toList()})',
        );
      }
      await _logStore.append(
        NotificationLogEntry.create(
          moduleId: parsed.moduleId,
          entityId: parsed.entityId,
          notificationId: notificationId,
          payload: payload,
          actionId: actionId,
          event: NotificationLifecycleEvent.failed,
          metadata: const <String, dynamic>{
            'reason': 'adapter_not_registered_for_action',
          },
        ),
      );
      return false;
    }

    final canonicalActionId = _actionAliases[actionId] ?? actionId;

    try {
      var handled = await adapter.onNotificationAction(
        actionId: canonicalActionId,
        payload: parsed,
        notificationId: notificationId,
      );

      // Fallback: view/open often means "open detail" – try onNotificationTapped
      if (!handled &&
          (canonicalActionId == 'view' ||
              actionId == 'open' ||
              actionId == 'view')) {
        try {
          await adapter.onNotificationTapped(parsed);
          handled = true;
        } catch (_) {}
      }

      if (handled) {
        await _logStore.append(
          NotificationLogEntry.create(
            moduleId: parsed.moduleId,
            entityId: parsed.entityId,
            notificationId: notificationId,
            payload: payload,
            actionId: actionId,
            event: NotificationLifecycleEvent.action,
          ),
        );
      } else {
        await _logStore.append(
          NotificationLogEntry.create(
            moduleId: parsed.moduleId,
            entityId: parsed.entityId,
            notificationId: notificationId,
            payload: payload,
            actionId: actionId,
            event: NotificationLifecycleEvent.failed,
            metadata: const <String, dynamic>{
              'reason': 'action_not_handled_by_adapter',
            },
          ),
        );
      }

      return handled;
    } catch (error) {
      await _logStore.append(
        NotificationLogEntry.create(
          moduleId: parsed.moduleId,
          entityId: parsed.entityId,
          notificationId: notificationId,
          payload: payload,
          actionId: actionId,
          event: NotificationLifecycleEvent.failed,
          metadata: <String, dynamic>{
            'reason': 'action_handler_error',
            'error': '$error',
          },
        ),
      );
      return false;
    }
  }

  Future<List<NotificationLogEntry>> getHistory({
    String? moduleId,
    NotificationLifecycleEvent? event,
    DateTime? from,
    DateTime? to,
    String? search,
    int limit = 300,
  }) async {
    return _logStore.query(
      moduleId: moduleId,
      event: event,
      from: from,
      to: to,
      search: search,
      limit: limit,
    );
  }

  Future<void> clearHistory() async {
    await _logStore.clear();
  }

  /// Compacts repeated `scheduled` history entries and returns
  /// how many were removed.
  Future<int> compactRedundantHistoryEntries() async {
    return _logStore.compactRedundantScheduledEntries();
  }

  /// Remove a single log entry by id (e.g. to clear a failed notification).
  Future<void> deleteLogEntry(String id) async {
    await _logStore.deleteById(id);
  }

  /// Remove multiple log entries by id.
  Future<void> deleteLogEntries(Set<String> ids) async {
    await _logStore.deleteByIds(ids);
  }

  Future<NotificationHubDashboardSummary> getDashboardSummary() async {
    await initialize();

    final pending = await _notificationService
        .getDetailedPendingNotifications();
    final pendingByModule = <String, int>{};

    NotificationHubUpcomingNotification? nextUpcoming;
    for (final info in pending) {
      final moduleId = _moduleIdForPendingInfo(info);
      pendingByModule[moduleId] = (pendingByModule[moduleId] ?? 0) + 1;

      final fireAt = info.willFireAt;
      if (fireAt == null) {
        continue;
      }
      if (nextUpcoming == null || fireAt.isBefore(nextUpcoming.scheduledAt)) {
        nextUpcoming = NotificationHubUpcomingNotification(
          moduleId: moduleId,
          title: info.title,
          scheduledAt: fireAt,
        );
      }
    }

    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfTomorrow = startOfToday.add(const Duration(days: 1));
    final todaysHistory = await _logStore.query(
      from: startOfToday,
      to: startOfTomorrow,
      limit: 1500,
    );

    var scheduledToday = 0;
    var tappedToday = 0;
    var actionToday = 0;
    var snoozedToday = 0;
    var cancelledToday = 0;
    var failedToday = 0;

    for (final entry in todaysHistory) {
      switch (entry.event) {
        case NotificationLifecycleEvent.scheduled:
          scheduledToday++;
          break;
        case NotificationLifecycleEvent.tapped:
          tappedToday++;
          break;
        case NotificationLifecycleEvent.action:
          actionToday++;
          break;
        case NotificationLifecycleEvent.snoozed:
          snoozedToday++;
          break;
        case NotificationLifecycleEvent.cancelled:
          cancelledToday++;
          break;
        case NotificationLifecycleEvent.failed:
          failedToday++;
          break;
        case NotificationLifecycleEvent.delivered:
        case NotificationLifecycleEvent.missed:
          break;
      }
    }

    return NotificationHubDashboardSummary(
      totalPending: pending.length,
      pendingByModule: pendingByModule,
      nextUpcoming: nextUpcoming,
      scheduledToday: scheduledToday,
      tappedToday: tappedToday,
      actionToday: actionToday,
      snoozedToday: snoozedToday,
      cancelledToday: cancelledToday,
      failedToday: failedToday,
    );
  }

  String moduleDisplayName(String moduleId) {
    return _adapters[moduleId]?.module.displayName ?? moduleId;
  }

  /// Returns the display name for a section if the adapter defines it.
  /// Falls back to null so callers can format the section ID themselves.
  String? sectionDisplayName(String moduleId, String sectionId) {
    if (sectionId.isEmpty) return null;
    final adapter = _adapters[moduleId];
    if (adapter == null) return null;
    for (final s in adapter.sections) {
      if (s.id == sectionId) return s.displayName;
    }
    return null;
  }

  String _moduleIdForPendingInfo(PendingNotificationInfo info) {
    final parsed = NotificationHubPayload.tryParse(info.payload);
    if (parsed != null && parsed.moduleId.isNotEmpty) {
      return parsed.moduleId;
    }

    if (info.type.isNotEmpty) {
      return info.type;
    }
    return 'unknown';
  }

  Future<MiniAppNotificationAdapter?> _waitForAdapter(
    String moduleId, {
    Duration timeout = _adapterLookupTimeout,
    Duration pollInterval = _adapterLookupPollInterval,
  }) async {
    var adapter = _adapters[moduleId];
    if (adapter != null) {
      return adapter;
    }

    final watch = Stopwatch()..start();
    while (watch.elapsed < timeout) {
      await Future<void>.delayed(pollInterval);
      adapter = _adapters[moduleId];
      if (adapter != null) {
        return adapter;
      }
    }
    return null;
  }

  void _forgetScheduledAtFor(int notificationId) {
    _lastScheduledAt.remove(notificationId);
    if (notificationId >= 100000) {
      _lastScheduledAt.remove(notificationId - 100000);
      return;
    }
    _lastScheduledAt.remove(notificationId + 100000);
  }

  Future<void> _ensureModuleStatesLoaded() async {
    if (_moduleStatesLoaded) {
      return;
    }
    _moduleEnabledStates = await _moduleSettingsStore.loadEnabledStates();
    _moduleStatesLoaded = true;
  }
}
