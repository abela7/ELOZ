import '../../../../core/services/reminder_manager.dart';
import '../repositories/habit_reason_repository.dart';
import '../repositories/habit_repository.dart';
import '../repositories/temptation_log_repository.dart';
import 'quit_habit_report_security_service.dart';

class QuitHabitDataResetSummary {
  final int deletedQuitHabits;
  final int deletedQuitCompletions;
  final int deletedTemptationLogs;
  final int deletedQuitReasons;

  const QuitHabitDataResetSummary({
    required this.deletedQuitHabits,
    required this.deletedQuitCompletions,
    required this.deletedTemptationLogs,
    required this.deletedQuitReasons,
  });
}

class QuitHabitDataResetService {
  final HabitRepository _habitRepository;
  final TemptationLogRepository _temptationRepository;
  final HabitReasonRepository _reasonRepository;
  final ReminderManager _reminderManager;
  final QuitHabitReportSecurityService _securityService;

  QuitHabitDataResetService({
    HabitRepository? habitRepository,
    TemptationLogRepository? temptationRepository,
    HabitReasonRepository? reasonRepository,
    ReminderManager? reminderManager,
    QuitHabitReportSecurityService? securityService,
  }) : _habitRepository = habitRepository ?? HabitRepository(),
       _temptationRepository =
           temptationRepository ?? TemptationLogRepository(),
       _reasonRepository = reasonRepository ?? HabitReasonRepository(),
       _reminderManager = reminderManager ?? ReminderManager(),
       _securityService = securityService ?? QuitHabitReportSecurityService();

  Future<QuitHabitDataResetSummary> wipeAllQuitHabitData() async {
    final allHabits = await _habitRepository.getAllHabits(
      includeArchived: true,
    );
    final quitHabits = allHabits.where((h) => h.isQuitHabit).toList();

    var deletedCompletions = 0;
    for (final habit in quitHabits) {
      final completions = await _habitRepository.getCompletionsForHabit(
        habit.id,
      );
      deletedCompletions += completions.length;
    }

    for (final habit in quitHabits) {
      await _cancelReminderSafely(habit.id);
      await _habitRepository.deleteHabit(habit.id);
    }

    final allTemptationLogs = await _temptationRepository.getAllLogs();
    final deletedTemptationLogs = allTemptationLogs.length;
    await _temptationRepository.clearAllLogs();

    final quitReasons = await _reasonRepository.getQuitReasons();
    final deletedQuitReasons = quitReasons.length;
    await _reasonRepository.deleteQuitReasons();
    await _reasonRepository.initializeQuitDefaults();

    await _securityService.resetAllSecurityState();

    return QuitHabitDataResetSummary(
      deletedQuitHabits: quitHabits.length,
      deletedQuitCompletions: deletedCompletions,
      deletedTemptationLogs: deletedTemptationLogs,
      deletedQuitReasons: deletedQuitReasons,
    );
  }

  Future<void> _cancelReminderSafely(String habitId) async {
    try {
      await _reminderManager.cancelRemindersForHabit(habitId);
    } catch (_) {
      // Ignore reminder cleanup errors to ensure secure data wipe still completes.
    }
  }
}
