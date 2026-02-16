import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/data/history_optimization_models.dart';
import '../../../../data/local/hive/hive_service.dart';
import '../models/transaction.dart';

/// Repository for transaction CRUD operations using encrypted Hive.
class TransactionRepository {
  static const String boxName = 'transactionsBox';
  static const String _dateIndexBoxName = 'finance_tx_date_index_v1';
  static const String _dailySummaryBoxName = 'finance_daily_summary_v1';
  static const String _indexMetaBoxName = 'finance_tx_index_meta_v1';
  static const String _rebuildNeededMetaKey = 'rebuild_needed';
  static const String _indexedFromMetaKey = 'indexed_from_date_key';
  static const String _oldestDataMetaKey = 'oldest_data_date_key';
  static const String _lastIndexedMetaKey = 'last_indexed_date_key';
  static const String _backfillCompleteMetaKey = 'backfill_complete';
  static const String _backfillPausedMetaKey = 'backfill_paused';
  static const String _summaryKeySeparator = '|';
  static const String _nullCurrencyToken = '__NULL_CURRENCY__';
  static const int _bootstrapWindowDays = 30;
  static const int _defaultBackfillChunkDays = 30;
  static const int _sessionScanYieldInterval = 450;
  static const int _indexVersion = 1;

  final Future<Box<Transaction>> Function()? _transactionBoxOpener;
  final Future<Box<dynamic>> Function(String boxName)? _dynamicBoxOpener;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> payload)?
  _chunkAggregationRunner;

  Box<Transaction>? _cachedBox;
  Box<dynamic>? _dateIndexBox;
  Box<dynamic>? _dailySummaryBox;
  Box<dynamic>? _indexMetaBox;

  bool _indexesReady = false;
  bool _integrityChecked = false;
  bool _useIndexedReads = true;
  bool _backfillComplete = false;
  DateTime? _indexedFromDate;

  TransactionRepository({
    Future<Box<Transaction>> Function()? transactionBoxOpener,
    Future<Box<dynamic>> Function(String boxName)? dynamicBoxOpener,
    Future<Map<String, dynamic>> Function(Map<String, dynamic> payload)?
    chunkAggregationRunner,
  }) : _transactionBoxOpener = transactionBoxOpener,
       _dynamicBoxOpener = dynamicBoxOpener,
       _chunkAggregationRunner = chunkAggregationRunner;

  Future<Box<Transaction>> _getBox() async {
    if (_cachedBox != null && _cachedBox!.isOpen) {
      return _cachedBox!;
    }
    final opener = _transactionBoxOpener;
    if (opener != null) {
      _cachedBox = await opener();
      return _cachedBox!;
    }
    _cachedBox = await HiveService.getBox<Transaction>(boxName);
    return _cachedBox!;
  }

  Future<void> createTransaction(Transaction transaction) async {
    await _ensureIndexesReady();
    final box = await _getBox();
    await box.put(transaction.id, transaction);
    await _addTransactionToIndexes(transaction);
  }

  Future<List<Transaction>> getAllTransactions() async {
    final box = await _getBox();
    return box.values.toList();
  }

  Future<Transaction?> getTransactionById(String id) async {
    final box = await _getBox();
    return box.get(id);
  }

  Future<void> updateTransaction(Transaction transaction) async {
    await _ensureIndexesReady();
    final box = await _getBox();
    final previous = box.get(transaction.id);
    transaction.updatedAt = DateTime.now();
    await box.put(transaction.id, transaction);
    if (previous != null) {
      await _removeTransactionFromIndexes(previous);
    }
    await _addTransactionToIndexes(transaction);
  }

  Future<void> deleteTransaction(String id) async {
    await _ensureIndexesReady();
    final box = await _getBox();
    final existing = box.get(id);
    await box.delete(id);
    if (existing != null) {
      await _removeTransactionFromIndexes(existing);
    }
  }

  Future<List<Transaction>> getTransactionsByType(String type) async {
    final allTransactions = await getAllTransactions();
    return allTransactions.where((t) => t.type == type).toList();
  }

  Future<List<Transaction>> getTransactionsForDate(DateTime date) async {
    await _ensureIndexesReady();
    final box = await _getBox();
    if (!_useIndexedReads || !_isDateWithinIndexedRange(date)) {
      return _scanTransactionsForDate(box.values, date);
    }

    final ids = _readStringList((await _getDateIndexBox()).get(_dateKey(date)));
    final transactions = <Transaction>[];
    for (final id in ids) {
      final transaction = box.get(id);
      if (transaction == null) continue;
      if (_isSameDate(transaction.transactionDate, date)) {
        transactions.add(transaction);
      }
    }
    return transactions;
  }

  Future<List<Transaction>> getTransactionsInRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    await _ensureIndexesReady();
    final startOnly = _dateOnly(startDate);
    final endOnly = _dateOnly(endDate);
    if (endOnly.isBefore(startOnly)) {
      return const <Transaction>[];
    }

    final box = await _getBox();
    if (!_useIndexedReads) {
      return _scanTransactionsInRange(box.values, startOnly, endOnly);
    }

    if (!_isRangeFullyIndexed(startOnly, endOnly)) {
      final indexedFrom = _indexedFromDate;
      if (indexedFrom == null) {
        return _scanTransactionsInRange(box.values, startOnly, endOnly);
      }

      final out = <Transaction>[];
      if (startOnly.isBefore(indexedFrom)) {
        final dayBeforeIndexed = indexedFrom.subtract(const Duration(days: 1));
        final olderEnd = endOnly.isBefore(dayBeforeIndexed)
            ? endOnly
            : dayBeforeIndexed;
        out.addAll(_scanTransactionsInRange(box.values, startOnly, olderEnd));
      }

      if (!endOnly.isBefore(indexedFrom)) {
        final indexedStart = startOnly.isBefore(indexedFrom)
            ? indexedFrom
            : startOnly;
        out.addAll(await _readIndexedRange(indexedStart, endOnly));
      }
      return out;
    }

    return _readIndexedRange(startOnly, endOnly);
  }

  Future<List<Transaction>> getTransactionsUpToDate(DateTime date) async {
    await _ensureIndexesReady();
    final endOnly = _dateOnly(date);
    final box = await _getBox();
    if (!_useIndexedReads || !_backfillComplete) {
      return _scanTransactionsUpToDate(box.values, endOnly);
    }

    final meta = await _getIndexMetaBox();
    final oldestDate = _parseDateKey('${meta.get(_oldestDataMetaKey)}');
    if (oldestDate == null) {
      return _scanTransactionsUpToDate(box.values, endOnly);
    }
    return _readIndexedRange(oldestDate, endOnly);
  }

  Future<List<Transaction>> getTransactionsByCategory(String categoryId) async {
    final allTransactions = await getAllTransactions();
    return allTransactions.where((t) => t.categoryId == categoryId).toList();
  }

  Future<List<Transaction>> getTransactionsByAccount(String accountId) async {
    final allTransactions = await getAllTransactions();
    return allTransactions
        .where((t) => t.accountId == accountId || t.toAccountId == accountId)
        .toList();
  }

  Future<List<Transaction>> searchTransactions(String query) async {
    final allTransactions = await getAllTransactions();
    final lowerQuery = query.toLowerCase();
    return allTransactions.where((t) {
      return t.title.toLowerCase().contains(lowerQuery) ||
          (t.description != null &&
              t.description!.toLowerCase().contains(lowerQuery)) ||
          (t.notes != null && t.notes!.toLowerCase().contains(lowerQuery));
    }).toList();
  }

  Future<List<Transaction>> getTransactionsNeedingReview() async {
    final allTransactions = await getAllTransactions();
    return allTransactions.where((t) => t.needsReview).toList();
  }

  Future<List<Transaction>> getUnclearedTransactions() async {
    final allTransactions = await getAllTransactions();
    return allTransactions.where((t) => !t.isCleared).toList();
  }

  Future<Map<String, dynamic>> getTransactionStatistics({
    required String defaultCurrency,
  }) async {
    await _ensureIndexesReady();
    if (!_useIndexedReads || !_backfillComplete) {
      return _buildStatisticsFromTransactions(
        transactions: await getAllTransactions(),
        defaultCurrency: defaultCurrency,
      );
    }

    final totalIncomeByCurrency = <String, double>{};
    final totalExpenseByCurrency = <String, double>{};

    var total = 0;
    var income = 0;
    var expense = 0;
    var transfer = 0;
    var needsReview = 0;
    var uncleared = 0;

    final summaryBox = await _getDailySummaryBox();
    for (final entry in summaryBox.toMap().entries) {
      final key = '${entry.key}';
      final currency = _currencyFromSummaryKey(
        summaryKey: key,
        defaultCurrency: defaultCurrency,
      );
      if (currency == null) continue;

      final summary = _readSummaryMap(entry.value);
      total += _asInt(summary['total_count']);
      income += _asInt(summary['income_count']);
      expense += _asInt(summary['expense_count']);
      transfer += _asInt(summary['transfer_count']);
      needsReview += _asInt(summary['needs_review_count']);
      uncleared += _asInt(summary['uncleared_count']);

      final incomeAmount = _asDouble(summary['income_amount']);
      if (incomeAmount != 0 || totalIncomeByCurrency.containsKey(currency)) {
        totalIncomeByCurrency[currency] =
            (totalIncomeByCurrency[currency] ?? 0) + incomeAmount;
      }

      final expenseAmount = _asDouble(summary['expense_amount']);
      if (expenseAmount != 0 || totalExpenseByCurrency.containsKey(currency)) {
        totalExpenseByCurrency[currency] =
            (totalExpenseByCurrency[currency] ?? 0) + expenseAmount;
      }
    }

    return <String, dynamic>{
      'total': total,
      'income': income,
      'expense': expense,
      'transfer': transfer,
      'totalIncomeByCurrency': totalIncomeByCurrency,
      'totalExpenseByCurrency': totalExpenseByCurrency,
      'needsReview': needsReview,
      'uncleared': uncleared,
    };
  }

  Future<void> deleteAllTransactions() async {
    await _ensureIndexesReady();
    final box = await _getBox();
    await box.clear();
    await (await _getDateIndexBox()).clear();
    await (await _getDailySummaryBox()).clear();

    final meta = await _getIndexMetaBox();
    final today = _dateOnly(DateTime.now());
    await meta.put('version', _indexVersion);
    await meta.put(_indexedFromMetaKey, _dateKey(today));
    await meta.put(_oldestDataMetaKey, _dateKey(today));
    await meta.put(_lastIndexedMetaKey, _dateKey(today));
    await meta.put(_backfillCompleteMetaKey, true);
    await meta.put(_backfillPausedMetaKey, false);
    await meta.delete(_rebuildNeededMetaKey);

    _indexedFromDate = today;
    _backfillComplete = true;
    _useIndexedReads = true;
  }

  Future<void> setBackfillPaused(bool paused) async {
    await _ensureIndexesReady();
    await (await _getIndexMetaBox()).put(_backfillPausedMetaKey, paused);
  }

  Future<ModuleHistoryOptimizationStatus> getHistoryOptimizationStatus() async {
    await _ensureIndexesReady();
    final meta = await _getIndexMetaBox();
    return ModuleHistoryOptimizationStatus(
      moduleId: 'finance',
      ready: _indexesReady,
      usingScanFallback: !_useIndexedReads,
      backfillComplete: meta.get(_backfillCompleteMetaKey) == true,
      paused: meta.get(_backfillPausedMetaKey) == true,
      indexedFromDateKey: meta.get(_indexedFromMetaKey) as String?,
      oldestDataDateKey: meta.get(_oldestDataMetaKey) as String?,
      lastIndexedDateKey: meta.get(_lastIndexedMetaKey) as String?,
      bootstrapWindowDays: _bootstrapWindowDays,
    );
  }

  Future<bool> backfillNextChunk({
    int chunkDays = _defaultBackfillChunkDays,
  }) async {
    await _ensureIndexesReady();
    if (!_useIndexedReads) return false;

    final meta = await _getIndexMetaBox();
    if (meta.get(_backfillPausedMetaKey) == true) {
      return false;
    }
    if (meta.get(_backfillCompleteMetaKey) == true) {
      return false;
    }

    final indexedFrom = _parseDateKey('${meta.get(_indexedFromMetaKey)}');
    final oldestData = _parseDateKey('${meta.get(_oldestDataMetaKey)}');
    if (indexedFrom == null || oldestData == null) {
      await meta.put(_rebuildNeededMetaKey, true);
      return false;
    }
    if (!indexedFrom.isAfter(oldestData)) {
      await meta.put(_backfillCompleteMetaKey, true);
      _backfillComplete = true;
      return false;
    }

    final chunkEnd = indexedFrom.subtract(const Duration(days: 1));
    final chunkStartCandidate = chunkEnd.subtract(
      Duration(days: chunkDays - 1),
    );
    final chunkStart = chunkStartCandidate.isBefore(oldestData)
        ? oldestData
        : chunkStartCandidate;

    final aggregated = await _runBackfillChunkAggregation(chunkStart, chunkEnd);
    final indexRaw = aggregated['indexMap'] as Map<String, dynamic>? ?? {};
    final summaryRaw = aggregated['summaryMap'] as Map<String, dynamic>? ?? {};

    final indexMap = <String, List<String>>{};
    final summaryMap = <String, Map<String, dynamic>>{};

    for (final entry in indexRaw.entries) {
      indexMap[entry.key] = (entry.value as List).map((e) => '$e').toList();
    }
    for (final entry in summaryRaw.entries) {
      summaryMap[entry.key] = _readSummaryMap(entry.value);
    }

    if (indexMap.isNotEmpty) {
      await (await _getDateIndexBox()).putAll(indexMap);
    }
    if (summaryMap.isNotEmpty) {
      await (await _getDailySummaryBox()).putAll(summaryMap);
    }

    final newIndexedFrom = chunkStart;
    final isComplete = !newIndexedFrom.isAfter(oldestData);
    await meta.put(_indexedFromMetaKey, _dateKey(newIndexedFrom));
    await meta.put(_lastIndexedMetaKey, _dateKey(newIndexedFrom));
    await meta.put(_backfillCompleteMetaKey, isComplete);
    _indexedFromDate = newIndexedFrom;
    _backfillComplete = isComplete;
    return true;
  }

  Future<Map<String, dynamic>> _runBackfillChunkAggregation(
    DateTime chunkStart,
    DateTime chunkEnd,
  ) async {
    final customRunner = _chunkAggregationRunner;
    if (customRunner != null) {
      return customRunner(<String, dynamic>{
        'chunkStartDateKey': _dateKey(chunkStart),
        'chunkEndDateKey': _dateKey(chunkEnd),
      });
    }

    if (!HiveService.isInitialized) {
      final entries = await _scanChunkEntries(chunkStart, chunkEnd);
      return _aggregateFinanceEntries(
        entries: entries,
        summaryKeySeparator: _summaryKeySeparator,
        nullCurrencyToken: _nullCurrencyToken,
      );
    }

    final openConfig = HiveService.getIsolateOpenConfig();
    final payload = <String, dynamic>{
      'hiveDirPath': openConfig['hiveDirPath'],
      'cipherKeyBytes': openConfig['cipherKeyBytes'],
      'boxName': boxName,
      'chunkStartDateKey': _dateKey(chunkStart),
      'chunkEndDateKey': _dateKey(chunkEnd),
      'summaryKeySeparator': _summaryKeySeparator,
      'nullCurrencyToken': _nullCurrencyToken,
    };

    return Isolate.run<Map<String, dynamic>>(
      () => _aggregateFinanceChunkWorker(payload),
    );
  }

  Future<Box<dynamic>> _getDateIndexBox() async {
    if (_dateIndexBox != null && _dateIndexBox!.isOpen) {
      return _dateIndexBox!;
    }
    _dateIndexBox = await _openDynamicBox(_dateIndexBoxName);
    return _dateIndexBox!;
  }

  Future<Box<dynamic>> _getDailySummaryBox() async {
    if (_dailySummaryBox != null && _dailySummaryBox!.isOpen) {
      return _dailySummaryBox!;
    }
    _dailySummaryBox = await _openDynamicBox(_dailySummaryBoxName);
    return _dailySummaryBox!;
  }

  Future<Box<dynamic>> _getIndexMetaBox() async {
    if (_indexMetaBox != null && _indexMetaBox!.isOpen) {
      return _indexMetaBox!;
    }
    _indexMetaBox = await _openDynamicBox(_indexMetaBoxName);
    return _indexMetaBox!;
  }

  Future<Box<dynamic>> _openDynamicBox(String boxName) async {
    final opener = _dynamicBoxOpener;
    if (opener != null) {
      return opener(boxName);
    }
    return HiveService.getBox<dynamic>(boxName);
  }

  Future<void> _ensureIndexesReady() async {
    if (_indexesReady) return;
    final meta = await _getIndexMetaBox();
    final version = _asInt(meta.get('version'));
    final rebuildNeeded = meta.get(_rebuildNeededMetaKey) == true;
    final hasBootstrapWindow =
        meta.get(_indexedFromMetaKey) is String &&
        meta.get(_oldestDataMetaKey) is String;
    var attemptedRebuild = false;

    if (version != _indexVersion || rebuildNeeded || !hasBootstrapWindow) {
      final reason = version != _indexVersion
          ? 'version_mismatch'
          : rebuildNeeded
          ? 'rebuild_needed_flag'
          : 'missing_bootstrap_window';
      await _bootstrapRecentWindowIndexes(reason: reason);
      await meta.put('version', _indexVersion);
      attemptedRebuild = true;
    }

    if (!_integrityChecked) {
      var valid = await _hasValidIndexes();
      if (!valid && !attemptedRebuild) {
        await _bootstrapRecentWindowIndexes(reason: 'integrity_mismatch');
        await meta.put('version', _indexVersion);
        valid = await _hasValidIndexes();
      }

      if (!valid) {
        _useIndexedReads = false;
        await meta.put(_rebuildNeededMetaKey, true);
        _debugLog(
          'Index mismatch persisted after rebuild; falling back to scan mode for this session.',
        );
      } else {
        _useIndexedReads = true;
        await meta.delete(_rebuildNeededMetaKey);
      }
      _indexedFromDate = _parseDateKey('${meta.get(_indexedFromMetaKey)}');
      _backfillComplete = meta.get(_backfillCompleteMetaKey) == true;
      _integrityChecked = true;
    }

    _indexesReady = true;
  }

  Future<bool> _hasValidIndexes() async {
    final box = await _getBox();
    if (box.isEmpty) return true;

    final indexedFrom =
        _indexedFromDate ??
        _parseDateKey('${(await _getIndexMetaBox()).get(_indexedFromMetaKey)}');
    if (indexedFrom == null) {
      return false;
    }

    var expectedCount = 0;
    for (final transaction in box.values) {
      if (!_isDateBefore(transaction.transactionDate, indexedFrom)) {
        expectedCount++;
      }
    }

    var indexedCount = 0;
    for (final value in (await _getDateIndexBox()).values) {
      indexedCount += _readStringList(value).length;
    }
    if (indexedCount != expectedCount) {
      return false;
    }

    var summarizedTotal = 0;
    for (final value in (await _getDailySummaryBox()).values) {
      summarizedTotal += _asInt(_readSummaryMap(value)['total_count']);
    }
    return summarizedTotal == expectedCount;
  }

  Future<void> _bootstrapRecentWindowIndexes({required String reason}) async {
    final box = await _getBox();
    final recordCount = box.length;
    final stopwatch = Stopwatch()..start();
    final indexBox = await _getDateIndexBox();
    final summaryBox = await _getDailySummaryBox();
    final meta = await _getIndexMetaBox();

    await indexBox.clear();
    await summaryBox.clear();

    final indexMap = <String, List<String>>{};
    final summaryMap = <String, Map<String, dynamic>>{};
    final now = _dateOnly(DateTime.now());
    final bootstrapFrom = now.subtract(
      const Duration(days: _bootstrapWindowDays - 1),
    );
    DateTime? oldestData;
    var scanned = 0;

    for (final transaction in box.values) {
      scanned++;
      if (scanned % _sessionScanYieldInterval == 0) {
        await Future<void>.delayed(Duration.zero);
      }

      final txDate = _dateOnly(transaction.transactionDate);
      if (oldestData == null || txDate.isBefore(oldestData)) {
        oldestData = txDate;
      }
      if (_isDateBefore(txDate, bootstrapFrom)) {
        continue;
      }

      final dateKey = _dateKey(txDate);
      indexMap.putIfAbsent(dateKey, () => <String>[]).add(transaction.id);
      final summaryKey = _summaryKey(
        dateKey,
        _currencyTokenForSummary(transaction),
      );
      final summary = summaryMap.putIfAbsent(summaryKey, _newSummaryMap);
      _applyTransactionDelta(summary, transaction, 1);
    }

    if (indexMap.isNotEmpty) {
      await indexBox.putAll(indexMap);
    }
    if (summaryMap.isNotEmpty) {
      await summaryBox.putAll(summaryMap);
    }

    final indexedFrom = oldestData == null || oldestData.isAfter(bootstrapFrom)
        ? (oldestData ?? now)
        : bootstrapFrom;
    final backfillComplete =
        oldestData == null || !indexedFrom.isAfter(oldestData);
    await meta.put(_indexedFromMetaKey, _dateKey(indexedFrom));
    await meta.put(_oldestDataMetaKey, _dateKey(oldestData ?? indexedFrom));
    await meta.put(_lastIndexedMetaKey, _dateKey(indexedFrom));
    await meta.put(_backfillCompleteMetaKey, backfillComplete);
    await meta.put(_backfillPausedMetaKey, false);
    await meta.delete(_rebuildNeededMetaKey);

    _indexedFromDate = indexedFrom;
    _backfillComplete = backfillComplete;
    _useIndexedReads = true;

    stopwatch.stop();
    _debugLog(
      'Index rebuild finished. reason=$reason records=$recordCount durationMs=${stopwatch.elapsedMilliseconds}',
    );
  }

  Future<void> _addTransactionToIndexes(Transaction transaction) async {
    if (!_useIndexedReads ||
        !_isDateWithinIndexedRange(transaction.transactionDate)) {
      await _markBackfillNeededForDate(transaction.transactionDate);
      return;
    }

    final dateKey = _dateKey(transaction.transactionDate);
    final indexBox = await _getDateIndexBox();
    final ids = _readStringList(indexBox.get(dateKey));
    if (!ids.contains(transaction.id)) {
      ids.add(transaction.id);
      await indexBox.put(dateKey, ids);
    }

    final summaryKey = _summaryKey(
      dateKey,
      _currencyTokenForSummary(transaction),
    );
    final summaryBox = await _getDailySummaryBox();
    final summary = _readSummaryMap(summaryBox.get(summaryKey));
    _applyTransactionDelta(summary, transaction, 1);
    await _writeOrDeleteSummary(summaryBox, summaryKey, summary);
  }

  Future<void> _removeTransactionFromIndexes(Transaction transaction) async {
    if (!_useIndexedReads ||
        !_isDateWithinIndexedRange(transaction.transactionDate)) {
      return;
    }

    final dateKey = _dateKey(transaction.transactionDate);
    final indexBox = await _getDateIndexBox();
    final ids = _readStringList(indexBox.get(dateKey));
    ids.remove(transaction.id);
    if (ids.isEmpty) {
      await indexBox.delete(dateKey);
    } else {
      await indexBox.put(dateKey, ids);
    }

    final summaryKey = _summaryKey(
      dateKey,
      _currencyTokenForSummary(transaction),
    );
    final summaryBox = await _getDailySummaryBox();
    final summary = _readSummaryMap(summaryBox.get(summaryKey));
    _applyTransactionDelta(summary, transaction, -1);
    await _writeOrDeleteSummary(summaryBox, summaryKey, summary);
  }

  Future<void> _writeOrDeleteSummary(
    Box<dynamic> summaryBox,
    String key,
    Map<String, dynamic> summary,
  ) async {
    if (_asInt(summary['total_count']) <= 0) {
      await summaryBox.delete(key);
      return;
    }
    await summaryBox.put(key, summary);
  }

  List<String> _readStringList(dynamic value) {
    if (value is List) {
      return value.map((e) => '$e').toList();
    }
    return <String>[];
  }

  Map<String, dynamic> _newSummaryMap() {
    return <String, dynamic>{
      'total_count': 0,
      'income_count': 0,
      'expense_count': 0,
      'transfer_count': 0,
      'needs_review_count': 0,
      'uncleared_count': 0,
      'income_amount': 0.0,
      'expense_amount': 0.0,
    };
  }

  Map<String, dynamic> _readSummaryMap(dynamic value) {
    if (value is! Map) {
      return _newSummaryMap();
    }
    return <String, dynamic>{
      'total_count': _asInt(value['total_count']),
      'income_count': _asInt(value['income_count']),
      'expense_count': _asInt(value['expense_count']),
      'transfer_count': _asInt(value['transfer_count']),
      'needs_review_count': _asInt(value['needs_review_count']),
      'uncleared_count': _asInt(value['uncleared_count']),
      'income_amount': _asDouble(value['income_amount']),
      'expense_amount': _asDouble(value['expense_amount']),
    };
  }

  void _applyTransactionDelta(
    Map<String, dynamic> summary,
    Transaction transaction,
    int delta,
  ) {
    summary['total_count'] = _asInt(summary['total_count']) + delta;
    if (transaction.needsReview) {
      summary['needs_review_count'] =
          _asInt(summary['needs_review_count']) + delta;
    }
    if (!transaction.isCleared) {
      summary['uncleared_count'] = _asInt(summary['uncleared_count']) + delta;
    }

    final amountDelta = transaction.amount * delta.toDouble();
    if (transaction.isIncome && !transaction.isBalanceAdjustment) {
      summary['income_count'] = _asInt(summary['income_count']) + delta;
      summary['income_amount'] =
          _asDouble(summary['income_amount']) + amountDelta;
    } else if (transaction.isExpense && !transaction.isBalanceAdjustment) {
      summary['expense_count'] = _asInt(summary['expense_count']) + delta;
      summary['expense_amount'] =
          _asDouble(summary['expense_amount']) + amountDelta;
    } else if (transaction.isTransfer) {
      summary['transfer_count'] = _asInt(summary['transfer_count']) + delta;
    }

    summary['total_count'] = _nonNegativeInt(summary['total_count']);
    summary['income_count'] = _nonNegativeInt(summary['income_count']);
    summary['expense_count'] = _nonNegativeInt(summary['expense_count']);
    summary['transfer_count'] = _nonNegativeInt(summary['transfer_count']);
    summary['needs_review_count'] = _nonNegativeInt(
      summary['needs_review_count'],
    );
    summary['uncleared_count'] = _nonNegativeInt(summary['uncleared_count']);
    summary['income_amount'] = _nonNegativeDouble(summary['income_amount']);
    summary['expense_amount'] = _nonNegativeDouble(summary['expense_amount']);
  }

  Future<Map<String, dynamic>> _buildStatisticsFromTransactions({
    required Iterable<Transaction> transactions,
    required String defaultCurrency,
  }) async {
    final income = transactions.where(
      (t) => t.isIncome && !t.isBalanceAdjustment,
    );
    final expenses = transactions.where(
      (t) => t.isExpense && !t.isBalanceAdjustment,
    );

    final totalIncomeByCurrency = <String, double>{};
    final totalExpenseByCurrency = <String, double>{};
    for (final transaction in income) {
      final currency = transaction.currency ?? defaultCurrency;
      totalIncomeByCurrency[currency] =
          (totalIncomeByCurrency[currency] ?? 0) + transaction.amount;
    }
    for (final transaction in expenses) {
      final currency = transaction.currency ?? defaultCurrency;
      totalExpenseByCurrency[currency] =
          (totalExpenseByCurrency[currency] ?? 0) + transaction.amount;
    }

    return <String, dynamic>{
      'total': transactions.length,
      'income': income.length,
      'expense': expenses.length,
      'transfer': transactions.where((t) => t.isTransfer).length,
      'totalIncomeByCurrency': totalIncomeByCurrency,
      'totalExpenseByCurrency': totalExpenseByCurrency,
      'needsReview': transactions.where((t) => t.needsReview).length,
      'uncleared': transactions.where((t) => !t.isCleared).length,
    };
  }

  String _currencyTokenForSummary(Transaction transaction) {
    final currency = transaction.currency?.trim();
    if (currency == null || currency.isEmpty) {
      return _nullCurrencyToken;
    }
    return currency;
  }

  String _summaryKey(String dateKey, String currencyToken) {
    return '$dateKey$_summaryKeySeparator$currencyToken';
  }

  String? _currencyFromSummaryKey({
    required String summaryKey,
    required String defaultCurrency,
  }) {
    final separatorIndex = summaryKey.indexOf(_summaryKeySeparator);
    if (separatorIndex <= 0 || separatorIndex >= summaryKey.length - 1) {
      return null;
    }
    final token = summaryKey.substring(separatorIndex + 1);
    if (token == _nullCurrencyToken) {
      return defaultCurrency;
    }
    return token;
  }

  bool _isDateWithinIndexedRange(DateTime date) {
    final indexedFrom = _indexedFromDate;
    if (indexedFrom == null) return false;
    return !_isDateBefore(date, indexedFrom);
  }

  bool _isRangeFullyIndexed(DateTime startDate, DateTime endDate) {
    final indexedFrom = _indexedFromDate;
    if (indexedFrom == null) return false;
    return !_isDateBefore(startDate, indexedFrom);
  }

  Future<List<Transaction>> _readIndexedRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final indexBox = await _getDateIndexBox();
    final txBox = await _getBox();
    final out = <Transaction>[];

    var day = _dateOnly(startDate);
    final end = _dateOnly(endDate);
    while (!day.isAfter(end)) {
      final ids = _readStringList(indexBox.get(_dateKey(day)));
      for (final id in ids) {
        final transaction = txBox.get(id);
        if (transaction == null) continue;
        if (_isSameDate(transaction.transactionDate, day)) {
          out.add(transaction);
        }
      }
      day = day.add(const Duration(days: 1));
    }
    return out;
  }

  List<Transaction> _scanTransactionsForDate(
    Iterable<Transaction> transactions,
    DateTime date,
  ) {
    return transactions
        .where((t) => _isSameDate(t.transactionDate, date))
        .toList();
  }

  List<Transaction> _scanTransactionsInRange(
    Iterable<Transaction> transactions,
    DateTime startDate,
    DateTime endDate,
  ) {
    final start = _dateOnly(startDate);
    final end = _dateOnly(endDate);
    return transactions.where((transaction) {
      final txDate = _dateOnly(transaction.transactionDate);
      return !_isDateBefore(txDate, start) && !_isDateAfter(txDate, end);
    }).toList();
  }

  List<Transaction> _scanTransactionsUpToDate(
    Iterable<Transaction> transactions,
    DateTime date,
  ) {
    final end = _dateOnly(date);
    return transactions.where((transaction) {
      final txDate = _dateOnly(transaction.transactionDate);
      return !txDate.isAfter(end);
    }).toList();
  }

  DateTime _dateOnly(DateTime date) {
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  String _dateKey(DateTime date) {
    final d = _dateOnly(date);
    final yyyy = d.year.toString().padLeft(4, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$yyyy$mm$dd';
  }

  DateTime? _parseDateKey(String value) {
    final match = RegExp(r'^(\d{4})(\d{2})(\d{2})$').firstMatch(value);
    if (match == null) return null;
    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  bool _isSameDate(DateTime a, DateTime b) {
    final aOnly = _dateOnly(a);
    final bOnly = _dateOnly(b);
    return aOnly.year == bOnly.year &&
        aOnly.month == bOnly.month &&
        aOnly.day == bOnly.day;
  }

  bool _isDateBefore(DateTime a, DateTime b) {
    return _dateOnly(a).isBefore(_dateOnly(b));
  }

  bool _isDateAfter(DateTime a, DateTime b) {
    return _dateOnly(a).isAfter(_dateOnly(b));
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  double _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  int _nonNegativeInt(dynamic value) {
    final parsed = _asInt(value);
    return parsed < 0 ? 0 : parsed;
  }

  double _nonNegativeDouble(dynamic value) {
    final parsed = _asDouble(value);
    return parsed < 0 ? 0 : parsed;
  }

  Future<void> _markBackfillNeededForDate(DateTime date) async {
    final meta = await _getIndexMetaBox();
    final dateOnly = _dateOnly(date);
    final existingOldest = _parseDateKey('${meta.get(_oldestDataMetaKey)}');
    if (existingOldest == null || dateOnly.isBefore(existingOldest)) {
      await meta.put(_oldestDataMetaKey, _dateKey(dateOnly));
    }

    final indexedFrom =
        _indexedFromDate ?? _parseDateKey('${meta.get(_indexedFromMetaKey)}');
    if (indexedFrom != null && dateOnly.isBefore(indexedFrom)) {
      await meta.put(_backfillCompleteMetaKey, false);
      _backfillComplete = false;
    }
  }

  Future<List<Map<String, dynamic>>> _scanChunkEntries(
    DateTime chunkStart,
    DateTime chunkEnd,
  ) async {
    final start = _dateOnly(chunkStart);
    final end = _dateOnly(chunkEnd);
    final entries = <Map<String, dynamic>>[];
    var scanned = 0;
    for (final transaction in (await _getBox()).values) {
      scanned++;
      if (scanned % _sessionScanYieldInterval == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      final txDate = _dateOnly(transaction.transactionDate);
      if (_isDateBefore(txDate, start) || _isDateAfter(txDate, end)) {
        continue;
      }
      entries.add(<String, dynamic>{
        'id': transaction.id,
        'dateKey': _dateKey(txDate),
        'currencyToken': _currencyTokenForSummary(transaction),
        'type': transaction.type,
        'amount': transaction.amount,
        'isBalanceAdjustment': transaction.isBalanceAdjustment,
        'needsReview': transaction.needsReview,
        'isCleared': transaction.isCleared,
      });
    }
    return entries;
  }

  void _debugLog(String message) {
    if (!kDebugMode) return;
    debugPrint('[TransactionRepository] $message');
  }
}

Future<Map<String, dynamic>> _aggregateFinanceChunkWorker(
  Map<String, dynamic> payload,
) async {
  final hiveDirPath = '${payload['hiveDirPath'] ?? ''}';
  final cipherKey =
      (payload['cipherKeyBytes'] as List?)?.cast<int>() ?? <int>[];
  final boxName = '${payload['boxName'] ?? ''}';
  final startDateKey = '${payload['chunkStartDateKey'] ?? ''}';
  final endDateKey = '${payload['chunkEndDateKey'] ?? ''}';
  final summaryKeySeparator = '${payload['summaryKeySeparator'] ?? '|'}';
  final nullCurrencyToken =
      '${payload['nullCurrencyToken'] ?? '__NULL_CURRENCY__'}';

  if (hiveDirPath.isEmpty ||
      cipherKey.isEmpty ||
      boxName.isEmpty ||
      startDateKey.length != 8 ||
      endDateKey.length != 8) {
    return <String, dynamic>{
      'indexMap': <String, List<String>>{},
      'summaryMap': <String, Map<String, dynamic>>{},
    };
  }

  final box = await HiveService.openIsolateBoxWithCipher<Transaction>(
    hiveDirPath: hiveDirPath,
    boxName: boxName,
    cipherKeyBytes: cipherKey,
    registerAdapters: () {
      if (!Hive.isAdapterRegistered(20)) {
        Hive.registerAdapter(TransactionAdapter());
      }
    },
  );

  final start = _parseWorkerDateKey(startDateKey);
  final end = _parseWorkerDateKey(endDateKey);
  if (start == null || end == null || end.isBefore(start)) {
    await box.close();
    await Hive.close();
    return <String, dynamic>{
      'indexMap': <String, List<String>>{},
      'summaryMap': <String, Map<String, dynamic>>{},
    };
  }

  final entries = <Map<String, dynamic>>[];
  for (final transaction in box.values) {
    final txDate = _workerDateOnly(transaction.transactionDate);
    if (txDate.isBefore(start) || txDate.isAfter(end)) {
      continue;
    }
    entries.add(<String, dynamic>{
      'id': transaction.id,
      'dateKey': _workerDateKey(txDate),
      'currencyToken': _workerCurrencyToken(
        transaction.currency,
        nullCurrencyToken,
      ),
      'type': transaction.type,
      'amount': transaction.amount,
      'isBalanceAdjustment': transaction.isBalanceAdjustment,
      'needsReview': transaction.needsReview,
      'isCleared': transaction.isCleared,
    });
  }

  await box.close();
  await Hive.close();
  return _aggregateFinanceEntries(
    entries: entries,
    summaryKeySeparator: summaryKeySeparator,
    nullCurrencyToken: nullCurrencyToken,
  );
}

Map<String, dynamic> _aggregateFinanceEntries({
  required List<Map<String, dynamic>> entries,
  required String summaryKeySeparator,
  required String nullCurrencyToken,
}) {
  final indexMap = <String, List<String>>{};
  final summaryMap = <String, Map<String, dynamic>>{};

  for (final entry in entries) {
    final id = '${entry['id'] ?? ''}';
    final dateKey = '${entry['dateKey'] ?? ''}';
    final currencyToken = '${entry['currencyToken'] ?? nullCurrencyToken}';
    final type = '${entry['type'] ?? ''}';
    final amount = _workerAsDouble(entry['amount']);
    final isBalanceAdjustment = entry['isBalanceAdjustment'] == true;
    final needsReview = entry['needsReview'] == true;
    final isCleared = entry['isCleared'] == true;

    if (id.isEmpty || dateKey.length != 8) continue;

    indexMap.putIfAbsent(dateKey, () => <String>[]).add(id);
    final summaryKey = '$dateKey$summaryKeySeparator$currencyToken';
    final summary = summaryMap.putIfAbsent(summaryKey, () {
      return <String, dynamic>{
        'total_count': 0,
        'income_count': 0,
        'expense_count': 0,
        'transfer_count': 0,
        'needs_review_count': 0,
        'uncleared_count': 0,
        'income_amount': 0.0,
        'expense_amount': 0.0,
      };
    });

    summary['total_count'] = _workerAsInt(summary['total_count']) + 1;
    if (needsReview) {
      summary['needs_review_count'] =
          _workerAsInt(summary['needs_review_count']) + 1;
    }
    if (!isCleared) {
      summary['uncleared_count'] = _workerAsInt(summary['uncleared_count']) + 1;
    }
    if (type == 'income' && !isBalanceAdjustment) {
      summary['income_count'] = _workerAsInt(summary['income_count']) + 1;
      summary['income_amount'] =
          _workerAsDouble(summary['income_amount']) + amount;
    } else if (type == 'expense' && !isBalanceAdjustment) {
      summary['expense_count'] = _workerAsInt(summary['expense_count']) + 1;
      summary['expense_amount'] =
          _workerAsDouble(summary['expense_amount']) + amount;
    } else if (type == 'transfer') {
      summary['transfer_count'] = _workerAsInt(summary['transfer_count']) + 1;
    }
  }

  return <String, dynamic>{'indexMap': indexMap, 'summaryMap': summaryMap};
}

DateTime? _parseWorkerDateKey(String key) {
  final match = RegExp(r'^(\d{4})(\d{2})(\d{2})$').firstMatch(key);
  if (match == null) return null;
  return DateTime(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );
}

DateTime _workerDateOnly(DateTime date) {
  final local = date.toLocal();
  return DateTime(local.year, local.month, local.day);
}

String _workerDateKey(DateTime date) {
  final d = _workerDateOnly(date);
  return '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
}

String _workerCurrencyToken(String? currency, String nullToken) {
  final trimmed = currency?.trim();
  if (trimmed == null || trimmed.isEmpty) return nullToken;
  return trimmed;
}

int _workerAsInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

double _workerAsDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}
