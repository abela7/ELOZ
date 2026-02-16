import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../data/local/hive/hive_service.dart';

const String _workerKindKey = 'kind';
const String _workerKindControl = 'control';
const String _workerKindProgress = 'progress';
const String _workerKindResult = 'result';
const String _workerKindError = 'error';
const String _workerErrorCancelled = 'cancelled';
const String _workerControlCancel = 'cancel';

const String _workerJobExport = 'export_backup';
const String _workerJobDecodeAndStage = 'decode_and_stage_backup';
const String _workerJobApplyStaged = 'apply_staged_hive_files';
const String _workerJobNoop = 'noop_for_test';

class ComprehensiveBackupSummary {
  final DateTime backupCreatedAt;
  final int hiveFilesCount;
  final int sharedPreferencesCount;
  final int secureStorageCount;
  final int totalHiveBytes;

  const ComprehensiveBackupSummary({
    required this.backupCreatedAt,
    required this.hiveFilesCount,
    required this.sharedPreferencesCount,
    required this.secureStorageCount,
    required this.totalHiveBytes,
  });
}

Future<void> _comprehensiveBackupWorkerMain(List<dynamic> args) async {
  final sendPort = args[0] as SendPort;
  final job = args[1] as String;
  final payload = Map<String, dynamic>.from(args[2] as Map);

  final controlPort = ReceivePort();
  sendPort.send(<String, dynamic>{
    _workerKindKey: _workerKindControl,
    'port': controlPort.sendPort,
  });

  var isCancelled = false;
  final controlSub = controlPort.listen((dynamic message) {
    if (message == _workerControlCancel) {
      isCancelled = true;
    }
  });

  try {
    Map<String, dynamic> result;
    switch (job) {
      case _workerJobExport:
        result = await _workerCreateBackupFile(
          payload,
          sendPort,
          () => isCancelled,
        );
        break;
      case _workerJobDecodeAndStage:
        result = await _workerDecodeAndStageBackup(
          payload,
          sendPort,
          () => isCancelled,
        );
        break;
      case _workerJobApplyStaged:
        result = await _workerApplyStagedHiveFiles(
          payload,
          sendPort,
          () => isCancelled,
        );
        break;
      case _workerJobNoop:
        result = <String, dynamic>{'value': _asIntStatic(payload['value'])};
        break;
      default:
        throw StateError('Unknown backup worker job: $job');
    }

    sendPort.send(<String, dynamic>{
      _workerKindKey: _workerKindResult,
      'data': result,
    });
  } on ComprehensiveBackupCancelledException {
    sendPort.send(<String, dynamic>{
      _workerKindKey: _workerKindError,
      'code': _workerErrorCancelled,
      'error': 'Backup worker cancelled.',
    });
  } catch (error, stackTrace) {
    sendPort.send(<String, dynamic>{
      _workerKindKey: _workerKindError,
      'error': '$error',
      'stack': '$stackTrace',
    });
  } finally {
    await controlSub.cancel();
    controlPort.close();
  }
}

Future<Map<String, dynamic>> _workerCreateBackupFile(
  Map<String, dynamic> payload,
  SendPort sendPort,
  bool Function() isCancelled,
) async {
  final backupPath = payload['backupPath'] as String?;
  final format = payload['format'] as String?;
  final version = _asIntStatic(payload['version']);
  final createdAt = payload['createdAt'] as String?;
  final excludedModule = payload['excludedModule'] as String?;
  if (backupPath == null ||
      format == null ||
      createdAt == null ||
      excludedModule == null) {
    throw const FormatException('Invalid export payload.');
  }

  final hiveFiles = _workerAsMapList(payload['hiveFiles']);
  final sharedPreferences = _workerAsMapList(payload['sharedPreferences']);
  final secureStorage = _workerAsMapList(payload['secureStorage']);
  final financeHiveBoxes = _workerAsStringList(
    payload['financeHiveBoxes'],
  ).map((String item) => item.toLowerCase()).toSet();

  _workerSendProgress(
    sendPort,
    phase: 'reading',
    current: 0,
    total: hiveFiles.length,
    message: 'Reading Hive files...',
  );

  final hiveEntries = <Map<String, dynamic>>[];
  var totalHiveBytes = 0;
  for (var i = 0; i < hiveFiles.length; i++) {
    _workerCheckCancelled(isCancelled);
    final entry = hiveFiles[i];
    final fileName = entry['fileName'] as String?;
    final filePath = entry['path'] as String?;
    if (fileName == null || filePath == null) {
      throw const FormatException('Invalid Hive file descriptor.');
    }
    if (!_isSafeHiveFilenameStatic(fileName)) {
      continue;
    }
    final boxName = _basenameWithoutExtensionStatic(fileName);
    if (_isFinanceHiveBoxStatic(boxName, financeHiveBoxes)) {
      continue;
    }

    final bytes = await File(filePath).readAsBytes();
    totalHiveBytes += bytes.length;
    hiveEntries.add(<String, dynamic>{
      'fileName': fileName,
      'byteLength': bytes.length,
      'base64': base64Encode(bytes),
    });
    _workerSendProgress(
      sendPort,
      phase: 'reading',
      current: i + 1,
      total: hiveFiles.length,
      message: 'Reading Hive files...',
    );
  }

  _workerCheckCancelled(isCancelled);
  _workerSendProgress(
    sendPort,
    phase: 'encoding',
    current: 0,
    total: 1,
    message: 'Encoding backup payload...',
  );

  final snapshot = <String, dynamic>{
    'format': format,
    'version': version,
    'createdAt': createdAt,
    'excludedModule': excludedModule,
    'hiveFiles': hiveEntries,
    'sharedPreferences': sharedPreferences,
    'secureStorage': secureStorage,
  };
  final jsonPayload = jsonEncode(snapshot);
  final compressed = gzip.encode(utf8.encode(jsonPayload));

  _workerCheckCancelled(isCancelled);
  _workerSendProgress(
    sendPort,
    phase: 'writing',
    current: 0,
    total: 1,
    message: 'Writing backup file...',
  );

  final outputFile = File(backupPath);
  await outputFile.writeAsBytes(compressed, flush: true);

  _workerSendProgress(
    sendPort,
    phase: 'finalizing',
    current: 1,
    total: 1,
    message: 'Backup created.',
  );

  return <String, dynamic>{
    'createdAt': createdAt,
    'hiveFilesCount': hiveEntries.length,
    'sharedPreferencesCount': sharedPreferences.length,
    'secureStorageCount': secureStorage.length,
    'totalHiveBytes': totalHiveBytes,
  };
}

Future<Map<String, dynamic>> _workerDecodeAndStageBackup(
  Map<String, dynamic> payload,
  SendPort sendPort,
  bool Function() isCancelled,
) async {
  final backupPath = payload['backupPath'] as String?;
  final stagingDirPath = payload['stagingDirPath'] as String?;
  final expectedFormat = payload['expectedFormat'] as String?;
  final expectedVersion = _asIntStatic(payload['expectedVersion']);
  if (backupPath == null ||
      stagingDirPath == null ||
      expectedFormat == null ||
      expectedVersion <= 0) {
    throw const FormatException('Invalid restore payload.');
  }

  final financeHiveBoxes = _workerAsStringList(
    payload['financeHiveBoxes'],
  ).map((String item) => item.toLowerCase()).toSet();

  _workerSendProgress(
    sendPort,
    phase: 'reading',
    current: 0,
    total: 1,
    message: 'Reading backup file...',
  );
  _workerCheckCancelled(isCancelled);

  final backupBytes = await File(backupPath).readAsBytes();

  _workerCheckCancelled(isCancelled);
  _workerSendProgress(
    sendPort,
    phase: 'encoding',
    current: 0,
    total: 1,
    message: 'Decoding backup payload...',
  );

  List<int> jsonBytes;
  try {
    jsonBytes = gzip.decode(backupBytes);
  } on FormatException {
    // Backward compatibility for non-compressed JSON backup payloads.
    jsonBytes = backupBytes;
  }

  final decoded = jsonDecode(utf8.decode(jsonBytes));
  if (decoded is! Map) {
    throw const FormatException('Invalid backup structure.');
  }
  final backup = Map<String, dynamic>.from(decoded);

  if (backup['format'] != expectedFormat) {
    throw const FormatException('Unsupported backup format.');
  }
  if (_asIntStatic(backup['version']) != expectedVersion) {
    throw const FormatException('Unsupported backup version.');
  }

  final hiveEntries = _workerAsMapList(backup['hiveFiles']);
  final sharedPreferences = _workerAsMapList(backup['sharedPreferences']);
  final secureStorage = _workerAsMapList(backup['secureStorage']);
  final createdAt = backup['createdAt'] as String?;

  final stagingDir = Directory(stagingDirPath);
  if (await stagingDir.exists()) {
    await stagingDir.delete(recursive: true);
  }
  await stagingDir.create(recursive: true);

  final eligibleHiveEntries = <Map<String, dynamic>>[];
  for (final entry in hiveEntries) {
    final fileName = entry['fileName'] as String?;
    if (fileName == null || !_isSafeHiveFilenameStatic(fileName)) {
      continue;
    }
    final boxName = _basenameWithoutExtensionStatic(fileName);
    if (_isFinanceHiveBoxStatic(boxName, financeHiveBoxes)) {
      continue;
    }
    eligibleHiveEntries.add(entry);
  }

  _workerSendProgress(
    sendPort,
    phase: 'writing',
    current: 0,
    total: eligibleHiveEntries.length,
    message: 'Staging Hive files...',
  );

  final stagedHiveFiles = <String>[];
  var totalHiveBytes = 0;
  for (var i = 0; i < eligibleHiveEntries.length; i++) {
    _workerCheckCancelled(isCancelled);
    final entry = eligibleHiveEntries[i];
    final fileName = entry['fileName'] as String?;
    final base64Payload = entry['base64'] as String?;
    if (fileName == null || base64Payload == null) {
      throw const FormatException('Invalid Hive backup entry.');
    }

    final bytes = base64Decode(base64Payload);
    totalHiveBytes += bytes.length;
    final stagedPath =
        '${stagingDir.path}${Platform.pathSeparator}${_basenameStatic(fileName)}';
    await File(stagedPath).writeAsBytes(bytes, flush: true);
    stagedHiveFiles.add(_basenameStatic(fileName));

    _workerSendProgress(
      sendPort,
      phase: 'writing',
      current: i + 1,
      total: eligibleHiveEntries.length,
      message: 'Staging Hive files...',
    );
  }

  _workerSendProgress(
    sendPort,
    phase: 'finalizing',
    current: 1,
    total: 1,
    message: 'Backup decoded.',
  );

  return <String, dynamic>{
    'createdAt': createdAt,
    'sharedPreferences': sharedPreferences,
    'secureStorage': secureStorage,
    'stagedHiveFiles': stagedHiveFiles,
    'totalHiveBytes': totalHiveBytes,
  };
}

Future<Map<String, dynamic>> _workerApplyStagedHiveFiles(
  Map<String, dynamic> payload,
  SendPort sendPort,
  bool Function() isCancelled,
) async {
  final hiveDirectoryPath = payload['hiveDirectoryPath'] as String?;
  final stagingDirPath = payload['stagingDirPath'] as String?;
  if (hiveDirectoryPath == null || stagingDirPath == null) {
    throw const FormatException('Invalid apply payload.');
  }

  final financeHiveBoxes = _workerAsStringList(
    payload['financeHiveBoxes'],
  ).map((String item) => item.toLowerCase()).toSet();
  final stagedHiveFiles = _workerAsStringList(payload['stagedHiveFiles']);

  final eligibleFileNames = stagedHiveFiles.where((String fileName) {
    if (!_isSafeHiveFilenameStatic(fileName)) {
      return false;
    }
    final boxName = _basenameWithoutExtensionStatic(fileName);
    return !_isFinanceHiveBoxStatic(boxName, financeHiveBoxes);
  }).toList()..sort();

  _workerSendProgress(
    sendPort,
    phase: 'writing',
    current: 0,
    total: eligibleFileNames.length,
    message: 'Applying Hive files...',
  );

  final hiveDir = Directory(hiveDirectoryPath);
  if (!await hiveDir.exists()) {
    await hiveDir.create(recursive: true);
  }
  final stagingDir = Directory(stagingDirPath);
  if (!await stagingDir.exists()) {
    throw StateError('Restore staging directory does not exist.');
  }

  final rollbackDir = Directory(
    '${hiveDir.path}${Platform.pathSeparator}.lmbk_rollback_${DateTime.now().microsecondsSinceEpoch}',
  );
  await rollbackDir.create(recursive: true);

  final replacedFiles = <Map<String, String>>[];
  final newFiles = <String>[];

  try {
    for (var i = 0; i < eligibleFileNames.length; i++) {
      _workerCheckCancelled(isCancelled);
      final fileName = eligibleFileNames[i];
      final stagedFilePath =
          '${stagingDir.path}${Platform.pathSeparator}$fileName';
      final targetFilePath =
          '${hiveDir.path}${Platform.pathSeparator}$fileName';
      final rollbackFilePath =
          '${rollbackDir.path}${Platform.pathSeparator}$fileName';

      final stagedFile = File(stagedFilePath);
      if (!await stagedFile.exists()) {
        continue;
      }

      final targetFile = File(targetFilePath);
      if (await targetFile.exists()) {
        await targetFile.rename(rollbackFilePath);
        replacedFiles.add(<String, String>{
          'target': targetFilePath,
          'rollback': rollbackFilePath,
        });
      }

      await stagedFile.copy(targetFilePath);
      newFiles.add(targetFilePath);

      _workerSendProgress(
        sendPort,
        phase: 'writing',
        current: i + 1,
        total: eligibleFileNames.length,
        message: 'Applying Hive files...',
      );
    }
  } catch (_) {
    for (final targetPath in newFiles) {
      final file = File(targetPath);
      if (await file.exists()) {
        await file.delete();
      }
    }

    for (final replaced in replacedFiles.reversed) {
      final rollbackPath = replaced['rollback'];
      final targetPath = replaced['target'];
      if (rollbackPath == null || targetPath == null) {
        continue;
      }
      final rollbackFile = File(rollbackPath);
      if (await rollbackFile.exists()) {
        await rollbackFile.rename(targetPath);
      }
    }

    rethrow;
  } finally {
    if (await rollbackDir.exists()) {
      await rollbackDir.delete(recursive: true);
    }
  }

  _workerSendProgress(
    sendPort,
    phase: 'finalizing',
    current: 1,
    total: 1,
    message: 'Hive files applied.',
  );

  return <String, dynamic>{'appliedHiveFilesCount': eligibleFileNames.length};
}

void _workerSendProgress(
  SendPort sendPort, {
  required String phase,
  required int current,
  required int total,
  required String message,
}) {
  sendPort.send(<String, dynamic>{
    _workerKindKey: _workerKindProgress,
    'phase': phase,
    'current': current,
    'total': total,
    'message': message,
  });
}

void _workerCheckCancelled(bool Function() isCancelled) {
  if (isCancelled()) {
    throw const ComprehensiveBackupCancelledException();
  }
}

List<Map<String, dynamic>> _workerAsMapList(Object? value) {
  if (value is! List) {
    throw const FormatException('Invalid backup structure.');
  }
  return value
      .map((dynamic item) => Map<String, dynamic>.from(item as Map))
      .toList();
}

List<String> _workerAsStringList(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return value.map((dynamic item) => '$item').toList();
}

bool _isSafeHiveFilenameStatic(String fileName) {
  final normalized = fileName.trim();
  if (normalized.isEmpty) {
    return false;
  }
  if (normalized.contains('/') || normalized.contains('\\')) {
    return false;
  }
  if (normalized.contains('..')) {
    return false;
  }
  return normalized.toLowerCase().endsWith('.hive');
}

bool _isFinanceHiveBoxStatic(String boxName, Set<String> financeHiveBoxes) {
  final normalized = boxName.toLowerCase();
  if (financeHiveBoxes.contains(normalized)) {
    return true;
  }
  return normalized.startsWith('finance');
}

String _basenameStatic(String path) {
  final normalized = path.replaceAll('\\', '/');
  final slash = normalized.lastIndexOf('/');
  if (slash < 0) {
    return normalized;
  }
  return normalized.substring(slash + 1);
}

String _basenameWithoutExtensionStatic(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot <= 0) {
    return fileName;
  }
  return fileName.substring(0, dot);
}

int _asIntStatic(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  return 0;
}

class ComprehensiveBackupCreateResult {
  final File file;
  final ComprehensiveBackupSummary summary;

  const ComprehensiveBackupCreateResult({
    required this.file,
    required this.summary,
  });
}

class ComprehensiveBackupRestoreResult {
  final ComprehensiveBackupSummary summary;
  final bool restartRecommended;

  const ComprehensiveBackupRestoreResult({
    required this.summary,
    required this.restartRecommended,
  });
}

enum ComprehensiveBackupPhase {
  scanning,
  reading,
  encoding,
  writing,
  finalizing,
}

class ComprehensiveBackupProgress {
  final ComprehensiveBackupPhase phase;
  final int current;
  final int total;
  final String message;

  const ComprehensiveBackupProgress({
    required this.phase,
    required this.current,
    required this.total,
    required this.message,
  });

  double? get fraction {
    if (total <= 0) return null;
    return (current / total).clamp(0.0, 1.0);
  }

  factory ComprehensiveBackupProgress.fromMessage(Map<String, dynamic> map) {
    final phaseName = (map['phase'] as String?) ?? 'scanning';
    return ComprehensiveBackupProgress(
      phase: _phaseFromName(phaseName),
      current: _asIntStatic(map['current']),
      total: _asIntStatic(map['total']),
      message: (map['message'] as String?) ?? 'Working...',
    );
  }

  static ComprehensiveBackupPhase _phaseFromName(String value) {
    switch (value) {
      case 'scanning':
        return ComprehensiveBackupPhase.scanning;
      case 'reading':
        return ComprehensiveBackupPhase.reading;
      case 'encoding':
        return ComprehensiveBackupPhase.encoding;
      case 'writing':
        return ComprehensiveBackupPhase.writing;
      case 'finalizing':
      default:
        return ComprehensiveBackupPhase.finalizing;
    }
  }
}

class ComprehensiveBackupCancellationToken {
  bool _isCancelled = false;

  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }
}

class ComprehensiveBackupCancelledException implements Exception {
  const ComprehensiveBackupCancelledException();

  @override
  String toString() => 'Comprehensive backup operation was cancelled.';
}

/// App-wide backup/restore excluding Finance module storage.
///
/// Heavy file and transformation work is executed in a background isolate.
/// Plugin operations (SharedPreferences, secure storage, Hive lifecycle) remain
/// on the main isolate.
class ComprehensiveAppBackupService {
  static const String _backupFormat = 'life_manager_comprehensive_backup';
  static const int _backupVersion = 1;
  static const String _backupFileExtension = 'lmbk';

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static const Set<String> _financeHiveBoxes = <String>{
    'transactionsbox',
    'transactioncategoriesbox',
    'transactiontemplatesbox',
    'budgetsbox',
    'accountsbox',
    'dailybalancesbox',
    'debtcategoriesbox',
    'debtsbox',
    'billcategoriesbox',
    'billsbox',
    'savingsgoalsbox',
    'recurring_incomes',
  };

  static const Set<String> _financePreferenceExactKeys = <String>{
    'default_currency',
    'finance_initial_setup_done',
    'finance_notification_settings_v1',
    'finance_bill_notification_profiles_v1',
    'bill_category_migrated_v1',
    'debt_category_migrated_v1',
    'notification_hub_module_settings_v1_finance',
  };

  @visibleForTesting
  static int debugWorkerLaunchCount = 0;

  Future<ComprehensiveBackupCreateResult> createShareableBackup({
    void Function(ComprehensiveBackupProgress progress)? onProgress,
    ComprehensiveBackupCancellationToken? cancellationToken,
  }) async {
    _emitProgress(
      onProgress,
      const ComprehensiveBackupProgress(
        phase: ComprehensiveBackupPhase.scanning,
        current: 0,
        total: 1,
        message: 'Preparing backup...',
      ),
    );
    _throwIfCancelled(cancellationToken);

    await _flushOpenBoxes();
    final hiveDir = await _resolveHiveDirectory();
    final hiveFiles = await _discoverEligibleHiveFiles(hiveDir);
    final sharedPreferences = await _captureSharedPreferences();
    final secureStorage = await _captureSecureStorage();

    _throwIfCancelled(cancellationToken);

    final createdAt = DateTime.now();
    final tempDir = await getTemporaryDirectory();
    final backupPath =
        '${tempDir.path}${Platform.pathSeparator}${_buildBackupFilename(createdAt)}';

    try {
      final result = await _runWorkerJob(
        job: _workerJobExport,
        payload: <String, dynamic>{
          'backupPath': backupPath,
          'format': _backupFormat,
          'version': _backupVersion,
          'createdAt': createdAt.toIso8601String(),
          'excludedModule': 'finance',
          'financeHiveBoxes': _financeHiveBoxes.toList(),
          'hiveFiles': hiveFiles,
          'sharedPreferences': sharedPreferences,
          'secureStorage': secureStorage,
        },
        onProgress: onProgress,
        cancellationToken: cancellationToken,
      );

      final summary = ComprehensiveBackupSummary(
        backupCreatedAt:
            DateTime.tryParse((result['createdAt'] as String?) ?? '') ??
            createdAt,
        hiveFilesCount: _asInt(result['hiveFilesCount']),
        sharedPreferencesCount: _asInt(result['sharedPreferencesCount']),
        secureStorageCount: _asInt(result['secureStorageCount']),
        totalHiveBytes: _asInt(result['totalHiveBytes']),
      );

      return ComprehensiveBackupCreateResult(
        file: File(backupPath),
        summary: summary,
      );
    } on ComprehensiveBackupCancelledException {
      final file = File(backupPath);
      if (await file.exists()) {
        await file.delete();
      }
      rethrow;
    }
  }

  Future<ComprehensiveBackupRestoreResult> restoreFromFile({
    required File file,
    void Function(ComprehensiveBackupProgress progress)? onProgress,
    ComprehensiveBackupCancellationToken? cancellationToken,
  }) async {
    if (!await file.exists()) {
      throw StateError('Backup file does not exist.');
    }

    _emitProgress(
      onProgress,
      const ComprehensiveBackupProgress(
        phase: ComprehensiveBackupPhase.scanning,
        current: 0,
        total: 1,
        message: 'Reading backup...',
      ),
    );
    _throwIfCancelled(cancellationToken);

    final tempDir = await getTemporaryDirectory();
    final stagingDirPath =
        '${tempDir.path}${Platform.pathSeparator}lmbk_restore_stage_${DateTime.now().microsecondsSinceEpoch}';
    var hiveClosed = false;
    try {
      final decoded = await _runWorkerJob(
        job: _workerJobDecodeAndStage,
        payload: <String, dynamic>{
          'backupPath': file.path,
          'stagingDirPath': stagingDirPath,
          'expectedFormat': _backupFormat,
          'expectedVersion': _backupVersion,
          'financeHiveBoxes': _financeHiveBoxes.toList(),
        },
        onProgress: onProgress,
        cancellationToken: cancellationToken,
      );

      _throwIfCancelled(cancellationToken);

      final createdAtRaw = decoded['createdAt'] as String?;
      final createdAt = createdAtRaw == null
          ? DateTime.now()
          : DateTime.tryParse(createdAtRaw) ?? DateTime.now();
      final prefsEntries = _asMapList(decoded['sharedPreferences']);
      final secureEntries = _asMapList(decoded['secureStorage']);
      final stagedHiveFiles = _asStringList(decoded['stagedHiveFiles']);
      final totalHiveBytes = _asInt(decoded['totalHiveBytes']);

      final hiveDir = await _resolveHiveDirectory();
      await HiveService.close();
      hiveClosed = true;

      _emitProgress(
        onProgress,
        const ComprehensiveBackupProgress(
          phase: ComprehensiveBackupPhase.writing,
          current: 0,
          total: 3,
          message: 'Applying Hive files...',
        ),
      );
      // Do not force-kill this worker on cancel; it can roll back safely.
      await _runWorkerJob(
        job: _workerJobApplyStaged,
        payload: <String, dynamic>{
          'hiveDirectoryPath': hiveDir.path,
          'stagingDirPath': stagingDirPath,
          'stagedHiveFiles': stagedHiveFiles,
          'financeHiveBoxes': _financeHiveBoxes.toList(),
        },
        onProgress: onProgress,
        cancellationToken: cancellationToken,
        forceKillOnCancel: false,
      );

      _emitProgress(
        onProgress,
        const ComprehensiveBackupProgress(
          phase: ComprehensiveBackupPhase.writing,
          current: 1,
          total: 3,
          message: 'Restoring secure storage...',
        ),
      );
      await _restoreSecureStorage(secureEntries);

      _emitProgress(
        onProgress,
        const ComprehensiveBackupProgress(
          phase: ComprehensiveBackupPhase.writing,
          current: 2,
          total: 3,
          message: 'Restoring app settings...',
        ),
      );
      await _restoreSharedPreferences(prefsEntries);

      _emitProgress(
        onProgress,
        const ComprehensiveBackupProgress(
          phase: ComprehensiveBackupPhase.finalizing,
          current: 1,
          total: 1,
          message: 'Import completed.',
        ),
      );

      return ComprehensiveBackupRestoreResult(
        summary: ComprehensiveBackupSummary(
          backupCreatedAt: createdAt,
          hiveFilesCount: stagedHiveFiles.length,
          sharedPreferencesCount: prefsEntries.length,
          secureStorageCount: secureEntries.length,
          totalHiveBytes: totalHiveBytes,
        ),
        // In-memory providers/services may still hold stale state until relaunch.
        restartRecommended: true,
      );
    } finally {
      await _safeDeleteDirectory(Directory(stagingDirPath));
      if (hiveClosed) {
        try {
          await HiveService.init();
        } catch (error) {
          debugPrint('Backup restore: Hive reinit warning: $error');
        }
      }
    }
  }

  @visibleForTesting
  Future<int> runNoopIsolateJobForTest(int value) async {
    final result = await _runWorkerJob(
      job: _workerJobNoop,
      payload: <String, dynamic>{'value': value},
    );
    return _asInt(result['value']);
  }

  Future<Map<String, dynamic>> _runWorkerJob({
    required String job,
    required Map<String, dynamic> payload,
    void Function(ComprehensiveBackupProgress progress)? onProgress,
    ComprehensiveBackupCancellationToken? cancellationToken,
    bool forceKillOnCancel = true,
  }) async {
    final receivePort = ReceivePort();
    Isolate? isolate;
    SendPort? controlPort;
    final completer = Completer<Map<String, dynamic>>();
    StreamSubscription? receiveSub;
    Timer? cancellationTimer;
    var cancellationSent = false;

    try {
      debugWorkerLaunchCount++;
      isolate = await Isolate.spawn<List<dynamic>>(
        _comprehensiveBackupWorkerMain,
        <dynamic>[receivePort.sendPort, job, payload],
      );

      receiveSub = receivePort.listen((dynamic message) {
        if (message is! Map) {
          return;
        }

        final kind = message[_workerKindKey];
        if (kind == _workerKindControl) {
          final port = message['port'];
          if (port is SendPort) {
            controlPort = port;
          }
          return;
        }

        if (kind == _workerKindProgress) {
          _emitProgress(
            onProgress,
            ComprehensiveBackupProgress.fromMessage(
              Map<String, dynamic>.from(message),
            ),
          );
          return;
        }

        if (kind == _workerKindResult) {
          if (!completer.isCompleted) {
            final data = message['data'];
            if (data is Map) {
              completer.complete(Map<String, dynamic>.from(data));
            } else {
              completer.complete(<String, dynamic>{});
            }
          }
          return;
        }

        if (kind == _workerKindError && !completer.isCompleted) {
          final code = message['code'] as String?;
          if (code == _workerErrorCancelled) {
            completer.completeError(
              const ComprehensiveBackupCancelledException(),
            );
          } else {
            completer.completeError(
              StateError(
                (message['error'] as String?) ?? 'Backup worker failed.',
              ),
            );
          }
        }
      });

      if (cancellationToken != null) {
        cancellationTimer = Timer.periodic(const Duration(milliseconds: 80), (
          _,
        ) {
          if (!cancellationToken.isCancelled || cancellationSent) {
            return;
          }

          cancellationSent = true;
          controlPort?.send(_workerControlCancel);

          if (forceKillOnCancel) {
            isolate?.kill(priority: Isolate.immediate);
            if (!completer.isCompleted) {
              completer.completeError(
                const ComprehensiveBackupCancelledException(),
              );
            }
          }
        });
      }

      return await completer.future;
    } finally {
      cancellationTimer?.cancel();
      await receiveSub?.cancel();
      receivePort.close();
      isolate?.kill(priority: Isolate.immediate);
    }
  }

  void _emitProgress(
    void Function(ComprehensiveBackupProgress progress)? onProgress,
    ComprehensiveBackupProgress progress,
  ) {
    if (onProgress == null) return;
    onProgress(progress);
  }

  void _throwIfCancelled(ComprehensiveBackupCancellationToken? token) {
    if (token?.isCancelled == true) {
      throw const ComprehensiveBackupCancelledException();
    }
  }

  Future<void> _flushOpenBoxes() async {
    final hiveDir = await _resolveHiveDirectory();
    if (!await hiveDir.exists()) return;

    await for (final entity in hiveDir.list()) {
      if (entity is! File) continue;
      final fileName = _basename(entity.path);
      if (!fileName.toLowerCase().endsWith('.hive')) continue;
      final boxName = _basenameWithoutExtension(fileName);
      if (!Hive.isBoxOpen(boxName)) continue;
      try {
        await Hive.box(boxName).flush();
      } catch (error) {
        debugPrint('Backup flush warning for box "$boxName": $error');
      }
    }
  }

  Future<Directory> _resolveHiveDirectory() async {
    if (Hive.isBoxOpen('life_manager_db')) {
      final path = Hive.box('life_manager_db').path;
      if (path != null && path.isNotEmpty) {
        return File(path).parent;
      }
    }
    return getApplicationDocumentsDirectory();
  }

  Future<List<Map<String, String>>> _discoverEligibleHiveFiles(
    Directory hiveDir,
  ) async {
    if (!await hiveDir.exists()) {
      return const <Map<String, String>>[];
    }

    final entries = <Map<String, String>>[];
    await for (final entity in hiveDir.list()) {
      if (entity is! File) {
        continue;
      }

      final fileName = _basename(entity.path);
      if (!fileName.toLowerCase().endsWith('.hive')) {
        continue;
      }

      final boxName = _basenameWithoutExtension(fileName);
      if (_isFinanceHiveBox(boxName)) {
        continue;
      }

      entries.add(<String, String>{'fileName': fileName, 'path': entity.path});
    }

    entries.sort((a, b) => a['fileName']!.compareTo(b['fileName']!));
    return entries;
  }

  Future<List<Map<String, dynamic>>> _captureSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().toList()..sort();
    final entries = <Map<String, dynamic>>[];

    for (final key in keys) {
      if (_isFinancePreferenceKey(key)) {
        continue;
      }

      final value = prefs.get(key);
      final encoded = _encodePreferenceValue(value);
      if (encoded == null) {
        continue;
      }

      entries.add(<String, dynamic>{
        'key': key,
        'type': encoded['type'],
        'value': encoded['value'],
      });
    }

    return entries;
  }

  Future<List<Map<String, dynamic>>> _captureSecureStorage() async {
    final all = await _secureStorage.readAll();
    final keys = all.keys.toList()..sort();
    final entries = <Map<String, dynamic>>[];

    for (final key in keys) {
      if (_isFinanceSecureStorageKey(key)) {
        continue;
      }
      final value = all[key];
      if (value == null) {
        continue;
      }
      entries.add(<String, dynamic>{'key': key, 'value': value});
    }

    return entries;
  }

  Future<void> _restoreSharedPreferences(
    List<Map<String, dynamic>> entries,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final existingKeys = prefs.getKeys();
    for (final key in existingKeys) {
      if (_isFinancePreferenceKey(key)) {
        continue;
      }
      await prefs.remove(key);
    }

    for (final entry in entries) {
      final key = entry['key'] as String?;
      final type = entry['type'] as String?;
      if (key == null || type == null || _isFinancePreferenceKey(key)) {
        continue;
      }

      final value = entry['value'];
      switch (type) {
        case 'bool':
          if (value is bool) {
            await prefs.setBool(key, value);
          }
          break;
        case 'int':
          await prefs.setInt(key, _asInt(value));
          break;
        case 'double':
          await prefs.setDouble(key, _asDouble(value));
          break;
        case 'string':
          if (value is String) {
            await prefs.setString(key, value);
          }
          break;
        case 'stringList':
          if (value is List) {
            await prefs.setStringList(
              key,
              value.map((dynamic item) => '$item').toList(),
            );
          }
          break;
        default:
          break;
      }
    }
  }

  Future<void> _restoreSecureStorage(List<Map<String, dynamic>> entries) async {
    final existing = await _secureStorage.readAll();
    for (final key in existing.keys) {
      if (_isFinanceSecureStorageKey(key)) {
        continue;
      }
      await _secureStorage.delete(key: key);
    }

    for (final entry in entries) {
      final key = entry['key'] as String?;
      final value = entry['value'] as String?;
      if (key == null || value == null || _isFinanceSecureStorageKey(key)) {
        continue;
      }
      await _secureStorage.write(key: key, value: value);
    }
  }

  Future<void> _safeDeleteDirectory(Directory directory) async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  Map<String, dynamic>? _encodePreferenceValue(Object? value) {
    if (value is bool) {
      return <String, dynamic>{'type': 'bool', 'value': value};
    }
    if (value is int) {
      return <String, dynamic>{'type': 'int', 'value': value};
    }
    if (value is double) {
      return <String, dynamic>{'type': 'double', 'value': value};
    }
    if (value is String) {
      return <String, dynamic>{'type': 'string', 'value': value};
    }
    if (value is List<String>) {
      return <String, dynamic>{'type': 'stringList', 'value': value};
    }
    return null;
  }

  String _buildBackupFilename(DateTime now) {
    final yyyy = now.year.toString().padLeft(4, '0');
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    final hh = now.hour.toString().padLeft(2, '0');
    final min = now.minute.toString().padLeft(2, '0');
    final sec = now.second.toString().padLeft(2, '0');
    return 'life_manager_backup_$yyyy$mm${dd}_$hh$min$sec.$_backupFileExtension';
  }

  @visibleForTesting
  static bool isFinanceHiveBoxName(String boxName) {
    final normalized = boxName.toLowerCase();
    if (_financeHiveBoxes.contains(normalized)) {
      return true;
    }
    return normalized.startsWith('finance');
  }

  @visibleForTesting
  static bool isFinanceHiveFileName(String fileName) {
    final lower = fileName.toLowerCase();
    if (!lower.endsWith('.hive')) {
      return false;
    }
    final boxName = lower.substring(0, lower.length - 5);
    return isFinanceHiveBoxName(boxName);
  }

  bool _isFinanceHiveBox(String boxName) {
    return isFinanceHiveBoxName(boxName);
  }

  bool _isFinancePreferenceKey(String key) {
    if (_financePreferenceExactKeys.contains(key)) {
      return true;
    }
    if (key.startsWith('finance_')) {
      return true;
    }
    return false;
  }

  bool _isFinanceSecureStorageKey(String key) {
    return key.startsWith('finance_');
  }

  List<Map<String, dynamic>> _asMapList(Object? value) {
    if (value is! List) {
      throw const FormatException('Invalid backup structure.');
    }
    return value
        .map((dynamic item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  List<String> _asStringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return value.map((dynamic item) => '$item').toList();
  }

  int _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  double _asDouble(Object? value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? 0;
    }
    return 0;
  }

  String _basename(String path) {
    final normalized = path.replaceAll('\\', '/');
    final slash = normalized.lastIndexOf('/');
    if (slash < 0) {
      return normalized;
    }
    return normalized.substring(slash + 1);
  }

  String _basenameWithoutExtension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot <= 0) {
      return fileName;
    }
    return fileName.substring(0, dot);
  }
}
