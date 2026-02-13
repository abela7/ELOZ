import '../models/transaction.dart';
import '../repositories/account_repository.dart';
import '../repositories/transaction_repository.dart';

/// Service to handle all transaction-related balance calculations
/// This ensures consistent and accurate financial calculations
class TransactionBalanceService {
  final AccountRepository _accountRepo;
  final TransactionRepository _transactionRepo;

  TransactionBalanceService(this._accountRepo, this._transactionRepo);

  /// Apply the impact of a transaction to account balance(s)
  /// Call this when CREATING a new transaction
  Future<void> applyTransactionImpact(Transaction transaction) async {
    final amount = transaction.amount;
    final accountId = transaction.accountId;

    if (accountId == null) return;

    switch (transaction.type) {
      case 'income':
        // Income ADDS to account balance
        await _accountRepo.updateAccountBalance(accountId, amount);
        break;
      case 'expense':
        // Expense SUBTRACTS from account balance
        await _accountRepo.updateAccountBalance(accountId, -amount);
        break;
      case 'transfer':
        // Transfer SUBTRACTS from source, ADDS to destination
        final toAccountId = transaction.toAccountId;
        if (toAccountId != null) {
          await _accountRepo.updateAccountBalance(accountId, -amount);
          await _accountRepo.updateAccountBalance(toAccountId, amount);
        }
        break;
    }
  }

  /// Reverse the impact of a transaction from account balance(s)
  /// Call this when DELETING a transaction or before EDITING
  Future<void> reverseTransactionImpact(Transaction transaction) async {
    final amount = transaction.amount;
    final accountId = transaction.accountId;

    if (accountId == null) return;

    switch (transaction.type) {
      case 'income':
        // Reverse income: SUBTRACT from account balance
        await _accountRepo.updateAccountBalance(accountId, -amount);
        break;
      case 'expense':
        // Reverse expense: ADD back to account balance
        await _accountRepo.updateAccountBalance(accountId, amount);
        break;
      case 'transfer':
        // Reverse transfer: ADD back to source, SUBTRACT from destination
        final toAccountId = transaction.toAccountId;
        if (toAccountId != null) {
          await _accountRepo.updateAccountBalance(accountId, amount);
          await _accountRepo.updateAccountBalance(toAccountId, -amount);
        }
        break;
    }
  }

  /// Recalculate all account balances from scratch based on transactions
  /// This preserves initial balances and recalculates based on all transactions
  Future<void> recalculateAllBalances() async {
    // Step 1: Reset all account balances to their initial balance
    await _accountRepo.resetAllBalancesToInitial();

    // Step 2: Get all transactions and apply their impacts
    final transactions = await _transactionRepo.getAllTransactions();

    // Sort by date to apply in chronological order
    transactions.sort((a, b) => a.transactionDate.compareTo(b.transactionDate));

    for (final tx in transactions) {
      await applyTransactionImpact(tx);
    }
  }

  /// Verify and fix account balance based on transaction history
  Future<Map<String, dynamic>> verifyAccountBalance(String accountId) async {
    final account = await _accountRepo.getAccountById(accountId);
    if (account == null) {
      return {'error': 'Account not found'};
    }

    final currentBalance = account.balance;

    // Calculate expected balance from transactions
    final transactions = await _transactionRepo.getTransactionsByAccount(
      accountId,
    );
    double calculatedBalance = account.initialBalance;

    for (final tx in transactions) {
      if (tx.type == 'income' && tx.accountId == accountId) {
        calculatedBalance += tx.amount;
      } else if (tx.type == 'expense' && tx.accountId == accountId) {
        calculatedBalance -= tx.amount;
      } else if (tx.type == 'transfer') {
        if (tx.accountId == accountId) {
          calculatedBalance -= tx.amount; // Money left this account
        } else if (tx.toAccountId == accountId) {
          calculatedBalance += tx.amount; // Money came to this account
        }
      }
    }

    final isCorrect = (currentBalance - calculatedBalance).abs() < 0.01;

    return {
      'accountId': accountId,
      'accountName': account.name,
      'currentBalance': currentBalance,
      'calculatedBalance': calculatedBalance,
      'isCorrect': isCorrect,
      'difference': currentBalance - calculatedBalance,
    };
  }
}
