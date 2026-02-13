import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/security/encryption_service.dart';
import 'migration_service.dart';

/// Service for initializing and managing Hive database
class HiveService {
  static bool _initialized = false;
  static Box? _encryptedBox;
  static List<int>? _cachedKeyBytes;

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

    // Try to open box if it doesn't exist
    if (!Hive.isBoxOpen(boxName)) {
      _cachedKeyBytes ??= _hexToBytes(
        await EncryptionService.getEncryptionKey(),
      );

      return await Hive.openBox<T>(
        boxName,
        encryptionCipher: HiveAesCipher(_cachedKeyBytes!),
      );
    }

    return Hive.box<T>(boxName);
  }

  /// Check if Hive is initialized
  static bool get isInitialized => _initialized;

  /// Close all boxes (for cleanup)
  static Future<void> close() async {
    await Hive.close();
    _initialized = false;
    _encryptedBox = null;
    _cachedKeyBytes = null;
  }
}
