import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/services/finance_data_reset_service.dart';
import '../../data/services/finance_security_service.dart';
import '../widgets/finance_security_dialogs.dart';

/// Orchestrates the full finance mini-app authentication flow:
///
/// 1. First-time setup: memorable word → passcode.
/// 2. Passcode verification with progressive lockout.
/// 3. "Forgot Passcode?" → bank-style character challenge.
/// 4. Emergency data wipe after exhausted challenge attempts.
class FinanceAccessGuard {
  // ---- Session management (static so it persists across instances) ----
  static bool _sessionUnlocked = false;
  static DateTime? _sessionUnlockedAt;
  static const Duration _sessionTimeout = Duration(minutes: 15);
  static const Duration _securityOperationTimeout = Duration(seconds: 10);

  final FinanceSecurityService _securityService;
  final FinanceDataResetService _dataResetService;

  FinanceAccessGuard({
    FinanceSecurityService? securityService,
    FinanceDataResetService? dataResetService,
  }) : _securityService = securityService ?? FinanceSecurityService(),
       _dataResetService = dataResetService ?? FinanceDataResetService();

  // =========================================================================
  // Session helpers
  // =========================================================================

  bool get isSessionUnlocked => _isSessionActive();

  void markSessionUnlocked() {
    _sessionUnlocked = true;
    _sessionUnlockedAt = DateTime.now();
  }

  void clearSession() {
    _sessionUnlocked = false;
    _sessionUnlockedAt = null;
  }

  static void clearAllSessions() {
    _sessionUnlocked = false;
    _sessionUnlockedAt = null;
  }

  bool _isSessionActive() {
    if (!_sessionUnlocked) return false;
    final at = _sessionUnlockedAt;
    if (at == null) {
      clearSession();
      return false;
    }
    if (DateTime.now().difference(at) >= _sessionTimeout) {
      clearSession();
      return false;
    }
    return true;
  }

  void _touchSession() {
    if (_sessionUnlocked) {
      _sessionUnlockedAt = DateTime.now();
    }
  }

  // =========================================================================
  // Main entry: ensure access to the finance mini app
  // =========================================================================

  /// Returns `true` if the user is authenticated (or completes setup).
  /// Returns `false` if access is denied.
  Future<bool> ensureAccess(
    BuildContext context, {
    Future<void> Function()? onSecurityEmergencyReset,
  }) async {
    // Fast path: already unlocked.
    if (isSessionUnlocked) {
      _touchSession();
      return true;
    }

    // Check if fully configured.
    final configured = await _withTimeout(
      _securityService.isSecurityFullyConfigured(),
      operation: 'checking security configuration',
    );
    if (!context.mounted) return false;

    if (!configured) {
      // First-time setup wizard.
      final setupOk = await _runFirstTimeSetup(context);
      if (!setupOk || !context.mounted) return false;
      markSessionUnlocked();
      return true;
    }

    // Existing user → passcode verification.
    final ok = await _authenticatePasscode(
      context,
      title: 'Unlock Finance',
      subtitle: 'Enter your 6-digit passcode.',
      onSecurityEmergencyReset: onSecurityEmergencyReset,
    );
    if (ok) markSessionUnlocked();
    return ok;
  }

  /// Verify current passcode before accessing security settings.
  Future<bool> ensureSettingsAccess(
    BuildContext context, {
    bool forcePrompt = false,
    Future<void> Function()? onSecurityEmergencyReset,
  }) async {
    final hasPasscode = await _withTimeout(
      _securityService.hasPasscode(),
      operation: 'checking passcode',
    );
    if (!context.mounted) return false;
    if (!hasPasscode) return true;

    if (!forcePrompt && isSessionUnlocked) {
      _touchSession();
      return true;
    }

    final ok = await _authenticatePasscode(
      context,
      title: 'Verify Passcode',
      subtitle: 'Enter your passcode to access security settings.',
      onSecurityEmergencyReset: onSecurityEmergencyReset,
    );
    if (ok) markSessionUnlocked();
    return ok;
  }

  // =========================================================================
  // First-time setup wizard
  // =========================================================================

  Future<bool> _runFirstTimeSetup(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Step 1: Memorable word.
    final memorableWord =
        await FinanceSecurityDialogs.showCreateMemorableWordDialog(
          context,
          isDark: isDark,
        );
    if (!context.mounted) return false;
    if (memorableWord == null) {
      _showSnackBar(context, 'Security setup canceled.');
      return false;
    }
    await _withTimeout(
      _securityService.setMemorableWord(memorableWord),
      operation: 'saving memorable word',
    );
    if (!context.mounted) return false;

    // Step 2: Passcode.
    final passcode = await FinanceSecurityDialogs.showCreatePasscodeDialog(
      context,
      isDark: isDark,
    );
    if (!context.mounted) return false;
    if (passcode == null) {
      _showSnackBar(context, 'Passcode setup canceled.');
      // Roll back the memorable word since setup is incomplete.
      await _withTimeout(
        _securityService.clearMemorableWord(),
        operation: 'rolling back memorable word',
      );
      return false;
    }
    await _withTimeout(
      _securityService.setPasscode(passcode),
      operation: 'saving passcode',
    );
    if (!context.mounted) return false;
    _showSnackBar(context, 'Finance security configured successfully.');
    return true;
  }

  // =========================================================================
  // Passcode authentication with retries
  // =========================================================================

  Future<bool> _authenticatePasscode(
    BuildContext context, {
    required String title,
    required String subtitle,
    Future<void> Function()? onSecurityEmergencyReset,
  }) async {
    const maxDialogAttempts = 3;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    var localAttempts = 0;

    // Check recovery-only mode first.
    final recoveryOnly = await _withTimeout(
      _securityService.isPasscodeRecoveryOnlyModeEnabled(),
      operation: 'checking recovery-only mode',
    );
    if (!context.mounted) return false;
    if (recoveryOnly) {
      _showSnackBar(
        context,
        'Passcode is locked. Memorable word verification required.',
      );
      return _handleForgotPasscodeFlow(
        context,
        onSecurityEmergencyReset: onSecurityEmergencyReset,
      );
    }

    while (localAttempts < maxDialogAttempts) {
      // Check lockout.
      final lockout = await _withTimeout(
        _securityService.getPasscodeLockoutRemaining(),
        operation: 'checking passcode lockout',
      );
      if (!context.mounted) return false;
      if (lockout != null) {
        _showSnackBar(
          context,
          'Too many failed attempts. Wait ${_formatDuration(lockout)}.',
        );
        return false;
      }

      final attemptsBeforeLock = await _withTimeout(
        _securityService.getRemainingPasscodeAttemptsBeforeLockout(),
        operation: 'checking lockout attempts',
      );
      final attemptsBeforeRecovery = await _withTimeout(
        _securityService.getRemainingPasscodeAttemptsBeforeRecoveryOnly(),
        operation: 'checking recovery-only attempts',
      );
      if (!context.mounted) return false;

      final currentSubtitle = localAttempts == 0
          ? subtitle
          : 'Incorrect passcode. Lock in $attemptsBeforeLock tries. '
                'Recovery-only in $attemptsBeforeRecovery tries.';

      final result = await FinanceSecurityDialogs.showEnterPasscodeDialog(
        context,
        title: title,
        subtitle: currentSubtitle,
        isDark: isDark,
        showForgotPasscode: true,
      );
      if (!context.mounted) return false;
      if (result == null) return false;

      // Handle "Forgot Passcode?"
      if (result.action == FinancePasscodeDialogAction.forgot) {
        final recovered = await _handleForgotPasscodeFlow(
          context,
          onSecurityEmergencyReset: onSecurityEmergencyReset,
        );
        if (!context.mounted) return false;
        if (recovered) return true;
        localAttempts++;
        continue;
      }

      // Verify passcode.
      final passcode = result.passcode;
      if (passcode == null) return false;

      final valid = await _withTimeout(
        _securityService.verifyPasscode(passcode),
        operation: 'verifying passcode',
      );
      if (!context.mounted) return false;
      if (valid) {
        await _withTimeout(
          _securityService.resetFailedPasscodeAttempts(),
          operation: 'resetting passcode failures',
        );
        await _withTimeout(
          _securityService.clearPasscodeRecoveryOnlyMode(),
          operation: 'clearing recovery-only mode',
        );
        return true;
      }

      // Register failure.
      final failure = await _withTimeout(
        _securityService.registerFailedPasscodeAttempt(),
        operation: 'recording failed passcode attempt',
      );
      if (!context.mounted) return false;

      switch (failure.outcome) {
        case FinancePasscodeFailureOutcome.none:
          localAttempts++;
          break;
        case FinancePasscodeFailureOutcome.temporaryLockout:
          _showSnackBar(
            context,
            'Passcode locked for ${_formatDuration(failure.lockoutDuration ?? const Duration(seconds: 30))}.',
          );
          return false;
        case FinancePasscodeFailureOutcome.recoveryOnlyLockdown:
          _showSnackBar(
            context,
            'Passcode permanently locked. Memorable word verification required.',
          );
          return _handleForgotPasscodeFlow(
            context,
            onSecurityEmergencyReset: onSecurityEmergencyReset,
          );
      }
    }

    if (!context.mounted) return false;
    _showSnackBar(context, 'Authentication failed.');
    return false;
  }

  // =========================================================================
  // Forgot passcode → bank-style character challenge
  // =========================================================================

  Future<bool> _handleForgotPasscodeFlow(
    BuildContext context, {
    Future<void> Function()? onSecurityEmergencyReset,
  }) async {
    final hasWord = await _withTimeout(
      _securityService.hasMemorableWord(),
      operation: 'checking memorable word',
    );
    if (!context.mounted) return false;
    if (!hasWord) {
      _showSnackBar(
        context,
        'No memorable word is configured. Cannot recover passcode.',
      );
      return false;
    }

    // Check memorable word lockout.
    final mwLockout = await _withTimeout(
      _securityService.getMemorableWordLockoutRemaining(),
      operation: 'checking memorable-word lockout',
    );
    if (!context.mounted) return false;
    if (mwLockout != null) {
      _showSnackBar(
        context,
        'Verification is locked. Try again in ${_formatDuration(mwLockout)}.',
      );
      return false;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final attemptsRemaining = await _withTimeout(
      _securityService.getRemainingMemorableWordAttemptsBeforeWipe(),
      operation: 'checking memorable-word attempts',
    );
    if (!context.mounted) return false;

    // Generate character challenge.
    final challenge = await _withTimeout(
      _securityService.generateCharacterChallenge(),
      operation: 'creating memorable-word challenge',
    );
    if (!context.mounted) return false;

    // Show the character challenge dialog.
    final charResult =
        await FinanceSecurityDialogs.showCharacterChallengeDialog(
          context,
          challenge: challenge,
          attemptsRemaining: attemptsRemaining,
          isDark: isDark,
        );
    if (!context.mounted) return false;
    if (charResult == null) return false;

    // Verify.
    final verified = await _withTimeout(
      _securityService.verifyCharacterChallenge(charResult),
      operation: 'verifying memorable-word challenge',
    );
    if (!context.mounted) return false;

    if (!verified) {
      final failure = await _withTimeout(
        _securityService.registerFailedMemorableWordAttempt(),
        operation: 'recording failed memorable-word attempt',
      );
      if (!context.mounted) return false;

      switch (failure.outcome) {
        case MemorableWordFailureOutcome.none:
          _showSnackBar(
            context,
            'Incorrect. ${failure.attemptsUntilWipe} attempts remaining before data wipe.',
          );
          return false;
        case MemorableWordFailureOutcome.temporaryLockout:
          _showSnackBar(
            context,
            'Verification locked for ${_formatDuration(failure.lockoutDuration ?? const Duration(minutes: 1))}. '
            '${failure.attemptsUntilWipe} attempts remaining before data wipe.',
          );
          return false;
        case MemorableWordFailureOutcome.wipeRequired:
          await _executeEmergencyDataReset(
            context,
            onSecurityEmergencyReset: onSecurityEmergencyReset,
          );
          return false;
      }
    }

    // Character challenge passed — reset counters and let user create new passcode.
    await _withTimeout(
      _securityService.resetFailedMemorableWordAttempts(),
      operation: 'resetting memorable-word failures',
    );
    await _withTimeout(
      _securityService.resetFailedPasscodeAttempts(),
      operation: 'resetting passcode failures',
    );
    await _withTimeout(
      _securityService.clearPasscodeRecoveryOnlyMode(),
      operation: 'clearing recovery-only mode',
    );
    if (!context.mounted) return false;

    final newPasscode = await FinanceSecurityDialogs.showCreatePasscodeDialog(
      context,
      isDark: isDark,
    );
    if (!context.mounted) return false;
    if (newPasscode == null) {
      _showSnackBar(context, 'Passcode reset canceled.');
      return false;
    }

    await _withTimeout(
      _securityService.setPasscode(newPasscode),
      operation: 'saving new passcode',
    );
    if (!context.mounted) return false;
    _showSnackBar(context, 'Passcode reset successful.');
    return true;
  }

  // =========================================================================
  // Emergency data wipe
  // =========================================================================

  Future<void> _executeEmergencyDataReset(
    BuildContext context, {
    Future<void> Function()? onSecurityEmergencyReset,
  }) async {
    try {
      final summary = await _dataResetService.wipeAllFinanceData();
      clearSession();
      if (!context.mounted) return;
      _showSnackBar(
        context,
        'Security reset activated. All finance data deleted '
        '(${summary.totalDeleted} items).',
      );
      if (onSecurityEmergencyReset != null) {
        await onSecurityEmergencyReset();
      }
    } catch (_) {
      if (!context.mounted) return;
      _showSnackBar(
        context,
        'Critical security failure. Restart app and try again.',
      );
    }
  }

  // =========================================================================
  // Helpers
  // =========================================================================

  Future<T> _withTimeout<T>(
    Future<T> future, {
    required String operation,
  }) async {
    return future.timeout(
      _securityOperationTimeout,
      onTimeout: () {
        throw TimeoutException(
          'Finance security timed out while $operation.',
          _securityOperationTimeout,
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    if (minutes > 0) return '${minutes}m ${seconds}s';
    return '${seconds}s';
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFFCDAF56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
