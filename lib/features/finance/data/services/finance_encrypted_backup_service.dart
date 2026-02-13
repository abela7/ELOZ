import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../data/local/hive/hive_service.dart';
import '../models/account.dart';
import '../models/bill.dart';
import '../models/bill_category.dart';
import '../models/budget.dart';
import '../models/daily_balance.dart';
import '../models/debt.dart';
import '../models/debt_category.dart';
import '../models/savings_goal.dart';
import '../models/transaction.dart';
import '../models/transaction_category.dart';
import '../models/transaction_template.dart';

class FinanceBackupSummary {
  final int transactions;
  final int transactionCategories;
  final int transactionTemplates;
  final int budgets;
  final int accounts;
  final int dailyBalances;
  final int debtCategories;
  final int debts;
  final int billCategories;
  final int bills;
  final int savingsGoals;

  const FinanceBackupSummary({
    required this.transactions,
    required this.transactionCategories,
    required this.transactionTemplates,
    required this.budgets,
    required this.accounts,
    required this.dailyBalances,
    required this.debtCategories,
    required this.debts,
    required this.billCategories,
    required this.bills,
    required this.savingsGoals,
  });

  int get totalRecords =>
      transactions +
      transactionCategories +
      transactionTemplates +
      budgets +
      accounts +
      dailyBalances +
      debtCategories +
      debts +
      billCategories +
      bills +
      savingsGoals;
}

class FinanceBackupCreateResult {
  final File file;
  final FinanceBackupSummary summary;

  const FinanceBackupCreateResult({required this.file, required this.summary});
}

class FinanceBackupRestoreResult {
  final FinanceBackupSummary summary;
  final bool replacedExisting;

  const FinanceBackupRestoreResult({
    required this.summary,
    required this.replacedExisting,
  });
}

class FinanceLocalBackupEntry {
  final File file;
  final DateTime modifiedAt;
  final int sizeBytes;

  const FinanceLocalBackupEntry({
    required this.file,
    required this.modifiedAt,
    required this.sizeBytes,
  });
}

class FinanceEncryptedBackupService {
  static const String _backupDirectoryName = 'finance_backups';
  static const String _backupFileExtension = 'finbk';

  static const String _payloadFormat = 'finance_backup_payload';
  static const int _payloadVersion = 1;

  static const String _envelopeFormat = 'finance_backup_envelope';
  static const int _envelopeVersion = 1;
  static const int _kdfIterations = 210000;
  static const int _derivedKeyBits = 256;

  static const int _minPassphraseLength = 8;

  final Random _random;
  final Cipher _cipher;
  final Pbkdf2 _pbkdf2;

  FinanceEncryptedBackupService({Random? random})
    : _random = random ?? Random.secure(),
      _cipher = AesGcm.with256bits(),
      _pbkdf2 = Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: _kdfIterations,
        bits: _derivedKeyBits,
      );

  Future<FinanceBackupCreateResult> createLocalBackup({
    required String passphrase,
  }) async {
    _validatePassphrase(passphrase);

    final snapshot = await _readSnapshotFromBoxes();
    final payload = _encodePayload(snapshot);
    final envelope = await _encryptPayload(payload, passphrase: passphrase);

    final backupDir = await _ensureBackupDirectory();
    final now = DateTime.now();
    final file = File(
      '${backupDir.path}${Platform.pathSeparator}${_buildBackupFilename(now)}',
    );

    await file.writeAsString(jsonEncode(envelope), flush: true);

    return FinanceBackupCreateResult(file: file, summary: snapshot.summary);
  }

  Future<FinanceBackupCreateResult> createShareableBackup({
    required String passphrase,
  }) async {
    _validatePassphrase(passphrase);

    final snapshot = await _readSnapshotFromBoxes();
    final payload = _encodePayload(snapshot);
    final envelope = await _encryptPayload(payload, passphrase: passphrase);

    final tempDir = await getTemporaryDirectory();
    final now = DateTime.now();
    final file = File(
      '${tempDir.path}${Platform.pathSeparator}${_buildBackupFilename(now)}',
    );

    await file.writeAsString(jsonEncode(envelope), flush: true);

    return FinanceBackupCreateResult(file: file, summary: snapshot.summary);
  }

  Future<List<FinanceLocalBackupEntry>> listLocalBackups() async {
    final dir = await _ensureBackupDirectory();
    final entries = <FinanceLocalBackupEntry>[];

    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File || !_isBackupFile(entity.path)) {
        continue;
      }
      final stat = await entity.stat();
      entries.add(
        FinanceLocalBackupEntry(
          file: entity,
          modifiedAt: stat.modified,
          sizeBytes: stat.size,
        ),
      );
    }

    entries.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return entries;
  }

  Future<void> deleteLocalBackup(FinanceLocalBackupEntry entry) async {
    final backupDir = await _ensureBackupDirectory();
    final targetPath = entry.file.absolute.path;
    final allowedPrefix = backupDir.absolute.path;

    if (!targetPath.startsWith(allowedPrefix)) {
      throw ArgumentError('Backup file is outside the finance backup folder.');
    }

    if (await entry.file.exists()) {
      await entry.file.delete();
    }
  }

  Future<FinanceBackupRestoreResult> restoreFromFile({
    required File file,
    required String passphrase,
    bool replaceExisting = true,
  }) async {
    _validatePassphrase(passphrase);

    if (!await file.exists()) {
      throw StateError('Backup file does not exist.');
    }

    final rawText = await file.readAsString();
    final envelopeMap = _decodeJsonMap(rawText);
    final payloadMap = await _decryptEnvelope(
      envelopeMap,
      passphrase: passphrase,
    );

    final incomingSnapshot = _decodePayload(payloadMap);

    final previousSnapshot = replaceExisting
        ? await _readSnapshotFromBoxes()
        : null;

    try {
      await _writeSnapshotToBoxes(
        incomingSnapshot,
        replaceExisting: replaceExisting,
      );
    } catch (error) {
      if (replaceExisting && previousSnapshot != null) {
        try {
          await _writeSnapshotToBoxes(previousSnapshot, replaceExisting: true);
        } catch (_) {
          throw StateError(
            'Restore failed and automatic rollback failed. Original data may '
            'be partially changed. Original error: $error',
          );
        }
      }
      rethrow;
    }

    return FinanceBackupRestoreResult(
      summary: incomingSnapshot.summary,
      replacedExisting: replaceExisting,
    );
  }

  Future<FinanceBackupRestoreResult> restoreFromLatestLocalBackup({
    required String passphrase,
    bool replaceExisting = true,
  }) async {
    final backups = await listLocalBackups();
    if (backups.isEmpty) {
      throw StateError('No local encrypted backups found.');
    }

    return restoreFromFile(
      file: backups.first.file,
      passphrase: passphrase,
      replaceExisting: replaceExisting,
    );
  }

  Future<Directory> _ensureBackupDirectory() async {
    final baseDir = await getApplicationDocumentsDirectory();
    final dir = Directory(
      '${baseDir.path}${Platform.pathSeparator}$_backupDirectoryName',
    );

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return dir;
  }

  Future<_FinanceSnapshot> _readSnapshotFromBoxes() async {
    final boxes = await _openBoxes();

    return _FinanceSnapshot(
      transactions: boxes.transactions.values.toList(growable: false),
      transactionCategories: boxes.transactionCategories.values.toList(
        growable: false,
      ),
      transactionTemplates: boxes.transactionTemplates.values.toList(
        growable: false,
      ),
      budgets: boxes.budgets.values.toList(growable: false),
      accounts: boxes.accounts.values.toList(growable: false),
      dailyBalances: boxes.dailyBalances.values.toList(growable: false),
      debtCategories: boxes.debtCategories.values.toList(growable: false),
      debts: boxes.debts.values.toList(growable: false),
      billCategories: boxes.billCategories.values.toList(growable: false),
      bills: boxes.bills.values.toList(growable: false),
      savingsGoals: boxes.savingsGoals.values.toList(growable: false),
    );
  }

  Future<void> _writeSnapshotToBoxes(
    _FinanceSnapshot snapshot, {
    required bool replaceExisting,
  }) async {
    final boxes = await _openBoxes();

    if (replaceExisting) {
      await boxes.transactions.clear();
      await boxes.transactionCategories.clear();
      await boxes.transactionTemplates.clear();
      await boxes.budgets.clear();
      await boxes.accounts.clear();
      await boxes.dailyBalances.clear();
      await boxes.debtCategories.clear();
      await boxes.debts.clear();
      await boxes.billCategories.clear();
      await boxes.bills.clear();
      await boxes.savingsGoals.clear();
    }

    if (snapshot.transactions.isNotEmpty) {
      await boxes.transactions.putAll({
        for (final item in snapshot.transactions) item.id: item,
      });
    }

    if (snapshot.transactionCategories.isNotEmpty) {
      await boxes.transactionCategories.putAll({
        for (final item in snapshot.transactionCategories) item.id: item,
      });
    }

    if (snapshot.transactionTemplates.isNotEmpty) {
      await boxes.transactionTemplates.putAll({
        for (final item in snapshot.transactionTemplates) item.id: item,
      });
    }

    if (snapshot.budgets.isNotEmpty) {
      await boxes.budgets.putAll({
        for (final item in snapshot.budgets) item.id: item,
      });
    }

    if (snapshot.accounts.isNotEmpty) {
      await boxes.accounts.putAll({
        for (final item in snapshot.accounts) item.id: item,
      });
    }

    if (snapshot.dailyBalances.isNotEmpty) {
      await boxes.dailyBalances.putAll({
        for (final item in snapshot.dailyBalances) item.id: item,
      });
    }

    if (snapshot.debtCategories.isNotEmpty) {
      await boxes.debtCategories.putAll({
        for (final item in snapshot.debtCategories) item.id: item,
      });
    }

    if (snapshot.debts.isNotEmpty) {
      await boxes.debts.putAll({
        for (final item in snapshot.debts) item.id: item,
      });
    }

    if (snapshot.billCategories.isNotEmpty) {
      await boxes.billCategories.putAll({
        for (final item in snapshot.billCategories) item.id: item,
      });
    }

    if (snapshot.bills.isNotEmpty) {
      await boxes.bills.putAll({
        for (final item in snapshot.bills) item.id: item,
      });
    }

    if (snapshot.savingsGoals.isNotEmpty) {
      await boxes.savingsGoals.putAll({
        for (final item in snapshot.savingsGoals) item.id: item,
      });
    }

    await boxes.transactions.flush();
    await boxes.transactionCategories.flush();
    await boxes.transactionTemplates.flush();
    await boxes.budgets.flush();
    await boxes.accounts.flush();
    await boxes.dailyBalances.flush();
    await boxes.debtCategories.flush();
    await boxes.debts.flush();
    await boxes.billCategories.flush();
    await boxes.bills.flush();
    await boxes.savingsGoals.flush();
  }

  Future<_FinanceBoxes> _openBoxes() async {
    final transactions = await HiveService.getBox<Transaction>(
      'transactionsBox',
    );
    final transactionCategories = await HiveService.getBox<TransactionCategory>(
      'transactionCategoriesBox',
    );
    final transactionTemplates = await HiveService.getBox<TransactionTemplate>(
      'transactionTemplatesBox',
    );
    final budgets = await HiveService.getBox<Budget>('budgetsBox');
    final accounts = await HiveService.getBox<Account>('accountsBox');
    final dailyBalances = await HiveService.getBox<DailyBalance>(
      'dailyBalancesBox',
    );
    final debtCategories = await HiveService.getBox<DebtCategory>(
      'debtCategoriesBox',
    );
    final debts = await HiveService.getBox<Debt>('debtsBox');
    final billCategories = await HiveService.getBox<BillCategory>(
      'billCategoriesBox',
    );
    final bills = await HiveService.getBox<Bill>('billsBox');
    final savingsGoals = await HiveService.getBox<SavingsGoal>(
      'savingsGoalsBox',
    );

    return _FinanceBoxes(
      transactions: transactions,
      transactionCategories: transactionCategories,
      transactionTemplates: transactionTemplates,
      budgets: budgets,
      accounts: accounts,
      dailyBalances: dailyBalances,
      debtCategories: debtCategories,
      debts: debts,
      billCategories: billCategories,
      bills: bills,
      savingsGoals: savingsGoals,
    );
  }

  Future<Map<String, dynamic>> _encryptPayload(
    Map<String, dynamic> payload, {
    required String passphrase,
  }) async {
    final payloadBytes = utf8.encode(jsonEncode(payload));

    final salt = _randomBytes(16);
    final nonce = _randomBytes(12);

    final key = await _pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );

    final secretBox = await _cipher.encrypt(
      payloadBytes,
      secretKey: key,
      nonce: nonce,
    );

    return {
      'format': _envelopeFormat,
      'version': _envelopeVersion,
      'createdAt': DateTime.now().toIso8601String(),
      'cipher': 'AES-256-GCM',
      'kdf': {
        'name': 'PBKDF2-HMAC-SHA256',
        'iterations': _kdfIterations,
        'bits': _derivedKeyBits,
        'salt': base64Encode(salt),
      },
      'nonce': base64Encode(secretBox.nonce),
      'cipherText': base64Encode(secretBox.cipherText),
      'mac': base64Encode(secretBox.mac.bytes),
    };
  }

  Future<Map<String, dynamic>> _decryptEnvelope(
    Map<String, dynamic> envelope, {
    required String passphrase,
  }) async {
    final format = envelope['format'];
    final version = _toInt(envelope['version']);

    if (format != _envelopeFormat || version != _envelopeVersion) {
      throw const FormatException('Unsupported encrypted backup format.');
    }

    final kdf = _asMap(envelope['kdf'], key: 'kdf');
    final kdfName = kdf['name'];
    final iterations = _toInt(kdf['iterations']);
    final bits = _toInt(kdf['bits']);

    if (kdfName != 'PBKDF2-HMAC-SHA256' ||
        iterations != _kdfIterations ||
        bits != _derivedKeyBits) {
      throw const FormatException(
        'Unsupported backup key derivation settings.',
      );
    }

    final salt = _decodeBase64Field(kdf['salt'], fieldName: 'kdf.salt');
    final nonce = _decodeBase64Field(envelope['nonce'], fieldName: 'nonce');
    final cipherText = _decodeBase64Field(
      envelope['cipherText'],
      fieldName: 'cipherText',
    );
    final mac = _decodeBase64Field(envelope['mac'], fieldName: 'mac');

    final key = await _pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );

    final secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(mac));

    List<int> clearBytes;
    try {
      clearBytes = await _cipher.decrypt(secretBox, secretKey: key);
    } catch (_) {
      throw const FormatException(
        'Unable to decrypt backup. Check the passphrase or file integrity.',
      );
    }

    return _decodeJsonMap(utf8.decode(clearBytes));
  }

  Map<String, dynamic> _encodePayload(_FinanceSnapshot snapshot) {
    return {
      'format': _payloadFormat,
      'version': _payloadVersion,
      'createdAt': DateTime.now().toIso8601String(),
      'data': {
        'transactions': snapshot.transactions.map(_encodeTransaction).toList(),
        'transactionCategories': snapshot.transactionCategories
            .map(_encodeTransactionCategory)
            .toList(),
        'transactionTemplates': snapshot.transactionTemplates
            .map(_encodeTransactionTemplate)
            .toList(),
        'budgets': snapshot.budgets.map(_encodeBudget).toList(),
        'accounts': snapshot.accounts.map(_encodeAccount).toList(),
        'dailyBalances': snapshot.dailyBalances
            .map(_encodeDailyBalance)
            .toList(),
        'debtCategories': snapshot.debtCategories
            .map(_encodeDebtCategory)
            .toList(),
        'debts': snapshot.debts.map(_encodeDebt).toList(),
        'billCategories': snapshot.billCategories
            .map(_encodeBillCategory)
            .toList(),
        'bills': snapshot.bills.map(_encodeBill).toList(),
        'savingsGoals': snapshot.savingsGoals.map(_encodeSavingsGoal).toList(),
      },
    };
  }

  _FinanceSnapshot _decodePayload(Map<String, dynamic> payload) {
    final format = payload['format'];
    final version = _toInt(payload['version']);

    if (format != _payloadFormat || version != _payloadVersion) {
      throw const FormatException('Unsupported backup payload format.');
    }

    final data = _asMap(payload['data'], key: 'data');

    return _FinanceSnapshot(
      transactions: _asMapList(
        data['transactions'],
        key: 'transactions',
      ).map(_decodeTransaction).toList(growable: false),
      transactionCategories: _asMapList(
        data['transactionCategories'],
        key: 'transactionCategories',
      ).map(_decodeTransactionCategory).toList(growable: false),
      transactionTemplates: _asMapList(
        data['transactionTemplates'],
        key: 'transactionTemplates',
      ).map(_decodeTransactionTemplate).toList(growable: false),
      budgets: _asMapList(
        data['budgets'],
        key: 'budgets',
      ).map(_decodeBudget).toList(growable: false),
      accounts: _asMapList(
        data['accounts'],
        key: 'accounts',
      ).map(_decodeAccount).toList(growable: false),
      dailyBalances: _asMapList(
        data['dailyBalances'],
        key: 'dailyBalances',
      ).map(_decodeDailyBalance).toList(growable: false),
      debtCategories: _asMapList(
        data['debtCategories'],
        key: 'debtCategories',
      ).map(_decodeDebtCategory).toList(growable: false),
      debts: _asMapList(
        data['debts'],
        key: 'debts',
      ).map(_decodeDebt).toList(growable: false),
      billCategories: _asMapList(
        data['billCategories'],
        key: 'billCategories',
      ).map(_decodeBillCategory).toList(growable: false),
      bills: _asMapList(
        data['bills'],
        key: 'bills',
      ).map(_decodeBill).toList(growable: false),
      savingsGoals: _asMapList(
        data['savingsGoals'],
        key: 'savingsGoals',
      ).map(_decodeSavingsGoal).toList(growable: false),
    );
  }

  Map<String, dynamic> _encodeTransaction(Transaction model) {
    return {
      'id': model.id,
      'title': model.title,
      'description': model.description,
      'amount': model.amount,
      'type': model.type,
      'categoryId': model.categoryId,
      'accountId': model.accountId,
      'toAccountId': model.toAccountId,
      'transactionDate': model.transactionDate.toIso8601String(),
      'transactionTimeHour': model.transactionTimeHour,
      'transactionTimeMinute': model.transactionTimeMinute,
      'createdAt': model.createdAt.toIso8601String(),
      'updatedAt': model.updatedAt?.toIso8601String(),
      'notes': model.notes,
      'tags': model.tags,
      'receiptPath': model.receiptPath,
      'paymentMethod': model.paymentMethod,
      'currency': model.currency,
      'isRecurring': model.isRecurring,
      'recurrenceRule': model.recurrenceRule,
      'recurringGroupId': model.recurringGroupId,
      'location': model.location,
      'contactPerson': model.contactPerson,
      'isSplit': model.isSplit,
      'splitData': model.splitData,
      'iconCodePoint': model.iconCodePoint,
      'iconFontFamily': model.iconFontFamily,
      'iconFontPackage': model.iconFontPackage,
      'needsReview': model.needsReview,
      'isCleared': model.isCleared,
      'clearedDate': model.clearedDate?.toIso8601String(),
      'isBalanceAdjustment': model.isBalanceAdjustment,
    };
  }

  Transaction _decodeTransaction(Map<String, dynamic> map) {
    final model = Transaction(
      id: _requiredString(map, 'id'),
      title: _requiredString(map, 'title'),
      description: _nullableString(map['description']),
      amount: _toDouble(map['amount']),
      type: _requiredString(map, 'type'),
      categoryId: _nullableString(map['categoryId']),
      accountId: _nullableString(map['accountId']),
      toAccountId: _nullableString(map['toAccountId']),
      transactionDate: _requiredDate(map, 'transactionDate'),
      createdAt: _requiredDate(map, 'createdAt'),
      updatedAt: _nullableDate(map['updatedAt']),
      notes: _nullableString(map['notes']),
      tags: _nullableStringList(map['tags']),
      receiptPath: _nullableString(map['receiptPath']),
      paymentMethod: _nullableString(map['paymentMethod']),
      currency: _nullableString(map['currency']),
      isRecurring: _toBool(map['isRecurring']),
      recurrenceRule: _nullableString(map['recurrenceRule']),
      recurringGroupId: _nullableString(map['recurringGroupId']),
      location: _nullableString(map['location']),
      contactPerson: _nullableString(map['contactPerson']),
      isSplit: _toBool(map['isSplit']),
      splitData: _nullableString(map['splitData']),
      iconCodePoint: _nullableInt(map['iconCodePoint']),
      iconFontFamily: _nullableString(map['iconFontFamily']),
      iconFontPackage: _nullableString(map['iconFontPackage']),
      needsReview: _toBool(map['needsReview']),
      isCleared: _toBool(map['isCleared']),
      clearedDate: _nullableDate(map['clearedDate']),
      isBalanceAdjustment: _toBool(map['isBalanceAdjustment']),
    );

    model.transactionTimeHour = _nullableInt(map['transactionTimeHour']);
    model.transactionTimeMinute = _nullableInt(map['transactionTimeMinute']);
    return model;
  }

  Map<String, dynamic> _encodeTransactionCategory(TransactionCategory model) {
    return {
      'id': model.id,
      'name': model.name,
      'description': model.description,
      'iconCodePoint': model.iconCodePoint,
      'iconFontFamily': model.iconFontFamily,
      'iconFontPackage': model.iconFontPackage,
      'colorValue': model.colorValue,
      'type': model.type,
      'isSystemCategory': model.isSystemCategory,
      'createdAt': model.createdAt.toIso8601String(),
      'sortOrder': model.sortOrder,
      'parentCategoryId': model.parentCategoryId,
      'monthlyBudget': model.monthlyBudget,
    };
  }

  TransactionCategory _decodeTransactionCategory(Map<String, dynamic> map) {
    return TransactionCategory(
      id: _requiredString(map, 'id'),
      name: _requiredString(map, 'name'),
      description: _nullableString(map['description']),
      iconCodePoint: _nullableInt(map['iconCodePoint']),
      iconFontFamily: _nullableString(map['iconFontFamily']),
      iconFontPackage: _nullableString(map['iconFontPackage']),
      colorValue: _nullableInt(map['colorValue']),
      type: _requiredString(map, 'type'),
      isSystemCategory: _toBool(map['isSystemCategory']),
      createdAt: _requiredDate(map, 'createdAt'),
      sortOrder: _toInt(map['sortOrder']),
      parentCategoryId: _nullableString(map['parentCategoryId']),
      monthlyBudget: _nullableDouble(map['monthlyBudget']),
    );
  }

  Map<String, dynamic> _encodeTransactionTemplate(TransactionTemplate model) {
    return {
      'id': model.id,
      'name': model.name,
      'transactionTitle': model.transactionTitle,
      'amount': model.amount,
      'type': model.type,
      'categoryId': model.categoryId,
      'accountId': model.accountId,
      'toAccountId': model.toAccountId,
      'description': model.description,
      'createdAt': model.createdAt.toIso8601String(),
      'iconCodePoint': model.iconCodePoint,
      'iconFontFamily': model.iconFontFamily,
      'iconFontPackage': model.iconFontPackage,
      'isRecurring': model.isRecurring,
      'recurrenceRule': model.recurrenceRule,
    };
  }

  TransactionTemplate _decodeTransactionTemplate(Map<String, dynamic> map) {
    final model = TransactionTemplate(
      id: _requiredString(map, 'id'),
      name: _requiredString(map, 'name'),
      transactionTitle: _requiredString(map, 'transactionTitle'),
      amount: _toDouble(map['amount']),
      type: _requiredString(map, 'type'),
      categoryId: _nullableString(map['categoryId']),
      accountId: _nullableString(map['accountId']),
      toAccountId: _nullableString(map['toAccountId']),
      description: _nullableString(map['description']),
      createdAt: _requiredDate(map, 'createdAt'),
      isRecurring: _toBool(map['isRecurring']),
      recurrenceRule: _nullableString(map['recurrenceRule']),
    );

    model.iconCodePoint = _nullableInt(map['iconCodePoint']);
    model.iconFontFamily = _nullableString(map['iconFontFamily']);
    model.iconFontPackage = _nullableString(map['iconFontPackage']);
    return model;
  }

  Map<String, dynamic> _encodeBudget(Budget model) {
    return {
      'id': model.id,
      'name': model.name,
      'description': model.description,
      'amount': model.amount,
      'period': model.period,
      'periodSpan': model.periodSpan,
      'categoryId': model.categoryId,
      'startDate': model.startDate.toIso8601String(),
      'endDate': model.endDate?.toIso8601String(),
      'isActive': model.isActive,
      'isPaused': model.isPaused,
      'isStopped': model.isStopped,
      'stoppedAt': model.stoppedAt?.toIso8601String(),
      'endedAt': model.endedAt?.toIso8601String(),
      'createdAt': model.createdAt.toIso8601String(),
      'currentSpent': model.currentSpent,
      'lifetimeSpent': model.lifetimeSpent,
      'matchedTransactionCount': model.matchedTransactionCount,
      'alertEnabled': model.alertEnabled,
      'alertThreshold': model.alertThreshold,
      'carryOver': model.carryOver,
      'endCondition': model.endCondition,
      'endTransactionCount': model.endTransactionCount,
      'endSpentAmount': model.endSpentAmount,
      'excludedCategoryIds': model.excludedCategoryIds,
      'currency': model.currency,
      'accountId': model.accountId,
    };
  }

  Budget _decodeBudget(Map<String, dynamic> map) {
    return Budget(
      id: _requiredString(map, 'id'),
      name: _requiredString(map, 'name'),
      description: _nullableString(map['description']),
      amount: _toDouble(map['amount']),
      period: _requiredString(map, 'period'),
      periodSpan: _nullableInt(map['periodSpan']) ?? 1,
      categoryId: _nullableString(map['categoryId']),
      startDate: _requiredDate(map, 'startDate'),
      endDate: _nullableDate(map['endDate']),
      isActive: _toBool(map['isActive']),
      isPaused: _toBool(map['isPaused']),
      isStopped: _toBool(map['isStopped']),
      stoppedAt: _nullableDate(map['stoppedAt']),
      endedAt: _nullableDate(map['endedAt']),
      createdAt: _requiredDate(map, 'createdAt'),
      currentSpent: _toDouble(map['currentSpent']),
      lifetimeSpent: _nullableDouble(map['lifetimeSpent']) ?? 0.0,
      matchedTransactionCount:
          _nullableInt(map['matchedTransactionCount']) ?? 0,
      alertEnabled: _toBool(map['alertEnabled']),
      alertThreshold: _toDouble(map['alertThreshold']),
      carryOver: _toBool(map['carryOver']),
      endCondition: _nullableString(map['endCondition']) ?? 'indefinite',
      endTransactionCount: _nullableInt(map['endTransactionCount']),
      endSpentAmount: _nullableDouble(map['endSpentAmount']),
      excludedCategoryIds: _nullableStringList(map['excludedCategoryIds']),
      currency: _requiredString(map, 'currency'),
      accountId: _nullableString(map['accountId']),
    );
  }

  Map<String, dynamic> _encodeAccount(Account model) {
    return {
      'id': model.id,
      'name': model.name,
      'description': model.description,
      'type': model.type,
      'balance': model.balance,
      'currency': model.currency,
      'iconCodePoint': model.iconCodePoint,
      'iconFontFamily': model.iconFontFamily,
      'iconFontPackage': model.iconFontPackage,
      'colorValue': model.colorValue,
      'createdAt': model.createdAt.toIso8601String(),
      'isActive': model.isActive,
      'includeInTotal': model.includeInTotal,
      'sortOrder': model.sortOrder,
      'bankName': model.bankName,
      'accountNumber': model.accountNumber,
      'creditLimit': model.creditLimit,
      'notes': model.notes,
      'lastSyncDate': model.lastSyncDate?.toIso8601String(),
      'isDefault': model.isDefault,
      'initialBalance': model.initialBalance,
    };
  }

  Account _decodeAccount(Map<String, dynamic> map) {
    return Account(
      id: _requiredString(map, 'id'),
      name: _requiredString(map, 'name'),
      description: _nullableString(map['description']),
      type: _requiredString(map, 'type'),
      balance: _toDouble(map['balance']),
      currency: _requiredString(map, 'currency'),
      iconCodePoint: _nullableInt(map['iconCodePoint']),
      iconFontFamily: _nullableString(map['iconFontFamily']),
      iconFontPackage: _nullableString(map['iconFontPackage']),
      colorValue: _nullableInt(map['colorValue']),
      createdAt: _requiredDate(map, 'createdAt'),
      isActive: _toBool(map['isActive']),
      includeInTotal: _toBool(map['includeInTotal']),
      sortOrder: _toInt(map['sortOrder']),
      bankName: _nullableString(map['bankName']),
      accountNumber: _nullableString(map['accountNumber']),
      creditLimit: _nullableDouble(map['creditLimit']),
      notes: _nullableString(map['notes']),
      lastSyncDate: _nullableDate(map['lastSyncDate']),
      isDefault: _toBool(map['isDefault']),
      initialBalance: _toDouble(map['initialBalance']),
    );
  }

  Map<String, dynamic> _encodeDailyBalance(DailyBalance model) {
    return {
      'id': model.id,
      'date': model.date.toIso8601String(),
      'currency': model.currency,
      'totalBalance': model.totalBalance,
      'createdAt': model.createdAt.toIso8601String(),
    };
  }

  DailyBalance _decodeDailyBalance(Map<String, dynamic> map) {
    return DailyBalance(
      id: _requiredString(map, 'id'),
      date: _requiredDate(map, 'date'),
      currency: _requiredString(map, 'currency'),
      totalBalance: _toDouble(map['totalBalance']),
      createdAt: _requiredDate(map, 'createdAt'),
    );
  }

  Map<String, dynamic> _encodeDebtCategory(DebtCategory model) {
    return {
      'id': model.id,
      'name': model.name,
      'description': model.description,
      'iconCodePoint': model.iconCodePoint,
      'iconFontFamily': model.iconFontFamily,
      'iconFontPackage': model.iconFontPackage,
      'colorValue': model.colorValue,
      'createdAt': model.createdAt.toIso8601String(),
      'isActive': model.isActive,
      'sortOrder': model.sortOrder,
    };
  }

  DebtCategory _decodeDebtCategory(Map<String, dynamic> map) {
    return DebtCategory(
      id: _requiredString(map, 'id'),
      name: _requiredString(map, 'name'),
      description: _nullableString(map['description']),
      iconCodePoint: _nullableInt(map['iconCodePoint']),
      iconFontFamily: _nullableString(map['iconFontFamily']),
      iconFontPackage: _nullableString(map['iconFontPackage']),
      colorValue: _nullableInt(map['colorValue']),
      createdAt: _requiredDate(map, 'createdAt'),
      isActive: _toBool(map['isActive']),
      sortOrder: _toInt(map['sortOrder']),
    );
  }

  Map<String, dynamic> _encodeDebt(Debt model) {
    return {
      'id': model.id,
      'name': model.name,
      'description': model.description,
      'categoryId': model.categoryId,
      'originalAmount': model.originalAmount,
      'currentBalance': model.currentBalance,
      'interestRate': model.interestRate,
      'creditorName': model.creditorName,
      'dueDate': model.dueDate?.toIso8601String(),
      'minimumPayment': model.minimumPayment,
      'currency': model.currency,
      'status': model.status,
      'createdAt': model.createdAt.toIso8601String(),
      'updatedAt': model.updatedAt?.toIso8601String(),
      'paidOffDate': model.paidOffDate?.toIso8601String(),
      'notes': model.notes,
      'accountId': model.accountId,
      'iconCodePoint': model.iconCodePoint,
      'iconFontFamily': model.iconFontFamily,
      'iconFontPackage': model.iconFontPackage,
      'colorValue': model.colorValue,
      'reminderEnabled': model.reminderEnabled,
      'reminderDaysBefore': model.reminderDaysBefore,
      'remindersJson': model.remindersJson,
      'paymentLogJson': model.paymentLogJson,
      'direction': model.direction,
    };
  }

  Debt _decodeDebt(Map<String, dynamic> map) {
    return Debt(
      id: _requiredString(map, 'id'),
      name: _requiredString(map, 'name'),
      description: _nullableString(map['description']),
      categoryId: _requiredString(map, 'categoryId'),
      originalAmount: _toDouble(map['originalAmount']),
      currentBalance: _toDouble(map['currentBalance']),
      interestRate: _nullableDouble(map['interestRate']),
      creditorName: _nullableString(map['creditorName']),
      dueDate: _nullableDate(map['dueDate']),
      minimumPayment: _nullableDouble(map['minimumPayment']),
      currency: _requiredString(map, 'currency'),
      status: _requiredString(map, 'status'),
      createdAt: _requiredDate(map, 'createdAt'),
      updatedAt: _nullableDate(map['updatedAt']),
      paidOffDate: _nullableDate(map['paidOffDate']),
      notes: _nullableString(map['notes']),
      accountId: _nullableString(map['accountId']),
      iconCodePoint: _nullableInt(map['iconCodePoint']),
      iconFontFamily: _nullableString(map['iconFontFamily']),
      iconFontPackage: _nullableString(map['iconFontPackage']),
      colorValue: _nullableInt(map['colorValue']),
      reminderEnabled: _toBool(map['reminderEnabled']),
      reminderDaysBefore: _toInt(map['reminderDaysBefore']),
      remindersJson: _nullableString(map['remindersJson']),
      paymentLogJson: (map['paymentLogJson'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(growable: false),
      direction: _nullableString(map['direction']) ?? 'owed',
    );
  }

  Map<String, dynamic> _encodeBillCategory(BillCategory model) {
    return {
      'id': model.id,
      'name': model.name,
      'iconCodePoint': model.iconCodePoint,
      'iconFontFamily': model.iconFontFamily,
      'iconFontPackage': model.iconFontPackage,
      'colorValue': model.colorValue,
      'isActive': model.isActive,
      'sortOrder': model.sortOrder,
      'createdAt': model.createdAt.toIso8601String(),
    };
  }

  BillCategory _decodeBillCategory(Map<String, dynamic> map) {
    final model = BillCategory(
      id: _requiredString(map, 'id'),
      name: _requiredString(map, 'name'),
      isActive: _toBool(map['isActive']),
      sortOrder: _toInt(map['sortOrder']),
      createdAt: _requiredDate(map, 'createdAt'),
    );

    model.iconCodePoint = _nullableInt(map['iconCodePoint']);
    model.iconFontFamily = _nullableString(map['iconFontFamily']);
    model.iconFontPackage = _nullableString(map['iconFontPackage']);
    final colorValue = _nullableInt(map['colorValue']);
    if (colorValue != null) {
      model.colorValue = colorValue;
    }

    return model;
  }

  Map<String, dynamic> _encodeBill(Bill model) {
    return {
      'id': model.id,
      'name': model.name,
      'description': model.description,
      'categoryId': model.categoryId,
      'accountId': model.accountId,
      'type': model.type,
      'amountType': model.amountType,
      'defaultAmount': model.defaultAmount,
      'currency': model.currency,
      'frequency': model.frequency,
      'recurrenceRule': model.recurrenceRule,
      'dueDay': model.dueDay,
      'nextDueDate': model.nextDueDate?.toIso8601String(),
      'lastPaidDate': model.lastPaidDate?.toIso8601String(),
      'lastPaidAmount': model.lastPaidAmount,
      'isActive': model.isActive,
      'autoPayEnabled': model.autoPayEnabled,
      'reminderEnabled': model.reminderEnabled,
      'reminderDaysBefore': model.reminderDaysBefore,
      'iconCodePoint': model.iconCodePoint,
      'iconFontFamily': model.iconFontFamily,
      'iconFontPackage': model.iconFontPackage,
      'colorValue': model.colorValue,
      'createdAt': model.createdAt.toIso8601String(),
      'startDate': model.startDate.toIso8601String(),
      'endCondition': model.endCondition,
      'endOccurrences': model.endOccurrences,
      'endAmount': model.endAmount,
      'endDate': model.endDate?.toIso8601String(),
      'occurrenceCount': model.occurrenceCount,
      'totalPaidAmount': model.totalPaidAmount,
      'notes': model.notes,
      'providerName': model.providerName,
      'paymentLink': model.paymentLink,
    };
  }

  Bill _decodeBill(Map<String, dynamic> map) {
    final model = Bill(
      id: _requiredString(map, 'id'),
      name: _requiredString(map, 'name'),
      description: _nullableString(map['description']),
      categoryId: _requiredString(map, 'categoryId'),
      accountId: _nullableString(map['accountId']),
      type: _requiredString(map, 'type'),
      amountType: _requiredString(map, 'amountType'),
      defaultAmount: _toDouble(map['defaultAmount']),
      currency: _requiredString(map, 'currency'),
      frequency: _requiredString(map, 'frequency'),
      recurrenceRule: _nullableString(map['recurrenceRule']),
      dueDay: _nullableInt(map['dueDay']),
      nextDueDate: _nullableDate(map['nextDueDate']),
      lastPaidDate: _nullableDate(map['lastPaidDate']),
      lastPaidAmount: _nullableDouble(map['lastPaidAmount']),
      isActive: _toBool(map['isActive']),
      autoPayEnabled: _toBool(map['autoPayEnabled']),
      reminderEnabled: _toBool(map['reminderEnabled']),
      reminderDaysBefore: _toInt(map['reminderDaysBefore']),
      createdAt: _requiredDate(map, 'createdAt'),
      startDate:
          _nullableDate(map['startDate']) ?? _requiredDate(map, 'createdAt'),
      endCondition: _nullableString(map['endCondition']) ?? 'indefinite',
      endOccurrences: _nullableInt(map['endOccurrences']),
      endAmount: _nullableDouble(map['endAmount']),
      endDate: _nullableDate(map['endDate']),
      occurrenceCount: _nullableInt(map['occurrenceCount']) ?? 0,
      totalPaidAmount: _nullableDouble(map['totalPaidAmount']) ?? 0.0,
      notes: _nullableString(map['notes']),
      providerName: _nullableString(map['providerName']),
      paymentLink: _nullableString(map['paymentLink']),
    );

    model.iconCodePoint = _nullableInt(map['iconCodePoint']);
    model.iconFontFamily = _nullableString(map['iconFontFamily']);
    model.iconFontPackage = _nullableString(map['iconFontPackage']);
    final colorValue = _nullableInt(map['colorValue']);
    if (colorValue != null) {
      model.colorValue = colorValue;
    }

    return model;
  }

  Map<String, dynamic> _encodeSavingsGoal(SavingsGoal model) {
    return {
      'id': model.id,
      'name': model.name,
      'description': model.description,
      'targetAmount': model.targetAmount,
      'savedAmount': model.savedAmount,
      'currency': model.currency,
      'startDate': model.startDate.toIso8601String(),
      'targetDate': model.targetDate.toIso8601String(),
      'status': model.status,
      'createdAt': model.createdAt.toIso8601String(),
      'updatedAt': model.updatedAt?.toIso8601String(),
      'closedAt': model.closedAt?.toIso8601String(),
      'accountId': model.accountId,
      'iconCodePoint': model.iconCodePoint,
      'iconFontFamily': model.iconFontFamily,
      'iconFontPackage': model.iconFontPackage,
      'colorValue': model.colorValue,
      'contributionLogJson': model.contributionLogJson,
      'failureReason': model.failureReason,
    };
  }

  SavingsGoal _decodeSavingsGoal(Map<String, dynamic> map) {
    return SavingsGoal(
      id: _requiredString(map, 'id'),
      name: _requiredString(map, 'name'),
      description: _nullableString(map['description']),
      targetAmount: _toDouble(map['targetAmount']),
      savedAmount: _toDouble(map['savedAmount']),
      currency: _requiredString(map, 'currency'),
      startDate: _requiredDate(map, 'startDate'),
      targetDate: _requiredDate(map, 'targetDate'),
      status: _requiredString(map, 'status'),
      createdAt: _requiredDate(map, 'createdAt'),
      updatedAt: _nullableDate(map['updatedAt']),
      closedAt: _nullableDate(map['closedAt']),
      accountId: _nullableString(map['accountId']),
      iconCodePoint: _nullableInt(map['iconCodePoint']),
      iconFontFamily: _nullableString(map['iconFontFamily']),
      iconFontPackage: _nullableString(map['iconFontPackage']),
      colorValue: _nullableInt(map['colorValue']),
      contributionLogJson: (map['contributionLogJson'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(growable: false),
      failureReason: _nullableString(map['failureReason']),
    );
  }

  List<int> _randomBytes(int length) {
    return List<int>.generate(length, (_) => _random.nextInt(256));
  }

  String _buildBackupFilename(DateTime dateTime) {
    final yyyy = dateTime.year.toString().padLeft(4, '0');
    final mm = dateTime.month.toString().padLeft(2, '0');
    final dd = dateTime.day.toString().padLeft(2, '0');
    final hh = dateTime.hour.toString().padLeft(2, '0');
    final min = dateTime.minute.toString().padLeft(2, '0');
    final sec = dateTime.second.toString().padLeft(2, '0');

    return 'finance_backup_${yyyy}${mm}${dd}_${hh}${min}${sec}.$_backupFileExtension';
  }

  bool _isBackupFile(String path) {
    return path.toLowerCase().endsWith('.$_backupFileExtension');
  }

  void _validatePassphrase(String passphrase) {
    if (passphrase.trim().length < _minPassphraseLength) {
      throw ArgumentError(
        'Passphrase must be at least $_minPassphraseLength characters.',
      );
    }
  }

  Map<String, dynamic> _decodeJsonMap(String jsonText) {
    dynamic decoded;
    try {
      decoded = jsonDecode(jsonText);
    } catch (_) {
      throw const FormatException('Backup file is not valid JSON.');
    }

    if (decoded is! Map) {
      throw const FormatException('Backup root JSON must be an object.');
    }

    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }

  Map<String, dynamic> _asMap(dynamic value, {required String key}) {
    if (value is! Map) {
      throw FormatException('Field \"$key\" must be an object.');
    }
    return value.map((k, v) => MapEntry(k.toString(), v));
  }

  List<Map<String, dynamic>> _asMapList(dynamic value, {required String key}) {
    if (value == null) {
      return const <Map<String, dynamic>>[];
    }

    if (value is! List) {
      throw FormatException('Field \"$key\" must be an array.');
    }

    return value
        .map((item) {
          if (item is! Map) {
            throw FormatException('Field \"$key\" must contain only objects.');
          }
          return item.map((k, v) => MapEntry(k.toString(), v));
        })
        .toList(growable: false);
  }

  List<int> _decodeBase64Field(dynamic value, {required String fieldName}) {
    if (value is! String || value.isEmpty) {
      throw FormatException('Field \"$fieldName\" must be a non-empty string.');
    }
    try {
      return base64Decode(value);
    } catch (_) {
      throw FormatException('Field \"$fieldName\" is not valid base64.');
    }
  }

  String _requiredString(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is String && value.isNotEmpty) {
      return value;
    }
    throw FormatException('Missing or invalid \"$key\" field.');
  }

  String? _nullableString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  int? _nullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0;
    }
    return 0;
  }

  double? _nullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.trim().toLowerCase();
      return lower == 'true' || lower == '1' || lower == 'yes';
    }
    return false;
  }

  DateTime _requiredDate(Map<String, dynamic> map, String key) {
    final value = map[key];
    final date = _nullableDate(value);
    if (date != null) {
      return date;
    }
    throw FormatException('Missing or invalid \"$key\" date field.');
  }

  DateTime? _nullableDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  List<String>? _nullableStringList(dynamic value) {
    if (value == null) return null;
    if (value is! List) return null;

    final result = <String>[];
    for (final item in value) {
      if (item == null) {
        continue;
      }
      result.add(item.toString());
    }
    return result;
  }
}

class _FinanceSnapshot {
  final List<Transaction> transactions;
  final List<TransactionCategory> transactionCategories;
  final List<TransactionTemplate> transactionTemplates;
  final List<Budget> budgets;
  final List<Account> accounts;
  final List<DailyBalance> dailyBalances;
  final List<DebtCategory> debtCategories;
  final List<Debt> debts;
  final List<BillCategory> billCategories;
  final List<Bill> bills;
  final List<SavingsGoal> savingsGoals;

  const _FinanceSnapshot({
    required this.transactions,
    required this.transactionCategories,
    required this.transactionTemplates,
    required this.budgets,
    required this.accounts,
    required this.dailyBalances,
    required this.debtCategories,
    required this.debts,
    required this.billCategories,
    required this.bills,
    required this.savingsGoals,
  });

  FinanceBackupSummary get summary => FinanceBackupSummary(
    transactions: transactions.length,
    transactionCategories: transactionCategories.length,
    transactionTemplates: transactionTemplates.length,
    budgets: budgets.length,
    accounts: accounts.length,
    dailyBalances: dailyBalances.length,
    debtCategories: debtCategories.length,
    debts: debts.length,
    billCategories: billCategories.length,
    bills: bills.length,
    savingsGoals: savingsGoals.length,
  );
}

class _FinanceBoxes {
  final Box<Transaction> transactions;
  final Box<TransactionCategory> transactionCategories;
  final Box<TransactionTemplate> transactionTemplates;
  final Box<Budget> budgets;
  final Box<Account> accounts;
  final Box<DailyBalance> dailyBalances;
  final Box<DebtCategory> debtCategories;
  final Box<Debt> debts;
  final Box<BillCategory> billCategories;
  final Box<Bill> bills;
  final Box<SavingsGoal> savingsGoals;

  const _FinanceBoxes({
    required this.transactions,
    required this.transactionCategories,
    required this.transactionTemplates,
    required this.budgets,
    required this.accounts,
    required this.dailyBalances,
    required this.debtCategories,
    required this.debts,
    required this.billCategories,
    required this.bills,
    required this.savingsGoals,
  });
}
