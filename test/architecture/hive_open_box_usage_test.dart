import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('runtime code uses centralized Hive open path', () async {
    final allowedFiles = <String>{
      'lib/data/local/hive/hive_service.dart',
      // Inspector is intentionally isolated and may open dynamically.
      'lib/features/more/data/services/hive_database_inspector_service.dart',
    };

    final offenders = <String>[];
    final dartFiles = await _allDartFilesUnder('lib');
    for (final file in dartFiles) {
      final normalizedPath = _normalizePath(file.path);
      final source = await file.readAsString();
      if (source.contains('Hive.openBox') &&
          !allowedFiles.contains(normalizedPath)) {
        offenders.add(normalizedPath);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Direct Hive.openBox usage is only allowed in the centralized store '
          'and isolated inspector.\nFound: ${offenders.join(', ')}',
    );
  });
}

Future<List<File>> _allDartFilesUnder(String rootPath) async {
  final root = Directory(rootPath);
  if (!await root.exists()) {
    return const <File>[];
  }

  final out = <File>[];
  await for (final entity in root.list(recursive: true, followLinks: false)) {
    if (entity is File && entity.path.toLowerCase().endsWith('.dart')) {
      out.add(entity);
    }
  }
  return out;
}

String _normalizePath(String path) {
  final normalized = path.replaceAll('\\', '/');
  if (normalized.startsWith('./')) {
    return normalized.substring(2);
  }
  return normalized;
}
