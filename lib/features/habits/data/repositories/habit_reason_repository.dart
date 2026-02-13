import 'package:hive_flutter/hive_flutter.dart';
import '../models/habit_reason.dart';
import '../../../../data/local/hive/hive_service.dart';
import '../services/quit_habit_secure_storage_service.dart';

/// Repository for habit reason CRUD operations using Hive
class HabitReasonRepository {
  static const String boxName = 'habitReasonsBox';
  static const String secureQuitBoxName =
      QuitHabitSecureStorageService.secureReasonsBoxName;

  /// Cached box reference for performance
  Box<HabitReason>? _cachedRegularBox;
  Box<HabitReason>? _cachedSecureQuitBox;
  final QuitHabitSecureStorageService _secureStorage;

  HabitReasonRepository({QuitHabitSecureStorageService? secureStorage})
    : _secureStorage = secureStorage ?? QuitHabitSecureStorageService();

  /// Get the reasons box (lazy initialization with caching)
  Future<Box<HabitReason>> _getRegularBox() async {
    if (_cachedRegularBox != null && _cachedRegularBox!.isOpen) {
      return _cachedRegularBox!;
    }
    _cachedRegularBox = await HiveService.getBox<HabitReason>(boxName);
    return _cachedRegularBox!;
  }

  Future<Box<HabitReason>?> _getSecureQuitBoxOrNull() async {
    if (_cachedSecureQuitBox != null && _cachedSecureQuitBox!.isOpen) {
      return _cachedSecureQuitBox!;
    }
    if (!_secureStorage.isSessionUnlocked) {
      return null;
    }
    _cachedSecureQuitBox = await _secureStorage.openSecureBox<HabitReason>(
      secureQuitBoxName,
    );
    return _cachedSecureQuitBox!;
  }

  /// Create a new reason
  Future<void> createReason(HabitReason reason) async {
    if (reason.typeIndex == 2 || reason.typeIndex == 3) {
      final secureBox = await _getSecureQuitBoxOrNull();
      if (secureBox == null) {
        throw StateError('Quit secure storage is locked.');
      }
      await secureBox.put(reason.id, reason);
      return;
    }
    final box = await _getRegularBox();
    await box.put(reason.id, reason);
  }

  /// Get all reasons
  Future<List<HabitReason>> getAllReasons() async {
    final regularBox = await _getRegularBox();
    final reasons = regularBox.values.toList();
    final secureBox = await _getSecureQuitBoxOrNull();
    if (secureBox != null) {
      reasons.addAll(secureBox.values);
    }
    return reasons;
  }

  /// Get reasons by type (0 = notDone, 1 = postpone)
  Future<List<HabitReason>> getReasonsByType(int typeIndex) async {
    if (typeIndex == 2 || typeIndex == 3) {
      final secureBox = await _getSecureQuitBoxOrNull();
      if (secureBox == null) return const <HabitReason>[];
      return secureBox.values.where((r) => r.typeIndex == typeIndex).toList();
    }
    final box = await _getRegularBox();
    return box.values.where((r) => r.typeIndex == typeIndex).toList();
  }

  /// Get "Not Done" reasons
  Future<List<HabitReason>> getNotDoneReasons() async {
    return getReasonsByType(0);
  }

  /// Get "Postpone" reasons
  Future<List<HabitReason>> getPostponeReasons() async {
    return getReasonsByType(1);
  }

  /// Get "Slip" reasons (for quit bad habit - when user slipped)
  Future<List<HabitReason>> getSlipReasons() async {
    return getReasonsByType(2);
  }

  /// Get "Temptation" reasons (for quit bad habit - when user felt tempted)
  Future<List<HabitReason>> getTemptationReasons() async {
    return getReasonsByType(3);
  }

  /// Get all quit habit reasons (slip + temptation)
  Future<List<HabitReason>> getQuitReasons() async {
    final secureBox = await _getSecureQuitBoxOrNull();
    if (secureBox == null) return const <HabitReason>[];
    return secureBox.values
        .where((r) => r.typeIndex == 2 || r.typeIndex == 3)
        .toList();
  }

  /// Get reason by ID
  Future<HabitReason?> getReasonById(String id) async {
    final regularBox = await _getRegularBox();
    final regularReason = regularBox.get(id);
    if (regularReason != null) return regularReason;
    final secureBox = await _getSecureQuitBoxOrNull();
    return secureBox?.get(id);
  }

  /// Update an existing reason
  Future<void> updateReason(HabitReason reason) async {
    if (reason.typeIndex == 2 || reason.typeIndex == 3) {
      final secureBox = await _getSecureQuitBoxOrNull();
      if (secureBox == null) {
        throw StateError('Quit secure storage is locked.');
      }
      await secureBox.put(reason.id, reason);
      return;
    }
    final regularBox = await _getRegularBox();
    await regularBox.put(reason.id, reason);
  }

  /// Delete a reason
  Future<void> deleteReason(String id) async {
    final regularBox = await _getRegularBox();
    await regularBox.delete(id);
    final secureBox = await _getSecureQuitBoxOrNull();
    await secureBox?.delete(id);
  }

  /// Delete all regular reasons (non-quit)
  Future<void> deleteAllRegularReasons() async {
    final regularBox = await _getRegularBox();
    await regularBox.clear();
  }

  /// Delete all reasons (regular + quit, if secure storage unlocked)
  Future<void> deleteAllReasons() async {
    await deleteAllRegularReasons();
    final secureBox = await _getSecureQuitBoxOrNull();
    await secureBox?.clear();
  }

  /// Delete all quit reasons (slip + temptation)
  Future<void> deleteQuitReasons() async {
    final secureBox = await _getSecureQuitBoxOrNull();
    if (secureBox == null) return;
    final quitReasonIds = secureBox.values
        .where((r) => r.typeIndex == 2 || r.typeIndex == 3)
        .map((r) => r.id)
        .toList();
    for (final id in quitReasonIds) {
      await secureBox.delete(id);
    }
  }

  /// Initialize with default "Not Done" and "Postpone" reasons
  Future<void> initializeDefaults() async {
    final box = await _getRegularBox();

    // Check if we already have "Not Done" reasons
    final existingNotDone = box.values.where((r) => r.typeIndex == 0).toList();
    if (existingNotDone.isEmpty) {
      for (final reason in HabitReason.getDefaultNotDoneReasons()) {
        await box.put(reason.id, reason);
      }
    }

    // Check if we already have "Postpone" reasons
    final existingPostpone = box.values.where((r) => r.typeIndex == 1).toList();
    if (existingPostpone.isEmpty) {
      for (final reason in HabitReason.getDefaultPostponeReasons()) {
        await box.put(reason.id, reason);
      }
    }
  }

  /// Initialize default slip and temptation reasons for quit habits
  Future<void> initializeQuitDefaults() async {
    final box = await _getSecureQuitBoxOrNull();
    if (box == null) return;

    // Check if we already have slip reasons
    final existingSlip = box.values.where((r) => r.typeIndex == 2).toList();
    if (existingSlip.isEmpty) {
      for (final reason in HabitReason.getDefaultSlipReasons()) {
        await box.put(reason.id, reason);
      }
    }

    // Check if we already have temptation reasons
    final existingTemptation = box.values
        .where((r) => r.typeIndex == 3)
        .toList();
    if (existingTemptation.isEmpty) {
      for (final reason in HabitReason.getDefaultTemptationReasons()) {
        await box.put(reason.id, reason);
      }
    }
  }
}
