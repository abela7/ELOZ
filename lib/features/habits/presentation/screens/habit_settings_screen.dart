import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/dark_gradient.dart';
import '../../data/models/habit_category.dart';
import '../providers/habit_category_providers.dart';
import '../widgets/add_habit_category_bottom_sheet.dart';
import '../../../../core/widgets/icon_picker_widget.dart';
import '../../../../core/widgets/color_picker_widget.dart';
import '../providers/habit_providers.dart';
import '../providers/habit_tag_providers.dart';
import '../providers/habit_reason_providers.dart';
import '../providers/temptation_log_providers.dart';
import '../providers/habit_type_providers.dart';
import '../providers/completion_type_config_providers.dart';
import '../providers/unit_category_providers.dart';
import '../providers/habit_unit_providers.dart';
import '../../data/models/habit_reason.dart';
import '../../data/services/quit_habit_report_security_service.dart';
import '../../../../core/services/reminder_manager.dart';
import '../../providers/habit_notification_settings_provider.dart';
import '../../../../core/widgets/sheet_dismiss_on_overscroll.dart';
import 'settings/habit_completion_types_screen.dart';
import 'settings/habit_units_screen.dart';
import 'settings/habit_notification_settings_screen.dart';

/// Habit Settings Screen - Configuration and management for habits
class HabitSettingsScreen extends ConsumerStatefulWidget {
  const HabitSettingsScreen({super.key});

  @override
  ConsumerState<HabitSettingsScreen> createState() =>
      _HabitSettingsScreenState();
}

class _HabitSettingsScreenState extends ConsumerState<HabitSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
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
        title: const Text('Habit Settings'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Categories'),
            Tab(text: 'Tags'),
            Tab(text: 'Reasons'),
            Tab(text: 'Completion Types'),
            Tab(text: 'Units'),
            Tab(text: 'Reset'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCategoriesTab(context, isDark),
          _buildTagsTab(context, isDark),
          _buildReasonsTab(context, isDark),
          const HabitCompletionTypesScreen(),
          const HabitUnitsScreen(),
          _buildResetTab(context, isDark),
        ],
      ),
    );
  }

  // TAB 1: Habit Categories
  Widget _buildCategoriesTab(BuildContext context, bool isDark) {
    final categoriesAsync = ref.watch(habitCategoryNotifierProvider);
    final habitsAsync = ref.watch(habitNotifierProvider);

    return categoriesAsync.when(
      data: (categories) {
        // Get habit counts for each category
        return habitsAsync.when(
          data: (habits) {
            final categoryHabitCounts = <String, int>{};
            for (final habit in habits) {
              if (habit.categoryId != null) {
                categoryHabitCounts[habit.categoryId!] =
                    (categoryHabitCounts[habit.categoryId!] ?? 0) + 1;
              }
            }

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const HabitNotificationSettingsScreen(),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E2230).withOpacity(0.6)
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.black12,
                        ),
                      ),
                      child: ListTile(
                        leading: const Icon(
                          Icons.notifications_rounded,
                          color: Color(0xFFCDAF56),
                        ),
                        title: Text(
                          'Notifications',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                        ),
                        subtitle: Text(
                          'Habit notification preferences',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                    ),
                  ),
                ),
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
                              final habitCount =
                                  categoryHabitCounts[category.id] ?? 0;
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
                                              '$habitCount ${habitCount == 1 ? 'habit' : 'habits'}',
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

  void _showAddCategoryBottomSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          const SheetDismissOnOverscroll(child: AddHabitCategoryBottomSheet()),
    ).then((result) {
      if (result != null && result is HabitCategory) {
        ref.read(habitCategoryNotifierProvider.notifier).addCategory(result);
      }
    });
  }

  void _editCategory(
    BuildContext context,
    bool isDark,
    HabitCategory category,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SheetDismissOnOverscroll(
        child: AddHabitCategoryBottomSheet(category: category),
      ),
    ).then((result) {
      if (result != null && result is HabitCategory) {
        ref.read(habitCategoryNotifierProvider.notifier).updateCategory(result);
      }
    });
  }

  void _deleteCategory(BuildContext context, HabitCategory category) {
    // Check if category is used by any habits
    final habitsAsync = ref.read(habitNotifierProvider);
    habitsAsync.whenData((habits) {
      final habitsUsingCategory = habits
          .where((h) => h.categoryId == category.id)
          .length;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Category'),
          content: Text(
            habitsUsingCategory > 0
                ? 'This category is used by $habitsUsingCategory ${habitsUsingCategory == 1 ? 'habit' : 'habits'}. Are you sure you want to delete it?'
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
                    .read(habitCategoryNotifierProvider.notifier)
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

  // TAB 2: Tags
  Widget _buildTagsTab(BuildContext context, bool isDark) {
    final tags = ref.watch(habitTagNotifierProvider);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Tags',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              if (tags.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'No tags yet. Add tags here and they will be available when creating or editing habits.',
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: tags.map((tag) {
                    return Chip(
                      label: Text(tag),
                      deleteIcon: const Icon(Icons.close, size: 18),
                      onDeleted: () {
                        ref
                            .read(habitTagNotifierProvider.notifier)
                            .removeTag(tag);
                      },
                      backgroundColor: isDark
                          ? const Color(0xFF2D3139)
                          : Colors.grey[200],
                      labelStyle: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      side: const BorderSide(
                        color: Color(0xFFCDAF56),
                        width: 1,
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Add new tag',
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF2D3139)
                        : Colors.grey[200],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: Color(0xFFCDAF56),
                        width: 2,
                      ),
                    ),
                  ),
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  onSubmitted: (value) {
                    final tag = value.trim().toLowerCase();
                    if (tag.isNotEmpty) {
                      ref.read(habitTagNotifierProvider.notifier).addTag(tag);
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

  // TAB 3: All Reasons (Not Done, Postpone, Slip, Temptation)
  Widget _buildReasonsTab(BuildContext context, bool isDark) {
    final reasonsAsync = ref.watch(habitReasonNotifierProvider);

    return reasonsAsync.when(
      data: (allReasons) {
        final notDoneReasons = allReasons
            .where((r) => r.typeIndex == 0)
            .toList();
        final postponeReasons = allReasons
            .where((r) => r.typeIndex == 1)
            .toList();
        final slipReasons = allReasons.where((r) => r.typeIndex == 2).toList();
        final temptationReasons = allReasons
            .where((r) => r.typeIndex == 3)
            .toList();

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Not Done / Skip Reasons
            _buildReasonCard(
              context: context,
              isDark: isDark,
              title: 'Skip / Not Done',
              subtitle: 'Why couldn\'t you complete it?',
              description:
                  'Understanding blockers helps you plan better next time.',
              reasons: notDoneReasons,
              typeIndex: 0,
              accentColor: const Color(0xFFFF6B6B),
              icon: Icons.close_rounded,
            ),
            const SizedBox(height: 16),

            // Postpone Reasons
            _buildReasonCard(
              context: context,
              isDark: isDark,
              title: 'Postpone',
              subtitle: 'Why are you delaying?',
              description: 'Track postponements to find better scheduling.',
              reasons: postponeReasons,
              typeIndex: 1,
              accentColor: const Color(0xFFFFB347),
              icon: Icons.schedule_rounded,
            ),
            const SizedBox(height: 32),

            // ===== QUIT HABIT REASONS SECTION =====
            _buildSectionHeader(
              context,
              isDark,
              'Quit Habit Reasons',
              'Track slips and temptations',
              Icons.smoke_free_rounded,
              const Color(0xFFE53935),
            ),
            const SizedBox(height: 16),

            // Slip Reasons
            _buildReasonCard(
              context: context,
              isDark: isDark,
              title: 'Slip',
              subtitle: 'Why did you give in?',
              description: 'Identify patterns to build stronger defenses.',
              reasons: slipReasons,
              typeIndex: 2,
              accentColor: const Color(0xFFE53935),
              icon: Icons.heart_broken_rounded,
            ),
            const SizedBox(height: 16),

            // Temptation Reasons
            _buildReasonCard(
              context: context,
              isDark: isDark,
              title: 'Temptation',
              subtitle: 'What triggered the urge?',
              description: 'You resisted! Track what tempts you.',
              reasons: temptationReasons,
              typeIndex: 3,
              accentColor: const Color(0xFF9C27B0),
              icon: Icons.psychology_rounded,
            ),
            const SizedBox(height: 32),

            // Quick Stats
            _buildReasonsStats(
              context,
              isDark,
              notDoneReasons,
              postponeReasons,
              slipReasons,
              temptationReasons,
            ),
            const SizedBox(height: 24),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) =>
          Center(child: Text('Error loading reasons: $error')),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    bool isDark,
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReasonCard({
    required BuildContext context,
    required bool isDark,
    required String title,
    required String subtitle,
    required String description,
    required List<HabitReason> reasons,
    required int typeIndex,
    required Color accentColor,
    required IconData icon,
  }) {
    final activeReasons = reasons.where((r) => r.isActive).toList();
    final inactiveReasons = reasons.where((r) => !r.isActive).toList();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D3139) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1E1E1E),
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white54 : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                // Add button
                GestureDetector(
                  onTap: () => _showCreateReasonWizard(
                    context,
                    isDark,
                    typeIndex,
                    accentColor,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: accentColor.withOpacity(0.25)),
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      color: accentColor,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Description
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
            child: Text(
              description,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white54 : Colors.grey[600],
              ),
            ),
          ),

          // Reasons list
          if (reasons.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: _buildEmptyReasonsPlaceholder(
                context,
                isDark,
                typeIndex,
                accentColor,
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Active reasons
                  if (activeReasons.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: activeReasons
                          .map(
                            (reason) => _buildReasonChip(
                              context,
                              isDark,
                              reason,
                              accentColor,
                            ),
                          )
                          .toList(),
                    ),
                  ],

                  // Inactive reasons (collapsed)
                  if (inactiveReasons.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Theme(
                      data: Theme.of(
                        context,
                      ).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(top: 8),
                        title: Text(
                          '${inactiveReasons.length} hidden',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white38 : Colors.grey[500],
                          ),
                        ),
                        leading: Icon(
                          Icons.visibility_off_rounded,
                          size: 16,
                          color: isDark ? Colors.white38 : Colors.grey[500],
                        ),
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: inactiveReasons
                                .map(
                                  (reason) => _buildReasonChip(
                                    context,
                                    isDark,
                                    reason,
                                    accentColor,
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReasonChip(
    BuildContext context,
    bool isDark,
    HabitReason reason,
    Color accentColor,
  ) {
    final isActive = reason.isActive;
    final chipColor = reason.color;

    return GestureDetector(
      onTap: () => _showReasonOptionsSheet(context, isDark, reason),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isActive ? 1.0 : 0.5,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: chipColor.withOpacity(isActive ? 0.1 : 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: chipColor.withOpacity(isActive ? 0.3 : 0.15),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                reason.icon ?? Icons.note_rounded,
                color: chipColor,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                reason.text,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                  decoration: isActive ? null : TextDecoration.lineThrough,
                ),
              ),
              if (!isActive) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.visibility_off_rounded,
                  color: Colors.grey,
                  size: 12,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyReasonsPlaceholder(
    BuildContext context,
    bool isDark,
    int typeIndex,
    Color color,
  ) {
    return GestureDetector(
      onTap: () => _showCreateReasonWizard(context, isDark, typeIndex, color),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.2),
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.add_circle_outline_rounded,
              size: 40,
              color: color.withOpacity(0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'Create your first reason',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap to add a personal reason',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white38 : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReasonsStats(
    BuildContext context,
    bool isDark,
    List<HabitReason> notDoneReasons,
    List<HabitReason> postponeReasons,
    List<HabitReason> slipReasons,
    List<HabitReason> temptationReasons,
  ) {
    final allReasons = [
      ...notDoneReasons,
      ...postponeReasons,
      ...slipReasons,
      ...temptationReasons,
    ];
    final totalReasons = allReasons.length;
    final activeReasons = allReasons.where((r) => r.isActive).length;
    final customReasons = allReasons.where((r) => !r.isDefault).length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D3139) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            context,
            isDark,
            totalReasons.toString(),
            'Total',
            Icons.list_rounded,
          ),
          Container(
            width: 1,
            height: 36,
            color: isDark ? Colors.white12 : Colors.grey[200],
          ),
          _buildStatItem(
            context,
            isDark,
            activeReasons.toString(),
            'Active',
            Icons.visibility_rounded,
          ),
          Container(
            width: 1,
            height: 36,
            color: isDark ? Colors.white12 : Colors.grey[200],
          ),
          _buildStatItem(
            context,
            isDark,
            customReasons.toString(),
            'Custom',
            Icons.person_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    bool isDark,
    String value,
    String label,
    IconData icon,
  ) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: const Color(0xFFCDAF56)),
            const SizedBox(width: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF1E1E1E),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white54 : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  // ignore: unused_element
  Widget _buildReasonSectionHeader(
    BuildContext context,
    bool isDark,
    String title,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildReasonCategory({
    required BuildContext context,
    required bool isDark,
    required String title,
    required String subtitle,
    required List<HabitReason> reasons,
    required int typeIndex,
    required Color color,
    required IconData icon,
  }) {
    return Card(
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.1),
      color: isDark ? const Color(0xFF2D3139) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                      ),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (reasons.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No reasons yet. Add one below.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.white38 : Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: reasons.map((reason) {
                  final reasonColor = reason.color;
                  final isActive = reason.isActive;
                  return GestureDetector(
                    onTap: () =>
                        _showReasonOptionsSheet(context, isDark, reason),
                    child: Opacity(
                      opacity: isActive ? 1.0 : 0.5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: reasonColor.withOpacity(
                            isActive ? 0.15 : 0.05,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: reasonColor.withOpacity(
                              isActive ? 0.4 : 0.2,
                            ),
                            width: isActive ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              reason.icon ?? Icons.note_rounded,
                              color: reasonColor,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              reason.text,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                    fontWeight: FontWeight.w500,
                                    decoration: isActive
                                        ? null
                                        : TextDecoration.lineThrough,
                                  ),
                            ),
                            if (!isActive) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.visibility_off_rounded,
                                color: Colors.grey,
                                size: 12,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () =>
                    _showAddReasonBottomSheet(context, isDark, typeIndex),
                icon: Icon(Icons.add_rounded, size: 18, color: color),
                label: Text(
                  'Add $title Reason',
                  style: TextStyle(color: color),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: color.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Get reason type info for UI
  Map<String, dynamic> _getReasonTypeInfo(int typeIndex) {
    switch (typeIndex) {
      case 0:
        return {
          'name': 'Not Done',
          'icon': Icons.close_rounded,
          'color': Colors.red,
          'defaultIcon': Icons.sentiment_dissatisfied_rounded,
        };
      case 1:
        return {
          'name': 'Postpone',
          'icon': Icons.schedule_rounded,
          'color': Colors.orange,
          'defaultIcon': Icons.schedule_rounded,
        };
      case 2:
        return {
          'name': 'Slip',
          'icon': Icons.sentiment_very_dissatisfied_rounded,
          'color': Colors.red[700]!,
          'defaultIcon': Icons.warning_rounded,
        };
      case 3:
        return {
          'name': 'Temptation',
          'icon': Icons.psychology_outlined,
          'color': Colors.amber[700]!,
          'defaultIcon': Icons.psychology_outlined,
        };
      default:
        return {
          'name': 'Unknown',
          'icon': Icons.note_rounded,
          'color': Colors.grey,
          'defaultIcon': Icons.note_rounded,
        };
    }
  }

  /// Show bottom sheet to add a new reason
  /// Modern step-by-step reason creation wizard
  void _showCreateReasonWizard(
    BuildContext context,
    bool isDark,
    int typeIndex,
    Color accentColor,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SheetDismissOnOverscroll(
        child: _ReasonCreationWizard(
          isDark: isDark,
          typeIndex: typeIndex,
          accentColor: accentColor,
          onSave: (reason) {
            ref.read(habitReasonNotifierProvider.notifier).addReason(reason);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Colors.white),
                    const SizedBox(width: 12),
                    Text('Reason "${reason.text}" created!'),
                  ],
                ),
                backgroundColor: accentColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showAddReasonBottomSheet(
    BuildContext context,
    bool isDark,
    int typeIndex,
  ) {
    final textController = TextEditingController();
    final typeInfo = _getReasonTypeInfo(typeIndex);
    IconData? selectedIcon = typeInfo['defaultIcon'] as IconData;
    Color selectedColor = typeInfo['color'] as Color; // Add color selection

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SheetDismissOnOverscroll(
          child: Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 20,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2D3139) : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add ${typeInfo['name']} Reason',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 20),
                // Icon and Color selector row
                Row(
                  children: [
                    // Icon selector
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Icon',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () async {
                              final icon = await showDialog<IconData>(
                                context: context,
                                builder: (context) => IconPickerWidget(
                                  selectedIcon:
                                      selectedIcon ?? Icons.note_rounded,
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
                                color: selectedColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selectedColor,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                selectedIcon,
                                color: selectedColor,
                                size: 28,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Color selector
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Color',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () async {
                              final color = await showDialog<Color>(
                                context: context,
                                builder: (context) => ColorPickerWidget(
                                  selectedColor: selectedColor,
                                  isDark: isDark,
                                ),
                              );
                              if (color != null) {
                                setSheetState(() => selectedColor = color);
                              }
                            },
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: selectedColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white24
                                      : Colors.black12,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
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
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (textController.text.trim().isNotEmpty &&
                          selectedIcon != null) {
                        final reason = HabitReason(
                          text: textController.text.trim(),
                          icon: selectedIcon,
                          typeIndex: typeIndex,
                          colorValue: selectedColor.value, // Add color
                        );
                        ref
                            .read(habitReasonNotifierProvider.notifier)
                            .addReason(reason);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Reason added!'),
                            backgroundColor: Color(0xFF4CAF50),
                          ),
                        );
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
      ),
    );
  }

  /// Show bottom sheet to edit an existing reason
  /// Show options sheet for a reason (edit, toggle active, delete)
  void _showReasonOptionsSheet(
    BuildContext context,
    bool isDark,
    HabitReason reason,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SheetDismissOnOverscroll(
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2D3139) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                // Reason preview
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: reason.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: reason.color.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        reason.icon ?? Icons.note_rounded,
                        color: reason.color,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              reason.text,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            Text(
                              '${reason.isDefault ? 'Default' : 'Custom'} • ${reason.isActive ? 'Active' : 'Inactive'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.white54
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Actions
                _buildOptionTile(
                  context: context,
                  isDark: isDark,
                  icon: Icons.edit_rounded,
                  color: const Color(0xFFCDAF56),
                  title: 'Edit Reason',
                  subtitle: 'Change text, icon, or color',
                  onTap: () {
                    Navigator.pop(context);
                    _showEditReasonBottomSheet(context, isDark, reason);
                  },
                ),
                _buildOptionTile(
                  context: context,
                  isDark: isDark,
                  icon: reason.isActive
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: reason.isActive ? Colors.orange : Colors.green,
                  title: reason.isActive ? 'Deactivate' : 'Activate',
                  subtitle: reason.isActive
                      ? 'Hide from skip dialog (can reactivate later)'
                      : 'Show in skip dialog',
                  onTap: () {
                    ref
                        .read(habitReasonNotifierProvider.notifier)
                        .toggleActive(reason.id);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          reason.isActive
                              ? 'Reason deactivated'
                              : 'Reason activated',
                        ),
                        backgroundColor: reason.isActive
                            ? Colors.orange
                            : Colors.green,
                      ),
                    );
                  },
                ),
                _buildOptionTile(
                  context: context,
                  isDark: isDark,
                  icon: Icons.delete_rounded,
                  color: Colors.red,
                  title: 'Delete',
                  subtitle: 'Permanently remove this reason',
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDeleteReason(context, isDark, reason);
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required BuildContext context,
    required bool isDark,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.white54 : Colors.grey[600],
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: isDark ? Colors.white38 : Colors.grey[400],
      ),
    );
  }

  /// Confirm delete reason
  void _confirmDeleteReason(
    BuildContext context,
    bool isDark,
    HabitReason reason,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF2D3139) : Colors.white,
        title: Text(
          'Delete Reason?',
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "${reason.text}"?',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.grey[700],
              ),
            ),
            if (reason.isDefault) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This is a default reason. You can restore it later by tapping "Reset Defaults".',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.grey[600],
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(habitReasonNotifierProvider.notifier)
                  .deleteReason(reason.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Reason deleted'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showEditReasonBottomSheet(
    BuildContext context,
    bool isDark,
    HabitReason reason,
  ) {
    final textController = TextEditingController(text: reason.text);
    IconData? selectedIcon = reason.icon ?? Icons.note_rounded;
    Color selectedColor = reason.color; // Get existing color

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SheetDismissOnOverscroll(
          child: Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 20,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2D3139) : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
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
                // Icon and Color selector row
                Row(
                  children: [
                    // Icon selector
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Icon',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () async {
                              final icon = await showDialog<IconData>(
                                context: context,
                                builder: (context) => IconPickerWidget(
                                  selectedIcon:
                                      selectedIcon ?? Icons.note_rounded,
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
                                color: selectedColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selectedColor,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                selectedIcon,
                                color: selectedColor,
                                size: 28,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Color selector
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Color',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () async {
                              final color = await showDialog<Color>(
                                context: context,
                                builder: (context) => ColorPickerWidget(
                                  selectedColor: selectedColor,
                                  isDark: isDark,
                                ),
                              );
                              if (color != null) {
                                setSheetState(() => selectedColor = color);
                              }
                            },
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: selectedColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white24
                                      : Colors.black12,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
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
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
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
                          colorValue: selectedColor.value, // Add color
                        );
                        ref
                            .read(habitReasonNotifierProvider.notifier)
                            .updateReason(updated);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Reason updated!'),
                            backgroundColor: Color(0xFF4CAF50),
                          ),
                        );
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
      ),
    );
  }

  // TAB 4: Reset
  Widget _buildResetTab(BuildContext context, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Reset Card
        Card(
          elevation: 4,
          shadowColor: Colors.black.withOpacity(0.15),
          color: isDark ? const Color(0xFF2D3139) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reset Options',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showResetTodayDialog(context, isDark),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reset Today\'s Completions'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: Color(0xFFCDAF56),
                        width: 1.5,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _showResetAllDialog(context, isDark);
                    },
                    icon: const Icon(Icons.warning_rounded),
                    label: const Text('Reset All Habits Data'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
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
          'Reset Today\'s Completions',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'This will undo all habits you marked as completed today.',
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

              final habitsAsync = ref.read(habitNotifierProvider);
              await habitsAsync.when(
                data: (habits) async {
                  final notifier = ref.read(habitNotifierProvider.notifier);

                  // Reset each habit's completion for today
                  for (final habit in habits) {
                    await notifier.uncompleteHabitToday(habit.id);
                  }

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Today\'s habits reset'),
                        backgroundColor: Color(0xFF4CAF50),
                      ),
                    );
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
          'This will permanently delete ALL habit data, including completions, categories, reasons, tags, units, types, and secure quit data. '
          'Notification settings will be reset to defaults. This action CANNOT be undone!',
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
              await _resetAllHabitData(context, isDark);
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

  Future<void> _resetAllHabitData(BuildContext context, bool isDark) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF2D3139) : Colors.white,
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Text(
              'Resetting all habit data...',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );

    try {
      // Cancel all habit reminders first
      await ReminderManager().cancelAllHabitReminders();

      // Reset secure quit data + security state (passcode, recovery)
      await QuitHabitReportSecurityService().resetAllSecurityState();

      // Clear all habit-related data stores
      final habitRepository = ref.read(habitRepositoryProvider);
      final categoryRepository = ref.read(habitCategoryRepositoryProvider);
      final habitTypeRepository = ref.read(habitTypeRepositoryProvider);
      final completionConfigRepository =
          ref.read(completionTypeConfigRepositoryProvider);
      final unitCategoryRepository = ref.read(unitCategoryRepositoryProvider);
      final unitRepository = ref.read(habitUnitRepositoryProvider);
      final reasonRepository = ref.read(habitReasonRepositoryProvider);
      final temptationRepository = ref.read(temptationLogRepositoryProvider);
      final tagNotifier = ref.read(habitTagNotifierProvider.notifier);

      await habitRepository.deleteAllHabits();
      await categoryRepository.deleteAllCategories();
      await habitTypeRepository.deleteAllHabitTypes();
      await completionConfigRepository.deleteAllConfigs();
      await unitRepository.deleteAllUnits();
      await unitCategoryRepository.deleteAllCategories();
      await reasonRepository.deleteAllReasons();
      await temptationRepository.clearAllLogs();
      await temptationRepository.clearLegacyLogs();
      await tagNotifier.clearAllTags();
      await ref.read(habitNotificationSettingsProvider.notifier).resetToDefaults();

      // Reinitialize default configs (factory state)
      await completionConfigRepository.initializeDefaults();
      await unitCategoryRepository.initializeDefaults();
      final unitCategories = await unitCategoryRepository.getAllCategories();
      await unitRepository.initializeDefaults(unitCategories);

      // Refresh UI providers
      await ref.read(habitNotifierProvider.notifier).loadHabits();
      await ref.read(habitCategoryNotifierProvider.notifier).loadCategories();
      await ref.read(habitTypeNotifierProvider.notifier).loadHabitTypes();
      await ref
          .read(completionTypeConfigNotifierProvider.notifier)
          .loadConfigs();
      await ref.read(unitCategoryNotifierProvider.notifier).loadCategories();
      await ref.read(habitUnitNotifierProvider.notifier).loadUnits();
      await ref.read(habitReasonNotifierProvider.notifier).loadReasons();
      await ref.read(temptationLogNotifierProvider.notifier).loadLogs();

      if (!context.mounted) return;
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All habits data has been reset successfully'),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error resetting data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

/// =============================================================================
/// REASON CREATION WIZARD - Beautiful step-by-step flow
/// =============================================================================

class _ReasonCreationWizard extends StatefulWidget {
  final bool isDark;
  final int typeIndex;
  final Color accentColor;
  final Function(HabitReason) onSave;

  const _ReasonCreationWizard({
    required this.isDark,
    required this.typeIndex,
    required this.accentColor,
    required this.onSave,
  });

  @override
  State<_ReasonCreationWizard> createState() => _ReasonCreationWizardState();
}

class _ReasonCreationWizardState extends State<_ReasonCreationWizard>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  final TextEditingController _textController = TextEditingController();
  IconData _selectedIcon = Icons.psychology_rounded;
  Color _selectedColor = const Color(0xFFFF6B6B);
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  // Suggested icons for quit habits
  static const List<Map<String, dynamic>> _suggestedIcons = [
    {'icon': Icons.psychology_rounded, 'label': 'Mind'},
    {'icon': Icons.favorite_border_rounded, 'label': 'Emotion'},
    {'icon': Icons.people_rounded, 'label': 'Social'},
    {'icon': Icons.work_rounded, 'label': 'Work'},
    {'icon': Icons.home_rounded, 'label': 'Home'},
    {'icon': Icons.nightlight_rounded, 'label': 'Night'},
    {'icon': Icons.wb_sunny_rounded, 'label': 'Morning'},
    {'icon': Icons.restaurant_rounded, 'label': 'Food'},
    {'icon': Icons.sports_bar_rounded, 'label': 'Drink'},
    {'icon': Icons.celebration_rounded, 'label': 'Party'},
    {'icon': Icons.mood_bad_rounded, 'label': 'Stress'},
    {'icon': Icons.hourglass_empty_rounded, 'label': 'Bored'},
    {'icon': Icons.visibility_rounded, 'label': 'Saw it'},
    {'icon': Icons.notifications_rounded, 'label': 'Trigger'},
    {'icon': Icons.location_on_rounded, 'label': 'Place'},
    {'icon': Icons.access_time_rounded, 'label': 'Time'},
  ];

  // Color palette
  static const List<Color> _colorPalette = [
    Color(0xFFFF6B6B), // Coral
    Color(0xFFEE5A5A), // Red
    Color(0xFFFF8E53), // Orange
    Color(0xFFFFB347), // Light Orange
    Color(0xFFFFC107), // Amber
    Color(0xFF66BB6A), // Green
    Color(0xFF26A69A), // Teal
    Color(0xFF42A5F5), // Blue
    Color(0xFF5C6BC0), // Indigo
    Color(0xFF7E57C2), // Purple
    Color(0xFFAB47BC), // Violet
    Color(0xFFEC407A), // Pink
  ];

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.accentColor;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _textController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 2) {
      setState(() => _currentStep++);
      _animController.reset();
      _animController.forward();
    } else {
      _saveReason();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _animController.reset();
      _animController.forward();
    }
  }

  void _saveReason() {
    final reason = HabitReason(
      text: _textController.text.trim(),
      icon: _selectedIcon,
      typeIndex: widget.typeIndex,
      colorValue: _selectedColor.value,
      isDefault: false,
    );
    widget.onSave(reason);
    Navigator.pop(context);
  }

  bool get _canProceed {
    switch (_currentStep) {
      case 0:
        return _textController.text.trim().isNotEmpty;
      case 1:
        return true;
      case 2:
        return true;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1A1D21) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: widget.isDark ? Colors.white24 : Colors.grey[300],
              borderRadius: BorderRadius.circular(3),
            ),
          ),

          // Header
          _buildHeader(),

          // Progress indicator
          _buildProgressIndicator(),

          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: _buildStepContent(),
              ),
            ),
          ),

          // Footer with buttons
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final titles = ['Describe your reason', 'Choose an icon', 'Pick a color'];
    final subtitles = _getSubtitles();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.accentColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(_getTypeIcon(), color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titles[_currentStep],
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: widget.isDark
                        ? Colors.white
                        : const Color(0xFF1E1E1E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitles[_currentStep],
                  style: TextStyle(
                    fontSize: 14,
                    color: widget.isDark ? Colors.white54 : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.close_rounded,
              color: widget.isDark ? Colors.white38 : Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  List<String> _getSubtitles() {
    switch (widget.typeIndex) {
      case 0: // Not Done
        return [
          'Why couldn\'t you complete it?',
          'Pick a visual symbol',
          'Choose your color',
        ];
      case 1: // Postpone
        return [
          'Why are you delaying?',
          'Pick a visual symbol',
          'Choose your color',
        ];
      case 2: // Slip
        return [
          'Why did you give in?',
          'Pick a visual symbol',
          'Choose your color',
        ];
      case 3: // Temptation
        return [
          'What triggered the urge?',
          'Pick a visual symbol',
          'Choose your color',
        ];
      default:
        return [
          'Describe your reason',
          'Pick a visual symbol',
          'Choose your color',
        ];
    }
  }

  IconData _getTypeIcon() {
    switch (widget.typeIndex) {
      case 0:
        return Icons.close_rounded;
      case 1:
        return Icons.schedule_rounded;
      case 2:
        return Icons.heart_broken_rounded;
      case 3:
        return Icons.psychology_rounded;
      default:
        return Icons.note_rounded;
    }
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: List.generate(3, (index) {
          final isActive = index <= _currentStep;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
              height: 4,
              decoration: BoxDecoration(
                color: isActive
                    ? widget.accentColor
                    : (widget.isDark ? Colors.white12 : Colors.grey[200]),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildTextStep();
      case 1:
        return _buildIconStep();
      case 2:
        return _buildColorStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildTextStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Preview card
        _buildPreviewCard(),
        const SizedBox(height: 24),

        // Text input
        TextField(
          controller: _textController,
          autofocus: true,
          maxLength: 50,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: widget.isDark ? Colors.white : const Color(0xFF1E1E1E),
          ),
          decoration: InputDecoration(
            hintText: 'e.g., Feeling stressed at work',
            hintStyle: TextStyle(
              color: widget.isDark ? Colors.white30 : Colors.grey[400],
            ),
            filled: true,
            fillColor: widget.isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: widget.accentColor, width: 2),
            ),
            contentPadding: const EdgeInsets.all(20),
            counterStyle: TextStyle(
              color: widget.isDark ? Colors.white38 : Colors.grey[500],
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),

        const SizedBox(height: 20),

        // Quick suggestions
        Text(
          'Quick suggestions',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: widget.isDark ? Colors.white70 : Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _getQuickSuggestions().map((suggestion) {
            return GestureDetector(
              onTap: () {
                _textController.text = suggestion;
                setState(() {});
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.grey[300]!,
                  ),
                ),
                child: Text(
                  suggestion,
                  style: TextStyle(
                    fontSize: 14,
                    color: widget.isDark ? Colors.white70 : Colors.grey[700],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  List<String> _getQuickSuggestions() {
    switch (widget.typeIndex) {
      case 0: // Not Done / Skip
        return [
          'Too tired',
          'No time',
          'Feeling sick',
          'Unexpected event',
          'Lost motivation',
          'Bad weather',
        ];
      case 1: // Postpone
        return [
          'Do it later today',
          'Tomorrow morning',
          'After work',
          'This weekend',
          'Need more energy',
          'When I get home',
        ];
      case 2: // Slip
        return [
          'Stressed out',
          'Social pressure',
          'Felt lonely',
          'Celebrating',
          'Bored',
          'After argument',
        ];
      case 3: // Temptation
        return [
          'Saw someone do it',
          'Passed by old spot',
          'Bad day',
          'Free time',
          'Weekend vibes',
          'Routine reminder',
        ];
      default:
        return ['Custom reason'];
    }
  }

  Widget _buildIconStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Preview
        _buildPreviewCard(),
        const SizedBox(height: 24),

        // Icon grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1,
          ),
          itemCount: _suggestedIcons.length,
          itemBuilder: (context, index) {
            final item = _suggestedIcons[index];
            final icon = item['icon'] as IconData;
            final label = item['label'] as String;
            final isSelected = _selectedIcon == icon;

            return GestureDetector(
              onTap: () => setState(() => _selectedIcon = icon),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _selectedColor.withOpacity(0.12)
                      : (widget.isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.grey[100]),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? _selectedColor
                        : (widget.isDark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.grey[300]!),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 28,
                      color: isSelected
                          ? _selectedColor
                          : (widget.isDark ? Colors.white60 : Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: isSelected
                            ? _selectedColor
                            : (widget.isDark
                                  ? Colors.white54
                                  : Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 20),

        // More icons button
        Center(
          child: TextButton.icon(
            onPressed: () async {
              final pickedIcon = await showDialog<IconData>(
                context: context,
                builder: (context) => IconPickerWidget(
                  isDark: widget.isDark,
                  selectedIcon: _selectedIcon,
                ),
              );
              if (pickedIcon != null) {
                setState(() => _selectedIcon = pickedIcon);
              }
            },
            icon: const Icon(Icons.apps_rounded, size: 18),
            label: const Text('Browse all icons'),
            style: TextButton.styleFrom(foregroundColor: widget.accentColor),
          ),
        ),
      ],
    );
  }

  Widget _buildColorStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Preview
        _buildPreviewCard(),
        const SizedBox(height: 24),

        // Color palette
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1,
          ),
          itemCount: _colorPalette.length,
          itemBuilder: (context, index) {
            final color = _colorPalette[index];
            final isSelected = _selectedColor.value == color.value;

            return GestureDetector(
              onTap: () => setState(() => _selectedColor = color),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? (widget.isDark
                              ? Colors.white
                              : const Color(0xFF1E1E1E))
                        : Colors.transparent,
                    width: 3,
                  ),
                ),
                child: isSelected
                    ? Icon(
                        Icons.check_rounded,
                        color: _getContrastColor(color),
                        size: 24,
                      )
                    : null,
              ),
            );
          },
        ),

        const SizedBox(height: 20),

        // Custom color button
        Center(
          child: TextButton.icon(
            onPressed: () async {
              final pickedColor = await showDialog<Color>(
                context: context,
                builder: (context) => ColorPickerWidget(
                  isDark: widget.isDark,
                  selectedColor: _selectedColor,
                ),
              );
              if (pickedColor != null) {
                setState(() => _selectedColor = pickedColor);
              }
            },
            icon: const Icon(Icons.palette_rounded, size: 18),
            label: const Text('Custom color'),
            style: TextButton.styleFrom(foregroundColor: widget.accentColor),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _selectedColor.withOpacity(0.15),
            _selectedColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _selectedColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _selectedColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_selectedIcon, color: _selectedColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _textController.text.isEmpty
                      ? 'Your reason'
                      : _textController.text,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: widget.isDark
                        ? Colors.white
                        : const Color(0xFF1E1E1E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.typeIndex == 2 ? 'Slip reason' : 'Temptation trigger',
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.isDark ? Colors.white54 : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Text(
            'Preview',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _selectedColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1A1D21) : Colors.white,
        border: Border(
          top: BorderSide(
            color: widget.isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.grey[200]!,
          ),
        ),
      ),
      child: Row(
        children: [
          // Back button
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _prevStep,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(
                    color: widget.isDark ? Colors.white24 : Colors.grey[300]!,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Back',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: widget.isDark ? Colors.white70 : Colors.grey[700],
                  ),
                ),
              ),
            ),

          if (_currentStep > 0) const SizedBox(width: 12),

          // Next/Create button
          Expanded(
            flex: _currentStep > 0 ? 2 : 1,
            child: ElevatedButton(
              onPressed: _canProceed ? _nextStep : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: widget.accentColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: widget.accentColor.withOpacity(0.3),
                disabledForegroundColor: Colors.white54,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _currentStep == 2 ? 'Create Reason' : 'Continue',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _currentStep == 2
                        ? Icons.check_rounded
                        : Icons.arrow_forward_rounded,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getContrastColor(Color color) {
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? const Color(0xFF1E1E1E) : Colors.white;
  }
}
