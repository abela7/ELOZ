import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/task_template.dart';
import '../../../../data/models/category.dart';
import '../providers/template_providers.dart';
import '../providers/category_providers.dart';
import '../screens/task_templates_screen.dart';

/// Bottom sheet for selecting a template when creating a new task
class TemplateSelectorSheet extends ConsumerStatefulWidget {
  const TemplateSelectorSheet({super.key});

  @override
  ConsumerState<TemplateSelectorSheet> createState() => _TemplateSelectorSheetState();
}

class _TemplateSelectorSheetState extends ConsumerState<TemplateSelectorSheet> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _recentlyUsedExpanded = false;
  bool _mostUsedExpanded = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final templatesAsync = _searchQuery.isEmpty
        ? ref.watch(templateNotifierProvider)
        : ref.watch(templateSearchProvider(_searchQuery));
    final categoriesAsync = ref.watch(categoryNotifierProvider);
    final recentlyUsedAsync = ref.watch(recentlyUsedTemplatesProvider);
    final mostUsedAsync = ref.watch(mostUsedTemplatesProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1D23) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header - Compact
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCDAF56).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.dashboard_customize_rounded,
                        color: Color(0xFFCDAF56),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Templates',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const TaskTemplatesScreen(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCDAF56).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.settings_rounded, size: 14, color: const Color(0xFFCDAF56)),
                            const SizedBox(width: 4),
                            Text(
                              'Manage',
                              style: TextStyle(
                                color: const Color(0xFFCDAF56),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Search Bar - Compact
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search...',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white.withOpacity(0.3) : Colors.black.withOpacity(0.3),
                      fontSize: 13,
                    ),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 12, right: 8),
                      child: Icon(
                        Icons.search_rounded,
                        color: isDark ? Colors.white.withOpacity(0.3) : Colors.black.withOpacity(0.3),
                        size: 18,
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            child: Icon(Icons.close_rounded, size: 16, color: isDark ? Colors.white.withOpacity(0.3) : Colors.black.withOpacity(0.3)),
                          )
                        : null,
                    filled: true,
                    fillColor: isDark ? const Color(0xFF252A31) : Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
              
              // Content
              Expanded(
                child: templatesAsync.when(
                  data: (templates) {
                    if (templates.isEmpty && _searchQuery.isEmpty) {
                      return _buildEmptyState(context, isDark);
                    }
                    if (templates.isEmpty && _searchQuery.isNotEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 32,
                              color: isDark ? Colors.white.withOpacity(0.2) : Colors.grey[300],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No results',
                              style: TextStyle(
                                color: isDark ? Colors.white38 : Colors.black38,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    
                    return categoriesAsync.when(
                      data: (categories) => _buildTemplatesList(
                        context,
                        scrollController,
                        isDark,
                        templates,
                        categories,
                        recentlyUsedAsync.valueOrNull ?? [],
                        mostUsedAsync.valueOrNull ?? [],
                      ),
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Error: $e')),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFCDAF56).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.dashboard_customize_rounded,
                size: 36,
                color: const Color(0xFFCDAF56).withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No Templates',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Create templates for tasks you repeat',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white38 : Colors.black38,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const TaskTemplatesScreen(),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFCDAF56),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.add_rounded, size: 16, color: Colors.black87),
                    SizedBox(width: 6),
                    Text(
                      'Create Template',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplatesList(
    BuildContext context,
    ScrollController scrollController,
    bool isDark,
    List<TaskTemplate> templates,
    List<Category> categories,
    List<TaskTemplate> recentlyUsed,
    List<TaskTemplate> mostUsed,
  ) {
    // Group templates by category
    final Map<String?, List<TaskTemplate>> grouped = {};
    for (final template in templates) {
      grouped.putIfAbsent(template.categoryId, () => []).add(template);
    }

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        // Recently Used Accordion
        if (_searchQuery.isEmpty && recentlyUsed.isNotEmpty)
          _buildAccordionSection(
            isDark: isDark,
            title: 'Recently Used',
            icon: Icons.history_rounded,
            count: recentlyUsed.length,
            isExpanded: _recentlyUsedExpanded,
            onTap: () => setState(() => _recentlyUsedExpanded = !_recentlyUsedExpanded),
            children: recentlyUsed.take(3).map((template) => _buildTemplateItemCompact(
              context,
              isDark,
              template,
              categories,
            )).toList(),
          ),
        
        // Most Used Accordion
        if (_searchQuery.isEmpty && mostUsed.isNotEmpty && mostUsed.any((t) => t.usageCount > 0))
          _buildAccordionSection(
            isDark: isDark,
            title: 'Most Used',
            icon: Icons.star_rounded,
            count: mostUsed.where((t) => t.usageCount > 0).length,
            isExpanded: _mostUsedExpanded,
            onTap: () => setState(() => _mostUsedExpanded = !_mostUsedExpanded),
            children: mostUsed.where((t) => t.usageCount > 0).take(3).map((template) => _buildTemplateItemCompact(
              context,
              isDark,
              template,
              categories,
            )).toList(),
          ),
        
        // All Templates by Category - Always visible
        ...grouped.entries.map((entry) {
          final categoryId = entry.key;
          final categoryTemplates = entry.value;
          
          Category? category;
          if (categoryId != null) {
            try {
              category = categories.firstWhere((c) => c.id == categoryId);
            } catch (_) {
              category = null;
            }
          }
          
          return _buildCategoryGroup(
            context,
            isDark,
            category,
            categoryTemplates,
            categories,
          );
        }),
      ],
    );
  }
  
  Widget _buildAccordionSection({
    required bool isDark,
    required String title,
    required IconData icon,
    required int count,
    required bool isExpanded,
    required VoidCallback onTap,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          // Accordion Header
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF252A31) : Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isExpanded 
                      ? const Color(0xFFCDAF56).withOpacity(0.3)
                      : (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
                ),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 14, color: const Color(0xFFCDAF56)),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCDAF56).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: Color(0xFFCDAF56),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more_rounded,
                      size: 18,
                      color: isDark ? Colors.white.withOpacity(0.3) : Colors.black.withOpacity(0.3),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Accordion Content
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(children: children),
            ),
            crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryGroup(
    BuildContext context,
    bool isDark,
    Category? category,
    List<TaskTemplate> templates,
    List<Category> allCategories,
  ) {
    final categoryColor = category?.color ?? Colors.grey;
    final categoryIcon = category?.icon ?? Icons.folder_outlined;
    final categoryName = category?.name ?? 'Uncategorized';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category Header - Compact
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: categoryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(categoryIcon, size: 12, color: categoryColor),
                ),
                const SizedBox(width: 8),
                Text(
                  categoryName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: categoryColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${templates.length}',
                    style: TextStyle(
                      color: categoryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Templates - Compact
          ...templates.map((template) => _buildTemplateItemCompact(
            context,
            isDark,
            template,
            allCategories,
          )),
        ],
      ),
    );
  }

  Widget _buildTemplateItemCompact(
    BuildContext context,
    bool isDark,
    TaskTemplate template,
    List<Category> categories,
  ) {
    Category? category;
    if (template.categoryId != null) {
      try {
        category = categories.firstWhere((c) => c.id == template.categoryId);
      } catch (_) {
        category = null;
      }
    }
    
    final categoryColor = category?.color ?? const Color(0xFFCDAF56);
    final templateIcon = template.icon ?? Icons.task_alt_rounded;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: isDark ? const Color(0xFF252A31) : Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            Navigator.of(context).pop(template);
          },
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // Icon - Smaller
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: categoryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(templateIcon, size: 16, color: categoryColor),
                ),
                const SizedBox(width: 10),
                
                // Title & Stats - Compact
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        template.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.play_arrow_rounded,
                            size: 10,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${template.usageCount}',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.schedule_rounded,
                            size: 10,
                            color: isDark ? Colors.white30 : Colors.black26,
                          ),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              template.lastUsedAgo,
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? Colors.white30 : Colors.black26,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Priority Badge - Smaller
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: _getPriorityColor(template.priority).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    template.priority[0].toUpperCase(),
                    style: TextStyle(
                      color: _getPriorityColor(template.priority),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return const Color(0xFFFF5252);
      case 'medium':
        return const Color(0xFFFFA726);
      case 'low':
        return const Color(0xFF66BB6A);
      default:
        return Colors.grey;
    }
  }
}

/// Shows the template selector bottom sheet
/// Returns the selected template or null if dismissed
Future<TaskTemplate?> showTemplateSelector(BuildContext context) {
  return showModalBottomSheet<TaskTemplate>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const TemplateSelectorSheet(),
  );
}
