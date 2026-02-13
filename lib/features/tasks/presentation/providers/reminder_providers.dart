import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/models/simple_reminder.dart';
import '../../../../data/local/hive/hive_service.dart';
import '../../../../core/services/notification_service.dart';

/// Provider for the reminder box name constant
const String _remindersBoxName = 'remindersBox';

/// StateNotifier for managing simple reminders
/// 
/// Features:
/// - CRUD operations for reminders
/// - Auto-purge reminders older than 24 hours (after scheduledAt)
/// - Notification scheduling integration
/// - Filter by date
class ReminderNotifier extends StateNotifier<AsyncValue<List<SimpleReminder>>> {
  final NotificationService _notificationService = NotificationService();

  ReminderNotifier() : super(const AsyncValue.loading()) {
    loadReminders();
  }

  /// Load all reminders from database and purge expired ones
  Future<void> loadReminders() async {
    state = const AsyncValue.loading();
    try {
      final box = await HiveService.getBox<SimpleReminder>(_remindersBoxName);
      final reminders = box.values.toList();
      
      // Purge expired reminders (24 hours after scheduledAt)
      final now = DateTime.now();
      final expiredIds = <String>[];
      final activeReminders = <SimpleReminder>[];
      
      for (final reminder in reminders) {
        final expiryTime = reminder.scheduledAt.add(const Duration(hours: 24));
        if (now.isAfter(expiryTime)) {
          expiredIds.add(reminder.id);
          // Also cancel any pending notifications
          await _notificationService.cancelSimpleReminder(reminder.notificationId);
        } else {
          activeReminders.add(reminder);
        }
      }
      
      // Delete expired reminders from storage
      for (final id in expiredIds) {
        await box.delete(id);
      }
      
      if (expiredIds.isNotEmpty) {
        print('🧹 ReminderNotifier: Purged ${expiredIds.length} expired reminders');
      }
      
      // Sort pinned first, then scheduledAt
      activeReminders.sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return a.scheduledAt.compareTo(b.scheduledAt);
      });
      
      state = AsyncValue.data(activeReminders);
    } catch (e, stackTrace) {
      print('❌ ReminderNotifier: Error loading reminders: $e');
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Add a new reminder
  Future<bool> addReminder(SimpleReminder reminder) async {
    try {
      final box = await HiveService.getBox<SimpleReminder>(_remindersBoxName);
      
      // Schedule notification
      final scheduled = await _notificationService.scheduleSimpleReminder(
        notificationId: reminder.notificationId,
        title: reminder.title,
        body: reminder.description,
        scheduledAt: reminder.scheduledAt,
        payload: 'simple_reminder|${reminder.id}',
        iconCodePoint: reminder.iconCodePoint,
        iconFontFamily: reminder.iconFontFamily,
        iconFontPackage: reminder.iconFontPackage,
        colorValue: reminder.colorValue,
      );
      
      if (!scheduled) {
        print('⚠️ ReminderNotifier: Notification could not be scheduled');
      }
      
      // Save to Hive
      await box.put(reminder.id, reminder);
      
      // Update state
      final currentReminders = state.valueOrNull ?? [];
      final updatedReminders = [...currentReminders, reminder];
      updatedReminders.sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return a.scheduledAt.compareTo(b.scheduledAt);
      });
      state = AsyncValue.data(updatedReminders);
      
      print('✅ ReminderNotifier: Added reminder "${reminder.title}"');
      return true;
    } catch (e) {
      print('❌ ReminderNotifier: Error adding reminder: $e');
      return false;
    }
  }

  /// Update an existing reminder
  Future<bool> updateReminder(SimpleReminder reminder) async {
    try {
      final box = await HiveService.getBox<SimpleReminder>(_remindersBoxName);
      
      // Reschedule notification
      await _notificationService.rescheduleSimpleReminder(
        notificationId: reminder.notificationId,
        title: reminder.title,
        body: reminder.description,
        scheduledAt: reminder.scheduledAt,
        payload: 'simple_reminder|${reminder.id}',
        iconCodePoint: reminder.iconCodePoint,
        iconFontFamily: reminder.iconFontFamily,
        iconFontPackage: reminder.iconFontPackage,
        colorValue: reminder.colorValue,
      );
      
      // Update in Hive
      await box.put(reminder.id, reminder);
      
      // Update state
      final currentReminders = state.valueOrNull ?? [];
      final updatedReminders = currentReminders.map((r) {
        return r.id == reminder.id ? reminder : r;
      }).toList();
      updatedReminders.sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return a.scheduledAt.compareTo(b.scheduledAt);
      });
      updatedReminders.sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return a.scheduledAt.compareTo(b.scheduledAt);
      });
      state = AsyncValue.data(updatedReminders);
      
      print('✅ ReminderNotifier: Updated reminder "${reminder.title}"');
      return true;
    } catch (e) {
      print('❌ ReminderNotifier: Error updating reminder: $e');
      return false;
    }
  }

  /// Mark a reminder as done
  Future<bool> markReminderDone(String reminderId) async {
    try {
      final box = await HiveService.getBox<SimpleReminder>(_remindersBoxName);
      final reminder = box.get(reminderId);
      
      if (reminder == null) {
        print('⚠️ ReminderNotifier: Reminder not found: $reminderId');
        return false;
      }
      
      // Cancel notification
      await _notificationService.cancelSimpleReminder(reminder.notificationId);
      
      // Update reminder status
      final updatedReminder = reminder.copyWith(
        status: ReminderStatus.done,
        completedAt: DateTime.now(),
      );
      await box.put(reminderId, updatedReminder);
      
      // Update state
      final currentReminders = state.valueOrNull ?? [];
      final updatedReminders = currentReminders.map((r) {
        return r.id == reminderId ? updatedReminder : r;
      }).toList();
      updatedReminders.sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return a.scheduledAt.compareTo(b.scheduledAt);
      });
      state = AsyncValue.data(updatedReminders);
      
      print('✅ ReminderNotifier: Marked reminder as done: "${reminder.title}"');
      return true;
    } catch (e) {
      print('❌ ReminderNotifier: Error marking reminder as done: $e');
      return false;
    }
  }

  /// Mark a reminder as pending (undo done)
  Future<bool> markReminderPending(String reminderId) async {
    try {
      final box = await HiveService.getBox<SimpleReminder>(_remindersBoxName);
      final reminder = box.get(reminderId);

      if (reminder == null) {
        print('⚠️ ReminderNotifier: Reminder not found: $reminderId');
        return false;
      }

      // Reschedule notification if the time is still in the future
      if (reminder.scheduledAt.isAfter(DateTime.now())) {
        await _notificationService.rescheduleSimpleReminder(
          notificationId: reminder.notificationId,
          title: reminder.title,
          body: reminder.description,
          scheduledAt: reminder.scheduledAt,
          payload: 'simple_reminder|${reminder.id}',
          iconCodePoint: reminder.iconCodePoint,
          iconFontFamily: reminder.iconFontFamily,
          iconFontPackage: reminder.iconFontPackage,
          colorValue: reminder.colorValue,
        );
      }

      // Update reminder status
      final updatedReminder = reminder.copyWith(
        status: ReminderStatus.pending,
        completedAt: null,
      );
      await box.put(reminderId, updatedReminder);

      // Update state
      final currentReminders = state.valueOrNull ?? [];
      final updatedReminders = currentReminders.map((r) {
        return r.id == reminderId ? updatedReminder : r;
      }).toList();
      updatedReminders.sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return a.scheduledAt.compareTo(b.scheduledAt);
      });
      state = AsyncValue.data(updatedReminders);

      print('✅ ReminderNotifier: Marked reminder as pending: "${reminder.title}"');
      return true;
    } catch (e) {
      print('❌ ReminderNotifier: Error marking reminder as pending: $e');
      return false;
    }
  }

  /// Start count-up timer for a reminder
  Future<bool> startCountup(String reminderId) async {
    try {
      final box = await HiveService.getBox<SimpleReminder>(_remindersBoxName);
      final reminder = box.get(reminderId);
      
      if (reminder == null) {
        print('⚠️ ReminderNotifier: Reminder not found: $reminderId');
        return false;
      }
      
      // Update reminder with count-up mode
      final updatedReminder = reminder.copyWith(
        timerMode: ReminderTimerMode.countup,
        counterStartedAt: DateTime.now(),
      );
      await box.put(reminderId, updatedReminder);
      
      // Update state
      final currentReminders = state.valueOrNull ?? [];
      final updatedReminders = currentReminders.map((r) {
        return r.id == reminderId ? updatedReminder : r;
      }).toList();
      state = AsyncValue.data(updatedReminders);
      
      print('✅ ReminderNotifier: Started count-up for: "${reminder.title}"');
      return true;
    } catch (e) {
      print('❌ ReminderNotifier: Error starting count-up: $e');
      return false;
    }
  }

  /// Toggle pin status
  Future<bool> togglePin(String reminderId) async {
    try {
      final box = await HiveService.getBox<SimpleReminder>(_remindersBoxName);
      final reminder = box.get(reminderId);

      if (reminder == null) {
        print('⚠️ ReminderNotifier: Reminder not found: $reminderId');
        return false;
      }

      final updatedReminder = reminder.copyWith(isPinned: !reminder.isPinned);
      await box.put(reminderId, updatedReminder);

      final currentReminders = state.valueOrNull ?? [];
      final updatedReminders = currentReminders.map((r) {
        return r.id == reminderId ? updatedReminder : r;
      }).toList();
      updatedReminders.sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return a.scheduledAt.compareTo(b.scheduledAt);
      });
      state = AsyncValue.data(updatedReminders);

      print('✅ ReminderNotifier: Toggled pin for: \"${reminder.title}\"');
      return true;
    } catch (e) {
      print('❌ ReminderNotifier: Error toggling pin: $e');
      return false;
    }
  }

  /// Delete a reminder
  Future<bool> deleteReminder(String reminderId) async {
    try {
      final box = await HiveService.getBox<SimpleReminder>(_remindersBoxName);
      final reminder = box.get(reminderId);
      
      if (reminder != null) {
        // Cancel notification
        await _notificationService.cancelSimpleReminder(reminder.notificationId);
      }
      
      // Delete from Hive
      await box.delete(reminderId);
      
      // Update state
      final currentReminders = state.valueOrNull ?? [];
      final updatedReminders = currentReminders.where((r) => r.id != reminderId).toList();
      state = AsyncValue.data(updatedReminders);
      
      print('✅ ReminderNotifier: Deleted reminder');
      return true;
    } catch (e) {
      print('❌ ReminderNotifier: Error deleting reminder: $e');
      return false;
    }
  }

  /// Purge all expired reminders manually
  Future<int> purgeExpiredReminders() async {
    try {
      final box = await HiveService.getBox<SimpleReminder>(_remindersBoxName);
      final reminders = box.values.toList();
      
      final now = DateTime.now();
      int purgedCount = 0;
      
      for (final reminder in reminders) {
        final expiryTime = reminder.scheduledAt.add(const Duration(hours: 24));
        if (now.isAfter(expiryTime)) {
          await _notificationService.cancelSimpleReminder(reminder.notificationId);
          await box.delete(reminder.id);
          purgedCount++;
        }
      }
      
      if (purgedCount > 0) {
        await loadReminders(); // Reload to update state
        print('🧹 ReminderNotifier: Purged $purgedCount expired reminders');
      }
      
      return purgedCount;
    } catch (e) {
      print('❌ ReminderNotifier: Error purging reminders: $e');
      return 0;
    }
  }
}

/// Provider for the ReminderNotifier
final reminderNotifierProvider = StateNotifierProvider<ReminderNotifier, AsyncValue<List<SimpleReminder>>>((ref) {
  return ReminderNotifier();
});

/// Provider for reminders filtered by a specific date
final remindersForDateProvider = Provider.family<List<SimpleReminder>, DateTime>((ref, date) {
  final remindersAsync = ref.watch(reminderNotifierProvider);
  
  return remindersAsync.when(
    data: (reminders) {
      final targetDate = DateTime(date.year, date.month, date.day);
      return reminders.where((reminder) {
        final reminderDate = DateTime(
          reminder.scheduledAt.year,
          reminder.scheduledAt.month,
          reminder.scheduledAt.day,
        );
        return reminderDate == targetDate;
      }).toList();
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Provider for today's reminders
final todayRemindersProvider = Provider<List<SimpleReminder>>((ref) {
  final today = DateTime.now();
  return ref.watch(remindersForDateProvider(today));
});

/// Provider for pending reminders only
final pendingRemindersProvider = Provider<List<SimpleReminder>>((ref) {
  final remindersAsync = ref.watch(reminderNotifierProvider);
  
  return remindersAsync.when(
    data: (reminders) => reminders.where((r) => r.isPending).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Provider for pending reminders count
final pendingRemindersCountProvider = Provider<int>((ref) {
  return ref.watch(pendingRemindersProvider).length;
});

/// Provider for done reminders
final doneRemindersProvider = Provider<List<SimpleReminder>>((ref) {
  final remindersAsync = ref.watch(reminderNotifierProvider);
  
  return remindersAsync.when(
    data: (reminders) => reminders.where((r) => r.isDone).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});
