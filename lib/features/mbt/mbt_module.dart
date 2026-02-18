import 'package:hive/hive.dart';

import '../../data/local/hive/hive_service.dart';
import '../../core/notifications/notification_hub.dart';
import 'data/models/mood.dart';
import 'data/models/mood_entry.dart';
import 'data/models/mood_reason.dart';
import 'notifications/mbt_mood_notification_adapter.dart';

class MbtModule {
  static bool _initialized = false;
  static bool _boxesPreopened = false;

  static const String moodsBoxName = 'mbt_moods_v1';
  static const String moodReasonsBoxName = 'mbt_mood_reasons_v1';
  static const String moodEntriesBoxName = 'mbt_mood_entries_v1';
  static const String moodEntryDateIndexBoxName =
      'mbt_mood_entry_date_index_v1';
  static const String moodDailySummaryBoxName = 'mbt_mood_daily_summary_v1';
  static const String moodIndexMetaBoxName = 'mbt_mood_index_meta_v1';

  static Future<void> init({bool preOpenBoxes = true}) async {
    if (!_initialized) {
      if (!Hive.isAdapterRegistered(60)) {
        Hive.registerAdapter(MoodAdapter());
      }
      if (!Hive.isAdapterRegistered(61)) {
        Hive.registerAdapter(MoodReasonAdapter());
      }
      if (!Hive.isAdapterRegistered(62)) {
        Hive.registerAdapter(MoodEntryAdapter());
      }
      _initialized = true;
    }

    NotificationHub().registerAdapter(MbtMoodNotificationAdapter());

    if (preOpenBoxes && !_boxesPreopened) {
      await HiveService.getBox<Mood>(moodsBoxName);
      await HiveService.getBox<MoodReason>(moodReasonsBoxName);
      await HiveService.getBox<MoodEntry>(moodEntriesBoxName);
      await HiveService.getBox<dynamic>(moodEntryDateIndexBoxName);
      await HiveService.getBox<dynamic>(moodDailySummaryBoxName);
      await HiveService.getBox<dynamic>(moodIndexMetaBoxName);
      _boxesPreopened = true;
    }
  }

  static bool get isInitialized => _initialized;
}
