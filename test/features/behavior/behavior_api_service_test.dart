import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:life_manager/features/behavior/behavior_module.dart';
import 'package:life_manager/features/behavior/data/models/behavior.dart';
import 'package:life_manager/features/behavior/data/models/behavior_log.dart';
import 'package:life_manager/features/behavior/data/models/behavior_log_reason.dart';
import 'package:life_manager/features/behavior/data/models/behavior_reason.dart';
import 'package:life_manager/features/behavior/data/repositories/behavior_repository.dart';
import 'package:life_manager/features/behavior/data/services/behavior_api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;
  late BehaviorApiService api;
  late BehaviorRepository repository;

  setUp(() async {
    hiveDir = await Directory.systemTemp.createTemp('behavior_api_');
    Hive.init(hiveDir.path);
    _registerAdapters();

    repository = BehaviorRepository(
      behaviorsBoxOpener: () =>
          Hive.openBox<Behavior>(BehaviorModule.behaviorsBoxName),
      reasonsBoxOpener: () =>
          Hive.openBox<BehaviorReason>(BehaviorModule.reasonsBoxName),
      logsBoxOpener: () =>
          Hive.openBox<BehaviorLog>(BehaviorModule.logsBoxName),
      logReasonsBoxOpener: () =>
          Hive.openBox<BehaviorLogReason>(BehaviorModule.logReasonsBoxName),
      dynamicBoxOpener: (boxName) => Hive.openBox<dynamic>(boxName),
    );
    api = BehaviorApiService(repository: repository);
  });

  tearDown(() async {
    await Hive.close();
    if (await hiveDir.exists()) {
      await hiveDir.delete(recursive: true);
    }
  });

  group('BehaviorApiService', () {
    test('enforces reason-required and type matching', () async {
      final behavior = await api.postBehavior(
        name: 'Smoking',
        type: 'bad',
        iconCodePoint: 0xe887,
        colorValue: 0xFFD32F2F,
        reasonRequired: true,
      );
      final badReason = await api.postBehaviorReason(
        name: 'Stress',
        type: 'bad',
      );
      final goodReason = await api.postBehaviorReason(
        name: 'Energy',
        type: 'good',
      );

      await expectLater(
        () => api.postBehaviorLog(
          behaviorId: behavior.id,
          occurredAt: DateTime(2026, 2, 18, 8),
        ),
        throwsA(isA<FormatException>()),
      );

      await expectLater(
        () => api.postBehaviorLog(
          behaviorId: behavior.id,
          occurredAt: DateTime(2026, 2, 18, 8),
          reasonIds: <String>[goodReason.id],
        ),
        throwsA(isA<FormatException>()),
      );

      final log = await api.postBehaviorLog(
        behaviorId: behavior.id,
        occurredAt: DateTime(2026, 2, 18, 8),
        reasonIds: <String>[badReason.id],
        intensity: 4,
      );
      expect(log.behaviorId, behavior.id);
    });

    test('returns summary and top reasons using indexed logs', () async {
      final goodBehavior = await api.postBehavior(
        name: 'Workout',
        type: 'good',
        iconCodePoint: 0xe3a1,
        colorValue: 0xFF2E7D32,
      );
      final badBehavior = await api.postBehavior(
        name: 'Overeating',
        type: 'bad',
        iconCodePoint: 0xe56c,
        colorValue: 0xFFD32F2F,
      );
      final goodReason = await api.postBehaviorReason(
        name: 'Routine',
        type: 'good',
      );
      final badReason = await api.postBehaviorReason(
        name: 'Stress',
        type: 'bad',
      );

      final from = DateTime(2026, 2, 10);
      final to = DateTime(2026, 2, 12);
      await api.postBehaviorLog(
        behaviorId: goodBehavior.id,
        occurredAt: DateTime(2026, 2, 10, 7),
        reasonIds: <String>[goodReason.id],
        durationMinutes: 20,
        intensity: 4,
      );
      await api.postBehaviorLog(
        behaviorId: goodBehavior.id,
        occurredAt: DateTime(2026, 2, 11, 7),
        reasonIds: <String>[goodReason.id],
        durationMinutes: 30,
        intensity: 5,
      );
      await api.postBehaviorLog(
        behaviorId: badBehavior.id,
        occurredAt: DateTime(2026, 2, 11, 22),
        reasonIds: <String>[badReason.id],
        durationMinutes: 10,
        intensity: 3,
      );

      final summary = await api.getBehaviorSummary(from: from, to: to);
      final topReasons = await api.getBehaviorTopReasons(from: from, to: to);

      expect(summary.items.length, 2);
      final workout = summary.items.firstWhere(
        (item) => item.behaviorId == goodBehavior.id,
      );
      expect(workout.totalCount, 2);
      expect(workout.totalDurationMinutes, 50);
      expect(workout.averageIntensity, closeTo(4.5, 0.001));

      expect(topReasons, isNotEmpty);
      expect(topReasons.first.reasonId, goodReason.id);
      expect(topReasons.first.usageCount, 2);
    });

    test('restore payload merge is idempotent', () async {
      final behavior = await api.postBehavior(
        name: 'Meditation',
        type: 'good',
        iconCodePoint: 0xe8b5,
        colorValue: 0xFF1565C0,
      );
      final reason = await api.postBehaviorReason(name: 'Calm', type: 'good');
      await api.postBehaviorLog(
        behaviorId: behavior.id,
        occurredAt: DateTime(2026, 2, 12, 20),
        reasonIds: <String>[reason.id],
        durationMinutes: 15,
        intensity: 4,
      );

      final payload = await api.exportBackupPayload();
      await api.restoreFromBackupPayload(payload);
      await api.restoreFromBackupPayload(payload);

      expect((await repository.getAllBehaviors()).length, 1);
      expect((await repository.getAllReasons()).length, 1);
      expect((await repository.getAllLogs()).length, 1);
      expect((await repository.getAllLogReasons()).length, 1);
    });
  });
}

void _registerAdapters() {
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
}
