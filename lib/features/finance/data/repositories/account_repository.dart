import 'package:hive_flutter/hive_flutter.dart';
import '../../../../data/local/hive/hive_service.dart';
import '../models/account.dart';

/// Repository for account CRUD operations using Hive
class AccountRepository {
  static const String boxName = 'accountsBox';

  /// Cached box reference for performance
  Box<Account>? _cachedBox;

  /// Get the accounts box (lazy initialization with caching)
  Future<Box<Account>> _getBox() async {
    if (_cachedBox != null && _cachedBox!.isOpen) {
      return _cachedBox!;
    }
    _cachedBox = await HiveService.getBox<Account>(boxName);
    return _cachedBox!;
  }

  /// Create a new account
  Future<void> createAccount(Account account) async {
    final box = await _getBox();
    await box.put(account.id, account);
  }

  /// Get all accounts
  Future<List<Account>> getAllAccounts() async {
    final box = await _getBox();
    return box.values.toList();
  }

  /// Get account by ID
  Future<Account?> getAccountById(String id) async {
    final box = await _getBox();
    return box.get(id);
  }

  /// Update an existing account
  Future<void> updateAccount(Account account) async {
    final box = await _getBox();

    // Always use put() to ensure the box has the updated object
    // This works for both new and existing objects
    await box.put(account.id, account);

    // If it's in the box, also call save() for extra safety
    if (account.isInBox) {
      await account.save();
    }
  }

  /// Delete an account
  Future<void> deleteAccount(String id) async {
    final box = await _getBox();
    await box.delete(id);
  }

  /// Get active accounts
  Future<List<Account>> getActiveAccounts() async {
    final allAccounts = await getAllAccounts();
    return allAccounts.where((a) => a.isActive).toList();
  }

  /// Get accounts included in total
  Future<List<Account>> getAccountsInTotal() async {
    final allAccounts = await getAllAccounts();
    return allAccounts.where((a) => a.includeInTotal && a.isActive).toList();
  }

  /// Get default account
  Future<Account?> getDefaultAccount() async {
    final allAccounts = await getAllAccounts();
    try {
      return allAccounts.firstWhere((a) => a.isDefault && a.isActive);
    } catch (e) {
      return null;
    }
  }

  /// Set default account
  Future<void> setDefaultAccount(String accountId) async {
    final allAccounts = await getAllAccounts();

    // Remove default from all accounts
    for (final account in allAccounts) {
      if (account.isDefault) {
        account.isDefault = false;
        await updateAccount(account);
      }
    }

    // Set new default
    final account = await getAccountById(accountId);
    if (account != null) {
      account.isDefault = true;
      await updateAccount(account);
    }
  }

  /// Get accounts by type
  Future<List<Account>> getAccountsByType(String type) async {
    final allAccounts = await getAllAccounts();
    return allAccounts.where((a) => a.type == type).toList();
  }

  /// Get accounts by currency
  Future<List<Account>> getAccountsByCurrency(String currency) async {
    final allAccounts = await getAllAccounts();
    return allAccounts.where((a) => a.currency == currency).toList();
  }

  /// Get total balance across all accounts in total
  Future<double> getTotalBalance() async {
    final accounts = await getAccountsInTotal();
    return accounts.fold<double>(0, (sum, a) => sum + a.balance);
  }

  /// Get total balance by currency
  Future<Map<String, double>> getTotalBalanceByCurrency() async {
    final accounts = await getAccountsInTotal();
    final Map<String, double> balances = {};

    for (final account in accounts) {
      balances[account.currency] =
          (balances[account.currency] ?? 0) + account.balance;
    }

    return balances;
  }

  /// Update account balance by adding/subtracting an amount
  Future<void> updateAccountBalance(String accountId, double amount) async {
    final box = await _getBox();
    final account = box.get(accountId);

    if (account != null) {
      account.balance += amount;
      account.lastSyncDate = DateTime.now();

      // Force persist using save() for HiveObjects
      if (account.isInBox) {
        await account.save();
      }
      // Also put to ensure box has updated value
      await box.put(accountId, account);
    }
  }

  /// Transfer between accounts
  Future<bool> transferBetweenAccounts(
    String fromAccountId,
    String toAccountId,
    double amount,
  ) async {
    final fromAccount = await getAccountById(fromAccountId);
    final toAccount = await getAccountById(toAccountId);

    if (fromAccount == null || toAccount == null) {
      return false;
    }

    // Update balances
    fromAccount.updateBalance(-amount);
    toAccount.updateBalance(amount);

    await updateAccount(fromAccount);
    await updateAccount(toAccount);

    return true;
  }

  /// Search accounts by name
  Future<List<Account>> searchAccounts(String query) async {
    final allAccounts = await getAllAccounts();
    final lowerQuery = query.toLowerCase();
    return allAccounts.where((a) {
      return a.name.toLowerCase().contains(lowerQuery) ||
          (a.description != null &&
              a.description!.toLowerCase().contains(lowerQuery)) ||
          (a.bankName != null &&
              a.bankName!.toLowerCase().contains(lowerQuery));
    }).toList();
  }

  /// Delete all accounts (for reset functionality)
  Future<void> deleteAllAccounts() async {
    final box = await _getBox();
    await box.clear();
  }

  /// Reset all account balances to their initial balance
  /// This is used during data reset to clear transaction effects
  Future<void> resetAllBalancesToInitial() async {
    final box = await _getBox();
    final accounts = box.values.toList();

    for (final account in accounts) {
      // Reset balance to initialBalance (starting point)
      account.balance = account.initialBalance;
      account.lastSyncDate = DateTime.now();

      // Force save using both methods to ensure persistence
      if (account.isInBox) {
        await account.save();
      }
      // Also put it back to ensure the box has the updated value
      await box.put(account.id, account);
    }

    // Flush the box to ensure all changes are written to disk
    await box.flush();
  }

  /// Set an account's balance to a specific value (for corrections)
  Future<void> setAccountBalance(String accountId, double newBalance) async {
    final box = await _getBox();
    final account = box.get(accountId);

    if (account != null) {
      account.balance = newBalance;
      account.lastSyncDate = DateTime.now();
      await account.save();
      await box.flush();
    }
  }
}
