import '../models/mood.dart';
import '../models/mood_entry.dart';
import '../models/mood_polarity.dart';
import '../models/mood_reason.dart';
import '../repositories/mood_repository.dart';

enum MoodRange { weekly, monthly, custom, lifetime }

class MoodSummaryResponse {
  const MoodSummaryResponse({
    required this.from,
    required this.to,
    required this.dailyScore,
    required this.weeklyAverage,
    required this.monthlyAverage,
    required this.lifetimeAverage,
    required this.positivePercent,
    required this.negativePercent,
    required this.entriesCount,
    required this.mostFrequentMoodId,
    required this.mostFrequentMoodName,
    required this.mostFrequentReasonId,
    required this.mostFrequentReasonName,
  });

  final DateTime from;
  final DateTime to;
  final int dailyScore;
  final double weeklyAverage;
  final double monthlyAverage;
  final double lifetimeAverage;
  final double positivePercent;
  final double negativePercent;
  final int entriesCount;
  final String? mostFrequentMoodId;
  final String? mostFrequentMoodName;
  final String? mostFrequentReasonId;
  final String? mostFrequentReasonName;
}

class MoodTrendsResponse {
  const MoodTrendsResponse({
    required this.from,
    required this.to,
    required this.dayScoreMap,
  });

  final DateTime from;
  final DateTime to;
  final Map<String, int> dayScoreMap;
}

/// Local API-style facade for the MBT Mood module.
///
/// Methods are intentionally named to mirror endpoint semantics:
/// - Mood management: post/put/delete/get
/// - Reason management: post/put/delete/get
/// - Logging: post + get by date/range
/// - Analytics: summary + trends
class MoodApiService {
  MoodApiService({MoodRepository? repository})
    : _repository = repository ?? MoodRepository();

  final MoodRepository _repository;

  // ---------------------------------------------------------------------------
  // Mood management (POST/PUT/DELETE/GET)
  // ---------------------------------------------------------------------------

  Future<Mood> postMood({
    required String name,
    required int iconCodePoint,
    String? iconFontFamily,
    String? iconFontPackage,
    int? emojiCodePoint,
    required int colorValue,
    required int pointValue,
    required bool reasonRequired,
    required String polarity,
    bool isActive = true,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw const FormatException('Mood name is required.');
    }
    if (!MoodPolarity.isValid(polarity)) {
      throw FormatException(
        'Mood polarity must be one of: ${MoodPolarity.supported}',
      );
    }
    return _repository.createMood(
      Mood(
        name: normalizedName,
        iconCodePoint: iconCodePoint,
        iconFontFamily: iconFontFamily ?? 'MaterialIcons',
        iconFontPackage: iconFontPackage,
        emojiCodePoint: emojiCodePoint,
        colorValue: colorValue,
        pointValue: pointValue,
        reasonRequired: reasonRequired,
        polarity: polarity,
        isActive: isActive,
      ),
    );
  }

  Future<Mood> putMood(
    String moodId, {
    String? name,
    int? iconCodePoint,
    String? iconFontFamily,
    String? iconFontPackage,
    int? emojiCodePoint,
    bool clearEmoji = false,
    int? colorValue,
    int? pointValue,
    bool? reasonRequired,
    String? polarity,
    bool? isActive,
  }) async {
    final existing = await _repository.getMoodById(moodId);
    if (existing == null) {
      throw StateError('Mood not found: $moodId');
    }
    final next = existing.copyWith(
      name: name?.trim().isNotEmpty == true ? name!.trim() : existing.name,
      iconCodePoint: iconCodePoint ?? existing.iconCodePoint,
      iconFontFamily: iconFontFamily ?? existing.iconFontFamily,
      iconFontPackage: iconFontPackage ?? existing.iconFontPackage,
      emojiCodePoint: clearEmoji ? null : (emojiCodePoint ?? existing.emojiCodePoint),
      colorValue: colorValue ?? existing.colorValue,
      pointValue: pointValue ?? existing.pointValue,
      reasonRequired: reasonRequired ?? existing.reasonRequired,
      polarity: polarity ?? existing.polarity,
      isActive: isActive ?? existing.isActive,
      updatedAt: DateTime.now(),
    );
    return _repository.updateMood(next);
  }

  Future<void> deleteMood(String moodId) async {
    await _repository.softDeleteMood(moodId);
  }

  Future<List<Mood>> getMoods({bool includeInactive = false}) async {
    return _repository.getMoods(
      includeInactive: includeInactive,
      includeDeleted: false,
    );
  }

  // ---------------------------------------------------------------------------
  // Reason management (POST/PUT/DELETE/GET)
  // ---------------------------------------------------------------------------

  Future<MoodReason> postReason({
    required String name,
    required String type,
    bool isActive = true,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw const FormatException('Reason name is required.');
    }
    if (!MoodPolarity.isValid(type)) {
      throw FormatException(
        'Reason type must be one of: ${MoodPolarity.supported}',
      );
    }
    return _repository.createReason(
      MoodReason(name: normalizedName, type: type, isActive: isActive),
    );
  }

  Future<MoodReason> putReason(
    String reasonId, {
    String? name,
    String? type,
    bool? isActive,
  }) async {
    final existing = await _repository.getReasonById(reasonId);
    if (existing == null) {
      throw StateError('Reason not found: $reasonId');
    }
    final next = existing.copyWith(
      name: name?.trim().isNotEmpty == true ? name!.trim() : existing.name,
      type: type ?? existing.type,
      isActive: isActive ?? existing.isActive,
      updatedAt: DateTime.now(),
    );
    return _repository.updateReason(next);
  }

  Future<void> deleteReason(String reasonId) async {
    await _repository.softDeleteReason(reasonId);
  }

  Future<List<MoodReason>> getReasons({
    String? type,
    bool includeInactive = false,
  }) async {
    if (type != null && !MoodPolarity.isValid(type)) {
      throw FormatException(
        'Reason type must be one of: ${MoodPolarity.supported}',
      );
    }
    return _repository.getReasons(
      type: type,
      includeInactive: includeInactive,
      includeDeleted: false,
    );
  }

  // ---------------------------------------------------------------------------
  // Logging (POST + GET by date/range)
  // ---------------------------------------------------------------------------

  /// Adds a new mood entry (always creates; never overwrites).
  ///
  /// Uses [loggedAt] with full timestamp. Defaults to device time when omitted.
  Future<MoodEntry> postMoodEntry({
    required String moodId,
    List<String>? reasonIds,
    String? customNote,
    DateTime? loggedAt,
    String source = 'manual',
  }) async {
    final mood = await _repository.getMoodById(moodId);
    if (mood == null || mood.isDeleted || !mood.isActive) {
      throw StateError('Mood is missing or inactive: $moodId');
    }

    final cleanIds =
        (reasonIds ?? <String>[]).where((r) => r.trim().isNotEmpty).toList();

    if (mood.reasonRequired && cleanIds.isEmpty) {
      throw const FormatException('This mood requires a reason.');
    }

    for (final reasonId in cleanIds) {
      final reason = await _repository.getReasonById(reasonId);
      if (reason == null || reason.isDeleted || !reason.isActive) {
        throw StateError('Reason is missing or inactive: $reasonId');
      }
      if (reason.type != mood.polarity) {
        throw FormatException(
          'Reason type (${reason.type}) must match mood polarity (${mood.polarity}).',
        );
      }
    }

    return _repository.addMoodEntry(
      loggedAt: loggedAt ?? DateTime.now(),
      moodId: moodId,
      reasonIds: cleanIds.isEmpty ? null : cleanIds,
      customNote: customNote?.trim().isEmpty == true
          ? null
          : customNote?.trim(),
      source: source,
    );
  }

  /// Updates an existing mood entry.
  Future<MoodEntry> updateMoodEntry({
    required String entryId,
    required String moodId,
    List<String>? reasonIds,
    String? customNote,
    DateTime? loggedAt,
    String source = 'manual',
  }) async {
    final existing = await _repository.getMoodEntryById(entryId);
    if (existing == null || existing.isDeleted) {
      throw StateError('Mood entry not found: $entryId');
    }

    final mood = await _repository.getMoodById(moodId);
    if (mood == null || mood.isDeleted || !mood.isActive) {
      throw StateError('Mood is missing or inactive: $moodId');
    }

    final cleanIds =
        (reasonIds ?? <String>[]).where((r) => r.trim().isNotEmpty).toList();

    if (mood.reasonRequired && cleanIds.isEmpty) {
      throw const FormatException('This mood requires a reason.');
    }

    for (final reasonId in cleanIds) {
      final reason = await _repository.getReasonById(reasonId);
      if (reason == null || reason.isDeleted || !reason.isActive) {
        throw StateError('Reason is missing or inactive: $reasonId');
      }
      if (reason.type != mood.polarity) {
        throw FormatException(
          'Reason type (${reason.type}) must match mood polarity (${mood.polarity}).',
        );
      }
    }

    return _repository.updateMoodEntry(
      id: entryId,
      loggedAt: loggedAt ?? existing.loggedAt,
      moodId: moodId,
      reasonIds: cleanIds.isEmpty ? null : cleanIds,
      customNote: customNote?.trim().isEmpty == true
          ? null
          : customNote?.trim(),
      source: source,
    );
  }

  /// Soft-deletes a mood entry.
  Future<bool> deleteMoodEntry(String entryId) async {
    return _repository.softDeleteMoodEntry(entryId);
  }

  /// Returns an entry by ID.
  Future<MoodEntry?> getMoodEntryById(String entryId) async {
    return _repository.getMoodEntryById(entryId);
  }

  /// Returns the most recent entry for the date (for backward compat).
  Future<MoodEntry?> getMoodEntryByDate(DateTime date) async {
    return _repository.getMoodEntryForDate(date);
  }

  /// Returns all entries for a date, sorted by [loggedAt] ascending.
  Future<List<MoodEntry>> getMoodEntriesForDate(DateTime date) async {
    return _repository.getMoodEntriesForDate(date);
  }

  Future<List<MoodEntry>> getMoodEntriesByRange({
    required MoodRange range,
    DateTime? from,
    DateTime? to,
  }) async {
    final resolved = await _resolveRange(range: range, from: from, to: to);
    return _repository.getMoodEntriesInRange(resolved.$1, resolved.$2);
  }

  // ---------------------------------------------------------------------------
  // Analytics (GET summary + trends)
  // ---------------------------------------------------------------------------

  Future<MoodSummaryResponse> getMoodSummary({
    required MoodRange range,
    DateTime? from,
    DateTime? to,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weeklyRange = (today.subtract(const Duration(days: 6)), today);
    final monthlyRange = (DateTime(today.year, today.month, 1), today);
    final selectedRange = await _resolveRange(range: range, from: from, to: to);
    final lifetimeRange = await _resolveRange(range: MoodRange.lifetime);

    final todaySummary = await _repository.getDailySummary(today);
    final weeklySummary = await _repository.getDailySummaryMapInRange(
      weeklyRange.$1,
      weeklyRange.$2,
    );
    final monthlySummary = await _repository.getDailySummaryMapInRange(
      monthlyRange.$1,
      monthlyRange.$2,
    );
    final selectedSummary = await _repository.getDailySummaryMapInRange(
      selectedRange.$1,
      selectedRange.$2,
    );
    final lifetimeSummary = await _repository.getDailySummaryMapInRange(
      lifetimeRange.$1,
      lifetimeRange.$2,
    );

    final selectedEntriesCount = selectedSummary.values.fold<int>(
      0,
      (sum, s) => sum + _asInt(s['entryCount']),
    );
    final positiveCount = selectedSummary.values.fold<int>(
      0,
      (sum, summary) => sum + _asInt(summary['positiveCount']),
    );
    final negativeCount = selectedSummary.values.fold<int>(
      0,
      (sum, summary) => sum + _asInt(summary['negativeCount']),
    );
    final totalPolarity = positiveCount + negativeCount;

    final moodFrequency = <String, int>{};
    final reasonFrequency = <String, int>{};
    for (final summary in selectedSummary.values) {
      final moodId = '${summary['moodId'] ?? ''}';
      if (moodId.isNotEmpty) {
        moodFrequency[moodId] = (moodFrequency[moodId] ?? 0) + 1;
      }
      // Count every reason in the multi-reason list.
      final rawIds = summary['reasonIds'];
      final reasonIds = rawIds is List
          ? rawIds.cast<String>()
          : ['${summary['reasonId'] ?? ''}'];
      for (final reasonId in reasonIds) {
        if (reasonId.isNotEmpty) {
          reasonFrequency[reasonId] = (reasonFrequency[reasonId] ?? 0) + 1;
        }
      }
    }

    final topMoodId = _topKey(moodFrequency);
    final topReasonId = _topKey(reasonFrequency);
    final topMood = topMoodId == null
        ? null
        : await _repository.getMoodById(topMoodId);
    final topReason = topReasonId == null
        ? null
        : await _repository.getReasonById(topReasonId);
    final topMoodName = topMood == null || topMood.isDeleted
        ? null
        : topMood.name;
    final topReasonName = topReason == null || topReason.isDeleted
        ? null
        : topReason.name;

    return MoodSummaryResponse(
      from: selectedRange.$1,
      to: selectedRange.$2,
      dailyScore: _asInt(todaySummary['score']),
      weeklyAverage: _averageScore(weeklySummary),
      monthlyAverage: _averageScore(monthlySummary),
      lifetimeAverage: _averageScore(lifetimeSummary),
      positivePercent: totalPolarity == 0
          ? 0
          : (positiveCount / totalPolarity) * 100,
      negativePercent: totalPolarity == 0
          ? 0
          : (negativeCount / totalPolarity) * 100,
      entriesCount: selectedEntriesCount,
      mostFrequentMoodId: topMoodId,
      mostFrequentMoodName: topMoodName,
      mostFrequentReasonId: topReasonId,
      mostFrequentReasonName: topReasonName,
    );
  }

  Future<MoodTrendsResponse> getMoodTrends({
    required MoodRange range,
    DateTime? from,
    DateTime? to,
  }) async {
    final resolved = await _resolveRange(range: range, from: from, to: to);
    final summaries = await _repository.getDailySummaryMapInRange(
      resolved.$1,
      resolved.$2,
    );
    final map = <String, int>{};
    final sortedKeys = summaries.keys.toList()..sort();
    for (final key in sortedKeys) {
      map[key] = _asInt(summaries[key]?['score']);
    }
    return MoodTrendsResponse(
      from: resolved.$1,
      to: resolved.$2,
      dayScoreMap: map,
    );
  }

  Future<(DateTime, DateTime)> _resolveRange({
    required MoodRange range,
    DateTime? from,
    DateTime? to,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (range) {
      case MoodRange.weekly:
        return (today.subtract(const Duration(days: 6)), today);
      case MoodRange.monthly:
        return (DateTime(today.year, today.month, 1), today);
      case MoodRange.custom:
        if (from == null || to == null) {
          throw const FormatException(
            'Custom range requires both from and to dates.',
          );
        }
        final fromOnly = DateTime(from.year, from.month, from.day);
        final toOnly = DateTime(to.year, to.month, to.day);
        if (toOnly.isBefore(fromOnly)) {
          throw const FormatException(
            'Range end cannot be before range start.',
          );
        }
        return (fromOnly, toOnly);
      case MoodRange.lifetime:
        final all = await _repository.getAllMoodEntries();
        if (all.isEmpty) {
          return (today, today);
        }
        final first = all.first.loggedAt;
        final fromOnly = DateTime(first.year, first.month, first.day);
        return (fromOnly, today);
    }
  }

  double _averageScore(Map<String, Map<String, dynamic>> summaryByDay) {
    if (summaryByDay.isEmpty) return 0;
    var total = 0;
    var count = 0;
    for (final summary in summaryByDay.values) {
      final entryCount = _asInt(summary['entryCount']);
      if (entryCount <= 0) continue;
      total += _asInt(summary['score']);
      count++;
    }
    if (count == 0) return 0;
    return total / count;
  }

  String? _topKey(Map<String, int> frequency) {
    String? top;
    var max = 0;
    for (final entry in frequency.entries) {
      if (entry.value > max) {
        max = entry.value;
        top = entry.key;
      }
    }
    return top;
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }
}
