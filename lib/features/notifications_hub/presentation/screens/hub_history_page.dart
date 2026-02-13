import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/notifications/models/notification_hub_payload.dart';
import '../../../../core/notifications/notifications.dart';
import '../../../../core/theme/color_schemes.dart';
import '../widgets/hub_history_entry_detail_sheet.dart';

/// History page – notification lifecycle event log.
///
/// Redesigned for clarity: summary strip at top, horizontal chip filters,
/// advanced filters in a bottom sheet, and clean minimal tiles.
class HubHistoryPage extends StatefulWidget {
  const HubHistoryPage({super.key});

  @override
  State<HubHistoryPage> createState() => _HubHistoryPageState();
}

enum _GroupBy { none, date, module, event, section }

enum _SortBy { newest, oldest, module, event, title }

class _HubHistoryPageState extends State<HubHistoryPage> {
  final NotificationHub _hub = NotificationHub();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  int _refreshSeed = 0;

  String _moduleFilter = 'all';
  NotificationLifecycleEvent? _eventFilter;
  String? _sectionFilter;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  _GroupBy _groupBy = _GroupBy.date;
  _SortBy _sortBy = _SortBy.newest;
  bool _searchVisible = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ─── Data loading (unchanged business logic) ─────────────────────────────

  Future<_HistData> _load() async {
    await _hub.initialize();
    await _hub.compactRedundantHistoryEntries();
    final modules = _hub.getRegisteredModules();
    final logs = await _hub.getHistory(
      moduleId: _moduleFilter == 'all' ? null : _moduleFilter,
      event: _eventFilter,
      from: _dateFrom,
      to: _dateTo,
      search: _searchController.text.trim().isEmpty
          ? null
          : _searchController.text.trim(),
      limit: 500,
    );

    final compacted = _collapseRedundantScheduleEvents(logs);
    var processed = List<NotificationLogEntry>.from(compacted);
    processed = _applySectionFilter(processed);
    processed = _applySort(processed);
    final grouped = _applyGrouping(processed);
    final sections = _extractSections(compacted);

    // Build event counts from the full compacted set (before section filter).
    final eventCounts = <NotificationLifecycleEvent, int>{};
    for (final e in compacted) {
      eventCounts[e.event] = (eventCounts[e.event] ?? 0) + 1;
    }

    return _HistData(
      modules: modules,
      rawLogs: logs,
      processed: processed,
      grouped: grouped,
      sections: sections,
      collapsedScheduleDuplicates: logs.length - compacted.length,
      eventCounts: eventCounts,
    );
  }

  List<NotificationLogEntry> _applySectionFilter(
    List<NotificationLogEntry> logs,
  ) {
    if (_sectionFilter == null || _sectionFilter!.isEmpty) return logs;
    return logs.where((e) {
      final section = _sectionFromEntry(e);
      return section == _sectionFilter;
    }).toList();
  }

  List<NotificationLogEntry> _collapseRedundantScheduleEvents(
    List<NotificationLogEntry> logs,
  ) {
    final seen = <String>{};
    final compacted = <NotificationLogEntry>[];

    for (final e in logs) {
      if (e.event != NotificationLifecycleEvent.scheduled) {
        compacted.add(e);
        continue;
      }

      final scheduledAtRaw = e.metadata['scheduledAt'];
      final scheduledAt = scheduledAtRaw is String ? scheduledAtRaw : '';
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

    return compacted;
  }

  List<NotificationLogEntry> _applySort(List<NotificationLogEntry> logs) {
    int Function(NotificationLogEntry a, NotificationLogEntry b) cmp;
    switch (_sortBy) {
      case _SortBy.newest:
        cmp = (a, b) => b.timestamp.compareTo(a.timestamp);
        break;
      case _SortBy.oldest:
        cmp = (a, b) => a.timestamp.compareTo(b.timestamp);
        break;
      case _SortBy.module:
        cmp = (a, b) {
          final na = _hub.moduleDisplayName(a.moduleId);
          final nb = _hub.moduleDisplayName(b.moduleId);
          final r = na.compareTo(nb);
          return r != 0 ? r : b.timestamp.compareTo(a.timestamp);
        };
        break;
      case _SortBy.event:
        cmp = (a, b) {
          final r = a.event.index.compareTo(b.event.index);
          return r != 0 ? r : b.timestamp.compareTo(a.timestamp);
        };
        break;
      case _SortBy.title:
        cmp = (a, b) {
          final ta = a.title.isEmpty ? 'Notification' : a.title;
          final tb = b.title.isEmpty ? 'Notification' : b.title;
          final r = ta.toLowerCase().compareTo(tb.toLowerCase());
          return r != 0 ? r : b.timestamp.compareTo(a.timestamp);
        };
        break;
    }
    return List.from(logs)..sort(cmp);
  }

  Map<String, List<NotificationLogEntry>> _applyGrouping(
    List<NotificationLogEntry> logs,
  ) {
    if (_groupBy == _GroupBy.none || logs.isEmpty) {
      return {'': logs};
    }

    final map = <String, List<NotificationLogEntry>>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekStart = today.subtract(Duration(days: now.weekday - 1));

    for (final e in logs) {
      String key;
      switch (_groupBy) {
        case _GroupBy.date:
          final t = e.timestamp;
          final d = DateTime(t.year, t.month, t.day);
          if (d == today) {
            key = 'Today';
          } else if (d == yesterday) {
            key = 'Yesterday';
          } else if (d.isAfter(weekStart) || d == weekStart) {
            key = 'This Week';
          } else {
            key = DateFormat('MMM d, yyyy').format(d);
          }
          break;
        case _GroupBy.module:
          key = _hub.moduleDisplayName(e.moduleId);
          break;
        case _GroupBy.event:
          key = e.event.label;
          break;
        case _GroupBy.section:
          key = _sectionDisplay(e) ?? 'Other';
          break;
        default:
          key = '';
      }
      map.putIfAbsent(key, () => []).add(e);
    }

    final orderedKeys = map.keys.toList();
    switch (_groupBy) {
      case _GroupBy.date:
        final priority = ['Today', 'Yesterday', 'This Week'];
        orderedKeys.sort((a, b) {
          final ai = priority.indexOf(a);
          final bi = priority.indexOf(b);
          if (ai >= 0 && bi >= 0) return ai.compareTo(bi);
          if (ai >= 0) return -1;
          if (bi >= 0) return 1;
          return b.compareTo(a);
        });
        break;
      case _GroupBy.module:
      case _GroupBy.event:
      case _GroupBy.section:
        orderedKeys.sort();
        break;
      default:
        break;
    }

    final result = <String, List<NotificationLogEntry>>{};
    for (final k in orderedKeys) {
      result[k] = map[k]!;
    }
    return result;
  }

  String? _sectionFromEntry(NotificationLogEntry e) {
    final p = NotificationHubPayload.tryParse(e.payload);
    if (p == null) return null;
    return p.extras['section'] ?? p.extras['type'];
  }

  String? _sectionDisplay(NotificationLogEntry e) {
    final sectionId = _sectionFromEntry(e);
    if (sectionId == null || sectionId.isEmpty) return null;
    return _hub.sectionDisplayName(e.moduleId, sectionId) ?? sectionId;
  }

  List<String> _extractSections(List<NotificationLogEntry> logs) {
    final set = <String>{};
    for (final e in logs) {
      final s = _sectionFromEntry(e);
      if (s != null && s.isNotEmpty) set.add(s);
    }
    return set.toList()..sort();
  }

  Future<void> _refresh() async {
    HapticFeedback.mediumImpact();
    setState(() => _refreshSeed++);
  }

  // ─── Quick filter presets ────────────────────────────────────────────────

  String get _activeQuickFilter {
    if (_eventFilter == NotificationLifecycleEvent.failed) return 'failed';
    final hasDate = _dateFrom != null && _dateTo != null;
    if (hasDate && DateTime.now().difference(_dateFrom!).inHours <= 25) {
      return '24h';
    }
    if (hasDate &&
        DateTime.now().difference(_dateFrom!).inDays <= 7 &&
        _eventFilter == null) {
      return '7d';
    }
    if (!hasDate && _eventFilter == null && _moduleFilter == 'all') {
      return 'all';
    }
    return '';
  }

  void _applyQuickFilter(String preset) {
    final now = DateTime.now();
    setState(() {
      switch (preset) {
        case 'all':
          _dateFrom = null;
          _dateTo = null;
          _eventFilter = null;
          _moduleFilter = 'all';
          _sectionFilter = null;
          break;
        case '24h':
          _dateFrom = now.subtract(const Duration(hours: 24));
          _dateTo = now.add(const Duration(days: 1));
          _eventFilter = null;
          break;
        case '7d':
          _dateFrom = now.subtract(const Duration(days: 7));
          _dateTo = now.add(const Duration(days: 1));
          _eventFilter = null;
          break;
        case 'failed':
          _eventFilter = NotificationLifecycleEvent.failed;
          _dateFrom = null;
          _dateTo = null;
          break;
      }
      _refreshSeed++;
    });
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 1)),
      initialDateRange: _dateFrom != null && _dateTo != null
          ? DateTimeRange(start: _dateFrom!, end: _dateTo!)
          : null,
    );
    if (range != null) {
      setState(() {
        _dateFrom = range.start;
        _dateTo = range.end.add(const Duration(days: 1));
        _refreshSeed++;
      });
    }
  }

  Future<void> _clearAllHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all history?'),
        content: const Text(
          'Permanently removes all notification log entries. '
          'Active notifications are NOT cancelled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      HapticFeedback.heavyImpact();
      await _hub.clearHistory();
      await _refresh();
    }
  }

  void _showAdvancedFilters(_HistData data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AdvancedFilterSheet(
        hub: _hub,
        modules: data.modules,
        sections: data.sections,
        selectedModule: _moduleFilter,
        selectedEvent: _eventFilter,
        selectedSection: _sectionFilter,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        groupBy: _groupBy,
        sortBy: _sortBy,
        onModuleChanged: (v) {
          setState(() {
            _moduleFilter = v;
            _refreshSeed++;
          });
          Navigator.pop(ctx);
        },
        onEventChanged: (v) {
          setState(() {
            _eventFilter = v;
            _refreshSeed++;
          });
          Navigator.pop(ctx);
        },
        onSectionChanged: (v) {
          setState(() {
            _sectionFilter = v;
            _refreshSeed++;
          });
          Navigator.pop(ctx);
        },
        onGroupByChanged: (v) {
          setState(() {
            _groupBy = v;
            _refreshSeed++;
          });
          Navigator.pop(ctx);
        },
        onSortByChanged: (v) {
          setState(() {
            _sortBy = v;
            _refreshSeed++;
          });
          Navigator.pop(ctx);
        },
        onDateRangeTap: () {
          Navigator.pop(ctx);
          _pickDateRange();
        },
        onClearDates: () {
          setState(() {
            _dateFrom = null;
            _dateTo = null;
            _refreshSeed++;
          });
          Navigator.pop(ctx);
        },
        onClearAll: () async {
          Navigator.pop(ctx);
          final confirm = await showDialog<bool>(
            context: context,
            builder: (dCtx) => AlertDialog(
              title: const Text('Clear All History?'),
              content: const Text(
                'This permanently removes all notification log entries.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dCtx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dCtx, true),
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Clear'),
                ),
              ],
            ),
          );
          if (confirm == true) {
            HapticFeedback.heavyImpact();
            await _hub.clearHistory();
            await _refresh();
          }
        },
      ),
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HistData>(
      key: ValueKey(
        'hist-$_refreshSeed-$_moduleFilter-${_eventFilter?.name ?? "all"}-'
        '$_sectionFilter-${_dateFrom?.toIso8601String()}-${_dateTo?.toIso8601String()}-'
        '${_groupBy.name}-${_sortBy.name}-${_searchController.text}',
      ),
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final data = snapshot.data!;

        return Column(
          children: [
            // 1) Summary strip
            if (data.eventCounts.isNotEmpty)
              _SummaryStrip(
                eventCounts: data.eventCounts,
                activeEvent: _eventFilter,
                onEventTap: (e) {
                  setState(() {
                    _eventFilter = (_eventFilter == e) ? null : e;
                    _refreshSeed++;
                  });
                },
              ),

            // 2) Chip bar + search + filter + clear
            _ChipBar(
              activePreset: _activeQuickFilter,
              onPreset: _applyQuickFilter,
              searchVisible: _searchVisible,
              onSearchToggle: () =>
                  setState(() => _searchVisible = !_searchVisible),
              onFilterTap: () => _showAdvancedFilters(data),
              onClearTap: () => _clearAllHistory(),
              hasActiveFilters: _moduleFilter != 'all' ||
                  _sectionFilter != null ||
                  (_dateFrom != null && _dateTo != null) ||
                  _groupBy != _GroupBy.date ||
                  _sortBy != _SortBy.newest,
            ),

            // 3) Collapsible search bar
            if (_searchVisible)
              _SearchBar(
                controller: _searchController,
                focusNode: _searchFocus,
                onChanged: (_) => setState(() => _refreshSeed++),
              ),

            // 4) Grouped list
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: data.processed.isEmpty
                    ? const _EmptyState()
                    : _GroupedList(
                        grouped: data.grouped,
                        groupBy: _groupBy,
                        hub: _hub,
                        onEntryDeleted: () =>
                            setState(() => _refreshSeed++),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Data model
// ═══════════════════════════════════════════════════════════════════════════════

class _HistData {
  final List<NotificationHubModule> modules;
  final List<NotificationLogEntry> rawLogs;
  final List<NotificationLogEntry> processed;
  final Map<String, List<NotificationLogEntry>> grouped;
  final List<String> sections;
  final int collapsedScheduleDuplicates;
  final Map<NotificationLifecycleEvent, int> eventCounts;

  const _HistData({
    required this.modules,
    required this.rawLogs,
    required this.processed,
    required this.grouped,
    required this.sections,
    required this.collapsedScheduleDuplicates,
    required this.eventCounts,
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// 1. Summary strip – colored count badges per event type
// ═══════════════════════════════════════════════════════════════════════════════

class _SummaryStrip extends StatelessWidget {
  final Map<NotificationLifecycleEvent, int> eventCounts;
  final NotificationLifecycleEvent? activeEvent;
  final ValueChanged<NotificationLifecycleEvent> onEventTap;

  const _SummaryStrip({
    required this.eventCounts,
    required this.activeEvent,
    required this.onEventTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Sort by count descending so the biggest shows first.
    final sorted = eventCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: sorted.map((entry) {
            final event = entry.key;
            final count = entry.value;
            final color = _eventColor(event);
            final isActive = activeEvent == event;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Material(
                color: isActive
                    ? color.withOpacity(isDark ? 0.3 : 0.2)
                    : color.withOpacity(isDark ? 0.1 : 0.07),
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onEventTap(event);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          event.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: color.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 2. Chip bar – horizontal quick filters + search + advanced filter icon
// ═══════════════════════════════════════════════════════════════════════════════

class _ChipBar extends StatelessWidget {
  final String activePreset;
  final ValueChanged<String> onPreset;
  final bool searchVisible;
  final VoidCallback onSearchToggle;
  final VoidCallback onFilterTap;
  final VoidCallback? onClearTap;
  final bool hasActiveFilters;

  const _ChipBar({
    required this.activePreset,
    required this.onPreset,
    required this.searchVisible,
    required this.onSearchToggle,
    required this.onFilterTap,
    this.onClearTap,
    required this.hasActiveFilters,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
      child: Row(
        children: [
          // Scrollable quick-filter chips
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _QuickChip(
                    label: 'All',
                    selected: activePreset == 'all',
                    onTap: () => onPreset('all'),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 6),
                  _QuickChip(
                    label: '24h',
                    selected: activePreset == '24h',
                    onTap: () => onPreset('24h'),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 6),
                  _QuickChip(
                    label: '7 Days',
                    selected: activePreset == '7d',
                    onTap: () => onPreset('7d'),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 6),
                  _QuickChip(
                    label: 'Failed',
                    selected: activePreset == 'failed',
                    onTap: () => onPreset('failed'),
                    isDark: isDark,
                    color: Colors.red,
                  ),
                ],
              ),
            ),
          ),
          // Search toggle
          _IconAction(
            icon: searchVisible
                ? Icons.search_off_rounded
                : Icons.search_rounded,
            onTap: onSearchToggle,
            isDark: isDark,
          ),
          // Clear all history
          if (onClearTap != null)
            _IconAction(
              icon: Icons.delete_sweep_rounded,
              onTap: onClearTap!,
              isDark: isDark,
              color: Colors.red.shade400,
            ),
          // Advanced filter icon
          Stack(
            children: [
              _IconAction(
                icon: Icons.tune_rounded,
                onTap: onFilterTap,
                isDark: isDark,
              ),
              if (hasActiveFilters)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColorSchemes.primaryGold,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isDark;
  final Color? color;

  const _QuickChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.isDark,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColorSchemes.primaryGold;
    return Material(
      color: selected
          ? c.withOpacity(isDark ? 0.25 : 0.15)
          : (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? c
                  : (isDark ? Colors.white70 : Colors.black54),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;
  final Color? color;

  const _IconAction({
    required this.icon,
    required this.onTap,
    required this.isDark,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      icon: Icon(icon, size: 22),
      color: color ?? (isDark ? Colors.white60 : Colors.black54),
      splashRadius: 20,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 3. Collapsible search bar
// ═══════════════════════════════════════════════════════════════════════════════

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search notifications...',
            isDense: true,
            prefixIcon: Icon(
              Icons.search_rounded,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 0,
              vertical: 12,
            ),
          ),
          style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 4. Advanced filter bottom sheet
// ═══════════════════════════════════════════════════════════════════════════════

class _AdvancedFilterSheet extends StatelessWidget {
  final NotificationHub hub;
  final List<NotificationHubModule> modules;
  final List<String> sections;
  final String selectedModule;
  final NotificationLifecycleEvent? selectedEvent;
  final String? selectedSection;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final _GroupBy groupBy;
  final _SortBy sortBy;
  final ValueChanged<String> onModuleChanged;
  final ValueChanged<NotificationLifecycleEvent?> onEventChanged;
  final ValueChanged<String?> onSectionChanged;
  final ValueChanged<_GroupBy> onGroupByChanged;
  final ValueChanged<_SortBy> onSortByChanged;
  final VoidCallback onDateRangeTap;
  final VoidCallback onClearDates;
  final VoidCallback onClearAll;

  const _AdvancedFilterSheet({
    required this.hub,
    required this.modules,
    required this.sections,
    required this.selectedModule,
    required this.selectedEvent,
    required this.selectedSection,
    required this.dateFrom,
    required this.dateTo,
    required this.groupBy,
    required this.sortBy,
    required this.onModuleChanged,
    required this.onEventChanged,
    required this.onSectionChanged,
    required this.onGroupByChanged,
    required this.onSortByChanged,
    required this.onDateRangeTap,
    required this.onClearDates,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A1D23) : const Color(0xFFF5F5F7);
    final muted = isDark ? Colors.white54 : Colors.black54;
    final hasDateRange = dateFrom != null && dateTo != null;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white30 : Colors.black26,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Advanced Filters',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),

          // Module
          _SheetDropdown<String>(
            label: 'Module',
            value: selectedModule,
            items: [
              const DropdownMenuItem(value: 'all', child: Text('All Modules')),
              ...modules.map(
                (m) => DropdownMenuItem(
                  value: m.moduleId,
                  child: Text(m.displayName),
                ),
              ),
            ],
            onChanged: (v) {
              if (v != null) onModuleChanged(v);
            },
            isDark: isDark,
          ),
          const SizedBox(height: 12),

          // Event type
          _SheetDropdown<String>(
            label: 'Event',
            value: selectedEvent?.name ?? 'all',
            items: [
              const DropdownMenuItem(value: 'all', child: Text('All Events')),
              ...NotificationLifecycleEvent.values.map(
                (e) => DropdownMenuItem(
                  value: e.name,
                  child: Text(e.label),
                ),
              ),
            ],
            onChanged: (v) => onEventChanged(
              v == 'all' ? null : notificationLifecycleEventFromStorage(v),
            ),
            isDark: isDark,
          ),
          const SizedBox(height: 12),

          // Section (only if sections exist)
          if (sections.isNotEmpty) ...[
            _SheetDropdown<String?>(
              label: 'Section',
              value: selectedSection,
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All Sections'),
                ),
                ...sections.map(
                  (s) => DropdownMenuItem<String?>(
                    value: s,
                    child: Text(_prettySectionLabel(s)),
                  ),
                ),
              ],
              onChanged: (v) => onSectionChanged(v),
              isDark: isDark,
            ),
            const SizedBox(height: 12),
          ],

          // Group + Sort row
          Row(
            children: [
              Expanded(
                child: _SheetDropdown<_GroupBy>(
                  label: 'Group by',
                  value: groupBy,
                  items: const [
                    DropdownMenuItem(value: _GroupBy.none, child: Text('None')),
                    DropdownMenuItem(value: _GroupBy.date, child: Text('Date')),
                    DropdownMenuItem(
                      value: _GroupBy.module,
                      child: Text('Module'),
                    ),
                    DropdownMenuItem(
                      value: _GroupBy.event,
                      child: Text('Event'),
                    ),
                    DropdownMenuItem(
                      value: _GroupBy.section,
                      child: Text('Section'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) onGroupByChanged(v);
                  },
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SheetDropdown<_SortBy>(
                  label: 'Sort by',
                  value: sortBy,
                  items: const [
                    DropdownMenuItem(
                      value: _SortBy.newest,
                      child: Text('Newest'),
                    ),
                    DropdownMenuItem(
                      value: _SortBy.oldest,
                      child: Text('Oldest'),
                    ),
                    DropdownMenuItem(
                      value: _SortBy.module,
                      child: Text('Module'),
                    ),
                    DropdownMenuItem(
                      value: _SortBy.event,
                      child: Text('Event'),
                    ),
                    DropdownMenuItem(
                      value: _SortBy.title,
                      child: Text('Title'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) onSortByChanged(v);
                  },
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Date range
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onDateRangeTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: hasDateRange
                    ? AppColorSchemes.primaryGold.withOpacity(0.1)
                    : (isDark
                        ? Colors.white.withOpacity(0.06)
                        : Colors.black.withOpacity(0.04)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_month_rounded,
                    size: 20,
                    color: hasDateRange
                        ? AppColorSchemes.primaryGold
                        : muted,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      hasDateRange
                          ? '${DateFormat('MMM d').format(dateFrom!)} - ${DateFormat('MMM d').format(dateTo!.subtract(const Duration(days: 1)))}'
                          : 'Select date range',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: hasDateRange
                            ? AppColorSchemes.primaryGold
                            : muted,
                      ),
                    ),
                  ),
                  if (hasDateRange)
                    GestureDetector(
                      onTap: onClearDates,
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Colors.red.withOpacity(0.7),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Clear All History
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onClearAll,
              icon: const Icon(Icons.delete_sweep_rounded, size: 20),
              label: const Text('Clear All History'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: BorderSide(color: Colors.red.withOpacity(0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  static String _prettySectionLabel(String id) {
    if (id.isEmpty) return id;
    return id
        .split(RegExp(r'[_\s]+'))
        .map(
          (w) => w.isEmpty
              ? ''
              : '${w[0].toUpperCase()}${w.length > 1 ? w.substring(1) : ''}',
        )
        .join(' ');
  }
}

class _SheetDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final bool isDark;

  const _SheetDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white54 : Colors.black54,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.black.withOpacity(0.04),
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              items: items,
              onChanged: onChanged,
              isExpanded: true,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 5. Grouped list with strong section headers
// ═══════════════════════════════════════════════════════════════════════════════

class _GroupedList extends StatelessWidget {
  final Map<String, List<NotificationLogEntry>> grouped;
  final _GroupBy groupBy;
  final NotificationHub hub;
  final VoidCallback? onEntryDeleted;

  const _GroupedList({
    required this.grouped,
    required this.groupBy,
    required this.hub,
    this.onEntryDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final entries = <Widget>[];

    for (final entry in grouped.entries) {
      final key = entry.key;
      final items = entry.value;

      // Group header
      if (key.isNotEmpty && groupBy != _GroupBy.none) {
        entries.add(
          Padding(
            padding: EdgeInsets.fromLTRB(
              4,
              entries.isEmpty ? 4 : 20,
              4,
              8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          key.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: isDark
                                ? Colors.white38
                                : Colors.black38,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColorSchemes.primaryGold.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${items.length}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColorSchemes.primaryGold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Thin divider line
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 1,
                    color: isDark
                        ? Colors.white.withOpacity(0.06)
                        : Colors.black.withOpacity(0.06),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      for (final e in items) {
        entries.add(
          _HistTile(
            entry: e,
            hub: hub,
            onEntryDeleted: onEntryDeleted,
          ),
        );
      }
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 48),
      children: entries,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 6. Clean minimal history tile
// ═══════════════════════════════════════════════════════════════════════════════

class _HistTile extends StatelessWidget {
  final NotificationLogEntry entry;
  final NotificationHub hub;
  final VoidCallback? onEntryDeleted;

  const _HistTile({
    required this.entry,
    required this.hub,
    this.onEntryDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final eventColor = _eventColor(entry.event);

    return GestureDetector(
      onTap: () {
        HubHistoryEntryDetailSheet.show(
          context,
          entry: entry,
          hub: hub,
          isDark: isDark,
          onDeleted: onEntryDeleted,
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.transparent,
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
            // Event dot
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: eventColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),

            // Title + body preview
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title.isEmpty ? 'Notification' : entry.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
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
                        color: isDark ? Colors.white38 : Colors.black45,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Time + event label
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _fmtTime(entry.timestamp),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.event.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: eventColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _fmtTime(DateTime t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(t.year, t.month, t.day);

    if (date == today) {
      return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    } else if (date == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return DateFormat('MMM d').format(t);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Empty state
// ═══════════════════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_rounded,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No history found',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try different filters or date range.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Shared helpers
// ═══════════════════════════════════════════════════════════════════════════════

Color _eventColor(NotificationLifecycleEvent event) {
  return switch (event) {
    NotificationLifecycleEvent.scheduled => Colors.blue,
    NotificationLifecycleEvent.delivered => Colors.green,
    NotificationLifecycleEvent.tapped => Colors.green,
    NotificationLifecycleEvent.action => Colors.teal,
    NotificationLifecycleEvent.snoozed => Colors.deepPurple,
    NotificationLifecycleEvent.cancelled => Colors.orange,
    NotificationLifecycleEvent.missed => Colors.amber,
    NotificationLifecycleEvent.failed => Colors.red,
  };
}
