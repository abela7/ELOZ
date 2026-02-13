import 'package:flutter/material.dart';

import '../../../data/services/quit_habit_report_security_service.dart';
import '../../services/quit_habit_report_access_guard.dart';
import '../../widgets/quit_habit_report_passcode_dialogs.dart';

class QuitHabitReportSecurityScreen extends StatefulWidget {
  const QuitHabitReportSecurityScreen({super.key});

  @override
  State<QuitHabitReportSecurityScreen> createState() =>
      _QuitHabitReportSecurityScreenState();
}

class _QuitHabitReportSecurityScreenState
    extends State<QuitHabitReportSecurityScreen> {
  final _service = QuitHabitReportSecurityService();
  final _guard = QuitHabitReportAccessGuard();

  bool _isLoading = true;
  bool _isMutating = false;
  bool _hasPasscode = false;
  bool _hasRecoveryWord = false;
  QuitHabitReportSecuritySettings _settings =
      QuitHabitReportSecuritySettings.defaults;

  // Modern Theme Colors
  static const _accentColor = Color(0xFFCDAF56);
  static const _bgLight = Color(0xFFF4F6F9);
  static const _bgDark = Color(0xFF13131F);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await _service.getSettings();
    final hasPasscode = await _service.hasPasscode();
    final hasRecoveryWord = await _service.hasRecoveryWord();

    if (!mounted) return;
    setState(() {
      _settings = settings;
      _hasPasscode = hasPasscode;
      _hasRecoveryWord = hasRecoveryWord;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? _bgDark : _bgLight,
      appBar: AppBar(
        title: const Text(
          'Security',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildProtectionCard(isDark),
                const SizedBox(height: 20),
                _buildPasscodeCard(isDark),
                const SizedBox(height: 20),
                _buildRecoveryWordCard(isDark),
                const SizedBox(height: 20),
                _buildTestCard(isDark),
              ],
            ),
    );
  }

  Widget _buildProtectionCard(bool isDark) {
    return _ModernCard(
      isDark: isDark,
      child: SwitchListTile(
        value: _settings.enabled,
        onChanged: _isMutating
            ? null
            : (value) => _updateEnabled(value, isDark),
        activeThumbColor: _accentColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        title: Text(
          'Lock Report Access',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: isDark ? Colors.white : const Color(0xFF2D3436),
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Require authentication to view quit habit analytics.',
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.black54,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasscodeCard(bool isDark) {
    return _ModernCard(
      isDark: isDark,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.pin_rounded, color: _accentColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Passcode',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF2D3436),
                        ),
                      ),
                      const SizedBox(height: 4),
                      _StatusBadge(
                        isConfigured: _hasPasscode,
                        label: _hasPasscode ? 'Configured' : 'Not Set',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '6-digit code required to unlock your report. Includes timed lockouts for security.',
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black54,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isMutating
                        ? null
                        : () => _setOrChangePasscode(isDark),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentColor,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _hasPasscode ? 'Change Passcode' : 'Set Passcode',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                if (_hasPasscode) ...[
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: _isMutating ? null : _removePasscode,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF5252),
                      side: const BorderSide(color: Color(0xFFFF5252)),
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Icon(Icons.delete_outline_rounded, size: 20),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecoveryWordCard(bool isDark) {
    return _ModernCard(
      isDark: isDark,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFAB40).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.key_rounded,
                    color: Color(0xFFFFAB40),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recovery Word',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF2D3436),
                        ),
                      ),
                      const SizedBox(height: 4),
                      _StatusBadge(
                        isConfigured: _hasRecoveryWord,
                        label: _hasRecoveryWord ? 'Configured' : 'Not Set',
                        activeColor: const Color(0xFFFFAB40),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? Colors.white10
                      : Colors.black.withValues(alpha: 0.05),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Used to reset your passcode if forgotten. Stored securely as a hash.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isMutating
                    ? null
                    : () => _setOrChangeRecoveryWord(isDark),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white : Colors.black87,
                  side: BorderSide(
                    color: isDark ? Colors.white24 : Colors.black12,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _hasRecoveryWord
                      ? 'Reset Recovery Word'
                      : 'Set Recovery Word',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestCard(bool isDark) {
    return _ModernCard(
      isDark: isDark,
      child: InkWell(
        onTap: _settings.enabled
            ? () async {
                final ok = await _guard.ensureAccess(
                  context,
                  onSecurityEmergencyReset: _load,
                );
                if (!mounted) return;
                _showSnack(
                  ok
                      ? 'Security check passed.'
                      : 'Security check failed or canceled.',
                  isError: !ok,
                );
              }
            : null,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFCDAF56).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  color: Color(0xFFCDAF56),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Test Security Flow',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: isDark ? Colors.white : const Color(0xFF2D3436),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Run the unlock simulation.',
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? Colors.white24 : Colors.black26,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateEnabled(bool value, bool isDark) async {
    if (_isMutating) return;
    if (_hasPasscode) {
      final verified = await _verifyCurrentCredentialForSecurityChanges(
        forcePrompt: true,
      );
      if (!verified) return;
    }

    setState(() => _isMutating = true);
    try {
      if (value && !_hasPasscode) {
        final created = await _createPasscodeIfNeeded(isDark);
        if (!created) return;
      }

      final next = QuitHabitReportSecuritySettings(
        enabled: value,
        method: QuitHabitReportLockMethod.passcodeOnly,
      );
      await _service.saveSettings(next);

      if (!mounted) return;
      setState(() => _settings = next);
    } finally {
      if (mounted) {
        setState(() => _isMutating = false);
      }
    }
  }

  Future<void> _setOrChangePasscode(bool isDark) async {
    if (_isMutating) return;
    if (_hasPasscode) {
      final verified = await _verifyCurrentCredentialForSecurityChanges(
        forcePrompt: true,
      );
      if (!verified) return;
    }
    if (!mounted) return;

    setState(() => _isMutating = true);
    try {
      if (!_hasRecoveryWord) {
        final created = await _createRecoveryWordIfNeeded(isDark);
        if (!created) return;
      }
      if (!mounted) return;

      final passcode =
          await QuitHabitReportPasscodeDialogs.showCreatePasscodeDialog(
            context,
            isDark: isDark,
          );
      if (passcode == null) return;

      await _service.setPasscode(passcode);
      if (!mounted) return;
      setState(() {
        _hasPasscode = true;
      });
      _guard.markSettingsSessionUnlocked();
      _showSnack('Passcode saved successfully.');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed to save passcode: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isMutating = false);
      }
    }
  }

  Future<void> _setOrChangeRecoveryWord(bool isDark) async {
    if (_isMutating) return;
    if (_hasPasscode) {
      final verified = await _verifyCurrentCredentialForSecurityChanges(
        forcePrompt: true,
      );
      if (!verified) return;
    }
    if (!mounted) return;

    setState(() => _isMutating = true);
    try {
      final recoveryWord =
          await QuitHabitReportPasscodeDialogs.showCreateRecoveryWordDialog(
            context,
            isDark: isDark,
          );
      if (recoveryWord == null) return;

      await _service.setRecoveryWord(recoveryWord);
      if (!mounted) return;
      setState(() {
        _hasRecoveryWord = true;
      });
      _guard.markSettingsSessionUnlocked();
      _showSnack('Recovery word saved.');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed to save recovery word: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isMutating = false);
      }
    }
  }

  Future<void> _removePasscode() async {
    if (_isMutating) return;
    if (!_hasPasscode) return;
    if (_settings.enabled) {
      _showSnack('Disable lock first before removing passcode.', isError: true);
      return;
    }

    final verified = await _verifyCurrentCredentialForSecurityChanges(
      forcePrompt: true,
    );
    if (!verified) return;

    setState(() => _isMutating = true);
    try {
      await _service.clearPasscode(lockSecureSession: false);
      if (!mounted) return;
      setState(() {
        _hasPasscode = false;
      });
      _showSnack('Passcode removed.');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed to remove passcode: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isMutating = false);
      }
    }
  }

  Future<bool> _verifyCurrentCredentialForSecurityChanges({
    bool forcePrompt = true,
  }) async {
    final ok = await _guard.verifyCurrentCredentialForSettings(
      context,
      forcePrompt: forcePrompt,
      onSecurityEmergencyReset: _load,
    );
    if (!mounted) return false;
    if (!ok) {
      _showSnack(
        'Verification required to change security settings.',
        isError: true,
      );
      return false;
    }

    return true;
  }

  Future<bool> _createPasscodeIfNeeded(bool isDark) async {
    if (!await _createRecoveryWordIfNeeded(isDark)) return false;
    if (!mounted) return false;

    final passcode =
        await QuitHabitReportPasscodeDialogs.showCreatePasscodeDialog(
          context,
          isDark: isDark,
        );
    if (passcode == null) {
      _showSnack('Passcode setup canceled.');
      return false;
    }
    await _service.setPasscode(passcode);
    if (!mounted) return false;
    setState(() {
      _hasPasscode = true;
    });
    _guard.markSettingsSessionUnlocked();
    return true;
  }

  Future<bool> _createRecoveryWordIfNeeded(bool isDark) async {
    if (_hasRecoveryWord) return true;

    final recoveryWord =
        await QuitHabitReportPasscodeDialogs.showCreateRecoveryWordDialog(
          context,
          isDark: isDark,
        );
    if (recoveryWord == null) {
      _showSnack('Recovery word setup canceled.');
      return false;
    }
    await _service.setRecoveryWord(recoveryWord);
    if (!mounted) return false;
    setState(() {
      _hasRecoveryWord = true;
    });
    _guard.markSettingsSessionUnlocked();
    _showSnack('Recovery word saved.');
    return true;
  }

  void _showSnack(String message, {bool isError = false}) {
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
        backgroundColor: isError ? const Color(0xFFFF5252) : _accentColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

class _ModernCard extends StatelessWidget {
  final bool isDark;
  final Widget child;

  const _ModernCard({required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isConfigured;
  final String label;
  final Color? activeColor;

  const _StatusBadge({
    required this.isConfigured,
    required this.label,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = isConfigured
        ? (activeColor ?? const Color(0xFFCDAF56))
        : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
