import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/notifications/notifications.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/color_schemes.dart';
import '../../../../core/widgets/settings_widgets.dart';
import '../../../finance/notifications/finance_notification_contract.dart';
import '../../../sleep/notifications/sleep_notification_contract.dart';
import 'hub_finance_module_page.dart';
import 'hub_habit_module_page.dart';
import 'hub_module_detail_page.dart';
import 'hub_failed_notifications_page.dart';
import 'hub_sleep_module_page.dart';
import 'hub_task_module_page.dart';
import 'hub_unified_notifications_page.dart';
import '../widgets/hub_activity_detail_sheet.dart';

/// Dashboard page – overview of all hub notifications.
class HubDashboardPage extends StatefulWidget {
  final VoidCallback onNavigateToSettings;
  final VoidCallback onNavigateToPermissions;

  const HubDashboardPage({
    super.key,
    required this.onNavigateToSettings,
    required this.onNavigateToPermissions,
  });

  @override
  State<HubDashboardPage> createState() => _HubDashboardPageState();
}

class _HubDashboardPageState extends State<HubDashboardPage> {
  final NotificationHub _hub = NotificationHub();
  int _refreshSeed = 0;

  Future<_DashData> _load() async {
    await _hub.initialize();
    final summary = await _hub.getDashboardSummary();
    final modules = _hub.getRegisteredModules();
    final enabledStates = await _hub.getModuleEnabledStates();

    final hasModules = modules.isNotEmpty;
    final modulesEnabledCount = enabledStates.values.where((e) => e).length;
    final hasPending = summary.totalPending > 0;
    final noFailures = summary.failedToday == 0;

    var healthScore = 0;
    int modulesScore = 0;
    if (hasModules) {
      healthScore += 25;
      modulesScore = 25;
    }
    int enabledScore = 0;
    if (modulesEnabledCount == modules.length && modules.isNotEmpty) {
      healthScore += 25;
      enabledScore = 25;
    } else if (modulesEnabledCount > 0) {
      healthScore += 15;
      enabledScore = 15;
    }
    int pendingScore = 0;
    if (hasPending) {
      healthScore += 25;
      pendingScore = 25;
    }
    int failuresScore = 0;
    if (noFailures) {
      healthScore += 25;
      failuresScore = 25;
    }

    return _DashData(
      summary: summary,
      modules: modules,
      enabledStates: enabledStates,
      healthScore: healthScore,
      healthBreakdown: _HealthBreakdown(
        modulesScore: modulesScore,
        modulesLabel: hasModules
            ? '${modules.length} modules registered'
            : 'No modules registered',
        enabledScore: enabledScore,
        enabledLabel: modules.isEmpty
            ? 'N/A'
            : modulesEnabledCount == modules.length
                ? 'All ${modules.length} enabled'
                : '$modulesEnabledCount of ${modules.length} enabled',
        pendingScore: pendingScore,
        pendingLabel:
            hasPending ? '${summary.totalPending} scheduled' : 'No scheduled',
        failuresScore: failuresScore,
        failuresLabel: noFailures
            ? 'No failures today'
            : '${summary.failedToday} failed today',
      ),
    );
  }

  Future<void> _refresh() async {
    HapticFeedback.mediumImpact();
    setState(() => _refreshSeed++);
  }

  void _showHealthBreakdownSheet(
    BuildContext context,
    int score,
    _HealthBreakdown breakdown, {
    required VoidCallback onOpenPermissions,
  }) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _HubHealthBreakdownSheet(
        score: score,
        breakdown: breakdown,
        onOpenPermissions: onOpenPermissions,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DashData>(
      key: ValueKey('dashboard-$_refreshSeed'),
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }
        if (snapshot.hasError) {
          return _ErrorRetry(
            message: 'Failed to load dashboard',
            onRetry: _refresh,
          );
        }

        final data = snapshot.data!;
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final summary = data.summary;

        return RefreshIndicator(
          onRefresh: _refresh,
          displacement: 20,
          color: AppColorSchemes.primaryGold,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 48),
            children: [
              // ── Headline card ──
              _HeadlineCard(
                count: summary.totalPending,
                subtitle: summary.nextUpcoming == null
                    ? 'No upcoming notifications'
                    : 'Next: ${_hub.moduleDisplayName(summary.nextUpcoming!.moduleId)}',
                time: summary.nextUpcoming == null
                    ? null
                    : _fmt(summary.nextUpcoming!.scheduledAt),
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const HubUnifiedNotificationsPage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),

              // ── Health score ──
              _HealthScoreCard(
                score: data.healthScore,
                onTap: () => _showHealthBreakdownSheet(
                  context,
                  data.healthScore,
                  data.healthBreakdown,
                  onOpenPermissions: widget.onNavigateToPermissions,
                ),
              ),
              const SizedBox(height: 16),

              // ── Quick actions ──
              _QuickActionCard(
                icon: Icons.list_alt_rounded,
                label: 'All Reminders',
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const HubUnifiedNotificationsPage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.settings_rounded,
                      label: 'Settings',
                      onTap: widget.onNavigateToSettings,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.security_rounded,
                      label: 'Permissions',
                      onTap: widget.onNavigateToPermissions,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Activity today ──
              SettingsSection(
                title: 'ACTIVITY TODAY',
                icon: Icons.bar_chart_rounded,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                      _StatChip(
                        label: 'Scheduled',
                        value: summary.totalPending,
                        icon: Icons.calendar_today_rounded,
                        color: Colors.blue,
                        onTap: summary.totalPending > 0
                            ? () {
                                HapticFeedback.lightImpact();
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const HubUnifiedNotificationsPage(),
                                  ),
                                );
                              }
                            : null,
                      ),
                      const SizedBox(width: 8),
                      _StatChip(
                        label: 'Tapped',
                        value: summary.tappedToday,
                        icon: Icons.touch_app_rounded,
                        color: Colors.green,
                        onTap: summary.tappedToday > 0
                            ? () async {
                                HapticFeedback.lightImpact();
                                await HubActivityDetailSheet.show(
                                  context,
                                  event: NotificationLifecycleEvent.tapped,
                                );
                                if (mounted) _refresh();
                              }
                            : null,
                      ),
                      const SizedBox(width: 8),
                      _StatChip(
                        label: 'Actions',
                        value: summary.actionToday,
                        icon: Icons.bolt_rounded,
                        color: Colors.amber,
                        onTap: summary.actionToday > 0
                            ? () async {
                                HapticFeedback.lightImpact();
                                await HubActivityDetailSheet.show(
                                  context,
                                  event: NotificationLifecycleEvent.action,
                                );
                                if (mounted) _refresh();
                              }
                            : null,
                      ),
                      const SizedBox(width: 8),
                      _StatChip(
                        label: 'Snoozed',
                        value: summary.snoozedToday,
                        icon: Icons.snooze_rounded,
                        color: Colors.deepPurple,
                        onTap: summary.snoozedToday > 0
                            ? () async {
                                HapticFeedback.lightImpact();
                                await HubActivityDetailSheet.show(
                                  context,
                                  event: NotificationLifecycleEvent.snoozed,
                                );
                                if (mounted) _refresh();
                              }
                            : null,
                      ),
                      const SizedBox(width: 8),
                      _StatChip(
                        label: 'Failed',
                        value: summary.failedToday,
                        icon: Icons.error_outline_rounded,
                        color: Colors.red,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  const HubFailedNotificationsPage(),
                            ),
                          ).then((_) {
                            if (mounted) _refresh();
                          });
                        },
                      ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Module status ──
              SettingsSection(
                title: 'CONNECTED APPS',
                icon: Icons.apps_rounded,
                child: data.modules.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'No modules registered yet',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          ...data.modules.asMap().entries.map((entry) {
                            final index = entry.key;
                            final module = entry.value;
                            final enabled =
                                data.enabledStates[module.moduleId] ??
                                    module.defaultEnabled;
                            final c = Color(module.colorValue);

                            return Column(
                              children: [
                                if (index > 0)
                                  Divider(
                                    height: 1,
                                    thickness: 1,
                                    indent: 56,
                                    color: theme.colorScheme.outlineVariant
                                        .withOpacity(isDark ? 0.2 : 0.1),
                                  ),
                                ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 4),
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            module.moduleId ==
                                                    FinanceNotificationContract
                                                        .moduleId
                                                ? const HubFinanceModulePage()
                                                : module.moduleId ==
                                                        SleepNotificationContract
                                                            .moduleId
                                                    ? const HubSleepModulePage()
                                                    : module.moduleId ==
                                                            NotificationHubModuleIds
                                                                .task
                                                        ? const HubTaskModulePage()
                                                        : module.moduleId ==
                                                                NotificationHubModuleIds
                                                                    .habit
                                                            ? const HubHabitModulePage()
                                                            : HubModuleDetailPage(
                                                                moduleId:
                                                                    module.moduleId,
                                                              ),
                                      ),
                                    );
                                  },
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: c.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      IconData(module.iconCodePoint,
                                          fontFamily: module.iconFontFamily,
                                          fontPackage:
                                              module.iconFontPackage),
                                      color: c,
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(
                                    module.displayName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${summary.pendingByModule[module.moduleId] ?? 0} pending',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color:
                                          theme.colorScheme.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Switch.adaptive(
                                        value: enabled,
                                        activeColor: AppColorSchemes.primaryGold,
                                        onChanged: (val) async {
                                          HapticFeedback.lightImpact();
                                          await _hub.setModuleEnabled(
                                              module.moduleId, val);
                                          if (mounted) await _refresh();
                                        },
                                      ),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        size: 20,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _fmt(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

// ─── Data model ───

class _DashData {
  final NotificationHubDashboardSummary summary;
  final List<NotificationHubModule> modules;
  final Map<String, bool> enabledStates;
  final int healthScore;
  final _HealthBreakdown healthBreakdown;

  const _DashData({
    required this.summary,
    required this.modules,
    required this.enabledStates,
    required this.healthScore,
    required this.healthBreakdown,
  });
}

class _HealthBreakdown {
  final int modulesScore;
  final String modulesLabel;
  final int enabledScore;
  final String enabledLabel;
  final int pendingScore;
  final String pendingLabel;
  final int failuresScore;
  final String failuresLabel;

  const _HealthBreakdown({
    required this.modulesScore,
    required this.modulesLabel,
    required this.enabledScore,
    required this.enabledLabel,
    required this.pendingScore,
    required this.pendingLabel,
    required this.failuresScore,
    required this.failuresLabel,
  });
}

// ─── Shared widgets ───

class _ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Headline card ───

class _HeadlineCard extends StatelessWidget {
  final int count;
  final String subtitle;
  final String? time;
  final VoidCallback? onTap;

  const _HeadlineCard({
    required this.count,
    required this.subtitle,
    this.time,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final card = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  AppColorSchemes.primaryGold.withOpacity(0.2),
                  AppColorSchemes.primaryGold.withOpacity(0.08),
                ]
              : [
                  AppColorSchemes.primaryGold.withOpacity(0.15),
                  AppColorSchemes.primaryGold.withOpacity(0.05),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColorSchemes.primaryGold.withOpacity(isDark ? 0.3 : 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColorSchemes.primaryGold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: AppColorSchemes.primaryGold,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Active Reminders',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              if (time != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColorSchemes.primaryGold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    time!,
                    style: const TextStyle(
                      color: AppColorSchemes.primaryGold,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.onSurface,
              letterSpacing: -1,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: card,
        ),
      );
    }
    return card;
  }
}

// ─── Hub Health breakdown sheet ───

class _HubHealthBreakdownSheet extends StatelessWidget {
  final int score;
  final _HealthBreakdown breakdown;
  final VoidCallback onOpenPermissions;

  const _HubHealthBreakdownSheet({
    required this.score,
    required this.breakdown,
    required this.onOpenPermissions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark
        ? theme.colorScheme.surface
        : theme.colorScheme.surfaceContainerHighest;
    final c = score >= 75
        ? AppColors.success
        : score >= 50
            ? Colors.amber
            : AppColors.error;

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withOpacity(0.3)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: score / 100,
                        color: c,
                        backgroundColor: c.withOpacity(0.15),
                        strokeWidth: 4,
                        strokeCap: StrokeCap.round,
                      ),
                      Text(
                        '$score',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: c,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hub Health',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Why $score%?',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _BreakdownRow(
              label: 'Modules registered',
              detail: breakdown.modulesLabel,
              points: breakdown.modulesScore,
              maxPoints: 25,
            ),
            _BreakdownRow(
              label: 'Modules enabled',
              detail: breakdown.enabledLabel,
              points: breakdown.enabledScore,
              maxPoints: 25,
            ),
            _BreakdownRow(
              label: 'Scheduled notifications',
              detail: breakdown.pendingLabel,
              points: breakdown.pendingScore,
              maxPoints: 25,
            ),
            _BreakdownRow(
              label: 'No failures today',
              detail: breakdown.failuresLabel,
              points: breakdown.failuresScore,
              maxPoints: 25,
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        onOpenPermissions();
                      },
                      icon: const Icon(Icons.security_rounded, size: 18),
                      label: const Text('Permissions'),
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
}

class _BreakdownRow extends StatelessWidget {
  final String label;
  final String detail;
  final int points;
  final int maxPoints;

  const _BreakdownRow({
    required this.label,
    required this.detail,
    required this.points,
    required this.maxPoints,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final achieved = points > 0;
    final c = achieved ? AppColors.success : theme.colorScheme.outline;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(
            achieved ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 20,
            color: c,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '+$points',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: achieved ? AppColors.success : theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Health score ───

class _HealthScoreCard extends StatelessWidget {
  final int score;
  final VoidCallback? onTap;

  const _HealthScoreCard({
    required this.score,
    this.onTap,
  });

  Color _color() {
    if (score >= 75) return AppColors.success;
    if (score >= 50) return Colors.amber;
    return AppColors.error;
  }

  String _label() {
    if (score >= 75) return 'Healthy';
    if (score >= 50) return 'Needs Attention';
    return 'Issues Found';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final c = _color();

    return Material(
      color: c.withOpacity(isDark ? 0.1 : 0.06),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: c.withOpacity(isDark ? 0.3 : 0.2),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: score / 100,
                      color: c,
                      backgroundColor: c.withOpacity(0.15),
                      strokeWidth: 4,
                      strokeCap: StrokeCap.round,
                    ),
                    Text(
                      '$score',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: c,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hub Health',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _label(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: c,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: c, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Quick actions ───

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final containerColor = isDark
        ? theme.colorScheme.surfaceContainerLow
        : theme.colorScheme.surfaceContainerHighest;

    return Material(
      color: containerColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: theme.colorScheme.outlineVariant
                  .withOpacity(isDark ? 0.3 : 0.4),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColorSchemes.primaryGold, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Stat chip (replaces the grid to avoid overflow) ───

class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final chip = Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.1 : 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(isDark ? 0.2 : 0.12),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 6),
          Text(
            '$value',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: theme.colorScheme.onSurface,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    final content =
        onTap != null
            ? Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(12),
                  child: chip,
                ),
              )
            : chip;
    return Expanded(child: content);
  }
}
