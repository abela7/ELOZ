import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/dark_gradient.dart';
import '../../../../core/widgets/icon_picker_widget.dart';
import '../../../../core/widgets/color_picker_widget.dart';
import '../../data/models/account.dart';
import '../../data/models/transaction.dart';
import '../providers/finance_providers.dart';
import '../../data/services/finance_settings_service.dart';
import '../../utils/currency_utils.dart';

/// Accounts Management Screen
class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
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
    final accountsAsync = ref.watch(allAccountsProvider);
    final totalBalanceAsync = ref.watch(totalBalanceProvider);
    final defaultCurrencyAsync = ref.watch(defaultCurrencyProvider);
    final defaultCurrency =
        defaultCurrencyAsync.value ?? FinanceSettingsService.fallbackCurrency;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('My Accounts'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => _showAccountsInfo(context, isDark),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(allAccountsProvider);
          ref.invalidate(totalBalanceProvider);
        },
        child: CustomScrollView(
          slivers: [
            // Total Balance Summary
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _buildTotalBalanceCard(
                  context,
                  isDark,
                  totalBalanceAsync,
                  defaultCurrency,
                ),
              ),
            ),

            // Accounts List
            accountsAsync.when(
              data: (accounts) => _buildAccountsList(context, isDark, accounts),
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stack) => SliverFillRemaining(
                child: Center(child: Text('Error loading accounts: $error')),
              ),
            ),

            const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAccountDialog(context, isDark),
        backgroundColor: const Color(0xFFCDAF56),
        icon: const Icon(Icons.add_rounded, color: Color(0xFF1E1E1E)),
        label: const Text(
          'Add Account',
          style: TextStyle(
            color: Color(0xFF1E1E1E),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildTotalBalanceCard(
    BuildContext context,
    bool isDark,
    AsyncValue<Map<String, double>> totalBalanceAsync,
    String defaultCurrency,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFCDAF56),
            const Color(0xFFE2C876),
            const Color(0xFFB0933E),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            right: -20,
            top: -20,
            child: CircleAvatar(
              radius: 60,
              backgroundColor: Colors.white.withOpacity(0.1),
            ),
          ),
          Positioned(
            left: -10,
            bottom: -30,
            child: CircleAvatar(
              radius: 40,
              backgroundColor: Colors.black.withOpacity(0.05),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TOTAL BALANCE',
                            style: TextStyle(
                              color: const Color(0xFF1E1E1E).withOpacity(0.5),
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          totalBalanceAsync.when(
                            data: (balances) {
                              if (balances.isEmpty) {
                                return Text(
                                  '${CurrencyUtils.getCurrencySymbol(defaultCurrency)}0.00',
                                  style: const TextStyle(
                                    color: Color(0xFF1E1E1E),
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1,
                                  ),
                                );
                              }
                              // Show primary balance (first currency or default currency if available)
                              final primaryCurrency =
                                  balances.containsKey(defaultCurrency)
                                  ? defaultCurrency
                                  : balances.keys.first;
                              final primaryBalance =
                                  balances[primaryCurrency] ?? 0.0;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${CurrencyUtils.getCurrencySymbol(primaryCurrency)}${primaryBalance.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: Color(0xFF1E1E1E),
                                      fontSize: 36,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -1,
                                    ),
                                  ),
                                  // Show other currencies if any
                                  if (balances.length > 1) ...[
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 4,
                                      children: balances.entries
                                          .where(
                                            (e) => e.key != primaryCurrency,
                                          )
                                          .map(
                                            (e) => Text(
                                              '${CurrencyUtils.getCurrencySymbol(e.key)}${e.value.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                color: const Color(
                                                  0xFF1E1E1E,
                                                ).withOpacity(0.7),
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ],
                                ],
                              );
                            },
                            loading: () => const SizedBox(
                              height: 44,
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF1E1E1E),
                                  ),
                                ),
                              ),
                            ),
                            error: (_, __) => const Text(
                              'Error',
                              style: TextStyle(color: Colors.red, fontSize: 36),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Color(0xFF1E1E1E),
                        size: 24,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    _buildBalanceInfo(
                      context,
                      'Active Accounts',
                      '${ref.watch(allAccountsProvider).asData?.value.where((a) => a.isActive).length ?? 0}',
                      Icons.check_circle_outline_rounded,
                    ),
                    const SizedBox(width: 24),
                    _buildBalanceInfo(
                      context,
                      'Default',
                      ref
                          .watch(allAccountsProvider)
                          .asData
                          ?.value
                          .firstWhere(
                            (a) => a.isDefault,
                            orElse: () =>
                                ref
                                    .watch(allAccountsProvider)
                                    .asData
                                    ?.value
                                    .first ??
                                Account(name: 'None'),
                          )
                          .name,
                      Icons.star_outline_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceInfo(
    BuildContext context,
    String label,
    String? value,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 12,
              color: const Color(0xFF1E1E1E).withOpacity(0.5),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: const Color(0xFF1E1E1E).withOpacity(0.5),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value ?? '-',
          style: const TextStyle(
            color: Color(0xFF1E1E1E),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildAccountsList(
    BuildContext context,
    bool isDark,
    List<Account> accounts,
  ) {
    if (accounts.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.account_balance_rounded,
                size: 80,
                color: isDark ? Colors.white24 : Colors.grey[300],
              ),
              const SizedBox(height: 16),
              Text(
                'No Accounts Yet',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: isDark ? Colors.white60 : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add your first wallet or bank account',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.white38 : Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Group accounts by type for better organization
    final groupedAccounts = <String, List<Account>>{};
    for (final account in accounts) {
      groupedAccounts.putIfAbsent(account.type, () => []).add(account);
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final type = groupedAccounts.keys.elementAt(index);
          final typeAccounts = groupedAccounts[type]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 24, bottom: 12, left: 4),
                child: Text(
                  _getAccountTypeDisplayName(type).toUpperCase(),
                  style: TextStyle(
                    color: const Color(0xFFCDAF56),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              ...typeAccounts.map(
                (account) => _buildAccountCard(context, isDark, account),
              ),
            ],
          );
        }, childCount: groupedAccounts.length),
      ),
    );
  }

  Widget _buildAccountCard(BuildContext context, bool isDark, Account account) {
    final bool isSpecialType = account.type == 'card' || account.type == 'bank';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D3139) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: account.color.withOpacity(isDark ? 0.15 : 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: account.color.withOpacity(isDark ? 0.05 : 0.1),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              _showAddFundDialog(context, isDark, account);
            },
            onLongPress: () {
              HapticFeedback.mediumImpact();
              _showAccountOptions(context, isDark, account);
            },
            child: Stack(
              children: [
                // Background visual for special types
                if (isSpecialType)
                  Positioned(
                    right: -10,
                    bottom: -10,
                    child: Icon(
                      account.type == 'card'
                          ? Icons.credit_card_rounded
                          : Icons.account_balance_rounded,
                      size: 80,
                      color: account.color.withOpacity(0.03),
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Icon Container
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              account.color.withOpacity(0.2),
                              account.color.withOpacity(0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: account.color.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          account.icon ?? Icons.account_balance_wallet_rounded,
                          color: account.color,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Name and Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              account.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1E1E1E),
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                if (account.isDefault) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFFCDAF56,
                                      ).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'DEFAULT',
                                      style: TextStyle(
                                        color: Color(0xFFCDAF56),
                                        fontSize: 8,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Icon(
                                  _getAccountTypeIcon(account.type),
                                  size: 12,
                                  color: isDark
                                      ? Colors.white30
                                      : Colors.black26,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    _getAccountTypeDisplayName(account.type),
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white38
                                          : Colors.black38,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Balance Section
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${CurrencyUtils.getCurrencySymbol(account.currency)}${account.balance.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              letterSpacing: -0.5,
                              color: account.balance >= 0
                                  ? (isDark
                                        ? Colors.white
                                        : const Color(0xFF1E1E1E))
                                  : Colors.redAccent,
                            ),
                          ),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              _showAccountOptions(context, isDark, account);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withOpacity(0.05)
                                    : Colors.black.withOpacity(0.03),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.more_horiz_rounded,
                                size: 18,
                                color: isDark ? Colors.white38 : Colors.black26,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getAccountTypeIcon(String type) {
    switch (type) {
      case 'cash':
        return Icons.payments_rounded;
      case 'bank':
        return Icons.account_balance_rounded;
      case 'card':
        return Icons.credit_card_rounded;
      case 'mobileMoney':
        return Icons.phone_android_rounded;
      case 'investment':
        return Icons.trending_up_rounded;
      case 'loan':
        return Icons.money_off_rounded;
      case 'other':
        return Icons.more_horiz_rounded;
      default:
        return Icons.wallet_rounded;
    }
  }

  String _getAccountTypeDisplayName(String type) {
    switch (type) {
      case 'cash':
        return 'Cash / Wallet';
      case 'bank':
        return 'Bank Account';
      case 'card':
        return 'Credit/Debit Card';
      case 'mobileMoney':
        return 'Mobile Money';
      case 'investment':
        return 'Investment';
      case 'loan':
        return 'Loan / Debt';
      case 'other':
        return 'Other';
      default:
        return 'Account';
    }
  }

  void _showAccountOptions(BuildContext context, bool isDark, Account account) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D3139) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: account.color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        account.icon ?? Icons.account_balance_wallet_rounded,
                        color: account.color,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            account.name,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1E1E1E),
                                ),
                          ),
                          Text(
                            '${CurrencyUtils.getCurrencySymbol(account.currency)}${account.balance.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white60 : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.add_card_rounded,
                    color: Colors.green,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Add Fund',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
                subtitle: const Text(
                  'Directly increase balance with tracking',
                  style: TextStyle(fontSize: 11),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showAddFundDialog(context, isDark, account);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.analytics_rounded,
                    color: Colors.blue,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Statistics',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
                subtitle: const Text(
                  'View detailed statement and tracking',
                  style: TextStyle(fontSize: 11),
                ),
                onTap: () {
                  Navigator.pop(context);
                  // Will implement statistics page later
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Account statistics coming soon!'),
                    ),
                  );
                },
              ),
              if (!account.isDefault)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCDAF56).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFCDAF56),
                      size: 20,
                    ),
                  ),
                  title: const Text('Set as Default'),
                  onTap: () async {
                    Navigator.pop(context);
                    await ref
                        .read(accountRepositoryProvider)
                        .setDefaultAccount(account.id);
                    ref.invalidate(allAccountsProvider);
                  },
                ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCDAF56).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    color: Color(0xFFCDAF56),
                    size: 20,
                  ),
                ),
                title: const Text('Edit Account'),
                onTap: () {
                  Navigator.pop(context);
                  _showEditAccountDialog(context, isDark, account);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.delete_rounded,
                    color: Colors.red,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Delete Account',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteAccount(context, isDark, account);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddFundDialog(BuildContext context, bool isDark, Account account) {
    showDialog(
      context: context,
      builder: (context) => _AddFundDialog(isDark: isDark, account: account),
    );
  }

  void _showAddAccountDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => _AddEditAccountDialog(isDark: isDark),
    );
  }

  void _showEditAccountDialog(
    BuildContext context,
    bool isDark,
    Account account,
  ) {
    showDialog(
      context: context,
      builder: (context) =>
          _AddEditAccountDialog(isDark: isDark, account: account),
    );
  }

  void _confirmDeleteAccount(
    BuildContext context,
    bool isDark,
    Account account,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF2D3139) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete Account?'),
        content: Text(
          'Are you sure you want to delete "${account.name}"? This will not delete transactions associated with this account, but it may cause issues with historical data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: isDark ? Colors.white70 : Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref
                  .read(accountRepositoryProvider)
                  .deleteAccount(account.id);
              ref.invalidate(allAccountsProvider);
              ref.invalidate(totalBalanceProvider);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAccountsInfo(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF2D3139) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('About Accounts'),
        content: const Text(
          '• Total Balance only includes active accounts that are "Included in Total".\n'
          '• Loan/Debt accounts will subtract from your total balance if their balance is negative.\n'
          '• The Default account will be pre-selected for all new transactions.\n'
          '• Long-press an account to see more options.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Got it',
              style: TextStyle(color: Color(0xFFCDAF56)),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddEditAccountDialog extends ConsumerStatefulWidget {
  final bool isDark;
  final Account? account;

  const _AddEditAccountDialog({required this.isDark, this.account});

  @override
  ConsumerState<_AddEditAccountDialog> createState() =>
      _AddEditAccountDialogState();
}

class _AddEditAccountDialogState extends ConsumerState<_AddEditAccountDialog> {
  late TextEditingController _nameController;
  late TextEditingController _balanceController;
  late TextEditingController _descriptionController;
  late String _selectedType;
  late String _selectedCurrency;
  late IconData _selectedIcon;
  late Color _selectedColor;
  late bool _includeInTotal;
  late bool _isDefault;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.account?.name ?? '');
    _balanceController = TextEditingController(
      text: widget.account?.balance.toString() ?? '0.0',
    );
    _descriptionController = TextEditingController(
      text: widget.account?.description ?? '',
    );
    _selectedType = widget.account?.type ?? 'cash';
    _selectedCurrency =
        widget.account?.currency ?? FinanceSettingsService.fallbackCurrency;
    _selectedIcon =
        widget.account?.icon ?? Icons.account_balance_wallet_rounded;
    _selectedColor = widget.account?.color ?? const Color(0xFFCDAF56);
    _includeInTotal = widget.account?.includeInTotal ?? true;
    _isDefault = widget.account?.isDefault ?? false;

    if (widget.account == null) {
      Future.microtask(() async {
        final service = ref.read(financeSettingsServiceProvider);
        final defaultCurrency = await service.getDefaultCurrency();
        if (mounted) {
          setState(() => _selectedCurrency = defaultCurrency);
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: widget.isDark ? const Color(0xFF1A1D23) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Custom Header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              decoration: BoxDecoration(
                color: widget.isDark
                    ? const Color(0xFF2D3139)
                    : Colors.grey[50],
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCDAF56).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      widget.account == null
                          ? Icons.add_rounded
                          : Icons.edit_rounded,
                      color: const Color(0xFFCDAF56),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.account == null
                              ? 'Add New Account'
                              : 'Edit Account',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: widget.isDark
                                ? Colors.white
                                : const Color(0xFF1E1E1E),
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'Keep your financial data organized',
                          style: TextStyle(
                            fontSize: 12,
                            color: widget.isDark
                                ? Colors.white38
                                : Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: widget.isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.05),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Visual Identity Section
                  _buildSectionLabel('ACCOUNT IDENTITY'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildIdentityOption(
                        context,
                        'Pick Icon',
                        _selectedIcon,
                        _selectedColor,
                        _showIconPicker,
                        isIcon: true,
                      ),
                      const SizedBox(width: 16),
                      _buildIdentityOption(
                        context,
                        'Pick Color',
                        null,
                        _selectedColor,
                        _showColorPicker,
                        isIcon: false,
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Form Fields Section
                  _buildSectionLabel('BASIC INFORMATION'),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _nameController,
                    label: 'Account Name',
                    hint: 'e.g., Main Savings',
                    icon: Icons.label_rounded,
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _balanceController,
                    label: 'Current Balance',
                    hint: '0.00',
                    icon: Icons.account_balance_wallet_rounded,
                    isNumeric: true,
                    prefix:
                        '${CurrencyUtils.getCurrencySymbol(_selectedCurrency)} ',
                  ),
                  const SizedBox(height: 20),
                  _buildDropdownField(
                    label: 'Currency',
                    value: _selectedCurrency,
                    icon: Icons.currency_exchange_rounded,
                    items: FinanceSettingsService.supportedCurrencies
                        .map(
                          (code) => DropdownMenuItem(
                            value: code,
                            child: Text(
                              '${CurrencyUtils.getCurrencySymbol(code)} $code',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) =>
                        setState(() => _selectedCurrency = val!),
                  ),
                  const SizedBox(height: 20),
                  _buildDropdownField(
                    label: 'Account Type',
                    value: _selectedType,
                    icon: Icons.category_rounded,
                    items:
                        [
                              'cash',
                              'bank',
                              'card',
                              'mobileMoney',
                              'investment',
                              'loan',
                              'other',
                            ]
                            .map(
                              (type) => DropdownMenuItem(
                                value: type,
                                child: Text(_getAccountTypeDisplayName(type)),
                              ),
                            )
                            .toList(),
                    onChanged: (val) => setState(() => _selectedType = val!),
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _descriptionController,
                    label: 'Notes / Description',
                    hint: 'Optional details...',
                    icon: Icons.notes_rounded,
                  ),
                  const SizedBox(height: 28),

                  // Settings Section
                  _buildSectionLabel('ACCOUNT SETTINGS'),
                  const SizedBox(height: 12),
                  _buildModernSwitch(
                    title: 'Include in Total',
                    subtitle: 'Affects overall balance summary',
                    value: _includeInTotal,
                    onChanged: (val) => setState(() => _includeInTotal = val),
                    icon: Icons.summarize_rounded,
                  ),
                  const SizedBox(height: 8),
                  _buildModernSwitch(
                    title: 'Set as Default',
                    subtitle: 'Pre-select for all new transactions',
                    value: _isDefault,
                    onChanged: (val) => setState(() => _isDefault = val),
                    icon: Icons.star_rounded,
                  ),
                  const SizedBox(height: 32),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(
                              color: widget.isDark
                                  ? Colors.white12
                                  : Colors.grey[300]!,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: widget.isDark
                                  ? Colors.white70
                                  : Colors.grey[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _saveAccount,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFCDAF56),
                            foregroundColor: const Color(0xFF1E1E1E),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 8,
                            shadowColor: const Color(
                              0xFFCDAF56,
                            ).withOpacity(0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            widget.account == null
                                ? 'CREATE ACCOUNT'
                                : 'SAVE CHANGES',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: const Color(0xFFCDAF56),
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildIdentityOption(
    BuildContext context,
    String label,
    IconData? icon,
    Color color,
    VoidCallback onTap, {
    required bool isIcon,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 64,
              decoration: BoxDecoration(
                color: widget.isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isIcon
                      ? color.withOpacity(0.3)
                      : color.withOpacity(0.6),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: isIcon
                    ? Icon(icon, color: color, size: 28)
                    : Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: widget.isDark ? Colors.white54 : Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isNumeric = false,
    String? prefix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: widget.isDark ? Colors.white70 : Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: isNumeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : null,
          style: TextStyle(
            color: widget.isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixText: prefix,
            prefixIcon: Icon(icon, size: 20, color: const Color(0xFFCDAF56)),
            filled: true,
            fillColor: widget.isDark
                ? Colors.white.withOpacity(0.03)
                : Colors.grey.withOpacity(0.03),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: widget.isDark ? Colors.white10 : Colors.grey[200]!,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: widget.isDark ? Colors.white10 : Colors.grey[200]!,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFFCDAF56),
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required IconData icon,
    required List<DropdownMenuItem<String>> items,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: widget.isDark ? Colors.white70 : Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          dropdownColor: widget.isDark ? const Color(0xFF2D3139) : Colors.white,
          style: TextStyle(
            color: widget.isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20, color: const Color(0xFFCDAF56)),
            filled: true,
            fillColor: widget.isDark
                ? Colors.white.withOpacity(0.03)
                : Colors.grey.withOpacity(0.03),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: widget.isDark ? Colors.white10 : Colors.grey[200]!,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: widget.isDark ? Colors.white10 : Colors.grey[200]!,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFFCDAF56),
                width: 1.5,
              ),
            ),
          ),
          items: items,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildModernSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.white.withOpacity(0.02)
            : Colors.grey.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 11,
            color: widget.isDark ? Colors.white38 : Colors.grey[600],
          ),
        ),
        secondary: Icon(icon, color: const Color(0xFFCDAF56), size: 20),
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFFCDAF56),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  String _getAccountTypeDisplayName(String type) {
    switch (type) {
      case 'cash':
        return 'Cash / Wallet';
      case 'bank':
        return 'Bank Account';
      case 'card':
        return 'Credit/Debit Card';
      case 'mobileMoney':
        return 'Mobile Money';
      case 'investment':
        return 'Investment';
      case 'loan':
        return 'Loan / Debt';
      case 'other':
        return 'Other';
      default:
        return 'Account';
    }
  }

  Future<void> _showIconPicker() async {
    final icon = await showDialog<IconData>(
      context: context,
      builder: (context) =>
          IconPickerWidget(selectedIcon: _selectedIcon, isDark: widget.isDark),
    );
    if (icon != null) {
      setState(() => _selectedIcon = icon);
    }
  }

  Future<void> _showColorPicker() async {
    final color = await showDialog<Color>(
      context: context,
      builder: (context) => ColorPickerWidget(
        selectedColor: _selectedColor,
        isDark: widget.isDark,
      ),
    );
    if (color != null) {
      setState(() => _selectedColor = color);
    }
  }

  Future<void> _saveAccount() async {
    if (_nameController.text.isEmpty) return;

    final balance = double.tryParse(_balanceController.text) ?? 0.0;
    final isEditing = widget.account != null;
    final oldBalance = widget.account?.balance ?? 0.0;
    final balanceDelta = balance - oldBalance;

    // For new accounts, initialBalance = balance (starting point)
    // For existing accounts, preserve the original initialBalance
    final account = Account(
      id: widget.account?.id,
      name: _nameController.text,
      description: _descriptionController.text.isEmpty
          ? null
          : _descriptionController.text,
      type: _selectedType,
      currency: _selectedCurrency,
      balance: isEditing ? oldBalance : balance,
      iconCodePoint: _selectedIcon.codePoint,
      iconFontFamily: _selectedIcon.fontFamily,
      iconFontPackage: _selectedIcon.fontPackage,
      colorValue: _selectedColor.value,
      includeInTotal: _includeInTotal,
      isDefault: _isDefault,
      // Preserve initial balance for existing accounts, set for new accounts
      initialBalance: widget.account?.initialBalance ?? balance,
      // Preserve other existing properties
      createdAt: widget.account?.createdAt,
      isActive: widget.account?.isActive ?? true,
      sortOrder: widget.account?.sortOrder ?? 0,
      bankName: widget.account?.bankName,
      accountNumber: widget.account?.accountNumber,
      creditLimit: widget.account?.creditLimit,
      notes: widget.account?.notes,
      lastSyncDate: widget.account?.lastSyncDate,
    );

    if (widget.account == null) {
      await ref.read(accountRepositoryProvider).createAccount(account);
    } else {
      await ref.read(accountRepositoryProvider).updateAccount(account);
    }

    // If editing and balance changed, record an adjustment transaction
    if (isEditing && balanceDelta.abs() >= 0.0001) {
      final adjustmentType = balanceDelta >= 0 ? 'income' : 'expense';
      final adjustmentTransaction = Transaction(
        title: 'Balance Adjustment',
        amount: balanceDelta.abs(),
        type: adjustmentType,
        categoryId: 'other',
        accountId: account.id,
        transactionDate: DateTime.now(),
        description: 'Manual balance correction',
        currency: account.currency,
        isBalanceAdjustment: true,
      );

      final balanceService = ref.read(transactionBalanceServiceProvider);
      final transactionRepo = ref.read(transactionRepositoryProvider);
      await balanceService.applyTransactionImpact(adjustmentTransaction);
      await transactionRepo.createTransaction(adjustmentTransaction);

      final normalizedDate = DateTime.now();
      final normalizedDay = DateTime(
        normalizedDate.year,
        normalizedDate.month,
        normalizedDate.day,
      );
      ref.invalidate(allTransactionsProvider);
      ref.invalidate(transactionsForDateProvider(normalizedDay));
      ref.invalidate(monthlyStatisticsProvider);

      // Invalidate daily balance snapshots from today onward
      await ref
          .read(dailyBalanceServiceProvider)
          .invalidateFromDate(normalizedDay);
    }

    if (_isDefault) {
      await ref.read(accountRepositoryProvider).setDefaultAccount(account.id);
    }

    // Account changes can affect historical totals, clear cached snapshots
    await ref.read(dailyBalanceServiceProvider).invalidateAll();
    ref.invalidate(dailyTotalBalanceProvider);

    ref.invalidate(allAccountsProvider);
    ref.invalidate(totalBalanceProvider);
    if (mounted) Navigator.pop(context);
  }
}

/// Dialog to add funds to an account with tracking
class _AddFundDialog extends ConsumerStatefulWidget {
  final bool isDark;
  final Account account;

  const _AddFundDialog({required this.isDark, required this.account});

  @override
  ConsumerState<_AddFundDialog> createState() => _AddFundDialogState();
}

class _AddFundDialogState extends ConsumerState<_AddFundDialog> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  bool _isLoading = false;
  String? _selectedCategoryId;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) return;

    setState(() => _isLoading = true);

    try {
      if (_selectedCategoryId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an income category')),
        );
        setState(() => _isLoading = false);
        return;
      }

      final now = DateTime.now();
      final transaction = Transaction(
        title: 'Fund Addition',
        amount: amount,
        type: 'income',
        categoryId: _selectedCategoryId!,
        accountId: widget.account.id,
        transactionDate: now,
        transactionTime: TimeOfDay.fromDateTime(now),
        description: _noteController.text.isEmpty
            ? 'Added funds to ${widget.account.name}'
            : _noteController.text,
        currency: widget.account.currency,
      );

      final balanceService = ref.read(transactionBalanceServiceProvider);
      final transactionRepo = ref.read(transactionRepositoryProvider);

      // Apply impact to account balance
      await balanceService.applyTransactionImpact(transaction);
      // Save the transaction for tracking
      await transactionRepo.createTransaction(transaction);

      // Invalidate related providers
      ref.invalidate(allTransactionsProvider);
      ref.invalidate(allAccountsProvider);
      ref.invalidate(totalBalanceProvider);
      ref.invalidate(monthlyStatisticsProvider);
      ref.invalidate(incomeTransactionCategoriesProvider);

      // Invalidate daily balance snapshots
      final today = DateTime(now.year, now.month, now.day);
      await ref.read(dailyBalanceServiceProvider).invalidateFromDate(today);
      ref.invalidate(dailyTotalBalanceProvider);

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding funds: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF1A1D23) : Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: widget.isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.05),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Enhanced Header with Gradient
              Container(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: widget.isDark
                        ? [const Color(0xFF2D3139), const Color(0xFF1A1D23)]
                        : [Colors.green.shade50, Colors.white],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.add_card_rounded,
                        color: Colors.green,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add Fund',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: widget.isDark
                                  ? Colors.white
                                  : const Color(0xFF1E1E1E),
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            'to ${widget.account.name}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: widget.isDark
                                  ? Colors.white38
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Amount Section
                      _buildFieldLabel('TRANSACTION AMOUNT'),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _amountController,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: widget.isDark
                              ? Colors.white
                              : const Color(0xFF1E1E1E),
                          letterSpacing: -1,
                        ),
                        decoration: InputDecoration(
                          hintText: '0.00',
                          prefixText:
                              '${CurrencyUtils.getCurrencySymbol(widget.account.currency)} ',
                          prefixStyle: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFCDAF56),
                          ),
                          filled: true,
                          fillColor: widget.isDark
                              ? Colors.white.withOpacity(0.03)
                              : Colors.grey.withOpacity(0.03),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.all(24),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Category Selection
                      _buildFieldLabel('INCOME CATEGORY'),
                      const SizedBox(height: 12),
                      _buildCategoryDropdown(),

                      const SizedBox(height: 28),

                      // Note Section
                      _buildFieldLabel('REFERENCE NOTE'),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _noteController,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: widget.isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: 'e.g., Pocket money, Gift...',
                          hintStyle: TextStyle(
                            color: widget.isDark
                                ? Colors.white24
                                : Colors.grey[400],
                          ),
                          prefixIcon: const Icon(
                            Icons.notes_rounded,
                            size: 20,
                            color: Color(0xFFCDAF56),
                          ),
                          filled: true,
                          fillColor: widget.isDark
                              ? Colors.white.withOpacity(0.03)
                              : Colors.grey.withOpacity(0.03),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Professional Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: Text(
                                'CANCEL',
                                style: TextStyle(
                                  color: widget.isDark
                                      ? Colors.white38
                                      : Colors.grey[500],
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _save,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                ),
                                elevation: 8,
                                shadowColor: Colors.green.withOpacity(0.3),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 3,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'CONFIRM FUND',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1,
                                        fontSize: 13,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        color: Color(0xFFCDAF56),
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    final categoriesAsync = ref.watch(incomeTransactionCategoriesProvider);

    return categoriesAsync.when(
      data: (categories) {
        if (categories.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: widget.isDark
                  ? Colors.orange.withOpacity(0.1)
                  : Colors.orange.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.orange.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_rounded, color: Colors.orange, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No income categories found. Please create categories in Finance Settings.',
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // Auto-select first category if none selected
        if (_selectedCategoryId == null && categories.isNotEmpty) {
          Future.microtask(() {
            if (mounted) {
              setState(() => _selectedCategoryId = categories.first.id);
            }
          });
        }

        return DropdownButtonFormField<String>(
          value: _selectedCategoryId,
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: widget.isDark ? Colors.white38 : Colors.black38,
          ),
          dropdownColor: widget.isDark ? const Color(0xFF1A1D23) : Colors.white,
          decoration: InputDecoration(
            prefixIcon: _selectedCategoryId != null
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: categories
                            .firstWhere((c) => c.id == _selectedCategoryId)
                            .color
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        categories
                                .firstWhere((c) => c.id == _selectedCategoryId)
                                .icon ??
                            Icons.category_rounded,
                        color: categories
                            .firstWhere((c) => c.id == _selectedCategoryId)
                            .color,
                        size: 16,
                      ),
                    ),
                  )
                : const Icon(
                    Icons.category_rounded,
                    size: 20,
                    color: Color(0xFF4CAF50),
                  ),
            filled: true,
            fillColor: widget.isDark
                ? Colors.white.withOpacity(0.03)
                : Colors.grey.withOpacity(0.03),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          items: categories
              .map(
                (c) => DropdownMenuItem(
                  value: c.id,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: c.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          c.icon ?? Icons.category_rounded,
                          color: c.color,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          c.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: widget.isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: (val) => setState(() => _selectedCategoryId = val),
        );
      },
      loading: () => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: widget.isDark
              ? Colors.white.withOpacity(0.03)
              : Colors.grey.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (error, stack) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: widget.isDark
              ? Colors.red.withOpacity(0.1)
              : Colors.red.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.red.withOpacity(0.3),
          ),
        ),
        child: Text(
          'Error loading categories: $error',
          style: const TextStyle(color: Colors.red, fontSize: 12),
        ),
      ),
    );
  }
}
