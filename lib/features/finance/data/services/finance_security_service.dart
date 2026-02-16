import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Result types
// ---------------------------------------------------------------------------

enum FinancePasscodeFailureOutcome {
  none,
  temporaryLockout,
  recoveryOnlyLockdown,
}

class FinancePasscodeFailureResult {
  final FinancePasscodeFailureOutcome outcome;
  final int failedAttempts;
  final Duration? lockoutDuration;
  final int attemptsUntilRecoveryOnly;

  const FinancePasscodeFailureResult({
    required this.outcome,
    required this.failedAttempts,
    required this.attemptsUntilRecoveryOnly,
    this.lockoutDuration,
  });
}

enum MemorableWordFailureOutcome { none, temporaryLockout, wipeRequired }

class MemorableWordFailureResult {
  final MemorableWordFailureOutcome outcome;
  final int failedAttempts;
  final Duration? lockoutDuration;
  final int attemptsUntilWipe;

  const MemorableWordFailureResult({
    required this.outcome,
    required this.failedAttempts,
    required this.attemptsUntilWipe,
    this.lockoutDuration,
  });
}

/// Represents a bank-style character challenge for the memorable word.
class CharacterChallenge {
  /// Zero-based positions to challenge (e.g. [3, 4, 7] means 4th, 5th, 8th).
  final List<int> positions;

  const CharacterChallenge({required this.positions});

  /// Human-readable ordinals (1-based) for UI display.
  List<int> get displayPositions =>
      positions.map((p) => p + 1).toList(growable: false);
}

// ---------------------------------------------------------------------------
// FinanceSecurityService
// ---------------------------------------------------------------------------

/// Bank-grade security service for the finance mini app.
///
/// - 6-digit passcode with salted SHA-256 hashing (90K rounds).
/// - 8-12 character memorable word with per-character position hashes.
/// - Progressive lockout with data wipe on excessive failures.
class FinanceSecurityService {
  // ---- Passcode keys (FlutterSecureStorage) ----
  static const _passcodeHashKey = 'finance_passcode_hash_v1';
  static const _passcodeSaltKey = 'finance_passcode_salt_v1';

  // ---- Memorable word keys (FlutterSecureStorage) ----
  static const _mwFullHashKey = 'finance_mw_full_hash_v1';
  static const _mwFullSaltKey = 'finance_mw_full_salt_v1';
  static const _mwLengthKey = 'finance_mw_length_v1';
  static const _mwCharHashPrefix = 'finance_mw_char_';
  static const _mwCharHashSuffix = '_hash_v1';
  static const _mwCharSaltPrefix = 'finance_mw_char_';
  static const _mwCharSaltSuffix = '_salt_v1';

  // ---- Enabled flag ----
  static const _enabledSecureKey = 'finance_security_enabled_v1';

  // ---- Passcode lockout (SharedPreferences) ----
  static const _failedPasscodeAttemptsKey = 'finance_failed_passcode_attempts';
  static const _passcodeLockoutUntilMsKey = 'finance_passcode_lockout_until_ms';
  static const _passcodeRecoveryOnlyKey = 'finance_passcode_recovery_only_mode';

  // ---- Memorable word lockout (SharedPreferences) ----
  static const _failedMwAttemptsKey = 'finance_failed_mw_attempts';
  static const _mwLockoutUntilMsKey = 'finance_mw_lockout_until_ms';

  // ---- Tunables ----
  static const int passcodeSoftAttemptLimit = 3;
  static const int passcodeRecoveryOnlyAttemptLimit = 7;
  static const List<Duration> _passcodeLockoutSchedule = [
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 15),
  ];

  static const int mwWipeAttemptLimit = 3;
  static const List<Duration> _mwLockoutSchedule = [
    Duration(minutes: 1),
    Duration(minutes: 5),
  ];

  static const int _passcodeHashRounds = 90000;
  static const int _charHashRounds = 90000;
  static const int _fullWordHashRounds = 120000;
  static const int minMemorableWordLength = 8;
  static const int maxMemorableWordLength = 12;
  static const int challengePositionCount = 3;

  final FlutterSecureStorage _secureStorage;
  final Random _random;

  FinanceSecurityService({FlutterSecureStorage? secureStorage, Random? random})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
      _random = random ?? Random.secure();

  // =========================================================================
  // Passcode management
  // =========================================================================

  Future<bool> hasPasscode() async {
    final results = await Future.wait([
      _secureStorage.read(key: _passcodeHashKey),
      _secureStorage.read(key: _passcodeSaltKey),
    ]);
    final hash = results[0];
    final salt = results[1];
    return hash != null && hash.isNotEmpty && salt != null && salt.isNotEmpty;
  }

  Future<void> setPasscode(String passcode) async {
    if (!_isValidPasscode(passcode)) {
      throw ArgumentError('Passcode must be exactly 6 digits.');
    }

    final saltBytes = _generateRandomBytes(16);
    final hash = await _deriveHashAsync(
      passcode,
      saltBytes,
      _passcodeHashRounds,
    );
    await _secureStorage.write(key: _passcodeHashKey, value: hash);
    await _secureStorage.write(
      key: _passcodeSaltKey,
      value: base64Encode(saltBytes),
    );

    await resetFailedPasscodeAttempts();
    await clearPasscodeRecoveryOnlyMode();
  }

  Future<bool> verifyPasscode(String input) async {
    if (!_isValidPasscode(input)) return false;

    final storedHash = await _secureStorage.read(key: _passcodeHashKey);
    final storedSalt = await _secureStorage.read(key: _passcodeSaltKey);
    if (storedHash == null || storedSalt == null) return false;

    List<int> saltBytes;
    try {
      saltBytes = base64Decode(storedSalt);
    } catch (_) {
      return false;
    }

    final computedHash = await _deriveHashAsync(
      input,
      saltBytes,
      _passcodeHashRounds,
    );
    return _constantTimeEquals(storedHash, computedHash);
  }

  Future<void> clearPasscode() async {
    await _secureStorage.delete(key: _passcodeHashKey);
    await _secureStorage.delete(key: _passcodeSaltKey);
    await resetFailedPasscodeAttempts();
    await clearPasscodeRecoveryOnlyMode();
  }

  // =========================================================================
  // Memorable word management
  // =========================================================================

  Future<bool> hasMemorableWord() async {
    final results = await Future.wait([
      _secureStorage.read(key: _mwFullHashKey),
      _secureStorage.read(key: _mwFullSaltKey),
      _secureStorage.read(key: _mwLengthKey),
    ]);
    final hash = results[0];
    final salt = results[1];
    final lengthStr = results[2];
    return hash != null &&
        hash.isNotEmpty &&
        salt != null &&
        salt.isNotEmpty &&
        lengthStr != null &&
        (int.tryParse(lengthStr) ?? 0) >= minMemorableWordLength;
  }

  Future<int> getMemorableWordLength() async {
    final lengthStr = await _secureStorage.read(key: _mwLengthKey);
    return int.tryParse(lengthStr ?? '') ?? 0;
  }

  /// Stores the memorable word as:
  /// 1. A full-word salted hash (120K rounds) for future full-verification.
  /// 2. Per-character position hashes (90K rounds each) for bank-style challenge.
  Future<void> setMemorableWord(String word) async {
    final normalized = _normalizeMemorableWord(word);
    if (!_isValidMemorableWord(normalized)) {
      throw ArgumentError(
        'Memorable word must be $minMemorableWordLength to '
        '$maxMemorableWordLength characters and include letters.',
      );
    }

    // Store word length (needed to generate random positions for challenges).
    await _secureStorage.write(
      key: _mwLengthKey,
      value: normalized.length.toString(),
    );

    // Full-word hash.
    final fullSalt = _generateRandomBytes(16);
    final fullHash = await _deriveHashAsync(
      normalized,
      fullSalt,
      _fullWordHashRounds,
    );
    await _secureStorage.write(key: _mwFullHashKey, value: fullHash);
    await _secureStorage.write(
      key: _mwFullSaltKey,
      value: base64Encode(fullSalt),
    );

    // Per-character hashes (position-specific context baked into salt prefix).
    for (var i = 0; i < normalized.length; i++) {
      final charSalt = _generateRandomBytes(16);
      final charInput = 'pos_${i}_${normalized[i]}';
      final charHash = await _deriveHashAsync(
        charInput,
        charSalt,
        _charHashRounds,
      );
      await _secureStorage.write(
        key: '$_mwCharHashPrefix$i$_mwCharHashSuffix',
        value: charHash,
      );
      await _secureStorage.write(
        key: '$_mwCharSaltPrefix$i$_mwCharSaltSuffix',
        value: base64Encode(charSalt),
      );
    }

    // Clean up any stale character hashes beyond the new word length.
    for (var i = normalized.length; i <= maxMemorableWordLength; i++) {
      await _secureStorage.delete(
        key: '$_mwCharHashPrefix$i$_mwCharHashSuffix',
      );
      await _secureStorage.delete(
        key: '$_mwCharSaltPrefix$i$_mwCharSaltSuffix',
      );
    }

    await resetFailedMemorableWordAttempts();
  }

  /// Generate a bank-style character challenge.
  ///
  /// Returns [challengePositionCount] random zero-based positions.
  Future<CharacterChallenge> generateCharacterChallenge() async {
    final length = await getMemorableWordLength();
    if (length < challengePositionCount) {
      throw StateError(
        'Memorable word is too short for a character challenge.',
      );
    }

    final allPositions = List<int>.generate(length, (i) => i);
    allPositions.shuffle(_random);
    final selected = allPositions.sublist(0, challengePositionCount)..sort();
    return CharacterChallenge(positions: selected);
  }

  /// Verify a bank-style character challenge.
  ///
  /// [positionToChar] maps zero-based positions to the single character the
  /// user entered.
  Future<bool> verifyCharacterChallenge(Map<int, String> positionToChar) async {
    for (final entry in positionToChar.entries) {
      final position = entry.key;
      final char = entry.value.toLowerCase();
      if (char.length != 1) return false;

      final storedHash = await _secureStorage.read(
        key: '$_mwCharHashPrefix$position$_mwCharHashSuffix',
      );
      final storedSalt = await _secureStorage.read(
        key: '$_mwCharSaltPrefix$position$_mwCharSaltSuffix',
      );
      if (storedHash == null || storedSalt == null) return false;

      List<int> saltBytes;
      try {
        saltBytes = base64Decode(storedSalt);
      } catch (_) {
        return false;
      }

      final charInput = 'pos_${position}_$char';
      final computedHash = await _deriveHashAsync(
        charInput,
        saltBytes,
        _charHashRounds,
      );
      if (!_constantTimeEquals(storedHash, computedHash)) return false;
    }
    return true;
  }

  Future<void> clearMemorableWord() async {
    await _secureStorage.delete(key: _mwFullHashKey);
    await _secureStorage.delete(key: _mwFullSaltKey);
    final length = await getMemorableWordLength();
    for (var i = 0; i <= max(length, maxMemorableWordLength); i++) {
      await _secureStorage.delete(
        key: '$_mwCharHashPrefix$i$_mwCharHashSuffix',
      );
      await _secureStorage.delete(
        key: '$_mwCharSaltPrefix$i$_mwCharSaltSuffix',
      );
    }
    await _secureStorage.delete(key: _mwLengthKey);
    await resetFailedMemorableWordAttempts();
  }

  // =========================================================================
  // Security state helpers
  // =========================================================================

  Future<bool> isSecurityFullyConfigured() async {
    final status = await Future.wait([hasPasscode(), hasMemorableWord()]);
    return status[0] && status[1];
  }

  // =========================================================================
  // Passcode lockout tracking
  // =========================================================================

  Future<bool> isPasscodeRecoveryOnlyModeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_passcodeRecoveryOnlyKey) ?? false;
  }

  Future<void> enablePasscodeRecoveryOnlyMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_passcodeRecoveryOnlyKey, true);
    await prefs.remove(_passcodeLockoutUntilMsKey);
  }

  Future<void> clearPasscodeRecoveryOnlyMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_passcodeRecoveryOnlyKey);
  }

  Future<Duration?> getPasscodeLockoutRemaining() async {
    final prefs = await SharedPreferences.getInstance();
    final lockedUntilMs = prefs.getInt(_passcodeLockoutUntilMsKey);
    if (lockedUntilMs == null) return null;

    final remainingMs = lockedUntilMs - DateTime.now().millisecondsSinceEpoch;
    if (remainingMs <= 0) {
      await prefs.remove(_passcodeLockoutUntilMsKey);
      return null;
    }
    return Duration(milliseconds: remainingMs);
  }

  Future<int> getRemainingPasscodeAttemptsBeforeLockout() async {
    final prefs = await SharedPreferences.getInstance();
    final failed = prefs.getInt(_failedPasscodeAttemptsKey) ?? 0;
    return (passcodeSoftAttemptLimit - failed).clamp(
      0,
      passcodeSoftAttemptLimit,
    );
  }

  Future<int> getRemainingPasscodeAttemptsBeforeRecoveryOnly() async {
    final prefs = await SharedPreferences.getInstance();
    final failed = prefs.getInt(_failedPasscodeAttemptsKey) ?? 0;
    return (passcodeRecoveryOnlyAttemptLimit - failed).clamp(
      0,
      passcodeRecoveryOnlyAttemptLimit,
    );
  }

  Future<FinancePasscodeFailureResult> registerFailedPasscodeAttempt() async {
    final prefs = await SharedPreferences.getInstance();

    final recoveryOnly = await isPasscodeRecoveryOnlyModeEnabled();
    if (recoveryOnly) {
      final failed = prefs.getInt(_failedPasscodeAttemptsKey) ?? 0;
      return FinancePasscodeFailureResult(
        outcome: FinancePasscodeFailureOutcome.recoveryOnlyLockdown,
        failedAttempts: failed,
        attemptsUntilRecoveryOnly: 0,
      );
    }

    final lockoutRemaining = await getPasscodeLockoutRemaining();
    if (lockoutRemaining != null) {
      final failed = prefs.getInt(_failedPasscodeAttemptsKey) ?? 0;
      return FinancePasscodeFailureResult(
        outcome: FinancePasscodeFailureOutcome.temporaryLockout,
        failedAttempts: failed,
        lockoutDuration: lockoutRemaining,
        attemptsUntilRecoveryOnly: max(
          0,
          passcodeRecoveryOnlyAttemptLimit - failed,
        ),
      );
    }

    final failed = (prefs.getInt(_failedPasscodeAttemptsKey) ?? 0) + 1;
    await prefs.setInt(_failedPasscodeAttemptsKey, failed);

    if (failed >= passcodeRecoveryOnlyAttemptLimit) {
      await enablePasscodeRecoveryOnlyMode();
      return const FinancePasscodeFailureResult(
        outcome: FinancePasscodeFailureOutcome.recoveryOnlyLockdown,
        failedAttempts: passcodeRecoveryOnlyAttemptLimit,
        attemptsUntilRecoveryOnly: 0,
      );
    }

    if (failed > passcodeSoftAttemptLimit) {
      final scheduleIndex = failed - passcodeSoftAttemptLimit - 1;
      final duration =
          _passcodeLockoutSchedule[min(
            scheduleIndex,
            _passcodeLockoutSchedule.length - 1,
          )];
      final lockoutUntil = DateTime.now().add(duration).millisecondsSinceEpoch;
      await prefs.setInt(_passcodeLockoutUntilMsKey, lockoutUntil);

      return FinancePasscodeFailureResult(
        outcome: FinancePasscodeFailureOutcome.temporaryLockout,
        failedAttempts: failed,
        lockoutDuration: duration,
        attemptsUntilRecoveryOnly: max(
          0,
          passcodeRecoveryOnlyAttemptLimit - failed,
        ),
      );
    }

    return FinancePasscodeFailureResult(
      outcome: FinancePasscodeFailureOutcome.none,
      failedAttempts: failed,
      attemptsUntilRecoveryOnly: max(
        0,
        passcodeRecoveryOnlyAttemptLimit - failed,
      ),
    );
  }

  Future<void> resetFailedPasscodeAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_failedPasscodeAttemptsKey);
    await prefs.remove(_passcodeLockoutUntilMsKey);
  }

  // =========================================================================
  // Memorable word lockout tracking
  // =========================================================================

  Future<Duration?> getMemorableWordLockoutRemaining() async {
    final prefs = await SharedPreferences.getInstance();
    final lockedUntilMs = prefs.getInt(_mwLockoutUntilMsKey);
    if (lockedUntilMs == null) return null;

    final remainingMs = lockedUntilMs - DateTime.now().millisecondsSinceEpoch;
    if (remainingMs <= 0) {
      await prefs.remove(_mwLockoutUntilMsKey);
      return null;
    }
    return Duration(milliseconds: remainingMs);
  }

  Future<int> getRemainingMemorableWordAttemptsBeforeWipe() async {
    final prefs = await SharedPreferences.getInstance();
    final failed = prefs.getInt(_failedMwAttemptsKey) ?? 0;
    return (mwWipeAttemptLimit - failed).clamp(0, mwWipeAttemptLimit);
  }

  Future<MemorableWordFailureResult>
  registerFailedMemorableWordAttempt() async {
    final prefs = await SharedPreferences.getInstance();

    final lockoutRemaining = await getMemorableWordLockoutRemaining();
    if (lockoutRemaining != null) {
      final failed = prefs.getInt(_failedMwAttemptsKey) ?? 0;
      return MemorableWordFailureResult(
        outcome: MemorableWordFailureOutcome.temporaryLockout,
        failedAttempts: failed,
        lockoutDuration: lockoutRemaining,
        attemptsUntilWipe: max(0, mwWipeAttemptLimit - failed),
      );
    }

    final failed = (prefs.getInt(_failedMwAttemptsKey) ?? 0) + 1;
    await prefs.setInt(_failedMwAttemptsKey, failed);

    if (failed >= mwWipeAttemptLimit) {
      await prefs.remove(_mwLockoutUntilMsKey);
      return const MemorableWordFailureResult(
        outcome: MemorableWordFailureOutcome.wipeRequired,
        failedAttempts: mwWipeAttemptLimit,
        attemptsUntilWipe: 0,
      );
    }

    // Apply lockout after the first failure.
    if (failed >= 1) {
      final scheduleIndex = failed - 1;
      final duration =
          _mwLockoutSchedule[min(scheduleIndex, _mwLockoutSchedule.length - 1)];
      final lockoutUntil = DateTime.now().add(duration).millisecondsSinceEpoch;
      await prefs.setInt(_mwLockoutUntilMsKey, lockoutUntil);

      return MemorableWordFailureResult(
        outcome: MemorableWordFailureOutcome.temporaryLockout,
        failedAttempts: failed,
        lockoutDuration: duration,
        attemptsUntilWipe: max(0, mwWipeAttemptLimit - failed),
      );
    }

    return MemorableWordFailureResult(
      outcome: MemorableWordFailureOutcome.none,
      failedAttempts: failed,
      attemptsUntilWipe: max(0, mwWipeAttemptLimit - failed),
    );
  }

  Future<void> resetFailedMemorableWordAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_failedMwAttemptsKey);
    await prefs.remove(_mwLockoutUntilMsKey);
  }

  // =========================================================================
  // Full security reset
  // =========================================================================

  /// Clears all security state: passcode, memorable word, lockout counters.
  Future<void> resetAllSecurityState() async {
    await clearPasscode();
    await clearMemorableWord();
    await resetFailedPasscodeAttempts();
    await resetFailedMemorableWordAttempts();
    await clearPasscodeRecoveryOnlyMode();
    await _secureStorage.delete(key: _enabledSecureKey);
  }

  // =========================================================================
  // Validation helpers
  // =========================================================================

  bool _isValidPasscode(String value) => RegExp(r'^\d{6}$').hasMatch(value);

  bool _isValidMemorableWord(String value) {
    if (value.length < minMemorableWordLength ||
        value.length > maxMemorableWordLength) {
      return false;
    }
    return RegExp(r'[a-zA-Z]').hasMatch(value);
  }

  String _normalizeMemorableWord(String input) {
    return input.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  // =========================================================================
  // Crypto helpers
  // =========================================================================

  List<int> _generateRandomBytes(int length) {
    return List<int>.generate(length, (_) => _random.nextInt(256));
  }

  Future<String> _deriveHashAsync(
    String input,
    List<int> saltBytes,
    int rounds,
  ) async {
    return Isolate.run(() => _deriveHashSync(input, saltBytes, rounds));
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

// ---------------------------------------------------------------------------
// Top-level isolate-safe hash function
// ---------------------------------------------------------------------------

String _deriveHashSync(String input, List<int> saltBytes, int rounds) {
  final inputBytes = utf8.encode(input);
  var block = sha256.convert([...saltBytes, ...inputBytes]).bytes;

  for (var i = 0; i < rounds; i++) {
    block = sha256.convert([...block, ...saltBytes, ...inputBytes]).bytes;
  }

  return base64Encode(block);
}
