import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/pending_notification_info.dart';
import '../../../../core/services/alarm_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/reminder_manager.dart';
import '../../../../data/repositories/task_repository.dart';
import '../../../../features/habits/data/repositories/habit_repository.dart';

/// Orphan entry: notification/alarm for a deleted task or habit.
/// Can come from Flutter (plugin + tracked) or native-only (AlarmBootReceiver).
class OrphanEntry {
  final int id;
  final String title;
  final String body;
  final String type;
  final String entityId;
  final DateTime? willFireAt;
  final bool isFromNative;

  OrphanEntry({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.entityId,
    this.willFireAt,
    this.isFromNative = false,
  });

  factory OrphanEntry.fromPendingInfo(PendingNotificationInfo info) =>
      OrphanEntry(
        id: info.id,
        title: info.title,
        body: info.body,
        type: info.type,
        entityId: info.entityId,
        willFireAt: info.willFireAt,
      );
}

/// Displays all pending notifications whose parent entity (Task or Habit) has
/// been deleted. These "orphaned" notifications keep firing even though the
/// entity no longer exists. The user can cancel them individually or in bulk.
///
/// Uses two data sources (per official Android docs, AlarmManager has no API to
/// list alarms; we read our own native persistence):
/// 1. Flutter: plugin + tracked_native_alarms
/// 2. Native: scheduled_alarms (AlarmBootReceiver) – often missed after reboot.
class HubOrphanedNotificationsPage extends StatefulWidget {
  /// Optional: pre-filter to a single type ('task' or 'habit').
  /// If null, shows all orphaned notifications.
  final String? filterType;

  const HubOrphanedNotificationsPage({super.key, this.filterType});

  @override
  State<HubOrphanedNotificationsPage> createState() =>
      _HubOrphanedNotificationsPageState();
}

class _HubOrphanedNotificationsPageState
    extends State<HubOrphanedNotificationsPage> {
  bool _loading = true;
  List<OrphanEntry> _orphans = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  // ─── Data Loading ──────────────────────────────────────────────────

  /// Parse type and entityId from payload (e.g. "habit|id|..." or "task|id|...").
  ({String type, String entityId}) _parsePayload(String payload) {
    final parts = payload.split('|');
    if (parts.length >= 2) {
      return (type: parts[0], entityId: parts[1]);
    }
    return (type: 'unknown', entityId: '');
  }

  Future<void> _scan() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final taskRepo = TaskRepository();
      final habitRepo = HabitRepository();

      final allTasks = await taskRepo.getAllTasks();
      final allHabits = await habitRepo.getAllHabits(includeArchived: true);

      final taskIds = allTasks.map((t) => t.id).toSet();
      final habitIds = allHabits.map((h) => h.id).toSet();
      final seenIds = <int>{};
      final orphans = <OrphanEntry>[];

      // 1. Flutter sources (plugin + tracked_native_alarms)
      final notificationService = NotificationService();
      final all = await notificationService.getDetailedPendingNotifications();

      for (final info in all) {
        if (info.entityId.isEmpty) continue;

        final isOrphan = (info.type == 'task' && !taskIds.contains(info.entityId)) ||
            (info.type == 'habit' && !habitIds.contains(info.entityId));

        if (!isOrphan) continue;

        if (widget.filterType != null && info.type != widget.filterType) {
          continue;
        }

        seenIds.add(info.id);
        orphans.add(OrphanEntry.fromPendingInfo(info));
      }

      // 2. Native-only alarms (AlarmBootReceiver – Android has no API to list
      //    AlarmManager alarms; we read our own persistence)
      if (Platform.isAndroid) {
        final nativeAlarms =
            await AlarmService().getScheduledAlarmsFromNative();

        for (final alarm in nativeAlarms) {
          final id = (alarm['id'] as num?)?.toInt();
          if (id == null || seenIds.contains(id)) continue;

          final payload = alarm['payload'] as String? ?? '';
          final parsed = _parsePayload(payload);
          if (parsed.entityId.isEmpty) continue;
          if (parsed.type != 'task' && parsed.type != 'habit') continue;

          final isOrphan = (parsed.type == 'task' && !taskIds.contains(parsed.entityId)) ||
              (parsed.type == 'habit' && !habitIds.contains(parsed.entityId));

          if (!isOrphan) continue;

          if (widget.filterType != null && parsed.type != widget.filterType) {
            continue;
          }

          seenIds.add(id);
          final triggerMs = (alarm['triggerTime'] as num?)?.toInt();
          orphans.add(OrphanEntry(
            id: id,
            title: alarm['title'] as String? ?? 'Alarm',
            body: alarm['body'] as String? ?? '',
            type: parsed.type,
            entityId: parsed.entityId,
            willFireAt: triggerMs != null
                ? DateTime.fromMillisecondsSinceEpoch(triggerMs)
                : null,
            isFromNative: true,
          ));
        }
      }

      // Sort: soonest fire-time first.
      orphans.sort((a, b) {
        if (a.willFireAt != null && b.willFireAt != null) {
          return a.willFireAt!.compareTo(b.willFireAt!);
        }
        if (a.willFireAt != null) return -1;
        if (b.willFireAt != null) return 1;
        return a.id.compareTo(b.id);
      });

      if (mounted) {
        setState(() {
          _orphans = orphans;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  // ─── Cancel Actions ────────────────────────────────────────────────

  Future<void> _cancelOne(OrphanEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel This Notification?'),
        content: Text(
          'Cancel "${entry.title}" (ID: ${entry.id})?\n\n'
          'The parent ${entry.type} was deleted, so this notification is stale.'
          '${entry.isFromNative ? "\n\n(Stored in native alarm backup.)" : ""}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel It'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      HapticFeedback.mediumImpact();

      if (entry.isFromNative) {
        await AlarmService().cancelAlarm(entry.id);
      } else {
        await ReminderManager().cancelPendingNotificationById(
          notificationId: entry.id,
          entityId: entry.entityId.isNotEmpty ? entry.entityId : null,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cancelled: ${entry.title}'),
            backgroundColor: Colors.green,
          ),
        );
        _scan();
      }
    }
  }

  Future<void> _cancelAll() async {
    if (_orphans.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel All Orphaned Notifications?'),
        content: Text(
          'This will cancel ${_orphans.length} notification(s) whose '
          'parent task or habit no longer exists.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel All'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      HapticFeedback.heavyImpact();
      setState(() => _loading = true);

      var cancelled = 0;

      for (final entry in _orphans) {
        try {
          if (entry.isFromNative) {
            await AlarmService().cancelAlarm(entry.id);
          } else {
            await ReminderManager().cancelPendingNotificationById(
              notificationId: entry.id,
              entityId: entry.entityId.isNotEmpty ? entry.entityId : null,
            );
          }
          cancelled++;
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cancelled $cancelled orphaned notification(s)'),
            backgroundColor: Colors.green,
          ),
        );
        _scan();
      }
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final typeLabel = widget.filterType != null
        ? '${widget.filterType![0].toUpperCase()}${widget.filterType!.substring(1)}'
        : null;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0D0F14) : const Color(0xFFF8F9FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: theme.colorScheme.onSurface,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.link_off_rounded,
                color: Colors.orange,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                typeLabel != null
                    ? 'Orphaned $typeLabel Notifications'
                    : 'Orphaned Notifications',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  color: theme.colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _scan,
            icon: Icon(
              Icons.refresh_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 48, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(
                'Failed to scan notifications',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _scan,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_orphans.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_outline_rounded,
                  size: 48,
                  color: Colors.green.shade400,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No Orphaned Notifications',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'All pending notifications belong to existing tasks and habits.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Header bar with count + bulk cancel
        _buildHeader(isDark),
        // List
        Expanded(
          child: RefreshIndicator(
            onRefresh: _scan,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: _orphans.length,
              itemBuilder: (context, index) =>
                  _buildOrphanCard(_orphans[index], isDark),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Colors.orange, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_orphans.length} orphaned notification${_orphans.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'These notify for deleted tasks/habits',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _cancelAll,
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            child: const Text(
              'Cancel All',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrphanCard(OrphanEntry entry, bool isDark) {
    final isTask = entry.type == 'task';
    final typeColor = isTask ? Colors.blue : Colors.deepPurple;
    final typeIcon =
        isTask ? Icons.task_alt_rounded : Icons.auto_awesome_rounded;

    final fireTimeStr = entry.willFireAt != null
        ? _formatFireTime(entry.willFireAt!)
        : 'Unknown fire time';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D23) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showDetail(entry),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    children: [
                      Center(child: Icon(typeIcon, color: typeColor, size: 22)),
                      Positioned(
                        right: -1,
                        bottom: -1,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color:
                                isDark ? const Color(0xFF1A1D23) : Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.link_off_rounded,
                            size: 13,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (entry.body.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          entry.body,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildChip(
                              label: entry.type.toUpperCase(),
                              color: typeColor,
                              isDark: isDark,
                            ),
                            const SizedBox(width: 6),
                            _buildChip(
                              label: fireTimeStr,
                              color: _fireTimeColor(entry.willFireAt),
                              isDark: isDark,
                            ),
                            if (entry.isFromNative) ...[
                              const SizedBox(width: 6),
                              _buildChip(
                                label: 'NATIVE',
                                color: Colors.orange,
                                isDark: isDark,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Cancel button
                IconButton(
                  onPressed: () => _cancelOne(entry),
                  icon: const Icon(Icons.cancel_rounded, size: 22),
                  color: Colors.red.shade400,
                  tooltip: 'Cancel this notification',
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Color _fireTimeColor(DateTime? dt) {
    if (dt == null) return Colors.grey;
    if (dt.isBefore(DateTime.now())) return Colors.red;
    if (dt.isBefore(DateTime.now().add(const Duration(hours: 1)))) {
      return Colors.orange;
    }
    return Colors.green;
  }

  String _formatFireTime(DateTime dt) {
    final now = DateTime.now();
    final diff = dt.difference(now);

    if (diff.isNegative) {
      final absDiff = diff.abs();
      if (absDiff.inMinutes < 60) return '${absDiff.inMinutes}m ago';
      if (absDiff.inHours < 24) return '${absDiff.inHours}h ago';
      return DateFormat('MMM d, HH:mm').format(dt);
    }

    if (diff.inMinutes < 60) return 'In ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'In ${diff.inHours}h';
    return DateFormat('MMM d, HH:mm').format(dt);
  }

  void _showDetail(OrphanEntry entry) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.7,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D23) : Colors.white,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Row(
                    children: [
                      Icon(
                        Icons.link_off_rounded,
                        color: Colors.orange,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Orphaned Notification',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _detailRow('Title', entry.title, isDark),
                  if (entry.body.isNotEmpty)
                    _detailRow('Body', entry.body, isDark),
                  _detailRow('Type', entry.type.toUpperCase(), isDark),
                  _detailRow('Notification ID', '${entry.id}', isDark),
                  _detailRow('Entity ID', entry.entityId, isDark),
                  _detailRow(
                    'Status',
                    'Parent ${entry.type} DELETED',
                    isDark,
                    valueColor: Colors.red,
                  ),
                  if (entry.willFireAt != null)
                    _detailRow(
                      'Fires at',
                      DateFormat('EEE, MMM d yyyy – HH:mm')
                          .format(entry.willFireAt!),
                      isDark,
                    ),
                  if (entry.isFromNative)
                    _detailRow('Source', 'Native alarm backup', isDark,
                        valueColor: Colors.orange),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _cancelOne(entry);
                      },
                      icon:
                          const Icon(Icons.cancel_rounded, size: 18),
                      label: const Text('Cancel This Notification'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(
    String label,
    String value,
    bool isDark, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ??
                    (isDark ? Colors.white : Colors.black87),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
