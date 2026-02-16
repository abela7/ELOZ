import 'dart:async';
import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/security/encryption_service.dart';
import 'migration_service.dart';

/// Service for initializing and managing Hive database
class HiveService {
  static bool _initialized = false;
  static Box? _encryptedBox;
  static List<int>? _cachedKeyBytes;
  static final Map<String, Future<Box<dynamic>>> _openingBoxes = {};
  static const Duration _boxOpenTimeout = Duration(seconds: 12);

  /// Initialize Hive database with encryption
  static Future<void> init() async {
    if (_initialized) return;

    try {
      // Initialize Hive for Flutter
      await Hive.initFlutter();

      // Get encryption key
      final encryptionKey = await EncryptionService.getEncryptionKey();

      // Convert hex string to bytes
      _cachedKeyBytes = _hexToBytes(encryptionKey);

      // Open encrypted box
      _encryptedBox = await Hive.openBox(
        'life_manager_db',
        encryptionCipher: HiveAesCipher(_cachedKeyBytes!),
      );

      // Perform migrations
      await MigrationService.migrate(_encryptedBox!);

      _initialized = true;
    } catch (e, stackTrace) {
      // Fail closed: never open unencrypted storage as a fallback.
      Error.throwWithStackTrace(
        StateError('Failed to initialize encrypted Hive storage: $e'),
        stackTrace,
      );
    }
  }

  /// Convert hex string to bytes
  static List<int> _hexToBytes(String hex) {
    final bytes = <int>[];
    for (int i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }

  /// Get the encrypted box
  static Box get box {
    if (!_initialized) {
      throw Exception('HiveService not initialized. Call init() first.');
    }
    return _encryptedBox!;
  }

  /// Get or open a named box with type support
  static Future<Box<T>> getBox<T>(String boxName) async {
    if (!_initialized) {
      throw Exception('HiveService not initialized. Call init() first.');
    }

    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<T>(boxName);
    }

    // Deduplicate concurrent open requests for the same box.
    final existingOpen = _openingBoxes[boxName];
    if (existingOpen != null) {
      return (await existingOpen) as Box<T>;
    }

    final openFuture = _openBox<T>(boxName);
    _openingBoxes[boxName] = openFuture;
    try {
      return await openFuture as Box<T>;
    } finally {
      _openingBoxes.remove(boxName);
    }
  }

  /// Get or open an encrypted box using a provided cipher key.
  ///
  /// This is used by passcode-bound secure domains (for example quit-habit
  /// secure data) while keeping all box opening logic centralized in one place.
  static Future<Box<T>> getBoxWithCipher<T>(
    String boxName, {
    required List<int> cipherKeyBytes,
  }) async {
    if (!_initialized) {
      throw Exception('HiveService not initialized. Call init() first.');
    }

    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<T>(boxName);
    }

    final existingOpen = _openingBoxes[boxName];
    if (existingOpen != null) {
      return (await existingOpen) as Box<T>;
    }

    final openFuture = _openBoxWithCipher<T>(
      boxName: boxName,
      cipherKeyBytes: List<int>.from(cipherKeyBytes),
    );
    _openingBoxes[boxName] = openFuture;
    try {
      return await openFuture as Box<T>;
    } finally {
      _openingBoxes.remove(boxName);
    }
  }

  static Future<Box<dynamic>> _openBox<T>(String boxName) async {
    _cachedKeyBytes ??= _hexToBytes(await EncryptionService.getEncryptionKey());

    return _openBoxWithCipher<T>(
      boxName: boxName,
      cipherKeyBytes: List<int>.from(_cachedKeyBytes!),
    );
  }

  static Future<Box<dynamic>> _openBoxWithCipher<T>({
    required String boxName,
    required List<int> cipherKeyBytes,
  }) async {
    try {
      return await Hive.openBox<T>(
        boxName,
        encryptionCipher: HiveAesCipher(cipherKeyBytes),
      ).timeout(_boxOpenTimeout);
    } on TimeoutException catch (e, stackTrace) {
      Error.throwWithStackTrace(
        TimeoutException(
          'Timed out opening Hive box "$boxName" after '
          '${_boxOpenTimeout.inSeconds}s.',
          e.duration,
        ),
        stackTrace,
      );
    }
  }

  /// Open an encrypted box inside a background isolate using plain config.
  ///
  /// This method is isolate-safe and does not depend on the main-isolate
  /// initialization state.
  static Future<Box<T>> openIsolateBoxWithCipher<T>({
    required String hiveDirPath,
    required String boxName,
    required List<int> cipherKeyBytes,
    void Function()? registerAdapters,
  }) async {
    Hive.init(hiveDirPath);
    registerAdapters?.call();
    return (await _openBoxWithCipher<T>(
          boxName: boxName,
          cipherKeyBytes: List<int>.from(cipherKeyBytes),
        ))
        as Box<T>;
  }

  /// Check if Hive is initialized
  static bool get isInitialized => _initialized;

  /// Build isolate-safe config for encrypted Hive access.
  /// Returns plain data only (directory path + cipher key bytes).
  static Map<String, dynamic> getIsolateOpenConfig() {
    if (!_initialized || _cachedKeyBytes == null || _encryptedBox == null) {
      throw Exception('HiveService not initialized. Call init() first.');
    }
    final boxPath = _encryptedBox!.path;
    if (boxPath == null || boxPath.isEmpty) {
      throw Exception('Hive storage path is unavailable.');
    }
    return <String, dynamic>{
      'hiveDirPath': File(boxPath).parent.path,
      'cipherKeyBytes': List<int>.from(_cachedKeyBytes!),
    };
  }

  /// Close all boxes (for cleanup)
  static Future<void> close() async {
    await Hive.close();
    _initialized = false;
    _encryptedBox = null;
    _cachedKeyBytes = null;
  }
}
