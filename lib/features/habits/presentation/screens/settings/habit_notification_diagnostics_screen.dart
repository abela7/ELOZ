import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/notifications/notifications.dart';
import '../../../../../core/models/notification_settings.dart';
import '../../../../../core/models/pending_notification_info.dart';
import '../../../../../core/services/reminder_manager.dart';
import '../../../../../core/theme/color_schemes.dart';
import '../../../../../core/theme/dark_gradient.dart';
import '../../../data/repositories/habit_repository.dart';
import '../../../providers/habit_notification_settings_provider.dart';

/// Habit Notification Diagnostics Screen
///
/// Full-featured diagnostics for habit notifications:
/// - Status summary dashboard (pending, special, blocked, quiet hours)
/// - **Smart grouping** – recurring habits are collapsed by habit (entityId)
///   with occurrence count, next-fire time, and expand/collapse toggle.
/// - Search / filter / sort
/// - Journey stages visualization per notification
/// - Notification preview mockup
/// - Test configuration with channel / sound / delay overrides
/// - Detail page for each notification
class HabitNotificationDiagnosticsScreen extends ConsumerStatefulWidget {
  const HabitNotificationDiagnosticsScreen({super.key});

  @override
  ConsumerState<HabitNotificationDiagnosticsScreen> createState() =>
      _HabitNotificationDiagnosticsScreenState();
}

// ─── Group model ────────────────────────────────────────────────────────────
/// Groups all notifications for a single habit (same entityId).
class _HabitNotificationGroup {
  final String entityId;
  final String habitTitle;
  final List<PendingNotificationInfo> notifications;

  _HabitNotificationGroup({
    required this.entityId,
    required this.habitTitle,
    required this.notifications,
  });

  int get count => notifications.length;
  bool get hasSpecial => notifications.any((n) => n.isSpecial);
  int get blockedCount =>
      notifications.where((n) => n.willBeBlockedByQuietHours).length;

  /// The soonest notification in this group.
  PendingNotificationInfo? get nextNotification {
    if (notifications.isEmpty) return null;
    final sorted = [...notifications]
      ..sort((a, b) {
        if (a.willFireAt == null && b.willFireAt == null) return 0;
        if (a.willFireAt == null) return 1;
        if (b.willFireAt == null) return -1;
        return a.willFireAt!.compareTo(b.willFireAt!);
      });
    return sorted.first;
  }

  DateTime? get nextFireAt => nextNotification?.willFireAt;
}

class _HabitNotificationDiagnosticsScreenState
    extends ConsumerState<HabitNotificationDiagnosticsScreen> {
  List<PendingNotificationInfo>? _notifications;
  bool _isLoading = true;
  String? _error;
  int? _firingId;
  bool _isClearingAll = false;

  // Search / filter / sort
  String _searchQuery = '';
  String _filterChannel = 'all';
  String _sortBy = 'time';
  bool _sortAscending = true;
  bool _filtersExpanded = false;

  // Expand/collapse state for groups (entityId -> expanded)
  final Map<String, bool> _expandedGroups = {};

  // Channel/Sound/Delay overrides for testing (per notification)
  final Map<int, String> _channelOverrides = {};
  final Map<int, String> _soundOverrides = {};
  final Map<int, int> _delayOverrides = {};

  // Available options
  late List<Map<String, String>> _availableChannels;
  late List<Map<String, String>> _availableSounds;
  late List<Map<String, dynamic>> _delayOptions;

  @override
  void initState() {
    super.initState();
    _availableChannels = ReminderManager().getAvailableChannels();
    _availableSounds = ReminderManager().getAvailableSounds();
    _delayOptions = ReminderManager().getDelayOptions();
    _loadNotifications();
    _loadSoundsAsync();
  }

  Future<void> _loadSoundsAsync() async {
    final sounds = await ReminderManager().getAvailableSoundsAsync();
    if (mounted) {
      setState(() => _availableSounds = sounds);
    }
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final all = await ReminderManager().getDetailedPendingNotifications();
      final habitOnly = _filterHabitNotifications(all);
      if (mounted) {
        setState(() {
          _notifications = habitOnly;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  List<PendingNotificationInfo> _filterHabitNotifications(
    List<PendingNotificationInfo> notifications,
  ) {
    return notifications.where(_isHabitNotification).toList();
  }

  bool _isHabitNotification(PendingNotificationInfo info) {
    if (info.type == NotificationHubModuleIds.habit) {
      return true;
    }
    final payload = info.payload;
    if (payload != null &&
        payload.startsWith('${NotificationHubModuleIds.habit}|')) {
      return true;
    }
    final parsed = NotificationHubPayload.tryParse(payload);
    if (parsed?.moduleId == NotificationHubModuleIds.habit) {
      return true;
    }
    final trackedType = info.metadata['type'] as String?;
    if (trackedType == NotificationHubModuleIds.habit) {
      return true;
    }
    return info.channelKey.startsWith('habit_');
  }

  Future<void> _clearAllPendingHabitNotifications() async {
    final pending = List<PendingNotificationInfo>.from(
      _notifications ?? const <PendingNotificationInfo>[],
    );
    if (pending.isEmpty || _isClearingAll) return;

    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear Pending Habit Notifications'),
        content: Text(
          'This will clear ${pending.length} pending habit notification${pending.length == 1 ? '' : 's'} from the device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF5350),
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (shouldClear != true || !mounted) return;

    setState(() => _isClearingAll = true);
    try {
      final reminderManager = ReminderManager();
      for (final info in pending) {
        await reminderManager.cancelPendingNotificationById(
          notificationId: info.id,
          entityId: info.entityId.isEmpty ? null : info.entityId,
        );
      }

      await NotificationHub().cancelForModule(
        moduleId: NotificationHubModuleIds.habit,
      );

      final habitRepo = HabitRepository();
      final allHabits = await habitRepo.getAllHabits(includeArchived: true);
      final activeHabitIds = allHabits.map((h) => h.id).toSet();
      final orphanEntityIds = pending
          .map((n) => n.entityId.trim())
          .where((id) => id.isNotEmpty && !activeHabitIds.contains(id))
          .toSet();

      if (orphanEntityIds.isNotEmpty) {
        final repo = UniversalNotificationRepository();
        for (final entityId in orphanEntityIds) {
          await repo.deleteByEntity(entityId);
        }
      }

      await _loadNotifications();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cleared ${pending.length} pending habit notification${pending.length == 1 ? '' : 's'}.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to clear pending notifications: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFEF5350),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isClearingAll = false);
      }
    }
  }

  Future<void> _fireNotification(PendingNotificationInfo info) async {
    setState(() => _firingId = info.id);
    HapticFeedback.mediumImpact();

    final channelOverride = _channelOverrides[info.id];
    final soundOverride = _soundOverrides[info.id];
    final delaySeconds = _delayOverrides[info.id] ?? 2;

    final channelDesc = channelOverride ?? info.channelKey;
    final soundDesc = soundOverride ?? info.soundKey;

    try {
      await ReminderManager().fireNotificationNow(
        info: info,
        channelOverride: channelOverride,
        soundOverride: soundOverride,
        delaySeconds: delaySeconds,
      );

      if (mounted) {
        final isAlarm =
            info.isSpecial ||
            (info.useAlarmMode &&
                (channelOverride ?? info.channelKey) ==
                    'habit_urgent_reminders');

        String delayText;
        String tipText;
        if (delaySeconds <= 3) {
          delayText = 'Fires in $delaySeconds seconds';
          tipText = 'Watch for the notification';
        } else if (delaySeconds <= 30) {
          delayText = 'Fires in $delaySeconds seconds';
          tipText = 'Try locking your phone now';
        } else if (delaySeconds <= 60) {
          delayText =
              'Fires in ${delaySeconds}s (${delaySeconds ~/ 60}m ${delaySeconds % 60}s)';
          tipText = 'You can close or kill the app now';
        } else {
          final mins = delaySeconds ~/ 60;
          delayText = 'Fires in $mins minute${mins > 1 ? 's' : ''}';
          tipText = 'Close app & lock phone to test deep sleep';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  isAlarm
                      ? Icons.alarm_rounded
                      : Icons.notifications_active_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        delayText,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        tipText,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Channel: $channelDesc • Sound: $soundDesc',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: delaySeconds > 10
                ? const Color(0xFF7E57C2)
                : const Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: Duration(seconds: delaySeconds > 10 ? 5 : 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _firingId = null);
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = ref.watch(habitNotificationSettingsProvider);

    final content = Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, isDark),
            _buildStatusSummary(context, isDark, settings),
            _buildFilterBar(context, isDark),
            Expanded(child: _buildNotificationList(context, isDark)),
          ],
        ),
      ),
    );

    return isDark
        ? DarkGradient.wrap(child: content)
        : Container(color: const Color(0xFFF5F5F5), child: content);
  }

  // ── Header ─────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.arrow_back_rounded,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Habit Diagnostics',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                Text(
                  'Preview & test pending habit notifications',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loadNotifications,
            icon: Icon(
              Icons.refresh_rounded,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed:
                (_notifications == null || _notifications!.isEmpty || _isClearingAll)
                ? null
                : _clearAllPendingHabitNotifications,
            icon: _isClearingAll
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.delete_sweep_rounded,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
            tooltip: 'Clear pending habit notifications',
          ),
        ],
      ),
    );
  }

  // ── Status Summary ─────────────────────────────────────────────────────

  Widget _buildStatusSummary(
    BuildContext context,
    bool isDark,
    dynamic settings,
  ) {
    final count = _notifications?.length ?? 0;
    final blockedCount =
        _notifications?.where((n) => n.willBeBlockedByQuietHours).length ?? 0;
    final specialCount = _notifications?.where((n) => n.isSpecial).length ?? 0;
    final nativeCount =
        _notifications
            ?.where((n) => n.metadata['trackedSource'] == 'native_alarm')
            .length ??
        0;
    final flutterCount = count - nativeCount;
    final habitCount = _buildGroups().length;

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2230) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.05),
            ),
          ),
          child: Row(
            children: [
              _buildStatusItem(
                context,
                isDark,
                habitCount.toString(),
                'Habits',
                Icons.self_improvement_rounded,
                AppColorSchemes.primaryGold,
              ),
              _buildStatusDivider(isDark),
              _buildStatusItem(
                context,
                isDark,
                count.toString(),
                'Scheduled',
                Icons.schedule_rounded,
                const Color(0xFF42A5F5),
              ),
              _buildStatusDivider(isDark),
              _buildStatusItem(
                context,
                isDark,
                specialCount.toString(),
                'Special',
                Icons.star_rounded,
                const Color(0xFFFFB74D),
              ),
              _buildStatusDivider(isDark),
              _buildStatusItem(
                context,
                isDark,
                blockedCount.toString(),
                'Blocked',
                Icons.block_rounded,
                const Color(0xFFEF5350),
              ),
              _buildStatusDivider(isDark),
              _buildStatusItem(
                context,
                isDark,
                settings.isInQuietHours() ? 'ON' : 'OFF',
                'Quiet Hrs',
                Icons.bedtime_rounded,
                settings.isInQuietHours()
                    ? const Color(0xFF7E57C2)
                    : const Color(0xFF4CAF50),
              ),
            ],
          ),
        ),
        if (count > 0)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF42A5F5).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF42A5F5).withOpacity(0.2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: Color(0xFF42A5F5),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Flutter: $flutterCount • Native: $nativeCount • Grouped into $habitCount habit${habitCount != 1 ? 's' : ''}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildStatusItem(
    BuildContext context,
    bool isDark,
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDivider(bool isDark) {
    return Container(
      width: 1,
      height: 40,
      color: isDark ? Colors.white12 : Colors.black12,
    );
  }

  // ── Filter Bar ─────────────────────────────────────────────────────────

  Widget _buildFilterBar(BuildContext context, bool isDark) {
    final hasActiveFilters =
        _searchQuery.isNotEmpty ||
        _filterChannel != 'all' ||
        _sortBy != 'time' ||
        !_sortAscending;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2230) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasActiveFilters
              ? AppColorSchemes.primaryGold.withOpacity(0.3)
              : (isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.05)),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() => _filtersExpanded = !_filtersExpanded);
              HapticFeedback.selectionClick();
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    Icons.filter_list_rounded,
                    size: 20,
                    color: hasActiveFilters
                        ? AppColorSchemes.primaryGold
                        : (isDark ? Colors.white54 : Colors.black54),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      hasActiveFilters
                          ? _getActiveFiltersText()
                          : 'Search & Filter',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: hasActiveFilters
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: hasActiveFilters
                            ? AppColorSchemes.primaryGold
                            : (isDark ? Colors.white : Colors.black),
                      ),
                    ),
                  ),
                  if (hasActiveFilters)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _searchQuery = '';
                          _filterChannel = 'all';
                          _sortBy = 'time';
                          _sortAscending = true;
                        });
                        HapticFeedback.lightImpact();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: AppColorSchemes.primaryGold.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'CLEAR',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppColorSchemes.primaryGold,
                          ),
                        ),
                      ),
                    ),
                  Icon(
                    _filtersExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ],
              ),
            ),
          ),
          if (_filtersExpanded) ...[
            Divider(
              height: 1,
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.1),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  TextField(
                    controller: TextEditingController(text: _searchQuery)
                      ..selection = TextSelection.fromPosition(
                        TextPosition(offset: _searchQuery.length),
                      ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    decoration: InputDecoration(
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                      hintText: 'Search by title...',
                      hintStyle: TextStyle(
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.04),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildFilterDropdown(
                          context,
                          isDark,
                          value: _filterChannel,
                          items: [
                            {'key': 'all', 'label': 'All Channels'},
                            ..._availableChannels.map(
                              (c) => {'key': c['key']!, 'label': c['name']!},
                            ),
                          ],
                          onChanged: (value) =>
                              setState(() => _filterChannel = value ?? 'all'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildFilterDropdown(
                          context,
                          isDark,
                          value: _sortBy,
                          items: const [
                            {'key': 'time', 'label': 'Sort: Time'},
                            {'key': 'status', 'label': 'Sort: Status'},
                          ],
                          onChanged: (value) =>
                              setState(() => _sortBy = value ?? 'time'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () =>
                            setState(() => _sortAscending = !_sortAscending),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.05)
                                : Colors.black.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _sortAscending
                                    ? Icons.arrow_upward_rounded
                                    : Icons.arrow_downward_rounded,
                                size: 16,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _sortAscending ? 'Asc' : 'Desc',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getActiveFiltersText() {
    final filters = <String>[];
    if (_searchQuery.isNotEmpty) {
      filters.add(
        'Search: "${_searchQuery.length > 15 ? '${_searchQuery.substring(0, 15)}...' : _searchQuery}"',
      );
    }
    if (_filterChannel != 'all') {
      final channel = _availableChannels.firstWhere(
        (c) => c['key'] == _filterChannel,
        orElse: () => {'name': _filterChannel},
      );
      filters.add(channel['name']!);
    }
    if (_sortBy != 'time' || !_sortAscending) {
      filters.add('Sort: $_sortBy ${_sortAscending ? '↑' : '↓'}');
    }
    return filters.join(' • ');
  }

  Widget _buildFilterDropdown(
    BuildContext context,
    bool isDark, {
    required String value,
    required List<Map<String, String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: isDark ? const Color(0xFF2A2D3A) : Colors.white,
          icon: Icon(
            Icons.expand_more_rounded,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
          items: items
              .map(
                (item) => DropdownMenuItem(
                  value: item['key'],
                  child: Text(
                    item['label'] ?? item['key'] ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ── Grouping & Filtering ──────────────────────────────────────────────

  List<PendingNotificationInfo> _getFilteredNotifications() {
    final source = _notifications ?? const [];
    final query = _searchQuery.trim().toLowerCase();

    return source.where((n) {
      if (query.isNotEmpty && !n.title.toLowerCase().contains(query)) {
        return false;
      }
      if (_filterChannel != 'all' && n.channelKey != _filterChannel) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Build groups from the (already filtered) notification list.
  List<_HabitNotificationGroup> _buildGroups() {
    final filtered = _getFilteredNotifications();
    final groupMap = <String, List<PendingNotificationInfo>>{};

    for (final n in filtered) {
      final groupKey = n.entityId.trim().isEmpty ? '__unknown_${n.id}' : n.entityId;
      groupMap.putIfAbsent(groupKey, () => []).add(n);
    }

    final groups = groupMap.entries.map((e) {
      // Sort notifications within the group by fire time
      final sorted = [...e.value]
        ..sort((a, b) {
          if (a.willFireAt == null && b.willFireAt == null) return 0;
          if (a.willFireAt == null) return 1;
          if (b.willFireAt == null) return -1;
          return a.willFireAt!.compareTo(b.willFireAt!);
        });
      return _HabitNotificationGroup(
        entityId: e.key,
        habitTitle: sorted.first.title,
        notifications: sorted,
      );
    }).toList();

    // Sort groups
    groups.sort((a, b) {
      int cmp;
      switch (_sortBy) {
        case 'status':
          int statusRank(_HabitNotificationGroup g) {
            if (g.blockedCount > 0) return 0;
            if (g.hasSpecial) return 1;
            return 2;
          }
          cmp = statusRank(a).compareTo(statusRank(b));
          break;
        case 'time':
        default:
          final at = a.nextFireAt;
          final bt = b.nextFireAt;
          if (at == null && bt == null) {
            cmp = 0;
          } else if (at == null) {
            cmp = 1;
          } else if (bt == null) {
            cmp = -1;
          } else {
            cmp = at.compareTo(bt);
          }
      }
      return _sortAscending ? cmp : -cmp;
    });

    return groups;
  }

  // ── Notification List ──────────────────────────────────────────────────

  Widget _buildNotificationList(BuildContext context, bool isDark) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColorSchemes.primaryGold),
            SizedBox(height: 16),
            Text('Loading habit notifications...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading notifications',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadNotifications,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_notifications == null || _notifications!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.notifications_off_rounded,
                size: 56,
                color: isDark ? Colors.white24 : Colors.black26,
              ),
              const SizedBox(height: 12),
              Text(
                'No Pending Habit Notifications',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Create a habit with a reminder to see it here.\nMake sure "Habit Time" is enabled and a reminder is selected.',
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

    final groups = _buildGroups();

    if (groups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 48,
                color: isDark ? Colors.white24 : Colors.black26,
              ),
              const SizedBox(height: 12),
              Text(
                'No results',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Try adjusting filters or search',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: groups.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final group = groups[index];
          return _buildGroupCard(context, isDark, group);
        },
      ),
    );
  }

  // ── Group Card ────────────────────────────────────────────────────────

  Widget _buildGroupCard(
    BuildContext context,
    bool isDark,
    _HabitNotificationGroup group,
  ) {
    final isExpanded = _expandedGroups[group.entityId] ?? false;
    final next = group.nextNotification;
    final nextTimeLabel = next?.willFireAt != null
        ? _formatFireTimeShort(next!.willFireAt!)
        : 'Unknown';

    // Group-level status color
    final statusColor = group.hasSpecial
        ? const Color(0xFFFFB74D)
        : (group.blockedCount > 0
              ? const Color(0xFFEF5350)
              : const Color(0xFF4CAF50));

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2230) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: group.blockedCount > 0
              ? const Color(0xFFEF5350).withOpacity(0.3)
              : (isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.05)),
        ),
      ),
      child: Column(
        children: [
          // ── Group header (always visible) ──
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              setState(() {
                _expandedGroups[group.entityId] = !isExpanded;
              });
              HapticFeedback.selectionClick();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  // Status icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      group.hasSpecial
                          ? Icons.star_rounded
                          : Icons.self_improvement_rounded,
                      color: statusColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Title and info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.habitTitle,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 12,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Next: $nextTimeLabel',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Count badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColorSchemes.primaryGold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.notifications_active_rounded,
                          size: 12,
                          color: AppColorSchemes.primaryGold,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${group.count}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColorSchemes.primaryGold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (group.blockedCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF5350).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${group.blockedCount} blocked',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEF5350),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 6),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded: individual notifications ──
          if (isExpanded) ...[
            Divider(
              height: 1,
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.06),
            ),
            ...group.notifications.map(
              (info) => _buildNotificationSubItem(context, isDark, info),
            ),
          ],
        ],
      ),
    );
  }

  /// A compact list item for a single notification inside an expanded group.
  Widget _buildNotificationSubItem(
    BuildContext context,
    bool isDark,
    PendingNotificationInfo info,
  ) {
    final timeLabel = info.willFireAt != null
        ? _formatFireTimeShort(info.willFireAt!)
        : 'Time unknown';

    return InkWell(
      onTap: () => _openNotificationDetail(context, info),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDark
                  ? Colors.white.withOpacity(0.04)
                  : Colors.black.withOpacity(0.04),
            ),
          ),
        ),
        child: Row(
          children: [
            // Date indicator
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: info.willBeBlockedByQuietHours
                    ? const Color(0xFFEF5350).withOpacity(0.1)
                    : (isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.04)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: info.willFireAt != null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${info.willFireAt!.day}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              height: 1.1,
                              color: info.willBeBlockedByQuietHours
                                  ? const Color(0xFFEF5350)
                                  : (isDark ? Colors.white70 : Colors.black87),
                            ),
                          ),
                          Text(
                            _monthAbbr(info.willFireAt!.month),
                            style: TextStyle(
                              fontSize: 8,
                              height: 1.1,
                              color: info.willBeBlockedByQuietHours
                                  ? const Color(0xFFEF5350)
                                  : (isDark ? Colors.white38 : Colors.black45),
                            ),
                          ),
                        ],
                      )
                    : Icon(
                        Icons.help_outline_rounded,
                        size: 14,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            // Time and reminder type
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    timeLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  Text(
                    info.getReminderDescription(),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Color(info.statusColor).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                info.willBeBlockedByQuietHours
                    ? 'Blocked'
                    : (info.isSpecial ? 'Special' : 'Ready'),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Color(info.statusColor),
                ),
              ),
            ),
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              tooltip: 'Notification actions',
              onSelected: (value) async {
                if (value == 'edit') {
                  await _editNotification(context, info);
                } else if (value == 'delete') {
                  await _deleteNotification(context, info);
                }
              },
              itemBuilder: (menuContext) => const [
                PopupMenuItem<String>(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 16),
                      SizedBox(width: 8),
                      Text('Edit time'),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline_rounded,
                        size: 16,
                        color: Color(0xFFEF5350),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Delete',
                        style: TextStyle(color: Color(0xFFEF5350)),
                      ),
                    ],
                  ),
                ),
              ],
              icon: Icon(
                Icons.more_vert_rounded,
                size: 18,
                color: isDark ? Colors.white24 : Colors.black26,
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _editNotification(
    BuildContext context,
    PendingNotificationInfo info,
  ) async {
    final now = DateTime.now();
    final initialDateTime =
        (info.willFireAt != null && info.willFireAt!.isAfter(now))
        ? info.willFireAt!
        : now.add(const Duration(minutes: 15));

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDateTime,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (pickedDate == null) return false;

    if (!mounted) return false;
    final pickedTime = await showTimePicker(
      context: this.context,
      initialTime: TimeOfDay.fromDateTime(initialDateTime),
    );
    if (pickedTime == null) return false;

    final newFireAt = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    if (!newFireAt.isAfter(DateTime.now())) {
      if (mounted) {
        ScaffoldMessenger.of(this.context).showSnackBar(
          const SnackBar(
            content: Text('Please select a future time.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }

    try {
      await ReminderManager().reschedulePendingNotification(
        info: info,
        scheduledAt: newFireAt,
        channelKeyOverride: _channelOverrides[info.id],
      );

      if (!mounted) return false;
      await _loadNotifications();

      if (!mounted) return false;
      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(
          content: Text('Notification updated successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(
            content: Text('Failed to update notification: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFEF5350),
          ),
        );
      }
      return false;
    }
  }

  Future<bool> _deleteNotification(
    BuildContext context,
    PendingNotificationInfo info,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Notification'),
        content: Text(
          'Delete this scheduled notification for "${info.title}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFEF5350),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return false;

    try {
      await ReminderManager().cancelPendingNotificationById(
        notificationId: info.id,
        entityId: info.entityId,
      );

      if (!mounted) return false;
      setState(() {
        _channelOverrides.remove(info.id);
        _soundOverrides.remove(info.id);
        _delayOverrides.remove(info.id);
        _notifications?.removeWhere((n) => n.id == info.id);
      });

      await _loadNotifications();

      if (!mounted) return false;
      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(
          content: Text('Notification deleted.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete notification: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFEF5350),
          ),
        );
      }
      return false;
    }
  }

  static String _monthAbbr(int month) {
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
    return months[month];
  }

  // ── Detail Page ────────────────────────────────────────────────────────

  Future<void> _openNotificationDetail(
    BuildContext context,
    PendingNotificationInfo info,
  ) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => _HabitDiagnosticsDetailPage(
          info: info,
          isDark: Theme.of(context).brightness == Brightness.dark,
          buildJourneyStages: _buildJourneyStages,
          buildNotificationPreview: _buildNotificationPreview,
          availableChannels: _availableChannels,
          availableSounds: _availableSounds,
          delayOptions: _delayOptions,
          initialChannel: _channelOverrides[info.id],
          initialSound: _soundOverrides[info.id],
          initialDelay: _delayOverrides[info.id],
          onConfigChanged: (channel, sound, delay) {
            setState(() {
              if (channel != null) {
                _channelOverrides[info.id] = channel;
              } else {
                _channelOverrides.remove(info.id);
              }
              if (sound != null) {
                _soundOverrides[info.id] = sound;
              } else {
                _soundOverrides.remove(info.id);
              }
              if (delay != null && delay > 2) {
                _delayOverrides[info.id] = delay;
              } else {
                _delayOverrides.remove(info.id);
              }
            });
          },
          onFire: () => _fireNotification(info),
          isFiring: () => _firingId == info.id,
          onEditNotification: () => _editNotification(context, info),
          onDeleteNotification: () => _deleteNotification(context, info),
        ),
      ),
    );

    if (changed == true && mounted) {
      await _loadNotifications();
    }
  }

  // ── Journey Stages ─────────────────────────────────────────────────────

  Widget _buildJourneyStages(
    BuildContext context,
    bool isDark,
    PendingNotificationInfo info,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          _buildJourneyStage(
            context,
            isDark,
            '1',
            'SCHEDULE',
            info.willFireAt != null
                ? _formatFireTime(info.willFireAt!)
                : 'Time unknown',
            Icons.schedule_rounded,
            const Color(0xFF42A5F5),
            isCompleted: true,
          ),
          _buildJourneyStage(
            context,
            isDark,
            '2',
            'QUIET HOURS',
            info.quietHoursStatus,
            Icons.bedtime_rounded,
            info.willBeBlockedByQuietHours
                ? const Color(0xFFEF5350)
                : const Color(0xFF4CAF50),
            isCompleted: true,
            isBlocked: info.willBeBlockedByQuietHours,
          ),
          _buildJourneyStage(
            context,
            isDark,
            '3',
            'CHANNEL',
            '${info.channelName} • ${info.soundName} • ${NotificationSettings.getAudioStreamDisplayName(info.audioStream)}',
            Icons.campaign_rounded,
            const Color(0xFFFFB74D),
            isCompleted: !info.willBeBlockedByQuietHours,
            isBlocked: info.willBeBlockedByQuietHours,
          ),
          _buildJourneyStage(
            context,
            isDark,
            '4',
            'BUILD',
            info.useAlarmMode ? 'Alarm Mode ON' : 'Standard Notification',
            Icons.build_rounded,
            const Color(0xFF7E57C2),
            isCompleted: !info.willBeBlockedByQuietHours,
            isBlocked: info.willBeBlockedByQuietHours,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildJourneyStage(
    BuildContext context,
    bool isDark,
    String number,
    String label,
    String value,
    IconData icon,
    Color color, {
    bool isCompleted = false,
    bool isBlocked = false,
    bool isLast = false,
  }) {
    final effectiveColor = isBlocked ? Colors.grey : color;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: effectiveColor.withOpacity(isCompleted ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: effectiveColor.withOpacity(isCompleted ? 0.5 : 0.2),
                ),
              ),
              child: Center(
                child: isBlocked
                    ? const Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: Colors.grey,
                      )
                    : Text(
                        number,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: effectiveColor,
                        ),
                      ),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 24,
                color: effectiveColor.withOpacity(0.2),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 14, color: effectiveColor),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: effectiveColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    color: isBlocked
                        ? Colors.grey
                        : (isDark ? Colors.white70 : Colors.black87),
                    decoration: isBlocked ? TextDecoration.lineThrough : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Notification Preview ───────────────────────────────────────────────

  Widget _buildNotificationPreview(
    BuildContext context,
    bool isDark,
    PendingNotificationInfo info,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.preview_rounded,
                size: 14,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
              const SizedBox(width: 6),
              Text(
                'NOTIFICATION PREVIEW',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2D3A) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColorSchemes.primaryGold.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.self_improvement_rounded,
                    color: AppColorSchemes.primaryGold,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        info.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        info.body.isEmpty ? 'No body content' : info.body,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Time Formatters ────────────────────────────────────────────────────

  String _formatFireTime(DateTime dt) {
    final now = DateTime.now();
    final diff = dt.difference(now);
    String relativeTime;
    if (diff.isNegative) {
      relativeTime = 'Overdue';
    } else if (diff.inMinutes < 1) {
      relativeTime = 'In < 1 min';
    } else if (diff.inMinutes < 60) {
      relativeTime = 'In ${diff.inMinutes} min';
    } else if (diff.inHours < 24) {
      final mins = diff.inMinutes % 60;
      relativeTime = mins > 0
          ? 'In ${diff.inHours}h ${mins}m'
          : 'In ${diff.inHours}h';
    } else {
      relativeTime = 'In ${diff.inDays} day${diff.inDays > 1 ? 's' : ''}';
    }
    final timeStr =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    final dateStr = '${dt.month}/${dt.day}';
    return '$relativeTime ($dateStr at $timeStr)';
  }

  String _formatFireTimeShort(DateTime dt) {
    final now = DateTime.now();
    final diff = dt.difference(now);
    if (diff.isNegative) return 'Overdue';
    if (diff.inMinutes < 60) return 'In ${diff.inMinutes} min';
    if (diff.inHours < 24) {
      final mins = diff.inMinutes % 60;
      return mins > 0 ? 'In ${diff.inHours}h ${mins}m' : 'In ${diff.inHours}h';
    }
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Detail Page
// ══════════════════════════════════════════════════════════════════════════

class _HabitDiagnosticsDetailPage extends StatefulWidget {
  final PendingNotificationInfo info;
  final bool isDark;
  final Widget Function(BuildContext, bool, PendingNotificationInfo)
  buildJourneyStages;
  final Widget Function(BuildContext, bool, PendingNotificationInfo)
  buildNotificationPreview;
  final List<Map<String, String>> availableChannels;
  final List<Map<String, String>> availableSounds;
  final List<Map<String, dynamic>> delayOptions;
  final String? initialChannel;
  final String? initialSound;
  final int? initialDelay;
  final void Function(String?, String?, int?) onConfigChanged;
  final VoidCallback onFire;
  final bool Function() isFiring;
  final Future<bool> Function() onEditNotification;
  final Future<bool> Function() onDeleteNotification;

  const _HabitDiagnosticsDetailPage({
    required this.info,
    required this.isDark,
    required this.buildJourneyStages,
    required this.buildNotificationPreview,
    required this.availableChannels,
    required this.availableSounds,
    required this.delayOptions,
    this.initialChannel,
    this.initialSound,
    this.initialDelay,
    required this.onConfigChanged,
    required this.onFire,
    required this.isFiring,
    required this.onEditNotification,
    required this.onDeleteNotification,
  });

  @override
  State<_HabitDiagnosticsDetailPage> createState() =>
      _HabitDiagnosticsDetailPageState();
}

class _HabitDiagnosticsDetailPageState
    extends State<_HabitDiagnosticsDetailPage> {
  late String _currentChannel;
  late String _currentSound;
  late int _currentDelay;
  bool _isFiring = false;

  @override
  void initState() {
    super.initState();
    _currentChannel = widget.initialChannel ?? widget.info.channelKey;
    _currentSound = widget.initialSound ?? widget.info.soundKey;
    _currentDelay = widget.initialDelay ?? 2;
  }

  void _updateConfig({String? channel, String? sound, int? delay}) {
    setState(() {
      if (channel != null) _currentChannel = channel;
      if (sound != null) _currentSound = sound;
      if (delay != null) _currentDelay = delay;
    });
    widget.onConfigChanged(
      _currentChannel != widget.info.channelKey ? _currentChannel : null,
      _currentSound != widget.info.soundKey ? _currentSound : null,
      _currentDelay > 2 ? _currentDelay : null,
    );
  }

  void _resetConfig() {
    setState(() {
      _currentChannel = widget.info.channelKey;
      _currentSound = widget.info.soundKey;
      _currentDelay = 2;
    });
    widget.onConfigChanged(null, null, null);
  }

  void _handleFire() async {
    setState(() => _isFiring = true);
    widget.onFire();
    await Future.delayed(
      Duration(milliseconds: _currentDelay > 2 ? 500 : 1500),
    );
    if (mounted) setState(() => _isFiring = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final info = widget.info;

    final content = Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          info.title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          info.getReminderDescription(),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Color(info.statusColor),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      info.statusSummary,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Notification actions',
                    onSelected: (value) async {
                      bool changed = false;
                      if (value == 'edit') {
                        changed = await widget.onEditNotification();
                      } else if (value == 'delete') {
                        changed = await widget.onDeleteNotification();
                      }

                      if (changed && mounted) {
                        Navigator.pop(this.context, true);
                      }
                    },
                    itemBuilder: (menuContext) => const [
                      PopupMenuItem<String>(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 16),
                            SizedBox(width: 8),
                            Text('Edit time'),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              size: 16,
                              color: Color(0xFFEF5350),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Delete',
                              style: TextStyle(color: Color(0xFFEF5350)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2230) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: info.willBeBlockedByQuietHours
                          ? const Color(0xFFEF5350).withOpacity(0.3)
                          : (isDark
                                ? Colors.white.withOpacity(0.05)
                                : Colors.black.withOpacity(0.05)),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      widget.buildJourneyStages(context, isDark, info),
                      widget.buildNotificationPreview(context, isDark, info),
                      _buildTestConfigSection(context, isDark, info),
                      _buildFireButton(context, isDark, info),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return isDark
        ? DarkGradient.wrap(child: content)
        : Container(color: const Color(0xFFF5F5F5), child: content);
  }

  // ── Test Config Section ────────────────────────────────────────────────

  Widget _buildTestConfigSection(
    BuildContext context,
    bool isDark,
    PendingNotificationInfo info,
  ) {
    final hasOverrides =
        _currentChannel != info.channelKey ||
        _currentSound != info.soundKey ||
        _currentDelay > 2;
    final hasDelaySet = _currentDelay > 10;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.05),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.tune_rounded,
                size: 14,
                color: hasOverrides
                    ? AppColorSchemes.primaryGold
                    : (isDark ? Colors.white54 : Colors.black54),
              ),
              const SizedBox(width: 6),
              Text(
                'TEST CONFIGURATION',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: hasOverrides
                      ? AppColorSchemes.primaryGold
                      : (isDark ? Colors.white54 : Colors.black54),
                ),
              ),
              const Spacer(),
              if (hasOverrides)
                GestureDetector(
                  onTap: () {
                    _resetConfig();
                    HapticFeedback.lightImpact();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF5350).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'RESET',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFEF5350),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Delay selector
          Row(
            children: [
              Icon(
                Icons.timer_outlined,
                size: 12,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
              const SizedBox(width: 4),
              Text(
                'Fire After',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
              const Spacer(),
              if (hasDelaySet)
                Text(
                  _getDelayTip(_currentDelay),
                  style: const TextStyle(
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF7E57C2),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: widget.delayOptions.map((option) {
                final seconds = option['seconds'] as int;
                final label = option['label'] as String;
                final isSelected = _currentDelay == seconds;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      _updateConfig(delay: seconds);
                      HapticFeedback.selectionClick();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (seconds > 10
                                  ? const Color(0xFF7E57C2)
                                  : AppColorSchemes.primaryGold)
                            : (isDark
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.black.withOpacity(0.05)),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? Colors.transparent
                              : (isDark
                                    ? Colors.white.withOpacity(0.1)
                                    : Colors.black.withOpacity(0.1)),
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? (seconds > 10 ? Colors.white : Colors.black)
                              : (isDark ? Colors.white70 : Colors.black54),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 12),

          // Channel selector
          _buildDropdown(
            context: context,
            isDark: isDark,
            label: 'Channel',
            icon: Icons.campaign_outlined,
            value: _currentChannel,
            items: widget.availableChannels
                .map((c) => {'value': c['key']!, 'label': c['name']!})
                .toList(),
            onChanged: (val) {
              if (val != null) _updateConfig(channel: val);
            },
          ),
          const SizedBox(height: 8),

          // Sound selector
          _buildDropdown(
            context: context,
            isDark: isDark,
            label: 'Sound',
            icon: Icons.music_note_outlined,
            value: _currentSound,
            items: widget.availableSounds
                .map((s) => {'value': s['key']!, 'label': s['name']!})
                .toList(),
            onChanged: (val) {
              if (val != null) _updateConfig(sound: val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required BuildContext context,
    required bool isDark,
    required String label,
    required IconData icon,
    required String value,
    required List<Map<String, String>> items,
    required void Function(String?) onChanged,
  }) {
    final itemValues = items.map((i) => i['value']!).toList();
    final effectiveItems = itemValues.contains(value)
        ? items
        : [
            {
              'value': value,
              'label': NotificationSettings.getSoundDisplayName(value),
            },
            ...items,
          ];

    final seen = <String>{};
    final uniqueItems = effectiveItems
        .where((i) => seen.add(i['value']!))
        .toList();

    return Row(
      children: [
        Icon(icon, size: 12, color: isDark ? Colors.white54 : Colors.black54),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<String>(
            value: value,
            underline: const SizedBox.shrink(),
            isDense: true,
            dropdownColor: isDark ? const Color(0xFF2A2F45) : Colors.white,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
            items: uniqueItems
                .map(
                  (item) => DropdownMenuItem(
                    value: item['value']!,
                    child: Text(item['label']!),
                  ),
                )
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  // ── Fire Button ────────────────────────────────────────────────────────

  Widget _buildFireButton(
    BuildContext context,
    bool isDark,
    PendingNotificationInfo info,
  ) {
    final hasDelaySet = _currentDelay > 10;
    final buttonLabel = _currentDelay > 2
        ? 'FIRE IN ${_currentDelay}s'
        : 'FIRE NOW';

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isFiring ? null : _handleFire,
              icon: _isFiring
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          hasDelaySet ? Colors.white : Colors.black,
                        ),
                      ),
                    )
                  : Icon(
                      hasDelaySet
                          ? Icons.schedule_rounded
                          : Icons.flash_on_rounded,
                      size: 18,
                      color: hasDelaySet ? Colors.white : Colors.black,
                    ),
              label: Text(
                _isFiring
                    ? (hasDelaySet ? 'SCHEDULED...' : 'FIRING...')
                    : buttonLabel,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: hasDelaySet ? Colors.white : Colors.black,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: hasDelaySet
                    ? const Color(0xFF7E57C2)
                    : AppColorSchemes.primaryGold,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          if (hasDelaySet) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF7E57C2).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 14,
                    color: Color(0xFF7E57C2),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getDelayInstructions(_currentDelay),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getDelayTip(int seconds) {
    if (seconds >= 30) return 'Test with app killed';
    if (seconds >= 10) return 'Test with app minimized';
    return '';
  }

  String _getDelayInstructions(int seconds) {
    if (seconds <= 10) return 'Watch for the notification to appear';
    if (seconds <= 30) {
      return 'After pressing, lock your phone to test lock screen notifications';
    }
    if (seconds <= 60) {
      return 'After pressing, swipe away or kill the app to test if notifications work with app closed';
    }
    return 'After pressing, close the app and lock the phone. This tests if notifications work when device is in deep sleep.';
  }
}
