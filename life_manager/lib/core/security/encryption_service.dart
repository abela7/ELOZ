import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for managing encryption keys securely
class EncryptionService {
  static const _storage = FlutterSecureStorage();
  static const String _encryptionKeyKey = 'hive_encryption_key';
  static String? _cachedKey;

  /// Get or create encryption key
  static Future<String> getEncryptionKey() async {
    if (_cachedKey != null) {
      return _cachedKey!;
    }

    String? key = await _storage.read(key: _encryptionKeyKey);

    if (key == null) {
      // Generate a new encryption key (32 bytes = 64 hex characters)
      key = _generateEncryptionKey();
      await _storage.write(key: _encryptionKeyKey, value: key);
    } else if (!_isValidHexKey(key)) {
      throw const FormatException(
        'Stored Hive encryption key is invalid. '
        'Secure storage may be corrupted.',
      );
    }

    _cachedKey = key;
    return key;
  }

  /// Generate a random encryption key
  static String _generateEncryptionKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static bool _isValidHexKey(String value) {
    return value.length == 64 && RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(value);
  }

  /// Clear encryption key (for testing/reset)
  static Future<void> clearEncryptionKey() async {
    await _storage.delete(key: _encryptionKeyKey);
    _cachedKey = null;
  }
}
