import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/notifications/notifications.dart';
import '../../../../core/theme/color_schemes.dart';
import '../../../finance/notifications/finance_notification_contract.dart';
import '../../../sleep/notifications/sleep_notification_contract.dart';
import '../utils/notifications_paging.dart';
import '../widgets/scheduled_notification_detail_sheet.dart';

/// Formats unknown section IDs for display (e.g. "recurring_income" -> "Recurring Income").
String _formatSectionIdForDisplay(String sectionId) {
  if (sectionId.isEmpty) return '';
  return sectionId
      .split(RegExp(r'[_\s]+'))
      .map(
        (p) =>
            p.isEmpty ? '' : p[0].toUpperCase() + p.substring(1).toLowerCase(),
      )
      .join(' ');
}

/// Hub page showing ALL scheduled notifications across the super app.
///
/// Modern UI with filter (by mini app, by section) and hierarchical grouping:
/// Mini App → Section → Entity. Uses [NotificationHub.getAllScheduledNotifications]
/// so it has access to every notification scheduled by Finance, Tasks, Habits,
/// Sleep, and any other modules.
class HubUnifiedNotificationsPage extends StatefulWidget {
  const HubUnifiedNotificationsPage({super.key});

  @override
  State<HubUnifiedNotificationsPage> createState() =>
      _HubUnifiedNotificationsPageState();
}

class _HubUnifiedNotificationsPageState
    extends State<HubUnifiedNotificationsPage> {
  static const int _pageSize = 60;

  int _refreshKey = 0;
  String? _filterModuleId;
  String? _filterSection;
  final ScrollController _scrollController = ScrollController();
  int _visibleCount = NotificationsPaging.initialVisible(pageSize: _pageSize);
  Future<List<Map<String, dynamic>>>? _notificationsFuture;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _notificationsFuture = _loadNotifications();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.maxScrollExtent <= 0) return;
    if (position.pixels < position.maxScrollExtent - 240) return;

    setState(() {
      _visibleCount = NotificationsPaging.nextVisible(
        _visibleCount,
        pageSize: _pageSize,
      );
    });
  }

  void _resetPaging() {
    _visibleCount = NotificationsPaging.initialVisible(pageSize: _pageSize);
  }

  Future<List<Map<String, dynamic>>> _loadNotifications() async {
    final hub = NotificationHub();
    await hub.initialize();
    return hub.getAllScheduledNotifications();
  }

  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> list) {
    var result = list;

    if (_filterModuleId != null) {
      result = result
          .where((n) => (n['moduleId'] as String? ?? '') == _filterModuleId)
          .toList();
    }

    if (_filterSection != null) {
      result = result
          .where((n) => (n['section'] as String? ?? '') == _filterSection)
          .toList();
    }

    return result;
  }

  List<_HierarchicalItem> _groupNotifications(
    List<Map<String, dynamic>> list,
    NotificationHub hub,
  ) {
    final Map<String, _NotificationGroup> entityMap = {};

    for (final n in list) {
      final entityId = n['entityId'] as String? ?? '';
      final targetId = n['targetEntityId'] as String?;
      final moduleId = n['moduleId'] as String? ?? '';
      final section = n['section'] as String? ?? '';
      final title = n['title'] as String? ?? 'Notification';

      String groupKey;
      String groupLabel;

      if (entityId.startsWith('bill:')) {
        final parts = entityId.split(':');
        final billId = targetId ?? (parts.length >= 2 ? parts[1] : entityId);
        groupKey = 'bill:$billId';
        groupLabel = _entityNameFromTitle(title) ?? 'Bill / Subscription';
      } else if (entityId.startsWith('debt:')) {
        final parts = entityId.split(':');
        final debtId = targetId ?? (parts.length >= 3 ? parts[2] : entityId);
        final dir = parts.length >= 2 ? parts[1] : '';
        groupKey = 'debt:$dir:$debtId';
        groupLabel =
            _entityNameFromTitle(title) ?? (dir == 'lent' ? 'Lending' : 'Debt');
      } else if (entityId.startsWith('budget:')) {
        groupKey = entityId.length > 12 ? entityId.substring(0, 30) : entityId;
        groupLabel = _entityNameFromTitle(title) ?? 'Budget';
      } else if (entityId.startsWith('task') ||
          moduleId == NotificationHubModuleIds.task) {
        groupKey = 'task:${targetId ?? entityId}';
        groupLabel = _entityNameFromTitle(title) ?? 'Task';
      } else if (entityId.startsWith('habit') ||
          moduleId == NotificationHubModuleIds.habit) {
        groupKey = 'habit:${targetId ?? entityId}';
        groupLabel = _entityNameFromTitle(title) ?? 'Habit';
      } else if (moduleId == NotificationHubModuleIds.sleep &&
          section.isNotEmpty &&
          (section == SleepNotificationContract.sectionBedtime ||
              section == SleepNotificationContract.sectionWakeup ||
              section == SleepNotificationContract.sectionWinddown)) {
        groupKey = 'sleep:$section';
        groupLabel = _sleepSectionLabel(section);
      } else if (section.isNotEmpty) {
        // Generic: any module with sections groups by module:section
        groupKey = '$moduleId:$section';
        groupLabel =
            hub.sectionDisplayName(moduleId, section) ??
            _sectionLabel(section) ??
            _formatSectionIdForDisplay(section);
      } else {
        groupKey = entityId.isNotEmpty ? entityId : 'single:${n.hashCode}';
        groupLabel =
            _entityNameFromTitle(title) ?? hub.moduleDisplayName(moduleId);
      }

      entityMap
          .putIfAbsent(
            groupKey,
            () => _NotificationGroup(
              key: groupKey,
              label: groupLabel,
              section: section,
              moduleId: moduleId,
              notifications: [],
            ),
          )
          .notifications
          .add(n);
    }

    final groups = entityMap.values.toList();
    for (final g in groups) {
      g.notifications.sort((a, b) {
        final aT = a['scheduledAt'] as DateTime?;
        final bT = b['scheduledAt'] as DateTime?;
        if (aT == null || bT == null) return 0;
        return aT.compareTo(bT);
      });
    }

    final byModule = <String, Map<String, List<_NotificationGroup>>>{};
    for (final g in groups) {
      final sec = g.section.isNotEmpty ? g.section : 'other';
      byModule
          .putIfAbsent(g.moduleId, () => {})
          .putIfAbsent(sec, () => [])
          .add(g);
    }

    // Known modules first, then any other registered modules
    const knownOrder = [
      FinanceNotificationContract.moduleId,
      NotificationHubModuleIds.task,
      NotificationHubModuleIds.habit,
      NotificationHubModuleIds.sleep,
    ];
    final registered = hub
        .getRegisteredModules()
        .map((m) => m.moduleId)
        .toList();
    final moduleOrder = [
      ...knownOrder.where(registered.contains),
      ...registered.where((id) => !knownOrder.contains(id)),
    ];
    final sectionOrder = [
      FinanceNotificationContract.sectionBills,
      FinanceNotificationContract.sectionDebts,
      FinanceNotificationContract.sectionLending,
      FinanceNotificationContract.sectionBudgets,
      FinanceNotificationContract.sectionSavingsGoals,
      FinanceNotificationContract.sectionRecurringIncome,
      SleepNotificationContract.sectionBedtime,
      SleepNotificationContract.sectionWakeup,
      SleepNotificationContract.sectionWinddown,
    ];

    final allModuleKeys = <String>[
      ...moduleOrder.where(byModule.containsKey),
      ...byModule.keys.where((k) => !moduleOrder.contains(k)),
    ];

    final bool singleModule = allModuleKeys.length == 1;

    final result = <_HierarchicalItem>[];
    for (final mid in allModuleKeys) {
      final bySection = byModule[mid];
      if (bySection == null || bySection.isEmpty) continue;

      if (!singleModule) {
        result.add(_HierarchicalItem.moduleHeader(moduleId: mid));
      }

      final orderedSections = moduleOrder.contains(mid)
          ? <String>[
              ...sectionOrder.where(bySection.containsKey),
              ...bySection.keys.where((s) => !sectionOrder.contains(s)),
            ]
          : bySection.keys.toList();

      final bool singleSection = orderedSections.length == 1;

      for (final sec in orderedSections) {
        final entityGroups = bySection[sec]!;
        if (entityGroups.isEmpty) continue;
        entityGroups.sort((a, b) {
          final aFirst =
              a.notifications.firstOrNull?['scheduledAt'] as DateTime?;
          final bFirst =
              b.notifications.firstOrNull?['scheduledAt'] as DateTime?;
          if (aFirst == null || bFirst == null) return 0;
          return aFirst.compareTo(bFirst);
        });
        if (!singleSection) {
          result.add(
            _HierarchicalItem.sectionHeader(section: sec, moduleId: mid),
          );
        }
        for (final eg in entityGroups) {
          result.add(_HierarchicalItem.entityGroup(group: eg));
        }
      }
    }
    return result;
  }

  String? _entityNameFromTitle(String title) {
    final lower = title.toLowerCase();
    const stopPhrases = [
      ' due ',
      ' payment ',
      ' reminder ',
      ' is ',
      ' overdue',
      ' tomorrow',
      ' today',
    ];
    for (final phrase in stopPhrases) {
      final idx = lower.indexOf(phrase);
      if (idx > 0) {
        final name = title.substring(0, idx).trim();
        if (name.length >= 2) return name;
      }
    }
    if (title.length <= 40) return title;
    return '${title.substring(0, 37)}...';
  }

  String? _sectionLabel(String section) {
    switch (section) {
      case FinanceNotificationContract.sectionBills:
        return 'Bills';
      case FinanceNotificationContract.sectionDebts:
        return 'Debts';
      case FinanceNotificationContract.sectionLending:
        return 'Lending';
      case FinanceNotificationContract.sectionBudgets:
        return 'Budgets';
      case FinanceNotificationContract.sectionSavingsGoals:
        return 'Savings';
      case FinanceNotificationContract.sectionRecurringIncome:
        return 'Income';
      case SleepNotificationContract.sectionBedtime:
        return 'Bedtime';
      case SleepNotificationContract.sectionWakeup:
        return 'Wake Up';
      case SleepNotificationContract.sectionWinddown:
        return 'Wind-Down';
      default:
        return section.isNotEmpty ? section : null;
    }
  }

  String _sleepSectionLabel(String section) {
    switch (section) {
      case SleepNotificationContract.sectionBedtime:
        return 'Bedtime';
      case SleepNotificationContract.sectionWakeup:
        return 'Wake Up';
      case SleepNotificationContract.sectionWinddown:
        return 'Wind-Down';
      default:
        return section;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hub = NotificationHub();

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Reminders'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        key: ValueKey(_refreshKey),
        future: _notificationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load reminders',
                      style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final all = snapshot.data ?? [];
          if (all.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.notifications_none_rounded,
                      size: 64,
                      color: (isDark ? Colors.white : Colors.black).withValues(
                        alpha: 0.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No reminders scheduled',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Reminders from Finance, Tasks, Habits, Sleep and other modules will appear here when scheduled.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final filtered = _applyFilter(all);
          final visibleCount = NotificationsPaging.clampVisible(
            totalCount: filtered.length,
            requestedVisible: _visibleCount,
          );
          final visibleNotifications = filtered.take(visibleCount).toList();
          final items = _groupNotifications(visibleNotifications, hub);
          final hasMore = NotificationsPaging.hasMore(
            totalCount: filtered.length,
            visibleCount: visibleCount,
          );

          if (filtered.isEmpty) {
            return Column(
              children: [
                _FilterBar(
                  all: all,
                  filterModuleId: _filterModuleId,
                  filterSection: _filterSection,
                  hub: hub,
                  isDark: isDark,
                  theme: theme,
                  onModuleChanged: (id) => setState(() {
                    _filterModuleId = id;
                    _filterSection = null;
                    _resetPaging();
                  }),
                  onSectionChanged: (id) => setState(() {
                    _filterSection = id;
                    _resetPaging();
                  }),
                ),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.filter_list_rounded,
                            size: 64,
                            color: (isDark ? Colors.white : Colors.black)
                                .withValues(alpha: 0.2),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No reminders match the current filter',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () => setState(() {
                              _filterModuleId = null;
                              _filterSection = null;
                              _resetPaging();
                            }),
                            icon: const Icon(Icons.clear_all_rounded, size: 18),
                            label: const Text('Clear filters'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FilterBar(
                all: all,
                filterModuleId: _filterModuleId,
                filterSection: _filterSection,
                hub: hub,
                isDark: isDark,
                theme: theme,
                onModuleChanged: (id) => setState(() {
                  _filterModuleId = id;
                  _filterSection = null;
                  _resetPaging();
                }),
                onSectionChanged: (id) => setState(() {
                  _filterSection = id;
                  _resetPaging();
                }),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    HapticFeedback.mediumImpact();
                    setState(() {
                      _refreshKey++;
                      _notificationsFuture = _loadNotifications();
                      _resetPaging();
                    });
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: items.length + (hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= items.length) {
                        final remaining = filtered.length - visibleCount;
                        return _LoadMoreHint(
                          remainingCount: remaining,
                          isDark: isDark,
                          onTap: () => setState(() {
                            _visibleCount = NotificationsPaging.nextVisible(
                              _visibleCount,
                              pageSize: _pageSize,
                            );
                          }),
                        );
                      }

                      final item = items[index];
                      if (item.isModuleHeader) {
                        return _ModuleHeader(
                          moduleId: item.moduleId!,
                          hub: hub,
                          theme: theme,
                        );
                      }
                      if (item.isSectionHeader) {
                        return _SectionHeader(
                          section: item.section!,
                          moduleId: item.moduleId ?? '',
                          hub: hub,
                          isDark: isDark,
                          theme: theme,
                        );
                      }
                      return _GroupCard(
                        group: item.group!,
                        hub: hub,
                        isDark: isDark,
                        theme: theme,
                        onNotificationTap: (notif) {
                          HapticFeedback.lightImpact();
                          ScheduledNotificationDetailSheet.show(
                            context,
                            notif: notif,
                            hub: hub,
                            isDark: isDark,
                            onDeleted: () => setState(() {
                              _refreshKey++;
                              _notificationsFuture = _loadNotifications();
                              _resetPaging();
                            }),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NotificationGroup {
  final String key;
  final String label;
  final String section;
  final String moduleId;
  final List<Map<String, dynamic>> notifications;

  _NotificationGroup({
    required this.key,
    required this.label,
    required this.section,
    required this.moduleId,
    required this.notifications,
  });
}

class _HierarchicalItem {
  final String? moduleId;
  final String? section;
  final _NotificationGroup? group;

  _HierarchicalItem._({this.moduleId, this.section, this.group});

  /// For section headers, moduleId identifies which module this section belongs to.
  String? get sectionModuleId => moduleId;

  factory _HierarchicalItem.moduleHeader({required String moduleId}) =>
      _HierarchicalItem._(moduleId: moduleId);

  factory _HierarchicalItem.sectionHeader({
    required String section,
    required String moduleId,
  }) => _HierarchicalItem._(section: section, moduleId: moduleId);

  factory _HierarchicalItem.entityGroup({required _NotificationGroup group}) =>
      _HierarchicalItem._(group: group);

  bool get isModuleHeader => moduleId != null;
  bool get isSectionHeader => section != null && group == null;
}

class _ModuleHeader extends StatelessWidget {
  final String moduleId;
  final NotificationHub hub;
  final ThemeData theme;

  const _ModuleHeader({
    required this.moduleId,
    required this.hub,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final name = hub.moduleDisplayName(moduleId);
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        name.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String section;
  final String moduleId;
  final NotificationHub hub;
  final bool isDark;
  final ThemeData theme;

  const _SectionHeader({
    required this.section,
    required this.moduleId,
    required this.hub,
    required this.isDark,
    required this.theme,
  });

  String _label(String s) {
    return hub.sectionDisplayName(moduleId, s) ??
        _FilterBar._knownSectionLabel(s) ??
        (s.isNotEmpty ? _formatSectionIdForDisplay(s) : 'Other');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Text(
        _label(section),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColorSchemes.primaryGold.withValues(
            alpha: isDark ? 0.9 : 0.85,
          ),
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final List<Map<String, dynamic>> all;
  final String? filterModuleId;
  final String? filterSection;
  final NotificationHub hub;
  final bool isDark;
  final ThemeData theme;
  final void Function(String?) onModuleChanged;
  final void Function(String?) onSectionChanged;

  const _FilterBar({
    required this.all,
    required this.filterModuleId,
    required this.filterSection,
    required this.hub,
    required this.isDark,
    required this.theme,
    required this.onModuleChanged,
    required this.onSectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final modules = <String, int>{};
    for (final n in all) {
      final id = n['moduleId'] as String? ?? 'unknown';
      modules[id] = (modules[id] ?? 0) + 1;
    }
    // Build sections for the selected module (any module, not just Finance)
    final sections = <String, int>{};
    if (filterModuleId != null) {
      for (final n in all) {
        if ((n['moduleId'] as String? ?? '') == filterModuleId) {
          final sec = n['section'] as String? ?? 'other';
          sections[sec] = (sections[sec] ?? 0) + 1;
        }
      }
    }
    final showSectionFilter = filterModuleId != null && sections.length > 1;

    final moduleChips = <Widget>[
      _FilterChip(
        label: 'All',
        count: all.length,
        isSelected: filterModuleId == null,
        isDark: isDark,
        onTap: () => onModuleChanged(null),
      ),
      ...modules.entries.map((e) {
        final name = hub.moduleDisplayName(e.key);
        return _FilterChip(
          label: name,
          count: e.value,
          isSelected: filterModuleId == e.key,
          isDark: isDark,
          onTap: () => onModuleChanged(e.key),
        );
      }),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      color: theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FILTER BY APP',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 8),
          _buildChipRow(
            chips: moduleChips,
            expandWhenFew: moduleChips.length <= 2,
          ),
          if (showSectionFilter) ...[
            const SizedBox(height: 12),
            Text(
              'FILTER BY CATEGORY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.8,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All',
                    count: all
                        .where(
                          (n) =>
                              (n['moduleId'] as String? ?? '') ==
                              filterModuleId,
                        )
                        .length,
                    isSelected: filterSection == null,
                    isDark: isDark,
                    onTap: () => onSectionChanged(null),
                  ),
                  ...sections.entries.where((e) => e.key != 'other').map((e) {
                    final label = _sectionDisplayLabel(
                      hub,
                      filterModuleId!,
                      e.key,
                    );
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _FilterChip(
                        label: label,
                        count: e.value,
                        isSelected: filterSection == e.key,
                        isDark: isDark,
                        onTap: () => onSectionChanged(e.key),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChipRow({
    required List<Widget> chips,
    required bool expandWhenFew,
  }) {
    if (expandWhenFew) {
      return Row(children: _withSpacing(chips, expand: true));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: _withSpacing(chips)),
    );
  }

  List<Widget> _withSpacing(List<Widget> children, {bool expand = false}) {
    final spaced = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        spaced.add(const SizedBox(width: 8));
      }
      final child = children[i];
      spaced.add(expand ? Expanded(child: child) : child);
    }
    return spaced;
  }

  String _sectionDisplayLabel(
    NotificationHub hub,
    String moduleId,
    String section,
  ) {
    return hub.sectionDisplayName(moduleId, section) ??
        _knownSectionLabel(section) ??
        _formatSectionIdForDisplay(section);
  }

  static String? _knownSectionLabel(String section) {
    switch (section) {
      case FinanceNotificationContract.sectionBills:
        return 'Bills';
      case FinanceNotificationContract.sectionDebts:
        return 'Debts';
      case FinanceNotificationContract.sectionLending:
        return 'Lending';
      case FinanceNotificationContract.sectionBudgets:
        return 'Budgets';
      case FinanceNotificationContract.sectionSavingsGoals:
        return 'Savings';
      case FinanceNotificationContract.sectionRecurringIncome:
        return 'Income';
      case SleepNotificationContract.sectionBedtime:
        return 'Bedtime';
      case SleepNotificationContract.sectionWakeup:
        return 'Wake Up';
      case SleepNotificationContract.sectionWinddown:
        return 'Wind-Down';
      default:
        return null;
    }
  }
}

class _LoadMoreHint extends StatelessWidget {
  final int remainingCount;
  final bool isDark;
  final VoidCallback onTap;

  const _LoadMoreHint({
    required this.remainingCount,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Center(
        child: TextButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.expand_more_rounded),
          label: Text(
            remainingCount > 0
                ? 'Load more ($remainingCount remaining)'
                : 'Load more',
          ),
          style: TextButton.styleFrom(
            foregroundColor: isDark
                ? Colors.white.withValues(alpha: 0.8)
                : theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColorSchemes.primaryGold.withValues(
                  alpha: isDark ? 0.25 : 0.2,
                )
              : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColorSchemes.primaryGold.withValues(alpha: 0.6)
                : (isDark ? Colors.white : Colors.black).withValues(
                    alpha: 0.08,
                  ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected
                      ? AppColorSchemes.primaryGold
                      : (isDark ? Colors.white70 : Colors.black54),
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withValues(
                  alpha: 0.1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupCard extends StatefulWidget {
  final _NotificationGroup group;
  final NotificationHub hub;
  final bool isDark;
  final ThemeData theme;
  final void Function(Map<String, dynamic>) onNotificationTap;

  const _GroupCard({
    required this.group,
    required this.hub,
    required this.isDark,
    required this.theme,
    required this.onNotificationTap,
  });

  @override
  State<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<_GroupCard> {
  bool _expanded = false;

  String _sectionLabel(NotificationHub hub, String moduleId, String section) {
    return hub.sectionDisplayName(moduleId, section) ??
        _FilterBar._knownSectionLabel(section) ??
        (section.isNotEmpty ? _formatSectionIdForDisplay(section) : '');
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final hub = widget.hub;
    final isDark = widget.isDark;
    final theme = widget.theme;
    final onNotificationTap = widget.onNotificationTap;
    final showExpand = group.notifications.length > 1;
    final expanded = showExpand ? _expanded : true;

    final cardBg = isDark
        ? theme.colorScheme.surfaceContainerLow
        : theme.colorScheme.surfaceContainerHighest;
    final border = (isDark ? Colors.white : Colors.black).withValues(
      alpha: isDark ? 0.08 : 0.06,
    );

    final sectionLabel = _sectionLabel(hub, group.moduleId, group.section);
    final moduleName = hub.moduleDisplayName(group.moduleId);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: showExpand
                  ? () => setState(() => _expanded = !_expanded)
                  : null,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.label,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (sectionLabel.isNotEmpty)
                                _CategoryChip(
                                  label: sectionLabel,
                                  isDark: isDark,
                                ),
                              _CategoryChip(label: moduleName, isDark: isDark),
                              Text(
                                '${group.notifications.length} reminder${group.notifications.length == 1 ? '' : 's'}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (showExpand)
                      Icon(
                        expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.5),
                        size: 24,
                      ),
                  ],
                ),
              ),
            ),
            if (expanded) ...[
              Divider(
                height: 1,
                thickness: 1,
                color: border,
                indent: 16,
                endIndent: 16,
              ),
              ...group.notifications.asMap().entries.map((entry) {
                final idx = entry.key;
                final notif = entry.value;
                final isLast = idx == group.notifications.length - 1;
                final title = notif['title'] as String? ?? 'Notification';
                final body = notif['body'] as String? ?? '';
                final scheduledAt = notif['scheduledAt'] as DateTime?;
                final timeStr = scheduledAt != null
                    ? DateFormat('HH:mm').format(scheduledAt)
                    : '—';
                final relativeStr = scheduledAt != null
                    ? _relativeTime(scheduledAt)
                    : '';

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onNotificationTap(notif),
                    borderRadius: isLast
                        ? const BorderRadius.vertical(
                            bottom: Radius.circular(16),
                          )
                        : BorderRadius.zero,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 56,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  timeStr,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppColorSchemes.primaryGold,
                                  ),
                                ),
                                if (relativeStr.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    relativeStr,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (body.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    body,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  String _relativeTime(DateTime scheduledAt) {
    final now = DateTime.now();
    final diff = scheduledAt.difference(now);

    if (diff.isNegative) return 'past';
    if (diff.inMinutes < 60) return 'in ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'in ${diff.inHours}h';
    if (diff.inDays == 1) return 'tomorrow';
    if (diff.inDays < 7) return 'in ${diff.inDays}d';
    return DateFormat('MMM d').format(scheduledAt);
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isDark;

  const _CategoryChip({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColorSchemes.primaryGold.withValues(
          alpha: isDark ? 0.15 : 0.12,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColorSchemes.primaryGold,
        ),
      ),
    );
  }
}
