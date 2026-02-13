import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/services/quit_habit_data_reset_service.dart';
import '../../data/services/quit_habit_secure_data_migration_service.dart';
import '../../data/services/quit_habit_secure_storage_service.dart';
import '../../data/services/quit_habit_report_security_service.dart';
import '../widgets/quit_habit_report_passcode_dialogs.dart';

class QuitHabitReportAccessGuard {
  static bool _settingsSessionUnlocked = false;
  static DateTime? _settingsSessionUnlockedAt;
  static const Duration _settingsSessionTimeout = Duration(minutes: 15);

  final QuitHabitReportSecurityService _securityService;
  final QuitHabitDataResetService _dataResetService;
  final QuitHabitSecureStorageService _quitSecureStorageService;
  final QuitHabitSecureDataMigrationService _secureDataMigrationService;

  QuitHabitReportAccessGuard({
    QuitHabitReportSecurityService? securityService,
    QuitHabitDataResetService? dataResetService,
    QuitHabitSecureStorageService? quitSecureStorageService,
    QuitHabitSecureDataMigrationService? secureDataMigrationService,
  }) : _securityService = securityService ?? QuitHabitReportSecurityService(),
       _dataResetService = dataResetService ?? QuitHabitDataResetService(),
       _quitSecureStorageService =
           quitSecureStorageService ?? QuitHabitSecureStorageService(),
       _secureDataMigrationService =
           secureDataMigrationService ?? QuitHabitSecureDataMigrationService();

  bool get isSettingsSessionUnlocked => _isSettingsSessionActive();

  void markSettingsSessionUnlocked() {
    _settingsSessionUnlocked = true;
    _settingsSessionUnlockedAt = DateTime.now();
  }

  void clearSettingsSession() {
    _settingsSessionUnlocked = false;
    _settingsSessionUnlockedAt = null;
    unawaited(_quitSecureStorageService.lockSession());
  }

  static void clearAllSessions() {
    _settingsSessionUnlocked = false;
    _settingsSessionUnlockedAt = null;
  }

  bool _isSettingsSessionActive() {
    if (!_settingsSessionUnlocked) return false;
    final unlockedAt = _settingsSessionUnlockedAt;
    if (unlockedAt == null) {
      clearSettingsSession();
      return false;
    }
    final elapsed = DateTime.now().difference(unlockedAt);
    if (elapsed >= _settingsSessionTimeout) {
      clearSettingsSession();
      return false;
    }
    return true;
  }

  void _touchSettingsSession() {
    if (_settingsSessionUnlocked) {
      _settingsSessionUnlockedAt = DateTime.now();
    }
  }

  Future<bool> ensureAccess(
    BuildContext context, {
    Future<void> Function()? onSecurityEmergencyReset,
  }) async {
    final settings = await _securityService.getSettings();
    if (!context.mounted) return false;
    if (!settings.enabled) return true;

    final hasPasscode = await _securityService.hasPasscode();
    if (!context.mounted) return false;
    if (!hasPasscode && !await _ensurePasscodeConfigured(context)) return false;
    if (!context.mounted) return false;

    return _authenticatePasscodeOnly(
      context,
      title: 'Unlock Quit Habit Report',
      subtitle: 'Enter your 6-digit passcode.',
      onSecurityEmergencyReset: onSecurityEmergencyReset,
    );
  }

  Future<bool> ensureQuitSettingsAccess(
    BuildContext context, {
    bool forcePrompt = false,
    Future<void> Function()? onSecurityEmergencyReset,
  }) async {
    final hasPasscode = await _securityService.hasPasscode();
    if (!context.mounted) return false;
    if (!hasPasscode) return true;
    if (!forcePrompt &&
        isSettingsSessionUnlocked &&
        _quitSecureStorageService.isSessionUnlocked) {
      _touchSettingsSession();
      return true;
    }

    final ok = await _authenticatePasscodeOnly(
      context,
      title: 'Unlock Quit Habit Settings',
      subtitle: 'Enter your 6-digit passcode to open quit settings.',
      onSecurityEmergencyReset: onSecurityEmergencyReset,
    );
    if (ok) {
      _settingsSessionUnlocked = true;
    }
    return ok;
  }

  Future<bool> ensureQuitHabitsAccess(
    BuildContext context, {
    bool forcePrompt = false,
    Future<void> Function()? onSecurityEmergencyReset,
  }) async {
    final settings = await _securityService.getSettings();
    if (!context.mounted) return false;
    if (!settings.enabled) return true;

    final hasPasscode = await _securityService.hasPasscode();
    if (!context.mounted) return false;
    if (!hasPasscode) return true;
    if (!forcePrompt &&
        isSettingsSessionUnlocked &&
        _quitSecureStorageService.isSessionUnlocked) {
      _touchSettingsSession();
      return true;
    }

    final ok = await _authenticatePasscodeOnly(
      context,
      title: 'Unlock Quit Habits',
      subtitle: 'Enter your 6-digit passcode to view quit habits.',
      onSecurityEmergencyReset: onSecurityEmergencyReset,
    );
    if (ok) {
      _settingsSessionUnlocked = true;
    }
    return ok;
  }

  Future<bool> verifyCurrentCredentialForSettings(
    BuildContext context, {
    bool forcePrompt = false,
    Future<void> Function()? onSecurityEmergencyReset,
  }) async {
    final hasPasscode = await _securityService.hasPasscode();
    if (!context.mounted) return false;
    if (!hasPasscode) return true;
    if (!forcePrompt &&
        isSettingsSessionUnlocked &&
        _quitSecureStorageService.isSessionUnlocked) {
      _touchSettingsSession();
      return true;
    }

    final ok = await _authenticatePasscodeOnly(
      context,
      title: 'Verify Current Passcode',
      subtitle: 'Enter current passcode to manage security settings.',
      onSecurityEmergencyReset: onSecurityEmergencyReset,
    );
    if (ok) {
      _settingsSessionUnlocked = true;
    }
    return ok;
  }

  Future<bool> _authenticatePasscodeOnly(
    BuildContext context, {
    required String title,
    required String subtitle,
    Future<void> Function()? onSecurityEmergencyReset,
  }) async {
    final hasPasscode = await _securityService.hasPasscode();
    if (!context.mounted) return false;
    if (!hasPasscode && !await _ensurePasscodeConfigured(context)) return false;
    if (!context.mounted) return false;
    return _promptPasscodeWithRetries(
      context,
      title: title,
      initialSubtitle: subtitle,
      onSecurityEmergencyReset: onSecurityEmergencyReset,
    );
  }

  Future<bool> _ensurePasscodeConfigured(BuildContext context) async {
    if (!await _ensureRecoveryWordConfigured(context)) return false;
    if (!context.mounted) return false;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final passcode =
        await QuitHabitReportPasscodeDialogs.showCreatePasscodeDialog(
          context,
          isDark: isDark,
        );
    if (!context.mounted) return false;
    if (passcode == null) {
      _showSnackBar(context, 'Passcode setup canceled.');
      return false;
    }
    await _securityService.setPasscode(passcode);
    if (!context.mounted) return false;
    _showSnackBar(context, 'Passcode configured successfully.');
    return true;
  }

  Future<bool> _ensureRecoveryWordConfigured(BuildContext context) async {
    final hasRecoveryWord = await _securityService.hasRecoveryWord();
    if (!context.mounted) return false;
    if (hasRecoveryWord) return true;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final recoveryWord =
        await QuitHabitReportPasscodeDialogs.showCreateRecoveryWordDialog(
          context,
          isDark: isDark,
        );
    if (!context.mounted) return false;
    if (recoveryWord == null) {
      _showSnackBar(context, 'Recovery word setup canceled.');
      return false;
    }

    await _securityService.setRecoveryWord(recoveryWord);
    if (!context.mounted) return false;
    _showSnackBar(context, 'Recovery word saved. Write it somewhere safe.');
    return true;
  }

  Future<bool> _promptPasscodeWithRetries(
    BuildContext context, {
    required String title,
    required String initialSubtitle,
    Future<void> Function()? onSecurityEmergencyReset,
  }) async {
    const maxDialogAttempts = 3;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    var localAttempts = 0;

    final recoveryOnlyMode = await _securityService
        .isPasscodeRecoveryOnlyModeEnabled();
    if (!context.mounted) return false;
    if (recoveryOnlyMode) {
      _showSnackBar(context, 'Passcode is locked. Recovery word is required.');
      return _handleForgotPasscodeFlow(
        context,
        subtitle: 'Passcode is permanently locked. Enter recovery word.',
        onSecurityEmergencyReset: onSecurityEmergencyReset,
      );
    }

    while (localAttempts < maxDialogAttempts) {
      final lockoutRemaining = await _securityService
          .getPasscodeLockoutRemaining();
      if (!context.mounted) return false;
      if (lockoutRemaining != null) {
        _showSnackBar(
          context,
          'Too many failed passcode attempts. Wait ${_formatDuration(lockoutRemaining)}.',
        );
        return false;
      }

      final attemptsBeforeWait = await _securityService
          .getRemainingPasscodeAttemptsBeforeLockout();
      final attemptsBeforeRecoveryOnly = await _securityService
          .getRemainingPasscodeAttemptsBeforeRecoveryOnly();
      if (!context.mounted) return false;

      final subtitle = localAttempts == 0
          ? initialSubtitle
          : 'Incorrect passcode. Wait lock in $attemptsBeforeWait tries. '
                'Recovery-only lock in $attemptsBeforeRecoveryOnly tries.';

      final passcodeResult =
          await QuitHabitReportPasscodeDialogs.showEnterPasscodeDialog(
            context,
            title: title,
            subtitle: subtitle,
            isDark: isDark,
            showForgotPasscode: true,
          );
      if (!context.mounted) return false;

      if (passcodeResult == null) return false;
      if (passcodeResult.action == QuitHabitPasscodeDialogAction.forgot) {
        final recovered = await _handleForgotPasscodeFlow(
          context,
          subtitle:
              'Enter your recovery word to reset passcode and unlock report.',
          onSecurityEmergencyReset: onSecurityEmergencyReset,
        );
        if (!context.mounted) return false;
        if (recovered) return true;
        localAttempts++;
        continue;
      }

      final passcode = passcodeResult.passcode;
      if (passcode == null) return false;
      final hasIntegrityCheck = await _quitSecureStorageService
          .hasDataKeyIntegrityCheck();
      if (!context.mounted) return false;

      var valid = false;
      var secureUnlocked = false;
      if (hasIntegrityCheck) {
        // Fast path: one KDF only (unlock validates passcode via integrity check).
        secureUnlocked = await _quitSecureStorageService.unlockWithPasscode(
          passcode,
        );
        valid = secureUnlocked;
      } else {
        // Legacy fallback: verify + unlock, then bootstrap integrity metadata.
        valid = await _securityService.verifyPasscode(passcode);
        if (!context.mounted) return false;
        if (valid) {
          secureUnlocked = await _quitSecureStorageService.unlockWithPasscode(
            passcode,
          );
          if (secureUnlocked) {
            await _quitSecureStorageService
                .bootstrapDataKeyIntegrityCheckFromUnlockedSession();
          }
        }
      }
      if (!context.mounted) return false;
      if (valid && secureUnlocked) {
        // Do not block unlock UX on legacy migration; run it in background.
        unawaited(() async {
          try {
            await _secureDataMigrationService.migrateLegacyDataIfNeeded();
          } catch (_) {
            if (!context.mounted) return;
            _showSnackBar(
              context,
              'Unlocked, but legacy quit data migration failed for some records.',
            );
          }
        }());
        await _securityService.resetFailedPasscodeAttempts();
        await _securityService.clearPasscodeRecoveryOnlyMode();
        markSettingsSessionUnlocked();
        return true;
      }
      if (valid && !secureUnlocked) {
        _showSnackBar(context, 'Unable to unlock secure quit data. Try again.');
        return false;
      }

      final failure = await _securityService.registerFailedPasscodeAttempt();
      if (!context.mounted) return false;

      switch (failure.outcome) {
        case PasscodeFailureOutcome.none:
          localAttempts++;
          break;
        case PasscodeFailureOutcome.temporaryLockout:
          _showSnackBar(
            context,
            'Passcode locked for ${_formatDuration(failure.lockoutDuration ?? const Duration(seconds: 30))}.',
          );
          return false;
        case PasscodeFailureOutcome.recoveryOnlyLockdown:
          _showSnackBar(
            context,
            'Passcode permanently locked. Use recovery word only.',
          );
          return _handleForgotPasscodeFlow(
            context,
            subtitle: 'Passcode is permanently locked. Enter recovery word.',
            onSecurityEmergencyReset: onSecurityEmergencyReset,
          );
      }
    }

    if (!context.mounted) return false;
    _showSnackBar(context, 'Authentication failed.');
    return false;
  }

  Future<bool> _handleForgotPasscodeFlow(
    BuildContext context, {
    required String subtitle,
    Future<void> Function()? onSecurityEmergencyReset,
  }) async {
    final hasRecoveryWord = await _securityService.hasRecoveryWord();
    if (!context.mounted) return false;
    if (!hasRecoveryWord) {
      _showSnackBar(
        context,
        'No recovery word is configured. Set one in security settings.',
      );
      return false;
    }

    final recoveryLockout = await _securityService
        .getRecoveryLockoutRemaining();
    if (!context.mounted) return false;
    if (recoveryLockout != null) {
      _showSnackBar(
        context,
        'Recovery is locked. Try again in ${_formatDuration(recoveryLockout)}.',
      );
      return false;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final recoveryWord =
        await QuitHabitReportPasscodeDialogs.showEnterRecoveryWordDialog(
          context,
          title: 'Recovery Verification',
          subtitle: subtitle,
          isDark: isDark,
        );
    if (!context.mounted) return false;
    if (recoveryWord == null) return false;

    final verified = await _securityService.verifyRecoveryWord(recoveryWord);
    if (!context.mounted) return false;
    if (!verified) {
      final failure = await _securityService.registerFailedRecoveryAttempt();
      if (!context.mounted) return false;

      switch (failure.outcome) {
        case RecoveryFailureOutcome.none:
          _showSnackBar(
            context,
            'Incorrect recovery word. Data reset in ${failure.attemptsUntilWipe} more failures.',
          );
          return false;
        case RecoveryFailureOutcome.temporaryLockout:
          _showSnackBar(
            context,
            'Recovery locked for ${_formatDuration(failure.lockoutDuration ?? const Duration(minutes: 1))}.',
          );
          return false;
        case RecoveryFailureOutcome.wipeRequired:
          await _executeEmergencyQuitDataReset(
            context,
            onSecurityEmergencyReset: onSecurityEmergencyReset,
          );
          return false;
      }
    }

    await _securityService.resetFailedRecoveryAttempts();
    if (!context.mounted) return false;

    final newPasscode =
        await QuitHabitReportPasscodeDialogs.showCreatePasscodeDialog(
          context,
          isDark: isDark,
        );
    if (!context.mounted) return false;
    if (newPasscode == null) {
      _showSnackBar(context, 'Passcode reset canceled.');
      return false;
    }

    final hasWrappedSecureData = await _quitSecureStorageService
        .hasProvisionedWrappedDataKey();
    if (!context.mounted) return false;
    if (hasWrappedSecureData && !_quitSecureStorageService.isSessionUnlocked) {
      await _quitSecureStorageService.wipeAllSecureData();
      if (!context.mounted) return false;
      _showSnackBar(
        context,
        'Recovery reset completed. Protected quit history was reset for security.',
      );
    }

    await _securityService.setPasscode(newPasscode);
    final secureUnlocked = await _quitSecureStorageService.unlockWithPasscode(
      newPasscode,
    );
    if (!context.mounted) return false;
    if (!secureUnlocked) {
      _showSnackBar(
        context,
        'Passcode reset completed, but secure data unlock failed. Try again.',
      );
      return false;
    }
    try {
      await _secureDataMigrationService.migrateLegacyDataIfNeeded();
    } catch (_) {
      if (!context.mounted) return false;
      _showSnackBar(
        context,
        'Passcode reset worked, but legacy quit data migration failed for some records.',
      );
    }
    markSettingsSessionUnlocked();
    if (!context.mounted) return false;
    _showSnackBar(context, 'Passcode reset successful.');
    return true;
  }

  Future<void> _executeEmergencyQuitDataReset(
    BuildContext context, {
    Future<void> Function()? onSecurityEmergencyReset,
  }) async {
    try {
      final summary = await _dataResetService.wipeAllQuitHabitData();
      clearSettingsSession();
      if (!context.mounted) return;
      _showSnackBar(
        context,
        'Security reset activated. Quit data cleared '
        '(${summary.deletedQuitHabits} habits, '
        '${summary.deletedQuitCompletions} logs, '
        '${summary.deletedTemptationLogs} temptations).',
      );
      if (onSecurityEmergencyReset != null) {
        await onSecurityEmergencyReset();
      }
    } catch (_) {
      if (!context.mounted) return;
      _showSnackBar(
        context,
        'Critical recovery failure detected, but data reset failed. Restart app and try again.',
      );
    }
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
