import '../../../../data/local/hive/hive_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/habit.dart';
import '../models/habit_completion.dart';
import '../models/habit_reason.dart';
import '../models/temptation_log.dart';
import '../repositories/habit_repository.dart';
import '../repositories/habit_reason_repository.dart';
import '../repositories/temptation_log_repository.dart';
import 'quit_habit_secure_storage_service.dart';

class QuitHabitSecureDataMigrationService {
  static const _migrationDoneKey = 'quit_habit_secure_legacy_migration_done_v1';
  static bool _migrationCheckedThisSession = false;

  final QuitHabitSecureStorageService _secureStorage;

  QuitHabitSecureDataMigrationService({
    QuitHabitSecureStorageService? secureStorage,
  }) : _secureStorage = secureStorage ?? QuitHabitSecureStorageService();

  /// Moves legacy quit data out of shared boxes into dedicated secure boxes.
  ///
  /// Safe to run multiple times.
  Future<void> migrateLegacyDataIfNeeded() async {
    if (!_secureStorage.isSessionUnlocked) return;
    if (_migrationCheckedThisSession) return;

    final prefs = await SharedPreferences.getInstance();
    final alreadyMigrated = prefs.getBool(_migrationDoneKey) ?? false;
    if (alreadyMigrated) {
      _migrationCheckedThisSession = true;
      return;
    }

    final regularHabits = await HiveService.getBox<Habit>(
      HabitRepository.habitsBoxName,
    );
    final regularCompletions = await HiveService.getBox<HabitCompletion>(
      HabitRepository.completionsBoxName,
    );
    final regularReasons = await HiveService.getBox<HabitReason>(
      HabitReasonRepository.boxName,
    );
    final regularTemptations = await HiveService.getBox<TemptationLog>(
      TemptationLogRepository.legacyBoxName,
    );

    final secureHabits = await _secureStorage.openSecureBox<Habit>(
      QuitHabitSecureStorageService.secureHabitsBoxName,
    );
    final secureCompletions = await _secureStorage
        .openSecureBox<HabitCompletion>(
          QuitHabitSecureStorageService.secureCompletionsBoxName,
        );
    final secureReasons = await _secureStorage.openSecureBox<HabitReason>(
      QuitHabitSecureStorageService.secureReasonsBoxName,
    );
    final secureTemptations = await _secureStorage.openSecureBox<TemptationLog>(
      QuitHabitSecureStorageService.secureTemptationsBoxName,
    );

    final legacyQuitHabits = regularHabits.values
        .where((h) => h.isQuitHabit)
        .toList();
    if (legacyQuitHabits.isNotEmpty) {
      for (final habit in legacyQuitHabits) {
        await secureHabits.put(habit.id, _cloneHabit(habit));
        await regularHabits.delete(habit.id);
      }
    }

    final secureQuitIds = secureHabits.values.map((h) => h.id).toSet();

    final legacyQuitCompletions = regularCompletions.values
        .where((c) => secureQuitIds.contains(c.habitId))
        .toList();
    if (legacyQuitCompletions.isNotEmpty) {
      for (final completion in legacyQuitCompletions) {
        await secureCompletions.put(
          completion.id,
          _cloneCompletion(completion),
        );
        await regularCompletions.delete(completion.id);
      }
    }

    final legacyQuitReasons = regularReasons.values
        .where((r) => r.typeIndex == 2 || r.typeIndex == 3)
        .toList();
    if (legacyQuitReasons.isNotEmpty) {
      for (final reason in legacyQuitReasons) {
        await secureReasons.put(reason.id, _cloneReason(reason));
        await regularReasons.delete(reason.id);
      }
    }

    if (regularTemptations.isNotEmpty) {
      for (final log in regularTemptations.values.toList()) {
        await secureTemptations.put(log.id, _cloneTemptation(log));
      }
      await regularTemptations.clear();
    }

    await prefs.setBool(_migrationDoneKey, true);
    _migrationCheckedThisSession = true;
  }

  Habit _cloneHabit(Habit habit) {
    return habit.copyWith(
      weekDays: habit.weekDays == null ? null : List<int>.from(habit.weekDays!),
      tags: habit.tags == null ? null : List<String>.from(habit.tags!),
      checklist: habit.checklist?.map((s) => s.copyWith()).toList(),
    );
  }

  HabitCompletion _cloneCompletion(HabitCompletion completion) {
    return completion.copyWith();
  }

  HabitReason _cloneReason(HabitReason reason) {
    return reason.copyWith();
  }

  TemptationLog _cloneTemptation(TemptationLog log) {
    return log.copyWith();
  }
}
