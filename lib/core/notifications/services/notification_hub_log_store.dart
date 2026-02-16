import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/notification_lifecycle_event.dart';
import '../models/notification_log_entry.dart';

class NotificationHubLogStore {
  static const String _logKey = 'notification_hub_history_v1';

  Future<List<NotificationLogEntry>> getAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = (prefs.getString(_logKey) ?? '').trim();
      if (raw.isEmpty) {
        return const <NotificationLogEntry>[];
      }

      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <NotificationLogEntry>[];
      }

      final entries =
          decoded
              .whereType<Map<String, dynamic>>()
              .map(NotificationLogEntry.fromJson)
              .toList()
            ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return entries;
    } catch (_) {
      return const <NotificationLogEntry>[];
    }
  }

  Future<void> append(
    NotificationLogEntry entry, {
    int maxEntries = 1200,
  }) async {
    // getAll() may return a const empty list when history is empty.
    // Always clone to a growable list before mutating.
    final entries = List<NotificationLogEntry>.from(await getAll());
    if (_isRedundantScheduled(entries, entry)) {
      return;
    }
    entries.insert(0, entry);
    if (entries.length > maxEntries) {
      entries.removeRange(maxEntries, entries.length);
    }
    await _save(entries);
  }

  /// Removes redundant `scheduled` logs that share the same
  /// module/entity/notificationId/scheduledAt tuple.
  ///
  /// Returns the number of removed entries.
  Future<int> compactRedundantScheduledEntries() async {
    final entries = await getAll();
    if (entries.isEmpty) return 0;

    final seen = <String>{};
    final compacted = <NotificationLogEntry>[];

    for (final e in entries) {
      if (e.event != NotificationLifecycleEvent.scheduled) {
        compacted.add(e);
        continue;
      }

      final scheduledAt = _scheduledAt(e);
      if (scheduledAt.isEmpty) {
        compacted.add(e);
        continue;
      }

      final key =
          '${e.moduleId}|${e.entityId}|${e.notificationId ?? ''}|$scheduledAt';
      if (seen.add(key)) {
        compacted.add(e);
      }
    }

    var removed = entries.length - compacted.length;
    if (removed > 0) {
      await _save(compacted);
    }
    removed += await purgeLegacyCancelEntries();
    return removed;
  }

  /// Removes cancelled entries with source 'legacy_cancel' (task/habit bulk
  /// cancels). These add noise and aren't user-actionable.
  Future<int> purgeLegacyCancelEntries() async {
    final entries = await getAll();
    final kept = entries
        .where((e) {
          if (e.event != NotificationLifecycleEvent.cancelled) return true;
          return e.metadata['source'] != 'legacy_cancel';
        })
        .toList();
    final removed = entries.length - kept.length;
    if (removed > 0) {
      await _save(kept);
    }
    return removed;
  }

  Future<List<NotificationLogEntry>> query({
    String? moduleId,
    NotificationLifecycleEvent? event,
    DateTime? from,
    DateTime? to,
    String? search,
    int limit = 300,
  }) async {
    final entries = await getAll();
    final queryLower = search?.trim().toLowerCase();

    final filtered = entries.where((entry) {
      if (moduleId != null &&
          moduleId.isNotEmpty &&
          entry.moduleId != moduleId) {
        return false;
      }
      if (event != null && entry.event != event) {
        return false;
      }
      if (from != null && entry.timestamp.isBefore(from)) {
        return false;
      }
      if (to != null && !entry.timestamp.isBefore(to)) {
        return false;
      }
      if (queryLower != null && queryLower.isNotEmpty) {
        final haystack = <String>[
          entry.moduleId,
          entry.entityId,
          entry.title,
          entry.body,
          entry.payload ?? '',
          entry.actionId ?? '',
          entry.event.name,
        ].join(' ').toLowerCase();
        if (!haystack.contains(queryLower)) {
          return false;
        }
      }
      return true;
    }).toList();

    if (limit < filtered.length) {
      return filtered.sublist(0, limit);
    }
    return filtered;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_logKey);
  }

  /// Remove a single entry by id.
  Future<void> deleteById(String id) async {
    final entries = await getAll();
    final filtered = entries.where((e) => e.id != id).toList();
    await _save(filtered);
  }

  /// Remove multiple entries by id.
  Future<void> deleteByIds(Set<String> ids) async {
    if (ids.isEmpty) return;
    final entries = await getAll();
    final filtered = entries.where((e) => !ids.contains(e.id)).toList();
    await _save(filtered);
  }

  Future<void> _save(List<NotificationLogEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(entries.map((entry) => entry.toJson()).toList());
    await prefs.setString(_logKey, encoded);
  }

  bool _isRedundantScheduled(
    List<NotificationLogEntry> existing,
    NotificationLogEntry candidate,
  ) {
    if (candidate.event != NotificationLifecycleEvent.scheduled) {
      return false;
    }
    final candidateScheduledAt = _scheduledAt(candidate);
    if (candidateScheduledAt.isEmpty) {
      return false;
    }

    for (final e in existing) {
      if (e.event != NotificationLifecycleEvent.scheduled) {
        continue;
      }
      if (e.moduleId != candidate.moduleId || e.entityId != candidate.entityId) {
        continue;
      }
      if (e.notificationId != candidate.notificationId) {
        continue;
      }
      if (_scheduledAt(e) == candidateScheduledAt) {
        return true;
      }
    }
    return false;
  }

  String _scheduledAt(NotificationLogEntry entry) {
    final raw = entry.metadata['scheduledAt'];
    return raw is String ? raw : '';
  }
}
