import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/dark_gradient.dart';
import '../../../../../core/theme/color_schemes.dart';
import '../../../../../core/models/notification_settings.dart';
import '../../../../../core/models/pending_notification_info.dart';
import '../../../../../core/services/reminder_manager.dart';
import '../../../../../core/providers/notification_settings_provider.dart';

/// Notification Diagnostics Screen
/// 
/// Shows all pending notifications with their full "journey":
/// - Schedule: When it will fire
/// - Quiet Hours: Whether blocked or allowed
/// - Channel: Which channel and sound
/// - Build: The final notification content
/// 
/// Also provides a "Test Now" button for each notification.
class NotificationDiagnosticsScreen extends ConsumerStatefulWidget {
  const NotificationDiagnosticsScreen({super.key});

  @override
  ConsumerState<NotificationDiagnosticsScreen> createState() => _NotificationDiagnosticsScreenState();
}

class _NotificationDiagnosticsScreenState extends ConsumerState<NotificationDiagnosticsScreen> {
  List<PendingNotificationInfo>? _notifications;
  bool _isLoading = true;
  String? _error;
  int? _firingId;

  // Search / filter / sort
  String _searchQuery = '';
  String _filterType = 'all';
  String _filterChannel = 'all';
  String _sortBy = 'time';
  bool _sortAscending = true;
  bool _filtersExpanded = false; // Accordion state
  
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
    _availableSounds = ReminderManager().getAvailableSounds(); // Initial basic sounds
    _delayOptions = ReminderManager().getDelayOptions();
    _loadNotifications();
    _loadSoundsAsync(); // Load full sounds list including user's custom sounds
  }
  
  Future<void> _loadSoundsAsync() async {
    final sounds = await ReminderManager().getAvailableSoundsAsync();
    if (mounted) {
      setState(() {
        _availableSounds = sounds;
      });
    }
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final notifications = await ReminderManager().getDetailedPendingNotifications();
      if (mounted) {
        setState(() {
          _notifications = notifications;
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

  Future<void> _fireNotification(PendingNotificationInfo info) async {
    setState(() => _firingId = info.id);
    HapticFeedback.mediumImpact();

    // Get overrides if set
    final channelOverride = _channelOverrides[info.id];
    final soundOverride = _soundOverrides[info.id];
    final delaySeconds = _delayOverrides[info.id] ?? 2;
    
    // Build description of what's being fired
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
        final isAlarm = info.isSpecial || 
            (info.useAlarmMode && (channelOverride ?? info.channelKey) == 'urgent_reminders');
        
        // Show appropriate message based on delay
        String delayText;
        String tipText;
        if (delaySeconds <= 3) {
          delayText = 'Fires in $delaySeconds seconds';
          tipText = 'Watch for the notification';
        } else if (delaySeconds <= 30) {
          delayText = 'Fires in $delaySeconds seconds';
          tipText = 'Try locking your phone now';
        } else if (delaySeconds <= 60) {
          delayText = 'Fires in ${delaySeconds}s (${delaySeconds ~/ 60}m ${delaySeconds % 60}s)';
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
                  isAlarm ? Icons.alarm_rounded : Icons.notifications_active_rounded,
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
                        style: const TextStyle(fontSize: 12, color: Colors.white),
                      ),
                      Text(
                        'Channel: $channelDesc • Sound: $soundDesc',
                        style: const TextStyle(fontSize: 10, color: Colors.white70),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: Duration(seconds: delaySeconds > 10 ? 5 : 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _firingId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = ref.watch(notificationSettingsProvider);

    final content = Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(context, isDark),
            
            // Status Summary
            _buildStatusSummary(context, isDark, settings),

            // Search / Filter / Sort
            _buildFilterBar(context, isDark),
            
            // Notification List
            Expanded(
              child: _buildNotificationList(context, isDark),
            ),
          ],
        ),
      ),
    );

    return isDark 
        ? DarkGradient.wrap(child: content) 
        : Container(
            color: const Color(0xFFF5F5F5),
            child: content,
          );
  }

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
                  'Notification Diagnostics',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                Text(
                  'Preview & test pending notifications',
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
        ],
      ),
    );
  }

  Widget _buildStatusSummary(BuildContext context, bool isDark, dynamic settings) {
    final count = _notifications?.length ?? 0;
    final blockedCount = _notifications?.where((n) => n.willBeBlockedByQuietHours).length ?? 0;
    final specialCount = _notifications?.where((n) => n.isSpecial).length ?? 0;
    final nativeCount = _notifications?.where((n) => n.metadata['trackedSource'] == 'native_alarm').length ?? 0;
    final flutterCount = count - nativeCount;

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2230) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
            ),
          ),
          child: Row(
            children: [
              _buildStatusItem(
                context, isDark,
                count.toString(),
                'Pending',
                Icons.schedule_rounded,
                AppColorSchemes.primaryGold,
              ),
              _buildStatusDivider(isDark),
              _buildStatusItem(
                context, isDark,
                specialCount.toString(),
                'Special',
                Icons.star_rounded,
                const Color(0xFFFFB74D),
              ),
              _buildStatusDivider(isDark),
              _buildStatusItem(
                context, isDark,
                blockedCount.toString(),
                'Blocked',
                Icons.block_rounded,
                const Color(0xFFEF5350),
              ),
              _buildStatusDivider(isDark),
              _buildStatusItem(
                context, isDark,
                settings.isInQuietHours() ? 'ON' : 'OFF',
                'Quiet Hours',
                Icons.bedtime_rounded,
                settings.isInQuietHours() ? const Color(0xFF7E57C2) : const Color(0xFF4CAF50),
              ),
            ],
          ),
        ),
        
        // Debug info - shows source breakdown  
        if (count > 0)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
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
                Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: const Color(0xFF42A5F5),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Flutter Notifications: $flutterCount • Native Alarms: $nativeCount',
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

  Widget _buildFilterBar(BuildContext context, bool isDark) {
    final hasActiveFilters = _searchQuery.isNotEmpty || 
                             _filterType != 'all' || 
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
              : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
        ),
      ),
      child: Column(
        children: [
          // Header - Always visible
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
                        fontWeight: hasActiveFilters ? FontWeight.w600 : FontWeight.normal,
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
                          _filterType = 'all';
                          _filterChannel = 'all';
                          _sortBy = 'time';
                          _sortAscending = true;
                        });
                        HapticFeedback.lightImpact();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
          
          // Expanded content
          if (_filtersExpanded) ...[
            Divider(
              height: 1,
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // Search field
                  TextField(
                    controller: TextEditingController(text: _searchQuery)
                      ..selection = TextSelection.fromPosition(
                        TextPosition(offset: _searchQuery.length),
                      ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded, color: isDark ? Colors.white54 : Colors.black54),
                      hintText: 'Search by title...',
                      hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                      filled: true,
                      fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 10),
                  
                  // Type and Channel filters
                  Row(
                    children: [
                      Expanded(
                        child: _buildFilterDropdown(
                          context,
                          isDark,
                          value: _filterType,
                          items: const [
                            {'key': 'all', 'label': 'All'},
                            {'key': 'task', 'label': 'Tasks'},
                            {'key': 'habit', 'label': 'Habits'},
                            {'key': 'simple_reminder', 'label': 'Reminders'},
                            {'key': 'unknown', 'label': 'Unknown'},
                          ],
                          onChanged: (value) => setState(() => _filterType = value ?? 'all'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildFilterDropdown(
                          context,
                          isDark,
                          value: _filterChannel,
                          items: [
                            {'key': 'all', 'label': 'All Channels'},
                            ..._availableChannels.map((c) => {
                                  'key': c['key']!,
                                  'label': c['name']!,
                                }),
                          ],
                          onChanged: (value) => setState(() => _filterChannel = value ?? 'all'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  
                  // Sort by and direction
                  Row(
                    children: [
                      Expanded(
                        child: _buildFilterDropdown(
                          context,
                          isDark,
                          value: _sortBy,
                          items: const [
                            {'key': 'time', 'label': 'Time'},
                            {'key': 'priority', 'label': 'Priority'},
                            {'key': 'status', 'label': 'Status'},
                          ],
                          onChanged: (value) => setState(() => _sortBy = value ?? 'time'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => setState(() => _sortAscending = !_sortAscending),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                size: 16,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _sortAscending ? 'Asc' : 'Desc',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white70 : Colors.black54,
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
      filters.add('Search: "${_searchQuery.length > 15 ? '${_searchQuery.substring(0, 15)}...' : _searchQuery}"');
    }
    if (_filterType != 'all') {
      final label = _filterType == 'simple_reminder' 
          ? 'Reminders' 
          : '${_filterType[0].toUpperCase()}${_filterType.substring(1)}s';
      filters.add(label);
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
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
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
              .map((item) => DropdownMenuItem(
                    value: item['key'],
                    child: Text(
                      item['label'] ?? item['key'] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  List<PendingNotificationInfo> _getFilteredSortedNotifications() {
    final source = _notifications ?? const [];
    final query = _searchQuery.trim().toLowerCase();

    final filtered = source.where((n) {
      if (query.isNotEmpty && !n.title.toLowerCase().contains(query)) return false;
      if (_filterType != 'all' && n.type != _filterType) return false;
      if (_filterChannel != 'all' && n.channelKey != _filterChannel) return false;
      return true;
    }).toList();

    int priorityRank(String? p) {
      switch (p) {
        case 'High':
          return 0;
        case 'Medium':
          return 1;
        case 'Low':
          return 2;
        default:
          return 3;
      }
    }

    int statusRank(PendingNotificationInfo n) {
      if (n.willBeBlockedByQuietHours) return 0;
      if (n.isSpecial) return 1;
      if (n.priority == 'High') return 2;
      return 3;
    }

    int compareTimes(PendingNotificationInfo a, PendingNotificationInfo b) {
      final at = a.willFireAt;
      final bt = b.willFireAt;
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return at.compareTo(bt);
    }

    filtered.sort((a, b) {
      int cmp;
      switch (_sortBy) {
        case 'priority':
          cmp = priorityRank(a.priority).compareTo(priorityRank(b.priority));
          break;
        case 'status':
          cmp = statusRank(a).compareTo(statusRank(b));
          break;
        case 'time':
        default:
          cmp = compareTimes(a, b);
      }
      return _sortAscending ? cmp : -cmp;
    });

    return filtered;
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

  Widget _buildNotificationList(BuildContext context, bool isDark) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColorSchemes.primaryGold),
            SizedBox(height: 16),
            Text('Loading notifications...'),
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
              const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
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
                style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
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
                'No Pending Notifications',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Create a task with a reminder to see it here.',
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

    final items = _getFilteredSortedNotifications();

    if (items.isEmpty) {
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
                style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final info = items[index];
        return _buildNotificationListItem(context, isDark, info);
      },
    );
  }

  Widget _buildNotificationListItem(BuildContext context, bool isDark, PendingNotificationInfo info) {
    final timeLabel = info.willFireAt != null
        ? _formatFireTimeShort(info.willFireAt!)
        : 'Time unknown';

    return InkWell(
      onTap: () => _openNotificationDetail(context, info),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2230) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: info.willBeBlockedByQuietHours
                ? const Color(0xFFEF5350).withOpacity(0.3)
                : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Color(info.statusColor).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                info.isSpecial
                    ? Icons.star_rounded
                    : (info.willBeBlockedByQuietHours
                        ? Icons.block_rounded
                        : Icons.notifications_active_rounded),
                color: Color(info.statusColor),
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timeLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ],
        ),
      ),
    );
  }

  void _openNotificationDetail(BuildContext context, PendingNotificationInfo info) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _NotificationDiagnosticsDetailPage(
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
        ),
      ),
    );
  }

  Widget _buildNotificationCard(BuildContext context, bool isDark, PendingNotificationInfo info) {
    final isFiring = _firingId == info.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2230) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: info.willBeBlockedByQuietHours
              ? const Color(0xFFEF5350).withOpacity(0.3)
              : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
          width: info.willBeBlockedByQuietHours ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(context, isDark, info),
          _buildJourneyStages(context, isDark, info),
          _buildNotificationPreview(context, isDark, info),
          _buildTestConfigSection(context, isDark, info),
          _buildFireButton(context, isDark, info, isFiring),
        ],
      ),
    );
  }

  Widget _buildCardHeader(BuildContext context, bool isDark, PendingNotificationInfo info) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(info.statusColor).withOpacity(0.1),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          // Status icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Color(info.statusColor).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              info.isSpecial 
                  ? Icons.star_rounded
                  : (info.willBeBlockedByQuietHours 
                      ? Icons.block_rounded 
                      : Icons.notifications_active_rounded),
              color: Color(info.statusColor),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          
          // Title and type
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${info.type.toUpperCase()} • ${info.getReminderDescription()}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Color(info.statusColor),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              info.statusSummary,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJourneyStages(BuildContext context, bool isDark, PendingNotificationInfo info) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          // Stage 1: Schedule
          _buildJourneyStage(
            context, isDark,
            '1',
            'SCHEDULE',
            info.willFireAt != null 
                ? _formatFireTime(info.willFireAt!)
                : 'Time unknown',
            Icons.schedule_rounded,
            const Color(0xFF42A5F5),
            isCompleted: true,
          ),
          
          // Stage 2: Quiet Hours
          _buildJourneyStage(
            context, isDark,
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
          
          // Stage 3: Channel
          _buildJourneyStage(
            context, isDark,
            '3',
            'CHANNEL',
            '${info.channelName} • ${info.soundName} • ${NotificationSettings.getAudioStreamDisplayName(info.audioStream)}',
            Icons.campaign_rounded,
            const Color(0xFFFFB74D),
            isCompleted: !info.willBeBlockedByQuietHours,
            isBlocked: info.willBeBlockedByQuietHours,
          ),
          
          // Stage 4: Build
          _buildJourneyStage(
            context, isDark,
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
        // Stage indicator
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
                    ? Icon(Icons.close_rounded, size: 14, color: Colors.grey)
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
        
        // Stage content
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

  Widget _buildNotificationPreview(BuildContext context, bool isDark, PendingNotificationInfo info) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.08),
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
          // Mock notification
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
                // App icon
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColorSchemes.primaryGold.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
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

  Widget _buildTestConfigSection(BuildContext context, bool isDark, PendingNotificationInfo info) {
    final currentChannel = _channelOverrides[info.id] ?? info.channelKey;
    final currentSound = _soundOverrides[info.id] ?? info.soundKey;
    final currentDelay = _delayOverrides[info.id] ?? 2;
    final hasOverrides = _channelOverrides.containsKey(info.id) || 
                         _soundOverrides.containsKey(info.id) ||
                         _delayOverrides.containsKey(info.id);
    final hasDelaySet = _delayOverrides.containsKey(info.id) && currentDelay > 10;
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasDelaySet 
            ? const Color(0xFF7E57C2).withOpacity(0.1)
            : (hasOverrides 
                ? const Color(0xFFFF9800).withOpacity(0.1)
                : (isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02))),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasDelaySet 
              ? const Color(0xFF7E57C2).withOpacity(0.3)
              : (hasOverrides 
                  ? const Color(0xFFFF9800).withOpacity(0.3)
                  : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasDelaySet ? Icons.timer_rounded : Icons.tune_rounded,
                size: 14,
                color: hasDelaySet 
                    ? const Color(0xFF7E57C2) 
                    : (hasOverrides ? const Color(0xFFFF9800) : (isDark ? Colors.white38 : Colors.black38)),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  hasDelaySet 
                      ? 'DELAYED TEST (${_formatDelay(currentDelay)})'
                      : (hasOverrides ? 'TESTING WITH OVERRIDES' : 'TEST CONFIGURATION'),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: hasDelaySet 
                        ? const Color(0xFF7E57C2) 
                        : (hasOverrides ? const Color(0xFFFF9800) : (isDark ? Colors.white38 : Colors.black38)),
                  ),
                ),
              ),
              if (hasOverrides)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _channelOverrides.remove(info.id);
                      _soundOverrides.remove(info.id);
                      _delayOverrides.remove(info.id);
                    });
                    HapticFeedback.selectionClick();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (hasDelaySet ? const Color(0xFF7E57C2) : const Color(0xFFFF9800)).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'RESET',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: hasDelaySet ? const Color(0xFF7E57C2) : const Color(0xFFFF9800),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Delay Selector (Full width at top)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
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
                      _getDelayTip(currentDelay),
                      style: TextStyle(
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                        color: const Color(0xFF7E57C2),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _delayOptions.map((option) {
                    final seconds = option['seconds'] as int;
                    final label = option['label'] as String;
                    final isSelected = currentDelay == seconds;
                    
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            if (seconds == 2) {
                              _delayOverrides.remove(info.id);
                            } else {
                              _delayOverrides[info.id] = seconds;
                            }
                          });
                          HapticFeedback.selectionClick();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? (seconds > 10 ? const Color(0xFF7E57C2) : AppColorSchemes.primaryGold)
                                : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected 
                                  ? Colors.transparent
                                  : (isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1)),
                            ),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Channel and Sound Selector
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Channel',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildDropdown(
                      context, isDark,
                      value: currentChannel,
                      items: _availableChannels.map((c) => {
                        'value': c['key']!,
                        'label': c['name']!,
                      }).toList(),
                      labelForValue: NotificationSettings.getChannelDisplayName,
                      onChanged: (value) {
                        setState(() {
                          if (value == info.channelKey) {
                            _channelOverrides.remove(info.id);
                          } else {
                            _channelOverrides[info.id] = value!;
                          }
                        });
                        HapticFeedback.selectionClick();
                      },
                      isOverridden: _channelOverrides.containsKey(info.id),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              
              // Sound Selector
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sound',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildDropdown(
                      context, isDark,
                      value: currentSound,
                      items: _availableSounds.map((s) => {
                        'value': s['key']!,
                        'label': s['name']!,
                      }).toList(),
                      labelForValue: NotificationSettings.getSoundDisplayName,
                      onChanged: (value) {
                        setState(() {
                          if (value == info.soundKey) {
                            _soundOverrides.remove(info.id);
                          } else {
                            _soundOverrides[info.id] = value!;
                          }
                        });
                        HapticFeedback.selectionClick();
                      },
                      isOverridden: _soundOverrides.containsKey(info.id),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          if (hasOverrides && !hasDelaySet) ...[
            const SizedBox(height: 8),
            Text(
              'Original: ${info.channelName} • ${info.soundName}',
              style: TextStyle(
                fontSize: 10,
                fontStyle: FontStyle.italic,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  String _formatDelay(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    if (secs == 0) return '${mins}m';
    return '${mins}m ${secs}s';
  }
  
  String _getDelayTip(int seconds) {
    if (seconds <= 10) return 'Quick test';
    if (seconds <= 30) return 'Lock screen test';
    if (seconds <= 60) return 'Kill app test';
    if (seconds <= 120) return 'Background test';
    return 'Deep sleep test';
  }
  
  Widget _buildDropdown(
    BuildContext context,
    bool isDark, {
    required String value,
    required List<Map<String, String>> items,
    required ValueChanged<String?> onChanged,
    required String Function(String) labelForValue,
    bool isOverridden = false,
  }) {
    // Ensure dropdown items contain the current value to avoid assertion errors.
    // Also dedupe values to avoid duplicate-value assertions.
    final List<Map<String, String>> normalizedItems = [];
    final Set<String> seen = {};
    for (final item in items) {
      final v = item['value'];
      if (v == null || seen.contains(v)) continue;
      seen.add(v);
      normalizedItems.add(item);
    }
    if (value.isNotEmpty && !seen.contains(value)) {
      normalizedItems.add({
        'value': value,
        'label': labelForValue(value),
      });
      seen.add(value);
    }

    final String? safeValue = seen.contains(value) ? value : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      decoration: BoxDecoration(
        color: isOverridden 
            ? const Color(0xFFFF9800).withOpacity(0.15)
            : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isOverridden 
              ? const Color(0xFFFF9800).withOpacity(0.4)
              : (isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1)),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: safeValue,
          isExpanded: true,
          isDense: true,
          dropdownColor: isDark ? const Color(0xFF2A2D3A) : Colors.white,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isOverridden ? FontWeight.bold : FontWeight.normal,
            color: isOverridden 
                ? const Color(0xFFFF9800)
                : (isDark ? Colors.white : Colors.black),
          ),
          icon: Icon(
            Icons.expand_more_rounded,
            size: 18,
            color: isOverridden 
                ? const Color(0xFFFF9800)
                : (isDark ? Colors.white54 : Colors.black54),
          ),
          items: normalizedItems.map((item) => DropdownMenuItem(
            value: item['value'],
            child: Text(item['label']!),
          )).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildFireButton(BuildContext context, bool isDark, PendingNotificationInfo info, bool isFiring) {
    final hasOverrides = _channelOverrides.containsKey(info.id) || 
                         _soundOverrides.containsKey(info.id) ||
                         _delayOverrides.containsKey(info.id);
    final currentDelay = _delayOverrides[info.id] ?? 2;
    final hasDelaySet = _delayOverrides.containsKey(info.id) && currentDelay > 10;
    
    // Build button label
    String buttonLabel;
    if (isFiring) {
      buttonLabel = 'Scheduled!';
    } else if (hasDelaySet) {
      buttonLabel = 'Fire in ${_formatDelay(currentDelay)}';
    } else if (hasOverrides) {
      buttonLabel = 'Fire with Overrides';
    } else {
      buttonLabel = 'Fire Now';
    }
    
    // Determine button color
    Color buttonColor;
    Color textColor;
    if (info.willBeBlockedByQuietHours) {
      buttonColor = Colors.grey;
      textColor = Colors.white70;
    } else if (hasDelaySet) {
      buttonColor = const Color(0xFF7E57C2);
      textColor = Colors.white;
    } else if (hasOverrides) {
      buttonColor = const Color(0xFFFF9800);
      textColor = Colors.white;
    } else {
      buttonColor = AppColorSchemes.primaryGold;
      textColor = Colors.black;
    }
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isFiring ? null : () => _fireNotification(info),
              icon: isFiring 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      hasDelaySet 
                          ? Icons.timer_rounded 
                          : (hasOverrides ? Icons.science_rounded : Icons.notifications_active_rounded),
                      size: 20,
                    ),
              label: Text(buttonLabel),
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: textColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
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
                      _getDelayInstructions(currentDelay),
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
  
  String _getDelayInstructions(int seconds) {
    if (seconds <= 10) {
      return 'Watch for the notification to appear';
    } else if (seconds <= 30) {
      return 'After pressing, lock your phone to test lock screen notifications';
    } else if (seconds <= 60) {
      return 'After pressing, swipe away or kill the app to test if notifications work with app closed';
    } else {
      return 'After pressing, close the app and lock the phone. This tests if notifications work when device is in deep sleep.';
    }
  }

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
    
    final timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    final dateStr = '${dt.month}/${dt.day}';
    
    return '$relativeTime ($dateStr at $timeStr)';
  }

  String _formatFireTimeShort(DateTime dt) {
    final now = DateTime.now();
    final diff = dt.difference(now);

    if (diff.isNegative) {
      return 'Overdue';
    }
    if (diff.inMinutes < 60) {
      return 'In ${diff.inMinutes} min';
    }
    if (diff.inHours < 24) {
      final mins = diff.inMinutes % 60;
      return mins > 0 ? 'In ${diff.inHours}h ${mins}m' : 'In ${diff.inHours}h';
    }
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _NotificationDiagnosticsDetailPage extends StatefulWidget {
  final PendingNotificationInfo info;
  final bool isDark;
  final Widget Function(BuildContext, bool, PendingNotificationInfo) buildJourneyStages;
  final Widget Function(BuildContext, bool, PendingNotificationInfo) buildNotificationPreview;
  final List<Map<String, String>> availableChannels;
  final List<Map<String, String>> availableSounds;
  final List<Map<String, dynamic>> delayOptions;
  final String? initialChannel;
  final String? initialSound;
  final int? initialDelay;
  final void Function(String?, String?, int?) onConfigChanged;
  final VoidCallback onFire;
  final bool Function() isFiring;

  const _NotificationDiagnosticsDetailPage({
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
  });

  @override
  State<_NotificationDiagnosticsDetailPage> createState() => _NotificationDiagnosticsDetailPageState();
}

class _NotificationDiagnosticsDetailPageState extends State<_NotificationDiagnosticsDetailPage> {
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
    // Sync back to parent
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
    // Keep firing state for a bit to show feedback
    await Future.delayed(Duration(milliseconds: _currentDelay > 2 ? 500 : 1500));
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2230) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: info.willBeBlockedByQuietHours
                          ? const Color(0xFFEF5350).withOpacity(0.3)
                          : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
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
        : Container(
            color: const Color(0xFFF5F5F5),
            child: content,
          );
  }

  Widget _buildTestConfigSection(BuildContext context, bool isDark, PendingNotificationInfo info) {
    final hasOverrides = _currentChannel != info.channelKey || 
                         _currentSound != info.soundKey ||
                         _currentDelay > 2;
    final hasDelaySet = _currentDelay > 10;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
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
                color: hasOverrides ? AppColorSchemes.primaryGold : (isDark ? Colors.white54 : Colors.black54),
              ),
              const SizedBox(width: 6),
              Text(
                'TEST CONFIGURATION',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: hasOverrides ? AppColorSchemes.primaryGold : (isDark ? Colors.white54 : Colors.black54),
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
          
          // Fire After (delay) selector
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? (seconds > 10 ? const Color(0xFF7E57C2) : AppColorSchemes.primaryGold)
                            : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected 
                              ? Colors.transparent
                              : (isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1)),
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
            items: widget.availableChannels.map((c) => {
              'value': c['key']!,
              'label': c['name']!,
            }).toList(),
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
            items: widget.availableSounds.map((s) => {
              'value': s['key']!,
              'label': s['name']!,
            }).toList(),
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
    // Ensure value is in items list
    final itemValues = items.map((i) => i['value']!).toList();
    final effectiveItems = itemValues.contains(value) 
        ? items 
        : [{'value': value, 'label': NotificationSettings.getSoundDisplayName(value)}, ...items];
    
    // Dedupe by value
    final seen = <String>{};
    final uniqueItems = effectiveItems.where((i) => seen.add(i['value']!)).toList();

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
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
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
            items: uniqueItems.map((item) {
              return DropdownMenuItem(
                value: item['value']!,
                child: Text(item['label']!),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildFireButton(BuildContext context, bool isDark, PendingNotificationInfo info) {
    final hasDelaySet = _currentDelay > 10;
    final buttonLabel = _currentDelay > 2 
        ? 'FIRE IN ${_currentDelay}s' 
        : 'FIRE NOW';

    return Container(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
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
                  hasDelaySet ? Icons.schedule_rounded : Icons.flash_on_rounded,
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
            backgroundColor: hasDelaySet ? const Color(0xFF7E57C2) : AppColorSchemes.primaryGold,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  String _getDelayTip(int seconds) {
    if (seconds >= 30) return 'Test with app killed';
    if (seconds >= 10) return 'Test with app minimized';
    return '';
  }
}
