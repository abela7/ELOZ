import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

import '../../../../data/local/hive/hive_service.dart';

/// Passcode-bound secure storage for quit-habit data.
///
/// - Uses PBKDF2-HMAC-SHA256 to derive an unwrap key from the passcode.
/// - Stores only wrapped key material in secure storage.
/// - Keeps the actual data key in memory only while unlocked.
class QuitHabitSecureStorageService {
  static const _storage = FlutterSecureStorage();
  static const _wrappedDataKeyKey = 'quit_habit_data_key_wrapped_v1';
  static const _kdfSaltKey = 'quit_habit_data_key_kdf_salt_v1';
  static const _kdfIterationsKey = 'quit_habit_data_key_kdf_iter_v1';
  static const _dataKeyCheckKey = 'quit_habit_data_key_check_v1';

  static const int _kdfIterations = 120000;
  static const int _keyLengthBytes = 32;
  static const int _saltLengthBytes = 16;

  static const String secureHabitsBoxName = 'quitHabitsSecureBox';
  static const String secureCompletionsBoxName =
      'quitHabitCompletionsSecureBox';
  static const String secureReasonsBoxName = 'quitHabitReasonsSecureBox';
  static const String secureTemptationsBoxName = 'quitTemptationLogsSecureBox';

  static const List<String> _secureBoxNames = <String>[
    secureHabitsBoxName,
    secureCompletionsBoxName,
    secureReasonsBoxName,
    secureTemptationsBoxName,
  ];

  static List<int>? _sessionDataKeyBytes;

  final Random _random;

  QuitHabitSecureStorageService({Random? random})
    : _random = random ?? Random.secure();

  bool get isSessionUnlocked =>
      _sessionDataKeyBytes != null &&
      _sessionDataKeyBytes!.length == _keyLengthBytes;

  Future<bool> hasDataKeyIntegrityCheck() async {
    final check = await _storage.read(key: _dataKeyCheckKey);
    return check != null && check.isNotEmpty;
  }

  Future<bool> hasProvisionedWrappedDataKey() async {
    final wrapped = await _storage.read(key: _wrappedDataKeyKey);
    final salt = await _storage.read(key: _kdfSaltKey);
    return wrapped != null &&
        wrapped.isNotEmpty &&
        salt != null &&
        salt.isNotEmpty;
  }

  Future<void> ensureProvisionedForPasscode(String passcode) async {
    if (await hasProvisionedWrappedDataKey()) return;

    final dataKey = _generateRandomBytes(_keyLengthBytes);
    final salt = _generateRandomBytes(_saltLengthBytes);
    final derived = await _derivePbkdf2KeyAsync(
      secret: passcode,
      salt: salt,
      iterations: _kdfIterations,
      keyLength: _keyLengthBytes,
    );
    final wrapped = _xorBytes(dataKey, derived);

    await _storage.write(key: _wrappedDataKeyKey, value: base64Encode(wrapped));
    await _storage.write(key: _kdfSaltKey, value: base64Encode(salt));
    await _storage.write(
      key: _kdfIterationsKey,
      value: _kdfIterations.toString(),
    );
    await _storage.write(
      key: _dataKeyCheckKey,
      value: _deriveDataKeyCheck(dataKey),
    );
  }

  /// Called after passcode is set/changed.
  ///
  /// If a secure data key exists, this re-wraps the same key using the new
  /// passcode. Requires an active unlocked session to avoid data loss.
  Future<void> onPasscodeSet(String newPasscode) async {
    final hasWrapped = await hasProvisionedWrappedDataKey();
    if (!hasWrapped) {
      await ensureProvisionedForPasscode(newPasscode);
      await unlockWithPasscode(newPasscode);
      return;
    }

    final dataKey = _sessionDataKeyBytes;
    if (dataKey == null) {
      throw StateError(
        'Quit secure data is locked. Unlock with current passcode before changing passcode.',
      );
    }

    final salt = _generateRandomBytes(_saltLengthBytes);
    final derived = await _derivePbkdf2KeyAsync(
      secret: newPasscode,
      salt: salt,
      iterations: _kdfIterations,
      keyLength: _keyLengthBytes,
    );
    final wrapped = _xorBytes(dataKey, derived);

    await _storage.write(key: _wrappedDataKeyKey, value: base64Encode(wrapped));
    await _storage.write(key: _kdfSaltKey, value: base64Encode(salt));
    await _storage.write(
      key: _kdfIterationsKey,
      value: _kdfIterations.toString(),
    );
    await _storage.write(
      key: _dataKeyCheckKey,
      value: _deriveDataKeyCheck(dataKey),
    );
    await unlockWithPasscode(newPasscode);
  }

  Future<bool> unlockWithPasscode(String passcode) async {
    final hasWrappedKey = await hasProvisionedWrappedDataKey();
    if (!hasWrappedKey) {
      return false;
    }

    final wrappedRaw = await _storage.read(key: _wrappedDataKeyKey);
    final saltRaw = await _storage.read(key: _kdfSaltKey);
    if (wrappedRaw == null || saltRaw == null) return false;

    final wrapped = _safeBase64Decode(wrappedRaw);
    final salt = _safeBase64Decode(saltRaw);
    if (wrapped == null || salt == null) return false;

    final iterRaw = await _storage.read(key: _kdfIterationsKey);
    final iterations = int.tryParse(iterRaw ?? '') ?? _kdfIterations;
    final derived = await _derivePbkdf2KeyAsync(
      secret: passcode,
      salt: salt,
      iterations: iterations,
      keyLength: _keyLengthBytes,
    );
    final dataKey = _xorBytes(wrapped, derived);
    if (dataKey.length != _keyLengthBytes) return false;

    final expectedCheck = await _storage.read(key: _dataKeyCheckKey);
    if (expectedCheck != null && expectedCheck.isNotEmpty) {
      final computedCheck = _deriveDataKeyCheck(dataKey);
      if (!_constantTimeEquals(expectedCheck, computedCheck)) {
        return false;
      }
    }

    _sessionDataKeyBytes = dataKey;
    return true;
  }

  /// Legacy bootstrap: persist integrity metadata once we already trust that
  /// the current unlocked session came from a verified passcode.
  Future<void> bootstrapDataKeyIntegrityCheckFromUnlockedSession() async {
    final sessionKey = _sessionDataKeyBytes;
    if (sessionKey == null || sessionKey.length != _keyLengthBytes) return;
    if (await hasDataKeyIntegrityCheck()) return;
    await _storage.write(
      key: _dataKeyCheckKey,
      value: _deriveDataKeyCheck(sessionKey),
    );
  }

  Future<Box<T>> openSecureBox<T>(String boxName) async {
    final key = _sessionDataKeyBytes;
    if (key == null) {
      throw StateError('Quit secure storage is locked.');
    }

    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<T>(boxName);
    }

    return HiveService.getBoxWithCipher<T>(boxName, cipherKeyBytes: key);
  }

  Future<void> lockSession() async {
    for (final boxName in _secureBoxNames) {
      if (Hive.isBoxOpen(boxName)) {
        await Hive.box(boxName).close();
      }
    }
    final existing = _sessionDataKeyBytes;
    if (existing != null) {
      for (var i = 0; i < existing.length; i++) {
        existing[i] = 0;
      }
    }
    _sessionDataKeyBytes = null;
  }

  Future<void> wipeAllSecureData() async {
    await lockSession();
    for (final boxName in _secureBoxNames) {
      final exists = await Hive.boxExists(boxName);
      if (exists) {
        await Hive.deleteBoxFromDisk(boxName);
      }
    }
    await _storage.delete(key: _wrappedDataKeyKey);
    await _storage.delete(key: _kdfSaltKey);
    await _storage.delete(key: _kdfIterationsKey);
    await _storage.delete(key: _dataKeyCheckKey);
  }

  List<int>? _safeBase64Decode(String input) {
    try {
      return base64Decode(input);
    } catch (_) {
      return null;
    }
  }

  List<int> _generateRandomBytes(int length) {
    return List<int>.generate(length, (_) => _random.nextInt(256));
  }

  List<int> _xorBytes(List<int> a, List<int> b) {
    if (a.length != b.length) {
      throw ArgumentError('Byte arrays must have equal length for XOR.');
    }
    return List<int>.generate(a.length, (i) => a[i] ^ b[i]);
  }

  String _deriveDataKeyCheck(List<int> dataKey) {
    final digest = sha256.convert(<int>[
      ...utf8.encode('quit_habit_data_key_check_v1'),
      ...dataKey,
    ]).bytes;
    return base64Encode(digest);
  }

  Future<List<int>> _derivePbkdf2KeyAsync({
    required String secret,
    required List<int> salt,
    required int iterations,
    required int keyLength,
  }) async {
    return Isolate.run(
      () => _derivePbkdf2KeySync(
        secret: secret,
        salt: salt,
        iterations: iterations,
        keyLength: keyLength,
      ),
    );
  }

  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }
}

List<int> _derivePbkdf2KeySync({
  required String secret,
  required List<int> salt,
  required int iterations,
  required int keyLength,
}) {
  if (iterations <= 0) {
    throw ArgumentError('PBKDF2 iterations must be greater than 0.');
  }
  if (keyLength <= 0) {
    throw ArgumentError('PBKDF2 keyLength must be greater than 0.');
  }

  final passwordBytes = utf8.encode(secret);
  final hmac = Hmac(sha256, passwordBytes);
  const hLen = 32; // SHA-256 output length in bytes.
  final blockCount = (keyLength / hLen).ceil();
  final output = <int>[];

  for (var blockIndex = 1; blockIndex <= blockCount; blockIndex++) {
    final blockIndexBytes = <int>[
      (blockIndex >> 24) & 0xff,
      (blockIndex >> 16) & 0xff,
      (blockIndex >> 8) & 0xff,
      blockIndex & 0xff,
    ];

    var u = hmac.convert([...salt, ...blockIndexBytes]).bytes;
    final t = List<int>.from(u);

    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < t.length; j++) {
        t[j] ^= u[j];
      }
    }

    output.addAll(t);
  }

  return output.sublist(0, keyLength);
}
