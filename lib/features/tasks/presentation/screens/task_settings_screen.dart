import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/dark_gradient.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../data/models/category.dart';
import '../../../../data/models/task_reason.dart';
import '../../../../data/local/hive/hive_service.dart';
import '../providers/category_providers.dart';
import '../providers/task_providers.dart';
import '../providers/task_reason_providers.dart';
import '../providers/tag_providers.dart';
import '../providers/task_settings_provider.dart';
import '../../../../core/widgets/add_category_bottom_sheet.dart';
import '../../../../core/widgets/icon_picker_widget.dart';
import 'settings/points_system_screen.dart';
import 'settings/notification_settings_screen.dart';
import 'task_templates_screen.dart';

/// Task Settings Screen - Configuration and management for tasks
class TaskSettingsScreen extends ConsumerStatefulWidget {
  const TaskSettingsScreen({super.key});

  @override
  ConsumerState<TaskSettingsScreen> createState() => _TaskSettingsScreenState();
}

class _TaskSettingsScreenState extends ConsumerState<TaskSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: isDark
          ? DarkGradient.wrap(child: _buildContent(context, isDark))
          : _buildContent(context, isDark),
    );
  }

  Widget _buildContent(BuildContext context, bool isDark) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Task Settings'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'General'),
            Tab(text: 'Notifications'),
            Tab(text: 'Categories'),
            Tab(text: 'Tags'),
            Tab(text: 'Reasons'),
            Tab(text: 'Points System'),
            Tab(text: 'Reset'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGeneralTab(context, isDark),
          _buildNotificationsTab(context, isDark),
          _buildCategoriesTab(context, isDark),
          _buildTagsTab(context, isDark),
          _buildReasonsTab(context, isDark),
          const PointsSystemScreen(),
          _buildResetTab(context, isDark),
        ],
      ),
    );
  }

  // TAB 1: General Settings
  Widget _buildGeneralTab(BuildContext context, bool isDark) {
    final settings = ref.watch(taskSettingsProvider);
    final settingsNotifier = ref.read(taskSettingsProvider.notifier);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // Title
        Text(
          'Defaults',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: isDark ? Colors.white54 : Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),

        // Default Priority
        _buildCompactCard(
          context,
          isDark,
          icon: Icons.flag_rounded,
          iconColor: const Color(0xFFCDAF56),
          title: 'Default Priority',
          value: settings.defaultPriority,
          onTap: () => _showPriorityPicker(
            context,
            isDark,
            settings.defaultPriority,
            (value) {
              settingsNotifier.setDefaultPriority(value);
            },
          ),
        ),
        const SizedBox(height: 8),

        // Default Category
        _buildCompactCard(
          context,
          isDark,
          icon: Icons.folder_rounded,
          iconColor: const Color(0xFF42A5F5),
          title: 'Default Category',
          value: _getCategoryName(settings.defaultCategoryId),
          onTap: () => _showCategoryPicker(
            context,
            isDark,
            settings.defaultCategoryId,
            (value) {
              settingsNotifier.setDefaultCategoryId(value);
            },
          ),
        ),
        const SizedBox(height: 16),

        // Preferences Title
        Text(
          'Display',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: isDark ? Colors.white54 : Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),

        // Show Streak Toggle
        _buildCompactToggleCard(
          context,
          isDark,
          icon: Icons.local_fire_department_rounded,
          iconColor: const Color(0xFFFF6B6B),
          title: 'Show Streak',
          subtitle: 'Display on dashboard',
          value: settings.showStreakOnDashboard,
          onChanged: (value) => settingsNotifier.setShowStreak(value),
        ),
        const SizedBox(height: 8),

        // Scoring Toggle
        _buildCompactToggleCard(
          context,
          isDark,
          icon: Icons.trending_up_rounded,
          iconColor: const Color(0xFF51CF66),
          title: 'Performance Scoring',
          subtitle: 'Track your performance',
          value: settings.enablePerformanceScoring,
          onChanged: (value) => settingsNotifier.setEnableScoring(value),
        ),
        const SizedBox(height: 16),

        // Templates Management Title
        Text(
          'Templates',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: isDark ? Colors.white54 : Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),

        // Templates Management Card
        _buildCompactCard(
          context,
          isDark,
          icon: Icons.dashboard_customize_rounded,
          iconColor: const Color(0xFF9C27B0),
          title: 'Manage Templates',
          value: 'Create & organize templates',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const TaskTemplatesScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCompactCard(
    BuildContext context,
    bool isDark, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E2230).withOpacity(0.6)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: iconColor.withOpacity(0.15), width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isDark ? Colors.white54 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.white24 : Colors.black12,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  String _getCategoryName(String? categoryId) {
    if (categoryId == null) return 'None';
    final categoriesAsync = ref.read(categoryNotifierProvider);
    return categoriesAsync.maybeWhen(
      data: (categories) {
        final cat = categories.where((c) => c.id == categoryId).firstOrNull;
        return cat?.name ?? 'None';
      },
      orElse: () => 'None',
    );
  }

  void _showPriorityPicker(
    BuildContext context,
    bool isDark,
    String currentValue,
    ValueChanged<String> onChanged,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2230) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Select Priority',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            ...['Low', 'Medium', 'High'].map((priority) {
              final isSelected = currentValue == priority;
              final color = priority == 'High'
                  ? Colors.red
                  : priority == 'Medium'
                  ? Colors.orange
                  : Colors.green;
              return ListTile(
                leading: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.flag_rounded, color: color, size: 16),
                ),
                title: Text(
                  priority,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFFCDAF56),
                      )
                    : null,
                onTap: () {
                  onChanged(priority);
                  Navigator.pop(context);
                },
              );
            }),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  void _showCategoryPicker(
    BuildContext context,
    bool isDark,
    String? currentValue,
    ValueChanged<String?> onChanged,
  ) {
    final categoriesAsync = ref.read(categoryNotifierProvider);

    categoriesAsync.whenData((categories) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2230) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Select Category',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              // None option
              ListTile(
                leading: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.remove_circle_outline_rounded,
                    color: Colors.grey,
                    size: 16,
                  ),
                ),
                title: Text(
                  'None',
                  style: TextStyle(
                    fontWeight: currentValue == null
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                trailing: currentValue == null
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFFCDAF56),
                      )
                    : null,
                onTap: () {
                  onChanged(null);
                  Navigator.pop(context);
                },
              ),
              // Category options
              ...categories.map((category) {
                final isSelected = currentValue == category.id;
                return ListTile(
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: category.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(category.icon, color: category.color, size: 16),
                  ),
                  title: Text(
                    category.name,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFFCDAF56),
                        )
                      : null,
                  onTap: () {
                    onChanged(category.id);
                    Navigator.pop(context);
                  },
                );
              }),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildCompactToggleCard(
    BuildContext context,
    bool isDark, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E2230).withOpacity(0.6)
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withOpacity(0.15), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isDark ? Colors.white54 : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFFCDAF56),
            activeTrackColor: const Color(0xFFCDAF56).withOpacity(0.3),
          ),
        ],
      ),
    );
  }

  // TAB 2: Notifications - Quick access to notification settings
  Widget _buildNotificationsTab(BuildContext context, bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // Main CTA
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const NotificationSettingsScreen(),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFCDAF56),
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.settings_rounded,
                  color: Color(0xFF1E1E1E),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  'Full Notification Settings',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E1E1E),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Quick Access Title
        Text(
          'Quick Access',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: isDark ? Colors.white54 : Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),

        // Shortcuts Grid
        _buildNotificationShortcutCard(
          context,
          isDark,
          icon: Icons.alarm_on_rounded,
          iconColor: const Color(0xFFE53935),
          title: 'Alarm Mode',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) =>
                    const NotificationSettingsScreen(initialTab: 0),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        _buildNotificationShortcutCard(
          context,
          isDark,
          icon: Icons.bedtime_rounded,
          iconColor: const Color(0xFF7E57C2),
          title: 'Quiet Hours',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) =>
                    const NotificationSettingsScreen(initialTab: 2),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        _buildNotificationShortcutCard(
          context,
          isDark,
          icon: Icons.schedule_rounded,
          iconColor: const Color(0xFF42A5F5),
          title: 'Snooze Settings',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) =>
                    const NotificationSettingsScreen(initialTab: 1),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        _buildNotificationShortcutCard(
          context,
          isDark,
          icon: Icons.volume_up_rounded,
          iconColor: const Color(0xFF26A69A),
          title: 'Sounds & Vibration',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) =>
                    const NotificationSettingsScreen(initialTab: 0),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildNotificationShortcutCard(
    BuildContext context,
    bool isDark, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E2230).withOpacity(0.6)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: iconColor.withOpacity(0.15), width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: isDark ? Colors.white24 : Colors.black12,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // TAB 3: Categories - Now uses database
  Widget _buildCategoriesTab(BuildContext context, bool isDark) {
    final categoriesAsync = ref.watch(categoryNotifierProvider);
    final tasksAsync = ref.watch(taskNotifierProvider);

    return categoriesAsync.when(
      data: (categories) {
        return tasksAsync.when(
          data: (tasks) {
            final categoryTaskCounts = <String, int>{};
            for (final task in tasks) {
              if (task.categoryId != null) {
                categoryTaskCounts[task.categoryId!] =
                    (categoryTaskCounts[task.categoryId!] ?? 0) + 1;
              }
            }

            return Column(
              children: [
                Expanded(
                  child: categories.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.folder_outlined,
                                size: 48,
                                color: isDark
                                    ? Colors.grey[600]
                                    : Colors.grey[400],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No categories yet',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                    ),
                              ),
                            ],
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          children: [
                            ...categories.map((category) {
                              final taskCount =
                                  categoryTaskCounts[category.id] ?? 0;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(
                                            0xFF1E2230,
                                          ).withOpacity(0.6)
                                        : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: category.color.withOpacity(0.15),
                                      width: 1,
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: category.color.withOpacity(
                                            0.12,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Icon(
                                          category.icon,
                                          color: category.color,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              category.name,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                    color: isDark
                                                        ? Colors.white
                                                        : Colors.black87,
                                                  ),
                                            ),
                                            Text(
                                              '$taskCount ${taskCount == 1 ? 'task' : 'tasks'}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall
                                                  ?.copyWith(
                                                    color: isDark
                                                        ? Colors.white54
                                                        : Colors.grey[600],
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit_rounded,
                                          size: 18,
                                        ),
                                        color: const Color(0xFFCDAF56),
                                        onPressed: () => _editCategory(
                                          context,
                                          isDark,
                                          category,
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 32,
                                          minHeight: 32,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          size: 18,
                                        ),
                                        color: Colors.red,
                                        onPressed: () =>
                                            _deleteCategory(context, category),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 32,
                                          minHeight: 32,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _showAddCategoryBottomSheet(context, isDark),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add Category'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFCDAF56),
                        foregroundColor: const Color(0xFF1E1E1E),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Error: $error')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) =>
          Center(child: Text('Error loading categories: $error')),
    );
  }

  Widget _buildCategoryDropdown(
    BuildContext context,
    bool isDark,
    String? currentValue,
    ValueChanged<String?> onChanged,
  ) {
    final categoriesAsync = ref.watch(categoryNotifierProvider);

    return categoriesAsync.when(
      data: (categories) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Default Category',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withOpacity(0.4)
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: DropdownButtonFormField<String>(
                value: currentValue,
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('None'),
                  ),
                  ...categories.map((category) {
                    return DropdownMenuItem<String>(
                      value: category.id,
                      child: Row(
                        children: [
                          Icon(category.icon, color: category.color, size: 20),
                          const SizedBox(width: 8),
                          Text(category.name),
                        ],
                      ),
                    );
                  }),
                ],
                onChanged: onChanged,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: InputBorder.none,
                ),
                dropdownColor: isDark ? const Color(0xFF2D3139) : Colors.white,
                icon: const Icon(
                  Icons.arrow_drop_down_rounded,
                  color: Color(0xFFCDAF56),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox(
        height: 60,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Text('Error: $error'),
    );
  }

  void _showAddCategoryBottomSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddCategoryBottomSheet(),
    ).then((result) {
      if (result != null && result is Category) {
        ref.read(categoryNotifierProvider.notifier).addCategory(result);
      }
    });
  }

  void _editCategory(BuildContext context, bool isDark, Category category) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddCategoryBottomSheet(category: category),
    ).then((result) {
      if (result != null && result is Category) {
        ref.read(categoryNotifierProvider.notifier).updateCategory(result);
      }
    });
  }

  void _deleteCategory(BuildContext context, Category category) {
    // Check if category is used by any tasks
    final tasksAsync = ref.read(taskNotifierProvider);
    tasksAsync.whenData((tasks) {
      final tasksUsingCategory = tasks
          .where((t) => t.categoryId == category.id)
          .length;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Category'),
          content: Text(
            tasksUsingCategory > 0
                ? 'This category is used by $tasksUsingCategory ${tasksUsingCategory == 1 ? 'task' : 'tasks'}. Are you sure you want to delete it?'
                : 'Are you sure you want to delete "${category.name}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                ref
                    .read(categoryNotifierProvider.notifier)
                    .deleteCategory(category.id);
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
    });
  }

  // TAB 4: Tags
  Widget _buildTagsTab(BuildContext context, bool isDark) {
    final tags = ref.watch(tagNotifierProvider);
    final tagsNotifier = ref.read(tagNotifierProvider.notifier);

    return Column(
      children: [
        Expanded(
          child: tags.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.label_outline_rounded,
                        size: 48,
                        color: isDark ? Colors.grey[600] : Colors.grey[400],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No tags yet',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: tags.map((tag) {
                        return Chip(
                          label: Text(
                            tag,
                            style: const TextStyle(fontSize: 12),
                          ),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () => tagsNotifier.removeTag(tag),
                          backgroundColor: isDark
                              ? const Color(0xFF1E2230)
                              : Colors.grey[200],
                          labelStyle: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 12,
                          ),
                          side: BorderSide(
                            color: const Color(0xFFCDAF56).withOpacity(0.2),
                            width: 1,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Add tag',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white38 : Colors.grey[500],
                    ),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF1E2230).withOpacity(0.6)
                        : Colors.grey.withOpacity(0.08),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.transparent),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: const Color(0xFFCDAF56).withOpacity(0.1),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: Color(0xFFCDAF56),
                        width: 1.5,
                      ),
                    ),
                  ),
                  onSubmitted: (value) {
                    final tag = value.trim().toLowerCase();
                    if (tag.isNotEmpty) {
                      tagsNotifier.addTag(tag);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // TAB 5: Reasons - Now uses database-backed provider
  Widget _buildReasonsTab(BuildContext context, bool isDark) {
    final reasonsAsync = ref.watch(taskReasonNotifierProvider);

    return reasonsAsync.when(
      data: (allReasons) {
        final notDoneReasons = allReasons
            .where((r) => r.typeIndex == 0)
            .toList();
        final postponeReasons = allReasons
            .where((r) => r.typeIndex == 1)
            .toList();

        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                children: [
                  // Not Done Reasons
                  if (notDoneReasons.isNotEmpty) ...[
                    Text(
                      'Not Done',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: isDark ? Colors.white54 : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...notDoneReasons.map((reason) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E2230).withOpacity(0.6)
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFFCDAF56).withOpacity(0.12),
                              width: 1,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFCDAF56,
                                  ).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: Icon(
                                  reason.icon ?? Icons.note_rounded,
                                  color: const Color(0xFFCDAF56),
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  reason.text,
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_rounded, size: 16),
                                color: const Color(0xFFCDAF56),
                                onPressed: () => _showEditReasonDbBottomSheet(
                                  context,
                                  isDark,
                                  reason,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 28,
                                  minHeight: 28,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 16),
                                color: Colors.red,
                                onPressed: () => ref
                                    .read(taskReasonNotifierProvider.notifier)
                                    .deleteReason(reason.id),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 28,
                                  minHeight: 28,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 16),
                  ],

                  // Postpone Reasons
                  if (postponeReasons.isNotEmpty) ...[
                    Text(
                      'Postpone',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: isDark ? Colors.white54 : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...postponeReasons.map((reason) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E2230).withOpacity(0.6)
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFFCDAF56).withOpacity(0.12),
                              width: 1,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFCDAF56,
                                  ).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: Icon(
                                  reason.icon ?? Icons.note_rounded,
                                  color: const Color(0xFFCDAF56),
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  reason.text,
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_rounded, size: 16),
                                color: const Color(0xFFCDAF56),
                                onPressed: () => _showEditReasonDbBottomSheet(
                                  context,
                                  isDark,
                                  reason,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 28,
                                  minHeight: 28,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 16),
                                color: Colors.red,
                                onPressed: () => ref
                                    .read(taskReasonNotifierProvider.notifier)
                                    .deleteReason(reason.id),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 28,
                                  minHeight: 28,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ],

                  if (notDoneReasons.isEmpty && postponeReasons.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            Icon(
                              Icons.note_outlined,
                              size: 48,
                              color: isDark
                                  ? Colors.grey[600]
                                  : Colors.grey[400],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No reasons yet',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _showAddReasonDbBottomSheet(context, isDark, 0),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text(
                        'Not Done',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: Color(0xFFCDAF56),
                          width: 1,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _showAddReasonDbBottomSheet(context, isDark, 1),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text(
                        'Postpone',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFCDAF56),
                        foregroundColor: const Color(0xFF1E1E1E),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) =>
          Center(child: Text('Error loading reasons: $error')),
    );
  }

  /// Show bottom sheet to add a new reason to the database
  void _showAddReasonDbBottomSheet(
    BuildContext context,
    bool isDark,
    int typeIndex,
  ) {
    final textController = TextEditingController();
    IconData? selectedIcon = typeIndex == 0
        ? Icons.sentiment_dissatisfied_rounded
        : Icons.schedule_rounded;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2D3139) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add ${typeIndex == 0 ? 'Not Done' : 'Postpone'} Reason',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 20),
              // Icon selector
              Row(
                children: [
                  Text(
                    'Select Icon:',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () async {
                      final icon = await showDialog<IconData>(
                        context: context,
                        builder: (context) => IconPickerWidget(
                          selectedIcon: selectedIcon ?? Icons.note_rounded,
                          isDark: isDark,
                        ),
                      );
                      if (icon != null) {
                        setSheetState(() => selectedIcon = icon);
                      }
                    },
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCDAF56).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFCDAF56),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        selectedIcon,
                        color: const Color(0xFFCDAF56),
                        size: 28,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: textController,
                decoration: InputDecoration(
                  labelText: 'Reason Text',
                  hintText: 'e.g., Too busy, Need more time',
                  filled: true,
                  fillColor: isDark
                      ? Colors.black.withOpacity(0.4)
                      : Colors.grey[200],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (textController.text.trim().isNotEmpty &&
                        selectedIcon != null) {
                      final reason = TaskReason(
                        text: textController.text.trim(),
                        icon: selectedIcon,
                        typeIndex: typeIndex,
                      );
                      ref
                          .read(taskReasonNotifierProvider.notifier)
                          .addReason(reason);
                      Navigator.pop(context);
                      AppSnackbar.showSuccess(context, 'Reason added!');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCDAF56),
                    foregroundColor: const Color(0xFF1E1E1E),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Save Reason'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show bottom sheet to edit an existing reason
  void _showEditReasonDbBottomSheet(
    BuildContext context,
    bool isDark,
    TaskReason reason,
  ) {
    final textController = TextEditingController(text: reason.text);
    IconData? selectedIcon = reason.icon ?? Icons.note_rounded;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2D3139) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit Reason',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 20),
              // Icon selector
              Row(
                children: [
                  Text(
                    'Select Icon:',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () async {
                      final icon = await showDialog<IconData>(
                        context: context,
                        builder: (context) => IconPickerWidget(
                          selectedIcon: selectedIcon ?? Icons.note_rounded,
                          isDark: isDark,
                        ),
                      );
                      if (icon != null) {
                        setSheetState(() => selectedIcon = icon);
                      }
                    },
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCDAF56).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFCDAF56),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        selectedIcon,
                        color: const Color(0xFFCDAF56),
                        size: 28,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: textController,
                decoration: InputDecoration(
                  labelText: 'Reason Text',
                  filled: true,
                  fillColor: isDark
                      ? Colors.black.withOpacity(0.4)
                      : Colors.grey[200],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (textController.text.trim().isNotEmpty &&
                        selectedIcon != null) {
                      final updated = reason.copyWith(
                        text: textController.text.trim(),
                        icon: selectedIcon,
                      );
                      ref
                          .read(taskReasonNotifierProvider.notifier)
                          .updateReason(updated);
                      Navigator.pop(context);
                      AppSnackbar.showSuccess(context, 'Reason updated!');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCDAF56),
                    foregroundColor: const Color(0xFF1E1E1E),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Update Reason'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // TAB 6: Reset
  Widget _buildResetTab(BuildContext context, bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        _buildCompactResetButton(
          context,
          isDark,
          icon: Icons.refresh_rounded,
          title: 'Reset Today',
          subtitle: 'Undo today\'s completions',
          isDanger: false,
          onPressed: () => _showResetTodayDialog(context, isDark),
        ),
        const SizedBox(height: 8),

        _buildCompactResetButton(
          context,
          isDark,
          icon: Icons.local_fire_department_rounded,
          title: 'Reset Streak',
          subtitle: 'Clear your streak counter',
          isDanger: false,
          onPressed: () => _showResetStreakDialog(context, isDark),
        ),
        const SizedBox(height: 8),

        _buildCompactResetButton(
          context,
          isDark,
          icon: Icons.warning_rounded,
          title: 'Delete All Data',
          subtitle: 'Permanent action - cannot be undone',
          isDanger: true,
          onPressed: () => _showResetAllDialog(context, isDark),
        ),
      ],
    );
  }

  Widget _buildCompactResetButton(
    BuildContext context,
    bool isDark, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDanger,
    required VoidCallback onPressed,
  }) {
    final color = isDanger ? Colors.red : const Color(0xFFCDAF56);

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E2230).withOpacity(0.6)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.15), width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isDark ? Colors.white54 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.white24 : Colors.black12,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // Helper Widgets
  Widget _buildDropdownSetting(
    BuildContext context, {
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.black.withOpacity(0.4) : Colors.grey[200],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            items: items.map((item) {
              return DropdownMenuItem(
                value: item,
                child: Text(
                  item,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              );
            }).toList(),
            onChanged: onChanged,
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              border: InputBorder.none,
            ),
            dropdownColor: isDark ? const Color(0xFF2D3139) : Colors.white,
            icon: const Icon(
              Icons.arrow_drop_down_rounded,
              color: Color(0xFFCDAF56),
            ),
          ),
        ),
      ],
    );
  }

  void _showResetTodayDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF2D3139) : Colors.white,
        title: Text(
          'Reset Today\'s Completed Tasks',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'This will undo all tasks you marked as completed today. They will return to pending status.',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              final tasksAsync = ref.read(taskNotifierProvider);
              await tasksAsync.when(
                data: (allTasks) async {
                  final notifier = ref.read(taskNotifierProvider.notifier);
                  final today = DateTime.now();

                  // Find all tasks completed today
                  final completedToday = allTasks.where((task) {
                    if (task.status != 'completed' || task.completedAt == null)
                      return false;
                    final completedDate = task.completedAt!;
                    return completedDate.year == today.year &&
                        completedDate.month == today.month &&
                        completedDate.day == today.day;
                  }).toList();

                  // Reset each task using robust undo system
                  int autoDeletedCount = 0;
                  for (final task in completedToday) {
                    // Track auto-generated tasks that will be cleaned up
                    final undoInfo = notifier.getUndoInfo(task.id);
                    autoDeletedCount += undoInfo['willDeleteTasks'] as int;

                    // Use specific undo method for completions
                    await notifier.undoTaskComplete(task.id);
                  }

                  if (mounted) {
                    String message =
                        '${completedToday.length} task${completedToday.length != 1 ? 's' : ''} reset to pending';
                    if (autoDeletedCount > 0) {
                      message +=
                          ' ($autoDeletedCount auto-generated occurrence${autoDeletedCount != 1 ? 's' : ''} removed)';
                    }
                    AppSnackbar.showSuccess(context, message);
                  }
                },
                loading: () async {},
                error: (_, __) async {},
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCDAF56),
              foregroundColor: const Color(0xFF1E1E1E),
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _showResetStreakDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF2D3139) : Colors.white,
        title: Text(
          'Reset Streak',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'This will reset your completion streak counter. Your task history will remain intact.',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Note: Streak is calculated dynamically from completed tasks
              // To truly reset streak, we would need to add a "last reset date" field
              // For now, inform user streak is based on actual completion history
              AppSnackbar.showInfo(
                context,
                'Streak is calculated from your task history. Complete a task to start a new streak!',
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFB347),
              foregroundColor: const Color(0xFF1E1E1E),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showResetAllDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF2D3139) : Colors.white,
        title: const Text(
          'Reset All Data',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'This will permanently delete ALL your tasks, categories, tags, reasons, and settings. This action CANNOT be undone!',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              try {
                // Delete all tasks
                final tasksAsync = ref.read(taskNotifierProvider);
                await tasksAsync.when(
                  data: (allTasks) async {
                    final notifier = ref.read(taskNotifierProvider.notifier);
                    for (final task in allTasks) {
                      await notifier.deleteTask(task.id);
                    }
                  },
                  loading: () async {},
                  error: (_, __) async {},
                );

                // Delete all categories
                final categoriesAsync = ref.read(categoryNotifierProvider);
                await categoriesAsync.when(
                  data: (allCategories) async {
                    final notifier = ref.read(
                      categoryNotifierProvider.notifier,
                    );
                    for (final category in allCategories) {
                      await notifier.deleteCategory(category.id);
                    }
                  },
                  loading: () async {},
                  error: (_, __) async {},
                );

                // Delete all tags
                final tags = ref.read(tagNotifierProvider);
                final tagNotifier = ref.read(tagNotifierProvider.notifier);
                for (final tag in tags) {
                  tagNotifier.removeTag(tag);
                }

                // Delete all reasons
                final reasonsAsync = ref.read(taskReasonNotifierProvider);
                await reasonsAsync.when(
                  data: (allReasons) async {
                    final notifier = ref.read(
                      taskReasonNotifierProvider.notifier,
                    );
                    for (final reason in allReasons) {
                      await notifier.deleteReason(reason.id);
                    }
                  },
                  loading: () async {},
                  error: (_, __) async {},
                );

                // Clear all daily reflections
                final box = HiveService.box;
                final reflectionKeys = box.keys
                    .where((key) => key.toString().startsWith('reflection_'))
                    .toList();
                for (final key in reflectionKeys) {
                  await box.delete(key);
                }

                // Reset settings to defaults (reminder defaults are in notification settings)
                await ref
                    .read(taskSettingsProvider.notifier)
                    .setDefaultPriority('Medium');
                await ref
                    .read(taskSettingsProvider.notifier)
                    .setDefaultCategoryId(null);
                await ref
                    .read(taskSettingsProvider.notifier)
                    .setShowStreak(true);
                await ref
                    .read(taskSettingsProvider.notifier)
                    .setEnableScoring(true);

                if (mounted) {
                  AppSnackbar.showSuccess(
                    context,
                    'All data has been reset successfully',
                  );
                }
              } catch (e) {
                if (mounted) {
                  AppSnackbar.showError(context, 'Error resetting data: $e');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );
  }
}
