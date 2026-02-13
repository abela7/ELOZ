import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'quit_habit_secure_storage_service.dart';

enum QuitHabitReportLockMethod { passcodeOnly }

class QuitHabitReportSecuritySettings {
  final bool enabled;
  final QuitHabitReportLockMethod method;

  const QuitHabitReportSecuritySettings({
    required this.enabled,
    required this.method,
  });

  static const defaults = QuitHabitReportSecuritySettings(
    enabled: true,
    method: QuitHabitReportLockMethod.passcodeOnly,
  );

  bool get requiresPasscode => true;
}

enum PasscodeFailureOutcome { none, temporaryLockout, recoveryOnlyLockdown }

class PasscodeFailureResult {
  final PasscodeFailureOutcome outcome;
  final int failedAttempts;
  final Duration? lockoutDuration;
  final int attemptsUntilRecoveryOnly;

  const PasscodeFailureResult({
    required this.outcome,
    required this.failedAttempts,
    required this.attemptsUntilRecoveryOnly,
    this.lockoutDuration,
  });
}

enum RecoveryFailureOutcome { none, temporaryLockout, wipeRequired }

class RecoveryFailureResult {
  final RecoveryFailureOutcome outcome;
  final int failedAttempts;
  final Duration? lockoutDuration;
  final int attemptsUntilWipe;

  const RecoveryFailureResult({
    required this.outcome,
    required this.failedAttempts,
    required this.attemptsUntilWipe,
    this.lockoutDuration,
  });
}

class QuitHabitReportSecurityService {
  static const _enabledKey = 'quit_habit_report_lock_enabled';
  static const _enabledSecureKey = 'quit_habit_report_lock_enabled_secure_v1';
  static const _methodKey = 'quit_habit_report_lock_method';
  static const _legacyPasscodeKey = 'quit_habit_report_passcode_v1';
  static const _passcodeHashKey = 'quit_habit_report_passcode_hash_v2';
  static const _passcodeSaltKey = 'quit_habit_report_passcode_salt_v2';

  static const _failedPasscodeAttemptsKey =
      'quit_habit_report_failed_passcode_attempts';
  static const _lockoutUntilEpochMsKey =
      'quit_habit_report_passcode_lockout_until_ms';
  static const _passcodeRecoveryOnlyKey =
      'quit_habit_report_passcode_recovery_only_mode';

  static const int passcodeSoftAttemptLimit = 3;
  static const int passcodeRecoveryOnlyAttemptLimit = 7;
  static const List<Duration> _passcodeLockoutSchedule = [
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 15),
  ];

  static const _recoveryWordHashKey = 'quit_habit_report_recovery_word_hash_v1';
  static const _recoveryWordSaltKey = 'quit_habit_report_recovery_word_salt_v1';
  static const _failedRecoveryAttemptsKey =
      'quit_habit_report_failed_recovery_attempts';
  static const _recoveryLockoutUntilEpochMsKey =
      'quit_habit_report_recovery_lockout_until_ms';

  static const int recoverySoftAttemptLimit = 3;
  static const int recoveryWipeAttemptLimit = 6; // More than 5 failures.
  static const List<Duration> _recoveryLockoutSchedule = [
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 15),
  ];

  static const int _passcodeHashRounds = 90000;
  static const int _recoveryHashRounds = 75000;
  static const int minRecoveryWordLength = 8;
  static const int maxRecoveryWordLength = 64;

  final FlutterSecureStorage _secureStorage;
  final Random _random;
  final QuitHabitSecureStorageService _quitSecureStorage;

  QuitHabitReportSecurityService({
    FlutterSecureStorage? secureStorage,
    Random? random,
    QuitHabitSecureStorageService? quitSecureStorage,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _random = random ?? Random.secure(),
       _quitSecureStorage =
           quitSecureStorage ?? QuitHabitSecureStorageService();

  Future<QuitHabitReportSecuritySettings> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final prefsEnabled = prefs.getBool(_enabledKey);
    final secureEnabledRaw = await _secureStorage.read(key: _enabledSecureKey);
    final secureEnabled = _decodeSecureBool(secureEnabledRaw);

    bool enabled;
    if (secureEnabled != null) {
      enabled = secureEnabled;
      if (prefsEnabled != enabled) {
        await prefs.setBool(_enabledKey, enabled);
      }
    } else if (prefsEnabled != null) {
      enabled = prefsEnabled;
      await _secureStorage.write(
        key: _enabledSecureKey,
        value: _encodeSecureBool(enabled),
      );
    } else {
      enabled = true;
      await prefs.setBool(_enabledKey, enabled);
      await _secureStorage.write(
        key: _enabledSecureKey,
        value: _encodeSecureBool(enabled),
      );
    }

    return QuitHabitReportSecuritySettings(
      enabled: enabled,
      method: QuitHabitReportLockMethod.passcodeOnly,
    );
  }

  Future<void> saveSettings(QuitHabitReportSecuritySettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, settings.enabled);
    await _secureStorage.write(
      key: _enabledSecureKey,
      value: _encodeSecureBool(settings.enabled),
    );
    await prefs.setString(_methodKey, _methodToString(settings.method));
  }

  Future<bool> hasPasscode() async {
    final hash = await _secureStorage.read(key: _passcodeHashKey);
    final salt = await _secureStorage.read(key: _passcodeSaltKey);
    if (hash != null && hash.isNotEmpty && salt != null && salt.isNotEmpty) {
      return true;
    }

    final legacy = await _secureStorage.read(key: _legacyPasscodeKey);
    return legacy != null && _isValidPasscode(legacy);
  }

  Future<void> setPasscode(String passcode) async {
    if (!_isValidPasscode(passcode)) {
      throw ArgumentError('Passcode must be exactly 6 digits.');
    }

    final existingHash = await _secureStorage.read(key: _passcodeHashKey);
    final existingSalt = await _secureStorage.read(key: _passcodeSaltKey);
    final existingLegacy = await _secureStorage.read(key: _legacyPasscodeKey);
    final hadExistingPasscode =
        existingHash != null &&
            existingHash.isNotEmpty &&
            existingSalt != null &&
            existingSalt.isNotEmpty ||
        (existingLegacy != null && _isValidPasscode(existingLegacy));

    try {
      await _quitSecureStorage.onPasscodeSet(passcode);
    } on StateError {
      // No active passcode + locked key material means we cannot re-wrap the
      // old secure key. Reset secure quit data to allow fresh provisioning.
      if (!hadExistingPasscode) {
        await _quitSecureStorage.wipeAllSecureData();
        await _quitSecureStorage.onPasscodeSet(passcode);
      } else {
        rethrow;
      }
    }

    final saltBytes = _generateRandomBytes(16);
    final hash = await _derivePasscodeHashAsync(passcode, saltBytes);
    await _secureStorage.write(key: _passcodeHashKey, value: hash);
    await _secureStorage.write(
      key: _passcodeSaltKey,
      value: base64Encode(saltBytes),
    );
    await _secureStorage.delete(key: _legacyPasscodeKey);

    await resetFailedPasscodeAttempts();
    await clearPasscodeRecoveryOnlyMode();
  }

  Future<void> clearPasscode({bool lockSecureSession = true}) async {
    await _secureStorage.delete(key: _passcodeHashKey);
    await _secureStorage.delete(key: _passcodeSaltKey);
    await _secureStorage.delete(key: _legacyPasscodeKey);
    if (lockSecureSession) {
      await _quitSecureStorage.lockSession();
    }
    await resetFailedPasscodeAttempts();
    await clearPasscodeRecoveryOnlyMode();
  }

  Future<bool> verifyPasscode(String input) async {
    if (!_isValidPasscode(input)) return false;

    final storedHash = await _secureStorage.read(key: _passcodeHashKey);
    final storedSalt = await _secureStorage.read(key: _passcodeSaltKey);
    if (storedHash != null && storedSalt != null) {
      List<int> saltBytes;
      try {
        saltBytes = base64Decode(storedSalt);
      } catch (_) {
        return false;
      }

      final computedHash = await _derivePasscodeHashAsync(input, saltBytes);
      return _constantTimeEquals(storedHash, computedHash);
    }

    final legacy = await _secureStorage.read(key: _legacyPasscodeKey);
    if (legacy == null) return false;
    final matched = _constantTimeEquals(legacy, input);
    if (matched) {
      await setPasscode(input);
    }
    return matched;
  }

  Future<bool> isPasscodeRecoveryOnlyModeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_passcodeRecoveryOnlyKey) ?? false;
  }

  Future<void> enablePasscodeRecoveryOnlyMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_passcodeRecoveryOnlyKey, true);
    await prefs.remove(_lockoutUntilEpochMsKey);
  }

  Future<void> clearPasscodeRecoveryOnlyMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_passcodeRecoveryOnlyKey);
  }

  Future<Duration?> getPasscodeLockoutRemaining() async {
    final prefs = await SharedPreferences.getInstance();
    final lockedUntilEpochMs = prefs.getInt(_lockoutUntilEpochMsKey);
    if (lockedUntilEpochMs == null) return null;

    final now = DateTime.now().millisecondsSinceEpoch;
    final remainingMs = lockedUntilEpochMs - now;
    if (remainingMs <= 0) {
      await prefs.remove(_lockoutUntilEpochMsKey);
      return null;
    }

    return Duration(milliseconds: remainingMs);
  }

  Future<int> getRemainingPasscodeAttemptsBeforeLockout() async {
    final prefs = await SharedPreferences.getInstance();
    final failedAttempts = prefs.getInt(_failedPasscodeAttemptsKey) ?? 0;
    final remaining = passcodeSoftAttemptLimit - failedAttempts;
    return remaining.clamp(0, passcodeSoftAttemptLimit);
  }

  Future<int> getRemainingPasscodeAttemptsBeforeRecoveryOnly() async {
    final prefs = await SharedPreferences.getInstance();
    final failedAttempts = prefs.getInt(_failedPasscodeAttemptsKey) ?? 0;
    final remaining = passcodeRecoveryOnlyAttemptLimit - failedAttempts;
    return remaining.clamp(0, passcodeRecoveryOnlyAttemptLimit);
  }

  Future<PasscodeFailureResult> registerFailedPasscodeAttempt() async {
    final prefs = await SharedPreferences.getInstance();
    final recoveryOnly = await isPasscodeRecoveryOnlyModeEnabled();
    if (recoveryOnly) {
      final failedAttempts = prefs.getInt(_failedPasscodeAttemptsKey) ?? 0;
      return PasscodeFailureResult(
        outcome: PasscodeFailureOutcome.recoveryOnlyLockdown,
        failedAttempts: failedAttempts,
        attemptsUntilRecoveryOnly: 0,
      );
    }

    final lockoutRemaining = await getPasscodeLockoutRemaining();
    if (lockoutRemaining != null) {
      final failedAttempts = prefs.getInt(_failedPasscodeAttemptsKey) ?? 0;
      return PasscodeFailureResult(
        outcome: PasscodeFailureOutcome.temporaryLockout,
        failedAttempts: failedAttempts,
        lockoutDuration: lockoutRemaining,
        attemptsUntilRecoveryOnly: max(
          0,
          passcodeRecoveryOnlyAttemptLimit - failedAttempts,
        ),
      );
    }

    final failedAttempts = (prefs.getInt(_failedPasscodeAttemptsKey) ?? 0) + 1;
    await prefs.setInt(_failedPasscodeAttemptsKey, failedAttempts);

    if (failedAttempts >= passcodeRecoveryOnlyAttemptLimit) {
      await enablePasscodeRecoveryOnlyMode();
      return const PasscodeFailureResult(
        outcome: PasscodeFailureOutcome.recoveryOnlyLockdown,
        failedAttempts: passcodeRecoveryOnlyAttemptLimit,
        attemptsUntilRecoveryOnly: 0,
      );
    }

    if (failedAttempts > passcodeSoftAttemptLimit) {
      final scheduleIndex = failedAttempts - passcodeSoftAttemptLimit - 1;
      final duration =
          _passcodeLockoutSchedule[min(
            scheduleIndex,
            _passcodeLockoutSchedule.length - 1,
          )];
      final lockoutUntil = DateTime.now().add(duration).millisecondsSinceEpoch;
      await prefs.setInt(_lockoutUntilEpochMsKey, lockoutUntil);

      return PasscodeFailureResult(
        outcome: PasscodeFailureOutcome.temporaryLockout,
        failedAttempts: failedAttempts,
        lockoutDuration: duration,
        attemptsUntilRecoveryOnly: max(
          0,
          passcodeRecoveryOnlyAttemptLimit - failedAttempts,
        ),
      );
    }

    return PasscodeFailureResult(
      outcome: PasscodeFailureOutcome.none,
      failedAttempts: failedAttempts,
      attemptsUntilRecoveryOnly: max(
        0,
        passcodeRecoveryOnlyAttemptLimit - failedAttempts,
      ),
    );
  }

  Future<void> resetFailedPasscodeAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_failedPasscodeAttemptsKey);
    await prefs.remove(_lockoutUntilEpochMsKey);
  }

  Future<bool> hasRecoveryWord() async {
    final hash = await _secureStorage.read(key: _recoveryWordHashKey);
    final salt = await _secureStorage.read(key: _recoveryWordSaltKey);
    return hash != null && hash.isNotEmpty && salt != null && salt.isNotEmpty;
  }

  Future<void> setRecoveryWord(String recoveryWord) async {
    final normalized = _normalizeRecoveryWord(recoveryWord);
    if (!_isValidRecoveryWord(normalized)) {
      throw ArgumentError(
        'Recovery word must be $minRecoveryWordLength to '
        '$maxRecoveryWordLength characters.',
      );
    }

    final saltBytes = _generateRandomBytes(16);
    final hash = await _deriveRecoveryWordHashAsync(normalized, saltBytes);
    await _secureStorage.write(key: _recoveryWordHashKey, value: hash);
    await _secureStorage.write(
      key: _recoveryWordSaltKey,
      value: base64Encode(saltBytes),
    );
    await resetFailedRecoveryAttempts();
  }

  Future<void> clearRecoveryWord() async {
    await _secureStorage.delete(key: _recoveryWordHashKey);
    await _secureStorage.delete(key: _recoveryWordSaltKey);
    await resetFailedRecoveryAttempts();
  }

  Future<bool> verifyRecoveryWord(String input) async {
    final normalized = _normalizeRecoveryWord(input);
    if (!_isValidRecoveryWord(normalized)) return false;

    final storedHash = await _secureStorage.read(key: _recoveryWordHashKey);
    final storedSalt = await _secureStorage.read(key: _recoveryWordSaltKey);
    if (storedHash == null || storedSalt == null) return false;

    List<int> saltBytes;
    try {
      saltBytes = base64Decode(storedSalt);
    } catch (_) {
      return false;
    }

    final computedHash = await _deriveRecoveryWordHashAsync(
      normalized,
      saltBytes,
    );
    return _constantTimeEquals(storedHash, computedHash);
  }

  Future<Duration?> getRecoveryLockoutRemaining() async {
    final prefs = await SharedPreferences.getInstance();
    final lockedUntilEpochMs = prefs.getInt(_recoveryLockoutUntilEpochMsKey);
    if (lockedUntilEpochMs == null) return null;

    final now = DateTime.now().millisecondsSinceEpoch;
    final remainingMs = lockedUntilEpochMs - now;
    if (remainingMs <= 0) {
      await prefs.remove(_recoveryLockoutUntilEpochMsKey);
      return null;
    }

    return Duration(milliseconds: remainingMs);
  }

  Future<int> getRemainingRecoveryAttemptsBeforeLockout() async {
    final prefs = await SharedPreferences.getInstance();
    final failedAttempts = prefs.getInt(_failedRecoveryAttemptsKey) ?? 0;
    final remaining = recoverySoftAttemptLimit - failedAttempts;
    return remaining.clamp(0, recoverySoftAttemptLimit);
  }

  Future<int> getRemainingRecoveryAttemptsBeforeWipe() async {
    final prefs = await SharedPreferences.getInstance();
    final failedAttempts = prefs.getInt(_failedRecoveryAttemptsKey) ?? 0;
    final remaining = recoveryWipeAttemptLimit - failedAttempts;
    return remaining.clamp(0, recoveryWipeAttemptLimit);
  }

  Future<RecoveryFailureResult> registerFailedRecoveryAttempt() async {
    final prefs = await SharedPreferences.getInstance();
    final lockoutRemaining = await getRecoveryLockoutRemaining();
    if (lockoutRemaining != null) {
      final failedAttempts = prefs.getInt(_failedRecoveryAttemptsKey) ?? 0;
      return RecoveryFailureResult(
        outcome: RecoveryFailureOutcome.temporaryLockout,
        failedAttempts: failedAttempts,
        lockoutDuration: lockoutRemaining,
        attemptsUntilWipe: max(0, recoveryWipeAttemptLimit - failedAttempts),
      );
    }

    final failedAttempts = (prefs.getInt(_failedRecoveryAttemptsKey) ?? 0) + 1;
    await prefs.setInt(_failedRecoveryAttemptsKey, failedAttempts);

    if (failedAttempts >= recoveryWipeAttemptLimit) {
      await prefs.remove(_recoveryLockoutUntilEpochMsKey);
      return const RecoveryFailureResult(
        outcome: RecoveryFailureOutcome.wipeRequired,
        failedAttempts: recoveryWipeAttemptLimit,
        attemptsUntilWipe: 0,
      );
    }

    if (failedAttempts > recoverySoftAttemptLimit) {
      final scheduleIndex = failedAttempts - recoverySoftAttemptLimit - 1;
      final duration =
          _recoveryLockoutSchedule[min(
            scheduleIndex,
            _recoveryLockoutSchedule.length - 1,
          )];
      final lockoutUntil = DateTime.now().add(duration).millisecondsSinceEpoch;
      await prefs.setInt(_recoveryLockoutUntilEpochMsKey, lockoutUntil);

      return RecoveryFailureResult(
        outcome: RecoveryFailureOutcome.temporaryLockout,
        failedAttempts: failedAttempts,
        lockoutDuration: duration,
        attemptsUntilWipe: max(0, recoveryWipeAttemptLimit - failedAttempts),
      );
    }

    return RecoveryFailureResult(
      outcome: RecoveryFailureOutcome.none,
      failedAttempts: failedAttempts,
      attemptsUntilWipe: max(0, recoveryWipeAttemptLimit - failedAttempts),
    );
  }

  Future<void> resetFailedRecoveryAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_failedRecoveryAttemptsKey);
    await prefs.remove(_recoveryLockoutUntilEpochMsKey);
  }

  Future<void> resetAllSecurityState() async {
    await _quitSecureStorage.wipeAllSecureData();
    await clearPasscode();
    await clearRecoveryWord();
    await resetFailedPasscodeAttempts();
    await resetFailedRecoveryAttempts();
    await clearPasscodeRecoveryOnlyMode();
    await saveSettings(QuitHabitReportSecuritySettings.defaults);
  }

  bool _isValidPasscode(String value) {
    return RegExp(r'^\d{6}$').hasMatch(value);
  }

  bool _isValidRecoveryWord(String value) {
    if (value.length < minRecoveryWordLength ||
        value.length > maxRecoveryWordLength) {
      return false;
    }
    return RegExp(r'[a-zA-Z]').hasMatch(value);
  }

  String _normalizeRecoveryWord(String input) {
    return input.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  List<int> _generateRandomBytes(int length) {
    return List<int>.generate(length, (_) => _random.nextInt(256));
  }

  Future<String> _deriveRecoveryWordHashAsync(
    String normalizedWord,
    List<int> saltBytes,
  ) async {
    return Isolate.run(
      () => _deriveRecoveryWordHashSync(
        normalizedWord,
        saltBytes,
        _recoveryHashRounds,
      ),
    );
  }

  Future<String> _derivePasscodeHashAsync(
    String passcode,
    List<int> saltBytes,
  ) async {
    return Isolate.run(
      () => _derivePasscodeHashSync(passcode, saltBytes, _passcodeHashRounds),
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

  String _methodToString(QuitHabitReportLockMethod method) {
    switch (method) {
      case QuitHabitReportLockMethod.passcodeOnly:
        return 'passcode_only';
    }
  }

  String _encodeSecureBool(bool value) => value ? '1' : '0';

  bool? _decodeSecureBool(String? value) {
    if (value == '1') return true;
    if (value == '0') return false;
    return null;
  }
}

String _deriveRecoveryWordHashSync(
  String normalizedWord,
  List<int> saltBytes,
  int rounds,
) {
  final wordBytes = utf8.encode(normalizedWord);
  var block = sha256.convert([...saltBytes, ...wordBytes]).bytes;

  for (var i = 0; i < rounds; i++) {
    block = sha256.convert([...block, ...saltBytes, ...wordBytes]).bytes;
  }

  return base64Encode(block);
}

String _derivePasscodeHashSync(
  String passcode,
  List<int> saltBytes,
  int rounds,
) {
  final passcodeBytes = utf8.encode(passcode);
  var block = sha256.convert([...saltBytes, ...passcodeBytes]).bytes;

  for (var i = 0; i < rounds; i++) {
    block = sha256.convert([...block, ...saltBytes, ...passcodeBytes]).bytes;
  }

  return base64Encode(block);
}
