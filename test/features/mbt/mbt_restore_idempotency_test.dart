import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:life_manager/core/notifications/models/notification_hub_modules.dart';
import 'package:life_manager/core/notifications/models/universal_notification.dart';
import 'package:life_manager/features/mbt/data/models/mood.dart';
import 'package:life_manager/features/mbt/data/models/mood_entry.dart';
import 'package:life_manager/features/mbt/data/models/mood_reason.dart';
import 'package:life_manager/features/mbt/data/repositories/mood_repository.dart';
import 'package:life_manager/features/mbt/mbt_module.dart';
import 'package:life_manager/features/mbt/notifications/mbt_notification_contract.dart';
import 'package:life_manager/features/more/data/services/comprehensive_app_backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MBT restore idempotency', () {
    test(
      'applying the same staged backup twice keeps one entry/day and one MBT reminder definition',
      () async {
        final service = ComprehensiveAppBackupService();
        final seedDir = await Directory.systemTemp.createTemp('mbt_seed_');
        final stageDir = await Directory.systemTemp.createTemp('mbt_stage_');
        final targetDir = await Directory.systemTemp.createTemp('mbt_target_');
        final day = DateTime(2026, 7, 3);

        try {
          Hive.init(seedDir.path);
          _registerAdapters();

          final moodBox = await Hive.openBox<Mood>(MbtModule.moodsBoxName);
          final entryBox = await Hive.openBox<MoodEntry>(
            MbtModule.moodEntriesBoxName,
          );
          final universalBox = await Hive.openBox<UniversalNotification>(
            'universal_notifications',
          );

          final mood = Mood(
            id: 'mood_restore_target',
            name: 'Restore Stable',
            iconCodePoint: Icons.mood_rounded.codePoint,
            iconFontFamily: 'MaterialIcons',
            colorValue: const Color(0xFF1976D2).toARGB32(),
            pointValue: 2,
            reasonRequired: false,
            polarity: 'good',
          );
          await moodBox.put(mood.id, mood);

          await entryBox.put(
            'entry_restore_target',
            MoodEntry(
              id: 'entry_restore_target',
              moodId: mood.id,
              loggedAt: DateTime(day.year, day.month, day.day, 20, 0),
              createdAt: DateTime(day.year, day.month, day.day, 20, 0),
            ),
          );

          await universalBox.put(
            'mbt_mood_daily_reminder_v1',
            UniversalNotification(
              id: 'mbt_mood_daily_reminder_v1',
              moduleId: NotificationHubModuleIds.mbtMood,
              section: MbtNotificationContract.sectionMoodCheckin,
              entityId: MbtNotificationContract.entityMoodDailyCheckin,
              entityName: 'Daily Mood Check-in',
              titleTemplate: 'How was your day today?',
              bodyTemplate: 'Take a moment to log your mood.',
              typeId: MbtNotificationContract.typeMoodDailyCheckin,
              timing: 'on_due',
              timingValue: 0,
              timingUnit: 'days',
              hour: 20,
              minute: 30,
            ),
          );
          await Hive.close();

          final stagedHiveFiles = await _copyHiveFiles(
            from: seedDir,
            to: stageDir,
          );
          expect(stagedHiveFiles, isNotEmpty);

          await service.applyStagedHiveFilesForTest(
            hiveDirectory: targetDir,
            stagingDirectory: stageDir,
            stagedHiveFiles: stagedHiveFiles,
          );
          await service.applyStagedHiveFilesForTest(
            hiveDirectory: targetDir,
            stagingDirectory: stageDir,
            stagedHiveFiles: stagedHiveFiles,
          );

          Hive.init(targetDir.path);
          _registerAdapters();

          final repository = MoodRepository(
            moodsBoxOpener: () => Hive.openBox<Mood>(MbtModule.moodsBoxName),
            reasonsBoxOpener: () =>
                Hive.openBox<MoodReason>(MbtModule.moodReasonsBoxName),
            entriesBoxOpener: () =>
                Hive.openBox<MoodEntry>(MbtModule.moodEntriesBoxName),
            dynamicBoxOpener: (boxName) => Hive.openBox<dynamic>(boxName),
          );

          final byDate = await repository.getMoodEntryForDate(day);
          final rangeEntries = await repository.getMoodEntriesInRange(day, day);
          expect(byDate, isNotNull);
          expect(rangeEntries.length, 1);
          expect(rangeEntries.first.id, 'entry_restore_target');

          final universalBoxAfter = await Hive.openBox<UniversalNotification>(
            'universal_notifications',
          );
          final mbtDefs = universalBoxAfter.values
              .where(
                (item) =>
                    item.moduleId == NotificationHubModuleIds.mbtMood &&
                    item.entityId ==
                        MbtNotificationContract.entityMoodDailyCheckin,
              )
              .toList();

          expect(mbtDefs.length, 1);
          expect(mbtDefs.first.id, 'mbt_mood_daily_reminder_v1');
        } finally {
          await Hive.close();
          if (await seedDir.exists()) {
            await seedDir.delete(recursive: true);
          }
          if (await stageDir.exists()) {
            await stageDir.delete(recursive: true);
          }
          if (await targetDir.exists()) {
            await targetDir.delete(recursive: true);
          }
        }
      },
    );
  });
}

void _registerAdapters() {
  if (!Hive.isAdapterRegistered(41)) {
    Hive.registerAdapter(UniversalNotificationAdapter());
  }
  if (!Hive.isAdapterRegistered(60)) {
    Hive.registerAdapter(MoodAdapter());
  }
  if (!Hive.isAdapterRegistered(61)) {
    Hive.registerAdapter(MoodReasonAdapter());
  }
  if (!Hive.isAdapterRegistered(62)) {
    Hive.registerAdapter(MoodEntryAdapter());
  }
}

Future<List<String>> _copyHiveFiles({
  required Directory from,
  required Directory to,
}) async {
  final out = <String>[];
  await for (final entity in from.list()) {
    if (entity is! File) continue;
    if (!entity.path.toLowerCase().endsWith('.hive')) continue;
    final name = _basename(entity.path);
    await entity.copy('${to.path}${Platform.pathSeparator}$name');
    out.add(name);
  }
  out.sort();
  return out;
}

String _basename(String path) {
  final normalized = path.replaceAll('\\', '/');
  final slash = normalized.lastIndexOf('/');
  if (slash < 0) {
    return normalized;
  }
  return normalized.substring(slash + 1);
}
