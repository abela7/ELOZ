import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/dark_gradient.dart';
import '../providers/finance_providers.dart';
import '../widgets/finance_security_dialogs.dart';

/// Privacy & Security settings for the finance mini app.
class FinancePrivacySecurityScreen extends ConsumerStatefulWidget {
  const FinancePrivacySecurityScreen({super.key});

  @override
  ConsumerState<FinancePrivacySecurityScreen> createState() =>
      _FinancePrivacySecurityScreenState();
}

class _FinancePrivacySecurityScreenState
    extends ConsumerState<FinancePrivacySecurityScreen> {
  bool _isLoading = true;
  bool _hasPasscode = false;
  bool _hasMemorableWord = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final service = ref.read(financeSecurityServiceProvider);
    final hasPC = await service.hasPasscode();
    final hasMW = await service.hasMemorableWord();
    if (mounted) {
      setState(() {
        _hasPasscode = hasPC;
        _hasMemorableWord = hasMW;
        _isLoading = false;
      });
    }
  }

  Future<void> _changePasscode() async {
    final guard = ref.read(financeAccessGuardProvider);
    final ok = await guard.ensureSettingsAccess(context, forcePrompt: true);
    if (!ok || !mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final newPasscode = await FinanceSecurityDialogs.showCreatePasscodeDialog(
      context,
      isDark: isDark,
    );
    if (newPasscode == null || !mounted) return;

    final service = ref.read(financeSecurityServiceProvider);
    await service.setPasscode(newPasscode);
    if (!mounted) return;

    HapticFeedback.mediumImpact();
    _showSnackBar('Passcode changed successfully.');
    _loadStatus();
  }

  Future<void> _changeMemorableWord() async {
    final guard = ref.read(financeAccessGuardProvider);
    final ok = await guard.ensureSettingsAccess(context, forcePrompt: true);
    if (!ok || !mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final newWord = await FinanceSecurityDialogs.showCreateMemorableWordDialog(
      context,
      isDark: isDark,
    );
    if (newWord == null || !mounted) return;

    final service = ref.read(financeSecurityServiceProvider);
    await service.setMemorableWord(newWord);
    if (!mounted) return;

    HapticFeedback.mediumImpact();
    _showSnackBar('Memorable word changed successfully.');
    _loadStatus();
  }

  Future<void> _resetSecurity() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1D23) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.warning_rounded,
                color: Colors.red,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Reset Security?')),
          ],
        ),
        content: Text(
          'This will remove your passcode and memorable word. '
          'You will need to set them up again next time you open the finance app.\n\n'
          'Your financial data will NOT be deleted.',
          style: TextStyle(
            color: isDark ? const Color(0xFFBDBDBD) : const Color(0xFF6E6E6E),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.grey[700],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Require passcode verification before resetting.
    final guard = ref.read(financeAccessGuardProvider);
    final ok = await guard.ensureSettingsAccess(context, forcePrompt: true);
    if (!ok || !mounted) return;

    final service = ref.read(financeSecurityServiceProvider);
    await service.resetAllSecurityState();
    guard.clearSession();

    if (!mounted) return;
    HapticFeedback.mediumImpact();
    _showSnackBar('Security settings reset. Set up again on next visit.');
    _loadStatus();
  }

  void _showSnackBar(String message) {
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: isDark
          ? DarkGradient.wrap(child: _buildContent(context, isDark))
          : _buildContent(context, isDark),
    );
  }

  Widget _buildContent(BuildContext context, bool isDark) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Privacy & Security'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Status Section
                _buildSectionHeader(context, isDark, 'Security Status'),
                const SizedBox(height: 16),
                _buildStatusCard(isDark),

                const SizedBox(height: 32),

                // Manage Section
                _buildSectionHeader(context, isDark, 'Manage Security'),
                const SizedBox(height: 16),
                _buildSettingCard(
                  context,
                  isDark,
                  title: 'Change Passcode',
                  subtitle: _hasPasscode
                      ? 'Update your 6-digit passcode'
                      : 'Set up a 6-digit passcode',
                  icon: Icons.pin_rounded,
                  onTap: _changePasscode,
                ),
                const SizedBox(height: 12),
                _buildSettingCard(
                  context,
                  isDark,
                  title: 'Change Memorable Word',
                  subtitle: _hasMemorableWord
                      ? 'Update your security memorable word'
                      : 'Set up a memorable word',
                  icon: Icons.key_rounded,
                  onTap: _changeMemorableWord,
                ),

                const SizedBox(height: 32),

                // Info Section
                _buildSectionHeader(context, isDark, 'How It Works'),
                const SizedBox(height: 16),
                _buildInfoCard(isDark),

                const SizedBox(height: 32),

                // Danger Zone
                _buildSectionHeader(context, isDark, 'Danger Zone'),
                const SizedBox(height: 16),
                _buildSettingCard(
                  context,
                  isDark,
                  title: 'Reset Security',
                  subtitle: 'Remove passcode and memorable word',
                  icon: Icons.lock_reset_rounded,
                  iconColor: Colors.red,
                  onTap: _resetSecurity,
                ),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, bool isDark, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: const Color(0xFFCDAF56),
        fontSize: 14,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildStatusCard(bool isDark) {
    final allConfigured = _hasPasscode && _hasMemorableWord;
    final statusColor = allConfigured ? Colors.green : Colors.orange;
    final statusText = allConfigured ? 'Fully Protected' : 'Setup Incomplete';
    final statusIcon = allConfigured
        ? Icons.shield_rounded
        : Icons.shield_outlined;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D3139) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: statusColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      allConfigured
                          ? 'Your finance data is secured with passcode and memorable word.'
                          : 'Complete the setup to protect your finance data.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? const Color(0xFFBDBDBD)
                            : const Color(0xFF6E6E6E),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatusRow(
                  label: 'Passcode',
                  isSet: _hasPasscode,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatusRow(
                  label: 'Memorable Word',
                  isSet: _hasMemorableWord,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D3139) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFCDAF56).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(
            Icons.lock_rounded,
            'Passcode',
            'Required every time you open the finance app.',
            isDark,
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            Icons.key_rounded,
            'Memorable Word',
            'Used for recovery if you forget your passcode. We ask random characters (e.g. 4th, 7th, 11th) like a bank.',
            isDark,
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            Icons.timer_rounded,
            'Progressive Lockout',
            '3 wrong passcodes → temporary lock. 7 wrong → memorable word required.',
            isDark,
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            Icons.delete_forever_rounded,
            'Emergency Wipe',
            '3 wrong memorable word attempts → ALL finance data is permanently deleted.',
            isDark,
            isWarning: true,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String title,
    String description,
    bool isDark, {
    bool isWarning = false,
  }) {
    final color = isWarning ? Colors.red : const Color(0xFFCDAF56);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? const Color(0xFFBDBDBD)
                      : const Color(0xFF6E6E6E),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingCard(
    BuildContext context,
    bool isDark, {
    required String title,
    required String subtitle,
    required IconData icon,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D3139) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (iconColor ?? const Color(0xFFCDAF56)).withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (iconColor ?? const Color(0xFFCDAF56)).withOpacity(
                      0.15,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor ?? const Color(0xFFCDAF56),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E1E1E),
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? const Color(0xFFBDBDBD)
                              : const Color(0xFF6E6E6E),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status row widget
// ---------------------------------------------------------------------------

class _StatusRow extends StatelessWidget {
  final String label;
  final bool isSet;
  final bool isDark;

  const _StatusRow({
    required this.label,
    required this.isSet,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          isSet ? Icons.check_circle_rounded : Icons.cancel_rounded,
          color: isSet ? Colors.green : Colors.red.shade300,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
