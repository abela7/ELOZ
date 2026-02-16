import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/notifications/models/hub_custom_notification_type.dart';
import '../../../../core/notifications/models/universal_notification.dart';
import '../../../../data/local/hive/hive_service.dart';

class HiveDatabaseInspectorExportResult {
  final File file;
  final int boxCount;
  final int totalRecords;

  const HiveDatabaseInspectorExportResult({
    required this.file,
    required this.boxCount,
    required this.totalRecords,
  });
}

/// Developer-focused export for inspecting Hive storage.
///
/// The output is a JSON file with:
/// - all discovered Hive files
/// - per-box record counts
/// - inferred "columns" from map-serializable rows
/// - sample rows for inspection
///
/// Notes:
/// - Hive is not relational, so "columns" are inferred from row structures.
/// - Strongly-typed objects without toJson() are represented as string snapshots.
class HiveDatabaseInspectorService {
  static const String _format = 'life_manager_hive_inspector_dump';
  static const int _version = 1;

  Future<HiveDatabaseInspectorExportResult> createShareableDump({
    int sampleRowsPerBox = 50,
  }) async {
    _ensureKnownAdaptersRegistered();
    final hiveDir = await _resolveHiveDirectory();
    final hiveFiles = await _listHiveFiles(hiveDir);
    final boxes = <Map<String, dynamic>>[];
    var totalRecords = 0;

    for (final file in hiveFiles) {
      final boxName = _basenameWithoutExtension(_basename(file.path));
      final report = await _inspectBox(
        boxName: boxName,
        file: file,
        sampleRowsPerBox: sampleRowsPerBox,
      );
      boxes.add(report);
      totalRecords += _asInt(report['recordCount']);
    }

    final createdAt = DateTime.now();
    final payload = <String, dynamic>{
      'format': _format,
      'version': _version,
      'generatedAt': createdAt.toIso8601String(),
      'notes': <String>[
        'Hive boxes are treated as table-like groups for analysis.',
        'columns are inferred from serializable row keys.',
        'values without serializers are exported as snapshots.',
      ],
      'hiveDirectory': hiveDir.path,
      'boxCount': boxes.length,
      'totalRecords': totalRecords,
      'boxes': boxes,
    };

    final tempDir = await getTemporaryDirectory();
    final file = File(
      '${tempDir.path}${Platform.pathSeparator}${_buildFilename(createdAt)}',
    );
    final prettyJson = const JsonEncoder.withIndent('  ').convert(payload);
    await file.writeAsString(prettyJson, flush: true);

    return HiveDatabaseInspectorExportResult(
      file: file,
      boxCount: boxes.length,
      totalRecords: totalRecords,
    );
  }

  void _ensureKnownAdaptersRegistered() {
    if (!Hive.isAdapterRegistered(40)) {
      Hive.registerAdapter(HubCustomNotificationTypeAdapter());
    }
    if (!Hive.isAdapterRegistered(41)) {
      Hive.registerAdapter(UniversalNotificationAdapter());
    }
  }

  Future<Map<String, dynamic>> _inspectBox({
    required String boxName,
    required File file,
    required int sampleRowsPerBox,
  }) async {
    final report = <String, dynamic>{
      'boxName': boxName,
      'fileName': _basename(file.path),
      'fileBytes': await file.length(),
      'isOpenBeforeInspection': Hive.isBoxOpen(boxName),
      'openedMode': 'unknown',
      'recordCount': 0,
      'sampleCount': 0,
      'inferredColumns': <String>[],
      'valueTypeDistribution': <String, int>{},
      'sampleRows': <Map<String, dynamic>>[],
    };

    Box<dynamic>? box;
    var openedByInspector = false;

    try {
      if (Hive.isBoxOpen(boxName)) {
        box = Hive.box<dynamic>(boxName);
        report['openedMode'] = 'already_open';
      } else {
        try {
          box = await HiveService.getBox<dynamic>(boxName);
          openedByInspector = true;
          report['openedMode'] = 'encrypted';
        } catch (_) {
          // Inspector-only fallback: this service is intentionally isolated
          // from runtime repositories and may attempt plain open for analysis.
          box = await Hive.openBox<dynamic>(boxName);
          openedByInspector = true;
          report['openedMode'] = 'plain';
        }
      }

      final typeDistribution = <String, int>{};
      final columns = <String>{'_hiveKey'};
      final sampleRows = <Map<String, dynamic>>[];

      final map = box.toMap();
      report['recordCount'] = map.length;

      for (final entry in map.entries) {
        final value = entry.value;
        final typeName = value?.runtimeType.toString() ?? 'null';
        typeDistribution[typeName] = (typeDistribution[typeName] ?? 0) + 1;

        if (sampleRows.length < sampleRowsPerBox) {
          final serialized = _serializeValue(value);
          final row = <String, dynamic>{'_hiveKey': _serializeValue(entry.key)};

          if (serialized is Map<String, dynamic>) {
            row.addAll(serialized);
            columns.addAll(serialized.keys);
          } else {
            row['_value'] = serialized;
            columns.add('_value');
          }

          sampleRows.add(row);
        }
      }

      report['sampleCount'] = sampleRows.length;
      report['inferredColumns'] = columns.toList()..sort();
      report['valueTypeDistribution'] = typeDistribution;
      report['sampleRows'] = sampleRows;
    } catch (error) {
      report['error'] = '$error';
    } finally {
      if (openedByInspector && box != null && box.isOpen) {
        await box.close();
      }
    }

    return report;
  }

  dynamic _serializeValue(dynamic value, {int depth = 0}) {
    if (depth > 6) {
      return '[depth_limit]';
    }

    if (value == null || value is bool || value is num || value is String) {
      return value;
    }
    if (value is DateTime) {
      return value.toIso8601String();
    }
    if (value is Duration) {
      return <String, dynamic>{'milliseconds': value.inMilliseconds};
    }
    if (value is Uint8List) {
      return <String, dynamic>{
        'byteLength': value.length,
        'base64': base64Encode(value),
      };
    }
    if (value is List) {
      return value
          .map((dynamic item) => _serializeValue(item, depth: depth + 1))
          .toList();
    }
    if (value is Set) {
      return value
          .map((dynamic item) => _serializeValue(item, depth: depth + 1))
          .toList();
    }
    if (value is Map) {
      final out = <String, dynamic>{};
      for (final entry in value.entries) {
        out['${entry.key}'] = _serializeValue(entry.value, depth: depth + 1);
      }
      return out;
    }

    final viaToJson = _tryToJson(value, depth: depth + 1);
    if (viaToJson != null) {
      return viaToJson;
    }

    return value.toString();
  }

  dynamic _tryToJson(dynamic value, {required int depth}) {
    try {
      final converted = (value as dynamic).toJson();
      return _serializeValue(converted, depth: depth);
    } catch (_) {
      return null;
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

  Future<List<File>> _listHiveFiles(Directory directory) async {
    if (!await directory.exists()) {
      return const <File>[];
    }

    final files = <File>[];
    await for (final entity in directory.list()) {
      if (entity is! File) continue;
      final fileName = _basename(entity.path).toLowerCase();
      if (!fileName.endsWith('.hive')) continue;
      files.add(entity);
    }
    files.sort((a, b) => _basename(a.path).compareTo(_basename(b.path)));
    return files;
  }

  String _buildFilename(DateTime now) {
    final yyyy = now.year.toString().padLeft(4, '0');
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    final hh = now.hour.toString().padLeft(2, '0');
    final min = now.minute.toString().padLeft(2, '0');
    final sec = now.second.toString().padLeft(2, '0');
    return 'hive_inspector_$yyyy$mm${dd}_$hh$min$sec.json';
  }

  int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  String _basename(String path) {
    final normalized = path.replaceAll('\\', '/');
    final slash = normalized.lastIndexOf('/');
    if (slash < 0) return normalized;
    return normalized.substring(slash + 1);
  }

  String _basenameWithoutExtension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot <= 0) return fileName;
    return fileName.substring(0, dot);
  }
}
