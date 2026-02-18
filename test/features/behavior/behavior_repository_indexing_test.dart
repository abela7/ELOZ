import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:life_manager/features/behavior/behavior_module.dart';
import 'package:life_manager/features/behavior/data/models/behavior.dart';
import 'package:life_manager/features/behavior/data/models/behavior_log.dart';
import 'package:life_manager/features/behavior/data/models/behavior_log_reason.dart';
import 'package:life_manager/features/behavior/data/models/behavior_reason.dart';
import 'package:life_manager/features/behavior/data/repositories/behavior_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;

  setUp(() async {
    hiveDir = await Directory.systemTemp.createTemp('behavior_repo_');
    Hive.init(hiveDir.path);
    _registerAdapters();
  });

  tearDown(() async {
    await Hive.close();
    if (await hiveDir.exists()) {
      await hiveDir.delete(recursive: true);
    }
  });

  group('BehaviorRepository indexing', () {
    test('updates summary and indexes on create/update/delete', () async {
      final repository = _buildRepository();
      final behavior = await repository.createBehavior(
        Behavior(
          name: 'Exercise',
          type: 'good',
          iconCodePoint: 0xe3a1,
          colorValue: 0xFF2E7D32,
          reasonRequired: true,
        ),
      );
      final reason = await repository.createReason(
        BehaviorReason(name: 'Morning routine', type: 'good'),
      );

      final day = DateTime(2026, 2, 18, 7, 0);
      final logA = await repository.createBehaviorLog(
        behaviorId: behavior.id,
        occurredAt: day,
        reasonIds: <String>[reason.id],
        durationMinutes: 30,
        intensity: 4,
      );
      final logB = await repository.createBehaviorLog(
        behaviorId: behavior.id,
        occurredAt: DateTime(2026, 2, 18, 19, 0),
        reasonIds: <String>[reason.id],
        durationMinutes: 40,
        intensity: 3,
      );

      final dateKey = '20260218';
      final summaryAfterCreate = await repository
          .getDailySummaryForBehaviorByDate(behavior.id, day);
      expect(summaryAfterCreate['totalCount'], 2);
      expect(summaryAfterCreate['totalDurationMinutes'], 70);
      expect(summaryAfterCreate['intensitySum'], 7);
      expect(summaryAfterCreate['intensityCount'], 2);

      final dateIndex = await Hive.openBox<dynamic>(
        BehaviorModule.logDateIndexBoxName,
      );
      final behaviorDateIndex = await Hive.openBox<dynamic>(
        BehaviorModule.logBehaviorDateIndexBoxName,
      );
      final ids = (dateIndex.get(dateKey) as List).cast<String>();
      expect(ids.toSet(), <String>{logA.id, logB.id});
      final byBehaviorIds =
          (behaviorDateIndex.get('${behavior.id}|$dateKey') as List)
              .cast<String>();
      expect(byBehaviorIds.toSet(), <String>{logA.id, logB.id});

      await repository.updateBehaviorLog(
        logB.id,
        durationMinutes: 50,
        intensity: 5,
      );
      final summaryAfterUpdate = await repository
          .getDailySummaryForBehaviorByDate(behavior.id, day);
      expect(summaryAfterUpdate['totalCount'], 2);
      expect(summaryAfterUpdate['totalDurationMinutes'], 80);
      expect(summaryAfterUpdate['intensitySum'], 9);
      expect(summaryAfterUpdate['intensityCount'], 2);

      final deleted = await repository.deleteBehaviorLog(logA.id);
      expect(deleted, isTrue);
      final summaryAfterDelete = await repository
          .getDailySummaryForBehaviorByDate(behavior.id, day);
      expect(summaryAfterDelete['totalCount'], 1);
      expect(summaryAfterDelete['totalDurationMinutes'], 50);
      expect(summaryAfterDelete['intensitySum'], 5);
      expect(summaryAfterDelete['intensityCount'], 1);
    });

    test(
      'bootstrap keeps recent indexed and marks older history for backfill',
      () async {
        final repository = _buildRepository();
        final behavior = await repository.createBehavior(
          Behavior(
            name: 'Reading',
            type: 'good',
            iconCodePoint: 0xe8b5,
            colorValue: 0xFF1565C0,
          ),
        );

        final logsBox = await Hive.openBox<BehaviorLog>(
          BehaviorModule.logsBoxName,
        );
        final today = DateTime.now();
        final recent = DateTime(
          today.year,
          today.month,
          today.day,
        ).subtract(const Duration(days: 2));
        final old = DateTime(
          today.year,
          today.month,
          today.day,
        ).subtract(const Duration(days: 90));
        await logsBox.put(
          'recent_log',
          BehaviorLog(
            id: 'recent_log',
            behaviorId: behavior.id,
            occurredAt: recent,
            dateKey: _dateKey(recent),
            createdAt: recent,
          ),
        );
        await logsBox.put(
          'old_log',
          BehaviorLog(
            id: 'old_log',
            behaviorId: behavior.id,
            occurredAt: old,
            dateKey: _dateKey(old),
            createdAt: old,
          ),
        );

        final recentLogs = await repository.getBehaviorLogsByDateKey(
          _dateKey(recent),
        );
        final oldLogs = await repository.getBehaviorLogsByDateKey(
          _dateKey(old),
        );
        expect(recentLogs.map((item) => item.id), contains('recent_log'));
        expect(oldLogs.map((item) => item.id), contains('old_log'));

        final status = await repository.getHistoryOptimizationStatus();
        expect(status.usingScanFallback, isFalse);
        expect(status.backfillComplete, isFalse);
      },
    );
  });
}

BehaviorRepository _buildRepository() {
  return BehaviorRepository(
    behaviorsBoxOpener: () =>
        Hive.openBox<Behavior>(BehaviorModule.behaviorsBoxName),
    reasonsBoxOpener: () =>
        Hive.openBox<BehaviorReason>(BehaviorModule.reasonsBoxName),
    logsBoxOpener: () => Hive.openBox<BehaviorLog>(BehaviorModule.logsBoxName),
    logReasonsBoxOpener: () =>
        Hive.openBox<BehaviorLogReason>(BehaviorModule.logReasonsBoxName),
    dynamicBoxOpener: (boxName) => Hive.openBox<dynamic>(boxName),
  );
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

String _dateKey(DateTime date) {
  final yyyy = date.year.toString().padLeft(4, '0');
  final mm = date.month.toString().padLeft(2, '0');
  final dd = date.day.toString().padLeft(2, '0');
  return '$yyyy$mm$dd';
}
