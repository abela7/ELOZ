import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/color_schemes.dart';
import '../../../../core/theme/dark_gradient.dart';
import '../../../../core/theme/typography.dart';
import 'hub_clear_history_page.dart';
import 'hub_dashboard_page.dart';
import 'hub_global_settings_page.dart';
import 'hub_history_page.dart';
import 'hub_orphaned_notifications_page.dart';
import 'hub_permissions_page.dart';
import 'hub_quiet_hours_page.dart';

/// Main Notification Hub screen.
///
/// Uses a 3-tab shell:
/// - **Overview**: Dashboard + quick-links to Permissions
/// - **Settings**: Global Settings, Quiet Hours, Permissions
/// - **History**: Notification lifecycle log
class NotificationHubScreen extends StatefulWidget {
  const NotificationHubScreen({super.key});

  @override
  State<NotificationHubScreen> createState() => _NotificationHubScreenState();
}

class _NotificationHubScreenState extends State<NotificationHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _goToTab(int index) {
    _tabController.animateTo(index);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final content = _buildContent(context, isDark);
    return isDark ? DarkGradient.wrap(child: content) : content;
  }

  Widget _buildContent(BuildContext context, bool isDark) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: colorScheme.onSurface,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Notification Hub',
          style: AppTypography.titleMedium(context).copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: colorScheme.onSurface,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {
              HapticFeedback.mediumImpact();
              setState(() {});
            },
            icon: Icon(
              Icons.refresh_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: AppColorSchemes.primaryGold,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
          indicatorColor: AppColorSchemes.primaryGold,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          dividerColor: colorScheme.outlineVariant.withValues(
            alpha: isDark ? 0.2 : 0.3,
          ),
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Settings'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Tab 1: Overview ──
          HubDashboardPage(
            onNavigateToSettings: () => _goToTab(1),
            onNavigateToPermissions: () {
              _goToTab(1);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _push(
                  context,
                  'Permissions & Health',
                  const HubPermissionsPage(),
                );
              });
            },
          ),

          // ── Tab 2: Settings ──
          _SettingsTab(onPush: _push),

          // ── Tab 3: History ──
          const HubHistoryPage(),
        ],
      ),
    );
  }

  void _push(BuildContext context, String title, Widget child) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _SubPage(title: title, isDark: isDark, child: child),
      ),
    );
  }
}

// ─── Settings tab with sub-navigation ──────────────────────────────────────

class _SettingsTab extends StatelessWidget {
  final void Function(BuildContext, String, Widget) onPush;

  const _SettingsTab({required this.onPush});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
      physics: const BouncingScrollPhysics(),
      children: [
        _SettingsNavCard(
          icon: Icons.tune_rounded,
          title: 'Global Settings',
          subtitle: 'Master toggle, sound, vibration, snooze, display',
          color: AppColorSchemes.primaryGold,
          onTap: () =>
              onPush(context, 'Global Settings', const HubGlobalSettingsPage()),
        ),
        _SettingsNavCard(
          icon: Icons.nights_stay_rounded,
          title: 'Quiet Hours',
          subtitle: 'Schedule silent periods & exceptions',
          color: Colors.indigo,
          onTap: () =>
              onPush(context, 'Quiet Hours', const HubQuietHoursPage()),
        ),
        _SettingsNavCard(
          icon: Icons.link_off_rounded,
          title: 'Orphaned Notifications',
          subtitle: 'Find & cancel notifications for deleted items',
          color: Colors.orange,
          onTap: () => onPush(
            context,
            'Orphaned Notifications',
            const HubOrphanedNotificationsPage(),
          ),
        ),
        _SettingsNavCard(
          icon: Icons.security_rounded,
          title: 'Permissions & Health',
          subtitle: 'Device permissions, battery, health score',
          color: Colors.orange,
          onTap: () => onPush(
            context,
            'Permissions & Health',
            const HubPermissionsPage(),
          ),
        ),
        _SettingsNavCard(
          icon: Icons.restart_alt_rounded,
          title: 'Reset Notification Hub',
          subtitle:
              'Wipe history log and/or full reset (definitions + alarms) – brand new hub',
          color: Colors.red.shade400,
          onTap: () => onPush(
            context,
            'Reset Notification Hub',
            const HubClearHistoryPage(),
          ),
        ),
      ],
    );
  }
}

// ─── Settings navigation card ──────────────────────────────────────────────

class _SettingsNavCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _SettingsNavCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final containerColor = isDark
        ? theme.colorScheme.surfaceContainerLow
        : theme.colorScheme.surfaceContainerHighest;
    final borderColor = theme.colorScheme.outlineVariant.withValues(
      alpha: isDark ? 0.4 : 0.6,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: containerColor,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Sub-page wrapper ──────────────────────────────────────────────────────

class _SubPage extends StatelessWidget {
  final String title;
  final Widget child;
  final bool isDark;

  const _SubPage({
    required this.title,
    required this.isDark,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final content = Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: colorScheme.onSurface,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          title,
          style: AppTypography.titleMedium(context).copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: colorScheme.onSurface,
          ),
        ),
      ),
      body: child,
    );

    return isDark ? DarkGradient.wrap(child: content) : content;
  }
}
