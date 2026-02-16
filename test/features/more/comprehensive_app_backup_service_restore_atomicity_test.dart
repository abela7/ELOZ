import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/more/data/services/comprehensive_app_backup_service.dart';

void main() {
  group('ComprehensiveAppBackupService staged apply', () {
    test('rolls back Hive file swaps when cancelled mid-apply', () async {
      final service = ComprehensiveAppBackupService();
      final hiveDir = await Directory.systemTemp.createTemp('lmbk_hive_');
      final stageDir = await Directory.systemTemp.createTemp('lmbk_stage_');

      final taskFile = File(
        '${hiveDir.path}${Platform.pathSeparator}tasksbox.hive',
      );
      final habitFile = File(
        '${hiveDir.path}${Platform.pathSeparator}habitcompletionsbox.hive',
      );
      final stagedTaskFile = File(
        '${stageDir.path}${Platform.pathSeparator}tasksbox.hive',
      );
      final stagedHabitFile = File(
        '${stageDir.path}${Platform.pathSeparator}habitcompletionsbox.hive',
      );

      try {
        await taskFile.writeAsString('old-task', flush: true);
        await habitFile.writeAsString('old-habit', flush: true);
        await stagedTaskFile.writeAsString('new-task', flush: true);
        await stagedHabitFile.writeAsString('new-habit', flush: true);

        await expectLater(
          service.applyStagedHiveFilesForTest(
            hiveDirectory: hiveDir,
            stagingDirectory: stageDir,
            stagedHiveFiles: const <String>[
              'tasksbox.hive',
              'habitcompletionsbox.hive',
            ],
            debugCancelAfterWrites: 1,
          ),
          throwsA(isA<ComprehensiveBackupCancelledException>()),
        );

        expect(await taskFile.readAsString(), 'old-task');
        expect(await habitFile.readAsString(), 'old-habit');
      } finally {
        if (await hiveDir.exists()) {
          await hiveDir.delete(recursive: true);
        }
        if (await stageDir.exists()) {
          await stageDir.delete(recursive: true);
        }
      }
    });

    test('emits bounded phase-based progress updates during apply', () async {
      final service = ComprehensiveAppBackupService();
      final hiveDir = await Directory.systemTemp.createTemp('lmbk_hive_');
      final stageDir = await Directory.systemTemp.createTemp('lmbk_stage_');

      final stagedFiles = const <String>[
        'tasksbox.hive',
        'habitcompletionsbox.hive',
      ];
      final events = <ComprehensiveBackupProgress>[];

      try {
        for (final fileName in stagedFiles) {
          await File(
            '${hiveDir.path}${Platform.pathSeparator}$fileName',
          ).writeAsString('old-$fileName', flush: true);
          await File(
            '${stageDir.path}${Platform.pathSeparator}$fileName',
          ).writeAsString('new-$fileName', flush: true);
        }

        await service.applyStagedHiveFilesForTest(
          hiveDirectory: hiveDir,
          stagingDirectory: stageDir,
          stagedHiveFiles: stagedFiles,
          onProgress: events.add,
        );

        expect(events.isNotEmpty, isTrue);
        expect(
          events.where((e) => e.phase == ComprehensiveBackupPhase.writing),
          isNotEmpty,
        );
        expect(events.last.phase, ComprehensiveBackupPhase.finalizing);
        // Initial writing + one update per file + finalizing.
        expect(events.length, lessThanOrEqualTo(stagedFiles.length + 2));
      } finally {
        if (await hiveDir.exists()) {
          await hiveDir.delete(recursive: true);
        }
        if (await stageDir.exists()) {
          await stageDir.delete(recursive: true);
        }
      }
    });
  });
}
