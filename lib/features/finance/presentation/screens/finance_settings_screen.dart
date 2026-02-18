import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/dark_gradient.dart';
import '../../../notifications_hub/presentation/screens/notification_hub_screen.dart';
import 'transaction_categories_screen.dart';
import 'finance_privacy_security_screen.dart';
import 'finance_notification_settings_screen.dart';
import '../../finance_module.dart';
import '../providers/finance_providers.dart';
import '../providers/income_providers.dart';
import '../../data/services/finance_encrypted_backup_service.dart';
import '../../data/services/finance_settings_service.dart';
import '../../utils/currency_utils.dart';

/// Finance Settings Screen
class FinanceSettingsScreen extends ConsumerStatefulWidget {
  const FinanceSettingsScreen({super.key});

  @override
  ConsumerState<FinanceSettingsScreen> createState() =>
      _FinanceSettingsScreenState();
}

class _FinanceSettingsScreenState extends ConsumerState<FinanceSettingsScreen> {
  String _selectedCurrency = FinanceSettingsService.fallbackCurrency;
  bool _isLoading = true;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final service = ref.read(financeSettingsServiceProvider);
    final defaultCurrency = await service.getDefaultCurrency();
    setState(() {
      _selectedCurrency = defaultCurrency;
      _isLoading = false;
    });
  }

  /// Show dialog to confirm currency change and ask about bulk update
  Future<void> _showCurrencyChangeDialog(String newCurrency) async {
    if (newCurrency == _selectedCurrency) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final symbol = CurrencyUtils.getCurrencySymbol(newCurrency);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1D23) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFCDAF56).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(symbol, style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Change Currency',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Change default currency to $newCurrency ($symbol)?',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.amber.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Update all existing accounts, transactions, budgets, bills & debts (no conversion).',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: Text(
              'Cancel',
              style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'new_only'),
            child: const Text(
              'New Items Only',
              style: TextStyle(color: Color(0xFFCDAF56)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'update_all'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCDAF56),
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Update All',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (result == null || result == 'cancel') return;

    if (result == 'update_all') {
      await _bulkUpdateCurrency(newCurrency);
    } else {
      await _saveCurrencyOnly(newCurrency);
    }
  }

  /// Save currency preference only (for new items)
  Future<void> _saveCurrencyOnly(String currency) async {
    final service = ref.read(financeSettingsServiceProvider);
    await service.setDefaultCurrency(currency);
    setState(() {
      _selectedCurrency = currency;
    });

    _invalidateAllProviders();

    if (mounted) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Default currency changed to ${CurrencyUtils.getCurrencySymbol(currency)} $currency',
          ),
          backgroundColor: const Color(0xFFCDAF56),
        ),
      );
    }
  }

  /// Bulk update all existing items to use the new currency
  Future<void> _bulkUpdateCurrency(String currency) async {
    setState(() => _isUpdating = true);

    try {
      final service = ref.read(financeSettingsServiceProvider);
      final result = await service.bulkUpdateCurrency(currency);

      setState(() {
        _selectedCurrency = currency;
        _isUpdating = false;
      });

      _invalidateAllProviders();

      if (mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Updated ${result.totalUpdated} items to ${CurrencyUtils.getCurrencySymbol(currency)} $currency',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() => _isUpdating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating currency: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Invalidate all providers that depend on currency
  void _invalidateAllProviders() {
    ref.invalidate(defaultCurrencyProvider);
    ref.invalidate(monthlyStatisticsProvider);
    ref.invalidate(yearlyStatisticsProvider);
    ref.invalidate(transactionStatisticsProvider);
    ref.invalidate(totalBalanceProvider);
    ref.invalidate(dailyTotalBalanceProvider);
    ref.invalidate(totalDebtByCurrencyProvider);
    ref.invalidate(totalLentByCurrencyProvider);
    ref.invalidate(totalDebtByCurrencyForDateProvider);
    ref.invalidate(totalLentByCurrencyForDateProvider);
    ref.invalidate(debtStatisticsProvider);
    ref.invalidate(lentStatisticsProvider);
    ref.invalidate(netWorthByCurrencyProvider);
    ref.invalidate(billSummaryProvider);
    ref.invalidate(allAccountsProvider);
    ref.invalidate(activeAccountsProvider);
    ref.invalidate(defaultAccountProvider);
    ref.invalidate(allBillsProvider);
    ref.invalidate(activeBillsProvider);
    ref.invalidate(allDebtsProvider);
    ref.invalidate(activeDebtsProvider);
    ref.invalidate(allLentDebtsProvider);
    ref.invalidate(activeLentDebtsProvider);
    ref.invalidate(allBudgetsProvider);
    ref.invalidate(activeBudgetsProvider);
    ref.invalidate(allBudgetStatusesProvider);
    ref.invalidate(allTransactionsProvider);
    ref.invalidate(transactionsForDateProvider);
    ref.invalidate(allTransactionCategoriesProvider);
    ref.invalidate(incomeTransactionCategoriesProvider);
    ref.invalidate(expenseCategoriesProvider);
    ref.invalidate(allTransactionTemplatesProvider);
    ref.invalidate(allDebtCategoriesProvider);
    ref.invalidate(activeDebtCategoriesProvider);
    ref.invalidate(allBillCategoriesProvider);
    ref.invalidate(activeBillCategoriesProvider);
    ref.invalidate(upcomingBillsProvider);
    ref.invalidate(overdueBillsProvider);
    ref.invalidate(monthlyBillsCostProvider);
    ref.invalidate(billsGroupedByCategoryProvider);
    ref.invalidate(debtsGroupedByCategoryProvider);
    ref.invalidate(debtsNeedingAttentionProvider);
    ref.invalidate(lentGroupedByCategoryProvider);
    ref.invalidate(lentNeedingAttentionProvider);
  }

  /// Helper to format currency name with symbol for display
  String _formatCurrencyDisplay(String code) {
    final symbol = CurrencyUtils.getCurrencySymbol(code);
    final name = CurrencyUtils.getCurrencyName(code);
    return '$name ($symbol)';
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
        title: const Text('Finance Settings'),
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
                // Currency Section
                _buildSectionHeader(context, isDark, 'Currency Settings'),
                const SizedBox(height: 16),
                _buildSettingCard(
                  context,
                  isDark,
                  title: 'Default Currency',
                  subtitle: _formatCurrencyDisplay(_selectedCurrency),
                  icon: Icons.attach_money_rounded,
                  trailing: _isUpdating
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              const Color(0xFFCDAF56).withOpacity(0.6),
                            ),
                          ),
                        )
                      : const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: _isUpdating
                      ? null
                      : () => _showCurrencyPicker(context, isDark),
                  disabled: _isUpdating,
                ),

                const SizedBox(height: 32),

                // Categories Section
                _buildSectionHeader(context, isDark, 'Categories'),
                const SizedBox(height: 16),
                _buildSettingCard(
                  context,
                  isDark,
                  title: 'Transaction Categories',
                  subtitle: 'Manage income and expense categories',
                  icon: Icons.category_rounded,
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                  ),
                  onTap: () =>
                      _showPlaceholder(context, 'Transaction Categories'),
                ),

                const SizedBox(height: 32),

                // Notifications Section
                _buildSectionHeader(context, isDark, 'Notifications'),
                const SizedBox(height: 16),
                _buildSettingCard(
                  context,
                  isDark,
                  title: 'Finance Notification Settings',
                  subtitle: 'Control all Finance reminders and hub integration',
                  icon: Icons.notifications_active_rounded,
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            const FinanceNotificationSettingsScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildSettingCard(
                  context,
                  isDark,
                  title: 'Open Notification Hub',
                  subtitle:
                      'Manage cross-app channels, history, and diagnostics',
                  icon: Icons.hub_rounded,
                  iconColor: Colors.teal,
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const NotificationHubScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 32),

                // Data Management Section
                _buildSectionHeader(context, isDark, 'Data Management'),
                const SizedBox(height: 16),
                _buildSettingCard(
                  context,
                  isDark,
                  title: 'Recalculate Balances',
                  subtitle: 'Fix account balances from transaction history',
                  icon: Icons.calculate_rounded,
                  iconColor: Colors.blue,
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                  ),
                  onTap: () => _showRecalculateConfirmation(context, isDark),
                ),
                const SizedBox(height: 12),
                _buildSettingCard(
                  context,
                  isDark,
                  title: 'Export Data',
                  subtitle: 'Create and share encrypted backup',
                  icon: Icons.file_download_rounded,
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                  ),
                  onTap: () => _exportEncryptedBackup(context),
                ),
                const SizedBox(height: 12),
                _buildSettingCard(
                  context,
                  isDark,
                  title: 'Import Data',
                  subtitle: 'Import encrypted finance backup file',
                  icon: Icons.file_upload_rounded,
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                  ),
                  onTap: () => _importEncryptedBackupFromFile(context),
                ),
                const SizedBox(height: 12),
                _buildSettingCard(
                  context,
                  isDark,
                  title: 'Backup & Restore',
                  subtitle: 'Manage local encrypted backups',
                  icon: Icons.backup_rounded,
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                  ),
                  onTap: () => _showBackupRestoreSheet(context),
                ),

                const SizedBox(height: 32),

                // App Settings Section
                _buildSectionHeader(context, isDark, 'App Settings'),
                const SizedBox(height: 16),
                _buildSettingCard(
                  context,
                  isDark,
                  title: 'Privacy & Security',
                  subtitle: 'Manage app lock and privacy settings',
                  icon: Icons.lock_rounded,
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                  ),
                  onTap: () => _showPlaceholder(context, 'Privacy & Security'),
                ),
                const SizedBox(height: 12),
                _buildSettingCard(
                  context,
                  isDark,
                  title: 'Reset All Data',
                  subtitle: 'Clear all financial data',
                  icon: Icons.delete_forever_rounded,
                  iconColor: Colors.red,
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                  ),
                  onTap: () => _showResetConfirmation(context, isDark),
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

  Widget _buildSettingCard(
    BuildContext context,
    bool isDark, {
    required String title,
    required String subtitle,
    required IconData icon,
    Color? iconColor,
    Widget? trailing,
    required VoidCallback? onTap,
    bool disabled = false,
  }) {
    return Opacity(
      opacity: disabled ? 0.6 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D3139) : const Color(0xFFFFFFFF),
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
            onTap: disabled ? null : onTap,
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
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: isDark
                                    ? const Color(0xFFBDBDBD)
                                    : const Color(0xFF6E6E6E),
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[const SizedBox(width: 8), trailing],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showCurrencyPicker(BuildContext context, bool isDark) {
    // Use the supported currencies from service - no hardcoding!
    final currencies = FinanceSettingsService.supportedCurrencies;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D3139) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCDAF56).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.attach_money_rounded,
                      color: Color(0xFFCDAF56),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Currency',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1E1E1E),
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Choose your default currency',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
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
            ),
            const Divider(height: 1),
            // Currency list
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.55,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: currencies.length,
                itemBuilder: (context, index) {
                  final code = currencies[index];
                  final symbol = CurrencyUtils.getCurrencySymbol(code);
                  final name = CurrencyUtils.getCurrencyName(code);
                  final isSelected = _selectedCurrency == code;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 4,
                    ),
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFCDAF56).withOpacity(0.15)
                            : (isDark ? Colors.white10 : Colors.grey[100]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          symbol,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? const Color(0xFFCDAF56)
                                : (isDark ? Colors.white70 : Colors.grey[600]),
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      name,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                      ),
                    ),
                    subtitle: Text(
                      code,
                      style: TextStyle(
                        color: isDark
                            ? const Color(0xFFBDBDBD)
                            : const Color(0xFF6E6E6E),
                      ),
                    ),
                    trailing: isSelected
                        ? Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFCDAF56).withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Color(0xFFCDAF56),
                              size: 20,
                            ),
                          )
                        : null,
                    onTap: () {
                      Navigator.of(context).pop();
                      _showCurrencyChangeDialog(code);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPlaceholder(BuildContext context, String feature) {
    if (feature == 'Transaction Categories') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const TransactionCategoriesScreen(),
        ),
      );
      return;
    }
    if (feature == 'Privacy & Security') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const FinancePrivacySecurityScreen(),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature - Coming soon!'),
        backgroundColor: const Color(0xFFCDAF56),
      ),
    );
  }

  Future<void> _exportEncryptedBackup(BuildContext context) async {
    final passphrase = await _promptBackupPassphrase(
      context,
      title: 'Export Encrypted Backup',
      description:
          'Set a passphrase to encrypt your finance backup before sharing.',
      requireConfirmation: true,
    );
    if (passphrase == null) return;

    _showBlockingProgressDialog(
      context,
      message: 'Encrypting and preparing backup...',
    );

    try {
      final backupService = ref.read(financeEncryptedBackupServiceProvider);
      final result = await backupService.createShareableBackup(
        passphrase: passphrase,
      );

      if (mounted) {
        Navigator.of(context).pop();
      }

      await Share.shareXFiles(
        [XFile(result.file.path)],
        text:
            'Encrypted Life Manager finance backup.\nKeep your passphrase safe.',
      );

      if (mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Encrypted export ready (${result.summary.totalRecords} records).',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _importEncryptedBackupFromFile(BuildContext context) async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select encrypted finance backup',
        type: FileType.custom,
        allowedExtensions: const ['finbk', 'backup', 'json'],
      );

      if (picked == null || picked.files.isEmpty) return;
      final selected = picked.files.single;
      if (selected.path == null || selected.path!.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not read selected file path.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      await _restoreFromEncryptedFile(
        context,
        file: File(selected.path!),
        sourceLabel: selected.name,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showBackupRestoreSheet(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backupService = ref.read(financeEncryptedBackupServiceProvider);
    Future<List<FinanceLocalBackupEntry>> localBackupsFuture = backupService
        .listLocalBackups();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Future<void> reloadBackups() async {
              setSheetState(() {
                localBackupsFuture = backupService.listLocalBackups();
              });
            }

            return Container(
              height: MediaQuery.of(sheetContext).size.height * 0.75,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2D3139) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFCDAF56).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.backup_rounded,
                            color: Color(0xFFCDAF56),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Encrypted Backups',
                                style: Theme.of(sheetContext)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF1E1E1E),
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Create, restore, share, or delete local backups',
                                style: Theme.of(sheetContext)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
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
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await _createLocalEncryptedBackup(context);
                              await reloadBackups();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFCDAF56),
                              foregroundColor: Colors.black87,
                            ),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text(
                              'Create Backup',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: FutureBuilder<List<FinanceLocalBackupEntry>>(
                      future: localBackupsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFCDAF56),
                            ),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(
                                'Failed to load backups: ${snapshot.error}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isDark
                                      ? const Color(0xFFBDBDBD)
                                      : const Color(0xFF6E6E6E),
                                ),
                              ),
                            ),
                          );
                        }

                        final backups =
                            snapshot.data ?? const <FinanceLocalBackupEntry>[];
                        if (backups.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(
                                'No local backups yet.',
                                style: TextStyle(
                                  color: isDark
                                      ? const Color(0xFFBDBDBD)
                                      : const Color(0xFF6E6E6E),
                                ),
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          itemBuilder: (context, index) {
                            final entry = backups[index];
                            final timestamp = _formatDateTime(entry.modifiedAt);
                            final size = _formatBytes(entry.sizeBytes);

                            return Container(
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1F2228)
                                    : const Color(0xFFF7F7F7),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: ListTile(
                                title: Text(
                                  entry.file.path
                                      .split(Platform.pathSeparator)
                                      .last,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF1E1E1E),
                                  ),
                                ),
                                subtitle: Text(
                                  '$timestamp - $size',
                                  style: TextStyle(
                                    color: isDark
                                        ? const Color(0xFFBDBDBD)
                                        : const Color(0xFF6E6E6E),
                                  ),
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) async {
                                    if (value == 'restore') {
                                      await _restoreFromEncryptedFile(
                                        context,
                                        file: entry.file,
                                        sourceLabel: entry.file.path
                                            .split(Platform.pathSeparator)
                                            .last,
                                      );
                                    } else if (value == 'share') {
                                      await Share.shareXFiles(
                                        [XFile(entry.file.path)],
                                        text:
                                            'Encrypted Life Manager finance backup.',
                                      );
                                    } else if (value == 'delete') {
                                      final delete = await _confirmAction(
                                        context,
                                        title: 'Delete Backup?',
                                        message:
                                            'This removes the local backup file only.',
                                        confirmLabel: 'Delete',
                                        confirmColor: Colors.red,
                                      );
                                      if (delete) {
                                        await backupService.deleteLocalBackup(
                                          entry,
                                        );
                                        await reloadBackups();
                                      }
                                    }
                                  },
                                  itemBuilder: (context) => const [
                                    PopupMenuItem(
                                      value: 'restore',
                                      child: Text('Restore'),
                                    ),
                                    PopupMenuItem(
                                      value: 'share',
                                      child: Text('Share'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Delete'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemCount: backups.length,
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _createLocalEncryptedBackup(BuildContext context) async {
    final passphrase = await _promptBackupPassphrase(
      context,
      title: 'Create Local Backup',
      description: 'Use a passphrase to encrypt the local finance backup file.',
      requireConfirmation: true,
    );
    if (passphrase == null) return;

    _showBlockingProgressDialog(context, message: 'Creating local backup...');
    try {
      final backupService = ref.read(financeEncryptedBackupServiceProvider);
      final result = await backupService.createLocalBackup(
        passphrase: passphrase,
      );
      if (mounted) {
        Navigator.of(context).pop();
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Backup created: ${result.file.path.split(Platform.pathSeparator).last}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _restoreFromEncryptedFile(
    BuildContext context, {
    required File file,
    required String sourceLabel,
  }) async {
    final confirmed = await _confirmAction(
      context,
      title: 'Restore Finance Data?',
      message:
          'This will replace current finance data (transactions, balances, and related finance records) with data from:\n\n$sourceLabel',
      confirmLabel: 'Restore',
      confirmColor: Colors.red,
    );
    if (!confirmed) return;

    final passphrase = await _promptBackupPassphrase(
      context,
      title: 'Backup Passphrase',
      description: 'Enter the passphrase used to encrypt this backup file.',
      requireConfirmation: false,
    );
    if (passphrase == null) return;

    _showBlockingProgressDialog(
      context,
      message: 'Restoring encrypted backup...',
    );
    try {
      final backupService = ref.read(financeEncryptedBackupServiceProvider);
      final result = await backupService.restoreFromFile(
        file: file,
        passphrase: passphrase,
        replaceExisting: true,
      );

      _invalidateAllProviders();

      if (mounted) {
        Navigator.of(context).pop();
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Restore complete: ${result.summary.totalRecords} records imported.',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restore failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<String?> _promptBackupPassphrase(
    BuildContext context, {
    required String title,
    required String description,
    required bool requireConfirmation,
  }) async {
    final passController = TextEditingController();
    final confirmController = TextEditingController();
    bool obscurePass = true;
    bool obscureConfirm = true;
    String? errorText;

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF2D3139) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(title),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      description,
                      style: TextStyle(
                        color: isDark
                            ? const Color(0xFFBDBDBD)
                            : const Color(0xFF6E6E6E),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passController,
                      obscureText: obscurePass,
                      decoration: InputDecoration(
                        labelText: 'Passphrase (min 8 chars)',
                        errorText: errorText,
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePass
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              obscurePass = !obscurePass;
                            });
                          },
                        ),
                      ),
                    ),
                    if (requireConfirmation) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: confirmController,
                        obscureText: obscureConfirm,
                        decoration: InputDecoration(
                          labelText: 'Confirm passphrase',
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureConfirm
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                            ),
                            onPressed: () {
                              setDialogState(() {
                                obscureConfirm = !obscureConfirm;
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final passphrase = passController.text.trim();
                    final confirm = confirmController.text.trim();

                    if (passphrase.length < 8) {
                      setDialogState(() {
                        errorText = 'Passphrase must be at least 8 characters.';
                      });
                      return;
                    }

                    if (requireConfirmation && passphrase != confirm) {
                      setDialogState(() {
                        errorText = 'Passphrases do not match.';
                      });
                      return;
                    }

                    Navigator.of(context).pop(passphrase);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCDAF56),
                    foregroundColor: Colors.black87,
                  ),
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );

    passController.dispose();
    confirmController.dispose();
    return result;
  }

  Future<bool> _confirmAction(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF2D3139) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(title),
          content: Text(
            message,
            style: TextStyle(
              color: isDark ? const Color(0xFFBDBDBD) : const Color(0xFF6E6E6E),
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: confirmColor,
                foregroundColor: Colors.white,
              ),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  void _showBlockingProgressDialog(
    BuildContext context, {
    required String message,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(color: Color(0xFFCDAF56)),
              const SizedBox(width: 20),
              Expanded(child: Text(message)),
            ],
          ),
        );
      },
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDateTime(DateTime dateTime) {
    final year = dateTime.year.toString().padLeft(4, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }

  void _showRecalculateConfirmation(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF2D3139) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.calculate_rounded,
                color: Colors.blue,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Recalculate Balances?')),
          ],
        ),
        content: Text(
          'This will recalculate all account balances based on your transaction history. Use this if your balances seem incorrect.',
          style: TextStyle(
            color: isDark ? const Color(0xFFBDBDBD) : const Color(0xFF6E6E6E),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.grey[700],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _recalculateBalances(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Recalculate'),
          ),
        ],
      ),
    );
  }

  Future<void> _recalculateBalances(BuildContext context) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(color: Color(0xFFCDAF56)),
            SizedBox(width: 24),
            Text('Recalculating balances...'),
          ],
        ),
      ),
    );

    try {
      final balanceService = ref.read(transactionBalanceServiceProvider);
      await balanceService.recalculateAllBalances();

      // Clear cached daily balance snapshots after recalculation
      await ref.read(dailyBalanceServiceProvider).invalidateAll();
      ref.invalidate(dailyTotalBalanceProvider);

      // Invalidate providers to refresh UI
      ref.invalidate(activeAccountsProvider);
      ref.invalidate(totalBalanceProvider);
      ref.invalidate(allAccountsProvider);

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account balances recalculated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error recalculating: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showResetConfirmation(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF2D3139) : Colors.white,
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
            const Expanded(child: Text('Reset All Data?')),
          ],
        ),
        content: Text(
          'This will permanently delete ALL finance data:\n'
          '• All transactions\n'
          '• All accounts\n'
          '• All budgets, debts, bills\n'
          '• All savings goals and recurring incomes\n'
          '• All categories and templates\n\n'
          'Your currency, security, and notification settings will be kept.\n'
          'A fresh default account will be created.\n\n'
          'This action cannot be undone.',
          style: TextStyle(
            color: isDark ? const Color(0xFFBDBDBD) : const Color(0xFF6E6E6E),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.grey[700],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _performDataReset(context);
            },
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
  }

  /// Performs a full data wipe: deletes ALL finance data, keeps settings only.
  /// Creates fresh default categories and a default Cash account.
  Future<void> _performDataReset(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(color: Colors.red),
            SizedBox(width: 24),
            Text('Wiping all finance data...'),
          ],
        ),
      ),
    );

    try {
      final dataResetService = ref.read(financeDataResetServiceProvider);
      await dataResetService.wipeAllFinanceDataKeepSettings();
      await FinanceModule.forceReinitializeDefaultsAfterWipe();

      ref.invalidate(allTransactionsProvider);
      ref.invalidate(allTransactionCategoriesProvider);
      ref.invalidate(allTransactionTemplatesProvider);
      ref.invalidate(allAccountsProvider);
      ref.invalidate(activeAccountsProvider);
      ref.invalidate(totalBalanceProvider);
      ref.invalidate(allBudgetsProvider);
      ref.invalidate(activeBudgetsProvider);
      ref.invalidate(monthlyStatisticsProvider);
      ref.invalidate(yearlyStatisticsProvider);
      ref.invalidate(dailyTotalBalanceProvider);
      ref.invalidate(allBillsProvider);
      ref.invalidate(activeBillsProvider);
      ref.invalidate(billSummaryProvider);
      ref.invalidate(monthlyBillsCostProvider);
      ref.invalidate(allDebtsProvider);
      ref.invalidate(activeDebtsProvider);
      ref.invalidate(allLentDebtsProvider);
      ref.invalidate(activeLentDebtsProvider);
      ref.invalidate(totalDebtByCurrencyProvider);
      ref.invalidate(totalLentByCurrencyProvider);
      ref.invalidate(totalDebtByCurrencyForDateProvider);
      ref.invalidate(totalLentByCurrencyForDateProvider);
      ref.invalidate(debtStatisticsProvider);
      ref.invalidate(lentStatisticsProvider);
      ref.invalidate(recurringIncomesProvider);
      ref.invalidate(allSavingsGoalsProvider);
      ref.invalidate(activeSavingsGoalsProvider);
      ref.invalidate(archivedSavingsGoalsProvider);
      ref.invalidate(savingsGoalsSummaryProvider);

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'All finance data wiped. Fresh start with default account and categories.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error wiping data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
