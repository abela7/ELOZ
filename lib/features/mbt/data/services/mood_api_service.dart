import '../models/mood.dart';
import '../models/mood_entry.dart';
import '../models/mood_polarity.dart';
import '../models/mood_reason.dart';
import '../repositories/mood_repository.dart';

enum MoodRange { daily, weekly, monthly, custom, lifetime }

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

/// Rich analytics payload for the report screen charts.
class MoodAnalyticsResponse {
  const MoodAnalyticsResponse({
    required this.from,
    required this.to,
    required this.moodDistribution,
    required this.reasonDistribution,
    required this.scoreTimeline,
    required this.reasonTimeline,
    required this.reasonMoodMatrix,
    required this.highPoint,
    required this.lowPoint,
    required this.entriesCount,
  });

  final DateTime from;
  final DateTime to;

  /// Mood ID -> occurrence count.
  final Map<String, int> moodDistribution;

  /// Reason ID -> occurrence count.
  final Map<String, int> reasonDistribution;

  /// Bucketed score timeline: label -> average score.
  /// Buckets are daily for <=60 days, weekly for <=365, monthly beyond that.
  final List<({String label, double score})> scoreTimeline;

  /// Top-5 reason IDs -> (bucket label -> count).
  final Map<String, List<({String label, int count})>> reasonTimeline;

  /// Reason ID -> Mood ID -> co-occurrence count.
  final Map<String, Map<String, int>> reasonMoodMatrix;

  /// Highest and lowest score points in the range.
  final ({String label, double score})? highPoint;
  final ({String label, double score})? lowPoint;

  final int entriesCount;
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
      emojiCodePoint: clearEmoji
          ? null
          : (emojiCodePoint ?? existing.emojiCodePoint),
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
    int? iconCodePoint,
    int? colorValue,
    int? emojiCodePoint,
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
      MoodReason(
        name: normalizedName,
        type: type,
        isActive: isActive,
        iconCodePoint: iconCodePoint ?? 0xe3a5,
        colorValue: colorValue ?? 0xFFCDAF56,
        emojiCodePoint: emojiCodePoint,
      ),
    );
  }

  Future<MoodReason> putReason(
    String reasonId, {
    String? name,
    String? type,
    bool? isActive,
    int? iconCodePoint,
    int? colorValue,
    int? emojiCodePoint,
    bool clearEmoji = false,
  }) async {
    final existing = await _repository.getReasonById(reasonId);
    if (existing == null) {
      throw StateError('Reason not found: $reasonId');
    }
    final next = existing.copyWith(
      name: name?.trim().isNotEmpty == true ? name!.trim() : existing.name,
      type: type ?? existing.type,
      isActive: isActive ?? existing.isActive,
      iconCodePoint: iconCodePoint ?? existing.iconCodePoint,
      colorValue: colorValue ?? existing.colorValue,
      emojiCodePoint: clearEmoji
          ? null
          : (emojiCodePoint ?? existing.emojiCodePoint),
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

    final cleanIds = (reasonIds ?? <String>[])
        .where((r) => r.trim().isNotEmpty)
        .toList();

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

    final cleanIds = (reasonIds ?? <String>[])
        .where((r) => r.trim().isNotEmpty)
        .toList();

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
    final selectedRange = await _resolveRange(range: range, from: from, to: to);

    final selectedSummary = await _repository.getDailySummaryMapInRange(
      selectedRange.$1,
      selectedRange.$2,
    );
    final selectedEntries = await _repository.getMoodEntriesInRange(
      selectedRange.$1,
      selectedRange.$2,
    );

    // Only compute cross-range averages when actually needed (not for daily).
    double weeklyAvg = 0, monthlyAvg = 0, lifetimeAvg = 0;
    int dailyScore = 0;
    if (range != MoodRange.daily) {
      final todaySummary = await _repository.getDailySummary(today);
      dailyScore = _asInt(todaySummary['score']);
      final weeklyRange = (today.subtract(const Duration(days: 6)), today);
      final monthlyRange = (DateTime(today.year, today.month, 1), today);
      final lifetimeRange = await _resolveRange(range: MoodRange.lifetime);
      final results = await Future.wait([
        _repository.getDailySummaryMapInRange(weeklyRange.$1, weeklyRange.$2),
        _repository.getDailySummaryMapInRange(monthlyRange.$1, monthlyRange.$2),
        _repository.getDailySummaryMapInRange(
            lifetimeRange.$1, lifetimeRange.$2),
      ]);
      weeklyAvg = _averageScore(results[0]);
      monthlyAvg = _averageScore(results[1]);
      lifetimeAvg = _averageScore(results[2]);
    } else {
      final todaySummary = await _repository.getDailySummary(today);
      dailyScore = _asInt(todaySummary['score']);
    }

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
    }
    for (final entry in selectedEntries) {
      if (entry.isDeleted) continue;
      for (final reasonId in entry.reasonIds) {
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
      dailyScore: dailyScore,
      weeklyAverage: weeklyAvg,
      monthlyAverage: monthlyAvg,
      lifetimeAverage: lifetimeAvg,
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

  /// Rich analytics for the report page charts.
  ///
  /// Performs a single-pass over entries and daily summaries, then buckets
  /// scores smartly: daily for <=60 days, weekly for <=365, monthly beyond.
  Future<MoodAnalyticsResponse> getMoodAnalytics({
    required MoodRange range,
    DateTime? from,
    DateTime? to,
  }) async {
    final resolved = await _resolveRange(range: range, from: from, to: to);
    final startDate = resolved.$1;
    final endDate = resolved.$2;
    final totalDays = endDate.difference(startDate).inDays + 1;

    final entries = await _repository.getMoodEntriesInRange(startDate, endDate);
    final summaries = await _repository.getDailySummaryMapInRange(
      startDate,
      endDate,
    );

    // -- Single pass over entries for distributions + matrix --
    final moodDist = <String, int>{};
    final reasonDist = <String, int>{};
    final reasonMoodMatrix = <String, Map<String, int>>{};

    for (final entry in entries) {
      if (entry.isDeleted) continue;
      moodDist[entry.moodId] = (moodDist[entry.moodId] ?? 0) + 1;
      for (final rid in entry.reasonIds) {
        if (rid.isEmpty) continue;
        reasonDist[rid] = (reasonDist[rid] ?? 0) + 1;
        reasonMoodMatrix
            .putIfAbsent(rid, () => <String, int>{})
            .update(entry.moodId, (v) => v + 1, ifAbsent: () => 1);
      }
    }

    // -- Build score timeline from daily summaries with smart bucketing --
    final sortedKeys = summaries.keys.toList()..sort();
    final rawDayScores = <({String key, double score})>[];
    for (final key in sortedKeys) {
      final s = summaries[key]!;
      final ec = _asInt(s['entryCount']);
      if (ec <= 0) continue;
      rawDayScores.add((key: key, score: _asInt(s['score']).toDouble()));
    }

    final scoreTimeline = <({String label, double score})>[];
    ({String label, double score})? highPoint;
    ({String label, double score})? lowPoint;

    if (totalDays <= 60) {
      // Daily buckets
      for (final d in rawDayScores) {
        final label = _formatBucketLabel(d.key);
        final point = (label: label, score: d.score);
        scoreTimeline.add(point);
        if (highPoint == null || d.score > highPoint.score) highPoint = point;
        if (lowPoint == null || d.score < lowPoint.score) lowPoint = point;
      }
    } else if (totalDays <= 365) {
      // Weekly buckets
      _bucketScores(rawDayScores, 7, scoreTimeline);
      for (final p in scoreTimeline) {
        if (highPoint == null || p.score > highPoint.score) highPoint = p;
        if (lowPoint == null || p.score < lowPoint.score) lowPoint = p;
      }
    } else {
      // Monthly buckets
      _bucketScoresMonthly(rawDayScores, scoreTimeline);
      for (final p in scoreTimeline) {
        if (highPoint == null || p.score > highPoint.score) highPoint = p;
        if (lowPoint == null || p.score < lowPoint.score) lowPoint = p;
      }
    }

    // -- Reason timeline: top 5 reasons bucketed the same way --
    final top5Reasons =
        (reasonDist.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .take(5)
            .map((e) => e.key)
            .toList();

    final reasonTimeline = <String, List<({String label, int count})>>{};
    if (top5Reasons.isNotEmpty) {
      // Build per-day counts for each top reason
      final perDayReasonCounts = <String, Map<String, int>>{};
      for (final rid in top5Reasons) {
        perDayReasonCounts[rid] = <String, int>{};
      }
      for (final entry in entries) {
        if (entry.isDeleted) continue;
        for (final rid in entry.reasonIds) {
          if (perDayReasonCounts.containsKey(rid)) {
            perDayReasonCounts[rid]!.update(
              entry.dayKey,
              (v) => v + 1,
              ifAbsent: () => 1,
            );
          }
        }
      }

      for (final rid in top5Reasons) {
        final dayMap = perDayReasonCounts[rid]!;
        final rawReasonDays = <({String key, double score})>[];
        for (final key in sortedKeys) {
          rawReasonDays.add((key: key, score: (dayMap[key] ?? 0).toDouble()));
        }

        if (totalDays <= 60) {
          reasonTimeline[rid] = rawReasonDays
              .map(
                (d) =>
                    (label: _formatBucketLabel(d.key), count: d.score.round()),
              )
              .toList();
        } else if (totalDays <= 365) {
          final buckets = <({String label, double score})>[];
          _bucketScores(rawReasonDays, 7, buckets);
          reasonTimeline[rid] = buckets
              .map((b) => (label: b.label, count: b.score.round()))
              .toList();
        } else {
          final buckets = <({String label, double score})>[];
          _bucketScoresMonthly(rawReasonDays, buckets);
          reasonTimeline[rid] = buckets
              .map((b) => (label: b.label, count: b.score.round()))
              .toList();
        }
      }
    }

    return MoodAnalyticsResponse(
      from: startDate,
      to: endDate,
      moodDistribution: moodDist,
      reasonDistribution: reasonDist,
      scoreTimeline: scoreTimeline,
      reasonTimeline: reasonTimeline,
      reasonMoodMatrix: reasonMoodMatrix,
      highPoint: highPoint,
      lowPoint: lowPoint,
      entriesCount: entries.where((e) => !e.isDeleted).length,
    );
  }

  void _bucketScores(
    List<({String key, double score})> raw,
    int bucketSize,
    List<({String label, double score})> out,
  ) {
    for (var i = 0; i < raw.length; i += bucketSize) {
      final chunk = raw.sublist(i, (i + bucketSize).clamp(0, raw.length));
      final avg = chunk.fold<double>(0, (s, e) => s + e.score) / chunk.length;
      out.add((label: _formatBucketLabel(chunk.first.key), score: avg));
    }
  }

  void _bucketScoresMonthly(
    List<({String key, double score})> raw,
    List<({String label, double score})> out,
  ) {
    final groups = <String, List<double>>{};
    for (final d in raw) {
      final monthKey = d.key.substring(0, 6); // YYYYMM
      groups.putIfAbsent(monthKey, () => []).add(d.score);
    }
    final sortedMonths = groups.keys.toList()..sort();
    for (final mk in sortedMonths) {
      final vals = groups[mk]!;
      final avg = vals.fold<double>(0, (s, v) => s + v) / vals.length;
      final y = mk.substring(0, 4);
      final m = mk.substring(4, 6);
      out.add((label: '$m/$y', score: avg));
    }
  }

  String _formatBucketLabel(String dayKey) {
    if (dayKey.length != 8) return dayKey;
    final month = int.tryParse(dayKey.substring(4, 6)) ?? 1;
    final day = int.tryParse(dayKey.substring(6, 8)) ?? 1;
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[month]} $day';
  }

  Future<(DateTime, DateTime)> _resolveRange({
    required MoodRange range,
    DateTime? from,
    DateTime? to,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (range) {
      case MoodRange.daily:
        return (today, today);
      case MoodRange.weekly:
        final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        return (startOfWeek, endOfWeek);
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
